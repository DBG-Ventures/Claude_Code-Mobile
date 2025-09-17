name: "SwiftUI Frontend Session Management Integration - Persistent SessionManager Support PRP"
description: |

---

## Goal

**Feature Goal**: Update SwiftUI frontend (VisionForge) to seamlessly integrate with the enhanced FastAPI backend SessionManager, implementing persistent session continuity, optimized session switching, and reliable conversation resumption across app launches using modern iOS patterns.

**Deliverable**: Enhanced SwiftUI VisionForge client with updated session management models, persistent session state management, optimized SessionManager API integration, session history persistence using SwiftData/CoreData, and improved real-time streaming with session context preservation.

**Success Definition**: iOS users experience seamless conversation continuity across app restarts, instant session switching without context loss, reliable session resumption after backend restarts, persistent conversation history accessible across app launches, and <200ms session switching performance with the new SessionManager architecture.

## User Persona

**Target User**: Claude Code CLI Power Users extending workflows to mobile devices

**Use Case**: Mobile development workflow with persistent session management - maintaining multiple concurrent Claude Code conversations across different technical contexts, seamlessly switching between project discussions, preserving conversation history for reference, and continuing conversations after app/backend restarts without losing context.

**User Journey**:
1. Open iOS app and automatically resume last active session from previous app launch
2. Switch between multiple concurrent sessions instantly without loading delays
3. Create new sessions that persist immediately and survive backend/app restarts
4. Access conversation history for any session across app launches
5. Experience real-time streaming responses with full session context preservation
6. Continue conversations seamlessly after network disruptions or backend maintenance

**Pain Points Addressed**:
- Session context loss when switching between conversations in mobile app
- Inability to resume conversations after app restarts due to local state loss
- No access to conversation history from previous app sessions
- Poor session switching performance requiring full conversation reload
- Real-time streaming that doesn't integrate with persistent session context
- Mobile app becomes unusable during backend restarts or network issues

## Why

- **Critical UX Enhancement**: New backend SessionManager provides persistent ClaudeSDKClient instances, but iOS app needs updates to leverage these improvements
- **Session Continuity Gap**: Current iOS implementation doesn't integrate with enhanced session persistence and conversation continuity features
- **Performance Optimization Opportunity**: Backend now maintains persistent sessions, enabling instant session switching and context preservation
- **Mobile Workflow Reliability**: Enhanced session management enables reliable mobile Claude Code workflows with conversation history and context preservation
- **API Alignment**: Frontend data models and networking need alignment with new SessionManager API structure and capabilities
- **SwiftUI Modern Patterns**: Opportunity to implement modern SwiftUI session management patterns with new backend architecture

## What

Implement comprehensive SwiftUI frontend updates to integrate with enhanced SessionManager backend:

1. **Updated Data Models**: Enhance ClaudeMessage models to support session metadata, conversation history access, and SessionManager response structure
2. **Session State Management**: Implement modern SwiftUI session state management using @EnvironmentObject patterns with persistent session registry
3. **SessionManager API Integration**: Update ClaudeService to use new SessionManager endpoints with persistent client connections and conversation continuity
4. **Session Persistence**: Add SwiftData/CoreData integration for persistent session storage, conversation history, and offline session management
5. **Optimized Session Switching**: Implement instant session switching leveraging backend persistent clients and local session caching
6. **Real-time Streaming Enhancement**: Update streaming implementation to integrate with SessionManager session context and conversation continuity
7. **Error Handling & Recovery**: Enhanced error handling for SessionManager integration with automatic session recovery and reconnection logic

### Success Criteria

- [ ] Session switching completes in <200ms using backend persistent sessions
- [ ] Conversation history accessible across app launches with full context preservation
- [ ] Sessions persist correctly across backend restarts using enhanced SessionManager
- [ ] Real-time streaming maintains session context with conversation continuity
- [ ] Multiple concurrent sessions (10+) work without interference using SessionManager isolation
- [ ] Session resumption works reliably after network disruptions with automatic recovery
- [ ] Session history and metadata persist locally using SwiftData/CoreData for offline access
- [ ] Error handling provides clear feedback for SessionManager issues with automatic retry
- [ ] Background/foreground app transitions maintain session state and connections
- [ ] iOS app gracefully handles SessionManager cleanup and session lifecycle management

## All Needed Context

### Context Completeness Check

_Validated: This PRP provides complete implementation guidance for developers unfamiliar with SwiftUI session management, SessionManager backend integration, and modern iOS persistence patterns through systematic research and comprehensive technical references._

### Documentation & References

