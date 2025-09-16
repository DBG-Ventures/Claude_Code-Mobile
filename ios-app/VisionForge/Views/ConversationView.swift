//
//  ConversationView.swift
//  Main chat interface with liquid glass effects and real-time streaming.
//
//  SwiftUI chat interface optimized for iPad with liquid glass visual effects and
//  performance-optimized streaming text display using AttributedString.
//

import SwiftUI
import Combine
import Network
import UIKit

struct ConversationView: View {

    // MARK: - Input Properties

    let sessionId: String

    // MARK: - State Properties

    @StateObject private var conversationViewModel = ConversationViewModel()
    @EnvironmentObject var networkManager: NetworkManager
    @EnvironmentObject var sessionListViewModel: SessionListViewModel
    @EnvironmentObject var sessionStateManager: SessionStateManager  // NEW: SessionManager integration
    @State private var messageText: String = ""
    @State private var isComposing: Bool = false
    @FocusState private var isInputFocused: Bool
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            LiquidGlassContainer {
                VStack(spacing: 0) {
                    // Navigation Header
                    navigationHeader

                    // Error Display
                    if let error = conversationViewModel.error {
                        errorBanner(error: error)
                    }

                    // Messages List
                    messagesScrollView(geometry: geometry)

                    // Processing Indicator (when streaming)
                    if conversationViewModel.isStreaming {
                        processingIndicator
                    }

                    // Input Area
                    messageInputArea
                }
            }
        }
        .navigationBarHidden(true)
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
    
    // MARK: - Navigation Header
    
    private var navigationHeader: some View {
        HStack {
            Button(action: {}) {
                Image(systemName: "sidebar.left")
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                Text("Claude Code")
                    .font(.headline)
                    .fontWeight(.semibold)

                // Network and SessionManager status indicators
                HStack(spacing: 12) {
                    // Network Status
                    HStack(spacing: 4) {
                        Circle()
                            .fill(networkManager.isNetworkAvailable ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(networkManager.isNetworkAvailable ? "Network" : "Offline")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // SessionManager Status
                    HStack(spacing: 4) {
                        Circle()
                            .fill(sessionManagerStatusColor)
                            .frame(width: 8, height: 8)
                        Text(sessionManagerStatusText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Button(action: {}) {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            .ultraThinMaterial,
            in: Rectangle()
        )
    }
    
    // MARK: - Messages Scroll View
    
    private func messagesScrollView(geometry: GeometryProxy) -> some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.vertical, showsIndicators: false) {
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
                .padding(.vertical, 16)
            }
            .onChange(of: conversationViewModel.messages.count) { _ in
                // Auto-scroll to latest message with animation
                if let lastMessage = conversationViewModel.messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        scrollProxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    // MARK: - Error Banner

    private func errorBanner(error: ErrorResponse) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)

                Text("Error")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: {
                    conversationViewModel.error = nil
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }

            Text(error.message)
                .font(.body)
                .foregroundColor(.primary)

            if !error.error.isEmpty {
                Text("Error type: \(error.error)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.orange.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.orange.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Processing Indicator

    private var processingIndicator: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                    .scaleEffect(0.8)

                Text("Claude is thinking...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Message Input Area

    private var messageInputArea: some View {
        HStack(alignment: .bottom, spacing: 12) {
            // Text Input Field
            HStack {
                TextField("Message Claude Code...", text: $messageText, axis: .vertical)
                    .focused($isInputFocused)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .lineLimit(1...5)
                    .onChange(of: messageText) { newValue in
                        isComposing = !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    }
                
                if !messageText.isEmpty {
                    Button(action: clearMessage) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.thickMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
            
            // Send Button
            Button(action: sendMessage) {
                Image(systemName: conversationViewModel.isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(canSendMessage ? .accentColor : .secondary)
            }
            .disabled(!canSendMessage)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            .regularMaterial,
            in: Rectangle()
        )
    }
    
    // MARK: - Computed Properties

    private var canSendMessage: Bool {
        return !conversationViewModel.isStreaming &&
               !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               networkManager.isNetworkAvailable
    }

    // SessionManager status indicators for navigation header
    private var sessionManagerStatusColor: Color {
        switch sessionStateManager.sessionManagerStatus {
        case .connected:
            return .green
        case .connecting:
            return .orange
        case .disconnected:
            return .red
        case .degraded:
            return .yellow
        case .error:
            return .red
        }
    }

    private var sessionManagerStatusText: String {
        switch sessionStateManager.sessionManagerStatus {
        case .connected:
            return "SessionMgr"
        case .connecting:
            return "Connecting"
        case .disconnected:
            return "Disconnected"
        case .degraded:
            return "Degraded"
        case .error:
            return "Error"
        }
    }
    
    // MARK: - Actions
    
    private func sendMessage() {
        guard canSendMessage else { return }
        
        let trimmedMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        conversationViewModel.sendMessage(trimmedMessage)
        
        // Clear input and hide keyboard
        messageText = ""
        isInputFocused = false
    }
    
    private func clearMessage() {
        messageText = ""
    }

    private func loadSessionFromViewModel() {
        // Legacy method: Load the session data from the backend (with messages)
        conversationViewModel.loadSession(sessionId: sessionId)
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

// MARK: - Liquid Glass Container

struct LiquidGlassContainer<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            // Background with liquid glass effect
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.blue.opacity(0.1),
                    Color.purple.opacity(0.05),
                    Color.clear
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Content with glass material background
            content
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 0)
                )
        }
        // Note: iOS 26+ liquid glass APIs are speculative
        // Using standard SwiftUI visual effects as fallback
        .background(Color(.systemBackground).opacity(0.9))
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