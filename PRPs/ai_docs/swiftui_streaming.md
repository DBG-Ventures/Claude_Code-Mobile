# SwiftUI Real-Time Streaming Patterns

## Overview

This document provides comprehensive patterns for implementing real-time streaming interfaces in SwiftUI, optimized for AI response display with liquid glass design effects and cross-platform compatibility.

## Core Streaming Architecture

### WebSocket Service Implementation

```swift
import Foundation
import Combine
import Starscream

@MainActor
class ClaudeStreamingService: NSObject, ObservableObject, WebSocketDelegate {
    @Published var connectionState: ConnectionState = .disconnected
    @Published var messages: [ClaudeMessage] = []
    @Published var currentStreamingText: String = ""

    private var socket: WebSocket?
    private let baseURL: String
    private var reconnectTimer: Timer?

    enum ConnectionState {
        case disconnected, connecting, connected, error(String)
    }

    init(baseURL: String) {
        self.baseURL = baseURL
        super.init()
        setupAppLifecycleHandling()
    }

    // CRITICAL: Handle app lifecycle for WebSocket connections
    private func setupAppLifecycleHandling() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.reconnectIfNeeded()
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.gracefulDisconnect()
        }
    }

    func connect() {
        guard socket == nil else { return }

        var request = URLRequest(url: URL(string: "\(baseURL)/claude/ws")!)
        request.timeoutInterval = 5

        socket = WebSocket(request: request)
        socket?.delegate = self
        socket?.connect()

        connectionState = .connecting
    }

    func sendQuery(_ query: String, sessionId: String) {
        guard socket?.isConnected == true else {
            connectionState = .error("Not connected")
            return
        }

        let message = ClaudeQuery(query: query, sessionId: sessionId)
        let encoder = JSONEncoder()

        do {
            let data = try encoder.encode(message)
            socket?.write(data: data)
        } catch {
            connectionState = .error("Failed to encode message: \(error)")
        }
    }

    // MARK: - WebSocketDelegate
    func didReceive(event: WebSocketEvent, client: WebSocket) {
        switch event {
        case .connected(let headers):
            connectionState = .connected
            print("WebSocket connected: \(headers)")

        case .disconnected(let reason, let code):
            connectionState = .disconnected
            print("WebSocket disconnected: \(reason) with code: \(code)")
            scheduleReconnect()

        case .text(let string):
            handleStreamingMessage(string)

        case .binary(let data):
            handleStreamingData(data)

        case .error(let error):
            connectionState = .error(error?.localizedDescription ?? "Unknown error")
            scheduleReconnect()

        default:
            break
        }
    }

    private func handleStreamingMessage(_ string: String) {
        guard let data = string.data(using: .utf8),
              let response = try? JSONDecoder().decode(StreamingResponse.self, from: data) else {
            return
        }

        switch response.type {
        case "delta":
            // CRITICAL: Use AttributedString for performance
            currentStreamingText += response.content

        case "complete":
            // Finalize message and add to history
            let finalMessage = ClaudeMessage(
                id: UUID().uuidString,
                content: currentStreamingText,
                role: .assistant,
                timestamp: Date(),
                sessionId: response.sessionId
            )
            messages.append(finalMessage)
            currentStreamingText = ""

        case "error":
            connectionState = .error(response.content)

        default:
            break
        }
    }
}
```

### Server-Sent Events Alternative (Recommended)