```yaml
# MUST READ - SwiftUI Session Management Patterns (Research Validated)
- url: https://www.avanderlee.com/swiftui/stateobject-observedobject-differences/
  why: SwiftUI @StateObject vs @ObservedObject patterns for session state management
  critical: @StateObject establishes ownership for session managers, prevents data loss during view recreation
  pattern: Use @StateObject in root views, @EnvironmentObject for child view access

- url: https://www.hackingwithswift.com/quick-start/swiftui/whats-the-difference-between-observedobject-state-and-environmentobject
  why: SwiftUI property wrapper patterns for global session state sharing
  pattern: Environment injection for session management across view hierarchies
  gotcha: @EnvironmentObject requires explicit injection from parent views

- url: https://github.com/nalexn/clean-architecture-swiftui
  why: Clean Architecture SwiftUI implementation with proper separation of concerns
  pattern: Session management in service layer with SwiftUI view integration
  critical: Proper dependency injection patterns for session services

# MUST READ - Backend SessionManager Integration (Project Context)
- file: backend/app/services/session_manager.py
  why: New SessionManager implementation with persistent ClaudeSDKClient management
  pattern: Persistent client pools, automatic cleanup, graceful shutdown handling
  critical: SessionManager provides persistent sessions that survive backend restarts
  gotcha: Session ID extraction from ClaudeSDKClient, working directory consistency requirements

- file: backend/app/api/claude.py
  why: Updated Claude API endpoints with SessionManager dependency injection
  pattern: Session management endpoints with conversation history support
  critical: New API structure for session creation, resumption, and streaming with persistent clients

- file: backend/app/models/responses.py
  why: Enhanced response models for session history and SessionManager integration
  pattern: Session metadata, conversation history, SessionManager statistics
  gotcha: Response structure changes for session management API

# MUST READ - Modern iOS Networking & Persistence (Research Validated)
- url: https://www.avanderlee.com/concurrency/urlsession-async-await-network-requests-in-swift/
  why: Modern URLSession async/await patterns for FastAPI backend integration
  pattern: Three-line REST API calls, SwiftUI .task() modifier for network calls
  critical: Native error handling with async/await eliminates callback complexity

- url: https://byby.dev/swiftdata-or-coredata
  why: 2024 assessment of SwiftData vs CoreData for production session persistence
  critical: SwiftData has stability issues in 2024, CoreData recommended for production
  gotcha: SwiftData performance problems and compatibility issues with iOS 18

- url: https://developer.apple.com/documentation/foundation/urlsession
  why: Official URLSession documentation for advanced networking patterns
  pattern: Session configuration, authentication, background tasks
  critical: Proper session configuration for long-running Claude Code connections

# MUST READ - Real-time Communication (Research Validated)
- url: https://medium.com/@thomsmed/real-time-with-websockets-and-swift-concurrency-8b44a8808d0d
  why: SwiftUI WebSocket implementation with Swift concurrency patterns
  pattern: URLSessionWebSocketTask with AsyncThrowingStream for message iteration
  gotcha: WebSocket connections limited to foreground, require background mode configuration

- url: https://fastapi.tiangolo.com/advanced/websockets/
  why: FastAPI WebSocket implementation patterns for real-time streaming
  pattern: Connection management, room-based messaging, broadcast patterns
  critical: Server-Sent Events may be better than WebSockets for unidirectional streaming

# MUST READ - iOS App Lifecycle & Background Tasks (Research Validated)
- url: https://developer.apple.com/documentation/backgroundtasks/bgtaskscheduler
  why: Modern background task management for session persistence and reconnection
  pattern: BGTaskScheduler for background session management
  gotcha: iOS heavily restricts background execution, implement foreground reconnection logic

- url: https://developer.apple.com/documentation/uikit/managing-your-app-s-life-cycle
  why: iOS app lifecycle management for session state preservation
  pattern: Background/foreground transitions, session state preservation
  critical: Session reconnection when app returns to foreground
```

### Current Codebase tree

```bash
Claude_Code-Mobile/
├── backend/                          # Enhanced SessionManager backend (COMPLETED)
│   ├── app/
│   │   ├── main.py                   # FastAPI with SessionManager lifecycle integration
│   │   ├── api/
│   │   │   └── claude.py             # Enhanced Claude endpoints with SessionManager
│   │   ├── services/
│   │   │   ├── claude_service.py     # SessionManager integration with ClaudeSDKClient
│   │   │   └── session_manager.py    # NEW: Persistent ClaudeSDKClient management
│   │   ├── models/
│   │   │   ├── requests.py           # Enhanced session management request models
│   │   │   └── responses.py          # Enhanced session response models with history
│   │   ├── core/
│   │   │   └── lifecycle.py          # SessionManager initialization and cleanup
│   │   └── utils/
│   │       ├── session_storage.py    # Enhanced session metadata storage
│   │       └── session_utils.py      # Session validation and recovery utilities
├── ios-app/VisionForge/              # SwiftUI client (NEEDS ENHANCEMENT)
│   ├── VisionForgeApp.swift          # App entry point with environment setup
│   ├── ContentView.swift             # Main interface with NavigationSplitView
│   ├── Models/
│   │   ├── ClaudeMessage.swift       # Data models matching backend API
│   │   └── SwiftDataModels.swift     # SwiftData persistence models
│   ├── Services/
│   │   ├── ClaudeService.swift       # HTTP client for backend communication
│   │   ├── NetworkManager.swift      # Network layer with configuration
│   │   └── KeychainManager.swift     # Secure storage for backend config
│   ├── ViewModels/
│   │   ├── ConversationViewModel.swift  # Chat interface state management
│   │   └── SessionListViewModel.swift   # Session management logic
│   ├── Views/
│   │   ├── ConversationView.swift    # Main chat interface
│   │   ├── SessionSidebarView.swift  # Session navigation sidebar
│   │   ├── SessionManagerView.swift  # Session management interface
│   │   └── EditableSettingsView.swift # Backend configuration
│   ├── Components/
│   │   ├── MessageBubble.swift       # Individual message display
│   │   ├── StreamingTextView.swift   # Real-time text streaming
│   │   └── ModernVisualEffects.swift # iOS 26 Liquid Glass effects
│   └── Setup/
│       ├── BackendSetupFlow.swift    # Backend configuration wizard
│       └── ConfigurationValidator.swift # Real-time validation
```

### Desired Codebase tree with files to be added and responsibility of file

