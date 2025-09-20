name: "Claude Service & SessionRepository Comprehensive Refactoring"
description: |
  Refactor ClaudeService.swift (865 lines) and SessionRepository.swift (708 lines) into modular, protocol-based architecture with files under 500 lines each, eliminating tight coupling and clarifying responsibilities.

---

## Goal

**Feature Goal**: Transform monolithic service architecture into modular, protocol-based design with clear separation of concerns and improved testability

**Deliverable**: Refactored service layer with 14 focused modules, each under 500 lines, following SOLID principles and Swift best practices

**Success Definition**: All existing functionality preserved, files under 500 lines, zero circular dependencies, passing all tests, improved testability through protocol abstractions

## User Persona

**Target User**: iOS Developer maintaining the Claude Code Mobile app

**Use Case**: Extending functionality, fixing bugs, and maintaining the codebase without navigating 800+ line files

**User Journey**: Developer can easily locate specific functionality, modify isolated components, and test individual modules without side effects

**Pain Points Addressed**:
- Difficulty navigating massive service files
- Tight coupling preventing independent testing
- Business logic mixed with networking concerns
- Unclear separation of responsibilities

## Why

- **Current ClaudeService.swift**: 865 lines violating CLAUDE.md's 500-line limit
- **Current SessionRepository.swift**: 708 lines exhibiting "God Object" anti-pattern
- **Tight coupling** prevents proper unit testing and mocking
- **Mixed concerns** violate Single Responsibility Principle
- **Business logic in wrong layer** breaks clean architecture patterns

## What

Decompose monolithic services into focused, testable modules following iOS best practices:

### Success Criteria

- [ ] All files under 500 lines (per CLAUDE.md requirements)
- [ ] Protocol-based architecture enabling dependency injection
- [ ] Business logic properly separated from networking
- [ ] All existing functionality preserved
- [ ] Tests passing with new architecture
- [ ] No circular dependencies between modules

## All Needed Context

### Context Completeness Check

_This PRP contains complete file paths, line numbers, patterns to follow, and architectural guidance enabling implementation without prior codebase knowledge._

### Documentation & References

```yaml
# MUST READ - Include these in your context window
- url: https://nalexn.github.io/clean-architecture-swiftui/#layers-and-data-flow
  why: Clean architecture pattern for SwiftUI apps - follow the repository and service separation
  critical: Repository handles business logic, Service handles pure networking

- url: https://www.avanderlee.com/swift/repository-design-pattern/
  why: Repository pattern implementation in Swift with protocol abstractions
  critical: Protocol-first design with async/await methods

- url: https://developer.apple.com/videos/play/wwdc2015/408/
  why: Apple's Protocol-Oriented Programming in Swift (WWDC) - fundamental POP patterns
  critical: Start with protocols, use protocol extensions for default implementations

- file: ios-app/VisionForge/Services/SessionRepository.swift
  why: Existing repository pattern implementation to follow
  pattern: Lines 14-21 show SessionRepositoryProtocol pattern, lines 85-93 show DI pattern
  gotcha: Keep @MainActor and @Observable annotations for SwiftUI compatibility

- file: ios-app/VisionForge/Services/SessionPersistenceService.swift
  why: Example of properly scoped service with protocol
  pattern: Lines 59-112 show protocol definition and implementation structure
  gotcha: Services use @MainActor for thread safety

- file: ios-app/VisionForge/Utils/PreviewEnvironment.swift
  why: Mock object creation pattern for testing
  pattern: Lines 23-39 show dependency injection setup for SwiftUI
  gotcha: Preview environment needs full dependency graph
```

### Current Codebase tree

```bash
ios-app/VisionForge/
├── Services/
│   ├── ClaudeService.swift (865 lines - NEEDS REFACTOR)
│   ├── SessionRepository.swift (708 lines - NEEDS REFACTOR)
│   ├── KeychainManager.swift
│   ├── NetworkManager.swift
│   └── SessionPersistenceService.swift
├── Models/
│   ├── ClaudeMessage.swift
│   ├── SessionManagerModels.swift
│   └── DummyData.swift
├── ViewModels/
│   └── ConversationViewModel.swift
├── Views/
│   ├── ConversationView.swift
│   └── SessionManagerView.swift
└── VisionForgeApp.swift
```

### Desired Codebase tree with files to be added and responsibility

