//
//  ClaudeService.swift
//  Facade for coordinating Claude API operations using modular services
//
//  Refactored to use dependency injection and delegate operations to specialized services.
//  Maintains ClaudeServiceProtocol compatibility while using clean architecture.
//

import Foundation
import Observation
import UIKit

// MARK: - Claude Service Protocol

protocol ClaudeServiceProtocol: AnyObject {
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
    func disconnect() async
    func checkHealth() async throws -> Bool
}

// MARK: - Connection Status moved to ClaudeServiceModels.swift

// MARK: - Service Interfaces imported from dedicated protocol files

// MARK: - Claude Service Implementation

@MainActor
@Observable
final class ClaudeService: NSObject, ClaudeServiceProtocol {

    // MARK: - Observable Properties

    var isConnected: Bool = false
    var connectionStatus: ConnectionStatus = .disconnected
    var sessionManagerConnectionStatus: SessionManagerConnectionStatus = .disconnected
    var lastError: ErrorResponse?
    var sessionManagerStats: SessionManagerStats?

    // MARK: - Service Dependencies

    private let networkClient: NetworkClientProtocol
    private let sessionDataSource: SessionDataSourceProtocol

    /// Expose sessionDataSource for dependency injection in other services
    var sessionAPIClient: SessionDataSourceProtocol {
        return sessionDataSource
    }
    private let streamingService: ClaudeStreamingServiceProtocol
    private let queryService: ClaudeQueryServiceProtocol

    // MARK: - Legacy Properties (temporary for backwards compatibility)

    private let baseURL: URL
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var lifecycleObservers: [NSObjectProtocol] = []

    // MARK: - Initialization

    init(
        networkClient: NetworkClientProtocol,
        sessionDataSource: SessionDataSourceProtocol,
        streamingService: ClaudeStreamingServiceProtocol,
        queryService: ClaudeQueryServiceProtocol
    ) {
        self.networkClient = networkClient
        self.sessionDataSource = sessionDataSource
        self.streamingService = streamingService
        self.queryService = queryService
        self.baseURL = networkClient.baseURL

        super.init()

        setupLifecycleObservers()
    }

    // Cleanup handled through proper lifecycle management

    // MARK: - Lifecycle Management

    private func setupLifecycleObservers() {
        // Handle app lifecycle transitions for connection management
        lifecycleObservers.append(
            NotificationCenter.default.addObserver(
                forName: UIApplication.willEnterForegroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    await self?.handleAppWillEnterForeground()
                }
            }
        )

        lifecycleObservers.append(
            NotificationCenter.default.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.handleAppDidEnterBackground()
                }
            }
        )
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
            try await networkClient.connect()
            isConnected = networkClient.isConnected
            connectionStatus = .connected
            print("✅ Claude service connected successfully")
        } catch {
            isConnected = false
            connectionStatus = .error(error.localizedDescription)
            throw error
        }
    }

    func disconnect() async {
        await networkClient.disconnect()
        isConnected = false
        connectionStatus = .disconnected
        endBackgroundTask()
        print("🔌 Claude service disconnected")
    }

    func checkHealth() async throws -> Bool {
        return try await networkClient.checkHealth()
    }

    // MARK: - Session Management

    func createSession(request: SessionRequest) async throws -> SessionResponse {
        return try await sessionDataSource.createSession(request)
    }

    func getSession(sessionId: String, userId: String) async throws -> SessionResponse {
        return try await sessionDataSource.getSession(sessionId: sessionId, userId: userId)
    }

    func getSessions(request: SessionListRequest) async throws -> SessionListResponse {
        return try await sessionDataSource.getSessions(request)
    }

    func deleteSession(sessionId: String, userId: String = "mobile-user") async throws {
        try await sessionDataSource.deleteSession(sessionId: sessionId, userId: userId)
    }

    // MARK: - Enhanced SessionManager Integration

    func createSessionWithManager(request: EnhancedSessionRequest) async throws -> SessionManagerResponse {
        do {
            let response = try await sessionDataSource.createSessionWithManager(request)
            await updateSessionManagerConnectionStatus(.connected)
            return response
        } catch {
            await updateSessionManagerConnectionStatus(.error)
            throw error
        }
    }

    func getSessionWithManager(sessionId: String, userId: String, includeHistory: Bool = true) async throws -> SessionManagerResponse? {
        do {
            let response = try await sessionDataSource.getSessionWithManager(
                sessionId: sessionId,
                userId: userId,
                includeHistory: includeHistory
            )
            await updateSessionManagerConnectionStatus(.connected)
            return response
        } catch {
            if case ClaudeServiceError.sessionNotFound = error {
                await updateSessionManagerConnectionStatus(.connected)
                return nil
            }
            await updateSessionManagerConnectionStatus(.error)
            throw error
        }
    }

    func getSessionsWithManager(request: SessionListRequest) async throws -> SessionListResponse {
        do {
            let response = try await sessionDataSource.getSessionsWithManager(request)
            await updateSessionManagerConnectionStatus(.connected)
            return response
        } catch {
            await updateSessionManagerConnectionStatus(.error)
            throw error
        }
    }

    func streamQueryWithSessionManager(request: ClaudeQueryRequest) -> AsyncThrowingStream<StreamingChunk, Error> {
        return streamingService.streamQueryWithSessionManager(request)
    }

    func getSessionManagerStats() async throws -> SessionManagerHealthResponse {
        do {
            let response = try await sessionDataSource.getSessionManagerStats()
            await updateSessionManagerConnectionStatus(.connected)
            return response
        } catch {
            await updateSessionManagerConnectionStatus(.error)
            throw error
        }
    }

    private func updateSessionManagerConnectionStatus(_ status: SessionManagerConnectionStatus) async {
        await MainActor.run {
            self.sessionManagerConnectionStatus = status
        }
    }

    func updateSession(request: SessionUpdateRequest) async throws -> SessionResponse {
        return try await sessionDataSource.updateSession(request)
    }

    // MARK: - Query Management

    func sendQuery(request: ClaudeQueryRequest) async throws -> ClaudeQueryResponse {
        return try await queryService.sendQuery(request)
    }

    func streamQuery(request: ClaudeQueryRequest) -> AsyncThrowingStream<StreamingChunk, Error> {
        return streamingService.streamQuery(request)
    }

}