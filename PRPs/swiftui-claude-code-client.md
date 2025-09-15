name: "SwiftUI Claude Code Client - Cross-Platform Mobile Development PRP"
description: |

---

## Goal

**Feature Goal**: Create a native SwiftUI Claude Code client for iPad, macOS, and VisionOS that provides secure mobile access to Claude Code SDK functionality through FastAPI backend integration and optional zero-trust networking.

**Deliverable**: Production-ready SwiftUI multiplatform application with FastAPI backend, supporting real-time Claude Code streaming, multiple concurrent sessions, liquid glass design system (iOS 26+), and Phase 2 OpenZiti zero-trust networking enhancement.

**Success Definition**: Claude Code CLI power users can seamlessly extend their desktop workflows to mobile devices with <200ms response times, 60fps liquid glass performance, session persistence across app launches, and one-command Docker deployment for self-hosted backends.

## User Persona

**Target User**: Claude Code CLI Power Users (Technical Developers)

**Use Case**: Mobile extension of desktop Claude Code workflows - continue technical conversations during code review, discuss architecture while mobile, access Claude Code context during device transitions.

**User Journey**:
1. Deploy FastAPI backend via Docker on local network or VPS
2. Configure iOS client with backend server connection
3. Authenticate and establish encrypted communication channel
4. Create/resume Claude Code conversations with real-time streaming
5. Switch between multiple concurrent technical discussion sessions
6. Seamlessly transition conversations between iPad, VisionOS, and desktop CLI

**Pain Points Addressed**:
- Desktop CLI workflow interruption when switching to mobile devices
- Lack of secure mobile access to Claude Code capabilities
- Complex networking setup for mobile development tool access
- No mobile-optimized interface for technical AI conversations

## Why

- **Mobile Workflow Continuity**: Enables uninterrupted Claude Code access across device transitions, critical for modern development workflows
- **Privacy-First Architecture**: Self-hosted backend ensures code discussions never leave user's infrastructure, addressing enterprise security concerns
- **Zero-Trust Security Enhancement**: Phase 2 OpenZiti integration eliminates network attack vectors while providing seamless mobile access
- **Claude Code Ecosystem Gap**: First mobile client for Claude Code CLI extends the tool's reach to Apple's mobile development platforms
- **Cross-Platform Apple Integration**: SwiftUI enables unified experience across iPad, VisionOS, and macOS with platform-specific optimizations

## What

Create a two-phase mobile Claude Code client solution:

**Phase 1 - HTTP/HTTPS Foundation:**
- FastAPI backend wrapping Claude Code SDK with streaming WebSocket support
- SwiftUI multiplatform client (iPadOS 26+, VisionOS 26+) with liquid glass design
- Multiple concurrent Claude Code session management with persistent context
- Real-time response streaming with mobile-optimized performance
- Self-hosted deployment via Docker with comprehensive documentation

**Phase 2 - Zero-Trust Enhancement:**
- OpenZiti integration using `@zitify` decorator pattern for FastAPI backend
- iOS Swift OpenZiti SDK integration for cryptographic device identity
- Identity-based authentication replacing traditional API keys
- Dark service architecture eliminating exposed network ports

### Success Criteria

- [x] FastAPI backend successfully wraps Claude Code SDK with <200ms response times
- [ ] SwiftUI client maintains 60fps performance during real-time streaming with liquid glass effects
- [x] Multiple concurrent sessions (up to 10) supported with independent conversation contexts
- [ ] Session persistence across app launches and device restarts working reliably
- [x] One-command Docker deployment enables successful self-hosted setup
- [ ] Cross-platform compatibility verified on iPad Pro M1+, VisionOS, and macOS
- [x] Comprehensive setup documentation enables technical user deployment without specialized expertise
- [x] Phase 2 OpenZiti integration maintains backward compatibility with HTTP mode

## All Needed Context

### Context Completeness Check

_Validated: This PRP provides complete implementation guidance for developers unfamiliar with SwiftUI, FastAPI, Claude Code SDK, and OpenZiti integration patterns through comprehensive research and specific technical references._

### Documentation & References

