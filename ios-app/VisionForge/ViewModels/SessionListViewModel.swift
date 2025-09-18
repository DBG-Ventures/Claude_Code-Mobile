//
//  SessionListViewModel.swift
//  Session management state and logic.
//
//  ObservableObject managing multiple Claude Code sessions, session lifecycle,
//  and coordination with the FastAPI backend for session persistence.
//

import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
class SessionListViewModel {

    // MARK: - Observable Properties

    var sessions: [SessionManagerResponse] = []
    var isLoading: Bool = false
    var error: ErrorResponse?
    var selectedSession: SessionManagerResponse?
    var sessionManagerStatus: SessionManagerConnectionStatus = .disconnected
    var isRefreshing: Bool = false

    // MARK: - Private Properties

    private var repository: SessionRepository?
    private var sessionStateManager: SessionStateManager?
    private var sessionStateObserver: Task<Void, Never>?
    // Single user system
    private let userId: String = "mobile-user"
    
    // MARK: - Computed Properties

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
    
    // MARK: - Initialization
    
    init() {
        setupInitialState()
    }
    
    // Cleanup handled in Task cancellation
    
    // MARK: - Public Methods
    
    func setRepository(_ repository: SessionRepository) {
        self.repository = repository
        Task {
            await observeRepositoryChanges()
        }
    }

    func setSessionStateManager(_ sessionStateManager: SessionStateManager) {
        self.sessionStateManager = sessionStateManager
        setupSessionStateObservers()
        loadSessions()
    }
    
    func loadSessions() {
        guard let repository else { return }

        Task {
            isLoading = true
            defer { isLoading = false }

            do {
                sessions = try await repository.getAllSessions()
            } catch {
                handleError(error, context: "loading sessions")
            }
        }
    }

    private func loadSessionsFromSessionManager() {
        #if DEBUG
        // Load dummy data in debug mode for UI testing
        print("⚠️ Loading dummy SessionManager sessions for development testing")
        isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.sessions = DummyData.dummySessionManagerSessions
            self.isLoading = false
            print("✅ Loaded \(DummyData.dummySessionManagerSessions.count) dummy SessionManager sessions for testing")
        }
        return
        #endif

        guard let sessionStateManager = sessionStateManager else { return }

        isLoading = true
        error = nil

