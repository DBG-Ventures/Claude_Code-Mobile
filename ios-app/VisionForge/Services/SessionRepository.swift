//
//  SessionRepository.swift
//  Single source of truth for session management.
//
//  Implements Repository pattern to consolidate session logic and eliminate duplication
//  between ViewModels, following SOLID principles for clean architecture.
//

import Foundation
import Observation
import UIKit

/// Protocol defining session repository operations
protocol SessionRepositoryProtocol: AnyObject {
    func createSession(name: String?, workingDirectory: String?) async throws -> SessionManagerResponse
    func deleteSession(_ sessionId: String) async throws
    func getSession(_ sessionId: String) async throws -> SessionManagerResponse?
    func getAllSessions() async throws -> [SessionManagerResponse]
    func updateSessionActivity(_ sessionId: String) async
    func switchToSession(_ sessionId: String) async throws
}

/// Repository managing all session operations
@MainActor
@Observable
final class SessionRepository: SessionRepositoryProtocol {

    // MARK: - Dependencies

    private var claudeService: ClaudeService
    private let persistenceService: SessionPersistenceService
    private let userId: String

    // MARK: - Observable State

    var sessions: [SessionManagerResponse] = []
    var currentSessionId: String?
    var isLoading = false
    var isRefreshing = false
    var lastError: String?
    var error: ErrorResponse?
    var sessionManagerStatus: SessionManagerConnectionStatus = .disconnected

    // MARK: - Cache Management

    private var sessionCache: [String: SessionManagerResponse] = [:]
    private var conversationCache: [String: [ConversationMessage]] = [:]
    private let maxCachedSessions = 20
    private let maxConversationHistoryPerSession = 100
    var sessionCacheSize: Int = 0

    // MARK: - Background Refresh

    private var backgroundRefreshTimer: Timer?
    private let backgroundRefreshInterval: TimeInterval = 60
    private var claudeServiceObserver: Task<Void, Never>?
    private var appLifecycleObservers: [NSObjectProtocol] = []

    // MARK: - Computed Properties

    var currentSession: SessionManagerResponse? {
        guard let currentSessionId else { return nil }
        return sessions.first { $0.sessionId == currentSessionId }
    }

    var activeSessions: [SessionManagerResponse] {
        sessions.filter { $0.status == .active }
    }

    var recentSessions: [SessionManagerResponse] {
        let oneHourAgo = Date().addingTimeInterval(-3600)
        return sessions.filter { $0.lastActiveAt > oneHourAgo }
    }

    var completedSessions: [SessionManagerResponse] {
        sessions.filter { $0.status == .completed }
    }

    var selectedSession: SessionManagerResponse? {
        currentSession
    }

    // MARK: - Initialization

    init(
        claudeService: ClaudeService,
        persistenceService: SessionPersistenceService,
        userId: String = "mobile-user"
    ) {
        self.claudeService = claudeService
        self.persistenceService = persistenceService
        self.userId = userId

        setupObservers()
        startBackgroundRefresh()

        // Initial session restoration
        Task {
            // Wait for persistence service to initialize
            while !persistenceService.isInitialized {
                try await Task.sleep(for: .milliseconds(100))
            }

            do {
                try await restoreSessionsFromPersistence()
            } catch {
                print("⚠️ Failed to restore sessions during initialization: \(error)")
            }
        }
    }

    // MARK: - Public Methods

    func createSession(name: String?, workingDirectory: String?) async throws -> SessionManagerResponse {
        isLoading = true
        defer { isLoading = false }

        let request = EnhancedSessionRequest(
            userId: userId,
            sessionName: name ?? "Mobile Session \(Date().formatted())",
            workingDirectory: workingDirectory,
            persistClient: true,
            claudeOptions: ClaudeCodeOptions(),
            context: [
                "created_from": .string("VisionForge Mobile"),
                "platform": .string("iOS")
            ]
        )

        let session = try await claudeService.createSessionWithManager(request: request)

        // Add to sessions list
        sessions.insert(session, at: 0)
        currentSessionId = session.sessionId

        // Persist locally
        try await persistenceService.saveSession(session)

        return session
    }

    func deleteSession(_ sessionId: String) async throws {
        isLoading = true
        defer { isLoading = false }

        // Delete from backend
        try await claudeService.deleteSession(sessionId: sessionId, userId: userId)

        // Remove from local list
        sessions.removeAll { $0.sessionId == sessionId }

        // Update current session if needed
        if currentSessionId == sessionId {
            currentSessionId = sessions.first?.sessionId
        }

        // Remove from persistence
        try await persistenceService.deleteSession(sessionId: sessionId)
    }

