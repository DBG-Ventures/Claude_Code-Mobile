# Refactoring Implementation Examples

## Example 1: Extracting MessageStreamingService

### Before (ConversationViewModel - 117 lines in one function)
```swift
private func startStreamingResponseWithSessionManager(query: String, sessionId: String) {
    // 117 lines of complex streaming logic
    // Mixed responsibilities: streaming, UI updates, error handling
    // Nested closures, switch statements, buffer management
}
```

### After - Step 1: Create Protocol
```swift
// File: Protocols/MessageStreamingServiceProtocol.swift
import Foundation

@MainActor
protocol MessageStreamingServiceProtocol {
    var isStreaming: Bool { get }
    var currentStreamId: String? { get }

    func startStreaming(
        query: String,
        sessionId: String,
        claudeService: ClaudeService
    ) -> AsyncStream<StreamingEvent>

    func stopStreaming()
}

enum StreamingEvent {
    case started(messageId: String)
    case chunk(content: String, messageId: String)
    case completed(finalContent: String, messageId: String)
    case error(Error)
}
```

### After - Step 2: Implement Service
```swift
// File: Services/Conversation/MessageStreamingService.swift
import Foundation
import Observation

@MainActor
@Observable
final class MessageStreamingService: MessageStreamingServiceProtocol {

    private(set) var isStreaming = false
    private(set) var currentStreamId: String?
    private var streamTask: Task<Void, Never>?

    func startStreaming(
        query: String,
        sessionId: String,
        claudeService: ClaudeService
    ) -> AsyncStream<StreamingEvent> {
        stopStreaming() // Cancel any existing stream

        return AsyncStream { continuation in
            streamTask = Task { [weak self] in
                guard let self else { return }

                self.isStreaming = true
                let messageId = UUID().uuidString
                self.currentStreamId = messageId

                continuation.yield(.started(messageId: messageId))

                do {
                    let stream = try await claudeService.streamQueryToSessionManager(
                        query: query,
                        sessionId: sessionId,
                        userId: "mobile-user"
                    )

                    for try await chunk in stream {
                        if Task.isCancelled { break }

                        switch chunk {
                        case .sessionUpdate(let response):
                            await self.handleSessionUpdate(response, continuation: continuation)
                        case .messageDelta(let delta):
                            continuation.yield(.chunk(
                                content: delta.content,
                                messageId: messageId
                            ))
                        case .messageComplete(let message):
                            continuation.yield(.completed(
                                finalContent: message.content,
                                messageId: messageId
                            ))
                        case .error(let error):
                            continuation.yield(.error(error))
                        }
                    }
                } catch {
                    continuation.yield(.error(error))
                }

                self.isStreaming = false
                self.currentStreamId = nil
                continuation.finish()
            }
        }
    }

    func stopStreaming() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        currentStreamId = nil
    }

    private func handleSessionUpdate(
        _ response: SessionManagerResponse,
        continuation: AsyncStream<StreamingEvent>.Continuation
    ) async {
        // Handle session updates separately
        // This was previously mixed into the main streaming logic
    }
}
```

### After - Step 3: Refactored ConversationViewModel
```swift
// File: ViewModels/ConversationViewModel.swift
@MainActor
@Observable
class ConversationViewModel {

    // Dependencies injected via constructor
    private let streamingService: MessageStreamingServiceProtocol
    private let bufferService: MessageBufferServiceProtocol
    private let stateManager: ConversationStateManagerProtocol

    init(
        streamingService: MessageStreamingServiceProtocol,
        bufferService: MessageBufferServiceProtocol,
        stateManager: ConversationStateManagerProtocol
    ) {
        self.streamingService = streamingService
        self.bufferService = bufferService
        self.stateManager = stateManager
    }

    func sendMessage(_ content: String) {
        // Add user message
        let userMessage = ClaudeMessage(
            id: UUID().uuidString,
            content: content,
            role: .user,
            timestamp: Date()
        )
        stateManager.addMessage(userMessage)

        // Start streaming response
        Task {
            await handleStreaming(query: content)
        }
    }

    private func handleStreaming(query: String) async {
        let stream = streamingService.startStreaming(
            query: query,
            sessionId: currentSessionId,
            claudeService: claudeService
        )

        for await event in stream {
            switch event {
            case .started(let messageId):
                let assistantMessage = ClaudeMessage(
                    id: messageId,
                    content: "",
                    role: .assistant,
                    timestamp: Date()
                )
                stateManager.addMessage(assistantMessage)

            case .chunk(let content, let messageId):
                bufferService.bufferMessage(content)
                if bufferService.shouldFlush() {
                    let buffered = bufferService.flushBuffer()
                    stateManager.updateMessage(id: messageId, content: buffered)
                }

            case .completed(let finalContent, let messageId):
                bufferService.clearBuffer()
                stateManager.updateMessage(id: messageId, content: finalContent)

            case .error(let error):
                handleError(error)
            }
        }
    }
}
```

