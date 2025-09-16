//
//  SessionManagerModels.swift
//  Enhanced data models for SessionManager integration.
//
//  SessionManager-specific models for persistent session management, conversation history,
//  and enhanced session statistics with SwiftUI integration patterns.
//

import Foundation

// MARK: - SessionManager Response Models

/// SessionManager response with enhanced session metadata and conversation history
/// Matches backend SessionManager response structure with persistent client information
struct SessionManagerResponse: Identifiable, Codable, Hashable {
    let sessionId: String
    let userId: String
    let sessionName: String?
    let workingDirectory: String
    let status: SessionStatus
    let createdAt: Date
    let lastActiveAt: Date
    let messageCount: Int
    let conversationHistory: [ConversationMessage]?
    let sessionManagerStats: SessionManagerStats?

    var id: String { sessionId }

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case userId = "user_id"
        case sessionName = "session_name"
        case workingDirectory = "working_directory"
        case status
        case createdAt = "created_at"
        case lastActiveAt = "last_active_at"
        case messageCount = "message_count"
        case conversationHistory = "conversation_history"
        case sessionManagerStats = "session_manager_stats"
    }

    init(sessionId: String, userId: String, sessionName: String? = nil,
         workingDirectory: String, status: SessionStatus = .active,
         createdAt: Date = Date(), lastActiveAt: Date = Date(),
         messageCount: Int = 0, conversationHistory: [ConversationMessage]? = nil,
         sessionManagerStats: SessionManagerStats? = nil) {
        self.sessionId = sessionId
        self.userId = userId
        self.sessionName = sessionName
        self.workingDirectory = workingDirectory
        self.status = status
        self.createdAt = createdAt
        self.lastActiveAt = lastActiveAt
        self.messageCount = messageCount
        self.conversationHistory = conversationHistory
        self.sessionManagerStats = sessionManagerStats
    }
}

/// Enhanced conversation message with SessionManager context and metadata
/// Supports session metadata and conversation continuity across app launches
struct ConversationMessage: Identifiable, Codable, Hashable {
    let id: String
    let role: MessageRole
    let content: String
    let timestamp: Date
    let sessionId: String
    let messageId: String?
    let sessionManagerContext: [String: AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case id
        case role
        case content
        case timestamp
        case sessionId = "session_id"
        case messageId = "message_id"
        case sessionManagerContext = "session_manager_context"
    }

    init(id: String, role: MessageRole, content: String, timestamp: Date = Date(),
         sessionId: String, messageId: String? = nil,
         sessionManagerContext: [String: AnyCodable]? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.messageId = messageId
        self.sessionManagerContext = sessionManagerContext
    }

    /// Convert to ClaudeMessage for backwards compatibility
    func toClaudeMessage() -> ClaudeMessage {
        return ClaudeMessage(
            id: id,
            content: content,
            role: role,
            timestamp: timestamp,
            sessionId: sessionId,
            metadata: sessionManagerContext
        )
    }

    /// Create from ClaudeMessage
    static func from(_ claudeMessage: ClaudeMessage, messageId: String? = nil) -> ConversationMessage {
        return ConversationMessage(
            id: claudeMessage.id,
            role: claudeMessage.role,
            content: claudeMessage.content,
            timestamp: claudeMessage.timestamp,
            sessionId: claudeMessage.sessionId,
            messageId: messageId,
            sessionManagerContext: claudeMessage.metadata
        )
    }
}

/// SessionManager statistics for monitoring and debugging
/// Provides real-time information about session manager health and performance
struct SessionManagerStats: Codable, Hashable {
    let activeSessions: Int
    let totalSessionsCreated: Int
    let memoryUsageMB: Float
    let cleanupLastRun: Date
    let sessionTimeoutSeconds: Int

    enum CodingKeys: String, CodingKey {
        case activeSessions = "active_sessions"
        case totalSessionsCreated = "total_sessions_created"
        case memoryUsageMB = "memory_usage_mb"
        case cleanupLastRun = "cleanup_last_run"
        case sessionTimeoutSeconds = "session_timeout_seconds"
    }

    init(activeSessions: Int, totalSessionsCreated: Int, memoryUsageMB: Float,
         cleanupLastRun: Date, sessionTimeoutSeconds: Int) {
        self.activeSessions = activeSessions
        self.totalSessionsCreated = totalSessionsCreated
        self.memoryUsageMB = memoryUsageMB
        self.cleanupLastRun = cleanupLastRun
        self.sessionTimeoutSeconds = sessionTimeoutSeconds
    }
}