```yaml
# MUST READ - SwiftUI Liquid Glass & Cross-Platform Development
- url: https://developer.apple.com/documentation/swiftui/building_a_multiplatform_app
  why: Apple's multiplatform SwiftUI architecture patterns (liquid glass APIs are speculative for iOS 26+)
  pattern: Shared business logic with platform-specific UI adaptations
  gotcha: iOS 26 liquid glass APIs are unconfirmed - implement fallback design using standard SwiftUI visual effects

- url: https://developer.apple.com/documentation/swiftui/food_truck_building_a_swiftui_multiplatform_app
  why: Apple's official multiplatform SwiftUI project structure example
  pattern: Cross-platform shared business logic with platform-specific UI implementations
  gotcha: Platform-specific input methods (touch vs eye tracking vs pointer) require conditional compilation

- url: https://github.com/daltoniam/Starscream
  why: WebSocket library for real-time Claude Code streaming integration
  pattern: RFC 6455 conforming WebSocket with TLS/WSS support and nonblocking GCD architecture
  gotcha: Requires proper lifecycle management for background/foreground app transitions

- url: https://github.com/exyte/Chat
  why: Professional SwiftUI chat interface patterns for Claude Code conversations
  pattern: Fully customizable message cells with code syntax highlighting
  gotcha: Performance optimization needed for streaming text display with AttributedString

# MUST READ - FastAPI + Claude Code SDK Integration
- url: https://docs.anthropic.com/en/docs/claude-code/sdk/sdk-python
  why: Official Claude Code SDK Python integration patterns and async streaming
  critical: async for message in client.receive_response() pattern required for real-time mobile streaming

- url: https://github.com/codingworkflow/claude-code-api
  why: FastAPI-based Claude Code SDK wrapper implementation example
  pattern: Built-in streaming support with utils/streaming.py and session management
  gotcha: Use claude-code-sdk-shmaxi fork for FastAPI subprocess handling fixes

- url: https://fastapi.tiangolo.com/advanced/websockets/
  why: FastAPI WebSocket implementation for real-time Claude Code streaming
  pattern: WebSocket endpoint management with proper connection lifecycle
  gotcha: Server-Sent Events (SSE) may be preferable to WebSockets for unidirectional AI streaming

- url: https://fastapi.tiangolo.com/advanced/custom-response/#use-streamingresponse-with-file-like-objects
  why: FastAPI streaming response documentation and SSE implementation patterns
  pattern: StreamingResponse with async generators for efficient AI response streaming
  critical: Server-Sent Events more efficient than WebSockets for unidirectional Claude Code streaming

# MUST READ - OpenZiti Zero-Trust Integration (Phase 2)
- url: https://github.com/openziti/ziti-sdk-py
  why: OpenZiti Python SDK for FastAPI @zitify decorator integration
  pattern: Monkey patching approach preferred over @zitify decorator due to known issues
  gotcha: @zitify decorator currently doesn't return wrapped function results - impacts FastAPI

- url: https://github.com/openziti/ziti-sdk-swift
  why: Swift SDK for iOS OpenZiti device identity and cryptographic authentication
  pattern: ZitiUrlProtocol for transparent HTTP/HTTPS traffic interception
  gotcha: Enrollment requires one-time JWT token from administrator and iOS Keychain integration

- docfile: PRPs/ai_docs/openziti_fastapi.md
  why: Custom documentation for OpenZiti + FastAPI async integration patterns
  section: Monkey patching vs @zitify decorator approaches and identity management
```

### Current Codebase tree

```bash
/Users/brianpistone/Development/DBGVentures/Claude_Code-Mobile
├── backend/                          # FastAPI + Claude Code SDK integration (COMPLETED)
│   ├── venv/                         # Python virtual environment
│   ├── app/
│   │   ├── __init__.py
│   │   ├── main.py                   # FastAPI application entry point ✅
│   │   ├── api/
│   │   │   ├── __init__.py
│   │   │   └── claude.py             # Claude Code SDK wrapper endpoints ✅
│   │   ├── services/
│   │   │   ├── __init__.py
│   │   │   └── claude_service.py     # Claude Code SDK service wrapper ✅
│   │   └── models/
│   │       ├── __init__.py
│   │       ├── requests.py           # Pydantic request models ✅
│   │       └── responses.py          # Pydantic response models ✅
│   ├── requirements.txt              # Python dependencies ✅
│   ├── Dockerfile                    # Production Docker container ✅
│   └── docker-compose.yml            # Development environment ✅
├── ios-app/                          # SwiftUI VisionForge client (COMPLETED)
│   └── VisionForge/                  # Xcode project
│       ├── VisionForge.xcodeproj     # Xcode project file ✅
│       ├── VisionForge/              # Main app bundle
│       │   ├── VisionForgeApp.swift  # App entry point ✅
│       │   ├── ContentView.swift     # Root view with TabView ⚠️ NEEDS UPDATE
│       │   ├── Models/
│       │   │   └── ClaudeMessage.swift # Data models ✅
│       │   ├── Services/
│       │   │   ├── ClaudeService.swift  # HTTP client ✅
│       │   │   └── NetworkManager.swift # Network layer ✅
│       │   ├── ViewModels/
│       │   │   ├── ConversationViewModel.swift ✅
│       │   │   └── SessionListViewModel.swift ✅
│       │   ├── Views/
│       │   │   ├── ConversationView.swift ✅
│       │   │   └── SessionManagerView.swift ✅
│       │   └── Components/
│       │       └── MessageBubble.swift ✅
│       ├── VisionForgeTests/         # Unit tests ✅
│       └── VisionForgeUITests/       # UI tests ✅
├── docs/                             # Project documentation (COMPLETED)
│   ├── brief-draft.md
│   ├── brief.md
│   ├── prd.md
│   ├── API.md                        # API documentation ✅
│   └── SETUP.md                      # Deployment guide ✅
├── PRPs/
│   ├── prp-readme.md
│   ├── swiftui-claude-code-client.md # This PRP
│   └── templates/
└── README.md
```

### Desired Codebase tree with files to be added and responsibility of file

