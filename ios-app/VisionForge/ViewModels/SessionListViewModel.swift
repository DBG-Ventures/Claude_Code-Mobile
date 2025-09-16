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
    @Published var isLoading: Bool = false
    @Published var error: ErrorResponse?
    @Published var selectedSession: SessionResponse?
    
    // MARK: - Private Properties
    
    private var claudeService: ClaudeService?
    private var cancellables = Set<AnyCancellable>()
    // Single user system
    private let userId: String = "mobile-user"
    
    // MARK: - Computed Properties
    
    var activeSessions: [SessionResponse] {
        sessions.filter { $0.status == .active }
    }
    
    var recentSessions: [SessionResponse] {
        let oneHourAgo = Date().addingTimeInterval(-3600)
        return sessions.filter { $0.updatedAt > oneHourAgo }
    }
    
    var completedSessions: [SessionResponse] {
        sessions.filter { $0.status == .completed }
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
    
    func loadSessions() {
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
    
    func createNewSession(name: String, completion: @escaping (Bool) -> Void) {
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
    
    func refreshSessions() {
        loadSessions()
    }
    
    func selectSession(_ session: SessionResponse) {
        selectedSession = session
        
        // Update the session's last accessed time
        updateSessionLastAccessed(session)
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
        isLoading = false
        error = nil
        selectedSession = nil
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
        
        // Add sample sessions for preview
        viewModel.sessions = [
            SessionResponse(
                sessionId: "session-1",
                userId: "preview-user",
                sessionName: "SwiftUI Help",
                status: .active,
                messages: [
                    ClaudeMessage(id: "msg-1", content: "How can I create a navigation stack?", role: .user, timestamp: Date(), sessionId: "session-1"),
                    ClaudeMessage(id: "msg-2", content: "I can help you with SwiftUI navigation...", role: .assistant, timestamp: Date(), sessionId: "session-1")
                ],
                createdAt: Date().addingTimeInterval(-3600),
                updatedAt: Date().addingTimeInterval(-300),
                messageCount: 4,
                context: ["platform": .string("iOS")]
            ),
            SessionResponse(
                sessionId: "session-2",
                userId: "preview-user",
                sessionName: "Python Debug",
                status: .completed,
                messages: [
                    ClaudeMessage(id: "msg-3", content: "Help me debug this Python code", role: .user, timestamp: Date(), sessionId: "session-2")
                ],
                createdAt: Date().addingTimeInterval(-7200),
                updatedAt: Date().addingTimeInterval(-1800),
                messageCount: 6,
                context: ["platform": .string("iOS")]
            )
        ]
        
        return viewModel
    }
}