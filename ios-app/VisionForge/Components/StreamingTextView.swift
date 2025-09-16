//
//  StreamingTextView.swift
//  Smooth text animation component for streaming Claude responses.
//
//  Provides typewriter-style animations with optimized performance for long streaming text.
//  Uses AttributedString for efficient rendering and smooth character-by-character reveal.
//

import SwiftUI
import Combine

// MARK: - Streaming Text View

struct StreamingTextView: View {
    let fullText: String
    let isStreaming: Bool
    let animationSpeed: Double

    @State private var visibleText: AttributedString = AttributedString("")
    @State private var animationTask: Task<Void, Never>?
    @State private var lastCharacterIndex: Int = 0

    // Animation configuration
    private let charactersPerBatch = 3  // Number of characters to add per animation frame
    private let baseDelay: TimeInterval = 0.03  // Base delay between batches

    init(
        text: String,
        isStreaming: Bool = false,
        animationSpeed: Double = 1.0
    ) {
        self.fullText = text
        self.isStreaming = isStreaming
        self.animationSpeed = max(0.1, min(animationSpeed, 5.0))  // Clamp speed
    }

    var body: some View {
        Text(visibleText)
            .font(.system(.body, design: .monospaced))
            .textSelection(.enabled)
            .onChange(of: fullText) { oldValue, newValue in
                if isStreaming {
                    updateStreamingText(oldText: oldValue, newText: newValue)
                } else {
                    // Show full text immediately when not streaming
                    visibleText = AttributedString(newValue)
                    lastCharacterIndex = newValue.count
                }
            }
            .onChange(of: isStreaming) { _, newValue in
                if !newValue {
                    // Streaming ended, show remaining text immediately
                    finishAnimation()
                }
            }
            .onAppear {
                if isStreaming && !fullText.isEmpty {
                    startAnimation(from: 0)
                } else {
                    visibleText = AttributedString(fullText)
                    lastCharacterIndex = fullText.count
                }
            }
            .onDisappear {
                animationTask?.cancel()
            }
    }

    // MARK: - Animation Methods

    private func updateStreamingText(oldText: String, newText: String) {
        guard isStreaming else {
            visibleText = AttributedString(newText)
            lastCharacterIndex = newText.count
            return
        }

        // Check if text was appended (common case)
        if newText.hasPrefix(oldText) {
            // Continue animation from where we left off
            if lastCharacterIndex < newText.count {
                continueAnimation(to: newText.count)
            }
        } else {
            // Text changed completely, restart animation
            animationTask?.cancel()
            visibleText = AttributedString("")
            lastCharacterIndex = 0
            startAnimation(from: 0)
        }
    }

    private func startAnimation(from startIndex: Int) {
        animationTask?.cancel()

        animationTask = Task {
            await animateText(from: startIndex)
        }
    }

    private func continueAnimation(to endIndex: Int) {
        // Don't restart if already animating
        guard animationTask == nil || animationTask?.isCancelled == true else {
            return
        }

        animationTask = Task {
            await animateText(from: lastCharacterIndex)
        }
    }

    private func animateText(from startIndex: Int) async {
        let text = fullText
        let textArray = Array(text)
        let adjustedDelay = baseDelay / animationSpeed

        for index in stride(from: startIndex, to: textArray.count, by: charactersPerBatch) {
            guard !Task.isCancelled else { break }

            let endIndex = min(index + charactersPerBatch, textArray.count)
            let substring = String(textArray[0..<endIndex])

            await MainActor.run {
                updateVisibleText(substring, currentIndex: endIndex)
            }

            // Dynamic delay based on content
            let delay = calculateDelay(for: textArray, at: index, baseDelay: adjustedDelay)

            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            } catch {
                break
            }
        }

        // Ensure full text is visible at the end
        await MainActor.run {
            finishAnimation()
        }
    }

    private func updateVisibleText(_ text: String, currentIndex: Int) {
        // Create styled attributed string with proper formatting
        var attributed = AttributedString(text)

        // Apply monospace font for code-like appearance
        attributed.font = .system(.body, design: .monospaced)

        // Add subtle fade-in effect for new characters
        if lastCharacterIndex < currentIndex && currentIndex <= text.count {
            let fadeRange = text.index(text.startIndex, offsetBy: max(0, lastCharacterIndex))..<text.index(text.startIndex, offsetBy: currentIndex)
            if let attributedRange = Range(fadeRange, in: attributed) {
                attributed[attributedRange].foregroundColor = .primary.opacity(0.9)
            }
        }

        visibleText = attributed
        lastCharacterIndex = currentIndex
    }

    private func calculateDelay(for textArray: [Character], at index: Int, baseDelay: TimeInterval) -> TimeInterval {
        guard index < textArray.count else { return baseDelay }

        let character = textArray[index]

        // Add natural pauses at punctuation
        switch character {
        case ".", "!", "?":
            return baseDelay * 3.0  // Longer pause at sentence end
        case ",", ";", ":":
            return baseDelay * 2.0  // Medium pause at clause breaks
        case "\n":
            return baseDelay * 2.5  // Pause at line breaks
        default:
            return baseDelay
        }
    }

    private func finishAnimation() {
        animationTask?.cancel()
        visibleText = AttributedString(fullText)
        lastCharacterIndex = fullText.count
    }
}

