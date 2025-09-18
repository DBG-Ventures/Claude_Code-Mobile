//
//  SessionListViewModel.swift
//  Session management state and logic.
//
//  ObservableObject managing multiple Claude Code sessions, session lifecycle,
//  and coordination with the FastAPI backend for session persistence.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class SessionListViewModel: ObservableObject {
    
    // MARK: - Published Properties

    @Published var sessions: [SessionResponse] = []
    @Published var sessionManagerSessions: [SessionManagerResponse] = []
    @Published var isLoading: Bool = false
    @Published var error: ErrorResponse?
    @Published var selectedSession: SessionResponse?
    @Published var selectedSessionManager: SessionManagerResponse?
    @Published var sessionManagerStatus: SessionManagerConnectionStatus = .disconnected
    @Published var isRefreshing: Bool = false
    
    // MARK: - Private Properties

    private var claudeService: ClaudeService?
    private var sessionStateManager: SessionStateManager?
    private var cancellables = Set<AnyCancellable>()
    // Single user system
    private let userId: String = "mobile-user"
    private var useSessionManager: Bool = true // Flag to use enhanced SessionManager features
    
    // MARK: - Computed Properties

    var activeSessions: [SessionResponse] {
        sessions.filter { $0.status == .active }
    }

    var activeSessionManagerSessions: [SessionManagerResponse] {
        sessionManagerSessions.filter { $0.status == .active }
    }

    var recentSessions: [SessionResponse] {
        let oneHourAgo = Date().addingTimeInterval(-3600)
        return sessions.filter { $0.updatedAt > oneHourAgo }
    }

    var recentSessionManagerSessions: [SessionManagerResponse] {
        let oneHourAgo = Date().addingTimeInterval(-3600)
        return sessionManagerSessions.filter { $0.lastActiveAt > oneHourAgo }
    }

    var completedSessions: [SessionResponse] {
        sessions.filter { $0.status == .completed }
    }

    var completedSessionManagerSessions: [SessionManagerResponse] {
        sessionManagerSessions.filter { $0.status == .completed }
    }

    var currentSessionsList: [SessionManagerResponse] {
        return useSessionManager ? sessionManagerSessions : []
    }
    
    // MARK: - Initialization
    
    init() {
        setupInitialState()
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    // MARK: - Public Methods
    
    func setClaudeService(_ service: ClaudeService) {
        self.claudeService = service
    }

    func setSessionStateManager(_ sessionStateManager: SessionStateManager) {
        self.sessionStateManager = sessionStateManager
        setupSessionStateObservers()

        // Auto-load sessions from SessionManager
        if useSessionManager {
            loadSessionsFromSessionManager()
        }
    }
    
    func loadSessions() {
        if useSessionManager {
            loadSessionsFromSessionManager()
        } else {
            loadSessionsLegacy()
        }
    }

    private func loadSessionsFromSessionManager() {
        #if DEBUG
        // Use dummy data for testing
        isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.sessions = DummyData.dummySessions
            self.isLoading = false
            print("✅ Loaded \(DummyData.dummySessions.count) dummy sessions for testing")
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
                    self.sessionManagerSessions = sessionStateManager.activeSessions.sorted {
                        $0.lastActiveAt > $1.lastActiveAt
                    }
                }

                // Then refresh from backend
                try await sessionStateManager.refreshSessionsFromBackend()

                await MainActor.run {
                    self.sessionManagerSessions = sessionStateManager.activeSessions.sorted {
                        $0.lastActiveAt > $1.lastActiveAt
                    }
                    self.isLoading = false
                    print("✅ Loaded \(self.sessionManagerSessions.count) sessions from SessionManager")
                }

            } catch {
                await MainActor.run {
                    self.handleError(error, context: "loading SessionManager sessions")
                    self.isLoading = false
                }
            }
        }
    }

    private func loadSessionsLegacy() {
        guard let claudeService = claudeService else { return }

        isLoading = true
        error = nil

        Task {
            do {
                // Create session list request
                let listRequest = SessionListRequest(
                    userId: userId,
                    limit: 50,
                    offset: 0,
                    statusFilter: nil
                )

                let sessionListResponse = try await claudeService.getSessions(request: listRequest)

                await MainActor.run {
                    self.sessions = sessionListResponse.sessions.sorted { $0.updatedAt > $1.updatedAt }
                    self.isLoading = false
                }

            } catch {
                await MainActor.run {
                    self.handleError(error, context: "loading sessions")
                    self.isLoading = false
                }
            }
        }
    }
    
    func createNewSession(name: String, workingDirectory: String? = nil, completion: @escaping (Bool) -> Void) {
        if useSessionManager {
            createNewSessionWithManager(name: name, workingDirectory: workingDirectory, completion: completion)
        } else {
            createNewSessionLegacy(name: name, workingDirectory: workingDirectory, completion: completion)
        }
    }

    private func createNewSessionWithManager(name: String, workingDirectory: String? = nil, completion: @escaping (Bool) -> Void) {
        guard let sessionStateManager = sessionStateManager else {
            completion(false)
            return
        }

        Task {
            do {
                let sessionName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                let newSession = try await sessionStateManager.createNewSession(
                    name: sessionName.isEmpty ? nil : sessionName,
                    workingDirectory: workingDirectory
                )

                await MainActor.run {
                    self.sessionManagerSessions.insert(newSession, at: 0)
                    self.selectedSessionManager = newSession
                    completion(true)
                    print("✅ Created new SessionManager session: \(newSession.sessionId)")
                }

            } catch {
                await MainActor.run {
                    self.handleError(error, context: "creating new SessionManager session")
                    completion(false)
                }
            }
        }
    }

    private func createNewSessionLegacy(name: String, workingDirectory: String? = nil, completion: @escaping (Bool) -> Void) {
        guard let claudeService = claudeService else {
            completion(false)
            return
        }

        Task {
            do {
                let sessionRequest = SessionRequest(
                    userId: userId,
                    claudeOptions: ClaudeCodeOptions(
                        apiKey: nil,
                        model: nil, // Use default (latest) model
                        maxTokens: 8192,
                        temperature: 0.7,
                        timeout: 60
                    ),
                    sessionName: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    workingDirectory: workingDirectory, // User-specified working directory
                    context: ["created_from": .string("mobile"), "platform": .string("iOS")]
                )

                let newSession = try await claudeService.createSession(request: sessionRequest)

                await MainActor.run {
                    self.sessions.insert(newSession, at: 0)
                    self.selectedSession = newSession
                    completion(true)
                }

            } catch {
                await MainActor.run {
                    self.handleError(error, context: "creating new session")
                    completion(false)
                }
            }
        }
    }
    
    func deleteSession(_ session: SessionResponse) {
        // Optimistically remove from UI
        sessions.removeAll { $0.id == session.id }

        // Clear selection if deleting selected session
        if selectedSession?.id == session.id {
            selectedSession = nil
        }

        // TODO: Implement actual backend deletion when available
        // The backend API doesn't currently support actual deletion
        // This would call claudeService.deleteSession(sessionId, userId)
    }

    func deleteSessionManager(_ session: SessionManagerResponse) {
        guard let sessionStateManager = sessionStateManager else { return }

        // Optimistically remove from UI
        sessionManagerSessions.removeAll { $0.id == session.id }

        // Clear selection if deleting selected session
        if selectedSessionManager?.id == session.id {
            selectedSessionManager = nil
        }

        Task {
            do {
                try await sessionStateManager.deleteSession(session.sessionId)
                print("✅ Deleted SessionManager session: \(session.sessionId)")
            } catch {
                await MainActor.run {
                    // Re-add session if deletion failed
                    self.sessionManagerSessions.append(session)
                    self.handleError(error, context: "deleting SessionManager session")
                }
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
                    self.sessionManagerSessions = sessionStateManager.activeSessions.sorted {
                        $0.lastActiveAt > $1.lastActiveAt
                    }
                    self.isRefreshing = false
                    print("✅ Force refreshed \(self.sessionManagerSessions.count) sessions from backend")
                }

            } catch {
                await MainActor.run {
                    self.handleError(error, context: "force refreshing sessions from backend")
                    self.isRefreshing = false
                }
            }
        }
    }
    
    func selectSession(_ session: SessionResponse) {
        selectedSession = session

        // Update the session's last accessed time
        updateSessionLastAccessed(session)
    }

    func selectSessionManager(_ session: SessionManagerResponse) {
        selectedSessionManager = session

        // Update the session's last accessed time using SessionStateManager
        Task {
            await sessionStateManager?.updateSessionLastActive(session.sessionId)
        }
    }

    func switchToSessionManager(_ sessionId: String) {
        guard let sessionStateManager = sessionStateManager else { return }

        Task {
            do {
                try await sessionStateManager.switchToSession(sessionId)

                // Update selection to reflect the switch
                await MainActor.run {
                    if let session = sessionStateManager.getSession(sessionId) {
                        self.selectedSessionManager = session
                    }
                }

            } catch {
                await MainActor.run {
                    self.handleError(error, context: "switching to SessionManager session")
                }
            }
        }
    }
    
    func updateSessionInList(_ updatedSession: SessionResponse) {
        if let index = sessions.firstIndex(where: { $0.id == updatedSession.id }) {
            sessions[index] = updatedSession
            
            // Re-sort sessions by updated date
            sessions.sort { $0.updatedAt > $1.updatedAt }
        }
    }
    
    func getSession(by id: String) -> SessionResponse? {
        return sessions.first { $0.id == id }
    }
    
    // MARK: - Private Methods

    private func setupInitialState() {
        sessions = []
        sessionManagerSessions = []
        isLoading = false
        isRefreshing = false
        error = nil
        selectedSession = nil
        selectedSessionManager = nil
        sessionManagerStatus = .disconnected
    }

    private func setupSessionStateObservers() {
        guard let sessionStateManager = sessionStateManager else { return }

        // Monitor SessionManager connection status
        sessionStateManager.$sessionManagerStatus
            .receive(on: DispatchQueue.main)
            .assign(to: \.sessionManagerStatus, on: self)
            .store(in: &cancellables)

        // Monitor active sessions changes
        sessionStateManager.$activeSessions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessions in
                self?.sessionManagerSessions = sessions.sorted { $0.lastActiveAt > $1.lastActiveAt }
            }
            .store(in: &cancellables)

        // Monitor current session changes
        sessionStateManager.$currentSessionId
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessionId in
                if let sessionId = sessionId,
                   let session = sessionStateManager.getSession(sessionId) {
                    self?.selectedSessionManager = session
                }
            }
            .store(in: &cancellables)
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

        // Configure for SessionManager mode
        viewModel.useSessionManager = true
        viewModel.sessionManagerStatus = .connected

        // Add sample SessionManager sessions for preview
        viewModel.sessionManagerSessions = [
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
        viewModel.selectedSessionManager = viewModel.sessionManagerSessions.first

        // Also add legacy sessions for compatibility testing
        viewModel.sessions = [
            SessionResponse(
                sessionId: "legacy-session-1",
                userId: "preview-user",
                sessionName: "Legacy Session",
                status: .active,
                messages: [],
                createdAt: Date().addingTimeInterval(-3600),
                updatedAt: Date().addingTimeInterval(-300),
                messageCount: 2,
                context: ["platform": .string("iOS")]
            )
        ]

        return viewModel
    }
}