```bash
Claude_Code-Mobile/ios-app/VisionForge/
├── VisionForgeApp.swift              # Enhanced with SessionManager environment setup
├── ContentView.swift                 # Updated session restoration and SessionManager integration
├── Models/
│   ├── ClaudeMessage.swift           # Enhanced with SessionManager response structure
│   ├── SwiftDataModels.swift         # Enhanced session persistence models
│   ├── SessionManagerModels.swift    # NEW: SessionManager-specific data models
│   └── SessionHistoryModels.swift    # NEW: Conversation history and metadata models
├── Services/
│   ├── ClaudeService.swift           # Enhanced SessionManager API integration
│   ├── NetworkManager.swift          # Updated configuration management
│   ├── KeychainManager.swift         # Enhanced session credential storage
│   ├── SessionPersistenceService.swift # NEW: Local session persistence with CoreData
│   └── SessionStateManager.swift     # NEW: Session state coordination and caching
├── ViewModels/
│   ├── ConversationViewModel.swift   # Enhanced with SessionManager session management
│   ├── SessionListViewModel.swift    # Enhanced with persistent session loading
│   ├── SessionHistoryViewModel.swift # NEW: Conversation history management
│   └── SessionSwitchingViewModel.swift # NEW: Optimized session switching logic
├── Views/
│   ├── ConversationView.swift        # Enhanced session context integration
│   ├── SessionSidebarView.swift      # Enhanced with persistent session display
│   ├── SessionManagerView.swift      # Enhanced SessionManager status display
│   ├── SessionHistoryView.swift      # NEW: Conversation history interface
│   └── EditableSettingsView.swift    # Enhanced SessionManager configuration
├── Components/
│   ├── MessageBubble.swift           # Enhanced with session metadata
│   ├── StreamingTextView.swift       # Enhanced SessionManager streaming integration
│   ├── ModernVisualEffects.swift     # Maintained liquid glass effects
│   ├── SessionRow.swift              # NEW: Persistent session display component
│   └── SessionStatusIndicator.swift  # NEW: SessionManager connection status
├── Setup/
│   ├── BackendSetupFlow.swift        # Enhanced SessionManager configuration
│   └── ConfigurationValidator.swift  # Enhanced SessionManager validation
└── Utils/
    ├── SessionCacheManager.swift     # NEW: Local session caching for performance
    └── ErrorRecoveryManager.swift    # NEW: SessionManager error handling and recovery
```

### Known Gotchas of our codebase & Library Quirks

```swift
// CRITICAL: SessionManager API integration patterns
// New SessionManager provides persistent ClaudeSDKClient instances
// Must update API calls to leverage session persistence

// CORRECT: SessionManager session creation
let request = SessionRequest(
    userId: "user123",
    sessionName: "Project Discussion",
    workingDirectory: "/project/path",  // CRITICAL: Must be consistent for session resumption
    persistClient: true                 // NEW: Enable persistent client management
)

// GOTCHA: Session ID handling with SessionManager
// SessionManager may return different session_id than requested
// Always use response.sessionId from backend, not local UUID
let response = try await claudeService.createSession(request: request)
let actualSessionId = response.sessionId  // Use this, not request sessionId

// CRITICAL: SwiftUI @StateObject vs @ObservedObject for session management
// Use @StateObject for session manager ownership, @EnvironmentObject for access
@main
struct VisionForgeApp: App {
    @StateObject private var sessionStateManager = SessionStateManager()  // OWNERSHIP

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sessionStateManager)  // INJECTION
        }
    }
}

// In child views, use @EnvironmentObject for session access
struct ConversationView: View {
    @EnvironmentObject var sessionStateManager: SessionStateManager  // ACCESS ONLY
}

// GOTCHA: SwiftData stability issues in 2024
// Use CoreData for production session persistence instead of SwiftData
// SwiftData has performance problems and iOS 18 compatibility issues
import CoreData  // Use this instead of SwiftData for production

// CRITICAL: URLSession configuration for SessionManager long-running connections
let configuration = URLSessionConfiguration.default
configuration.timeoutIntervalForRequest = 300.0    // 5 minutes for SessionManager
configuration.timeoutIntervalForResource = 600.0   // 10 minutes for streaming
configuration.waitsForConnectivity = true          // Mobile network handling

// GOTCHA: iOS WebSocket background limitations
// WebSocket connections suspend in background, implement foreground reconnection
NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
    .sink { _ in
        Task {
            await self.reconnectToSessionManager()  // Reconnect on foreground
        }
    }

// CRITICAL: SessionManager error handling patterns
// SessionManager provides specific error types for different failure scenarios
catch ClaudeServiceError.sessionNotFound {
    // Session may have been cleaned up by SessionManager timeout
    await attemptSessionRecovery()
}
catch ClaudeServiceError.sessionManagerUnavailable {
    // Backend SessionManager not responding, implement fallback
    showSessionManagerErrorUI()
}

// GOTCHA: Session history access limitations
// Backend provides conversation history but may be large
// Implement pagination and lazy loading for mobile performance
let request = ClaudeQueryRequest(
    sessionId: sessionId,
    query: query,
    includeHistory: false,  // Only include history when needed
    stream: true
)

// CRITICAL: Real-time streaming with SessionManager integration
// Streaming now maintains session context automatically
// Update streaming implementation to preserve SessionManager session state
func streamQuery(request: ClaudeQueryRequest) -> AsyncThrowingStream<StreamingChunk, Error> {
    return AsyncThrowingStream { continuation in
        Task {
            // SessionManager maintains session context during streaming
            await streamWithSessionContext(request: request, continuation: continuation)
        }
    }
}
```

