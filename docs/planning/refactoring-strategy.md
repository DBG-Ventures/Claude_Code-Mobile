# iOS App Strategic Refactoring Plan

**Date**: January 21, 2025
**Objective**: Transform god classes into modular, testable architecture while maintaining functionality

## Executive Summary

After comprehensive analysis, the iOS app shows excellent Swift 6.2 adoption (95/100) but suffers from architectural debt with two god classes (ConversationViewModel: 673 lines, SessionRepository: 625 lines) and critical testing gaps (15/100 coverage). This plan outlines a strategic, incremental approach to refactoring.

## Current State Analysis

### Strengths to Preserve
- ✅ Modern @Observable pattern throughout
- ✅ Excellent protocol usage (6 protocols defined)
- ✅ Partial modularization in SessionRepository (3 extracted services)
- ✅ Good dependency injection patterns
- ✅ Zero force unwrapping, modern async/await

### Critical Issues
1. **ConversationViewModel God Class** (673 lines, 34 functions)
   - Handles 5+ responsibilities: UI state, streaming, buffering, session management, error handling
   - 117-line streaming function violates all clean code principles
   - Performance issues: excessive UI updates, memory churn

2. **SessionRepository Complexity** (625 lines, 28 functions)
   - Better structured but still too large
   - Already partially refactored with 3 extracted services
   - Blocking initialization loop

3. **Testing Crisis** (15/100 score)
   - Zero tests on critical components
   - No mock infrastructure
   - 193 async functions untested

## Strategic Refactoring Approach

### Core Principles
1. **Incremental Transformation**: Never break working functionality
2. **Test-First Migration**: Add tests before refactoring critical paths
3. **Protocol-Driven Design**: Use protocols for all new services
4. **Dependency Injection**: Constructor-based injection throughout
5. **Single Responsibility**: Each service handles one concern

## Phase-by-Phase Execution Plan

### Phase 1: Foundation & Testing Infrastructure (Week 1)
**Goal**: Create testing foundation before major refactoring

#### 1.1 Mock Architecture (4h)
```swift
// Create comprehensive mock implementations
MockClaudeService: ClaudeServiceProtocol
MockSessionRepository: SessionRepositoryProtocol
MockNetworkClient: NetworkClientProtocol
```

#### 1.2 Critical Component Tests (6h)
- ConversationViewModel basic tests (prevent regression)
- SessionRepository core operations
- KeychainManager security tests

**Deliverables**:
- 12 mock implementations
- 30% test coverage on critical paths
- CI/CD test validation

---

### Phase 2: ConversationViewModel Decomposition (Week 2)
**Goal**: Break down the 673-line god class into focused services

#### 2.1 Extract Message Streaming Service (3h)
```swift
// New service: MessageStreamingService.swift
protocol MessageStreamingServiceProtocol {
    func startStreaming(query: String, sessionId: String) -> AsyncStream<StreamChunk>
    func stopStreaming()
    func handleStreamChunk(_ chunk: StreamChunk) async
}

class MessageStreamingService: MessageStreamingServiceProtocol {
    // Extract 117-line streaming function
    // Break into 5 focused methods
    // Implement proper cancellation
}
```

#### 2.2 Extract Message Buffer Service (2h)
```swift
// New service: MessageBufferService.swift
protocol MessageBufferServiceProtocol {
    func bufferMessage(_ content: String)
    func flushBuffer() -> String
    func startBuffering(updateInterval: TimeInterval)
}

class MessageBufferService: MessageBufferServiceProtocol {
    // Extract buffering logic
    // Fix timer retain cycles with [weak self]
    // Optimize with 100ms batch updates
}
```

#### 2.3 Extract Conversation State Manager (3h)
```swift
// New service: ConversationStateManager.swift
protocol ConversationStateManagerProtocol {
    var messages: [ClaudeMessage] { get }
    func addMessage(_ message: ClaudeMessage)
    func updateMessage(id: String, content: String)
    func clearMessages()
}

@Observable
class ConversationStateManager: ConversationStateManagerProtocol {
    // Pure state management
    // Message CRUD operations
    // Efficient lookup with Dictionary
}
```

#### 2.4 Refactor ConversationViewModel (2h)
```swift
// Reduced ConversationViewModel.swift (~150 lines)
@Observable
class ConversationViewModel {
    // Dependencies via constructor injection
    private let streamingService: MessageStreamingServiceProtocol
    private let bufferService: MessageBufferServiceProtocol
    private let stateManager: ConversationStateManagerProtocol
    private let repository: SessionRepositoryProtocol

    // Pure UI coordination
    // Delegate to services
    // No business logic
}
```

**Deliverables**:
- 3 new focused services with protocols
- ConversationViewModel reduced to 150 lines
- All streaming logic properly decomposed

---

### Phase 3: SessionRepository Optimization (Week 3)
**Goal**: Complete modularization of SessionRepository

#### 3.1 Extract Session Query Service (2h)
```swift
// New service: SessionQueryService.swift
protocol SessionQueryServiceProtocol {
    func getActiveSessions() -> [SessionManagerResponse]
    func getRecentSessions(since: Date) -> [SessionManagerResponse]
    func searchSessions(query: String) -> [SessionManagerResponse]
}
```

