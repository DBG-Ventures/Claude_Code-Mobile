//
//  ClaudeService.swift
//  HTTP client for FastAPI backend communication.
//
//  Provides comprehensive HTTP/WebSocket client for Claude Code mobile backend.
//  Handles real-time streaming, session management, and mobile lifecycle events.
//

import Foundation
import Combine
import UIKit

// MARK: - Claude Service Protocol

protocol ClaudeServiceProtocol: ObservableObject {
    // Legacy session management (backwards compatibility)
    func createSession(request: SessionRequest) async throws -> SessionResponse
    func getSession(sessionId: String, userId: String) async throws -> SessionResponse
    func sendQuery(request: ClaudeQueryRequest) async throws -> ClaudeQueryResponse
    func streamQuery(request: ClaudeQueryRequest) -> AsyncThrowingStream<StreamingChunk, Error>
    func getSessions(request: SessionListRequest) async throws -> SessionListResponse
    func updateSession(request: SessionUpdateRequest) async throws -> SessionResponse

    // Enhanced SessionManager integration
    func createSessionWithManager(request: EnhancedSessionRequest) async throws -> SessionManagerResponse
    func getSessionWithManager(sessionId: String, userId: String, includeHistory: Bool) async throws -> SessionManagerResponse?
    func getSessionsWithManager(request: SessionListRequest) async throws -> SessionListResponse
    func streamQueryWithSessionManager(request: ClaudeQueryRequest) -> AsyncThrowingStream<StreamingChunk, Error>
    func getSessionManagerStats() async throws -> SessionManagerHealthResponse

    // Connection management
    func connect() async throws
    func disconnect()
    func checkHealth() async throws -> Bool
}

// MARK: - Connection Status

enum ConnectionStatus: Equatable {
    case disconnected
    case connecting
    case connected
    case error(String)

    var sessionManagerStatus: SessionManagerConnectionStatus {
        switch self {
        case .disconnected:
            return .disconnected
        case .connecting:
            return .connecting
        case .connected:
            return .connected
        case .error:
            return .error
        }
    }
}

// MARK: - Claude Service Implementation

@MainActor
class ClaudeService: NSObject, ClaudeServiceProtocol {

    // MARK: - Published Properties

    @Published var isConnected: Bool = false
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var sessionManagerConnectionStatus: SessionManagerConnectionStatus = .disconnected
    @Published var lastError: ErrorResponse?
    @Published var sessionManagerStats: SessionManagerStats?

    // MARK: - Private Properties

    private let baseURL: URL
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    // Lifecycle management
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var cancellables = Set<AnyCancellable>()

    // Retry configuration
    private let maxRetryAttempts = 3
    private let baseRetryDelay: TimeInterval = 1.0
    private let maxRetryDelay: TimeInterval = 30.0

    // MARK: - Initialization

    init(baseURL: URL) {
        self.baseURL = baseURL

        // Configure URLSession with mobile optimizations for long-running tasks
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 300.0  // 5 minutes for requests
        configuration.timeoutIntervalForResource = 600.0 // 10 minutes for resources
        configuration.waitsForConnectivity = true
        configuration.allowsCellularAccess = true
        configuration.allowsExpensiveNetworkAccess = true
        configuration.allowsConstrainedNetworkAccess = true

        self.session = URLSession(configuration: configuration)

        // Configure JSON coders with date formatting
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

        encoder.dateEncodingStrategy = .formatted(dateFormatter)
        decoder.dateDecodingStrategy = .formatted(dateFormatter)

        super.init()

        setupLifecycleObservers()
    }

    deinit {
        Task { @MainActor in
            disconnect()
        }
        cancellables.removeAll()
    }

    // MARK: - Lifecycle Management