## Implementation Blueprint

### Data models and structure

Enhance existing data models to support SessionManager integration and persistent session management.

```swift
// Enhanced session models for SessionManager integration
import Foundation
import SwiftData // Consider CoreData for production stability

// NEW: SessionManager-specific response models
struct SessionManagerResponse: Codable {
    let sessionId: String
    let userId: String
    let sessionName: String?
    let workingDirectory: String
    let status: SessionStatus
    let createdAt: Date
    let lastActiveAt: Date
    let messageCount: Int
    let conversationHistory: [ConversationMessage]?
    let sessionManagerStats: SessionManagerStats?

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case userId = "user_id"
        case sessionName = "session_name"
        case workingDirectory = "working_directory"
        case status, createdAt = "created_at"
        case lastActiveAt = "last_active_at"
        case messageCount = "message_count"
        case conversationHistory = "conversation_history"
        case sessionManagerStats = "session_manager_stats"
    }
}

// Enhanced conversation message for SessionManager context
struct ConversationMessage: Identifiable, Codable {
    let id: String
    let role: MessageRole
    let content: String
    let timestamp: Date
    let sessionId: String
    let messageId: String?
    let sessionManagerContext: [String: AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case id, role, content, timestamp
        case sessionId = "session_id"
        case messageId = "message_id"
        case sessionManagerContext = "session_manager_context"
    }
}

// NEW: SessionManager statistics for monitoring
struct SessionManagerStats: Codable {
    let activeSessions: Int
    let totalSessionsCreated: Int
    let memoryUsageMB: Float
    let cleanupLastRun: Date
    let sessionTimeoutSeconds: Int

    enum CodingKeys: String, CodingKey {
        case activeSessions = "active_sessions"
        case totalSessionsCreated = "total_sessions_created"
        case memoryUsageMB = "memory_usage_mb"
        case cleanupLastRun = "cleanup_last_run"
        case sessionTimeoutSeconds = "session_timeout_seconds"
    }
}

// Enhanced session request for SessionManager features
struct EnhancedSessionRequest: Codable {
    let userId: String
    let sessionName: String?
    let workingDirectory: String?
    let persistClient: Bool
    let claudeOptions: ClaudeCodeOptions
    let context: [String: AnyCodable]

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case sessionName = "session_name"
        case workingDirectory = "working_directory"
        case persistClient = "persist_client"
        case claudeOptions = "claude_options"
        case context
    }

    init(userId: String, sessionName: String? = nil, workingDirectory: String? = nil,
         persistClient: Bool = true, claudeOptions: ClaudeCodeOptions = ClaudeCodeOptions(),
         context: [String: AnyCodable] = [:]) {
        self.userId = userId
        self.sessionName = sessionName
        self.workingDirectory = workingDirectory
        self.persistClient = persistClient
        self.claudeOptions = claudeOptions
        self.context = context
    }
}

// Local persistence models using CoreData (recommended over SwiftData)
import CoreData

@objc(PersistedSession)
class PersistedSession: NSManagedObject {
    @NSManaged var sessionId: String
    @NSManaged var userId: String
    @NSManaged var sessionName: String?
    @NSManaged var workingDirectory: String?
    @NSManaged var status: String
    @NSManaged var createdAt: Date
    @NSManaged var lastActiveAt: Date
    @NSManaged var messageCount: Int32
    @NSManaged var conversationData: Data?  // JSON-encoded conversation history
    @NSManaged var sessionManagerMetadata: Data?  // JSON-encoded session metadata
}

@objc(PersistedMessage)
class PersistedMessage: NSManagedObject {
    @NSManaged var messageId: String
    @NSManaged var sessionId: String
    @NSManaged var role: String
    @NSManaged var content: String
    @NSManaged var timestamp: Date
    @NSManaged var metadata: Data?  // JSON-encoded message metadata
}
```

### Implementation Tasks (ordered by dependencies)