---

## Example 2: Creating MessageBufferService

### Before (Mixed into ConversationViewModel)
```swift
// Scattered throughout ConversationViewModel
private var messageBuffer: String = ""
private var bufferTimer: Timer?
private let bufferUpdateInterval: TimeInterval = 0.1
private let maxBufferSize = 500
```

### After: Dedicated Buffer Service
```swift
// File: Services/Conversation/MessageBufferService.swift
import Foundation
import Combine

@MainActor
final class MessageBufferService: MessageBufferServiceProtocol {

    private var buffer = ""
    private var timer: Timer?
    private let updateInterval: TimeInterval
    private let maxSize: Int
    private let updateHandler: (String) -> Void

    init(
        updateInterval: TimeInterval = 0.1,
        maxSize: Int = 500,
        updateHandler: @escaping (String) -> Void
    ) {
        self.updateInterval = updateInterval
        self.maxSize = maxSize
        self.updateHandler = updateHandler
    }

    func startBuffering() {
        stopBuffering()

        timer = Timer.scheduledTimer(
            withTimeInterval: updateInterval,
            repeats: true
        ) { [weak self] _ in
            self?.flushIfNeeded()
        }
    }

    func bufferMessage(_ content: String) {
        buffer.append(content)

        if buffer.count >= maxSize {
            flush()
        }
    }

    func shouldFlush() -> Bool {
        return buffer.count >= maxSize
    }

    func flushBuffer() -> String {
        let content = buffer
        buffer = ""
        return content
    }

    func flush() {
        guard !buffer.isEmpty else { return }
        let content = flushBuffer()
        updateHandler(content)
    }

    func stopBuffering() {
        timer?.invalidate()
        timer = nil
        flush() // Flush any remaining content
    }

    private func flushIfNeeded() {
        if !buffer.isEmpty {
            flush()
        }
    }

    deinit {
        stopBuffering()
    }
}
```

---

## Example 3: Mock Implementation for Testing

```swift
// File: Tests/Mocks/MockMessageStreamingService.swift
import Foundation
@testable import VisionForge

final class MockMessageStreamingService: MessageStreamingServiceProtocol {

    var isStreaming = false
    var currentStreamId: String?

    // Test control properties
    var shouldSucceed = true
    var chunksToStream: [String] = []
    var errorToThrow: Error?
    var startStreamingCallCount = 0
    var stopStreamingCallCount = 0

    func startStreaming(
        query: String,
        sessionId: String,
        claudeService: ClaudeService
    ) -> AsyncStream<StreamingEvent> {
        startStreamingCallCount += 1

        return AsyncStream { continuation in
            Task {
                if let error = errorToThrow {
                    continuation.yield(.error(error))
                    continuation.finish()
                    return
                }

                let messageId = "test-message-id"
                continuation.yield(.started(messageId: messageId))

                for chunk in chunksToStream {
                    try? await Task.sleep(for: .milliseconds(10))
                    continuation.yield(.chunk(content: chunk, messageId: messageId))
                }

                let finalContent = chunksToStream.joined()
                continuation.yield(.completed(
                    finalContent: finalContent,
                    messageId: messageId
                ))
                continuation.finish()
            }
        }
    }

    func stopStreaming() {
        stopStreamingCallCount += 1
        isStreaming = false
        currentStreamId = nil
    }
}
```

---

## Example 4: Unit Test with Mock