// MARK: - Enhanced Request Models

/// Enhanced session request for SessionManager features
/// Supports persistent client configuration and enhanced context management
struct EnhancedSessionRequest: Codable {
    let userId: String
    let sessionName: String?
    let workingDirectory: String?
    let persistClient: Bool
    let claudeOptions: ClaudeCodeOptions
    let context: [String: AnyCodable]

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case sessionName = "session_name"
        case workingDirectory = "working_directory"
        case persistClient = "persist_client"
        case claudeOptions = "claude_options"
        case context
    }

    init(userId: String, sessionName: String? = nil, workingDirectory: String? = nil,
         persistClient: Bool = true, claudeOptions: ClaudeCodeOptions = ClaudeCodeOptions(),
         context: [String: AnyCodable] = [:]) {
        self.userId = userId
        self.sessionName = sessionName
        self.workingDirectory = workingDirectory
        self.persistClient = persistClient
        self.claudeOptions = claudeOptions
        self.context = context
    }

    /// Convert from legacy SessionRequest
    static func from(_ sessionRequest: SessionRequest, persistClient: Bool = true) -> EnhancedSessionRequest {
        return EnhancedSessionRequest(
            userId: sessionRequest.userId,
            sessionName: sessionRequest.sessionName,
            workingDirectory: sessionRequest.workingDirectory,
            persistClient: persistClient,
            claudeOptions: sessionRequest.claudeOptions,
            context: sessionRequest.context
        )
    }
}

/// Enhanced session list request with filtering and sorting options for SessionManager
struct SessionManagerListRequest: Codable {
    let userId: String
    let limit: Int
    let offset: Int
    let includeHistory: Bool
    let statusFilter: SessionStatus?
    let sortBy: SessionSortOption

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case limit
        case offset
        case includeHistory = "include_history"
        case statusFilter = "status_filter"
        case sortBy = "sort_by"
    }

    init(userId: String, limit: Int = 20, offset: Int = 0,
         includeHistory: Bool = false, statusFilter: SessionStatus? = nil,
         sortBy: SessionSortOption = .lastActiveAt) {
        self.userId = userId
        self.limit = limit
        self.offset = offset
        self.includeHistory = includeHistory
        self.statusFilter = statusFilter
        self.sortBy = sortBy
    }
}

/// Session sorting options for SessionManager queries
enum SessionSortOption: String, Codable, CaseIterable {
    case createdAt = "created_at"
    case lastActiveAt = "last_active_at"
    case sessionName = "session_name"
    case messageCount = "message_count"
}

// MARK: - Enhanced Response Models

/// Enhanced session list response with SessionManager metadata
struct SessionManagerListResponse: Codable {
    let sessions: [SessionManagerResponse]
    let totalCount: Int
    let hasMore: Bool
    let nextOffset: Int?
    let sessionManagerStats: SessionManagerStats?

    enum CodingKeys: String, CodingKey {
        case sessions
        case totalCount = "total_count"
        case hasMore = "has_more"
        case nextOffset = "next_offset"
        case sessionManagerStats = "session_manager_stats"
    }

    init(sessions: [SessionManagerResponse], totalCount: Int, hasMore: Bool,
         nextOffset: Int? = nil, sessionManagerStats: SessionManagerStats? = nil) {
        self.sessions = sessions
        self.totalCount = totalCount
        self.hasMore = hasMore
        self.nextOffset = nextOffset
        self.sessionManagerStats = sessionManagerStats
    }
}

/// SessionManager health response with detailed status information
struct SessionManagerHealthResponse: Codable {
    let sessionManagerAvailable: Bool
    let activeSessions: Int
    let memoryUsageMB: Float
    let lastCleanupRun: Date?
    let connectionStatus: String

    enum CodingKeys: String, CodingKey {
        case sessionManagerAvailable = "session_manager_available"
        case activeSessions = "active_sessions"
        case memoryUsageMB = "memory_usage_mb"
        case lastCleanupRun = "last_cleanup_run"
        case connectionStatus = "connection_status"
    }

    init(sessionManagerAvailable: Bool, activeSessions: Int, memoryUsageMB: Float,
         lastCleanupRun: Date? = nil, connectionStatus: String = "unknown") {
        self.sessionManagerAvailable = sessionManagerAvailable
        self.activeSessions = activeSessions
        self.memoryUsageMB = memoryUsageMB
        self.lastCleanupRun = lastCleanupRun
        self.connectionStatus = connectionStatus
    }
}

