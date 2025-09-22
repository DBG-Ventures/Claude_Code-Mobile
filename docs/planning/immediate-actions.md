# Immediate Refactoring Actions - Quick Start Guide

## 🚀 Day 1: Mock Infrastructure (4 hours)

### Task 1.1: Create Base Mock Protocol
```bash
# Create mock infrastructure directory
mkdir -p ios-app/VisionForgeTests/Mocks
```

### Task 1.2: MockClaudeService
```swift
// File: ios-app/VisionForgeTests/Mocks/MockClaudeService.swift
import Foundation
@testable import VisionForge

final class MockClaudeService: ClaudeServiceProtocol {
    // Control test behavior
    var shouldSucceed = true
    var streamChunks: [StreamChunk] = []
    var errorToReturn: Error?

    // Tracking
    var createSessionCallCount = 0
    var streamQueryCallCount = 0

    func streamQueryToSessionManager(
        query: String,
        sessionId: String,
        userId: String
    ) async throws -> AsyncStream<StreamChunk> {
        streamQueryCallCount += 1

        if let error = errorToReturn {
            throw error
        }

        return AsyncStream { continuation in
            Task {
                for chunk in streamChunks {
                    continuation.yield(chunk)
                    try? await Task.sleep(for: .milliseconds(10))
                }
                continuation.finish()
            }
        }
    }
}
```

### Task 1.3: Create First Test
```swift
// File: ios-app/VisionForgeTests/ConversationViewModelTests.swift
import Testing
@testable import VisionForge

@Test("ConversationViewModel sends message successfully")
func testSendMessage() async {
    // Arrange
    let mockClaude = MockClaudeService()
    mockClaude.streamChunks = [
        .messageDelta(MessageDelta(content: "Hello")),
        .messageDelta(MessageDelta(content: " World")),
        .messageComplete(ClaudeMessage(content: "Hello World", role: .assistant))
    ]

    let viewModel = ConversationViewModel()
    viewModel.setClaudeService(mockClaude)

    // Act
    viewModel.sendMessage("Test query")
    try? await Task.sleep(for: .milliseconds(100))

    // Assert
    #expect(viewModel.messages.count == 2)
    #expect(viewModel.messages[0].role == .user)
    #expect(viewModel.messages[1].role == .assistant)
}
```

---

## 🎯 Day 2: Extract MessageStreamingService (3 hours)

### Task 2.1: Create Service Protocol
```bash
# Create conversation services directory
mkdir -p ios-app/VisionForge/Services/Conversation
```

```swift
// File: ios-app/VisionForge/Services/Protocols/MessageStreamingServiceProtocol.swift
@MainActor
protocol MessageStreamingServiceProtocol {
    var isStreaming: Bool { get }
    func startStreaming(query: String, sessionId: String, claudeService: ClaudeService) -> AsyncStream<StreamingEvent>
    func stopStreaming()
}
```

### Task 2.2: Move Streaming Logic
1. Copy the 117-line `startStreamingResponseWithSessionManager` function
2. Create new `MessageStreamingService.swift`
3. Break into 5 smaller functions:
   - `startStreaming()` - Main entry point (20 lines)
   - `handleStreamStart()` - Initialize streaming (15 lines)
   - `processStreamChunk()` - Process each chunk (20 lines)
   - `handleStreamComplete()` - Finalize stream (15 lines)
   - `handleStreamError()` - Error handling (10 lines)

### Task 2.3: Update ConversationViewModel
```swift
// Add property
private let streamingService: MessageStreamingServiceProtocol

// Update sendMessage to use service
func sendMessage(_ content: String) {
    Task {
        let stream = streamingService.startStreaming(
            query: content,
            sessionId: currentSessionId,
            claudeService: claudeService
        )

        for await event in stream {
            handleStreamEvent(event)
        }
    }
}
```

---

## ✅ Day 3: Validate & Test (2 hours)