```bash
ios-app/VisionForge/
├── Services/
│   ├── Network/
│   │   ├── ClaudeNetworkClient.swift (~200 lines) - Core HTTP/URLSession operations
│   │   ├── ClaudeStreamingService.swift (~200 lines) - SSE streaming logic
│   │   ├── SessionAPIClient.swift (~150 lines) - Session CRUD API calls
│   │   └── ClaudeQueryService.swift (~150 lines) - Query and message operations
│   ├── Session/
│   │   ├── SessionRepository.swift (~200 lines) - Core state management & public API
│   │   ├── SessionCacheManager.swift (~150 lines) - In-memory cache with eviction
│   │   ├── SessionSyncService.swift (~180 lines) - Backend sync & refresh logic
│   │   └── SessionLifecycleManager.swift (~150 lines) - App lifecycle & background tasks
│   ├── Protocols/
│   │   ├── NetworkClientProtocol.swift (~30 lines) - Network abstraction
│   │   ├── SessionDataSourceProtocol.swift (~30 lines) - Session data operations
│   │   ├── CacheProtocol.swift (~30 lines) - Generic cache interface
│   │   └── SessionRepositoryProtocol.swift (~30 lines) - Repository interface
│   ├── ClaudeService.swift (~165 lines) - Facade coordinating all services
│   └── [existing services remain unchanged]
├── Models/
│   ├── ClaudeServiceModels.swift (~100 lines) - ClaudeServiceError, ConnectionStatus
│   └── [existing models remain]
└── [rest of structure unchanged]
```

### Known Gotchas of our codebase & Library Quirks

```swift
// CRITICAL: All service classes must use @MainActor for SwiftUI thread safety
@MainActor
@Observable
class ServiceName: ServiceProtocol {

// CRITICAL: Protocol naming convention uses *Protocol suffix
protocol ServiceNameProtocol: AnyObject {

// CRITICAL: Dependency injection through init, not property injection
init(dependency: DependencyProtocol) {
    self.dependency = dependency
}

// CRITICAL: SwiftUI Environment integration pattern
@Environment(SessionRepository.self) var repository

// CRITICAL: Background task management required for iOS
private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

// CRITICAL: SSE parsing must handle partial chunks and reconnection
// Library: URLSession doesn't have built-in SSE support, manual parsing required
```

## Implementation Blueprint

### Data models and structure

Extract models from service files into dedicated model files:

```swift
// Models/ClaudeServiceModels.swift
// Extract from ClaudeService.swift lines 39-57, 785-865
enum ConnectionStatus: Equatable {
    case disconnected
    case connecting
    case connected
    case error(String)
}

enum ClaudeServiceError: LocalizedError {
    case invalidURL
    case networkError(String)
    // ... rest of error cases
}

// Request/Response models
struct SessionListRequest: Codable { }
struct SessionListResponse: Codable { }
struct SessionUpdateRequest: Codable { }
```

### Implementation Tasks (ordered by dependencies)