```yaml
Task 1: ENHANCE ios-app/VisionForge/Models/SessionManagerModels.swift
  - IMPLEMENT: SessionManagerResponse, ConversationMessage, SessionManagerStats models
  - FOLLOW pattern: existing ClaudeMessage.swift (Codable protocol, CodingKeys enum)
  - NAMING: PascalCase Swift naming, match backend snake_case field names
  - PLACEMENT: Models directory for SessionManager-specific data structures
  - DEPENDENCIES: Foundation framework, AnyCodable from existing models
  - CRITICAL: Exact field matching with backend SessionManager response structure

Task 2: CREATE ios-app/VisionForge/Services/SessionPersistenceService.swift
  - IMPLEMENT: CoreData integration for local session persistence and conversation history
  - FOLLOW pattern: Modern CoreData with NSPersistentContainer and async operations
  - NAMING: SessionPersistenceService class with async persistence methods
  - FEATURES: save/load sessions, conversation history, session metadata caching
  - DEPENDENCIES: CoreData framework, SessionManagerModels from Task 1
  - CRITICAL: Use CoreData instead of SwiftData for production stability

Task 3: ENHANCE ios-app/VisionForge/Services/ClaudeService.swift
  - IMPLEMENT: SessionManager API integration with persistent session management
  - UPDATE: session creation, query streaming, session resumption with SessionManager
  - FOLLOW pattern: existing async/await URLSession patterns with enhanced error handling
  - PRESERVE: existing streaming optimization and mobile lifecycle management
  - DEPENDENCIES: SessionManagerModels from Task 1, enhanced error handling
  - CRITICAL: Update API endpoints to match SessionManager backend structure

Task 4: CREATE ios-app/VisionForge/Services/SessionStateManager.swift
  - IMPLEMENT: SwiftUI session state coordination and caching for optimized performance
  - FEATURES: session registry, active session tracking, session switching optimization
  - FOLLOW pattern: @ObservableObject with @Published properties for SwiftUI integration
  - NAMING: SessionStateManager class with clear session management methods
  - DEPENDENCIES: ClaudeService from Task 3, SessionPersistenceService from Task 2
  - CRITICAL: Implement singleton pattern with proper SwiftUI lifecycle management

Task 5: ENHANCE ios-app/VisionForge/ViewModels/ConversationViewModel.swift
  - INTEGRATE: SessionStateManager for persistent session context and conversation continuity
  - UPDATE: streaming message handling with SessionManager session context preservation
  - PRESERVE: existing real-time streaming and message display logic
  - FOLLOW pattern: existing @ObservableObject with @Published state properties
  - DEPENDENCIES: SessionStateManager from Task 4, enhanced ClaudeService from Task 3
  - CRITICAL: Maintain session context during streaming and conversation updates

Task 6: ENHANCE ios-app/VisionForge/ViewModels/SessionListViewModel.swift
  - IMPLEMENT: persistent session loading and optimized session switching with SessionManager
  - UPDATE: session creation, deletion, status tracking with backend SessionManager integration
  - FEATURES: session history loading, session metadata display, SessionManager statistics
  - DEPENDENCIES: SessionStateManager from Task 4, SessionPersistenceService from Task 2
  - CRITICAL: Leverage SessionManager persistent sessions for instant switching

Task 7: UPDATE ios-app/VisionForge/Views/ConversationView.swift
  - INTEGRATE: enhanced session context with conversation history and SessionManager status
  - UPDATE: session switching handling with optimized performance using persistent sessions
  - PRESERVE: existing liquid glass effects and message display components
  - FOLLOW pattern: existing SwiftUI view structure with @EnvironmentObject injection
  - DEPENDENCIES: Enhanced ViewModels from Tasks 5-6, SessionStateManager integration
  - CRITICAL: Seamless session switching with conversation context preservation

Task 8: ENHANCE ios-app/VisionForge/Views/SessionSidebarView.swift
  - IMPLEMENT: persistent session display with SessionManager status indicators
  - UPDATE: session creation flow with SessionManager configuration options
  - FEATURES: session history preview, SessionManager health status, session metadata
  - DEPENDENCIES: Enhanced SessionListViewModel from Task 6, new session components
  - CRITICAL: Display SessionManager persistent session benefits (instant switching)

Task 9: CREATE ios-app/VisionForge/Components/SessionStatusIndicator.swift
  - IMPLEMENT: SwiftUI component for SessionManager connection and session status
  - FEATURES: visual indicators for session health, SessionManager availability, connection status
  - FOLLOW pattern: existing ModernVisualEffects.swift component structure
  - PLACEMENT: Components directory for reusable session status display
  - DEPENDENCIES: SessionStateManager for status information
  - CRITICAL: Clear visual feedback for SessionManager operational status

Task 10: ENHANCE ios-app/VisionForge/ContentView.swift
  - INTEGRATE: SessionStateManager initialization and environment injection
  - UPDATE: session restoration logic with persistent session loading from SessionManager
  - PRESERVE: existing NavigationSplitView structure and backend setup flow
  - DEPENDENCIES: SessionStateManager from Task 4, enhanced session restoration
  - CRITICAL: Initialize SessionStateManager with proper SwiftUI lifecycle management
```

### Implementation Patterns & Key Details