```swift
import Foundation
import Combine

@MainActor
class SSEClaudeService: ObservableObject {
    @Published var connectionState: ConnectionState = .disconnected
    @Published var messages: [ClaudeMessage] = []
    @Published var currentStreamingText: AttributedString = AttributedString()

    private var eventSource: URLSessionDataTask?
    private let session = URLSession.shared
    private let baseURL: String

    enum ConnectionState {
        case disconnected, connecting, connected, error(String)
    }

    init(baseURL: String) {
        self.baseURL = baseURL
    }

    func startStreaming(query: String, sessionId: String) {
        guard let url = URL(string: "\(baseURL)/claude/stream/\(sessionId)?query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") else {
            connectionState = .error("Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        connectionState = .connecting
        currentStreamingText = AttributedString() // Reset streaming text

        eventSource = session.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.handleSSEResponse(data: data, response: response, error: error)
            }
        }

        eventSource?.resume()
        connectionState = .connected
    }

    private func handleSSEResponse(data: Data?, response: URLResponse?, error: Error?) {
        if let error = error {
            connectionState = .error(error.localizedDescription)
            return
        }

        guard let data = data else { return }

        let string = String(data: data, encoding: .utf8) ?? ""
        let lines = string.components(separatedBy: .newlines)

        for line in lines {
            if line.hasPrefix("data: ") {
                let jsonString = String(line.dropFirst(6))
                handleStreamingJSON(jsonString)
            }
        }
    }

    private func handleStreamingJSON(_ jsonString: String) {
        guard let data = jsonString.data(using: .utf8),
              let response = try? JSONDecoder().decode(StreamingResponse.self, from: data) else {
            return
        }

        switch response.type {
        case "delta":
            // PERFORMANCE CRITICAL: AttributedString append for smooth streaming
            var newText = AttributedString(response.content)
            newText.font = .system(.body, design: .monospaced)
            currentStreamingText.append(newText)

        case "complete":
            finalizeMessage(sessionId: response.sessionId)

        case "error":
            connectionState = .error(response.content)

        default:
            break
        }
    }
}
```

## Performance-Optimized Text Streaming

### AttributedString Streaming Implementation

```swift
import SwiftUI

struct StreamingTextView: View {
    @State private var visibleText = AttributedString()
    @State private var fullText = AttributedString()
    let streamingText: String
    let isComplete: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(visibleText)
                        .textSelection(.enabled)
                        .monospaced() // CRITICAL: Layout stability during streaming
                        .animation(nil) // AVOID: withAnimation causes blending issues
                        .id("streaming-text")
                }
                .padding()
            }
            .onChange(of: streamingText) { _, newValue in
                updateStreamingText(newValue)

                // Auto-scroll to bottom during streaming
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo("streaming-text", anchor: .bottom)
                }
            }
        }
    }

    // PERFORMANCE PATTERN: Batch updates for smooth streaming
    private func updateStreamingText(_ newContent: String) {
        // Convert to AttributedString for performance
        var attributed = AttributedString(newContent)

        // Apply consistent styling
        attributed.font = .system(.body, design: .monospaced)
        attributed.foregroundColor = .primary

        // Syntax highlighting for code blocks (basic)
        if newContent.contains("```") {
            applySyntaxHighlighting(to: &attributed)
        }

        fullText = attributed

        // CRITICAL: Direct assignment instead of character-by-character animation
        visibleText = fullText
    }

    private func applySyntaxHighlighting(to text: inout AttributedString) {
        // Basic syntax highlighting for code blocks
        let codePattern = try! NSRegularExpression(pattern: "```[\\s\\S]*?```", options: [])
        let fullRange = NSRange(location: 0, length: text.description.count)

        let matches = codePattern.matches(in: text.description, options: [], range: fullRange)

        for match in matches {
            if let range = Range(match.range, in: text.description) {
                let attributeRange = range
                text[attributeRange].backgroundColor = Color.gray.opacity(0.1)
                text[attributeRange].font = .system(.body, design: .monospaced)
            }
        }
    }
}
```

### Typewriter Effect (Alternative Approach)

```swift
struct TypewriterTextView: View {
    @State private var visibleCharacterCount = 0
    @State private var typewriterTimer: Timer?

    let text: String
    let typingSpeed: TimeInterval = 0.03 // 30ms per character

    var body: some View {
        Text(String(text.prefix(visibleCharacterCount)))
            .monospaced()
            .onAppear {
                startTypewriterEffect()
            }
            .onChange(of: text) { _, _ in
                resetTypewriter()
            }
    }

