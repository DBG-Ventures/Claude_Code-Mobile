//
//  SessionRepositoryProtocol.swift
//  Repository interface for session management
//

import Foundation

@MainActor
protocol SessionRepositoryProtocol: AnyObject {

    // Observable state
    var sessions: [SessionManagerResponse] { get }
    var currentSessionId: String? { get }
    var isLoading: Bool { get }
    var isRefreshing: Bool { get }
    var lastError: String? { get }
    var sessionManagerStatus: SessionManagerConnectionStatus { get }

    // Session operations
    func createSession(name: String?, workingDirectory: String?) async throws -> SessionManagerResponse
    func deleteSession(_ sessionId: String) async throws
    func getSession(_ sessionId: String) async throws -> SessionManagerResponse?
    func getAllSessions() async throws -> [SessionManagerResponse]
    func updateSessionActivity(_ sessionId: String) async
    func switchToSession(_ sessionId: String) async throws

    // Refresh and sync
    func refreshSessionsFromBackend() async throws
    func startBackgroundRefresh()
    func stopBackgroundRefresh()

    // Cache management
    func clearCache() async
    func getCacheSize() async -> Int
}