```swift
// SessionStateManager implementation with SwiftUI integration
import SwiftUI
import Combine

@MainActor
class SessionStateManager: ObservableObject {
    @Published var activeSessions: [SessionManagerResponse] = []
    @Published var currentSessionId: String?
    @Published var sessionManagerStatus: ConnectionStatus = .disconnected
    @Published var isLoading: Bool = false

    private let claudeService: ClaudeService
    private let persistenceService: SessionPersistenceService
    private var sessionCache: [String: SessionManagerResponse] = [:]
    private var cancellables = Set<AnyCancellable>()

    init(claudeService: ClaudeService, persistenceService: SessionPersistenceService) {
        self.claudeService = claudeService
        self.persistenceService = persistenceService
        setupSessionMonitoring()
    }

    // PATTERN: Optimized session switching using SessionManager persistent sessions
    func switchToSession(_ sessionId: String) async {
        guard sessionId != currentSessionId else { return }

        isLoading = true
        defer { isLoading = false }

        // Check local cache first for instant switching
        if let cachedSession = sessionCache[sessionId] {
            currentSessionId = sessionId
            // SessionManager maintains persistent clients, no reload needed
            return
        }

        do {
            // Fetch session from SessionManager (should be instant due to persistent clients)
            let session = try await claudeService.getSession(sessionId: sessionId, userId: getUserId())
            sessionCache[sessionId] = session
            currentSessionId = sessionId

            // Save to local persistence for offline access
            await persistenceService.saveSession(session)
        } catch {
            print("⚠️ Failed to switch to session \(sessionId): \(error)")
        }
    }

    // PATTERN: Session restoration with persistent session management
    func restoreSessionsFromPersistence() async {
        // Load from local persistence first for immediate UI
        let localSessions = await persistenceService.loadRecentSessions(limit: 10)
        activeSessions = localSessions.map { $0.toSessionManagerResponse() }

        // Then sync with SessionManager backend for latest state
        await refreshSessionsFromBackend()
    }

    private func refreshSessionsFromBackend() async {
        do {
            let sessionList = try await claudeService.getSessions(
                request: SessionListRequest(userId: getUserId(), limit: 20, offset: 0)
            )

            activeSessions = sessionList.sessions

            // Update local cache and persistence
            for session in sessionList.sessions {
                sessionCache[session.sessionId] = session
                await persistenceService.saveSession(session)
            }
        } catch {
            print("⚠️ Failed to refresh sessions from backend: \(error)")
        }
    }

    private func getUserId() -> String {
        // Get from user preferences or device identifier
        return UIDevice.current.identifierForVendor?.uuidString ?? "default-user"
    }
}

// Enhanced ClaudeService with SessionManager integration
extension ClaudeService {
    func createSessionWithManager(request: EnhancedSessionRequest) async throws -> SessionManagerResponse {
        let url = baseURL.appendingPathComponent("claude/sessions")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestData = try encoder.encode(request)
        urlRequest.httpBody = requestData

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeServiceError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200, 201:
            return try decoder.decode(SessionManagerResponse.self, from: data)
        case 404:
            throw ClaudeServiceError.sessionManagerUnavailable
        default:
            let errorResponse = try? decoder.decode(ErrorResponse.self, from: data)
            throw ClaudeServiceError.serverError(errorResponse?.message ?? "HTTP \(httpResponse.statusCode)")
        }
    }

    // PATTERN: Streaming with SessionManager context preservation
    func streamQueryWithSessionManager(request: ClaudeQueryRequest) -> AsyncThrowingStream<StreamingChunk, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let url = baseURL.appendingPathComponent("claude/stream")
                    var urlRequest = URLRequest(url: url)
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")

                    let requestData = try encoder.encode(request)
                    urlRequest.httpBody = requestData

                    let (asyncBytes, response) = try await session.bytes(for: urlRequest)

                    guard let httpResponse = response as? HTTPURLResponse,
                          httpResponse.statusCode == 200 else {
                        throw ClaudeServiceError.invalidResponse
                    }

                    // Process Server-Sent Events with SessionManager context
                    for try await line in asyncBytes.lines {
                        if line.hasPrefix("data: ") {
                            let jsonData = String(line.dropFirst(6))
                            if let data = jsonData.data(using: .utf8) {
                                do {
                                    let chunk = try decoder.decode(StreamingChunk.self, from: data)
                                    continuation.yield(chunk)

                                    if chunk.chunkType == .complete || chunk.chunkType == .error {
                                        continuation.finish()
                                        return
                                    }
                                } catch {
                                    print("⚠️ Failed to decode SessionManager streaming chunk: \(error)")
                                }
                            }
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// SwiftUI ContentView integration with SessionStateManager
struct ContentView: View {
    @EnvironmentObject var networkManager: NetworkManager
    @EnvironmentObject var persistenceManager: PersistenceManager
    @StateObject private var sessionStateManager: SessionStateManager
    @State private var needsBackendSetup = false
    @State private var selectedSessionId: String?
    @State private var isInitializing = true

    init() {
        // Initialize SessionStateManager with dependencies
        let claudeService = ClaudeService(baseURL: URL(string: "http://localhost:8000")!)
        let persistenceService = SessionPersistenceService()
        _sessionStateManager = StateObject(wrappedValue: SessionStateManager(
            claudeService: claudeService,
            persistenceService: persistenceService
        ))
    }

    var body: some View {
        Group {
            if isInitializing {
                initializationView
            } else if needsBackendSetup {
                backendSetupView
            } else {
                mainInterface
            }
        }
        .environmentObject(sessionStateManager)  // Inject SessionStateManager
        .onAppear {
            initializeApp()
        }
    }

    private var mainInterface: some View {
        NavigationSplitView {
            SessionSidebarView(selectedSessionId: $selectedSessionId)
                .navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 450)
        } detail: {
            if let sessionId = selectedSessionId {
                ConversationView(sessionId: sessionId)
                    .id(sessionId)  // Force view refresh when session changes
            } else {
                sessionEmptyState
            }
        }
        .navigationSplitViewStyle(.balanced)
        .task {
            // Restore sessions using SessionManager persistence
            await sessionStateManager.restoreSessionsFromPersistence()

            // Select most recent active session
            if let recentSession = sessionStateManager.activeSessions.first(where: { $0.status == .active }) {
                selectedSessionId = recentSession.sessionId
            }
        }
    }

    private func initializeApp() async {
        // Check backend configuration and SessionManager availability
        checkBackendConfiguration()

        // Initialize session state management
        await sessionStateManager.restoreSessionsFromPersistence()

        await MainActor.run {
            isInitializing = false
        }
    }
}
```

### Integration Points