        Task {
            do {
                // First restore from persistence for instant UI
                try await sessionStateManager.restoreSessionsFromPersistence()

                await MainActor.run {
                    self.sessions = sessionStateManager.activeSessions.sorted {
                        $0.lastActiveAt > $1.lastActiveAt
                    }
                }

                // Then refresh from backend
                try await sessionStateManager.refreshSessionsFromBackend()

                await MainActor.run {
                    self.sessions = sessionStateManager.activeSessions.sorted {
                        $0.lastActiveAt > $1.lastActiveAt
                    }
                    self.isLoading = false
                    print("✅ Loaded \(self.sessions.count) sessions from SessionManager")
                }

            } catch {
                await MainActor.run {
                    self.handleError(error, context: "loading SessionManager sessions")
                    self.isLoading = false
                }
            }
        }
    }

    
    func createNewSession(name: String, workingDirectory: String? = nil) async -> Bool {
        guard let repository else { return false }

        do {
            let sessionName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let newSession = try await repository.createSession(
                name: sessionName.isEmpty ? nil : sessionName,
                workingDirectory: workingDirectory
            )

            self.sessions.insert(newSession, at: 0)
            self.selectedSession = newSession
            print("✅ Created new session: \(newSession.sessionId)")
            return true

        } catch {
            self.handleError(error, context: "creating new session")
            return false
        }
    }

    private func createNewSessionWithManager(name: String, workingDirectory: String? = nil) async -> Bool {
        guard let sessionStateManager = sessionStateManager else {
            return false
        }

        do {
            let sessionName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let newSession = try await sessionStateManager.createNewSession(
                name: sessionName.isEmpty ? nil : sessionName,
                workingDirectory: workingDirectory
            )

            self.sessions.insert(newSession, at: 0)
            self.selectedSession = newSession
            print("✅ Created new SessionManager session: \(newSession.sessionId)")
            return true

        } catch {
            self.handleError(error, context: "creating new SessionManager session")
            return false
        }
    }

    
    func deleteSession(_ session: SessionManagerResponse) {
        guard let repository else { return }

        // Optimistically remove from UI
        sessions.removeAll { $0.sessionId == session.sessionId }

        // Clear selection if deleting selected session
        if selectedSession?.sessionId == session.sessionId {
            selectedSession = nil
        }

        Task {
            do {
                try await repository.deleteSession(session.sessionId)
                print("✅ Deleted session: \(session.sessionId)")
            } catch {
                // Re-add session if deletion failed
                self.sessions.append(session)
                self.handleError(error, context: "deleting session")
            }
        }
    }
    
    func refreshSessions() {
        isRefreshing = true
        loadSessions()

        // Auto-clear refreshing state after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.isRefreshing = false
        }
    }

    func forceRefreshFromBackend() {
        guard let sessionStateManager = sessionStateManager else {
            refreshSessions()
            return
        }

        isRefreshing = true
        error = nil

        Task {
            do {
                try await sessionStateManager.refreshSessionsFromBackend()

                await MainActor.run {
                    self.sessions = sessionStateManager.activeSessions.sorted {
                        $0.lastActiveAt > $1.lastActiveAt
                    }
                    self.isRefreshing = false
                    print("✅ Force refreshed \(self.sessions.count) sessions from backend")
                }

            } catch {
                await MainActor.run {
                    self.handleError(error, context: "force refreshing sessions from backend")
                    self.isRefreshing = false
                }
            }
        }
    }
    
    func selectSession(_ session: SessionManagerResponse) {
        selectedSession = session

        // Update the session's last accessed time
        Task {
            await repository?.updateSessionActivity(session.sessionId)
        }
    }

    func switchToSessionManager(_ sessionId: String) {
        guard let repository = repository else { return }

        Task {
            do {
                try await repository.switchToSession(sessionId)

                await MainActor.run {
                    if let session = sessions.first(where: { $0.sessionId == sessionId }) {
                        self.selectedSession = session
                    }
                }
            } catch {
                await MainActor.run {
                    self.handleError(error, context: "switching to session")
                }
            }
        }
    }
    
    func updateSessionInList(_ updatedSession: SessionManagerResponse) {
        if let index = sessions.firstIndex(where: { $0.sessionId == updatedSession.sessionId }) {
            sessions[index] = updatedSession
            
            // Re-sort sessions by updated date
            sessions.sort { $0.lastActiveAt > $1.lastActiveAt }
        }
    }
    
    func getSession(by id: String) -> SessionManagerResponse? {
        return sessions.first { $0.sessionId == id }
    }
    
    // MARK: - Private Methods

    private func setupInitialState() {
        sessions = []
        isLoading = false
        isRefreshing = false
        error = nil
        selectedSession = nil
        sessionManagerStatus = .disconnected
    }

    private func observeRepositoryChanges() async {
        guard let repository else { return }

        // Observe repository changes using withObservationTracking
        while !Task.isCancelled {
            withObservationTracking {
                // Sync sessions from repository
                self.sessions = repository.sessions
                self.isLoading = repository.isLoading

                // Update selected session if current selection changed
                if let currentId = repository.currentSessionId,
                   selectedSession?.sessionId != currentId {
                    self.selectedSession = repository.currentSession
                }
            } onChange: {
                Task { @MainActor in
                    // Changes detected, loop will continue
                }
            }

            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
    }

    private func setupSessionStateObservers() {
        guard let sessionStateManager = sessionStateManager else { return }

        // Use withObservationTracking for efficient updates
        Task { @MainActor in
            while true {
                withObservationTracking {
                    // Track changes to SessionStateManager properties
                    self.sessionManagerStatus = sessionStateManager.sessionManagerStatus
                    self.sessions = sessionStateManager.activeSessions.sorted {
                        $0.lastActiveAt > $1.lastActiveAt
                    }

                    if let sessionId = sessionStateManager.currentSessionId,
                       let session = sessionStateManager.getSession(sessionId) {
                        self.selectedSession = session
                    }
                } onChange: {
                    // This will be called when any tracked property changes
                    Task { @MainActor in
                        // Update will happen on next iteration
                    }
                }

                // Small delay to prevent tight loop
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
        }
    }
    
    private func updateSessionLastAccessed(_ session: SessionResponse) {
        // Temporarily disabled to avoid 404 errors with in-memory backend storage
        // TODO: Re-enable when backend has persistent storage
        return
    }
    
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
}

// MARK: - Preview Helper

extension SessionListViewModel {
    static func preview() -> SessionListViewModel {
        let viewModel = SessionListViewModel()

        // Configure for connected status
        viewModel.sessionManagerStatus = .connected

        // Add sample sessions for preview
        viewModel.sessions = [
            SessionManagerResponse(
                sessionId: "session-manager-1",
                userId: "preview-user",
                sessionName: "SwiftUI Help",
                workingDirectory: "/Users/developer/Projects/SwiftUI",
                status: .active,
                createdAt: Date().addingTimeInterval(-3600),
                lastActiveAt: Date().addingTimeInterval(-300),
                messageCount: 4,
                conversationHistory: [
                    ConversationMessage(
                        id: "msg-1",
                        role: .user,
                        content: "How can I create a navigation stack?",
                        sessionId: "session-manager-1"
                    ),
                    ConversationMessage(
                        id: "msg-2",
                        role: .assistant,
                        content: "I can help you with SwiftUI navigation...",
                        sessionId: "session-manager-1"
                    )
                ],
                sessionManagerStats: SessionManagerStats(
                    activeSessions: 3,
                    totalSessionsCreated: 15,
                    memoryUsageMB: 125.5,
                    cleanupLastRun: Date().addingTimeInterval(-1800),
                    sessionTimeoutSeconds: 3600
                )
            ),
            SessionManagerResponse(
                sessionId: "session-manager-2",
                userId: "preview-user",
                sessionName: "Python Debug",
                workingDirectory: "/Users/developer/Projects/Python",
                status: .completed,
                createdAt: Date().addingTimeInterval(-7200),
                lastActiveAt: Date().addingTimeInterval(-1800),
                messageCount: 6,
                conversationHistory: [
                    ConversationMessage(
                        id: "msg-3",
                        role: .user,
                        content: "Help me debug this Python code",
                        sessionId: "session-manager-2"
                    )
                ]
            ),
            SessionManagerResponse(
                sessionId: "session-manager-3",
                userId: "preview-user",
                sessionName: "React Components",
                workingDirectory: "/Users/developer/Projects/React",
                status: .active,
                createdAt: Date().addingTimeInterval(-5400),
                lastActiveAt: Date().addingTimeInterval(-900),
                messageCount: 12
            )
        ]

        // Set selected session
        viewModel.selectedSession = viewModel.sessions.first

        return viewModel
    }
}