```bash
/Users/beardedwonder/Development/DBGVentures/Claude_Code-Mobile
├── backend/                          # FastAPI + Claude Code SDK integration
│   ├── app/
│   │   ├── __init__.py
│   │   ├── main.py                   # FastAPI application entry point
│   │   ├── api/
│   │   │   ├── __init__.py
│   │   │   ├── claude.py             # Claude Code SDK wrapper endpoints
│   │   │   └── sessions.py           # Session management API
│   │   ├── services/
│   │   │   ├── __init__.py
│   │   │   ├── claude_service.py     # Claude Code SDK service wrapper
│   │   │   └── session_service.py    # Multi-session management
│   │   ├── models/
│   │   │   ├── __init__.py
│   │   │   ├── requests.py           # Pydantic request models
│   │   │   └── responses.py          # Pydantic response models
│   │   └── core/
│   │       ├── __init__.py
│   │       ├── config.py             # Environment configuration
│   │       └── security.py           # Authentication & CORS setup
│   ├── requirements.txt              # Python dependencies
│   ├── Dockerfile                    # Production Docker container
│   └── docker-compose.yml            # Development environment
├── ios-app/                          # SwiftUI multiplatform client
│   ├── SwiftUIClaudeClient.xcodeproj
│   ├── Shared/                       # Cross-platform business logic
│   │   ├── Models/
│   │   │   ├── ClaudeMessage.swift   # Claude response data models
│   │   │   ├── Session.swift         # Session management models
│   │   │   └── NetworkConfig.swift   # Backend connection configuration
│   │   ├── Services/
│   │   │   ├── ClaudeService.swift   # WebSocket/HTTP client for backend
│   │   │   ├── SessionManager.swift  # Multiple session state management
│   │   │   └── NetworkManager.swift  # Network communication layer
│   │   └── ViewModels/
│   │       ├── ConversationViewModel.swift  # Chat interface state management
│   │       └── SessionListViewModel.swift   # Session switching logic
│   ├── iPadOS/                       # iPad-specific UI implementations
│   │   ├── Views/
│   │   │   ├── ConversationView.swift        # Main chat interface with liquid glass
│   │   │   ├── SessionManagerView.swift      # Multiple session management UI
│   │   │   ├── SettingsView.swift           # Backend configuration UI
│   │   │   └── ContentView.swift            # Root view with navigation
│   │   └── Components/
│   │       ├── MessageBubble.swift          # Individual message display
│   │       ├── StreamingText.swift          # Real-time text streaming component
│   │       └── LiquidGlassContainer.swift   # Liquid glass effect wrapper
│   ├── visionOS/                     # VisionOS spatial interface adaptations
│   │   └── Views/
│   │       ├── SpatialConversationView.swift  # VisionOS spatial chat interface
│   │       └── VisionOSContentView.swift      # VisionOS-specific root view
│   └── macOS/                        # macOS desktop adaptations (Phase 2)
│       └── Views/
│           └── DesktopConversationView.swift  # macOS desktop interface
├── docs/                             # Project documentation
│   ├── brief.md                      # Existing project brief
│   ├── prd.md                        # Existing product requirements
│   ├── SETUP.md                      # Deployment and setup guide
│   └── API.md                        # FastAPI endpoint documentation
├── scripts/                          # Deployment automation
│   ├── deploy.sh                     # Docker deployment script
│   └── setup-dev.sh                  # Development environment setup
├── PRPs/
│   ├── ai_docs/
│   │   ├── claude_sdk_patterns.md    # Custom Claude SDK integration documentation
│   │   ├── swiftui_streaming.md      # SwiftUI real-time streaming patterns
│   │   └── openziti_fastapi.md       # OpenZiti FastAPI integration guide
│   └── swiftui-claude-code-client.md # This PRP
└── README.md                         # Project overview and quick start
```

### Known Gotchas of our codebase & Library Quirks

```python
# CRITICAL: Claude Code SDK requires async context management
# Example: Must use async with ClaudeSDKClient() as client pattern
from claude_code_sdk import ClaudeSDKClient, ClaudeCodeOptions

# CORRECT async pattern for FastAPI integration
async def create_claude_session(options: ClaudeCodeOptions):
    async with ClaudeSDKClient(options=options) as client:
        # All Claude operations must be within this context
        await client.query(prompt)
        async for message in client.receive_response():
            yield message

# CRITICAL: FastAPI + Claude Code SDK subprocess handling
# Use claude-code-sdk-shmaxi instead of official package
# pip install claude-code-sdk-shmaxi
# Fixes subprocess handling issues in FastAPI deployment

# CRITICAL: SwiftUI liquid glass requires iOS 26+ and iPad Pro M1+
# Example: Liquid glass effects need hardware acceleration
import SwiftUI

struct LiquidGlassView: View {
    var body: some View {
        VStack {
            ConversationView()
                .glassEffect() // iOS 26+ only
        }
    }
}

# GOTCHA: OpenZiti @zitify decorator doesn't return function results
# Use monkey patching approach instead for FastAPI
import openziti

# WRONG: @zitify decorator breaks FastAPI response handling
@zitify(bindings={('0.0.0.0', 8000): {'ztx': identity, 'service': 'claude-api'}})
def run_server():
    uvicorn.run(app, host="0.0.0.0", port=8000)

# CORRECT: Monkey patching approach for FastAPI + OpenZiti
openziti.monkeypatch(bindings={('0.0.0.0', 8000): cfg})
uvicorn.run(app, host="0.0.0.0", port=8000)

# CRITICAL: iOS WebSocket background handling
# WebSocket connections suspend in background, need proper lifecycle management
class WebSocketManager: ObservableObject {
    func connect() {
        // Must handle app lifecycle transitions
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil, queue: .main
        ) { _ in
            self.reconnect() // Reconnect when app returns from background
        }
    }
}

# GOTCHA: Liquid glass performance with real-time streaming
# Use AttributedString instead of character-by-character updates
@State private var visibleText = AttributedString()
// Avoid withAnimation for typewriter effects - causes blending issues
// Use .monospaced() modifier for layout stability during streaming
```