```yaml
Task 1: CREATE ios-app/VisionForge/Services/Protocols/NetworkClientProtocol.swift
  - IMPLEMENT: Protocol defining network operations abstraction
  - FOLLOW pattern: ios-app/VisionForge/Services/ClaudeService.swift:15 (ClaudeServiceProtocol structure)
  - NAMING: NetworkClientProtocol with AnyObject constraint
  - METHODS: request<T: Decodable>(), stream(), post(), get()
  - PLACEMENT: New Protocols directory in Services/

Task 2: CREATE ios-app/VisionForge/Services/Protocols/SessionDataSourceProtocol.swift
  - IMPLEMENT: Protocol for session data operations
  - FOLLOW pattern: ios-app/VisionForge/Services/SessionRepository.swift:14-21
  - NAMING: SessionDataSourceProtocol: AnyObject
  - METHODS: createSession(), getSession(), deleteSession(), updateSession()
  - PLACEMENT: Services/Protocols/

Task 3: CREATE ios-app/VisionForge/Services/Protocols/CacheProtocol.swift
  - IMPLEMENT: Generic cache protocol with associated type
  - PATTERN: protocol CacheProtocol { associatedtype Value }
  - METHODS: get(), set(), evict(), clear()
  - PLACEMENT: Services/Protocols/

Task 4: CREATE ios-app/VisionForge/Models/ClaudeServiceModels.swift
  - EXTRACT: Lines 39-57, 785-865 from ClaudeService.swift
  - IMPLEMENT: ConnectionStatus enum, ClaudeServiceError enum, request/response structs
  - FOLLOW pattern: ios-app/VisionForge/Models/SessionManagerModels.swift structure
  - PLACEMENT: Models/ directory

Task 5: CREATE ios-app/VisionForge/Services/Network/ClaudeNetworkClient.swift
  - EXTRACT: Core networking from ClaudeService.swift
  - IMPLEMENT: URLSession configuration, request building, response parsing
  - FOLLOW pattern: ClaudeService.swift lines 177-223 (connection management)
  - DEPENDENCIES: Import NetworkClientProtocol from Task 1
  - ANNOTATIONS: @MainActor, @Observable
  - PLACEMENT: New Services/Network/ directory

Task 6: CREATE ios-app/VisionForge/Services/Network/ClaudeStreamingService.swift
  - EXTRACT: SSE streaming logic from ClaudeService.swift lines 609-730
  - IMPLEMENT: Stream parsing, chunk processing, reconnection
  - PATTERN: AsyncThrowingStream<StreamingChunk, Error>
  - DEPENDENCIES: Import NetworkClientProtocol
  - CRITICAL: Handle partial chunks, parse "data:" prefixed lines
  - PLACEMENT: Services/Network/

Task 7: CREATE ios-app/VisionForge/Services/Network/SessionAPIClient.swift
  - EXTRACT: Session CRUD operations from ClaudeService.swift lines 224-321
  - IMPLEMENT: createSession(), getSession(), deleteSession(), updateSession()
  - CONFORM TO: SessionDataSourceProtocol from Task 2
  - DEPENDENCIES: NetworkClientProtocol for HTTP operations
  - PLACEMENT: Services/Network/

Task 8: CREATE ios-app/VisionForge/Services/Network/ClaudeQueryService.swift
  - EXTRACT: Query operations from ClaudeService.swift lines 609-730
  - IMPLEMENT: sendQuery(), streamQuery() methods
  - DEPENDENCIES: ClaudeStreamingService from Task 6
  - PLACEMENT: Services/Network/

Task 9: CREATE ios-app/VisionForge/Services/Session/SessionCacheManager.swift
  - EXTRACT: Cache logic from SessionRepository.swift lines 466-494
  - IMPLEMENT: LRU cache with size limits, eviction
  - CONFORM TO: CacheProtocol from Task 3
  - PATTERN: Dictionary storage with access tracking
  - PLACEMENT: Services/Session/

Task 10: CREATE ios-app/VisionForge/Services/Session/SessionSyncService.swift
  - EXTRACT: Sync operations from SessionRepository.swift lines 287-408
  - IMPLEMENT: refreshSessionsFromBackend(), checkSessionManagerConnectionStatus()
  - DEPENDENCIES: SessionDataSourceProtocol
  - PATTERN: Timer-based refresh, error recovery
  - PLACEMENT: Services/Session/

Task 11: CREATE ios-app/VisionForge/Services/Session/SessionLifecycleManager.swift
  - EXTRACT: Lifecycle handling from SessionRepository.swift lines 522-557
  - IMPLEMENT: App foreground/background handlers
  - DEPENDENCIES: UIKit for app lifecycle notifications
  - PATTERN: NotificationCenter observers
  - PLACEMENT: Services/Session/

Task 12: MODIFY ios-app/VisionForge/Services/ClaudeService.swift
  - REFACTOR: To facade pattern coordinating new services
  - PRESERVE: Public API (ClaudeServiceProtocol methods)
  - INJECT: Dependencies for all extracted services
  - DELEGATE: Operations to appropriate service modules
  - TARGET: ~165 lines

Task 13: MODIFY ios-app/VisionForge/Services/SessionRepository.swift
  - REFACTOR: To use extracted components
  - INJECT: SessionCacheManager, SessionSyncService, SessionLifecycleManager
  - PRESERVE: Public API (SessionRepositoryProtocol)
  - DELEGATE: Cache, sync, lifecycle to injected services
  - TARGET: ~200 lines

Task 14: UPDATE ios-app/VisionForge/VisionForgeApp.swift
  - MODIFY: Dependency injection setup for new architecture
  - WIRE: All new services with proper initialization order
  - PRESERVE: Existing app functionality
  - PATTERN: Follow lines 45-65 environment setup
```

### Implementation Patterns & Key Details

```swift
// Protocol definition pattern (all protocols)
@MainActor
protocol NetworkClientProtocol: AnyObject {
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T
    func stream(_ endpoint: Endpoint) -> AsyncThrowingStream<Data, Error>
}

// Service implementation pattern
@MainActor
@Observable
final class ClaudeNetworkClient: NetworkClientProtocol {
    // PATTERN: Observable properties for SwiftUI
    var isConnected: Bool = false

    // PATTERN: Dependency injection through init
    init(baseURL: URL, configuration: URLSessionConfiguration = .default) {
        self.baseURL = baseURL
        self.session = URLSession(configuration: configuration)
    }

    // GOTCHA: Always use Task for async operations in Observable
    func connect() async throws {
        // Implementation
    }
}

// Repository pattern with dependency injection
@MainActor
@Observable
final class SessionRepository: SessionRepositoryProtocol {
    // PATTERN: Protocol-based dependencies
    private let dataSource: SessionDataSourceProtocol
    private let cache: any CacheProtocol
    private let syncService: SessionSyncService

    init(
        dataSource: SessionDataSourceProtocol,
        cache: any CacheProtocol,
        syncService: SessionSyncService
    ) {
        self.dataSource = dataSource
        self.cache = cache
        self.syncService = syncService
    }
}

// SSE streaming pattern
func streamQuery(request: ClaudeQueryRequest) -> AsyncThrowingStream<StreamingChunk, Error> {
    AsyncThrowingStream { continuation in
        Task { @MainActor in
            // CRITICAL: Parse SSE format
            // data: {"content": "text"}\n\n
            // PATTERN: Handle reconnection on error
        }
    }
}
```

