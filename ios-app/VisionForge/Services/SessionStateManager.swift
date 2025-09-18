//
//  SessionStateManager.swift
//  SwiftUI session state coordination and caching.
//
//  Manages session state coordination, caching, and optimization for the VisionForge app
//  with SessionManager backend integration and persistent session management.
//

import SwiftUI
import Observation
import Foundation

// MARK: - Session State Manager Protocol

protocol SessionStateManagerProtocol: AnyObject {
    var activeSessions: [SessionManagerResponse] { get }
    var currentSessionId: String? { get }
    var sessionManagerStatus: SessionManagerConnectionStatus { get }
    var isLoading: Bool { get }
    var sessionCache: [String: SessionManagerResponse] { get }

    func switchToSession(_ sessionId: String) async throws
    func createNewSession(name: String?, workingDirectory: String?) async throws -> SessionManagerResponse
    func refreshSessionsFromBackend() async throws
    func restoreSessionsFromPersistence() async throws
    func deleteSession(_ sessionId: String) async throws
    func getSession(_ sessionId: String) -> SessionManagerResponse?
    func updateSessionLastActive(_ sessionId: String) async
}

// MARK: - Session State Manager Implementation

@MainActor
@Observable
class SessionStateManager: SessionStateManagerProtocol {

    // MARK: - Observable Properties

    var activeSessions: [SessionManagerResponse] = []
    var currentSessionId: String?
    var sessionManagerStatus: SessionManagerConnectionStatus = .disconnected
    var isLoading: Bool = false
    var lastError: String?
    var sessionCacheSize: Int = 0

    // MARK: - Internal Properties

    internal var sessionCache: [String: SessionManagerResponse] = [:]
    private var conversationCache: [String: [ConversationMessage]] = [:]

    // MARK: - Private Properties

    private var claudeService: ClaudeService
    private let persistenceService: SessionPersistenceService
    private var claudeServiceObserver: Task<Void, Never>?
    private var appLifecycleObservers: [NSObjectProtocol] = []

    // Configuration
    private let maxCachedSessions = 20
    private let maxConversationHistoryPerSession = 100
    private let cacheExpirationInterval: TimeInterval = 300 // 5 minutes
    private let userId: String

    // Background refresh management
    private var backgroundRefreshTimer: Timer?
    private let backgroundRefreshInterval: TimeInterval = 60 // 1 minute

    // MARK: - Initialization