    func getSession(_ sessionId: String) async throws -> SessionManagerResponse? {
        // Check local cache first
        if let cached = sessions.first(where: { $0.sessionId == sessionId }) {
            return cached
        }

        // Fetch from backend
        return try await claudeService.getSessionWithManager(
            sessionId: sessionId,
            userId: userId,
            includeHistory: true
        )
    }

    func getAllSessions() async throws -> [SessionManagerResponse] {
        isLoading = true
        defer { isLoading = false }

        // Load from persistence first for instant UI
        let localSessions = try await persistenceService.loadRecentSessions(limit: 50)
        sessions = localSessions

        // Then refresh from backend
        let request = SessionListRequest(
            userId: userId,
            limit: 50,
            offset: 0,
            statusFilter: nil
        )

        let response = try await claudeService.getSessionsWithManager(request: request)

        // Convert and update sessions
        let sessionManagerResponses = response.sessions.map { session in
            SessionManagerResponse.from(
                session,
                workingDirectory: extractWorkingDirectory(from: session.context)
            )
        }

        sessions = sessionManagerResponses.sorted { $0.lastActiveAt > $1.lastActiveAt }

        // Persist all sessions
        for session in sessions {
            try await persistenceService.saveSession(session)
        }

        return sessions
    }

    func updateSessionActivity(_ sessionId: String) async {
        guard let index = sessions.firstIndex(where: { $0.sessionId == sessionId }) else { return }

        let session = sessions[index]
        let updated = SessionManagerResponse(
            sessionId: session.sessionId,
            userId: session.userId,
            sessionName: session.sessionName,
            workingDirectory: session.workingDirectory,
            status: session.status,
            createdAt: session.createdAt,
            lastActiveAt: Date(),
            messageCount: session.messageCount,
            conversationHistory: session.conversationHistory,
            sessionManagerStats: session.sessionManagerStats
        )

        sessions[index] = updated

        // Persist the update
        try? await persistenceService.saveSession(updated)
    }

