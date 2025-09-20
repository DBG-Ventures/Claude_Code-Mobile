//
//  ClaudeNetworkClient.swift
//  Core HTTP/URLSession operations for Claude API communication
//

import Foundation
import Observation

@MainActor
@Observable
final class ClaudeNetworkClient: NetworkClientProtocol {

    // MARK: - Observable Properties

    var isConnected: Bool = false
    var connectionStatus: ConnectionStatus = .disconnected
    let baseURL: URL

    // MARK: - Private Properties

    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let maxRetryAttempts = 3
    private let baseRetryDelay: TimeInterval = 1.0
    private let maxRetryDelay: TimeInterval = 30.0

    // MARK: - Initialization

    init(baseURL: URL, configuration: URLSessionConfiguration = .default) {
        self.baseURL = baseURL

        // Configure URLSession with mobile optimizations
        var config = configuration
        config.timeoutIntervalForRequest = 300.0  // 5 minutes for requests
        config.timeoutIntervalForResource = 600.0 // 10 minutes for resources
        config.waitsForConnectivity = true
        config.allowsCellularAccess = true
        config.allowsExpensiveNetworkAccess = true
        config.sessionSendsLaunchEvents = true

        self.session = URLSession(configuration: config)

        // Configure JSON encoder/decoder with custom date format
        // Backend expects format: yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        self.encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .formatted(dateFormatter)

        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(dateFormatter)
    }

    // MARK: - NetworkClientProtocol Implementation

    func connect() async throws {
        guard connectionStatus != .connecting && !isConnected else { return }

        connectionStatus = .connecting

        do {
            let isHealthy = try await checkHealth()
            if isHealthy {
                isConnected = true
                connectionStatus = .connected
                print("✅ Network client connected successfully")
            } else {
                throw ClaudeServiceError.healthCheckFailed
            }
        } catch {
            isConnected = false
            connectionStatus = .error(error.localizedDescription)
            throw error
        }
    }

    func disconnect() async {
        isConnected = false
        connectionStatus = .disconnected
        print("🔌 Network client disconnected")
    }

    func checkHealth() async throws -> Bool {
        let healthURL = baseURL.appendingPathComponent("health")
        let (data, response) = try await session.data(from: healthURL)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return false
        }

        let healthResponse = try decoder.decode(HealthResponse.self, from: data)
        return healthResponse.status == "healthy"
    }

    // MARK: - Core Request Methods

    func request<T: Decodable>(_ endpoint: String, method: HTTPMethod, body: Data?) async throws -> T {
        // Properly construct URL to handle query parameters
        let url: URL
        if endpoint.contains("?") {
            // If endpoint contains query parameters, append as string to avoid encoding
            url = URL(string: baseURL.absoluteString + "/" + endpoint)!
        } else {
            // For simple paths, use appendingPathComponent
            url = baseURL.appendingPathComponent(endpoint)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = body {
            request.httpBody = body
        }

        return try await performRequest(request)
    }

    func stream(_ endpoint: String, method: HTTPMethod, body: Data?) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            Task {
                await self.performStreamRequest(endpoint: endpoint, method: method, body: body, continuation: continuation)
            }
        }
    }

    // MARK: - Convenience Methods

    func get<T: Decodable>(_ endpoint: String) async throws -> T {
        try await request(endpoint, method: .get, body: nil)
    }

    func post<T: Decodable, U: Encodable>(_ endpoint: String, body: U) async throws -> T {
        let bodyData = try encoder.encode(body)
        return try await request(endpoint, method: .post, body: bodyData)
    }

    func put<T: Decodable, U: Encodable>(_ endpoint: String, body: U) async throws -> T {
        let bodyData = try encoder.encode(body)
        return try await request(endpoint, method: .put, body: bodyData)
    }

    func delete(_ endpoint: String) async throws {
        let _: EmptyResponse = try await request(endpoint, method: .delete, body: nil)
    }

    // MARK: - Private Methods

    private func performRequest<T: Decodable>(_ request: URLRequest, attempt: Int = 0) async throws -> T {
        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ClaudeServiceError.invalidResponse
            }

            if httpResponse.statusCode == 429 {
                // Handle rate limiting
                if attempt < maxRetryAttempts {
                    let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                        .flatMap { Double($0) } ?? baseRetryDelay
                    let delay = calculateRetryDelay(attempt: attempt, statusCode: 429)
                    print("⚠️ Rate limited, retrying in \(delay)s")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    return try await performRequest(request, attempt: attempt + 1)
                }
                throw NetworkError.rateLimited(retryAfter: nil)
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                if let errorData = try? decoder.decode(ErrorResponse.self, from: data) {
                    throw ClaudeServiceError.serverError(errorData.message)
                }
                throw ClaudeServiceError.serverError("HTTP \(httpResponse.statusCode)")
            }

            return try decoder.decode(T.self, from: data)

        } catch {
            if attempt < maxRetryAttempts && isRetryableError(error) {
                let delay = calculateRetryDelay(attempt: attempt, statusCode: 0)
                print("⚠️ Request error: \(error.localizedDescription), retrying in \(delay)s")
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                return try await performRequest(request, attempt: attempt + 1)
            }
            throw error
        }
    }

    private func performStreamRequest(endpoint: String, method: HTTPMethod, body: Data?, continuation: AsyncThrowingStream<Data, Error>.Continuation) async {
        // Properly construct URL to handle query parameters
        let url: URL
        if endpoint.contains("?") {
            // If endpoint contains query parameters, append as string to avoid encoding
            url = URL(string: baseURL.absoluteString + "/" + endpoint)!
        } else {
            // For simple paths, use appendingPathComponent
            url = baseURL.appendingPathComponent(endpoint)
        }
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = body {
            request.httpBody = body
        }

        do {
            let (bytes, response) = try await session.bytes(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                if let httpResponse = response as? HTTPURLResponse,
                   let errorData = try? Data(contentsOf: url),
                   let errorResponse = try? decoder.decode(ErrorResponse.self, from: errorData) {
                    continuation.finish(throwing: ClaudeServiceError.serverError(errorResponse.message))
                } else {
                    continuation.finish(throwing: ClaudeServiceError.invalidResponse)
                }
                return
            }

            for try await line in bytes.lines {
                if line.hasPrefix("data: ") {
                    let jsonString = String(line.dropFirst(6))
                    if let data = jsonString.data(using: .utf8) {
                        continuation.yield(data)
                    }
                }
            }

            continuation.finish()

        } catch {
            continuation.finish(throwing: error)
        }
    }

    private func calculateRetryDelay(attempt: Int, statusCode: Int) -> TimeInterval {
        let exponentialDelay = min(baseRetryDelay * pow(2.0, Double(attempt)), maxRetryDelay)
        let jitter = Double.random(in: 0...0.3) * exponentialDelay

        if statusCode == 429 {
            return exponentialDelay + jitter + 5.0
        }

        return exponentialDelay + jitter
    }

    private func isRetryableError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .networkConnectionLost, .notConnectedToInternet,
                 .dnsLookupFailed, .cannotConnectToHost:
                return true
            default:
                return false
            }
        }

        if let serviceError = error as? ClaudeServiceError {
            switch serviceError {
            case .connectionTimeout, .healthCheckFailed:
                return true
            default:
                return false
            }
        }

        return false
    }
}

// MARK: - Supporting Types

private struct EmptyResponse: Codable {}