### Integration Points

```yaml
DEPENDENCY_INJECTION:
  - modify: ios-app/VisionForge/VisionForgeApp.swift
  - pattern: "Lines 45-65 show environment setup"
  - add: "Wire all new service dependencies"

VIEWMODEL_UPDATE:
  - modify: ios-app/VisionForge/ViewModels/ConversationViewModel.swift
  - preserve: "Existing public API"
  - update: "Repository injection if needed"

ENVIRONMENT_SETUP:
  - modify: ios-app/VisionForge/Utils/PreviewEnvironment.swift
  - add: "Mock implementations for new protocols"
  - pattern: "Lines 23-39 mock setup"
```

## Validation Loop

### Level 1: Syntax & Style (Immediate Feedback)

```bash
# Swift syntax validation
cd ios-app
swift build --target VisionForge

# SwiftLint validation (optional - only if SwiftLint is installed)
# swiftlint lint --path VisionForge/Services/ 2>/dev/null || echo "SwiftLint not installed - skipping"

# Expected: Zero errors. Fix any syntax issues immediately.
```

### Level 2: Unit Tests (Component Validation)

```bash
# Run existing tests to ensure no regression
xcodebuild test \
  -project VisionForge.xcodeproj \
  -scheme VisionForge \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.0' \
  -only-testing:VisionForgeTests

# Expected: All existing tests pass
```

### Level 3: Integration Testing (System Validation)

```bash
# Build and run the app in simulator
xcodebuild build \
  -project VisionForge.xcodeproj \
  -scheme VisionForge \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.0'

# Test critical user flows
# 1. Launch app
# 2. Configure backend connection
# 3. Create new session
# 4. Send message and receive response
# 5. Switch between sessions
# 6. Background/foreground app

# Expected: All functionality works as before refactoring
```

### Level 4: Architecture Validation

```bash
# Check file sizes are under 500 lines
find VisionForge/Services -name "*.swift" -exec wc -l {} \; | sort -rn | head -20

# Check for circular dependencies
swift package show-dependencies 2>/dev/null || echo "Check imports manually"

# Verify protocol conformance
grep -r "protocol.*Protocol" VisionForge/Services/Protocols/

# Count protocols vs implementations
echo "Protocols: $(find VisionForge/Services/Protocols -name "*.swift" | wc -l)"
echo "Services: $(find VisionForge/Services -name "*.swift" -not -path "*/Protocols/*" | wc -l)"

# Expected: All files under 500 lines, clear protocol/implementation separation
```

## Final Validation Checklist

### Technical Validation

- [ ] All files under 500 lines: `find VisionForge/Services -name "*.swift" -exec bash -c 'lines=$(wc -l < "$1"); if [ $lines -gt 500 ]; then echo "$1: $lines lines"; fi' _ {} \;`
- [ ] Build succeeds: `xcodebuild build -project VisionForge.xcodeproj -scheme VisionForge`
- [ ] Tests pass: `xcodebuild test -project VisionForge.xcodeproj -scheme VisionForge`
- [ ] No SwiftLint errors (if installed): `swiftlint lint --path VisionForge/ 2>/dev/null || echo "SwiftLint not installed"`

### Feature Validation

- [ ] Session creation works as before
- [ ] Message streaming functions correctly
- [ ] Session switching preserves state
- [ ] Background refresh continues working
- [ ] Error handling remains intact
- [ ] Connection status updates properly

### Code Quality Validation

- [ ] Follows existing protocol naming (*Protocol suffix)
- [ ] Uses @MainActor and @Observable consistently
- [ ] Dependency injection through init()
- [ ] No circular dependencies between modules
- [ ] Business logic moved to appropriate repositories
- [ ] Network logic isolated in network layer

### Architecture Validation

- [ ] Clear separation of concerns achieved
- [ ] Protocol-based abstractions enable mocking
- [ ] Single Responsibility Principle followed
- [ ] Dependencies flow in one direction
- [ ] Testability improved through loose coupling

---

## Anti-Patterns to Avoid

- ❌ Don't create circular dependencies between services
- ❌ Don't skip @MainActor annotation on service classes
- ❌ Don't use property injection instead of constructor injection
- ❌ Don't mix business logic with networking code
- ❌ Don't create files over 500 lines
- ❌ Don't break existing public APIs
- ❌ Don't ignore thread safety with @MainActor
- ❌ Don't create protocols without clear purpose
- ❌ Don't forget to update dependency injection in VisionForgeApp