```yaml
SESSIONMANAGER_INTEGRATION:
  - api_endpoints: "Updated /claude/sessions, /claude/stream endpoints with SessionManager"
  - persistent_sessions: "Leverage backend persistent ClaudeSDKClient instances"
  - session_context: "Maintain conversation context across app/backend restarts"
  - error_handling: "Enhanced error recovery for SessionManager-specific issues"

SWIFTUI_STATE_MANAGEMENT:
  - session_state: "@StateObject SessionStateManager for session ownership and coordination"
  - environment_injection: "@EnvironmentObject for session access across view hierarchy"
  - persistence_integration: "CoreData for local session and conversation history storage"
  - caching_strategy: "Local session cache for instant switching with backend sync"

REAL_TIME_STREAMING:
  - session_context: "Streaming maintains SessionManager session context automatically"
  - connection_management: "URLSession configuration optimized for SessionManager connections"
  - background_handling: "Reconnection logic for app lifecycle transitions"
  - error_recovery: "Automatic retry with SessionManager session restoration"

MOBILE_OPTIMIZATION:
  - session_switching: "Instant switching using SessionManager persistent clients"
  - conversation_history: "Local caching with backend sync for offline access"
  - performance_monitoring: "SessionManager statistics integration for debugging"
  - battery_efficiency: "Leverage persistent connections to reduce connection overhead"
```

## Validation Loop

### Level 1: Syntax & Style (Immediate Feedback)

```bash
# SwiftUI/iOS validation with Xcode build system
cd ios-app/VisionForge

# Build and check for compilation errors
xcodebuild -scheme VisionForge -destination 'platform=iOS Simulator,name=iPad Pro' clean build

# Install SwiftLint if available for style checking
if command -v swiftlint &> /dev/null; then
    swiftlint --fix                    # Auto-fix style issues
    swiftlint                          # Check remaining issues
else
    echo "SwiftLint not available - using Xcode built-in formatting"
fi

# Check for Swift compiler warnings and errors
xcodebuild -scheme VisionForge -destination 'platform=iOS Simulator,name=iPad Pro' build 2>&1 | grep -E "(warning|error):"

# Expected: Zero errors, minimal warnings. Fix compilation issues before proceeding.
```

### Level 2: Unit Tests (Component Validation)

```bash
# Test SessionManager integration and session management functionality
cd ios-app/VisionForge

# Run unit tests for session management components
xcodebuild test -scheme VisionForge -destination 'platform=iOS Simulator,name=iPad Pro' \
  -only-testing:VisionForgeTests/SessionStateManagerTests

# Run unit tests for enhanced ClaudeService
xcodebuild test -scheme VisionForge -destination 'platform=iOS Simulator,name=iPad Pro' \
  -only-testing:VisionForgeTests/ClaudeServiceTests

# Run unit tests for session persistence
xcodebuild test -scheme VisionForge -destination 'platform=iOS Simulator,name=iPad Pro' \
  -only-testing:VisionForgeTests/SessionPersistenceTests

# Full test suite for session management
xcodebuild test -scheme VisionForge -destination 'platform=iOS Simulator,name=iPad Pro'

# Expected: All tests pass, session management components work correctly
```

### Level 3: Integration Testing (System Validation)

```bash
# Backend SessionManager integration validation
cd backend
docker-compose up -d
sleep 5

# Verify SessionManager health and functionality
curl -f http://localhost:8000/health || echo "Backend health check failed"

# Test SessionManager session creation
SESSION_ID=$(curl -s -X POST http://localhost:8000/claude/sessions \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test-user", "session_name": "iOS Integration Test", "persist_client": true}' | jq -r .session_id)

echo "Created SessionManager session: $SESSION_ID"

# Test conversation with SessionManager persistent client
curl -X POST http://localhost:8000/claude/stream \
  -H "Content-Type: application/json" \
  -d "{\"session_id\": \"$SESSION_ID\", \"query\": \"Test SessionManager integration\", \"user_id\": \"test-user\"}"

# iOS app integration testing
cd ios-app/VisionForge

# Launch iOS simulator and test SessionManager integration
xcodebuild -scheme VisionForge -destination 'platform=iOS Simulator,name=iPad Pro' \
  -configuration Debug build-for-testing test-without-building

# Manual verification checklist:
# - Backend SessionManager connection successful
# - Session creation and persistence working
# - Real-time streaming with session context
# - Session switching performance <200ms
# - Conversation history accessible
# - App restart preserves session state

# Expected: iOS app integrates successfully with SessionManager backend
```

### Level 4: Creative & Domain-Specific Validation

```bash
# SessionManager conversation continuity testing
cd backend

# Test session persistence across backend restart
SESSION_ID=$(curl -s -X POST http://localhost:8000/claude/sessions \
  -H "Content-Type: application/json" \
  -d '{"user_id": "continuity-test", "session_name": "Persistence Test"}' | jq -r .session_id)

# Start conversation
curl -X POST http://localhost:8000/claude/stream \
  -H "Content-Type: application/json" \
  -d "{\"session_id\": \"$SESSION_ID\", \"query\": \"Remember: my favorite color is blue\", \"user_id\": \"continuity-test\"}"

# Restart SessionManager backend
docker-compose restart claude-backend
sleep 10

# Test session resumption and context preservation
curl -X POST http://localhost:8000/claude/stream \
  -H "Content-Type: application/json" \
  -d "{\"session_id\": \"$SESSION_ID\", \"query\": \"What color did I mention?\", \"user_id\": \"continuity-test\"}"

# iOS App User Experience Testing
# Manual testing scenarios:

# 1. Session Switching Performance Test
# - Create 5+ sessions with different conversations
# - Switch between sessions rapidly
# - Verify <200ms switching time with SessionManager persistent clients
# - Confirm conversation context preserved during switches

# 2. App Lifecycle Testing
# - Start conversation in iOS app
# - Background app for 5+ minutes
# - Return to foreground
# - Verify session reconnection and context preservation

# 3. Network Disruption Testing
# - Start streaming conversation
# - Disable/enable network connection
# - Verify automatic reconnection with SessionManager session restoration

# 4. Conversation History Testing
# - Create session with multiple messages
# - Restart iOS app completely
# - Verify conversation history loads from persistence
# - Confirm SessionManager session resumption

# 5. Multiple Concurrent Sessions Testing
# - Create 10+ sessions with different contexts
# - Switch between sessions frequently
# - Verify session isolation and no context bleeding
# - Confirm SessionManager handles concurrent sessions

# Performance benchmarking with iOS Instruments
# Test session switching performance and memory usage
instruments -t "Time Profiler" -D session_performance.trace \
  -l 30000 "VisionForge.app"  # 30 second trace

# Memory usage analysis for session management
instruments -t "Allocations" -D session_memory.trace \
  -l 60000 "VisionForge.app"  # 60 second trace

# Expected: All creative validations pass, SessionManager integration delivers enhanced UX
```