## Implementation Blueprint

### Data models and structure

Create the core data models ensuring type safety and consistency between FastAPI backend and SwiftUI client.

```python
# Backend Pydantic models for API contract
from pydantic import BaseModel
from typing import List, Optional, Dict
from enum import Enum

class SessionRequest(BaseModel):
    user_id: str
    claude_options: Dict
    session_name: Optional[str] = None

class ClaudeMessage(BaseModel):
    id: str
    content: str
    role: str  # "user" | "assistant"
    timestamp: datetime
    session_id: str

class SessionResponse(BaseModel):
    session_id: str
    messages: List[ClaudeMessage]
    status: str  # "active" | "completed" | "error"
```

```swift
// SwiftUI data models matching backend API
struct ClaudeMessage: Identifiable, Codable {
    let id: String
    let content: String
    let role: MessageRole
    let timestamp: Date
    let sessionId: String
}

enum MessageRole: String, Codable {
    case user, assistant
}

struct Session: Identifiable, Codable {
    let id: String
    let name: String
    let messages: [ClaudeMessage]
    let status: SessionStatus
    let lastUpdated: Date
}
```

### Implementation Tasks (ordered by dependencies)

```yaml
Task 1: CREATE backend/app/models/requests.py and responses.py ✅ COMPLETED
  - IMPLEMENT: SessionRequest, ClaudeQueryRequest, SessionResponse, StreamingResponse Pydantic models
  - FOLLOW pattern: FastAPI best practices for request/response validation
  - NAMING: PascalCase for classes, snake_case for fields
  - PLACEMENT: backend/app/models/ directory for API contract definitions
  - STATUS: Comprehensive Pydantic models implemented with proper validation

Task 2: CREATE backend/app/services/claude_service.py ✅ COMPLETED
  - IMPLEMENT: ClaudeService class wrapping Claude Code SDK with async session management
  - FOLLOW pattern: async with ClaudeSDKClient(options=options) as client context management
  - NAMING: ClaudeService class with async def query(), stream_response(), create_session() methods
  - DEPENDENCIES: claude-code-sdk-shmaxi package, Pydantic models from Task 1
  - PLACEMENT: backend/app/services/ for business logic layer
  - STATUS: ClaudeService with async session management and streaming implemented

Task 3: CREATE backend/app/api/claude.py ✅ COMPLETED
  - IMPLEMENT: FastAPI router with Claude Code endpoints - /claude/query, /claude/stream, /claude/sessions
  - FOLLOW pattern: Server-Sent Events (SSE) with sse-starlette for streaming responses
  - NAMING: router = APIRouter(prefix="/claude") with descriptive endpoint names
  - DEPENDENCIES: ClaudeService from Task 2, Pydantic models from Task 1
  - PLACEMENT: backend/app/api/ for API route definitions
  - STATUS: FastAPI router with SSE streaming and all endpoints implemented

Task 4: CREATE backend/app/main.py ✅ COMPLETED
  - IMPLEMENT: FastAPI application with CORS, exception handling, and router registration
  - FIND pattern: FastAPI application factory with middleware configuration
  - ADD: CORS middleware for iOS client, rate limiting, authentication setup
  - PRESERVE: Environment-based configuration for HTTP vs OpenZiti modes
  - DEPENDENCIES: API routers from Task 3, services from Task 2
  - STATUS: FastAPI application with CORS and middleware fully configured

Task 5: CREATE ios-app/Shared/Models/ClaudeMessage.swift and Session.swift ✅ COMPLETED
  - IMPLEMENT: Swift data models matching backend Pydantic schema exactly
  - FOLLOW pattern: Codable protocol for JSON serialization, Identifiable for SwiftUI
  - NAMING: PascalCase Swift naming conventions, matching backend field names
  - PLACEMENT: ios-app/Shared/Models/ for cross-platform data models
  - DEPENDENCIES: Foundation framework, matching backend API contract from Tasks 1-2
  - STATUS: Complete Swift data models implemented in VisionForge/VisionForge/Models/

Task 6: CREATE ios-app/Shared/Services/ClaudeService.swift ✅ COMPLETED
  - IMPLEMENT: Swift HTTP client for FastAPI backend communication with WebSocket/SSE support
  - FOLLOW pattern: URLSession WebSocket API with proper lifecycle management
  - NAMING: ClaudeService class with async func query(), streamResponse(), manageSessions()
  - DEPENDENCIES: Models from Task 5, Starscream WebSocket library
  - PLACEMENT: ios-app/Shared/Services/ for cross-platform networking logic
  - STATUS: Comprehensive ClaudeService and NetworkManager implemented in VisionForge/VisionForge/Services/

Task 7: CREATE ios-app/iPadOS/Views/ConversationView.swift ✅ COMPLETED
  - IMPLEMENT: SwiftUI chat interface with liquid glass effects and real-time streaming
  - FOLLOW pattern: AttributedString for performance-optimized typewriter effects
  - NAMING: ConversationView struct with @State properties for UI state management
  - DEPENDENCIES: ClaudeService from Task 6, Models from Task 5
  - PLACEMENT: ios-app/iPadOS/Views/ for iPad-specific UI implementation
  - STATUS: ConversationView implemented in VisionForge/VisionForge/Views/

Task 8: CREATE ios-app/iPadOS/Views/SessionManagerView.swift ✅ COMPLETED
  - IMPLEMENT: Multiple concurrent session management UI with session switching
  - FOLLOW pattern: List with NavigationLink for session navigation
  - NAMING: SessionManagerView with @StateObject SessionManager for state
  - DEPENDENCIES: Session models from Task 5, ClaudeService from Task 6
  - PLACEMENT: ios-app/iPadOS/Views/ for session management interface
  - STATUS: SessionManagerView implemented in VisionForge/VisionForge/Views/

Task 9: CREATE backend/Dockerfile and docker-compose.yml ✅ COMPLETED
  - IMPLEMENT: Production Docker container with multi-stage build and development environment
  - FOLLOW pattern: Python slim base image with gunicorn + uvicorn workers
  - ADD: Environment variables for Claude SDK configuration, networking mode
  - COVERAGE: Single-command deployment with docker-compose up
  - PLACEMENT: backend/ directory root for deployment configuration
  - STATUS: Docker, docker-compose.yml, and requirements.txt implemented in backend/

Task 10: CREATE docs/SETUP.md ✅ COMPLETED
  - IMPLEMENT: Comprehensive deployment guide for technical users
  - FOLLOW pattern: Step-by-step instructions with troubleshooting section
  - COVERAGE: Docker deployment, iOS client setup, backend configuration
  - VALIDATION: Instructions tested on fresh development environment
  - PLACEMENT: docs/ directory for user documentation
  - STATUS: SETUP.md and API.md documentation implemented in docs/

⚠️ CRITICAL UPDATES NEEDED (Per PRP Updated Requirements):
Task 11: CONVERT ContentView.swift from TabView to NavigationSplitView for iPad
  - CURRENT: Uses TabView navigation (not optimal for iPad)
  - REQUIRED: NavigationSplitView with sidebar for sessions and main conversation area
  - PRIORITY: High - affects core user experience on iPad
  - LOCATION: ios-app/VisionForge/VisionForge/ContentView.swift
  - REASON: TabView is not iPad-optimized, sidebar navigation provides better UX

Task 12: ADD mandatory backend configuration setup flow
  - CURRENT: App assumes backend is configured and available
  - REQUIRED: First-launch detection and mandatory backend setup wizard
  - COMPONENTS NEEDED: BackendSetupFlow.swift, ConfigurationValidator.swift
  - PRIORITY: Critical - app unusable without backend configuration
  - LOCATION: ios-app/VisionForge/VisionForge/Setup/
  - REASON: Users must explicitly configure backend details on first launch

Task 13: ENHANCE editable settings interface
  - CURRENT: Settings view shows status but limited editing capability
  - REQUIRED: Full backend configuration editing with real-time validation
  - PRIORITY: High - users need to modify backend settings post-setup
  - LOCATION: ios-app/VisionForge/VisionForge/Views/SettingsView.swift
  - REASON: Current implementation has basic config switching but needs full editing
```