    private func startTypewriterEffect() {
        typewriterTimer = Timer.scheduledTimer(withTimeInterval: typingSpeed, repeats: true) { _ in
            if visibleCharacterCount < text.count {
                visibleCharacterCount += 1
            } else {
                typewriterTimer?.invalidate()
                typewriterTimer = nil
            }
        }
    }

    private func resetTypewriter() {
        typewriterTimer?.invalidate()
        visibleCharacterCount = 0
        startTypewriterEffect()
    }
}
```

## Liquid Glass Integration

### Liquid Glass Container with Streaming

```swift
import SwiftUI

struct LiquidGlassConversationView: View {
    @StateObject private var claudeService = ClaudeStreamingService(baseURL: "ws://localhost:8000")
    @State private var currentQuery = ""

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background for liquid glass effects
                LinearGradient(
                    colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                // CRITICAL: GlassEffectContainer for coordinated glass elements
                GlassEffectContainer {
                    VStack(spacing: 20) {
                        // Message history with glass effect
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(claudeService.messages) { message in
                                    MessageBubbleView(message: message)
                                        .glassEffect() // iOS 26+ liquid glass
                                }

                                // Streaming message display
                                if !claudeService.currentStreamingText.isEmpty {
                                    StreamingMessageView(
                                        text: claudeService.currentStreamingText
                                    )
                                    .glassEffect()
                                    .glassEffectID("streaming", in: Namespace().wrappedValue)
                                }
                            }
                            .padding()
                        }
                        .frame(maxHeight: geometry.size.height * 0.7)

                        // Input area with glass effect
                        HStack {
                            TextField("Ask Claude Code...", text: $currentQuery)
                                .textFieldStyle(.roundedBorder)

                            Button("Send") {
                                sendQuery()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                        .glassEffect()
                        .glassEffectUnion() // Groups with other glass elements
                    }
                }
            }
        }
        .onAppear {
            claudeService.connect()
        }
    }

    private func sendQuery() {
        claudeService.sendQuery(currentQuery, sessionId: "main")
        currentQuery = ""
    }
}

struct MessageBubbleView: View {
    let message: ClaudeMessage

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }

            VStack(alignment: message.role == .user ? .trailing : .leading) {
                Text(message.content)
                    .padding()
                    .background(
                        message.role == .user
                        ? Color.blue.opacity(0.6)
                        : Color.gray.opacity(0.3)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .textSelection(.enabled)

                Text(message.timestamp.formatted(.dateTime.hour().minute()))
                    .font(.caption2)
                    .opacity(0.7)
            }

            if message.role == .assistant {
                Spacer()
            }
        }
    }
}

struct StreamingMessageView: View {
    let text: String

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                StreamingTextView(
                    streamingText: text,
                    isComplete: false
                )
                .padding()
                .background(Color.gray.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Claude is typing...")
                        .font(.caption2)
                        .opacity(0.7)
                }
            }
            Spacer()
        }
    }
}
```

## Session Management Integration

### Multi-Session SwiftUI Interface

```swift
import SwiftUI

struct SessionManagerView: View {
    @StateObject private var sessionManager = SessionManager()
    @State private var showingNewSessionSheet = false

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(sessionManager.sessions) { session in
                    NavigationLink(destination: ConversationView(session: session)) {
                        SessionRowView(session: session)
                    }
                }
                .onDelete(perform: deleteSessions)
            }
            .navigationTitle("Claude Sessions")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("New Session") {
                        showingNewSessionSheet = true
                    }
                }
            }
            .sheet(isPresented: $showingNewSessionSheet) {
                NewSessionView { sessionName in
                    sessionManager.createSession(name: sessionName)
                    showingNewSessionSheet = false
                }
            }

        } detail: {
            Text("Select a session")
                .foregroundColor(.secondary)
        }
    }

    private func deleteSessions(at offsets: IndexSet) {
        for offset in offsets {
            sessionManager.deleteSession(sessionManager.sessions[offset])
        }
    }
}