    init(claudeService: ClaudeService, persistenceService: SessionPersistenceService, userId: String = "mobile-user") {
        self.claudeService = claudeService
        self.persistenceService = persistenceService
        self.userId = userId

        setupObservers()
        startBackgroundRefresh()

        // Initial session restoration - wait for persistence service to initialize
        Task {
            // Wait for persistence service to initialize CoreData
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

    // Cleanup handled through proper lifecycle management

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

    // MARK: - Session Management

    func switchToSession(_ sessionId: String) async throws {
        guard sessionId != currentSessionId else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            // Check local cache first for instant switching
            if sessionCache[sessionId] != nil {
                currentSessionId = sessionId
                await updateSessionLastActive(sessionId)
                print("✅ Switched to cached session \(sessionId)")
                return
            }

            // Fetch from SessionManager backend (should be instant due to persistent clients)
            guard let session = try await claudeService.getSessionWithManager(
                sessionId: sessionId,
                userId: userId,
                includeHistory: true
            ) else {
                throw SessionStateError.sessionNotFound(sessionId)
            }

            // Update cache and current session
            await cacheSession(session)
            currentSessionId = sessionId
            await updateSessionLastActive(sessionId)

            // Save to local persistence for offline access
            try await persistenceService.saveSession(session)

            print("✅ Switched to SessionManager session \(sessionId)")

        } catch {
            lastError = "Failed to switch to session \(sessionId): \(error.localizedDescription)"
            print("⚠️ Failed to switch to session \(sessionId): \(error)")
            throw error
        }
    }

    func createNewSession(name: String? = nil, workingDirectory: String? = nil) async throws -> SessionManagerResponse {
        print("🔍 SessionStateManager: createNewSession called with name: \(name ?? "nil"), workingDirectory: \(workingDirectory ?? "nil")")
        isLoading = true
        defer { isLoading = false }

        do {
            let enhancedRequest = EnhancedSessionRequest(
                userId: userId,
                sessionName: name ?? "Mobile Session \(Date().formatted(date: .abbreviated, time: .shortened))",
                workingDirectory: workingDirectory,
                persistClient: true,
                claudeOptions: ClaudeCodeOptions(),
                context: [
                    "created_from": .string("VisionForge Mobile"),
                    "created_at": .string(Date().ISO8601Format())
                ]
            )

            print("🔍 SessionStateManager: Calling claudeService.createSessionWithManager with request...")
            let session = try await claudeService.createSessionWithManager(request: enhancedRequest)
            print("🔍 SessionStateManager: Received session response: \(session.sessionId)")

            // Add to cache and session list
            await cacheSession(session)
            activeSessions.insert(session, at: 0) // Add to beginning for recency

            // Save to persistence
            try await persistenceService.saveSession(session)

            // Auto-switch to new session
            currentSessionId = session.sessionId

            print("✅ Created new SessionManager session: \(session.sessionId)")
            return session

        } catch {
            lastError = "Failed to create session: \(error.localizedDescription)"
            print("⚠️ Failed to create session: \(error)")
            throw error
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
            activeSessions = sessionManagerResponses

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
        // Ensure persistence service is initialized before attempting operations
        guard persistenceService.isInitialized else {
            throw SessionStateError.persistenceError(SessionPersistenceError.coreDataNotInitialized)
        }

        do {
            // Load from local persistence first for immediate UI
            let localSessions = try await persistenceService.loadRecentSessions(limit: 20)
            activeSessions = localSessions

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

    func deleteSession(_ sessionId: String) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            // Delete from backend first
            try await claudeService.deleteSession(sessionId: sessionId, userId: userId)

            // Remove from cache
            sessionCache.removeValue(forKey: sessionId)
            conversationCache.removeValue(forKey: sessionId)

            // Remove from session list
            activeSessions.removeAll { $0.sessionId == sessionId }

            // Remove from persistence
            try await persistenceService.deleteSession(sessionId: sessionId)

            // Switch to another session if current was deleted
            if currentSessionId == sessionId {
                currentSessionId = activeSessions.first?.sessionId
            }

            await updateCacheSize()
            print("✅ Deleted session \(sessionId)")

        } catch {
            lastError = "Failed to delete session: \(error.localizedDescription)"
            print("⚠️ Failed to delete session \(sessionId): \(error)")
            throw error
        }
    }

    func getSession(_ sessionId: String) -> SessionManagerResponse? {
        return sessionCache[sessionId]
    }

    func updateSessionLastActive(_ sessionId: String) async {
        // Update in cache
        if let session = sessionCache[sessionId] {
            let updatedSession = SessionManagerResponse(
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
            await cacheSession(updatedSession)

            // Update in session list
            if let index = activeSessions.firstIndex(where: { $0.sessionId == sessionId }) {
                activeSessions[index] = updatedSession
            }

            // Persist the update
            do {
                try await persistenceService.saveSession(updatedSession)
            } catch {
                print("⚠️ Failed to persist session update: \(error)")
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
        let sessionsToRemove = sortedSessions.prefix(sessionCache.count - maxCachedSessions + 5) // Remove extra for efficiency

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
            // Lightweight refresh - just check for new sessions
            try await refreshSessionsFromBackend()
        } catch {
            print("⚠️ Background refresh failed: \(error)")
        }
    }

    private func handleSessionManagerStatsUpdate(_ stats: SessionManagerStats) {
        // Monitor SessionManager health and respond accordingly
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

    // MARK: - Connection Status Management

    func checkSessionManagerConnectionStatus() async {
        // Check SessionManager health/connection status
        sessionManagerStatus = .connecting

        do {
            // Try to get ALL sessions to verify SessionManager is working and populate the list
            let sessionList = try await claudeService.getSessions(
                request: SessionListRequest(userId: userId, limit: 50, offset: 0, statusFilter: nil)
            )

            // If we successfully get a response, SessionManager is connected
            sessionManagerStatus = .connected
            print("✅ SessionManager connected - found \(sessionList.totalCount) sessions")

            // Update activeSessions with all sessions
            activeSessions = sessionList.sessions.map { session in
                convertToSessionManagerResponse(session)
            }

            // Also update the session cache
            for session in activeSessions {
                sessionCache[session.sessionId] = session
            }
        } catch {
            // If we get an error, SessionManager is not available
            sessionManagerStatus = .disconnected
            print("⚠️ SessionManager not available: \(error)")
        }
    }

    private func convertToSessionManagerResponse(_ session: SessionResponse) -> SessionManagerResponse {
        // Extract working directory from context dictionary
        let workingDir: String
        if let contextValue = session.context["working_directory"] {
            // AnyCodable is an enum, extract the string case
            switch contextValue {
            case .string(let value):
                workingDir = value
            default:
                workingDir = "/"
            }
        } else {
            workingDir = "/"
        }

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


    // MARK: - Service Updates

    func updateClaudeService(_ newClaudeService: ClaudeService) async {
        claudeService = newClaudeService

        // Re-setup observers with the new service
        claudeServiceObserver?.cancel()
        setupObservers()

        print("✅ SessionStateManager updated with new ClaudeService")

        // Trigger a connection test
        do {
            try await claudeService.connect()
            sessionManagerStatus = .connected
        } catch {
            print("⚠️ Failed to connect with updated ClaudeService: \(error)")
            sessionManagerStatus = .disconnected
        }
    }

    // MARK: - Error Handling

    func clearError() {
        lastError = nil
    }

    // MARK: - Statistics and Monitoring

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
        // Simplified cache hit rate calculation
        // In a real implementation, you'd track cache hits vs misses
        return sessionCache.isEmpty ? 0.0 : 0.85 // Estimate 85% hit rate
    }
}

// MARK: - Supporting Types

enum SessionStateError: LocalizedError {
    case sessionNotFound(String)
    case cacheError(String)
    case persistenceError(Error)
    case sessionManagerUnavailable

    var errorDescription: String? {
        switch self {
        case .sessionNotFound(let sessionId):
            return "Session not found: \(sessionId)"
        case .cacheError(let message):
            return "Cache error: \(message)"
        case .persistenceError(let error):
            return "Persistence error: \(error.localizedDescription)"
        case .sessionManagerUnavailable:
            return "SessionManager service unavailable"
        }
    }
}

struct SessionStateStatistics {
    let totalActiveSessions: Int
    let cachedSessions: Int
    let currentSessionId: String?
    let sessionManagerStatus: SessionManagerConnectionStatus
    let lastRefreshTime: Date
    let cacheHitRate: Double
}

// MARK: - Preview Support

extension SessionStateManager {
    static func preview() -> SessionStateManager {
        let mockClaudeService = ClaudeService(baseURL: URL(string: "http://localhost:8000")!)
        let mockPersistenceService = SessionPersistenceService()
        return SessionStateManager(
            claudeService: mockClaudeService,
            persistenceService: mockPersistenceService,
            userId: "preview-user"
        )
    }
}