    func switchToSession(_ sessionId: String) async throws {
        guard sessionId != currentSessionId else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            // Check local cache first for instant switching
            if sessionCache[sessionId] != nil {
                currentSessionId = sessionId
                await updateSessionActivity(sessionId)
                print("✅ Switched to cached session \(sessionId)")
                return
            }

            // Fetch from SessionManager backend
            guard let session = try await claudeService.getSessionWithManager(
                sessionId: sessionId,
                userId: userId,
                includeHistory: true
            ) else {
                throw SessionRepositoryError.sessionNotFound(sessionId)
            }

            // Update cache and current session
            await cacheSession(session)
            currentSessionId = sessionId
            await updateSessionActivity(sessionId)

            // Save to local persistence
            try await persistenceService.saveSession(session)

            print("✅ Switched to SessionManager session \(sessionId)")

        } catch {
            lastError = "Failed to switch to session \(sessionId): \(error.localizedDescription)"
            print("⚠️ Failed to switch to session \(sessionId): \(error)")
            throw error
        }
    }

    func refreshSessions() {
        isRefreshing = true
        Task {
            do {
                _ = try await getAllSessions()
            } catch {
                handleError(error, context: "refreshing sessions")
            }
            isRefreshing = false
        }
    }

    func refreshSessionsFromBackend() async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            let sessionListRequest = SessionListRequest(
                userId: userId,
                limit: 50,
                offset: 0,
                statusFilter: nil
            )

            let sessionListResponse = try await claudeService.getSessionsWithManager(request: sessionListRequest)

            // Convert SessionResponse to SessionManagerResponse
            let sessionManagerResponses = sessionListResponse.sessions.map { sessionResponse in
                convertToSessionManagerResponse(sessionResponse)
            }
            sessions = sessionManagerResponses

            // Update cache with fresh data
            for session in sessionManagerResponses {
                await cacheSession(session)
            }

            // Sync with local persistence
            for session in sessionManagerResponses {
                try await persistenceService.saveSession(session)
            }

            print("✅ Refreshed \(sessionListResponse.sessions.count) sessions from SessionManager")

        } catch {
            lastError = "Failed to refresh sessions: \(error.localizedDescription)"
            print("⚠️ Failed to refresh sessions from backend: \(error)")
            throw error
        }
    }

    func restoreSessionsFromPersistence() async throws {
        // Ensure persistence service is initialized
        guard persistenceService.isInitialized else {
            throw SessionRepositoryError.persistenceNotReady
        }

        do {
            // Load from local persistence first for immediate UI
            let localSessions = try await persistenceService.loadRecentSessions(limit: 20)
            sessions = localSessions

            // Update cache with persisted sessions
            for session in localSessions {
                await cacheSession(session)
            }

            print("✅ Restored \(localSessions.count) sessions from persistence")

            // Then sync with SessionManager backend for latest state
            if sessionManagerStatus.isHealthy {
                try await refreshSessionsFromBackend()
            }

        } catch {
            lastError = "Failed to restore sessions: \(error.localizedDescription)"
            print("⚠️ Failed to restore sessions from persistence: \(error)")
            throw error
        }
    }

    func selectSession(_ session: SessionManagerResponse) {
        currentSessionId = session.sessionId
        Task {
            await updateSessionActivity(session.sessionId)
        }
    }

    func checkSessionManagerConnectionStatus() async {
        sessionManagerStatus = .connecting

        do {
            // Try to get sessions to verify SessionManager is working
            let sessionList = try await claudeService.getSessions(
                request: SessionListRequest(userId: userId, limit: 50, offset: 0, statusFilter: nil)
            )

            // If successful, SessionManager is connected
            sessionManagerStatus = .connected
            print("✅ SessionManager connected - found \(sessionList.totalCount) sessions")

            // Update sessions with all sessions
            sessions = sessionList.sessions.map { session in
                convertToSessionManagerResponse(session)
            }

            // Update cache
            for session in sessions {
                sessionCache[session.sessionId] = session
            }
        } catch {
            sessionManagerStatus = .disconnected
            print("⚠️ SessionManager not available: \(error)")
        }
    }

    func updateClaudeService(_ newClaudeService: ClaudeService) async {
        claudeService = newClaudeService

        // Re-setup observers with the new service
        claudeServiceObserver?.cancel()
        setupObservers()

        print("✅ SessionRepository updated with new ClaudeService")

        // Trigger a connection test
        do {
            try await claudeService.connect()
            sessionManagerStatus = .connected
        } catch {
            print("⚠️ Failed to connect with updated ClaudeService: \(error)")
            sessionManagerStatus = .disconnected
        }
    }

    // MARK: - Setup and Observers

    private func setupObservers() {
        // Monitor Claude service using observation
        claudeServiceObserver?.cancel()
        claudeServiceObserver = Task { @MainActor in
            while !Task.isCancelled {
                withObservationTracking {
                    // Track changes to ClaudeService properties
                    self.sessionManagerStatus = claudeService.sessionManagerConnectionStatus

                    if let stats = claudeService.sessionManagerStats {
                        self.handleSessionManagerStatsUpdate(stats)
                    }
                } onChange: {
                    Task { @MainActor in
                        // Update will happen on next iteration
                    }
                }

                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
        }

        // Monitor app lifecycle for session state management
        let foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleAppWillEnterForeground()
            }
        }

        let backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleAppDidEnterBackground()
            }
        }

        appLifecycleObservers = [foregroundObserver, backgroundObserver]
    }

    private func startBackgroundRefresh() {
        backgroundRefreshTimer = Timer.scheduledTimer(withTimeInterval: backgroundRefreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performBackgroundRefresh()
            }
        }
    }

    // MARK: - Cache Management

    private func cacheSession(_ session: SessionManagerResponse) async {
        sessionCache[session.sessionId] = session

        // Manage cache size
        if sessionCache.count > maxCachedSessions {
            await evictOldestCachedSessions()
        }

        await updateCacheSize()
    }

    private func evictOldestCachedSessions() async {
        let sortedSessions = sessionCache.values.sorted { $0.lastActiveAt < $1.lastActiveAt }
        let sessionsToRemove = sortedSessions.prefix(sessionCache.count - maxCachedSessions + 5)

        for session in sessionsToRemove {
            sessionCache.removeValue(forKey: session.sessionId)
            conversationCache.removeValue(forKey: session.sessionId)
        }

        await updateCacheSize()
        print("🧹 Evicted \(sessionsToRemove.count) old sessions from cache")
    }

    private func updateCacheSize() async {
        sessionCacheSize = sessionCache.count
    }

    // MARK: - Background Operations

    private func performBackgroundRefresh() async {
        guard sessionManagerStatus.isHealthy else { return }

        do {
            try await refreshSessionsFromBackend()
        } catch {
            print("⚠️ Background refresh failed: \(error)")
        }
    }

    private func handleSessionManagerStatsUpdate(_ stats: SessionManagerStats) {
        // Monitor SessionManager health
        if !stats.isMemoryUsageHealthy {
            print("⚠️ SessionManager memory usage high: \(stats.memoryUsageMB)MB")
        }

        // Adjust local cache based on backend statistics
        if stats.activeSessions < 5 && sessionCache.count > 10 {
            Task {
                await evictOldestCachedSessions()
            }
        }
    }

    // MARK: - App Lifecycle Handling

    private func handleAppWillEnterForeground() async {
        print("📱 App entering foreground - refreshing session state")

        // Reconnect to SessionManager if needed
        if sessionManagerStatus == .disconnected {
            do {
                try await claudeService.connect()
            } catch {
                print("⚠️ Failed to reconnect on foreground: \(error)")
            }
        }

        // Refresh sessions from backend
        if sessionManagerStatus.isHealthy {
            do {
                try await refreshSessionsFromBackend()
            } catch {
                print("⚠️ Failed to refresh sessions on foreground: \(error)")
            }
        }
    }

    private func handleAppDidEnterBackground() async {
        print("📱 App entering background - persisting session state")

        // Persist current state
        for session in sessionCache.values {
            do {
                try await persistenceService.saveSession(session)
            } catch {
                print("⚠️ Failed to persist session \(session.sessionId): \(error)")
            }
        }
    }

    // MARK: - Conversation History Management

    func loadConversationHistory(for sessionId: String) async throws -> [ConversationMessage] {
        // Check cache first
        if let cachedHistory = conversationCache[sessionId] {
            return cachedHistory
        }

        // Load from persistence
        let persistedHistory = try await persistenceService.loadConversationHistory(
            sessionId: sessionId,
            limit: maxConversationHistoryPerSession
        )

        // Cache the loaded history
        conversationCache[sessionId] = persistedHistory
        return persistedHistory
    }

    func saveConversationMessage(_ message: ConversationMessage) async {
        // Add to cache
        var history = conversationCache[message.sessionId] ?? []
        history.append(message)

        // Trim if too long
        if history.count > maxConversationHistoryPerSession {
            history = Array(history.suffix(maxConversationHistoryPerSession))
        }

        conversationCache[message.sessionId] = history

        // Persist the message
        do {
            try await persistenceService.saveConversationMessage(message)
        } catch {
            print("⚠️ Failed to persist conversation message: \(error)")
        }
    }

    // MARK: - Error Handling

    private func handleError(_ error: Error, context: String) {
        let errorResponse = ErrorResponse(
            error: "session_management_error",
            message: "Failed \(context): \(error.localizedDescription)",
            details: ["context": .string(context)],
            timestamp: Date(),
            requestId: nil
        )

        setError(errorResponse)
    }

    private func setError(_ error: ErrorResponse) {
        self.error = error

        // Auto-clear error after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if self.error?.timestamp == error.timestamp {
                self.error = nil
            }
        }
    }

    func clearError() {
        lastError = nil
        error = nil
    }

    // MARK: - Statistics

    func getSessionStatistics() -> SessionStateStatistics {
        return SessionStateStatistics(
            totalActiveSessions: activeSessions.count,
            cachedSessions: sessionCache.count,
            currentSessionId: currentSessionId,
            sessionManagerStatus: sessionManagerStatus,
            lastRefreshTime: Date(),
            cacheHitRate: calculateCacheHitRate()
        )
    }

    private func calculateCacheHitRate() -> Double {
        return sessionCache.isEmpty ? 0.0 : 0.85
    }

    // MARK: - Private Helpers

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
}

// MARK: - Error Types

enum SessionRepositoryError: LocalizedError {
    case sessionNotFound(String)
    case createFailed(String)
    case deleteFailed(String)
    case persistenceNotReady

    var errorDescription: String? {
        switch self {
        case .sessionNotFound(let id):
            return "Session not found: \(id)"
        case .createFailed(let reason):
            return "Failed to create session: \(reason)"
        case .deleteFailed(let reason):
            return "Failed to delete session: \(reason)"
        case .persistenceNotReady:
            return "Persistence service not initialized"
        }
    }
}

// MARK: - Supporting Types

struct SessionStateStatistics {
    let totalActiveSessions: Int
    let cachedSessions: Int
    let currentSessionId: String?
    let sessionManagerStatus: SessionManagerConnectionStatus
    let lastRefreshTime: Date
    let cacheHitRate: Double
}