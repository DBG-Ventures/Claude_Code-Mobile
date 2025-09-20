//
//  SessionAPIClient.swift
//  Session CRUD operations client for Claude API communication
//
//  Handles session creation, retrieval, updates, and deletion.
//  Conforms to SessionDataSourceProtocol for dependency injection.
//

import Foundation
import Observation

/// Client responsible for session-related API operations
/// Manages session CRUD operations and SessionManager integration
@MainActor
@Observable
final class SessionAPIClient: SessionDataSourceProtocol {

    // MARK: - Observable Properties

    var sessionManagerConnectionStatus: SessionManagerConnectionStatus = .disconnected
    var lastSessionError: Error?

    // MARK: - Private Properties

    private let networkClient: NetworkClientProtocol
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    // MARK: - Initialization

    init(networkClient: NetworkClientProtocol) {
        self.networkClient = networkClient

        // Configure JSON coders with date formatting
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()

        // Backend expects format: yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        encoder.dateEncodingStrategy = .formatted(dateFormatter)
        decoder.dateDecodingStrategy = .formatted(dateFormatter)
    }

    // MARK: - SessionDataSourceProtocol Implementation

    /// Create a new session
    func createSession(_ request: SessionRequest) async throws -> SessionResponse {
        lastSessionError = nil

        do {
            let response: SessionResponse = try await networkClient.post("claude/sessions", body: request)
            return response
        } catch {
            lastSessionError = error
            throw error
        }
    }

    /// Retrieve a specific session
    func getSession(sessionId: String, userId: String) async throws -> SessionResponse {
        lastSessionError = nil

        do {
            let endpoint = "claude/sessions/\(sessionId)?user_id=\(userId)"
            let response: SessionResponse = try await networkClient.get(endpoint)
            return response
        } catch {
            lastSessionError = error
            throw error
        }
    }

    /// Update an existing session
    func updateSession(_ request: SessionUpdateRequest) async throws -> SessionResponse {
        lastSessionError = nil

        do {
            let response: SessionResponse = try await networkClient.put("claude/sessions/\(request.sessionId)", body: request)
            return response
        } catch {
            lastSessionError = error
            throw error
        }
    }

    /// Delete a session
    func deleteSession(sessionId: String, userId: String) async throws {
        lastSessionError = nil

        do {
            let endpoint = "claude/sessions/\(sessionId)?user_id=\(userId)"
            try await networkClient.delete(endpoint)
        } catch {
            lastSessionError = error
            throw error
        }
    }

    /// Create a session with SessionManager integration
    func createSessionWithManager(_ request: EnhancedSessionRequest) async throws -> SessionManagerResponse {
        lastSessionError = nil

        do {
            print("🔍 SessionAPIClient: createSessionWithManager called")
            print("🔍 SessionAPIClient: Making HTTP request to backend...")

            let response: SessionManagerResponse = try await networkClient.post("claude/sessions", body: request)
            await updateSessionManagerConnectionStatus(.connected)

            print("🔍 SessionAPIClient: Session created successfully with SessionManager")
            return response
        } catch {
            lastSessionError = error

            if let serviceError = error as? ClaudeServiceError {
                switch serviceError {
                case .serverError(let message) where message.contains("404"):
                    await updateSessionManagerConnectionStatus(.error)
                    throw ClaudeServiceError.sessionManagerUnavailable
                default:
                    await updateSessionManagerConnectionStatus(.error)
                }
            } else {
                await updateSessionManagerConnectionStatus(.error)
            }

            throw error
        }
    }

    /// Retrieve a session with SessionManager integration
    func getSessionWithManager(sessionId: String, userId: String, includeHistory: Bool = true) async throws -> SessionManagerResponse? {
        lastSessionError = nil

        do {
            let endpoint = "claude/sessions/\(sessionId)?user_id=\(userId)&include_history=\(includeHistory)"
            let response: SessionManagerResponse = try await networkClient.get(endpoint)
            await updateSessionManagerConnectionStatus(.connected)
            return response
        } catch {
            lastSessionError = error

            if let serviceError = error as? ClaudeServiceError {
                switch serviceError {
                case .sessionNotFound:
                    await updateSessionManagerConnectionStatus(.connected) // SessionManager is available, session just not found
                    return nil
                case .serverError(let message) where message.contains("404"):
                    await updateSessionManagerConnectionStatus(.error)
                    throw ClaudeServiceError.sessionManagerUnavailable
                default:
                    await updateSessionManagerConnectionStatus(.error)
                }
            } else {
                await updateSessionManagerConnectionStatus(.error)
            }

            throw error
        }
    }

