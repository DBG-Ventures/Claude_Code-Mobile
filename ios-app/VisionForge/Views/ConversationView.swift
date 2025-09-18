//
//  ConversationView.swift
//  Main chat interface with floating liquid glass elements.
//
//  Implements liquid glass design using iOS 26 glassEffect modifier
//  following Apple's guidelines for floating functional layers.
//

import SwiftUI
import Combine
import Network
import UIKit

struct ConversationView: View {

    // MARK: - Input Properties

    let sessionId: String

    // MARK: - State Properties

    @State private var conversationViewModel = ConversationViewModel()
    @Environment(NetworkManager.self) var networkManager
    @Environment(SessionListViewModel.self) var sessionListViewModel
    @Environment(SessionStateManager.self) var sessionStateManager
    @State private var messageText: String = ""
    @State private var isComposing: Bool = false
    @FocusState private var isInputFocused: Bool
    @State private var scrollProxy: ScrollViewProxy?

    // MARK: - Body

    var body: some View {
        ZStack {
            // Base layer: Messages that scroll edge-to-edge
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 16) {
                        ForEach(conversationViewModel.messages) { message in
                            MessageBubble(
                                message: message,
                                isStreaming: conversationViewModel.isStreaming &&
                                            message.id == conversationViewModel.streamingMessageId
                            )
                            .id(message.id)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .background(Color(.systemBackground))
                .onAppear {
                    scrollProxy = proxy
                }
                .onChange(of: conversationViewModel.messages.count) {
                    // Auto-scroll to latest message with animation
                    if let lastMessage = conversationViewModel.messages.last {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Floating layer with glass effects
            VStack {
                // Top header bar with glass effect - anchored to top edge
                GlassEffectContainer {
                    HStack {
                        // Left spacer for center alignment
                        Spacer()

                        // Centered header component mimicking Messages app
                        ConversationHeaderView(
                            sessionName: getCurrentSessionName(),
                            status: sessionStateManager.sessionManagerStatus
                        )

                        // Right spacer and action button
                        Spacer()

                        // Action button with glass effect
                        Button(action: clearConversation) {
                            Image(systemName: "trash")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .frame(width: 52, height: 52)
                                .glassEffect(.clear.tint(.secondary.opacity(0.1)), in: Circle())
                        }
                        .disabled(conversationViewModel.messages.isEmpty)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                    .padding(.top, 30)
                }
                .ignoresSafeArea(edges: .top)

                // Error banner (appears above input when needed)
                if let error = conversationViewModel.error {
                    errorBanner(error: error)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                }
                
                Spacer()

                // Processing indicator (when streaming)
                if conversationViewModel.isStreaming {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)

                        Text("Claude is thinking...")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 4)
                    .transition(.opacity)
                }

                // Bottom input area with glass effect - properly anchored to bottom edge
                GlassEffectContainer {
                    HStack(alignment: .bottom, spacing: 12) {
                        // Text Input Field with glass effect only (no overlay)
                        HStack {
                            TextField("Message", text: $messageText, axis: .vertical)
                                .textFieldStyle(.plain)
                                .font(.body)
                                .lineLimit(1...6)
                                .focused($isInputFocused)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                        }
                        .glassEffect(
                            .clear.tint(Color(.systemGray5).opacity(0.2)),
                            in: RoundedRectangle(cornerRadius: 20)
                        )
                        .onSubmit {
                            if canSendMessage {
                                sendMessage()
                            }
                        }

                        // Send Button with glass effect
                        Button(action: sendMessage) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(canSendMessage ? .white : Color(.systemGray3))
                                .frame(width: 34, height: 34)
                                .background(
                                    Circle()
                                        .fill(canSendMessage ? Color.blue : Color.clear)
                                )
                                .glassEffect(
                                    canSendMessage ? .clear.tint(.blue.opacity(0.1)) : .regular,
                                    in: Circle()
                                )
                        }
                        .disabled(!canSendMessage)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 5)
                }
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .onAppear {
            setupConversationIntegration()
            loadSessionWithSessionManager()
        }
        .onChange(of: sessionId) { oldValue, newValue in
            // Optimized session switching using SessionManager persistent sessions
            Task {
                do {
                    try await sessionStateManager.switchToSession(newValue)
                    loadSessionWithSessionManager()
                } catch {
                    print("⚠️ Failed to switch to session: \(error)")
                }
            }
        }
    }

    // MARK: - Error Banner

    private func errorBanner(error: ErrorResponse) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)

            Text(error.message)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(2)

            Spacer()

            Button(action: {
                conversationViewModel.error = nil
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.orange.opacity(0.1))
                .strokeBorder(.orange.opacity(0.3), lineWidth: 0.5)
        )
    }

    // MARK: - Computed Properties

    private var canSendMessage: Bool {
        return !conversationViewModel.isStreaming &&
               !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               networkManager.isNetworkAvailable
    }


    // MARK: - Actions

    private func sendMessage() {
        guard canSendMessage else { return }

        let trimmedMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        conversationViewModel.sendMessage(trimmedMessage)

        // Clear input
        messageText = ""
    }

    private func clearConversation() {
        // TODO: Implement clear conversation
        print("Clear conversation - not yet implemented")
    }

    private func getCurrentSessionName() -> String {
        // Get session name from SessionStateManager
        if let session = sessionStateManager.activeSessions.first(where: { $0.sessionId == sessionId }) {
            return session.sessionName ?? "Untitled"
        }
        return "Session"
    }

    // MARK: - SessionManager Integration Methods

    private func setupConversationIntegration() {
        // Initialize ConversationViewModel with SessionStateManager integration
        conversationViewModel.setClaudeService(networkManager.claudeService)
        conversationViewModel.setSessionStateManager(sessionStateManager)

        print("✅ ConversationView SessionManager integration initialized")
    }

    private func loadSessionWithSessionManager() {
        // Load session using SessionManager with conversation history and context preservation
        Task {
            // Ensure SessionStateManager has this session in its active sessions
            if !sessionStateManager.activeSessions.contains(where: { $0.sessionId == sessionId }) {
                // Session not in SessionManager cache, trigger load
                do {
                    try await sessionStateManager.refreshSessionsFromBackend()
                } catch {
                    print("⚠️ Failed to refresh sessions: \(error)")
                }
            }

            // Load conversation through enhanced ConversationViewModel with SessionManager context
            conversationViewModel.loadSession(sessionId: sessionId)
        }
    }
}


// MARK: - Preview

#Preview {
    NavigationView {
        ConversationView(sessionId: "preview-session")
            .environmentObject(NetworkManager())
            .environmentObject(SessionListViewModel())
            .environmentObject(SessionStateManager(
                claudeService: ClaudeService(baseURL: URL(string: "http://localhost:8000")!),
                persistenceService: SessionPersistenceService()
            ))
    }
}