    private func setupLifecycleObservers() {
        // Handle app lifecycle transitions for connection management
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.handleAppWillEnterForeground()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.handleAppDidEnterBackground()
                }
            }
            .store(in: &cancellables)
    }

    private func handleAppWillEnterForeground() async {
        // Reconnect if needed when app returns to foreground
        if connectionStatus == .disconnected {
            do {
                try await connect()
            } catch {
                print("⚠️ Failed to reconnect on app foreground: \(error)")
            }
        }
    }

    private func handleAppDidEnterBackground() {
        // Keep connection alive but prepare for backgrounding
        backgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }

    // MARK: - Connection Management

    func connect() async throws {
        // Prevent redundant connection attempts
        if isConnected || connectionStatus == .connecting {
            return
        }

        connectionStatus = .connecting

        do {
            let isHealthy = try await checkHealth()
            if isHealthy {
                isConnected = true
                connectionStatus = .connected
                print("✅ Claude service connected successfully")
            } else {
                throw ClaudeServiceError.healthCheckFailed
            }
        } catch {
            isConnected = false
            connectionStatus = .error(error.localizedDescription)
            throw error
        }
    }

    func disconnect() {
        isConnected = false
        connectionStatus = .disconnected
        endBackgroundTask()
        print("🔌 Claude service disconnected")
    }

    func checkHealth() async throws -> Bool {
        let healthURL = baseURL.appendingPathComponent("health")
        let (data, response) = try await session.data(from: healthURL)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return false
        }
        
        // Parse health response
        let healthResponse = try decoder.decode(HealthResponse.self, from: data)
        return healthResponse.status == "healthy"
    }

    // MARK: - Session Management

    func createSession(request: SessionRequest) async throws -> SessionResponse {
        let url = baseURL.appendingPathComponent("claude/sessions")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestData = try encoder.encode(request)
        urlRequest.httpBody = requestData
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeServiceError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
            return try decoder.decode(SessionResponse.self, from: data)
        } else {
            let errorResponse = try? decoder.decode(ErrorResponse.self, from: data)
            throw ClaudeServiceError.serverError(errorResponse?.message ?? "Unknown error")
        }
    }

    func getSession(sessionId: String, userId: String) async throws -> SessionResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("claude/sessions/\(sessionId)"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "user_id", value: userId)
        ]

        guard let url = components.url else {
            throw ClaudeServiceError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeServiceError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            return try decoder.decode(SessionResponse.self, from: data)
        case 404:
            throw ClaudeServiceError.sessionNotFound
        default:
            let errorResponse = try? decoder.decode(ErrorResponse.self, from: data)
            throw ClaudeServiceError.serverError(errorResponse?.message ?? "HTTP \(httpResponse.statusCode)")
        }
    }

    func getSessions(request: SessionListRequest) async throws -> SessionListResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("claude/sessions"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "user_id", value: request.userId),
            URLQueryItem(name: "limit", value: String(request.limit)),
            URLQueryItem(name: "offset", value: String(request.offset))
        ]

        guard let url = components.url else {
            throw ClaudeServiceError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ClaudeServiceError.invalidResponse
        }

        return try decoder.decode(SessionListResponse.self, from: data)
    }

    // MARK: - Enhanced SessionManager Integration

    func createSessionWithManager(request: EnhancedSessionRequest) async throws -> SessionManagerResponse {
        let url = baseURL.appendingPathComponent("claude/sessions")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestData = try encoder.encode(request)
        urlRequest.httpBody = requestData

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeServiceError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200, 201:
            let sessionManagerResponse = try decoder.decode(SessionManagerResponse.self, from: data)
            await updateSessionManagerConnectionStatus(.connected)
            return sessionManagerResponse
        case 404:
            await updateSessionManagerConnectionStatus(.error)
            throw ClaudeServiceError.sessionManagerUnavailable
        default:
            let errorResponse = try? decoder.decode(ErrorResponse.self, from: data)
            await updateSessionManagerConnectionStatus(.error)
            throw ClaudeServiceError.serverError(errorResponse?.message ?? "HTTP \(httpResponse.statusCode)")
        }
    }

    func getSessionWithManager(sessionId: String, userId: String, includeHistory: Bool = true) async throws -> SessionManagerResponse? {
        var components = URLComponents(url: baseURL.appendingPathComponent("claude/sessions/\(sessionId)"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "user_id", value: userId),
            URLQueryItem(name: "include_history", value: String(includeHistory))
        ]

        guard let url = components.url else {
            throw ClaudeServiceError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeServiceError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            let sessionManagerResponse = try decoder.decode(SessionManagerResponse.self, from: data)
            await updateSessionManagerConnectionStatus(.connected)
            return sessionManagerResponse
        case 404:
            await updateSessionManagerConnectionStatus(.connected) // SessionManager is available, session just not found
            return nil
        default:
            let errorResponse = try? decoder.decode(ErrorResponse.self, from: data)
            await updateSessionManagerConnectionStatus(.error)
            throw ClaudeServiceError.serverError(errorResponse?.message ?? "HTTP \(httpResponse.statusCode)")
        }
    }

    func getSessionsWithManager(request: SessionListRequest) async throws -> SessionListResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("claude/sessions"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "user_id", value: request.userId),
            URLQueryItem(name: "limit", value: String(request.limit)),
            URLQueryItem(name: "offset", value: String(request.offset))
        ]

        if let statusFilter = request.statusFilter {
            components.queryItems?.append(URLQueryItem(name: "status_filter", value: statusFilter))
        }

        guard let url = components.url else {
            throw ClaudeServiceError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeServiceError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            let sessionListResponse = try decoder.decode(SessionListResponse.self, from: data)
            await updateSessionManagerConnectionStatus(.connected)

            // TODO: Update local session manager stats if available in future API version
            // SessionListResponse currently doesn't include sessionManagerStats

            return sessionListResponse
        case 404:
            await updateSessionManagerConnectionStatus(.error)
            throw ClaudeServiceError.sessionManagerUnavailable
        default:
            let errorResponse = try? decoder.decode(ErrorResponse.self, from: data)
            await updateSessionManagerConnectionStatus(.error)
            throw ClaudeServiceError.serverError(errorResponse?.message ?? "HTTP \(httpResponse.statusCode)")
        }
    }

    func streamQueryWithSessionManager(request: ClaudeQueryRequest) -> AsyncThrowingStream<StreamingChunk, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                await streamQueryWithSessionManagerRetry(request: request, continuation: continuation, attempt: 0)
            }
        }
    }

    private func streamQueryWithSessionManagerRetry(
        request: ClaudeQueryRequest,
        continuation: AsyncThrowingStream<StreamingChunk, Error>.Continuation,
        attempt: Int
    ) async {
        do {
            let url = baseURL.appendingPathComponent("claude/stream")
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
            urlRequest.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

            let requestData = try encoder.encode(request)
            urlRequest.httpBody = requestData

            let (asyncBytes, response) = try await session.bytes(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ClaudeServiceError.invalidResponse
            }

            // Handle SessionManager-specific errors
            if httpResponse.statusCode == 404 {
                await updateSessionManagerConnectionStatus(.error)
                continuation.finish(throwing: ClaudeServiceError.sessionManagerUnavailable)
                return
            }

            // Handle rate limiting and server errors with retry
            if httpResponse.statusCode == 429 || (500...599).contains(httpResponse.statusCode) {
                if attempt < maxRetryAttempts {
                    let delay = calculateRetryDelay(attempt: attempt, statusCode: httpResponse.statusCode)
                    print("⚠️ SessionManager stream request failed with status \(httpResponse.statusCode), retrying in \(delay)s (attempt \(attempt + 1)/\(maxRetryAttempts))")

                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    await streamQueryWithSessionManagerRetry(request: request, continuation: continuation, attempt: attempt + 1)
                    return
                } else {
                    await updateSessionManagerConnectionStatus(.error)
                    continuation.finish(throwing: ClaudeServiceError.serverError("Max retry attempts reached after status \(httpResponse.statusCode)"))
                    return
                }
            }

            guard httpResponse.statusCode == 200 else {
                await updateSessionManagerConnectionStatus(.error)
                continuation.finish(throwing: ClaudeServiceError.invalidResponse)
                return
            }

            // Mark SessionManager as connected on successful streaming start
            await updateSessionManagerConnectionStatus(.connected)

            var hasReceivedData = false

            // Process Server-Sent Events with SessionManager context preservation
            for try await line in asyncBytes.lines {
                if line.hasPrefix("data: ") {
                    hasReceivedData = true
                    let jsonData = String(line.dropFirst(6))
                    if let data = jsonData.data(using: .utf8) {
                        do {
                            let chunk = try decoder.decode(StreamingChunk.self, from: data)
                            continuation.yield(chunk)

                            if chunk.chunkType == .complete || chunk.chunkType == .error {
                                continuation.finish()
                                return
                            }
                        } catch {
                            print("⚠️ Failed to decode SessionManager streaming chunk: \(error)")
                        }
                    }
                } else if line.hasPrefix(":ping") || line.hasPrefix(": ping") {
                    // SessionManager keep-alive
                    continue
                }
            }

            // If stream ended without completion, check if retry is needed
            if !hasReceivedData && attempt < maxRetryAttempts {
                let delay = calculateRetryDelay(attempt: attempt, statusCode: 0)
                print("⚠️ SessionManager stream ended without data, retrying in \(delay)s (attempt \(attempt + 1)/\(maxRetryAttempts))")

                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                await streamQueryWithSessionManagerRetry(request: request, continuation: continuation, attempt: attempt + 1)
            } else {
                continuation.finish()
            }
        } catch {
            // Handle network errors with retry
            if attempt < maxRetryAttempts && isRetryableError(error) {
                let delay = calculateRetryDelay(attempt: attempt, statusCode: 0)
                print("⚠️ SessionManager stream error: \(error.localizedDescription), retrying in \(delay)s (attempt \(attempt + 1)/\(maxRetryAttempts))")

                do {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    await streamQueryWithSessionManagerRetry(request: request, continuation: continuation, attempt: attempt + 1)
                } catch {
                    await updateSessionManagerConnectionStatus(.error)
                    continuation.finish(throwing: error)
                }
            } else {
                await updateSessionManagerConnectionStatus(.error)
                continuation.finish(throwing: error)
            }
        }
    }

    func getSessionManagerStats() async throws -> SessionManagerHealthResponse {
        let url = baseURL.appendingPathComponent("claude/session-manager/stats")
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeServiceError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            let statsResponse = try decoder.decode(SessionManagerHealthResponse.self, from: data)
            await updateSessionManagerConnectionStatus(.connected)

            // Extract and store session manager stats if available
            if let statsData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let sessionManagerStatsData = statsData["session_manager_stats"] as? [String: Any] {

                let statsJsonData = try JSONSerialization.data(withJSONObject: sessionManagerStatsData)
                let stats = try decoder.decode(SessionManagerStats.self, from: statsJsonData)

                await MainActor.run {
                    self.sessionManagerStats = stats
                }
            }

            return statsResponse
        case 404:
            await updateSessionManagerConnectionStatus(.error)
            throw ClaudeServiceError.sessionManagerUnavailable
        default:
            let errorResponse = try? decoder.decode(ErrorResponse.self, from: data)
            await updateSessionManagerConnectionStatus(.error)
            throw ClaudeServiceError.serverError(errorResponse?.message ?? "HTTP \(httpResponse.statusCode)")
        }
    }

    private func updateSessionManagerConnectionStatus(_ status: SessionManagerConnectionStatus) async {
        await MainActor.run {
            self.sessionManagerConnectionStatus = status
        }
    }

    func updateSession(request: SessionUpdateRequest) async throws -> SessionResponse {
        let url = baseURL.appendingPathComponent("claude/sessions/\(request.sessionId)")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "PUT"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestData = try encoder.encode(request)
        urlRequest.httpBody = requestData
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ClaudeServiceError.invalidResponse
        }
        
        return try decoder.decode(SessionResponse.self, from: data)
    }

    // MARK: - Query Management

    func sendQuery(request: ClaudeQueryRequest) async throws -> ClaudeQueryResponse {
        let url = baseURL.appendingPathComponent("claude/query")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestData = try encoder.encode(request)
        urlRequest.httpBody = requestData
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ClaudeServiceError.invalidResponse
        }
        
        return try decoder.decode(ClaudeQueryResponse.self, from: data)
    }

    func streamQuery(request: ClaudeQueryRequest) -> AsyncThrowingStream<StreamingChunk, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                await streamQueryWithRetry(request: request, continuation: continuation, attempt: 0)
            }
        }
    }

    private func streamQueryWithRetry(
        request: ClaudeQueryRequest,
        continuation: AsyncThrowingStream<StreamingChunk, Error>.Continuation,
        attempt: Int
    ) async {
        do {
            let url = baseURL.appendingPathComponent("claude/stream")
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
            urlRequest.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

            let requestData = try encoder.encode(request)
            urlRequest.httpBody = requestData

            let (asyncBytes, response) = try await session.bytes(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ClaudeServiceError.invalidResponse
            }

            // Handle rate limiting and server errors with retry
            if httpResponse.statusCode == 429 || (500...599).contains(httpResponse.statusCode) {
                if attempt < maxRetryAttempts {
                    let delay = calculateRetryDelay(attempt: attempt, statusCode: httpResponse.statusCode)
                    print("⚠️ Stream request failed with status \(httpResponse.statusCode), retrying in \(delay)s (attempt \(attempt + 1)/\(maxRetryAttempts))")

                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    await streamQueryWithRetry(request: request, continuation: continuation, attempt: attempt + 1)
                    return
                } else {
                    continuation.finish(throwing: ClaudeServiceError.serverError("Max retry attempts reached after status \(httpResponse.statusCode)"))
                    return
                }
            }

            guard httpResponse.statusCode == 200 else {
                continuation.finish(throwing: ClaudeServiceError.invalidResponse)
                return
            }

            var hasReceivedData = false
            var connectionIdleTime: TimeInterval = 0
            let maxIdleTime: TimeInterval = 30.0

            // Process Server-Sent Events with connection monitoring
            for try await line in asyncBytes.lines {
                connectionIdleTime = 0  // Reset idle timer on data received

                if line.hasPrefix("data: ") {
                    hasReceivedData = true
                    let jsonData = String(line.dropFirst(6))
                    if let data = jsonData.data(using: .utf8) {
                        do {
                            let chunk = try decoder.decode(StreamingChunk.self, from: data)
                            continuation.yield(chunk)

                            if chunk.chunkType == .complete || chunk.chunkType == .error {
                                continuation.finish()
                                return
                            }
                        } catch {
                            print("⚠️ Failed to decode streaming chunk: \(error)")
                            // Continue processing other chunks
                        }
                    }
                } else if line.hasPrefix(":ping") || line.hasPrefix(": ping") {
                    // Server keep-alive, reset idle timer
                    connectionIdleTime = 0
                }
            }

            // If stream ended without completion, check if retry is needed
            if !hasReceivedData && attempt < maxRetryAttempts {
                let delay = calculateRetryDelay(attempt: attempt, statusCode: 0)
                print("⚠️ Stream ended without data, retrying in \(delay)s (attempt \(attempt + 1)/\(maxRetryAttempts))")

                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                await streamQueryWithRetry(request: request, continuation: continuation, attempt: attempt + 1)
            } else {
                continuation.finish()
            }
        } catch {
            // Handle network errors with retry
            if attempt < maxRetryAttempts && isRetryableError(error) {
                let delay = calculateRetryDelay(attempt: attempt, statusCode: 0)
                print("⚠️ Stream error: \(error.localizedDescription), retrying in \(delay)s (attempt \(attempt + 1)/\(maxRetryAttempts))")

                do {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    await streamQueryWithRetry(request: request, continuation: continuation, attempt: attempt + 1)
                } catch {
                    continuation.finish(throwing: error)
                }
            } else {
                continuation.finish(throwing: error)
            }
        }
    }

    private func calculateRetryDelay(attempt: Int, statusCode: Int) -> TimeInterval {
        // Exponential backoff with jitter
        let exponentialDelay = min(baseRetryDelay * pow(2.0, Double(attempt)), maxRetryDelay)
        let jitter = Double.random(in: 0...0.3) * exponentialDelay

        // Additional delay for rate limiting
        if statusCode == 429 {
            return exponentialDelay + jitter + 5.0  // Add extra delay for rate limits
        }

        return exponentialDelay + jitter
    }

    private func isRetryableError(_ error: Error) -> Bool {
        // Check for retryable network errors
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .networkConnectionLost, .notConnectedToInternet,
                 .dnsLookupFailed, .cannotConnectToHost:
                return true
            default:
                return false
            }
        }

        // Check for our custom errors
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

    private func isSessionManagerError(_ error: Error) -> Bool {
        if let serviceError = error as? ClaudeServiceError {
            switch serviceError {
            case .sessionManagerUnavailable:
                return true
            default:
                return false
            }
        }
        return false
    }
}