    /// Retrieve sessions with SessionManager integration
    func getSessionsWithManager(_ request: SessionListRequest) async throws -> SessionListResponse {
        lastSessionError = nil

        do {
            var endpoint = "claude/sessions?user_id=\(request.userId)&limit=\(request.limit)&offset=\(request.offset)"

            if let statusFilter = request.statusFilter {
                endpoint += "&status_filter=\(statusFilter)"
            }

            let response: SessionListResponse = try await networkClient.get(endpoint)
            await updateSessionManagerConnectionStatus(.connected)
            return response
        } catch {
            lastSessionError = error

            if let serviceError = error as? ClaudeServiceError {
                switch serviceError {
                case .serverError(let message) where message.contains("404"):
                    await updateSessionManagerConnectionStatus(.error)
                    throw ClaudeServiceError.sessionManagerUnavailable
                default:
                    await updateSessionManagerConnectionStatus(.error)
                }
            } else {
                await updateSessionManagerConnectionStatus(.error)
            }

            throw error
        }
    }

    /// Retrieve sessions using standard protocol (backwards compatibility)
    func getSessions(_ request: SessionListRequest) async throws -> SessionListResponse {
        return try await getSessionsWithManager(request)
    }

    /// Get SessionManager statistics
    /// Note: This endpoint may not exist in all backend implementations
    /// Falls back to checking session list endpoint for connectivity
    func getSessionManagerStats() async throws -> SessionManagerHealthResponse {
        lastSessionError = nil

        do {
            // Try the dedicated stats endpoint first (if it exists)
            let response: SessionManagerHealthResponse = try await networkClient.get("claude/session-manager/stats")
            await updateSessionManagerConnectionStatus(.connected)
            return response
        } catch {
            // If stats endpoint doesn't exist, try a simple session list request to verify connectivity
            if let serviceError = error as? ClaudeServiceError,
               case .serverError(let message) = serviceError,
               message.contains("404") {

                // Try to get sessions with minimal parameters to check if backend is working
                do {
                    let testRequest = SessionListRequest(userId: "mobile-user", limit: 1, offset: 0, statusFilter: nil)
                    _ = try await getSessionsWithManager(testRequest)

                    // If we can get sessions, backend is working, just without dedicated stats endpoint
                    await updateSessionManagerConnectionStatus(.connected)

                    // Return a mock healthy response matching backend format
                    let mockStats = SessionManagerStats(
                        activeSessions: 0,
                        sessionTimeoutSeconds: 3600,
                        cleanupIntervalSeconds: 300,
                        cleanupTaskRunning: false,
                        timestamp: ISO8601DateFormatter().string(from: Date()),
                        oldestSessionAgeSeconds: nil,
                        newestSessionAgeSeconds: nil,
                        averageSessionAgeSeconds: nil
                    )
                    return SessionManagerHealthResponse(
                        sessionManagerStats: mockStats,
                        timestamp: ISO8601DateFormatter().string(from: Date())
                    )
                } catch {
                    // If both endpoints fail, then we have a real connection issue
                    lastSessionError = error
                    await updateSessionManagerConnectionStatus(.error)
                    throw ClaudeServiceError.sessionManagerUnavailable
                }
            }

            lastSessionError = error
            await updateSessionManagerConnectionStatus(.error)
            throw error
        }
    }

    /// Check SessionManager connection status
    func checkSessionManagerConnectionStatus() async throws -> SessionManagerConnectionStatus {
        do {
            _ = try await getSessionManagerStats()
            return .connected
        } catch {
            if case ClaudeServiceError.sessionManagerUnavailable = error {
                return .error
            }
            throw error
        }
    }

    // MARK: - Private Methods

    /// Update SessionManager connection status
    private func updateSessionManagerConnectionStatus(_ status: SessionManagerConnectionStatus) async {
        await MainActor.run {
            self.sessionManagerConnectionStatus = status
        }
    }
}