@MainActor
class SessionManager: ObservableObject {
    @Published var sessions: [Session] = []
    @Published var activeSession: Session?

    func createSession(name: String) {
        let newSession = Session(
            id: UUID().uuidString,
            name: name,
            messages: [],
            status: .active,
            lastUpdated: Date()
        )
        sessions.append(newSession)
        activeSession = newSession
    }

    func deleteSession(_ session: Session) {
        sessions.removeAll { $0.id == session.id }
        if activeSession?.id == session.id {
            activeSession = sessions.first
        }
    }
}
```

## Cross-Platform Adaptations

### Conditional Compilation for Platforms

```swift
import SwiftUI

struct ConversationView: View {
    let session: Session

    var body: some View {
        #if os(iOS)
        iOSConversationView(session: session)
        #elseif os(macOS)
        macOSConversationView(session: session)
        #elseif os(visionOS)
        visionOSConversationView(session: session)
        #endif
    }
}

// iPad-specific implementation
struct iOSConversationView: View {
    let session: Session

    var body: some View {
        LiquidGlassConversationView()
            .navigationTitle(session.name)
            .navigationBarTitleDisplayMode(.inline)
    }
}

// VisionOS spatial implementation
#if os(visionOS)
struct visionOSConversationView: View {
    let session: Session

    var body: some View {
        NavigationStack {
            ConversationContent()
                .navigationTitle(session.name)
                .toolbar {
                    ToolbarItemGroup(placement: .bottomOrnament) {
                        // VisionOS-specific controls
                        Button("Voice Input") { }
                        Button("Spatial View") { }
                    }
                }
        }
        .frame(minWidth: 800, minHeight: 600)
        .glassBackgroundEffect() // VisionOS glass effect
    }
}
#endif
```

## Performance Optimization

### Memory Management for Streaming

```swift
class StreamingTextManager: ObservableObject {
    @Published var displayText: AttributedString = AttributedString()

    private let maxBufferSize = 10000 // Characters
    private var textBuffer: String = ""

    func appendStreamingText(_ newText: String) {
        textBuffer += newText

        // Trim buffer if too large to prevent memory issues
        if textBuffer.count > maxBufferSize {
            let trimAmount = textBuffer.count - maxBufferSize
            textBuffer = String(textBuffer.dropFirst(trimAmount))
        }

        // Convert to AttributedString efficiently
        var attributed = AttributedString(textBuffer)
        attributed.font = .system(.body, design: .monospaced)

        displayText = attributed
    }

    func clearBuffer() {
        textBuffer = ""
        displayText = AttributedString()
    }
}
```

## Best Practices Summary

1. **Use AttributedString** for performance-optimized streaming text
2. **Avoid withAnimation** for typewriter effects - causes blending issues
3. **Prefer Server-Sent Events** over WebSockets for unidirectional streaming
4. **Handle app lifecycle** properly for WebSocket connections
5. **Use monospaced fonts** for layout stability during streaming
6. **Implement proper error handling** and reconnection logic
7. **Optimize memory usage** with text buffer management
8. **Use liquid glass effects judiciously** - performance impact on streaming
9. **Test on actual hardware** - iPad Pro M1+ required for optimal performance
10. **Implement graceful degradation** when liquid glass APIs unavailable

## Common Pitfalls to Avoid

- Don't use character-by-character animations - performance killer
- Don't ignore WebSocket lifecycle management - causes connection issues
- Don't skip AttributedString optimization - impacts streaming performance
- Don't overuse liquid glass effects - can hurt real-time performance
- Don't forget cross-platform conditional compilation
- Don't skip proper error handling for network failures
- Don't ignore memory management for long streaming sessions

This document provides comprehensive patterns for implementing high-performance streaming interfaces in SwiftUI with liquid glass design integration.