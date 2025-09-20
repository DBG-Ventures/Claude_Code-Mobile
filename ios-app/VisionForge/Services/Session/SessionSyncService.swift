//
//  SessionSyncService.swift
//  Session synchronization service with backend
//
//  Extracted from SessionRepository for clean separation of sync concerns.
//  Implements background refresh with error recovery and connection monitoring.
//

import Foundation
import Observation

// MARK: - Protocol Definition

protocol SessionSyncServiceProtocol {
    func syncSessionsFromBackend() async throws -> [SessionManagerResponse]
    func syncSessionToBackend(_ session: SessionManagerResponse) async throws
    func performBackgroundSync() async
}

/// Service responsible for synchronizing session data with backend
@MainActor
@Observable
final class SessionSyncService: SessionSyncServiceProtocol {

    // MARK: - Dependencies

    private let dataSource: SessionDataSourceProtocol
    private let userId: String

    // MARK: - Observable State

    private(set) var isRefreshing = false
    private(set) var lastRefreshTime: Date?
    private(set) var sessionManagerStatus: SessionManagerConnectionStatus = .disconnected
    private(set) var lastError: String?

    // MARK: - Background Refresh

    private var backgroundRefreshTimer: Timer?
    private let backgroundRefreshInterval: TimeInterval
    private var maxRetryAttempts: Int = 3
    private var currentRetryAttempt: Int = 0
    private var isBackgroundRefreshEnabled = false

    // MARK: - Statistics

    private(set) var refreshCount: Int = 0
    private(set) var errorCount: Int = 0
    private(set) var lastSuccessfulRefresh: Date?

    // MARK: - Initialization

    init(
        dataSource: SessionDataSourceProtocol,
        userId: String = "mobile-user",
        backgroundRefreshInterval: TimeInterval = 60.0
    ) {
        self.dataSource = dataSource
        self.userId = userId
        self.backgroundRefreshInterval = backgroundRefreshInterval
    }

    deinit {
        Task { @MainActor in
            stopBackgroundRefresh()
        }
    }

    // MARK: - SessionSyncServiceProtocol Implementation

    func syncSessionsFromBackend() async throws -> [SessionManagerResponse] {
        return try await refreshSessionsFromBackend()
    }

    func syncSessionToBackend(_ session: SessionManagerResponse) async throws {
        // For now, just validate the session exists
        _ = try await dataSource.getSession(sessionId: session.sessionId, userId: userId)
    }

    func performBackgroundSync() async {
        await performBackgroundRefresh()
    }

    // MARK: - Public Interface

