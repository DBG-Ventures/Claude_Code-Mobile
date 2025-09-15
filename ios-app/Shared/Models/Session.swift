"""
Session.swift - Session management models for Claude Code mobile client.

Session-related data models that provide multi-session management capabilities
matching the FastAPI backend schema for consistent data handling.
"""

import Foundation

// MARK: - Session Models

/// Core Session model for SwiftUI app state management
/// Based on backend SessionResponse but optimized for mobile UI
struct Session: Identifiable, Codable, Hashable {
    let id: String
    let userId: String
    let name: String
    let status: SessionStatus
    var messages: [ClaudeMessage]
    let createdAt: Date
    var updatedAt: Date
    var messageCount: Int
    let context: [String: AnyCodable]

    /// Computed property for last message timestamp
    var lastMessageTime: Date {
        messages.last?.timestamp ?? updatedAt
    }

    /// Computed property for display name with fallback
    var displayName: String {
        if name.isEmpty {
            return "Session \(id.prefix(8))"
        }
        return name
    }

    /// Computed property for preview text
    var previewText: String {
        if let lastMessage = messages.last {
            let prefix = lastMessage.role == .user ? "You: " : "Claude: "
            return prefix + String(lastMessage.content.prefix(50)) + (lastMessage.content.count > 50 ? "..." : "")
        }
        return "No messages"
    }

    init(id: String, userId: String, name: String, status: SessionStatus = .active, messages: [ClaudeMessage] = [], createdAt: Date = Date(), updatedAt: Date = Date(), messageCount: Int = 0, context: [String: AnyCodable] = [:]) {
        self.id = id
        self.userId = userId
        self.name = name
        self.status = status
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messageCount = messageCount
        self.context = context
    }

    /// Create Session from SessionResponse
    init(from response: SessionResponse) {
        self.id = response.sessionId
        self.userId = response.userId
        self.name = response.sessionName ?? ""
        self.status = response.status
        self.messages = response.messages
        self.createdAt = response.createdAt
        self.updatedAt = response.updatedAt
        self.messageCount = response.messageCount
        self.context = response.context
    }

    /// Add message to session
    mutating func addMessage(_ message: ClaudeMessage) {
        messages.append(message)
        updatedAt = Date()
        messageCount = messages.count
    }

    /// Update session status
    mutating func updateStatus(_ newStatus: SessionStatus) {
        status = newStatus
        updatedAt = Date()
    }
}

/// Session list response wrapper
/// Matches backend SessionListResponse Pydantic model exactly
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

/// Request to list user sessions
/// Matches backend SessionListRequest Pydantic model exactly
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

    init(userId: String, limit: Int = 10, offset: Int = 0, statusFilter: String? = nil) {
        self.userId = userId
        self.limit = min(max(limit, 1), 100) // Clamp between 1-100
        self.offset = max(offset, 0) // Ensure non-negative
        self.statusFilter = statusFilter
    }
}

/// Request to update session properties
/// Matches backend SessionUpdateRequest Pydantic model exactly
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

    init(sessionId: String, userId: String, sessionName: String? = nil, status: String? = nil, context: [String: AnyCodable]? = nil) {
        self.sessionId = sessionId
        self.userId = userId
        self.sessionName = sessionName
        self.status = status
        self.context = context
    }
}

// MARK: - Session State Management

/// Session manager state for handling multiple concurrent sessions
/// Provides observable state management for SwiftUI views
@MainActor
class SessionManager: ObservableObject {
    @Published var sessions: [Session] = []
    @Published var activeSession: Session?
    @Published var isLoading = false
    @Published var error: ErrorResponse?

    private let maxSessions = 10 // Concurrent session limit per PRP requirements

    /// Add new session to manager
    func addSession(_ session: Session) {
        // Remove oldest session if at limit
        if sessions.count >= maxSessions {
            sessions.removeFirst()
        }

        sessions.append(session)
        activeSession = session

        // Sort by last update time (most recent first)
        sessions.sort { $0.lastMessageTime > $1.lastMessageTime }
    }

    /// Update existing session
    func updateSession(_ updatedSession: Session) {
        if let index = sessions.firstIndex(where: { $0.id == updatedSession.id }) {
            sessions[index] = updatedSession
        }

        // Update active session if it matches
        if activeSession?.id == updatedSession.id {
            activeSession = updatedSession
        }

        // Re-sort by last update time
        sessions.sort { $0.lastMessageTime > $1.lastMessageTime }
    }

    /// Remove session from manager
    func removeSession(withId sessionId: String) {
        sessions.removeAll { $0.id == sessionId }

        // Clear active session if it was removed
        if activeSession?.id == sessionId {
            activeSession = sessions.first
        }
    }

    /// Set active session
    func setActiveSession(_ session: Session) {
        activeSession = session
    }

    /// Add message to active session
    func addMessageToActiveSession(_ message: ClaudeMessage) {
        guard var session = activeSession else { return }

        session.addMessage(message)
        updateSession(session)
    }

    /// Get session by ID
    func getSession(withId sessionId: String) -> Session? {
        return sessions.first { $0.id == sessionId }
    }

    /// Clear all sessions
    func clearAllSessions() {
        sessions.removeAll()
        activeSession = nil
    }

    /// Set loading state
    func setLoading(_ loading: Bool) {
        isLoading = loading
    }

    /// Set error state
    func setError(_ error: ErrorResponse?) {
        self.error = error
    }
}

// MARK: - Session Persistence

/// Session storage manager for persistence across app launches
actor SessionStorage {
    private let userDefaults = UserDefaults.standard
    private let sessionsKey = "claude_sessions"
    private let activeSessionKey = "active_session_id"

    /// Save sessions to persistent storage
    func saveSessions(_ sessions: [Session]) throws {
        let data = try JSONEncoder().encode(sessions)
        userDefaults.set(data, forKey: sessionsKey)
    }

    /// Load sessions from persistent storage
    func loadSessions() throws -> [Session] {
        guard let data = userDefaults.data(forKey: sessionsKey) else {
            return []
        }

        return try JSONDecoder().decode([Session].self, from: data)
    }

    /// Save active session ID
    func saveActiveSessionId(_ sessionId: String?) {
        if let sessionId = sessionId {
            userDefaults.set(sessionId, forKey: activeSessionKey)
        } else {
            userDefaults.removeObject(forKey: activeSessionKey)
        }
    }

    /// Load active session ID
    func loadActiveSessionId() -> String? {
        return userDefaults.string(forKey: activeSessionKey)
    }

    /// Clear all stored sessions
    func clearStoredSessions() {
        userDefaults.removeObject(forKey: sessionsKey)
        userDefaults.removeObject(forKey: activeSessionKey)
    }
}