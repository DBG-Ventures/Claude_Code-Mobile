//
//  DummyData.swift
//  VisionForge
//
//  Dummy data for testing liquid glass effects with realistic content
//

import Foundation

struct DummyData {

    // MARK: - Dummy Sessions
    static let dummySessions: [SessionResponse] = [
        SessionResponse(
            sessionId: "session-1",
            userId: "user-1",
            sessionName: "SwiftUI Liquid Glass Implementation",
            status: .active,
            messages: [
                ClaudeMessage(
                    id: "msg-1-1",
                    content: "How do I implement the new iOS 26 liquid glass effects?",
                    role: .user,
                    timestamp: Date().addingTimeInterval(-3600),
                    sessionId: "session-1",
                    metadata: [:]
                ),
                ClaudeMessage(
                    id: "msg-1-2",
                    content: "To implement iOS 26 liquid glass effects, use the new `.glassEffect()` modifier...",
                    role: .assistant,
                    timestamp: Date().addingTimeInterval(-3500),
                    sessionId: "session-1",
                    metadata: [:]
                )
            ],
            createdAt: Date().addingTimeInterval(-7200),
            updatedAt: Date().addingTimeInterval(-3500),
            messageCount: 2,
            context: [:]
        ),
        SessionResponse(
            sessionId: "session-2",
            userId: "user-1",
            sessionName: "FastAPI Backend Development",
            status: .active,
            messages: [
                ClaudeMessage(
                    id: "msg-2-1",
                    content: "Can you help me set up a FastAPI server with WebSocket support?",
                    role: .user,
                    timestamp: Date().addingTimeInterval(-86400),
                    sessionId: "session-2",
                    metadata: [:]
                )
            ],
            createdAt: Date().addingTimeInterval(-86400),
            updatedAt: Date().addingTimeInterval(-86400),
            messageCount: 1,
            context: [:]
        ),
        SessionResponse(
            sessionId: "session-3",
            userId: "user-1",
            sessionName: "Core Data Integration",
            status: .completed,
            messages: [],
            createdAt: Date().addingTimeInterval(-172800),
            updatedAt: Date().addingTimeInterval(-172800),
            messageCount: 15,
            context: [:]
        ),
        SessionResponse(
            sessionId: "session-4",
            userId: "user-1",
            sessionName: "Machine Learning Model Training",
            status: .active,
            messages: [],
            createdAt: Date().addingTimeInterval(-259200),
            updatedAt: Date().addingTimeInterval(-200000),
            messageCount: 23,
            context: [:]
        ),
        SessionResponse(
            sessionId: "session-5",
            userId: "user-1",
            sessionName: "API Authentication Strategies",
            status: .paused,
            messages: [],
            createdAt: Date().addingTimeInterval(-345600),
            updatedAt: Date().addingTimeInterval(-300000),
            messageCount: 8,
            context: [:]
        ),
        SessionResponse(
            sessionId: "session-6",
            userId: "user-1",
            sessionName: "Database Schema Design",
            status: .completed,
            messages: [],
            createdAt: Date().addingTimeInterval(-432000),
            updatedAt: Date().addingTimeInterval(-400000),
            messageCount: 12,
            context: [:]
        ),
        SessionResponse(
            sessionId: "session-7",
            userId: "user-1",
            sessionName: "React Native Performance Optimization",
            status: .active,
            messages: [],
            createdAt: Date().addingTimeInterval(-518400),
            updatedAt: Date().addingTimeInterval(-500000),
            messageCount: 19,
            context: [:]
        ),
        SessionResponse(
            sessionId: "session-8",
            userId: "user-1",
            sessionName: "Docker Container Configuration",
            status: .completed,
            messages: [],
            createdAt: Date().addingTimeInterval(-604800),
            updatedAt: Date().addingTimeInterval(-600000),
            messageCount: 7,
            context: [:]
        ),
        SessionResponse(
            sessionId: "session-9",
            userId: "user-1",
            sessionName: "GraphQL Schema Implementation",
            status: .active,
            messages: [],
            createdAt: Date().addingTimeInterval(-691200),
            updatedAt: Date().addingTimeInterval(-650000),
            messageCount: 31,
            context: [:]
        ),
        SessionResponse(
            sessionId: "session-10",
            userId: "user-1",
            sessionName: "AWS Lambda Functions",
            status: .error,
            messages: [],
            createdAt: Date().addingTimeInterval(-777600),
            updatedAt: Date().addingTimeInterval(-700000),
            messageCount: 5,
            context: [:]
        ),
        SessionResponse(
            sessionId: "session-11",
            userId: "user-1",
            sessionName: "Kubernetes Deployment Strategy",
            status: .active,
            messages: [],
            createdAt: Date().addingTimeInterval(-864000),
            updatedAt: Date().addingTimeInterval(-800000),
            messageCount: 14,
            context: [:]
        ),
        SessionResponse(
            sessionId: "session-12",
            userId: "user-1",
            sessionName: "Redis Cache Implementation",
            status: .completed,
            messages: [],
            createdAt: Date().addingTimeInterval(-950400),
            updatedAt: Date().addingTimeInterval(-900000),
            messageCount: 9,
            context: [:]
        )
    ]