    /// Refresh sessions from backend with error handling
    func refreshSessionsFromBackend() async throws -> [SessionManagerResponse] {
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let sessionListRequest = SessionListRequest(
                userId: userId,
                limit: 50,
                offset: 0,
                statusFilter: nil
            )

            let sessionListResponse = try await dataSource.getSessionsWithManager(sessionListRequest)

            // Convert SessionResponse to SessionManagerResponse
            let sessionManagerResponses = sessionListResponse.sessions.map { sessionResponse in
                convertToSessionManagerResponse(sessionResponse)
            }

            // Update statistics
            refreshCount += 1
            lastSuccessfulRefresh = Date()
            lastRefreshTime = Date()
            currentRetryAttempt = 0
            clearError()

            print("✅ Refreshed \(sessionManagerResponses.count) sessions from SessionManager")
            return sessionManagerResponses

        } catch {
            errorCount += 1
            lastError = "Failed to refresh sessions: \(error.localizedDescription)"
            print("⚠️ Failed to refresh sessions from backend: \(error)")

            // Implement retry logic for certain errors
            if shouldRetry(error: error) && currentRetryAttempt < maxRetryAttempts {
                currentRetryAttempt += 1
                let delay = calculateRetryDelay(attempt: currentRetryAttempt)

                print("🔄 Retrying refresh in \(delay)s (attempt \(currentRetryAttempt)/\(maxRetryAttempts))")
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                return try await refreshSessionsFromBackend()
            }

            throw error
        }
    }

    /// Check SessionManager connection status
    func checkSessionManagerConnectionStatus() async {
        let previousStatus = sessionManagerStatus
        sessionManagerStatus = .connecting

        do {
            // Try to get basic session info to verify connection
            let request = SessionListRequest(
                userId: userId,
                limit: 1,
                offset: 0,
                statusFilter: nil
            )

            let response = try await dataSource.getSessions(request)

            // If successful, SessionManager is connected
            sessionManagerStatus = .connected
            print("✅ SessionManager connected - found \(response.totalCount) total sessions")

            // Reset retry counter on successful connection
            currentRetryAttempt = 0
            clearError()

        } catch {
            sessionManagerStatus = .disconnected
            lastError = "SessionManager connection failed: \(error.localizedDescription)"
            print("⚠️ SessionManager not available: \(error)")

            // If we were previously connected, this might be a temporary issue
            if previousStatus == .connected {
                sessionManagerStatus = .degraded
            }
        }
    }

    /// Get detailed SessionManager health information
    func getSessionManagerHealth() async throws -> SessionManagerHealthResponse {
        do {
            let healthResponse = try await dataSource.getSessionManagerStats()
            sessionManagerStatus = .connected
            return healthResponse
        } catch {
            sessionManagerStatus = .disconnected
            throw error
        }
    }

    // MARK: - Background Refresh Management

    func startBackgroundRefresh() {
        guard !isBackgroundRefreshEnabled else { return }

        isBackgroundRefreshEnabled = true
        scheduleNextRefresh()
        print("🔄 Background session refresh started (interval: \(backgroundRefreshInterval)s)")
    }

    func stopBackgroundRefresh() {
        isBackgroundRefreshEnabled = false
        backgroundRefreshTimer?.invalidate()
        backgroundRefreshTimer = nil
        print("⏹️ Background session refresh stopped")
    }

    private func scheduleNextRefresh() {
        guard isBackgroundRefreshEnabled else { return }

        backgroundRefreshTimer?.invalidate()
        backgroundRefreshTimer = Timer.scheduledTimer(withTimeInterval: backgroundRefreshInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.performBackgroundRefresh()
            }
        }
    }

    private func performBackgroundRefresh() async {
        guard isBackgroundRefreshEnabled else { return }
        guard sessionManagerStatus.isHealthy else {
            // Try to reconnect first
            await checkSessionManagerConnectionStatus()
            scheduleNextRefresh()
            return
        }

        do {
            _ = try await refreshSessionsFromBackend()
        } catch {
            print("⚠️ Background refresh failed: \(error.localizedDescription)")
            // Don't throw error for background operations
        }

        scheduleNextRefresh()
    }

    // MARK: - Error Handling & Retry Logic

    private func shouldRetry(error: Error) -> Bool {
        if let claudeError = error as? ClaudeServiceError {
            switch claudeError {
            case .connectionTimeout, .networkError, .sessionManagerUnavailable:
                return true
            case .invalidURL, .invalidResponse, .sessionNotFound, .serverError, .healthCheckFailed:
                return false
            }
        }

        if let networkError = error as? NetworkError {
            return networkError.isRetryable
        }

        // For unknown errors, don't retry to avoid infinite loops
        return false
    }

    private func calculateRetryDelay(attempt: Int) -> TimeInterval {
        // Exponential backoff: 2^attempt seconds, max 30 seconds
        let delay = min(pow(2.0, Double(attempt)), 30.0)
        return delay
    }

    private func clearError() {
        lastError = nil
    }

    // MARK: - Connection Health Monitoring

    /// Monitor connection health with periodic checks
    func startConnectionMonitoring(interval: TimeInterval = 120.0) {
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkSessionManagerConnectionStatus()
            }
        }
    }

    /// Force reconnection attempt
    func forceReconnection() async {
        print("🔄 Forcing SessionManager reconnection...")
        sessionManagerStatus = .connecting
        await checkSessionManagerConnectionStatus()

        if sessionManagerStatus == .connected {
            // Trigger a refresh to validate the connection
            do {
                _ = try await refreshSessionsFromBackend()
            } catch {
                print("⚠️ Post-reconnection refresh failed: \(error)")
            }
        }
    }

    // MARK: - Statistics & Debugging

    func getSyncStatistics() -> SyncStatistics {
        return SyncStatistics(
            refreshCount: refreshCount,
            errorCount: errorCount,
            lastRefreshTime: lastRefreshTime,
            lastSuccessfulRefresh: lastSuccessfulRefresh,
            currentRetryAttempt: currentRetryAttempt,
            maxRetryAttempts: maxRetryAttempts,
            sessionManagerStatus: sessionManagerStatus,
            isBackgroundRefreshEnabled: isBackgroundRefreshEnabled
        )
    }

    func getDebugInfo() -> String {
        return """
        SessionSyncService Debug:
        - Status: \(sessionManagerStatus.displayName)
        - Background refresh: \(isBackgroundRefreshEnabled ? "enabled" : "disabled")
        - Refresh count: \(refreshCount)
        - Error count: \(errorCount)
        - Current retry attempt: \(currentRetryAttempt)/\(maxRetryAttempts)
        - Last refresh: \(lastRefreshTime?.formatted() ?? "never")
        - Last successful: \(lastSuccessfulRefresh?.formatted() ?? "never")
        - Last error: \(lastError ?? "none")
        """
    }

    // MARK: - Private Helpers

    private func convertToSessionManagerResponse(_ session: SessionResponse) -> SessionManagerResponse {
        // Extract working directory from context dictionary
        let workingDir = extractWorkingDirectory(from: session.context)

        return SessionManagerResponse(
            sessionId: session.sessionId,
            userId: session.userId,
            sessionName: session.sessionName,
            workingDirectory: workingDir,
            status: session.status,
            createdAt: session.createdAt,
            lastActiveAt: session.updatedAt,
            messageCount: session.messageCount,
            conversationHistory: nil,
            sessionManagerStats: nil
        )
    }

    private func extractWorkingDirectory(from context: [String: AnyCodable]) -> String {
        if let value = context["working_directory"] {
            switch value {
            case .string(let dir):
                return dir
            default:
                return "/"
            }
        }
        return "/"
    }
}

// MARK: - Supporting Types

struct SyncStatistics {
    let refreshCount: Int
    let errorCount: Int
    let lastRefreshTime: Date?
    let lastSuccessfulRefresh: Date?
    let currentRetryAttempt: Int
    let maxRetryAttempts: Int
    let sessionManagerStatus: SessionManagerConnectionStatus
    let isBackgroundRefreshEnabled: Bool

    var successRate: Double {
        guard refreshCount > 0 else { return 0.0 }
        let successCount = refreshCount - errorCount
        return Double(successCount) / Double(refreshCount)
    }

    var isHealthy: Bool {
        return sessionManagerStatus.isHealthy && successRate > 0.8
    }
}