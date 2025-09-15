"""
ClaudeService.swift - HTTP client for FastAPI backend communication.

Provides comprehensive HTTP/WebSocket client for Claude Code mobile backend.
Handles real-time streaming, session management, and mobile lifecycle events.
"""

import Foundation
import Starscream
import Combine

// MARK: - Claude Service Protocol

protocol ClaudeServiceProtocol: ObservableObject {
    func createSession(request: SessionRequest) async throws -> SessionResponse
    func sendQuery(request: ClaudeQueryRequest) async throws -> ClaudeQueryResponse
    func streamQuery(request: ClaudeQueryRequest) -> AsyncThrowingStream<StreamingChunk, Error>
    func getSessions(request: SessionListRequest) async throws -> SessionListResponse
    func updateSession(request: SessionUpdateRequest) async throws -> SessionResponse
    func connect() async throws
    func disconnect()
}

// MARK: - Claude Service Implementation

@MainActor
class ClaudeService: NSObject, ClaudeServiceProtocol {

    // MARK: - Published Properties

    @Published var isConnected: Bool = false
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var lastError: ErrorResponse?

    // MARK: - Private Properties

    private let baseURL: URL
    private let session: URLSession
    private var webSocket: WebSocket?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    // Stream continuations for real-time responses
    private var streamContinuations: [String: AsyncThrowingStream<StreamingChunk, Error>.Continuation] = [:]

    // Lifecycle management
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(baseURL: URL) {
        self.baseURL = baseURL

        // Configure URLSession with mobile optimizations
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30.0
        configuration.timeoutIntervalForResource = 120.0
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
        disconnect()
        cancellables.removeAll()
    }

    // MARK: - Lifecycle Management