// MARK: - Error Types

enum ClaudeServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(String)
    case sessionNotFound
    case sessionManagerUnavailable
    case healthCheckFailed
    case connectionTimeout
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid server response"
        case .serverError(let message):
            return "Server error: \(message)"
        case .sessionNotFound:
            return "Session not found"
        case .healthCheckFailed:
            return "Health check failed"
        case .connectionTimeout:
            return "Connection timeout"
        case .sessionManagerUnavailable:
            return "SessionManager service unavailable"
        }
    }
}

// MARK: - Supporting Models

struct SessionListRequest: Codable {
    let userId: String
    let limit: Int
    let offset: Int
    let statusFilter: String?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case limit
        case offset
        case statusFilter = "status_filter"
    }
}

struct SessionListResponse: Codable {
    let sessions: [SessionResponse]
    let totalCount: Int
    let hasMore: Bool
    let nextOffset: Int?
    
    enum CodingKeys: String, CodingKey {
        case sessions
        case totalCount = "total_count"
        case hasMore = "has_more"
        case nextOffset = "next_offset"
    }
}

struct SessionUpdateRequest: Codable {
    let sessionId: String
    let userId: String
    let sessionName: String?
    let status: String?
    let context: [String: AnyCodable]?
    
    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case userId = "user_id"
        case sessionName = "session_name"
        case status
        case context
    }
}

struct HealthResponse: Codable {
    let status: String
    let timestamp: Date
    let version: String
    let dependencies: [String: String]?
}