### Task 3.1: Run Existing Tests
```bash
# Ensure nothing broke
xcodebuild test -scheme VisionForge -sdk iphonesimulator
```

### Task 3.2: Add Service Tests
```swift
@Test("MessageStreamingService handles chunks correctly")
func testStreamingService() async {
    // Test the new service in isolation
    let service = MessageStreamingService()
    let mockClaude = MockClaudeService()
    // ... test implementation
}
```

### Task 3.3: Performance Test
```swift
@Test("Streaming doesn't cause excessive UI updates")
func testStreamingPerformance() async {
    // Measure UI update frequency
    // Should be < 10 updates per second
}
```

---

## 📋 Checklist for Success

### Before Starting
- [ ] Create Git branch: `git checkout -b refactor/conversation-viewmodel`
- [ ] Commit current state: `git commit -am "Checkpoint before refactoring"`
- [ ] Run tests to establish baseline

### Day 1 Completion
- [ ] MockClaudeService created
- [ ] MockSessionRepository created
- [ ] First test passing
- [ ] No production code changed yet

### Day 2 Completion
- [ ] MessageStreamingService extracted
- [ ] ConversationViewModel updated
- [ ] All tests still passing
- [ ] Streaming function < 50 lines

### Day 3 Completion
- [ ] Service tests added
- [ ] Performance validated
- [ ] Documentation updated
- [ ] PR created for review

---

## 🎮 Quick Commands

### Build & Test
```bash
# Quick build check
xcodebuild -scheme VisionForge -configuration Debug build

# Run tests
xcodebuild test -scheme VisionForge -sdk iphonesimulator

# Run specific test
xcodebuild test -scheme VisionForge -only-testing:VisionForgeTests/ConversationViewModelTests
```

### Code Quality
```bash
# Check for long functions
rg "func.*\{" ios-app/ --files-with-matches | xargs wc -l | sort -n

# Find god classes
find ios-app -name "*.swift" -exec wc -l {} \; | sort -n | tail -10

# Check test coverage
xcodebuild test -scheme VisionForge -enableCodeCoverage YES
```

### Git Workflow
```bash
# Feature branch
git checkout -b refactor/conversation-viewmodel

# Incremental commits
git add -p  # Stage chunks interactively
git commit -m "refactor: extract MessageStreamingService from ConversationViewModel"

# Push for review
git push origin refactor/conversation-viewmodel
```

---

## 🚨 Risk Mitigation

### Feature Flag Setup
```swift
// File: ios-app/VisionForge/Config/FeatureFlags.swift
struct FeatureFlags {
    static let useRefactoredStreaming = ProcessInfo.processInfo.environment["USE_REFACTORED_STREAMING"] == "true"
}

// In ConversationViewModel
func sendMessage(_ content: String) {
    if FeatureFlags.useRefactoredStreaming {
        // New implementation
        sendMessageWithNewService(content)
    } else {
        // Old implementation
        sendMessageWithSessionManager(content)
    }
}
```

### Rollback Plan
```bash
# If something breaks
git reset --hard HEAD~1  # Undo last commit
git checkout main        # Return to stable
```

### Monitoring
- Watch for crash reports
- Monitor streaming performance
- Check memory usage doesn't increase
- Validate UI update frequency

---

## 💡 Pro Tips

1. **Start Small**: Extract one service at a time
2. **Test First**: Write test before refactoring
3. **Keep Old Code**: Don't delete until new is proven
4. **Incremental PRs**: Small, reviewable changes
5. **Document Why**: Explain refactoring rationale

## Next Week Preview

After completing Days 1-3:
- **Day 4-5**: Extract MessageBufferService
- **Day 6-7**: Extract ConversationStateManager
- **Day 8-9**: Complete ConversationViewModel refactoring
- **Day 10**: Performance optimization and benchmarking

Start with Day 1 tasks immediately - the mock infrastructure enables everything else!