## Final Validation Checklist

### Technical Validation

- [ ] All 4 validation levels completed successfully
- [ ] SessionManager integration tests pass with conversation continuity
- [ ] SwiftUI app builds successfully with enhanced session management
- [ ] No compilation errors: `xcodebuild -scheme VisionForge clean build`
- [ ] Unit tests pass: `xcodebuild test -scheme VisionForge`
- [ ] Session state management works correctly with @StateObject/@EnvironmentObject patterns
- [ ] CoreData session persistence functions correctly for offline access
- [ ] SessionManager API integration provides proper error handling and recovery

### Feature Validation

- [ ] Session switching completes in <200ms using SessionManager persistent clients
- [ ] Conversation history accessible across app launches with full context preservation
- [ ] Sessions persist correctly across backend restarts using enhanced SessionManager
- [ ] Real-time streaming maintains session context with conversation continuity
- [ ] Multiple concurrent sessions (10+) work without interference using SessionManager isolation
- [ ] Session resumption works reliably after network disruptions with automatic recovery
- [ ] Session history and metadata persist locally using CoreData for offline access
- [ ] Error handling provides clear feedback for SessionManager issues with automatic retry
- [ ] Background/foreground app transitions maintain session state and connections
- [ ] iOS app gracefully handles SessionManager cleanup and session lifecycle management

### Code Quality Validation

- [ ] Follows SwiftUI modern patterns: @StateObject for ownership, @EnvironmentObject for access
- [ ] SessionManager API integration follows async/await patterns consistently
- [ ] File placement matches desired codebase tree structure exactly
- [ ] Anti-patterns avoided: SwiftData for production, blocking session operations
- [ ] Dependencies properly managed: SessionStateManager, SessionPersistenceService
- [ ] CoreData integration stable and performant for session persistence
- [ ] Error handling comprehensive for SessionManager-specific scenarios
- [ ] Session caching optimized for performance without memory leaks

### SessionManager Integration Validation

- [ ] SessionManager persistent sessions leveraged for instant session switching
- [ ] Session creation uses enhanced SessionManager API with proper configuration
- [ ] Session resumption works through SessionManager with conversation continuity
- [ ] Session cleanup integrates with SessionManager lifecycle management
- [ ] Conversation context preserved across all SessionManager operations
- [ ] Session validation and error recovery handle SessionManager-specific issues
- [ ] Real-time streaming integrates with SessionManager session context
- [ ] Session metadata and statistics accessible from SessionManager backend

---

## Anti-Patterns to Avoid

### SwiftUI Session Management Anti-Patterns
- ❌ Don't use @StateObject in child views - causes ownership confusion and memory issues
- ❌ Don't skip @EnvironmentObject injection - breaks session state sharing across views
- ❌ Don't create multiple SessionStateManager instances - use singleton pattern with proper injection
- ❌ Don't ignore SwiftUI view lifecycle - properly manage session state during view recreation
- ❌ Don't block UI with synchronous session operations - use async/await patterns consistently

### SessionManager Integration Anti-Patterns
- ❌ Don't ignore SessionManager persistent session benefits - leverage for instant switching
- ❌ Don't create new sessions when SessionManager already has persistent clients
- ❌ Don't skip session context preservation during streaming - breaks conversation continuity
- ❌ Don't ignore SessionManager error types - handle specific error scenarios appropriately
- ❌ Don't bypass SessionManager session validation - causes "No conversation found" errors
- ❌ Don't skip SessionManager status monitoring - implement proper connection state handling

### iOS Persistence Anti-Patterns
- ❌ Don't use SwiftData for production session persistence - stability issues in 2024
- ❌ Don't skip local session caching - impacts performance and offline functionality
- ❌ Don't ignore conversation history persistence - users expect history across app launches
- ❌ Don't store sensitive data in local persistence without encryption
- ❌ Don't skip migration paths for persistence model changes

### Real-time Communication Anti-Patterns
- ❌ Don't ignore iOS background limitations for WebSocket connections
- ❌ Don't skip reconnection logic for app lifecycle transitions
- ❌ Don't assume connections persist across background/foreground cycles
- ❌ Don't ignore SessionManager session context during streaming operations
- ❌ Don't skip error recovery for streaming connection failures

### Performance & UX Anti-Patterns
- ❌ Don't reload entire conversations when switching sessions - leverage SessionManager persistence
- ❌ Don't skip session switching performance optimization - users expect instant switching
- ❌ Don't ignore memory management for session caching - implement proper cleanup
- ❌ Don't skip loading states during session operations - provide clear user feedback
- ❌ Don't ignore network state changes - implement proper connection monitoring and recovery