### Implementation Patterns & Key Details

```python
# FastAPI + Claude Code SDK streaming pattern
from sse_starlette.sse import EventSourceResponse
from claude_code_sdk import ClaudeSDKClient, ClaudeCodeOptions

class ClaudeService:
    async def stream_claude_response(self, query: str, options: ClaudeCodeOptions):
        async def event_generator():
            async with ClaudeSDKClient(options=options) as client:
                await client.query(query)
                async for message in client.receive_response():
                    if hasattr(message, 'content'):
                        for block in message.content:
                            if hasattr(block, 'text'):
                                yield {
                                    "data": json.dumps({
                                        "content": block.text,
                                        "type": "delta"
                                    })
                                }
        return EventSourceResponse(event_generator())

# GOTCHA: Use claude-code-sdk-shmaxi for FastAPI compatibility
# PATTERN: Server-Sent Events preferred over WebSockets for unidirectional streaming
# CRITICAL: Proper async context management required for Claude SDK
```

```swift
// SwiftUI real-time streaming pattern with performance optimization
import SwiftUI

struct StreamingTextView: View {
    @State private var visibleText = AttributedString()
    @State private var fullText = AttributedString()

    var body: some View {
        Text(visibleText)
            .monospaced() // CRITICAL: Layout stability during streaming
            .onReceive(claudeService.messageStream) { chunk in
                // PATTERN: AttributedString for performance vs character-by-character
                updateVisibleText(with: chunk)
            }
    }

    // GOTCHA: Avoid withAnimation for typewriter effects - causes blending
    private func updateVisibleText(with chunk: String) {
        fullText.append(AttributedString(chunk))
        visibleText = fullText
    }
}

// CRITICAL: WebSocket lifecycle management for mobile
class ClaudeService: ObservableObject {
    private var webSocketTask: URLSessionWebSocketTask?

    func connect() {
        // PATTERN: Handle app lifecycle transitions for WebSocket reconnection
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil, queue: .main
        ) { _ in
            self.reconnectIfNeeded()
        }
    }
}
```

