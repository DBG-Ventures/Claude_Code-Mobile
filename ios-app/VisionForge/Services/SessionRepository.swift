//
//  SessionRepository.swift
//  Single source of truth for session management.
//
//  Implements Repository pattern to consolidate session logic and eliminate duplication
//  between ViewModels, following SOLID principles for clean architecture.
//

import Foundation
import Observation

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

    private let claudeService: ClaudeService
    private let persistenceService: SessionPersistenceService
    private let userId: String

    // MARK: - Observable State

    var sessions: [SessionManagerResponse] = []
    var currentSessionId: String?
    var isLoading = false
    var lastError: String?

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

    // MARK: - Initialization

    init(
        claudeService: ClaudeService,
        persistenceService: SessionPersistenceService,
        userId: String = "mobile-user"
    ) {
        self.claudeService = claudeService
        self.persistenceService = persistenceService
        self.userId = userId
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

        // Ensure session exists
        guard let session = try await getSession(sessionId) else {
            throw SessionRepositoryError.sessionNotFound(sessionId)
        }

        currentSessionId = sessionId
        await updateSessionActivity(sessionId)

        // Update in sessions list if not present
        if !sessions.contains(where: { $0.sessionId == sessionId }) {
            sessions.append(session)
        }
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
}

// MARK: - Error Types

enum SessionRepositoryError: LocalizedError {
    case sessionNotFound(String)
    case createFailed(String)
    case deleteFailed(String)

    var errorDescription: String? {
        switch self {
        case .sessionNotFound(let id):
            return "Session not found: \(id)"
        case .createFailed(let reason):
            return "Failed to create session: \(reason)"
        case .deleteFailed(let reason):
            return "Failed to delete session: \(reason)"
        }
    }
}