// MARK: - Streaming Message Bubble

struct StreamingMessageBubble: View {
    let message: ClaudeMessage
    let isStreaming: Bool

    @State private var showThinkingIndicator = false
    @State private var opacity: Double = 0

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == .assistant {
                assistantAvatar
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                if isStreaming && showThinkingIndicator {
                    ThinkingIndicator()
                        .padding(.bottom, 4)
                }

                StreamingTextView(
                    text: message.content,
                    isStreaming: isStreaming,
                    animationSpeed: 1.2
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(bubbleBackground)
                .clipShape(BubbleShape(isUser: message.role == .user))

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }

            if message.role == .user {
                userAvatar
            }
        }
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeIn(duration: 0.3)) {
                opacity = 1
            }

            if isStreaming && message.role == .assistant {
                showThinkingIndicator = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation {
                        showThinkingIndicator = false
                    }
                }
            }
        }
    }

    private var assistantAvatar: some View {
        Circle()
            .fill(LinearGradient(
                colors: [.blue, .cyan],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .frame(width: 32, height: 32)
            .overlay(
                Image(systemName: "cpu")
                    .foregroundColor(.white)
                    .font(.system(size: 16))
            )
    }

    private var userAvatar: some View {
        Circle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: 32, height: 32)
            .overlay(
                Image(systemName: "person.fill")
                    .foregroundColor(.gray)
                    .font(.system(size: 16))
            )
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        if message.role == .user {
            Color.blue.opacity(0.15)
        } else {
            Color(.systemBackground)
                .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
        }
    }
}

// MARK: - Bubble Shape

struct BubbleShape: Shape {
    let isUser: Bool

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 16
        let tailSize: CGFloat = 8

        var path = Path()

        if isUser {
            // User bubble (right-aligned with tail on right)
            path.move(to: CGPoint(x: radius, y: 0))
            path.addLine(to: CGPoint(x: rect.width - radius - tailSize, y: 0))
            path.addArc(
                center: CGPoint(x: rect.width - radius - tailSize, y: radius),
                radius: radius,
                startAngle: .degrees(-90),
                endAngle: .degrees(0),
                clockwise: false
            )

            // Tail
            path.addLine(to: CGPoint(x: rect.width - tailSize, y: radius))
            path.addQuadCurve(
                to: CGPoint(x: rect.width, y: radius + tailSize),
                control: CGPoint(x: rect.width - tailSize/2, y: radius)
            )
            path.addLine(to: CGPoint(x: rect.width - tailSize, y: radius + tailSize))

            path.addLine(to: CGPoint(x: rect.width - tailSize, y: rect.height - radius))
            path.addArc(
                center: CGPoint(x: rect.width - radius - tailSize, y: rect.height - radius),
                radius: radius,
                startAngle: .degrees(0),
                endAngle: .degrees(90),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: radius, y: rect.height))
            path.addArc(
                center: CGPoint(x: radius, y: rect.height - radius),
                radius: radius,
                startAngle: .degrees(90),
                endAngle: .degrees(180),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: 0, y: radius))
            path.addArc(
                center: CGPoint(x: radius, y: radius),
                radius: radius,
                startAngle: .degrees(180),
                endAngle: .degrees(270),
                clockwise: false
            )
        } else {
            // Assistant bubble (standard rounded rectangle)
            path = Path(roundedRect: rect, cornerRadius: radius)
        }

        return path
    }
}

// MARK: - Thinking Indicator

struct ThinkingIndicator: View {
    @State private var animationAmount = 0.0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.blue.opacity(0.6))
                    .frame(width: 8, height: 8)
                    .scaleEffect(animationAmount)
                    .opacity(2 - animationAmount)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.2),
                        value: animationAmount
                    )
            }
        }
        .onAppear {
            animationAmount = 2
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        StreamingTextView(
            text: "Hello! I'm Claude, your AI assistant. How can I help you today?",
            isStreaming: true,
            animationSpeed: 1.0
        )
        .padding()

        StreamingMessageBubble(
            message: ClaudeMessage(
                id: "1",
                content: "This is a streaming message that will animate character by character.",
                role: .assistant,
                timestamp: Date(),
                sessionId: "preview"
            ),
            isStreaming: true
        )
        .padding()
    }
}