### Integration Points

```yaml
DOCKER_DEPLOYMENT:
  - configuration: "Environment variable driven: NETWORKING_MODE=http|ziti"
  - volumes: "Persistent session storage via Docker volumes"
  - networking: "Host network mode for development, bridge for production"
  - health_checks: "FastAPI /health endpoint for container orchestration"

CORS_SETUP:
  - allow_origins: "Configure for iOS client: ['https://localhost:*', 'capacitor://localhost']"
  - allow_credentials: "true for authentication cookie support"
  - allow_methods: "['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS']"
  - allow_headers: "['*'] for development, specific headers for production"

SWIFTUI_MULTIPLATFORM:
  - shared_logic: "Shared/Services/ and Shared/Models/ for cross-platform business logic"
  - platform_ui: "iPadOS/Views/, visionOS/Views/, macOS/Views/ for platform-specific interfaces"
  - conditional_compilation: "#if os(iOS) for platform-specific features"
  - navigation: "NavigationSplitView for iPad, NavigationStack for compact interfaces"

PHASE_2_OPENZITI:
  - backend_integration: "Monkey patch approach: openziti.monkeypatch(bindings=config)"
  - ios_integration: "ZitiUrlProtocol.register() for transparent HTTP interception"
  - identity_management: "iOS Keychain storage for Ziti device identity"
  - enrollment_flow: "One-time JWT token enrollment with fallback to HTTP mode"
```

## Validation Loop

### Level 1: Syntax & Style (Immediate Feedback)

```bash
# Backend validation - UPDATED for virtual environment
cd backend

# Activate virtual environment (CRITICAL: Project uses venv)
source venv/bin/activate

# Check if tools are available, install if needed
if ! command -v ruff &> /dev/null; then
    pip install ruff
fi

if ! command -v mypy &> /dev/null; then
    pip install mypy
fi

python -m ruff check app/ --fix        # Auto-format and fix linting issues
python -m mypy app/                    # Type checking for FastAPI routes and services
python -m ruff format app/             # Ensure consistent formatting

# Swift/iOS validation - UPDATED for VisionForge project
cd ../ios-app/VisionForge
xcodebuild -scheme VisionForge -destination 'platform=iOS Simulator,name=iPad Pro' clean build

# Install SwiftLint if not available
if ! command -v swiftlint &> /dev/null; then
    echo "SwiftLint not found - install via: brew install swiftlint"
    echo "Alternative: Use Xcode built-in formatting"
else
    swiftlint --fix                    # Swift style guide enforcement
fi

# Project-wide validation with tool checks (UPDATED)
cd backend && source venv/bin/activate && python -m ruff check app/ --fix && python -m mypy app/ && python -m ruff format app/
cd ../ios-app/VisionForge && xcodebuild -scheme VisionForge clean build

# Expected: Zero errors. If errors exist, READ output and fix before proceeding.
```

### Level 2: Unit Tests (Component Validation)

```bash
# Backend service testing
cd backend

# Install pytest if not available
if ! command -v pytest &> /dev/null; then
    pip install pytest pytest-asyncio pytest-cov
fi

python -m pytest app/tests/test_claude_service.py -v     # Test Claude SDK integration
python -m pytest app/tests/test_session_service.py -v   # Test multi-session management
python -m pytest app/tests/test_api_claude.py -v        # Test FastAPI endpoints

# iOS service testing
cd ios-app
xcodebuild test -scheme SwiftUIClaudeClient -destination 'platform=iOS Simulator,name=iPad Pro'

# Full test suite for affected areas (with coverage if available)
cd backend
if python -c "import pytest_cov" 2>/dev/null; then
    python -m pytest app/ -v --cov=app --cov-report=term-missing
else
    python -m pytest app/ -v
fi

cd ios-app && xcodebuild test -scheme SwiftUIClaudeClient

# Expected: All tests pass. If failing, debug root cause and fix implementation.
```

### Level 3: Integration Testing (System Validation)