    private func setupLifecycleObservers() {
        // Handle app lifecycle transitions for WebSocket management
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
                    await self?.handleAppDidEnterBackground()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)
            .sink { [weak self] _ in
                self?.disconnect()
            }
            .store(in: &cancellables)
    }

    private func handleAppWillEnterForeground() async {
        // Reconnect WebSocket if needed
        if webSocket != nil && !isConnected {
            do {
                try await connect()
            } catch {
                lastError = ErrorResponse(
                    error: "reconnection_failed",
                    message: "Failed to reconnect when entering foreground",
                    details: ["underlying_error": .string(error.localizedDescription)],
                    timestamp: Date(),
                    requestId: nil
                )
            }
        }
    }

    private func handleAppDidEnterBackground() async {
        // Keep connection alive for background streaming
        backgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }

        // Gracefully pause streaming after 30 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) { [weak self] in
            if UIApplication.shared.applicationState == .background {
                self?.pauseStreaming()
            }
        }
    }

    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }

    private func pauseStreaming() {
        // Gracefully close streaming connections
        for (_, continuation) in streamContinuations {
            continuation.finish()
        }
        streamContinuations.removeAll()
    }

    // MARK: - Connection Management

    func connect() async throws {
        guard !isConnected else { return }

        connectionStatus = .connecting

        // Create WebSocket URL for streaming
        var wsURLComponents = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        wsURLComponents?.scheme = baseURL.scheme == "https" ? "wss" : "ws"
        wsURLComponents?.path = "/claude/stream"

        guard let wsURL = wsURLComponents?.url else {
            throw URLError(.badURL)
        }

        // Configure WebSocket with mobile optimizations
        var request = URLRequest(url: wsURL)
        request.timeoutInterval = 30.0

        webSocket = WebSocket(request: request)
        webSocket?.delegate = self

        // Connect WebSocket
        webSocket?.connect()

        // Wait for connection with timeout
        let connectionTimeout: TimeInterval = 10.0
        let startTime = Date()

        while !isConnected && Date().timeIntervalSince(startTime) < connectionTimeout {
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }

        if !isConnected {
            connectionStatus = .error
            throw URLError(.timedOut)
        }

        connectionStatus = .connected
    }

    func disconnect() {
        webSocket?.disconnect()
        webSocket = nil
        isConnected = false
        connectionStatus = .disconnected

        // Clean up streaming
        for (_, continuation) in streamContinuations {
            continuation.finish()
        }
        streamContinuations.removeAll()

        endBackgroundTask()
    }

    // MARK: - HTTP API Methods

    func createSession(request: SessionRequest) async throws -> SessionResponse {
        let url = baseURL.appendingPathComponent("/claude/sessions")

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestData = try encoder.encode(request)
        urlRequest.httpBody = requestData

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if httpResponse.statusCode >= 400 {
            let errorResponse = try decoder.decode(ErrorResponse.self, from: data)
            throw errorResponse
        }

        return try decoder.decode(SessionResponse.self, from: data)
    }

    func sendQuery(request: ClaudeQueryRequest) async throws -> ClaudeQueryResponse {
        let url = baseURL.appendingPathComponent("/claude/query")

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestData = try encoder.encode(request)
        urlRequest.httpBody = requestData

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if httpResponse.statusCode >= 400 {
            let errorResponse = try decoder.decode(ErrorResponse.self, from: data)
            throw errorResponse
        }

        return try decoder.decode(ClaudeQueryResponse.self, from: data)
    }

    func getSessions(request: SessionListRequest) async throws -> SessionListResponse {
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent("/claude/sessions"), resolvingAgainstBaseURL: false)

        urlComponents?.queryItems = [
            URLQueryItem(name: "user_id", value: request.userId),
            URLQueryItem(name: "limit", value: String(request.limit)),
            URLQueryItem(name: "offset", value: String(request.offset))
        ]

        if let statusFilter = request.statusFilter {
            urlComponents?.queryItems?.append(URLQueryItem(name: "status_filter", value: statusFilter))
        }

        guard let url = urlComponents?.url else {
            throw URLError(.badURL)
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if httpResponse.statusCode >= 400 {
            let errorResponse = try decoder.decode(ErrorResponse.self, from: data)
            throw errorResponse
        }

        return try decoder.decode(SessionListResponse.self, from: data)
    }

    func updateSession(request: SessionUpdateRequest) async throws -> SessionResponse {
        let url = baseURL.appendingPathComponent("/claude/sessions/\(request.sessionId)")

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "PUT"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestData = try encoder.encode(request)
        urlRequest.httpBody = requestData

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if httpResponse.statusCode >= 400 {
            let errorResponse = try decoder.decode(ErrorResponse.self, from: data)
            throw errorResponse
        }

        return try decoder.decode(SessionResponse.self, from: data)
    }

    // MARK: - Streaming API

    func streamQuery(request: ClaudeQueryRequest) -> AsyncThrowingStream<StreamingChunk, Error> {
        return AsyncThrowingStream { continuation in
            Task { @MainActor in
                do {
                    // Ensure WebSocket connection
                    if !isConnected {
                        try await connect()
                    }

                    // Store continuation for this stream
                    let streamId = UUID().uuidString
                    streamContinuations[streamId] = continuation

                    // Send streaming request via WebSocket
                    let requestData = try encoder.encode(request)
                    webSocket?.write(data: requestData)

                    // Set up continuation cleanup
                    continuation.onTermination = { [weak self] _ in
                        Task { @MainActor in
                            self?.streamContinuations.removeValue(forKey: streamId)
                        }
                    }

                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Health Check

    func checkHealth() async throws -> Bool {
        let url = baseURL.appendingPathComponent("/health")

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.timeoutInterval = 10.0

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }

        if httpResponse.statusCode == 200 {
            // Try to parse health response
            if let healthData = try? decoder.decode([String: AnyCodable].self, from: data),
               let status = healthData["status"],
               case .string(let statusString) = status {
                return statusString == "healthy"
            }
            return true
        }

        return false
    }
}

// MARK: - WebSocket Delegate

extension ClaudeService: WebSocketDelegate {

    nonisolated func didReceive(event: WebSocketEvent, client: WebSocketClient) {
        Task { @MainActor in
            handleWebSocketEvent(event)
        }
    }

    private func handleWebSocketEvent(_ event: WebSocketEvent) {
        switch event {
        case .connected(let headers):
            print("🔗 WebSocket connected with headers: \(headers)")
            isConnected = true
            connectionStatus = .connected

        case .disconnected(let reason, let code):
            print("💔 WebSocket disconnected: \(reason) with code: \(code)")
            isConnected = false
            connectionStatus = .disconnected

            // Clean up streams
            for (_, continuation) in streamContinuations {
                continuation.finish()
            }
            streamContinuations.removeAll()

        case .text(let string):
            handleStreamingResponse(string)

        case .binary(let data):
            if let string = String(data: data, encoding: .utf8) {
                handleStreamingResponse(string)
            }

        case .error(let error):
            print("⚠️ WebSocket error: \(error?.localizedDescription ?? "Unknown error")")
            connectionStatus = .error

            let errorResponse = ErrorResponse(
                error: "websocket_error",
                message: error?.localizedDescription ?? "Unknown WebSocket error",
                details: nil,
                timestamp: Date(),
                requestId: nil
            )

            lastError = errorResponse

            // Finish all streams with error
            for (_, continuation) in streamContinuations {
                continuation.finish(throwing: errorResponse)
            }
            streamContinuations.removeAll()

        case .cancelled:
            print("🔄 WebSocket cancelled")
            isConnected = false
            connectionStatus = .disconnected

        case .reconnectSuggested(let reconnect):
            print("🔄 WebSocket reconnect suggested: \(reconnect)")
            if reconnect {
                Task {
                    try? await connect()
                }
            }

        case .viabilityChanged(let viable):
            print("📊 WebSocket viability changed: \(viable)")
            if !viable {
                connectionStatus = .error
            }

        case .peerClosed:
            print("👋 WebSocket peer closed")
            isConnected = false
            connectionStatus = .disconnected
        }
    }

    private func handleStreamingResponse(_ text: String) {
        // Parse Server-Sent Events format
        let lines = text.components(separatedBy: .newlines)

        for line in lines {
            if line.hasPrefix("data: ") {
                let jsonData = String(line.dropFirst(6))

                if let data = jsonData.data(using: .utf8) {
                    do {
                        let chunk = try decoder.decode(StreamingChunk.self, from: data)

                        // Send to all active streams
                        for (_, continuation) in streamContinuations {
                            continuation.yield(chunk)
                        }

                        // Check for completion
                        if chunk.chunkType == .complete {
                            for (_, continuation) in streamContinuations {
                                continuation.finish()
                            }
                            streamContinuations.removeAll()
                        }

                    } catch {
                        print("⚠️ Failed to parse streaming chunk: \(error)")
                    }
                }
            }
        }
    }
}

// MARK: - Connection Status

enum ConnectionStatus: String, CaseIterable {
    case disconnected = "disconnected"
    case connecting = "connecting"
    case connected = "connected"
    case error = "error"

    var displayName: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .error: return "Error"
        }
    }

    var color: String {
        switch self {
        case .disconnected: return "gray"
        case .connecting: return "yellow"
        case .connected: return "green"
        case .error: return "red"
        }
    }
}

// MARK: - Claude Service Factory

class ClaudeServiceFactory {
    static func createService(with config: NetworkConfig) -> ClaudeService {
        guard let baseURL = config.baseURL else {
            fatalError("Invalid network configuration - no base URL")
        }

        return ClaudeService(baseURL: baseURL)
    }
}

// MARK: - Network Configuration

struct NetworkConfig {
    let baseURL: URL?
    let timeout: TimeInterval
    let allowsCellularAccess: Bool

    init(baseURL: URL?, timeout: TimeInterval = 30.0, allowsCellularAccess: Bool = true) {
        self.baseURL = baseURL
        self.timeout = timeout
        self.allowsCellularAccess = allowsCellularAccess
    }

    static var development: NetworkConfig {
        NetworkConfig(baseURL: URL(string: "http://localhost:8000"))
    }

    static var production: NetworkConfig {
        NetworkConfig(baseURL: URL(string: "https://api.yourserver.com"))
    }
}