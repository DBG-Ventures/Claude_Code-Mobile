//
//  ConversationViewModel.swift
//  Chat interface state management and Claude Code integration.
//
//  ObservableObject managing conversation state, message handling, and real-time streaming
//  integration with Claude Code FastAPI backend.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class ConversationViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var messages: [ClaudeMessage] = []
    @Published var isStreaming: Bool = false
    @Published var streamingMessageId: String?
    @Published var currentSession: SessionResponse?
    @Published var error: ErrorResponse?
    @Published var isLoading: Bool = false
    
    // MARK: - Private Properties

    private var claudeService: ClaudeService?
    private var cancellables = Set<AnyCancellable>()
    private var streamingContinuation: Task<Void, Never>?
    private var currentSessionId: String?

    // Message accumulation optimization
    private var messageBuffer: String = ""
    private var bufferTimer: Timer?
    private let bufferUpdateInterval: TimeInterval = 0.1  // Update UI every 100ms
    private let maxBufferSize = 500  // Max characters before forced update
    private var lastUpdateTime: Date = Date()
    
    // Configuration - Single user system
    private let userId: String = "mobile-user"
    private let claudeOptions = ClaudeCodeOptions(
        apiKey: nil, // Will be set from environment or user preferences
        model: nil, // Use default (latest) model
        maxTokens: 8192,
        temperature: 0.7,
        timeout: 60
    )
    
    // MARK: - Initialization
    
    init() {
        setupInitialState()
    }
    
    deinit {
        streamingContinuation?.cancel()
        cancellables.removeAll()
    }
    
    // MARK: - Public Methods
    
    func setClaudeService(_ service: ClaudeService) {
        self.claudeService = service
        createInitialSessionIfNeeded()
    }
    
    func sendMessage(_ content: String) {
        guard let claudeService = claudeService,
              let session = currentSession else {
            setError(ErrorResponse(
                error: "configuration_error",
                message: "Claude service not configured or no active session",
                details: nil,
                timestamp: Date(),
                requestId: nil
            ))
            return
        }
        
        // Add user message immediately
        let userMessage = ClaudeMessage(
            id: UUID().uuidString,
            content: content,
            role: .user,
            timestamp: Date(),
            sessionId: session.sessionId
        )
        
        messages.append(userMessage)
        
        // Start streaming Claude's response
        startStreamingResponse(query: content, sessionId: session.sessionId)
    }
    
    func stopStreaming() {
        streamingContinuation?.cancel()
        isStreaming = false
        streamingMessageId = nil
    }
    
    func clearMessages() {
        messages.removeAll()
        error = nil
    }
    
    func refreshSession() {
        createInitialSessionIfNeeded()
    }

    func loadSession(sessionId: String) {
        // Stop any current streaming
        stopStreaming()

        // Clear current messages
        clearMessages()

        // Load session from service or persistence
        Task {
            await loadSessionData(sessionId: sessionId)
        }
    }
    
    // MARK: - Private Methods
    
    private func setupInitialState() {
        messages = []
        isStreaming = false
        streamingMessageId = nil
        error = nil
    }
    
    private func createInitialSessionIfNeeded() {
        guard let claudeService = claudeService, currentSession == nil else { return }
        
        isLoading = true
        
        Task {
            do {
                let sessionRequest = SessionRequest(
                    userId: userId,
                    claudeOptions: claudeOptions,
                    sessionName: "Mobile Chat Session",
                    context: [:]
                )
                
                let session = try await claudeService.createSession(request: sessionRequest)
                await MainActor.run {
                    self.currentSession = session
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.setError(ErrorResponse(
                        error: "session_creation_error",
                        message: "Failed to create chat session: \(error.localizedDescription)",
                        details: nil,
                        timestamp: Date(),
                        requestId: nil
                    ))
                    self.isLoading = false
                }
            }
        }
    }
    
    private func startStreamingResponse(query: String, sessionId: String) {
        guard let claudeService = claudeService else { return }

        isStreaming = true
        let messageId = UUID().uuidString
        streamingMessageId = messageId

        // Reset buffer
        messageBuffer = ""
        lastUpdateTime = Date()

        // Start buffer update timer for smooth UI updates
        startBufferTimer(messageId: messageId, sessionId: sessionId)

        // Start streaming task
        streamingContinuation = Task {
            do {
                let queryRequest = ClaudeQueryRequest(
                    sessionId: sessionId,
                    query: query,
                    userId: userId,
                    stream: true,
                    context: [:]
                )

                var accumulatedContent = ""
                var messageCreated = false

                for try await chunk in claudeService.streamQuery(request: queryRequest) {
                    guard !Task.isCancelled else { break }

                    switch chunk.chunkType {
                    case .start:
                        // Streaming has started, continue processing
                        break

                    case .delta:
                        // Buffer the content for optimized updates
                        if let content = chunk.content {
                            accumulatedContent += content

                            await MainActor.run {
                                self.messageBuffer += content

                                // Create message if it doesn't exist yet
                                if !messageCreated {
                                    let deltaMessage = ClaudeMessage(
                                        id: messageId,
                                        content: "",
                                        role: .assistant,
                                        timestamp: Date(),
                                        sessionId: sessionId
                                    )
                                    self.messages.append(deltaMessage)
                                    messageCreated = true
                                }

                                // Force update if buffer is too large or too much time has passed
                                let timeSinceLastUpdate = Date().timeIntervalSince(self.lastUpdateTime)
                                if self.messageBuffer.count > self.maxBufferSize || timeSinceLastUpdate > 1.0 {
                                    self.flushBuffer(messageId: messageId, sessionId: sessionId, accumulatedContent: accumulatedContent)
                                }
                            }
                        }

                    case .assistant, .thinking, .tool, .system:
                        // Flush buffer before adding special message
                        await MainActor.run {
                            if !self.messageBuffer.isEmpty {
                                self.flushBuffer(messageId: messageId, sessionId: sessionId, accumulatedContent: accumulatedContent)
                            }

                            // Create separate message bubbles for each thinking step/tool usage
                            if let content = chunk.content, !content.isEmpty {
                                let stepMessageId = UUID().uuidString
                                let stepMessage = ClaudeMessage(
                                    id: stepMessageId,
                                    content: content,
                                    role: .assistant,
                                    timestamp: Date(),
                                    sessionId: sessionId,
                                    metadata: [
                                        "chunk_type": .string(chunk.chunkType.rawValue),
                                        "is_thinking_step": .bool(true)
                                    ]
                                )
                                self.messages.append(stepMessage)
                            }
                        }

                    case .complete:
                        await MainActor.run {
                            // Final flush of any remaining buffer
                            if !self.messageBuffer.isEmpty {
                                self.flushBuffer(messageId: messageId, sessionId: sessionId, accumulatedContent: accumulatedContent)
                            }
                            self.stopBufferTimer()
                            self.isStreaming = false
                            self.streamingMessageId = nil
                        }

                    case .error:
                        await MainActor.run {
                            self.stopBufferTimer()
                            let errorMessage = chunk.error ?? chunk.message ?? chunk.content ?? "Unknown streaming error"
                            self.handleStreamingError(errorMessage)
                        }
                    }
                }

                await MainActor.run {
                    // Final cleanup
                    if !self.messageBuffer.isEmpty {
                        self.flushBuffer(messageId: messageId, sessionId: sessionId, accumulatedContent: accumulatedContent)
                    }
                    self.stopBufferTimer()
                    self.isStreaming = false
                    self.streamingMessageId = nil
                }

            } catch {
                await MainActor.run {
                    self.stopBufferTimer()
                    self.handleStreamingError(error.localizedDescription)
                }
            }
        }
    }

    private func startBufferTimer(messageId: String, sessionId: String) {
        stopBufferTimer()  // Clean up any existing timer

        bufferTimer = Timer.scheduledTimer(withTimeInterval: bufferUpdateInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            Task { @MainActor in
                if !self.messageBuffer.isEmpty {
                    // Only update if there's new content in the buffer
                    if let existingIndex = self.messages.firstIndex(where: { $0.id == messageId }) {
                        let currentContent = self.messages[existingIndex].content
                        let newContent = currentContent + self.messageBuffer

                        // Use efficient update without recreating the entire message
                        self.messages[existingIndex] = ClaudeMessage(
                            id: messageId,
                            content: newContent,
                            role: .assistant,
                            timestamp: self.messages[existingIndex].timestamp,
                            sessionId: sessionId
                        )

                        self.messageBuffer = ""
                        self.lastUpdateTime = Date()
                    }
                }
            }
        }
    }

    private func stopBufferTimer() {
        bufferTimer?.invalidate()
        bufferTimer = nil
    }

    private func flushBuffer(messageId: String, sessionId: String, accumulatedContent: String) {
        guard !messageBuffer.isEmpty else { return }

        if let existingIndex = messages.firstIndex(where: { $0.id == messageId }) {
            // Update with accumulated content directly for final flush
            messages[existingIndex] = ClaudeMessage(
                id: messageId,
                content: accumulatedContent,
                role: .assistant,
                timestamp: messages[existingIndex].timestamp,
                sessionId: sessionId
            )
        }

        messageBuffer = ""
        lastUpdateTime = Date()
    }

    private func handleStreamingError(_ errorMessage: String) {
        isStreaming = false
        streamingMessageId = nil
        
        setError(ErrorResponse(
            error: "streaming_error",
            message: "Streaming failed: \(errorMessage)",
            details: nil,
            timestamp: Date(),
            requestId: nil
        ))
    }
    
    private func setError(_ error: ErrorResponse) {
        self.error = error

        // Auto-clear error after 15 seconds (longer for users to read)
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
            if self.error?.timestamp == error.timestamp {
                self.error = nil
            }
        }
    }

    private func loadSessionData(sessionId: String) async {
        guard let claudeService = claudeService else { return }

        // Store current session ID
        currentSessionId = sessionId

        isLoading = true

        do {
            // Load the specific session metadata
            let sessionResponse = try await claudeService.getSession(sessionId: sessionId, userId: userId)

            await MainActor.run {
                self.currentSession = sessionResponse
                // Note: With Claude SDK session management, conversation history is maintained
                // by the SDK itself through session resumption. The UI starts fresh but
                // Claude will remember the conversation context when new messages are sent.
                self.messages = []
                self.isLoading = false
                print("✅ Loaded session \(sessionId) - conversation history maintained by Claude SDK")
            }
        } catch ClaudeServiceError.sessionNotFound {
            await MainActor.run {
                self.isLoading = false
                print("⚠️ Session \(sessionId) not found - creating new session")
                // Session doesn't exist, create a new one
                self.createInitialSessionIfNeeded()
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                print("⚠️ Failed to load session \(sessionId): \(error)")

                // Show error to user
                self.setError(ErrorResponse(
                    error: "session_load_failed",
                    message: "Could not load session: \(error.localizedDescription)",
                    details: nil,
                    timestamp: Date(),
                    requestId: nil
                ))

                // Try to create a new session as fallback
                self.createInitialSessionIfNeeded()
            }
        }
    }
}

// MARK: - Preview Helper

extension ConversationViewModel {
    static func preview() -> ConversationViewModel {
        let viewModel = ConversationViewModel()
        
        // Add sample messages for preview
        viewModel.messages = [
            ClaudeMessage(
                id: "1",
                content: "Hello! I'm Claude Code. How can I help you with your development work today?",
                role: .assistant,
                timestamp: Date().addingTimeInterval(-300),
                sessionId: "preview-session"
            ),
            ClaudeMessage(
                id: "2", 
                content: "Can you help me understand how to implement a SwiftUI navigation stack?",
                role: .user,
                timestamp: Date().addingTimeInterval(-200),
                sessionId: "preview-session"
            ),
            ClaudeMessage(
                id: "3",
                content: "I'd be happy to help you with SwiftUI navigation! Here's how you can implement a navigation stack...",
                role: .assistant,
                timestamp: Date().addingTimeInterval(-100),
                sessionId: "preview-session"
            )
        ]
        
        return viewModel
    }
}