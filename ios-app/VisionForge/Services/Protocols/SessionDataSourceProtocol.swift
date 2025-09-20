//
//  SessionDataSourceProtocol.swift
//  Protocol for session data operations
//

import Foundation

@MainActor
protocol SessionDataSourceProtocol: AnyObject {

    // Session CRUD operations
    func createSession(_ request: SessionRequest) async throws -> SessionResponse
    func getSession(sessionId: String, userId: String) async throws -> SessionResponse
    func updateSession(_ request: SessionUpdateRequest) async throws -> SessionResponse
    func deleteSession(sessionId: String, userId: String) async throws

    // Enhanced SessionManager operations
    func createSessionWithManager(_ request: EnhancedSessionRequest) async throws -> SessionManagerResponse
    func getSessionWithManager(sessionId: String, userId: String, includeHistory: Bool) async throws -> SessionManagerResponse?
    func getSessionsWithManager(_ request: SessionListRequest) async throws -> SessionListResponse

    // Session listing and querying
    func getSessions(_ request: SessionListRequest) async throws -> SessionListResponse
    func getSessionManagerStats() async throws -> SessionManagerHealthResponse

    // Health check
    func checkSessionManagerConnectionStatus() async throws -> SessionManagerConnectionStatus
}