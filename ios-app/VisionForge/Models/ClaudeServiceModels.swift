//
//  ClaudeServiceModels.swift
//  Models extracted from ClaudeService for clean separation
//

import Foundation

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

// MARK: - Error Types

enum ClaudeServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(String)
    case sessionNotFound
    case sessionManagerUnavailable
    case healthCheckFailed
    case connectionTimeout
    case networkError(String)

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
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}

// MARK: - Request/Response Models

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

// SessionManager health response wrapper from backend's session-manager/stats endpoint
struct SessionManagerHealthResponse: Codable {
    let sessionManagerStats: SessionManagerStats
    let timestamp: String

    enum CodingKeys: String, CodingKey {
        case sessionManagerStats = "session_manager_stats"
        case timestamp
    }
}


// MARK: - Network Types

enum NetworkError: LocalizedError {
    case timedOut
    case connectionLost
    case notConnectedToInternet
    case dnsLookupFailed
    case cannotConnectToHost
    case rateLimited(retryAfter: TimeInterval?)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .timedOut:
            return "Request timed out"
        case .connectionLost:
            return "Network connection lost"
        case .notConnectedToInternet:
            return "No internet connection"
        case .dnsLookupFailed:
            return "DNS lookup failed"
        case .cannotConnectToHost:
            return "Cannot connect to host"
        case .rateLimited(let retryAfter):
            if let retryAfter = retryAfter {
                return "Rate limited. Retry after \(Int(retryAfter)) seconds"
            }
            return "Rate limited"
        case .unknown(let error):
            return error.localizedDescription
        }
    }

    var isRetryable: Bool {
        switch self {
        case .timedOut, .connectionLost, .notConnectedToInternet,
             .dnsLookupFailed, .cannotConnectToHost, .rateLimited:
            return true
        case .unknown:
            return false
        }
    }
}