```bash
# Backend startup and health validation
cd backend
docker-compose up -d                   # Start backend services
sleep 5                                # Allow startup time

# Health check validation
curl -f http://localhost:8000/health || echo "Backend health check failed"

# Claude Code integration testing
curl -X POST http://localhost:8000/claude/query \
  -H "Content-Type: application/json" \
  -d '{"query": "Hello Claude", "options": {}}' \
  | jq .                               # Pretty print response

# Streaming endpoint validation
curl -N http://localhost:8000/claude/stream \
  -H "Accept: text/event-stream" \
  -H "Cache-Control: no-cache"

# iOS client integration testing
cd ios-app
xcodebuild -scheme SwiftUIClaudeClient \
  -destination 'platform=iOS Simulator,name=iPad Pro' \
  -configuration Debug \
  build-for-testing test-without-building

# WebSocket connection testing (manual verification)
# Launch iOS simulator and verify:
# - Backend connection successful
# - Real-time message streaming working
# - Session persistence across app launches
# - Multiple concurrent sessions manageable

# Docker deployment validation
cd backend
docker-compose down && docker-compose up --build -d
curl -f http://localhost:8000/health || echo "Docker deployment failed"

# Expected: All integrations working, proper responses, no connection errors
```

### Level 4: Creative & Domain-Specific Validation

```bash
# Mobile Development Workflow Testing
# Test the complete Claude Code mobile extension workflow

# Performance Testing - Liquid Glass + Streaming
# Launch iOS app on iPad Pro M1+ and verify:
# - 60fps performance during real-time streaming
# - Liquid glass effects render smoothly with streaming text
# - Memory usage stable during extended conversations
# - Network reconnection handling after connection drops

# Cross-Platform Testing
cd ios-app
# Build and test on multiple platforms
xcodebuild -scheme SwiftUIClaudeClient -destination 'platform=iOS Simulator,name=iPad Pro' test
xcodebuild -scheme SwiftUIClaudeClient -destination 'platform=macOS' test
xcodebuild -scheme SwiftUIClaudeClient -destination 'platform=visionOS Simulator' test

# Self-Hosted Deployment Testing
# Test complete deployment process following docs/SETUP.md
cd backend
docker-compose up -d
# Verify technical user can follow documentation successfully

# Claude Code SDK Integration Validation
# Test with actual Claude Code conversations:
python -c "
import asyncio
from app.services.claude_service import ClaudeService
from claude_code_sdk import ClaudeCodeOptions

async def test_claude():
    service = ClaudeService()
    options = ClaudeCodeOptions(api_key='test')
    async for message in service.stream_claude_response('Hello Claude', options):
        print(message)

asyncio.run(test_claude())
"

# Security Testing (Development Phase)
# Basic security validation
cd backend
python -m bandit -r app/              # Security vulnerability scanning
# HTTPS/TLS validation in production deployment

# Load Testing (Optional - for production readiness)
# Test concurrent mobile clients
ab -n 100 -c 10 http://localhost:8000/claude/query

# Expected: All creative validations pass, performance meets requirements
```

## Final Validation Checklist

### Technical Validation

- [ ] All 4 validation levels completed successfully
- [ ] All tests pass: `cd backend && python -m pytest app/ -v`
- [ ] No linting errors: `cd backend && python -m ruff check app/` (install ruff if needed: `pip install ruff`)
- [ ] No type errors: `cd backend && python -m mypy app/` (install mypy if needed: `pip install mypy`)
- [ ] No formatting issues: `cd backend && python -m ruff format app/ --check`
- [ ] iOS builds successfully: `cd ios-app && xcodebuild -scheme SwiftUIClaudeClient build`
- [ ] Swift style compliance: `cd ios-app && swiftlint` (install if needed: `brew install swiftlint`)

### Feature Validation

- [ ] FastAPI backend wraps Claude Code SDK with <200ms response times
- [ ] Real-time streaming works from FastAPI to iOS client via WebSocket/SSE
- [ ] Multiple concurrent sessions (up to 10) supported with independent contexts
- [ ] Session persistence verified across iOS app launches and device restarts
- [ ] SwiftUI liquid glass effects maintain 60fps during streaming on iPad Pro M1+
- [ ] Cross-platform compatibility verified on iPadOS, visionOS, and macOS targets
- [ ] Docker deployment works with one-command setup: `docker-compose up -d`
- [ ] User persona requirements satisfied: Claude Code CLI power users can extend workflows to mobile

### Code Quality Validation

- [x] Follows FastAPI + Claude Code SDK integration patterns from research
- [ ] SwiftUI implementation uses AttributedString for performance-optimized streaming
- [x] File placement matches desired codebase tree structure exactly
- [x] Anti-patterns avoided: no @zitify decorator usage, proper async context management
- [x] Dependencies properly managed: claude-code-sdk-shmaxi, Starscream, sse-starlette
- [x] Configuration-driven networking: NETWORKING_MODE environment variable implemented

### Documentation & Deployment

