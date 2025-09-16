//
//  MessageBubble.swift
//  Individual message display component with streaming support.
//
//  SwiftUI component for displaying individual Claude Code messages with support for 
//  real-time streaming, syntax highlighting, and mobile-optimized performance.
//

import SwiftUI

struct MessageBubble: View {
    
    // MARK: - Properties
    
    let message: ClaudeMessage
    let isStreaming: Bool
    
    @State private var animateInsertion: Bool = false
    
    // MARK: - Body
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == .user {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
                // Message Content
                messageContent
                
                // Message Metadata
                messageMetadata
            }
            
            if message.role == .assistant {
                Spacer(minLength: 50)
            }
        }
        .scaleEffect(animateInsertion ? 1.0 : 0.95)
        .opacity(animateInsertion ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                animateInsertion = true
            }
        }
    }
    
    // MARK: - Message Content
    
    private var messageContent: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 0) {
            // Role Avatar
            roleAvatar
            
            // Message Bubble
            messageBubble
        }
    }
    
    // MARK: - Role Avatar
    
    private var roleAvatar: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }

            Circle()
                .fill(avatarColor)
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: avatarIcon)
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .semibold))
                }

            if message.role == .assistant {
                Spacer()
            }
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - Message Bubble
    
    private var messageBubble: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isStreaming {
                StreamingText(content: message.content)
                    .padding(.horizontal, bubblePadding.horizontal)
                    .padding(.vertical, bubblePadding.vertical)
            } else {
                Text(message.content)
                    .font(messageFont)
                    .foregroundColor(messageForegroundColor)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, bubblePadding.horizontal)
                    .padding(.vertical, bubblePadding.vertical)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: bubbleCornerRadius)
                .fill(bubbleColor)
                .shadow(color: .black.opacity(bubbleShadowOpacity), radius: 2, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: bubbleCornerRadius)
                .stroke(bubbleBorderColor, lineWidth: 0.5)
        )
    }
    
    // MARK: - Message Metadata
    
    private var messageMetadata: some View {
        HStack(spacing: 8) {
            if message.role == .user {
                Spacer()
            }

            Text(formatTimestamp(message.timestamp))
                .font(.caption2)
                .foregroundColor(.secondary)

            // Show chunk type indicator for debugging (optional)
            if let chunkType = getChunkType() {
                Text("• \(chunkType)")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.6))
            }

            if message.role == .assistant {
                Spacer()
            }
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Computed Properties
    
    private var bubbleColor: Color {
        switch message.role {
        case .user:
            return Color.blue
        case .assistant:
            return Color(.secondarySystemGroupedBackground)
        case .system:
            return Color(.tertiarySystemGroupedBackground)
        }
    }
    
    private var bubbleBorderColor: Color {
        switch message.role {
        case .user:
            return Color.blue.opacity(0.3)
        case .assistant:
            return Color.secondary.opacity(0.2)
        case .system:
            return Color.secondary.opacity(0.1)
        }
    }

    private var avatarColor: Color {
        // Check if this is a thinking step with chunk type metadata
        if let chunkType = getChunkType() {
            switch chunkType {
            case "thinking":
                return Color.purple
            case "tool":
                return Color.orange
            case "assistant":
                return Color.green
            case "system":
                return Color.gray
            default:
                break
            }
        }

        // Default colors
        switch message.role {
        case .user:
            return Color.blue
        case .assistant:
            return Color.green
        case .system:
            return Color.gray
        }
    }

    private var avatarIcon: String {
        // Check if this is a thinking step with chunk type metadata
        if let chunkType = getChunkType() {
            switch chunkType {
            case "thinking":
                return "brain.head.profile"
            case "tool":
                return "wrench.and.screwdriver"
            case "assistant":
                return "message.fill"
            case "system":
                return "info.circle.fill"
            default:
                break
            }
        }

        // Default icons
        switch message.role {
        case .user:
            return "person.fill"
        case .assistant:
            return "brain.head.profile"
        case .system:
            return "info.circle.fill"
        }
    }

    private func getChunkType() -> String? {
        guard let metadata = message.metadata,
              let chunkTypeValue = metadata["chunk_type"],
              case .string(let chunkType) = chunkTypeValue else {
            return nil
        }
        return chunkType
    }

    // MARK: - Dynamic Styling Properties

    private var messageFont: Font {
        if let chunkType = getChunkType() {
            switch chunkType {
            case "tool", "system":
                return .caption // More compact for tool messages
            case "thinking":
                return .callout // Slightly smaller for thinking
            default:
                return .body
            }
        }
        return .body
    }

    private var messageForegroundColor: Color {
        if let chunkType = getChunkType() {
            switch chunkType {
            case "tool", "system":
                return .secondary // More subtle for tool messages
            case "thinking":
                return .primary.opacity(0.9) // Slightly muted for thinking
            default:
                return message.role == .user ? .white : .primary
            }
        }
        return message.role == .user ? .white : .primary
    }

    private var bubblePadding: (horizontal: CGFloat, vertical: CGFloat) {
        if let chunkType = getChunkType() {
            switch chunkType {
            case "tool", "system":
                return (12, 8) // More compact padding
            case "thinking":
                return (14, 10) // Slightly less padding
            default:
                return (16, 12) // Full padding for main messages
            }
        }
        return (16, 12)
    }

    private var bubbleCornerRadius: CGFloat {
        if let chunkType = getChunkType() {
            switch chunkType {
            case "tool", "system":
                return 12 // Smaller radius for subtle appearance
            default:
                return 16
            }
        }
        return 16
    }

    private var bubbleShadowOpacity: Double {
        if let chunkType = getChunkType() {
            switch chunkType {
            case "tool", "system":
                return 0.05 // Very subtle shadow
            case "thinking":
                return 0.08 // Slightly more than tool
            default:
                return 0.1 // Full shadow for main messages
            }
        }
        return 0.1
    }
    
    // MARK: - Helper Methods
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDate(date, inSameDayAs: Date()) {
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if calendar.isDate(date, inSameDayAs: Date().addingTimeInterval(-86400)) {
            return "Yesterday"
        } else {
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
}

// MARK: - Streaming Text Component

struct StreamingText: View {
    
    // MARK: - Properties
    
    let content: String
    @State private var visibleText: AttributedString = AttributedString()
    @State private var displayIndex: Int = 0
    @State private var streamTimer: Timer?
    
    // MARK: - Body
    
    var body: some View {
        Text(visibleText)
            .font(.body.monospaced()) // CRITICAL: Layout stability during streaming
            .multilineTextAlignment(.leading)
            .animation(nil) // Avoid withAnimation for typewriter effects - causes blending issues
            .onAppear {
                startStreaming()
            }
            .onDisappear {
                stopStreaming()
            }
            .onChange(of: content) { newContent in
                updateStreamingContent(newContent)
            }
    }
    
    // MARK: - Streaming Logic
    
    private func startStreaming() {
        streamTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { _ in
            updateVisibleText()
        }
    }
    
    private func stopStreaming() {
        streamTimer?.invalidate()
        streamTimer = nil
    }
    
    private func updateStreamingContent(_ newContent: String) {
        // Reset streaming when content changes
        displayIndex = 0
        visibleText = AttributedString()
        startStreaming()
    }
    
    private func updateVisibleText() {
        guard displayIndex < content.count else {
            stopStreaming()
            return
        }
        
        let endIndex = content.index(content.startIndex, offsetBy: min(displayIndex + 1, content.count))
        let currentText = String(content[content.startIndex..<endIndex])
        
        // PATTERN: AttributedString for performance vs character-by-character
        visibleText = AttributedString(currentText)
        displayIndex += 1
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        MessageBubble(
            message: ClaudeMessage(
                id: "1",
                content: "Hello! How can I help you with your code today?",
                role: .assistant,
                timestamp: Date(),
                sessionId: "session-1"
            ),
            isStreaming: false
        )
        
        MessageBubble(
            message: ClaudeMessage(
                id: "2",
                content: "Can you help me debug this Swift code?",
                role: .user,
                timestamp: Date(),
                sessionId: "session-1"
            ),
            isStreaming: false
        )
        
        MessageBubble(
            message: ClaudeMessage(
                id: "3",
                content: "I'd be happy to help you debug your Swift code. Please share the code you're working with...",
                role: .assistant,
                timestamp: Date(),
                sessionId: "session-1"
            ),
            isStreaming: true
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}