// MARK: - Supporting Types

/// Connection status for SessionManager integration
enum SessionManagerConnectionStatus: String, Codable, CaseIterable {
    case disconnected = "disconnected"
    case connecting = "connecting"
    case connected = "connected"
    case degraded = "degraded"
    case error = "error"

    var displayName: String {
        switch self {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected"
        case .degraded:
            return "Degraded"
        case .error:
            return "Error"
        }
    }

    var isHealthy: Bool {
        switch self {
        case .connected, .degraded:
            return true
        case .disconnected, .connecting, .error:
            return false
        }
    }
}

/// Session recovery information for handling SessionManager disconnections
struct SessionRecoveryInfo: Codable {
    let sessionId: String
    let lastKnownState: SessionStatus
    let lastActiveAt: Date
    let recoveryAttempts: Int
    let canRecover: Bool

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case lastKnownState = "last_known_state"
        case lastActiveAt = "last_active_at"
        case recoveryAttempts = "recovery_attempts"
        case canRecover = "can_recover"
    }

    init(sessionId: String, lastKnownState: SessionStatus, lastActiveAt: Date,
         recoveryAttempts: Int = 0, canRecover: Bool = true) {
        self.sessionId = sessionId
        self.lastKnownState = lastKnownState
        self.lastActiveAt = lastActiveAt
        self.recoveryAttempts = recoveryAttempts
        self.canRecover = canRecover
    }
}

// MARK: - Extensions for Backwards Compatibility

extension SessionManagerResponse {
    /// Convert to legacy SessionResponse for backwards compatibility
    func toSessionResponse() -> SessionResponse {
        let messages = conversationHistory?.map { $0.toClaudeMessage() } ?? []
        return SessionResponse(
            sessionId: sessionId,
            userId: userId,
            sessionName: sessionName,
            status: status,
            messages: messages,
            createdAt: createdAt,
            updatedAt: lastActiveAt,
            messageCount: messageCount,
            context: sessionManagerStats.map { stats in
                [
                    "active_sessions": .int(stats.activeSessions),
                    "memory_usage_mb": .double(Double(stats.memoryUsageMB)),
                    "session_timeout_seconds": .int(stats.sessionTimeoutSeconds)
                ]
            } ?? [:]
        )
    }

    /// Create from legacy SessionResponse
    static func from(_ sessionResponse: SessionResponse, workingDirectory: String,
                    sessionManagerStats: SessionManagerStats? = nil) -> SessionManagerResponse {
        let conversationHistory = sessionResponse.messages.map {
            ConversationMessage.from($0)
        }

        return SessionManagerResponse(
            sessionId: sessionResponse.sessionId,
            userId: sessionResponse.userId,
            sessionName: sessionResponse.sessionName,
            workingDirectory: workingDirectory,
            status: sessionResponse.status,
            createdAt: sessionResponse.createdAt,
            lastActiveAt: sessionResponse.updatedAt,
            messageCount: sessionResponse.messageCount,
            conversationHistory: conversationHistory,
            sessionManagerStats: sessionManagerStats
        )
    }
}

// MARK: - Utility Extensions

extension Array where Element == SessionManagerResponse {
    /// Filter sessions by status
    func filtered(by status: SessionStatus) -> [SessionManagerResponse] {
        return filter { $0.status == status }
    }

    /// Sort sessions by specified option
    func sorted(by option: SessionSortOption) -> [SessionManagerResponse] {
        switch option {
        case .createdAt:
            return sorted { $0.createdAt > $1.createdAt }
        case .lastActiveAt:
            return sorted { $0.lastActiveAt > $1.lastActiveAt }
        case .sessionName:
            return sorted {
                ($0.sessionName ?? "") < ($1.sessionName ?? "")
            }
        case .messageCount:
            return sorted { $0.messageCount > $1.messageCount }
        }
    }
}

extension SessionManagerStats {
    /// Check if memory usage is within acceptable limits
    var isMemoryUsageHealthy: Bool {
        return memoryUsageMB < 500.0 // Alert if over 500MB
    }

    /// Calculate cleanup efficiency
    var cleanupEfficiency: Double {
        guard totalSessionsCreated > 0 else { return 1.0 }
        return Double(totalSessionsCreated - activeSessions) / Double(totalSessionsCreated)
    }
}