```swift
// File: Tests/Services/MessageStreamingServiceTests.swift
import XCTest
import Testing
@testable import VisionForge

@Test("Streaming service processes chunks correctly")
func testStreamingChunks() async {
    // Arrange
    let mockService = MockMessageStreamingService()
    mockService.chunksToStream = ["Hello", " ", "World", "!"]

    let mockClaude = MockClaudeService()

    var receivedEvents: [StreamingEvent] = []

    // Act
    let stream = mockService.startStreaming(
        query: "test query",
        sessionId: "test-session",
        claudeService: mockClaude
    )

    for await event in stream {
        receivedEvents.append(event)
    }

    // Assert
    #expect(receivedEvents.count == 6) // started + 4 chunks + completed
    #expect(mockService.startStreamingCallCount == 1)

    if case .completed(let content, _) = receivedEvents.last {
        #expect(content == "Hello World!")
    } else {
        Issue.record("Expected completed event")
    }
}

@Test("Buffer service flushes at max size")
func testBufferMaxSizeFlush() async {
    // Arrange
    var flushedContent = ""
    let buffer = MessageBufferService(
        updateInterval: 1.0, // Long interval to test size-based flush
        maxSize: 10,
        updateHandler: { content in
            flushedContent = content
        }
    )

    // Act
    buffer.startBuffering()
    buffer.bufferMessage("12345")
    #expect(flushedContent.isEmpty) // Not flushed yet

    buffer.bufferMessage("67890") // Should trigger flush at 10 chars

    // Assert
    #expect(flushedContent == "1234567890")
}
```

---

## Example 5: Dependency Injection Setup

```swift
// File: VisionForgeApp.swift
import SwiftUI

@main
struct VisionForgeApp: App {

    // Service container
    let serviceContainer = ServiceContainer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(serviceContainer.makeConversationViewModel())
        }
    }
}

// File: Services/ServiceContainer.swift
@MainActor
final class ServiceContainer {

    // Lazy initialization of services
    private lazy var streamingService = MessageStreamingService()

    private lazy var bufferService = MessageBufferService { [weak self] content in
        // Update handler implementation
    }

    private lazy var stateManager = ConversationStateManager()

    private lazy var sessionRepository = SessionRepository(
        claudeService: claudeService,
        persistenceService: persistenceService,
        cacheManager: cacheManager,
        syncService: syncService,
        lifecycleManager: lifecycleManager
    )

    // Factory method for ViewModel
    func makeConversationViewModel() -> ConversationViewModel {
        return ConversationViewModel(
            streamingService: streamingService,
            bufferService: bufferService,
            stateManager: stateManager
        )
    }

    // For testing - inject mocks
    func makeTestConversationViewModel(
        streamingService: MessageStreamingServiceProtocol? = nil,
        bufferService: MessageBufferServiceProtocol? = nil,
        stateManager: ConversationStateManagerProtocol? = nil
    ) -> ConversationViewModel {
        return ConversationViewModel(
            streamingService: streamingService ?? MockMessageStreamingService(),
            bufferService: bufferService ?? MockMessageBufferService(),
            stateManager: stateManager ?? MockConversationStateManager()
        )
    }
}
```

## Key Refactoring Patterns Used

### 1. **Protocol-Driven Design**
- Every service has a protocol
- Enables easy mocking for tests
- Allows runtime swapping of implementations

### 2. **Constructor Injection**
- All dependencies passed via init
- No hidden dependencies
- Testable by design

### 3. **Single Responsibility**
- Each service does ONE thing
- StreamingService: manages streaming
- BufferService: manages buffering
- StateManager: manages state

### 4. **Async/Await Patterns**
- Modern Swift concurrency
- Proper cancellation support
- No completion handler pyramids

### 5. **Observable State**
- Using @Observable for reactive UI
- Clean state propagation
- SwiftUI integration

## Migration Strategy

### Step 1: Add New Services (No Breaking Changes)
1. Create new service files
2. Implement protocols
3. Add tests for new services
4. Services exist alongside old code

### Step 2: Gradual Integration
1. Add feature flag: `useRefactoredStreaming`
2. Inject new services into ViewModel
3. Route calls through new services when flag enabled
4. A/B test with subset of users

### Step 3: Complete Migration
1. Remove old code once validated
2. Remove feature flags
3. Clean up unused imports
4. Update documentation

This approach ensures zero downtime and safe rollback at any point.