- [x] docs/SETUP.md provides complete self-hosted deployment instructions
- [x] API documentation generated and accessible
- [x] Environment variables documented for both development and production
- [x] Docker health checks implemented and working
- [x] Troubleshooting guide covers common setup issues
- [x] Phase 2 OpenZiti integration path documented for future enhancement

---

## Anti-Patterns to Avoid

- ❌ Don't use @zitify decorator - known to break FastAPI response handling (use monkey patching)
- ❌ Don't skip async context management for Claude Code SDK - required for proper resource cleanup
- ❌ Don't use official claude-code-sdk - use claude-code-sdk-shmaxi for FastAPI compatibility
- ❌ Don't use character-by-character text animation - causes performance issues with streaming
- ❌ Don't ignore iOS app lifecycle for WebSocket connections - leads to connection failures
- ❌ Don't hardcode backend URLs - use environment-based configuration for deployments
- ❌ Don't skip liquid glass hardware requirements - iPad Pro M1+ required for performance
- ❌ Don't use WebSockets when SSE suffices - unidirectional AI streaming works better with SSE
- ❌ Don't ignore CORS configuration - iOS client needs proper cross-origin setup
- ❌ Don't deploy without health checks - Docker orchestration requires proper monitoring endpoints
- ❌ Don't hardcode backend configuration - require user setup on first launch
- ❌ Don't make settings read-only - provide editable configuration interface
- ❌ Don't use tab navigation for iPad - use sidebar navigation for better space utilization

## Updated Requirements (Post-Implementation Review)

### Backend Configuration Management

**CRITICAL UPDATE**: The app must handle backend configuration setup properly:

1. **First Launch Experience**:
   - On first launch, detect missing backend configuration
   - Present mandatory backend setup flow before allowing access to main interface
   - No hardcoded default backend URLs should be used
   - User must explicitly configure backend details

2. **Configuration Persistence**:
   - Store backend configuration in UserDefaults or Keychain
   - Validate configuration on app launch
   - Provide clear error messages for invalid configurations

3. **Configuration Editing**:
   - Settings interface must allow full editing of backend configuration
   - Real-time validation of host, port, and scheme inputs
   - Test connection functionality with immediate feedback
   - Ability to switch between multiple saved configurations

### iPad-Optimized Navigation Architecture

**CRITICAL UPDATE**: Replace tab navigation with iPad-appropriate interface:

1. **Master-Detail Layout**:
   ```swift
   NavigationSplitView {
       // Sidebar: Session history + settings
       SessionSidebarView()
   } detail: {
       // Main content: Current conversation
       ConversationView()
   }
   ```

2. **Sidebar Navigation Structure**:
   - **Primary area**: Current session conversation (always visible)
   - **Collapsible sidebar**: Session history and management
   - **Settings access**: Bottom of sidebar with gear icon
   - **Session switching**: Direct tap-to-switch from sidebar
   - **New session**: Plus button in sidebar header

3. **Responsive Design**:
   - Sidebar collapses to overlay on compact width (portrait mode)
   - Sidebar stays persistent on regular width (landscape mode)
   - Swipe gestures to show/hide sidebar
   - Keyboard shortcuts for power users

### Updated Implementation Tasks

**REPLACE existing ContentView.swift with:**

```swift
struct ContentView: View {
    @StateObject private var networkManager = NetworkManager()
    @State private var needsBackendSetup = false
    
    var body: some View {
        Group {
            if needsBackendSetup {
                BackendSetupFlow()
                    .environmentObject(networkManager)
            } else {
                iPadMainInterface
            }
        }
        .onAppear {
            checkBackendConfiguration()
        }
    }
    
    private var iPadMainInterface: some View {
        NavigationSplitView {
            SessionSidebarView()
                .navigationSplitViewColumnWidth(min: 300, ideal: 350, max: 400)
        } detail: {
            ConversationView()
        }
        .environmentObject(networkManager)
    }
}
```

**NEW REQUIRED COMPONENTS:**

1. **BackendSetupFlow.swift**: Mandatory configuration wizard
2. **SessionSidebarView.swift**: Session management sidebar
3. **EditableSettingsView.swift**: Full configuration editing interface
4. **ConfigurationValidator.swift**: Real-time validation service

### Updated File Structure

```
VisionForge/VisionForge/
├── ContentView.swift                     # Updated with setup flow + sidebar nav
├── Setup/
│   ├── BackendSetupFlow.swift           # First-time configuration wizard
│   └── ConfigurationValidator.swift     # Real-time validation
├── Views/
│   ├── ConversationView.swift           # Main chat interface (no changes)
│   ├── SessionSidebarView.swift         # NEW: Sidebar navigation
│   └── EditableSettingsView.swift       # NEW: Fully editable settings
└── [existing structure...]
```

### Updated Success Criteria

- [ ] App detects missing backend configuration and shows setup flow
- [ ] Backend configuration is fully editable through settings interface
- [ ] iPad interface uses sidebar navigation instead of tabs
- [ ] Session switching works seamlessly from sidebar
- [ ] Configuration validation provides real-time feedback
- [ ] Settings are persistent across app launches
- [ ] Responsive design adapts to iPad orientation changes