#### 3.2 Extract Session Statistics Service (2h)
```swift
// New service: SessionStatisticsService.swift
protocol SessionStatisticsServiceProtocol {
    func getSessionStats(sessionId: String) -> SessionStatistics
    func getTotalMessageCount() -> Int
    func getAverageSessionDuration() -> TimeInterval
}
```

#### 3.3 Refactor SessionRepository (2h)
```swift
// Reduced SessionRepository.swift (~200 lines)
class SessionRepository: SessionRepositoryProtocol {
    // Pure orchestration
    // Delegate all operations to services
    // Maintain protocol compliance
}
```

**Deliverables**:
- 2 additional extracted services
- SessionRepository reduced to 200 lines
- Complete separation of concerns

---

### Phase 4: Performance Optimization (Week 4)
**Goal**: Fix identified performance bottlenecks

#### 4.1 Streaming Performance (2h)
- Implement message accumulation buffer
- Batch UI updates every 100ms
- Reduce message bubble creation

#### 4.2 Memory Management (2h)
- Fix all timer retain cycles
- Optimize message lookup with Dictionary
- Reduce object creation in loops

#### 4.3 Async Optimization (1h)
- Replace blocking loops with continuations
- Implement proper task cancellation
- Add timeout handling

**Deliverables**:
- 50% reduction in UI updates during streaming
- Zero retain cycles
- No main thread blocking

---

### Phase 5: Comprehensive Testing (Week 5)
**Goal**: Achieve 80% test coverage on business logic

#### 5.1 Unit Test Suite (8h)
- Test all new services
- Async function testing
- Error scenario coverage

#### 5.2 Integration Tests (4h)
- Service interaction tests
- Data flow validation
- Session lifecycle tests

#### 5.3 UI Tests (3h)
- Conversation flow tests
- Session management tests
- Error handling UI

**Deliverables**:
- 80% coverage on business logic
- All async functions tested
- Complete mock infrastructure

---

## Risk Mitigation Strategy

### Incremental Safety
1. **Feature Flags**: Gate each refactoring behind flags
2. **Parallel Implementation**: Keep old code until new is validated
3. **Rollback Points**: Git tags at each phase completion
4. **Monitoring**: Track performance metrics and error rates

### Validation Checkpoints
- ✅ After each service extraction: Run full test suite
- ✅ After ViewModel refactoring: UI smoke tests
- ✅ After optimization: Performance benchmarks
- ✅ Weekly: Full regression testing

## Success Metrics

### Architecture Quality
- [ ] No files > 500 lines
- [ ] No functions > 50 lines
- [ ] All services < 200 lines
- [ ] 100% protocol usage for services

### Performance
- [ ] Streaming UI updates < 10/second
- [ ] Memory usage stable during streaming
- [ ] App launch < 1 second
- [ ] No main thread blocking

### Testing
- [ ] 80% business logic coverage
- [ ] 100% critical path coverage
- [ ] All async functions tested
- [ ] Complete mock infrastructure

## Implementation Order Priority

### Critical Path (Do First)
1. **Mock Infrastructure** - Enables safe refactoring
2. **MessageStreamingService** - Fixes performance issues
3. **ConversationStateManager** - Core functionality
4. **Basic Tests** - Prevent regression

### High Priority
5. **MessageBufferService** - Performance optimization
6. **ConversationViewModel refactoring** - Architecture improvement
7. **Async optimization** - Remove blocking operations

### Medium Priority
8. **SessionRepository optimization** - Already partially done
9. **Additional services** - Nice to have
10. **Comprehensive testing** - Long-term maintenance

## Code Organization Structure

```
ios-app/VisionForge/
├── Services/
│   ├── Conversation/
│   │   ├── MessageStreamingService.swift
│   │   ├── MessageBufferService.swift
│   │   └── ConversationStateManager.swift
│   ├── Session/
│   │   ├── SessionCacheManager.swift (existing)
│   │   ├── SessionSyncService.swift (existing)
│   │   ├── SessionLifecycleManager.swift (existing)
│   │   ├── SessionQueryService.swift (new)
│   │   └── SessionStatisticsService.swift (new)
│   └── Protocols/
│       ├── MessageStreamingServiceProtocol.swift
│       ├── MessageBufferServiceProtocol.swift
│       └── ConversationStateManagerProtocol.swift
├── ViewModels/
│   └── ConversationViewModel.swift (reduced)
└── Tests/
    ├── Mocks/
    ├── Services/
    └── ViewModels/
```

## Next Immediate Actions

1. **Create Mock Infrastructure** (Today)
   - Start with MockClaudeService
   - Add MockSessionRepository
   - Enable dependency injection

2. **Extract MessageStreamingService** (Tomorrow)
   - Move streaming logic
   - Break down 117-line function
   - Add proper error handling

3. **Add First Tests** (Day 3)
   - Test new streaming service
   - Validate refactoring didn't break functionality
   - Establish testing pattern

## Conclusion

This strategic plan transforms the codebase from monolithic god classes to a modular, testable architecture while maintaining functionality throughout. The incremental approach minimizes risk while the test-first strategy ensures quality.

Total effort: ~65 hours over 5 weeks
Risk level: Low (incremental approach)
Business impact: Minimal (feature flags)
Long-term benefit: High (maintainability, testability, performance)

Start with Phase 1 immediately to establish the testing foundation that enables safe refactoring.