    // MARK: - Dummy Messages
    static let dummyMessages: [ClaudeMessage] = [
        ClaudeMessage(
            id: "msg-1",
            content: "Hello! I need help implementing the new iOS 26 liquid glass effects in my SwiftUI app. Can you guide me through the process?",
            role: .user,
            timestamp: Date().addingTimeInterval(-600),
            sessionId: "session-1",
            metadata: [:]
        ),
        ClaudeMessage(
            id: "msg-2",
            content: "I'd be happy to help you implement iOS 26's liquid glass effects! The key is using the new `.glassEffect()` modifier and `GlassEffectContainer` for optimal performance.\n\nHere's how to get started:\n\n1. **Basic Glass Effect**\n```swift\nView()\n    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))\n```\n\n2. **Multiple Glass Effects**\nWhen applying multiple glass effects in the same area, use `GlassEffectContainer`:\n```swift\nGlassEffectContainer {\n    // Your content with glass effects\n}\n```\n\n3. **Important**: Avoid using `.ultraThinMaterial` or `.regularMaterial` - these are the old approach and not part of the liquid glass design system.",
            role: .assistant,
            timestamp: Date().addingTimeInterval(-550),
            sessionId: "session-1",
            metadata: [:]
        ),
        ClaudeMessage(
            id: "msg-3",
            content: "That makes sense! How do I make the glass elements float above my content like in the Messages app?",
            role: .user,
            timestamp: Date().addingTimeInterval(-500),
            sessionId: "session-1",
            metadata: [:]
        ),
        ClaudeMessage(
            id: "msg-4",
            content: "Great question! To achieve the floating effect like in Messages, you need to use a `ZStack` architecture:\n\n```swift\nZStack {\n    // Base layer: Your scrollable content\n    ScrollView {\n        // Messages, sessions, etc.\n    }\n    \n    // Floating layer: Glass elements\n    VStack {\n        // Top floating header\n        headerView\n            .glassEffect(.regular, in: Rectangle())\n        \n        Spacer()\n        \n        // Bottom floating input\n        inputArea\n            .glassEffect(.regular, in: Rectangle())\n    }\n}\n```\n\nThe key principles:\n- Content extends edge-to-edge\n- Glass elements create a distinct functional layer\n- Add padding to your scroll content to account for floating elements",
            role: .assistant,
            timestamp: Date().addingTimeInterval(-450),
            sessionId: "session-1",
            metadata: [:]
        ),
        ClaudeMessage(
            id: "msg-5",
            content: "What about performance? I noticed the documentation mentions something about combining glass effects?",
            role: .user,
            timestamp: Date().addingTimeInterval(-400),
            sessionId: "session-1",
            metadata: [:]
        ),
        ClaudeMessage(
            id: "msg-6",
            content: "Excellent observation! Performance is crucial when using liquid glass effects. Here's how to optimize:\n\n**Use GlassEffectContainer for Multiple Effects:**\n```swift\nGlassEffectContainer {\n    HStack {\n        Button(\"Action 1\")\n            .glassEffect(.regular, in: Capsule())\n        \n        Button(\"Action 2\")\n            .glassEffect(.regular, in: Capsule())\n    }\n}\n.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))\n```\n\nThis combines the effects efficiently and prevents performance issues.\n\n**Best Practices:**\n- Don't overuse glass effects - apply sparingly to key functional elements\n- Test with accessibility settings (Reduce Transparency)\n- Monitor frame rates on older devices\n- The glass dynamically adapts to content beneath it",
            role: .assistant,
            timestamp: Date().addingTimeInterval(-350),
            sessionId: "session-1",
            metadata: [:]
        ),
        ClaudeMessage(
            id: "msg-7",
            content: "Can you show me a complete example of a chat interface with proper liquid glass implementation?",
            role: .user,
            timestamp: Date().addingTimeInterval(-300),
            sessionId: "session-1",
            metadata: [:]
        ),
        ClaudeMessage(
            id: "msg-8",
            content: "Here's a complete example of a chat interface with proper liquid glass implementation:\n\n```swift\nstruct ChatView: View {\n    @State private var messageText = \"\"\n    @State private var messages: [Message] = []\n    \n    var body: some View {\n        ZStack {\n            // Base: Scrollable messages\n            ScrollView {\n                LazyVStack(spacing: 12) {\n                    // Top padding for header\n                    Color.clear.frame(height: 60)\n                    \n                    ForEach(messages) { message in\n                        MessageBubble(message: message)\n                    }\n                    \n                    // Bottom padding for input\n                    Color.clear.frame(height: 80)\n                }\n                .padding(.horizontal)\n            }\n            .background(Color(.systemBackground))\n            \n            // Floating glass layers\n            VStack {\n                // Header\n                GlassEffectContainer {\n                    HStack {\n                        Text(\"Chat\")\n                            .font(.headline)\n                        Spacer()\n                        Button(action: {}) {\n                            Image(systemName: \"ellipsis\")\n                                .glassEffect(.regular, in: Circle())\n                        }\n                    }\n                    .padding()\n                }\n                .glassEffect(.regular, in: Rectangle())\n                \n                Spacer()\n                \n                // Input area\n                GlassEffectContainer {\n                    HStack {\n                        TextField(\"Message\", text: $messageText)\n                            .textFieldStyle(.plain)\n                            .padding(8)\n                            .background(Color(.secondarySystemBackground))\n                            .clipShape(Capsule())\n                        \n                        Button(action: sendMessage) {\n                            Image(systemName: \"arrow.up.circle.fill\")\n                                .font(.title)\n                                .glassEffect(.regular, in: Circle())\n                        }\n                    }\n                    .padding()\n                }\n                .glassEffect(.regular, in: Rectangle())\n            }\n        }\n    }\n}\n```",
            role: .assistant,
            timestamp: Date().addingTimeInterval(-250),
            sessionId: "session-1",
            metadata: [:]
        ),
        ClaudeMessage(
            id: "msg-9",
            content: "This is really helpful! What about dark mode? Does the glass effect adapt automatically?",
            role: .user,
            timestamp: Date().addingTimeInterval(-200),
            sessionId: "session-1",
            metadata: [:]
        ),
        ClaudeMessage(
            id: "msg-10",
            content: "Yes! One of the beautiful aspects of liquid glass is its automatic adaptation to different contexts:\n\n**Automatic Adaptations:**\n- **Dark/Light Mode**: Glass effects automatically adjust their appearance\n- **Content Behind**: The glass dynamically responds to what's beneath it\n- **Accessibility**: Respects Reduce Transparency settings\n- **Device Capabilities**: Optimizes for different hardware\n\n**No Manual Adjustments Needed:**\n```swift\n// This automatically works in both light and dark mode\n.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))\n```\n\n**Testing Different Modes:**\n1. Toggle between light/dark in Settings\n2. Test with different wallpapers/backgrounds\n3. Enable Reduce Transparency to ensure fallback\n4. Test on various devices (iPhone 12+ has full effects)\n\nThe system handles all the visual adjustments, maintaining legibility and visual hierarchy automatically. This is why it's important to use `.glassEffect()` instead of custom materials - you get all these adaptations for free!",
            role: .assistant,
            timestamp: Date().addingTimeInterval(-150),
            sessionId: "session-1",
            metadata: [:]
        ),
        ClaudeMessage(
            id: "msg-11",
            content: "Perfect! One last question - are there different glass styles I can use?",
            role: .user,
            timestamp: Date().addingTimeInterval(-100),
            sessionId: "session-1",
            metadata: [:]
        ),
        ClaudeMessage(
            id: "msg-12",
            content: "Yes, there are several glass styles available with different visual characteristics:\n\n**Glass Styles:**\n```swift\n// Standard glass\n.glassEffect(.regular, in: shape)\n\n// Glass with tint\n.glassEffect(.clear.tint(.blue.opacity(0.1)), in: shape)\n\n// Multiple styles in iOS 26:\n.glass           // Standard glass\n.glassProminent  // More prominent glass\n.glass(_:)       // Custom glass configuration\n```\n\n**Tinting Glass:**\n```swift\n// Subtle blue tint for buttons\nButton(\"Action\")\n    .glassEffect(.clear.tint(.blue.opacity(0.1)), in: Capsule())\n\n// Red tint for destructive actions\nButton(\"Delete\")\n    .glassEffect(.clear.tint(.red.opacity(0.1)), in: RoundedRectangle(cornerRadius: 8))\n```\n\n**Shape Options:**\n```swift\n// Different shapes\n.glassEffect(.regular, in: Circle())\n.glassEffect(.regular, in: Capsule())\n.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))\n.glassEffect(.regular, in: Rectangle())\n```\n\nRemember: Less is more! Use glass effects strategically on functional elements to maintain focus on content.",
            role: .assistant,
            timestamp: Date().addingTimeInterval(-50),
            sessionId: "session-1",
            metadata: [:]
        )
    ]
}
