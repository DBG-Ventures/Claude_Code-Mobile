name: "Claude Code Mobile - Enhanced Session Management & Conversation Continuity PRP"
description: |

---

## Goal

**Feature Goal**: Implement robust session management and conversation continuity for Claude Code Mobile using persistent ClaudeSDKClient instances and session registry architecture, eliminating "No conversation found" errors while supporting multiple concurrent sessions with full context preservation.

**Deliverable**: Enhanced FastAPI backend with persistent ClaudeSDKClient session management, improved session registry with proper cleanup, reliable conversation resumption across app restarts, and comprehensive session lifecycle management that maintains conversation context across all mobile client interactions.

**Success Definition**: iOS app users can seamlessly switch between multiple Claude Code conversations without losing context, sessions persist reliably across backend restarts, conversation history is preserved across app launches, and session management handles 10+ concurrent sessions without performance degradation or context loss.

## User Persona

**Target User**: Claude Code CLI Power Users extending workflows to mobile devices

**Use Case**: Multi-session mobile development workflow - maintaining separate Claude Code conversations for different technical contexts (architecture planning, debugging specific issues, code reviews, feature implementation) while preserving full conversation history and context across device transitions and app restarts.

**User Journey**:
1. Create multiple Claude Code conversation sessions in iOS app for different projects/contexts
2. Have extended technical conversations with Claude about different topics in each session
3. Switch seamlessly between sessions without losing conversation context
4. Resume conversations after app restarts with full history preserved
5. Access conversation history for reference and continuation
6. Work across multiple concurrent sessions without interference

**Pain Points Addressed**:
- "No conversation found with session ID" errors breaking conversation flow
- Context loss when switching between sessions in mobile app
- Session history unavailable after app/backend restarts
- Inability to maintain multiple concurrent technical discussions
- Poor session management causing performance issues and reliability problems

## Why

- **Critical Mobile UX Issue**: Session management failures render the core value proposition of mobile Claude Code access unusable
- **SDK Architecture Mismatch**: Current implementation fights against Claude Code SDK's intended usage patterns instead of leveraging them effectively
- **Session Persistence Gap**: Current implementation loses session context across restarts, breaking conversation continuity
- **Multi-Session Requirements**: Mobile users need multiple concurrent conversations for different technical contexts
- **Performance & Reliability**: Proper session management prevents resource leaks and improves response times
- **Claude SDK Best Practices**: Align with recommended ClaudeSDKClient patterns for persistent conversations

## What

Implement comprehensive session management architecture featuring:

1. **Persistent ClaudeSDKClient Management**: Singleton SessionManager maintaining long-lived ClaudeSDKClient instances for each session
2. **Enhanced Session Registry**: Improved PersistentSessionStorage with session metadata, working directory tracking, and cleanup capabilities
3. **Conversation Continuity**: Reliable session resumption using ClaudeSDKClient resume functionality with full context preservation
4. **Session Lifecycle Management**: Automatic cleanup of inactive sessions, graceful shutdown handling, and resource management
5. **Multi-Session Support**: Support for 10+ concurrent sessions without interference or performance degradation
6. **Mobile-Optimized Streaming**: Preserve existing SSE streaming optimizations while adding session persistence

### Success Criteria

- [ ] iOS app session switching maintains full conversation history and context
- [ ] Sessions persist correctly across FastAPI backend restarts and Docker deployments
- [ ] Session resumption works reliably with <200ms response times
- [ ] Multiple concurrent sessions (10+) work without interference or context bleeding
- [ ] Session lifecycle management prevents memory leaks and resource exhaustion
- [ ] Conversation history is accessible programmatically for mobile UI display
- [ ] Streaming responses maintain <100ms first chunk latency with session persistence
- [ ] Session cleanup occurs automatically for inactive sessions (configurable timeout)
- [ ] Error handling provides clear debugging information for session management issues
- [ ] Backend API tests demonstrate reliable session continuity across restart scenarios

## All Needed Context

### Context Completeness Check

_Validated: This PRP provides complete implementation guidance for developers unfamiliar with Claude Code SDK session management, persistent client patterns, and FastAPI lifecycle management through comprehensive research and specific technical references._

### Documentation & References

```yaml
# MUST READ - Claude Code SDK Session Management
- url: https://github.com/anthropics/claude-code-sdk-python/issues/109
  why: Official GitHub issue discussing session management, conversation history access, and current limitations
  critical: Sessions stored as .jsonl files in ~/.claude/projects/, manual parsing challenges, SDK improvement roadmap
  pattern: ClaudeSDKClient maintains context during resume but lacks programmatic history access

- url: https://docs.claude.com/en/docs/claude-code/sdk/sdk-overview
  why: Official Claude Code SDK documentation with authentication, configuration, and deployment patterns
  pattern: File system-based configuration, automatic context management, production-ready error handling
  critical: SDK designed for persistent conversations with ClaudeSDKClient

# MUST READ - Current Implementation Analysis (Critical Issues Found)
- file: backend/app/services/claude_service.py
  why: Current session management implementation with mixed ClaudeSDKClient and query() usage
  pattern: PersistentSessionStorage integration, working directory management, session extraction logic
  gotcha: Uses standalone query() for session creation but ClaudeSDKClient for resumption (inconsistent)
  gotcha: Session ID extraction may not work reliably, lacks proper session validation

- file: backend/app/utils/session_storage.py
  why: Persistent session metadata storage implementation with thread safety
  pattern: JSON file-based storage with atomic writes, session cleanup capabilities
  critical: Provides session metadata persistence but doesn't integrate with ClaudeSDKClient lifecycle

- file: backend/app/core/lifecycle.py
  why: FastAPI application lifecycle management with working directory setup
  pattern: Working directory consistency for Claude SDK operations, session storage initialization
  critical: Sets working directory before Claude operations for consistent session storage

- file: docs/claude-sdk-session-manager-implementation-plan.md
  why: Detailed implementation plan for SessionManager architecture with persistent clients
  pattern: SessionManager singleton with ClaudeSDKClient pools, cleanup loop, lifecycle management
  critical: Complete architecture for addressing current session management issues

# MUST READ - FastAPI Integration Patterns
- url: https://fastapi.tiangolo.com/advanced/events/#lifespan
  why: FastAPI lifespan events for proper service initialization and cleanup
  pattern: @asynccontextmanager async def lifespan(app: FastAPI) for startup/shutdown
  critical: Essential for SessionManager initialization and graceful cleanup

- url: https://fastapi.tiangolo.com/tutorial/dependencies/#using-dependencies-in-path-operation-functions
  why: Dependency injection patterns for singleton service management
  pattern: @lru_cache decorator for singleton service instances
  gotcha: Global variables don't work reliably with multiple FastAPI workers
```

### Current Codebase tree

```bash
Claude_Code-Mobile/
├── backend/
│   ├── app/
│   │   ├── main.py                   # FastAPI application with lifespan management
│   │   ├── api/
│   │   │   └── claude.py             # Claude API endpoints with SSE streaming
│   │   ├── services/
│   │   │   └── claude_service.py     # Current mixed SDK usage (NEEDS ENHANCEMENT)
│   │   ├── models/
│   │   │   ├── requests.py           # Pydantic request models
│   │   │   └── responses.py          # Pydantic response models
│   │   ├── core/
│   │   │   └── lifecycle.py          # Working directory and session storage setup
│   │   └── utils/
│   │       ├── session_storage.py    # Persistent session metadata storage
│   │       └── logging.py            # Structured logging utilities
│   ├── requirements.txt              # Claude Code SDK dependencies
│   ├── Dockerfile                    # Multi-stage container configuration
│   └── docker-compose.yml            # Docker deployment with volumes
├── ios-app/VisionForge/              # SwiftUI iOS client
├── docs/
│   ├── SETUP.md                      # Deployment documentation
│   └── claude-sdk-session-manager-implementation-plan.md  # Implementation plan
├── .claude_sessions.json             # Persistent session registry
└── PRPs/
    ├── templates/prp_base.md          # PRP template structure
    └── claude-mobile-session-management-v2.md  # This PRP
```

### Desired Codebase tree with files to be added and responsibility of file

```bash
Claude_Code-Mobile/
├── backend/
│   ├── app/
│   │   ├── main.py                   # Enhanced with SessionManager integration
│   │   ├── api/
│   │   │   └── claude.py             # Updated with SessionManager dependency injection
│   │   ├── services/
│   │   │   ├── claude_service.py     # Enhanced with SessionManager integration
│   │   │   └── session_manager.py    # NEW: Persistent ClaudeSDKClient management
│   │   ├── models/
│   │   │   ├── requests.py           # Enhanced with session management options
│   │   │   └── responses.py          # Enhanced with session history support
│   │   ├── core/
│   │   │   ├── lifecycle.py          # Enhanced with SessionManager initialization
│   │   │   └── config.py             # Enhanced with session management configuration
│   │   └── utils/
│   │       ├── session_storage.py    # Enhanced with SessionManager integration
│   │       ├── session_utils.py      # NEW: Session validation and recovery utilities
│   │       └── logging.py            # Enhanced with session management logging
│   ├── tests/                        # NEW: Comprehensive testing
│   │   ├── __init__.py
│   │   ├── conftest.py              # Test configuration and fixtures
│   │   ├── test_session_manager.py   # SessionManager unit tests
│   │   ├── test_session_persistence.py  # Session persistence integration tests
│   │   └── test_conversation_continuity.py  # End-to-end conversation tests
│   └── scripts/
│       ├── verify_sessions.py        # Enhanced session debugging and validation
│       └── cleanup_sessions.py       # NEW: Session cleanup utilities
```

### Known Gotchas of our codebase & Library Quirks

```python
# CRITICAL: Claude Code SDK ClaudeSDKClient vs query() usage patterns
from claude_code_sdk import query, ClaudeSDKClient
from claude_code_sdk.types import ClaudeCodeOptions

# WRONG: Mixing standalone query() and ClaudeSDKClient causes session inconsistencies
response = query(prompt="Create session", options=ClaudeCodeOptions())  # Creates session
async with ClaudeSDKClient(options=ClaudeCodeOptions(resume=session_id)) as client:  # Different context

# CORRECT: Use ClaudeSDKClient for entire session lifecycle
async with ClaudeSDKClient(options=ClaudeCodeOptions()) as client:
    await client.query("Initial message")  # Session created here
    session_id = client.session_id  # Get session ID from client
    # Continue using same client for conversation

# CRITICAL: Session persistence and working directory dependency
# Sessions must use consistent working directory for proper resumption
options = ClaudeCodeOptions(
    cwd="/consistent/working/directory",  # MUST be same for session resumption
    resume=session_id  # Only works with consistent working directory
)

# GOTCHA: Session ID extraction from ClaudeSDKClient
# Current extraction logic from query() response may not work with ClaudeSDKClient
# ClaudeSDKClient has session_id property: client.session_id

# GOTCHA: ClaudeSDKClient lifecycle management
# ClaudeSDKClient instances must be properly managed for resource cleanup
class SessionManager:
    def __init__(self):
        self.active_clients: Dict[str, ClaudeSDKClient] = {}

    async def cleanup_session(self, session_id: str):
        if session_id in self.active_clients:
            client = self.active_clients[session_id]
            await client.disconnect()  # Proper cleanup
            del self.active_clients[session_id]

# GOTCHA: FastAPI singleton with multiple workers
# Global variables don't persist across FastAPI workers
# Use app.state or proper dependency injection with @lru_cache

# CRITICAL: Session file storage location dependency
# Claude SDK stores sessions in ~/.claude/projects/{working_dir_hash}/
# Working directory MUST be consistent for session resumption to work
import os
os.chdir("/consistent/project/root")  # Set before ANY Claude SDK operations

# GOTCHA: Session cleanup and memory management
# Long-lived ClaudeSDKClient instances can accumulate memory
# Implement proper cleanup with configurable timeouts
session_timeout = 3600  # 1 hour inactivity timeout
cleanup_interval = 300   # Check every 5 minutes

# CRITICAL: Session history access limitations
# Claude SDK doesn't provide programmatic access to conversation history
# Must parse .jsonl files manually or use internal _message_parser.py
# Consider implementing session history caching for mobile UI
```

## Implementation Blueprint

### Data models and structure

Enhance existing data models to support persistent session management and conversation history access.

```python
# Enhanced request models in backend/app/models/requests.py
from pydantic import BaseModel, Field
from typing import Optional, Dict, Any

class SessionRequest(BaseModel):
    user_id: str
    session_name: Optional[str] = None
    working_directory: Optional[str] = Field(None, description="Working directory for Claude SDK session storage")
    persist_client: bool = Field(True, description="Keep ClaudeSDKClient persistent for conversation continuity")

class ClaudeQueryRequest(BaseModel):
    session_id: str
    query: str
    user_id: str
    stream: bool = Field(True, description="Enable streaming response")
    include_history: bool = Field(False, description="Include conversation history in response")

# Enhanced response models for session history
class ConversationMessage(BaseModel):
    role: str  # "user" | "assistant"
    content: str
    timestamp: datetime
    message_id: Optional[str] = None

class SessionResponse(BaseModel):
    session_id: str
    user_id: str
    session_name: str
    working_directory: str
    status: str = "active"
    created_at: datetime
    last_active_at: datetime
    message_count: int
    conversation_history: Optional[List[ConversationMessage]] = Field(None, description="Available when include_history=True")

class SessionManagerStats(BaseModel):
    active_sessions: int
    total_sessions_created: int
    memory_usage_mb: float
    cleanup_last_run: datetime
    session_timeout_seconds: int
```

### Implementation Tasks (ordered by dependencies)

```yaml
Task 1: CREATE backend/app/services/session_manager.py
  - IMPLEMENT: SessionManager class with persistent ClaudeSDKClient management
  - PATTERN: Singleton with session pools, automatic cleanup, graceful shutdown
  - FEATURES: get_or_create_session(), cleanup_session(), periodic cleanup loop
  - DEPENDENCIES: ClaudeSDKClient lifecycle, asyncio task management
  - CRITICAL: Proper async context management and resource cleanup
  - NAMING: SessionManager class with descriptive async methods

Task 2: ENHANCE backend/app/core/lifecycle.py
  - IMPLEMENT: SessionManager initialization in FastAPI lifespan events
  - INTEGRATE: Working directory setup with SessionManager startup
  - ADD: Graceful SessionManager shutdown with proper client cleanup
  - FOLLOW pattern: Existing working directory and session storage setup
  - CRITICAL: Initialize SessionManager after working directory setup
  - PRESERVE: Existing project root and session storage configuration

Task 3: ENHANCE backend/app/services/claude_service.py
  - REFACTOR: Replace mixed query()/ClaudeSDKClient usage with SessionManager integration
  - IMPLEMENT: Session creation using persistent ClaudeSDKClient instances
  - PRESERVE: Existing SSE streaming implementation and mobile optimization
  - FOLLOW pattern: Current PersistentSessionStorage integration
  - CRITICAL: Use SessionManager for all Claude SDK operations
  - ENHANCE: Add conversation history access for mobile UI

Task 4: UPDATE backend/app/api/claude.py
  - INTEGRATE: SessionManager dependency injection in all endpoints
  - ENHANCE: Session endpoints with conversation history support
  - PRESERVE: Existing SSE streaming configuration and CORS setup
  - ADD: Session management status endpoints for debugging
  - FOLLOW pattern: Current dependency injection with get_claude_service()
  - CRITICAL: Maintain mobile streaming optimization (0.01s delays)

Task 5: CREATE backend/app/utils/session_utils.py
  - IMPLEMENT: Session validation, recovery, and debugging utilities
  - FUNCTIONS: validate_session_client(), recover_session(), get_session_stats()
  - INTEGRATE: SessionManager monitoring and health checking
  - USAGE: Debugging support for session management issues
  - PATTERN: Utility functions with comprehensive error handling

Task 6: CREATE comprehensive testing suite
  - FILES: test_session_manager.py, test_session_persistence.py, test_conversation_continuity.py
  - TESTS: Session creation/cleanup, multi-session isolation, conversation continuity
  - INTEGRATION: End-to-end session resumption across backend restarts
  - PERFORMANCE: Memory usage, cleanup effectiveness, concurrent session handling
  - VALIDATION: Session management reliability under various failure scenarios

Task 7: ENHANCE backend/scripts/verify_sessions.py
  - ADD: SessionManager status monitoring and diagnostic capabilities
  - IMPLEMENT: Active session inspection, client status validation
  - FUNCTIONS: Session health checking, cleanup simulation, performance metrics
  - USAGE: Production debugging and monitoring tool for session management
  - OUTPUT: Detailed session management status and recommendations
```

### Implementation Patterns & Key Details

```python
# SessionManager architecture with persistent ClaudeSDKClient instances
import asyncio
import time
from typing import Dict, Optional
from claude_code_sdk import ClaudeSDKClient
from claude_code_sdk.types import ClaudeCodeOptions

class SessionManager:
    """Manages persistent ClaudeSDKClient instances for conversation continuity."""

    def __init__(self):
        self.active_sessions: Dict[str, Dict] = {}
        # Structure: {
        #   "session_id": {
        #       "client": ClaudeSDKClient,
        #       "working_dir": str,
        #       "last_used": float,
        #       "created_at": float,
        #       "user_id": str
        #   }
        # }
        self.cleanup_task = None
        self.session_timeout = 3600  # 1 hour configurable timeout

    async def get_or_create_session(self, session_id: str, working_dir: str,
                                   user_id: str, is_new_session: bool = False) -> ClaudeSDKClient:
        """Get existing persistent session client or create new one."""

        # Check if session exists and client is still valid
        if session_id in self.active_sessions:
            session_info = self.active_sessions[session_id]
            client = session_info["client"]

            # Validate client is still connected
            if await self._validate_client(client):
                session_info["last_used"] = time.time()
                return client
            else:
                # Client disconnected, clean up and recreate
                await self.cleanup_session(session_id)

        # Create new persistent client
        options = ClaudeCodeOptions(
            cwd=working_dir,
            permission_mode="bypassPermissions",
            resume=None if is_new_session else session_id
        )

        client = ClaudeSDKClient(options)
        await client.connect()

        # For new sessions, get session ID from client
        if is_new_session:
            # Wait for session initialization
            await asyncio.sleep(0.1)
            session_id = client.session_id or session_id

        # Store session info
        self.active_sessions[session_id] = {
            "client": client,
            "working_dir": working_dir,
            "user_id": user_id,
            "last_used": time.time(),
            "created_at": time.time()
        }

        # Start cleanup task if not running
        if self.cleanup_task is None:
            self.cleanup_task = asyncio.create_task(self._cleanup_loop())

        return client

    async def _validate_client(self, client: ClaudeSDKClient) -> bool:
        """Validate that ClaudeSDKClient is still connected and functional."""
        try:
            # Simple validation - check if client is connected
            return hasattr(client, '_session') and client._session is not None
        except Exception:
            return False

    async def cleanup_session(self, session_id: str):
        """Manually cleanup a specific session with proper client disconnect."""
        if session_id in self.active_sessions:
            session_info = self.active_sessions[session_id]
            client = session_info["client"]

            try:
                await client.disconnect()
            except Exception as e:
                # Log but don't fail cleanup
                pass

            del self.active_sessions[session_id]

    async def _cleanup_loop(self):
        """Periodically cleanup inactive sessions."""
        while True:
            try:
                await asyncio.sleep(300)  # Check every 5 minutes
                current_time = time.time()
                sessions_to_remove = []

                for session_id, session_info in self.active_sessions.items():
                    if current_time - session_info["last_used"] > self.session_timeout:
                        sessions_to_remove.append(session_id)

                for session_id in sessions_to_remove:
                    await self.cleanup_session(session_id)

            except Exception as e:
                # Log cleanup errors but continue loop
                pass

    async def shutdown(self):
        """Cleanup all sessions on application shutdown."""
        if self.cleanup_task:
            self.cleanup_task.cancel()

        # Cleanup all active sessions
        for session_id in list(self.active_sessions.keys()):
            await self.cleanup_session(session_id)

# Enhanced ClaudeService integration with SessionManager
class ClaudeService:
    def __init__(self, project_root: Path, session_storage: PersistentSessionStorage,
                 session_manager: SessionManager):
        self.project_root = project_root
        self.session_storage = session_storage
        self.session_manager = session_manager

    async def create_session(self, request: SessionRequest) -> SessionResponse:
        """Create new session using persistent ClaudeSDKClient."""
        working_dir = request.working_directory or str(self.project_root)
        session_id = str(uuid.uuid4())

        # Create persistent client through SessionManager
        client = await self.session_manager.get_or_create_session(
            session_id=session_id,
            working_dir=working_dir,
            user_id=request.user_id,
            is_new_session=True
        )

        # Get actual session ID from client (may be different)
        actual_session_id = client.session_id or session_id

        # Store metadata for UI
        self.session_storage.store_session(
            session_id=actual_session_id,
            user_id=request.user_id,
            working_directory=working_dir,
            session_name=request.session_name or f"Session {actual_session_id[:8]}",
            created_at=datetime.utcnow()
        )

        return SessionResponse(
            session_id=actual_session_id,
            user_id=request.user_id,
            session_name=request.session_name or f"Session {actual_session_id[:8]}",
            working_directory=working_dir,
            status="active",
            created_at=datetime.utcnow(),
            last_active_at=datetime.utcnow(),
            message_count=0
        )

    async def stream_response(self, request: ClaudeQueryRequest,
                            options: RequestOptions) -> AsyncGenerator[StreamingChunk, None]:
        """Stream response using persistent ClaudeSDKClient."""

        # Get session metadata
        session_metadata = self.session_storage.get_session(request.session_id)
        if not session_metadata:
            raise ValueError(f"Session {request.session_id} not found")

        working_dir = session_metadata["working_directory"]

        # Get persistent client from SessionManager
        client = await self.session_manager.get_or_create_session(
            session_id=request.session_id,
            working_dir=working_dir,
            user_id=request.user_id,
            is_new_session=False
        )

        # Send query to persistent client
        await client.query(request.query)

        # Stream response with mobile optimization
        async for message in client.receive_response():
            if hasattr(message, "content"):
                for block in message.content:
                    if hasattr(block, "text"):
                        yield StreamingChunk(
                            chunk_type=ChunkType.DELTA,
                            content=block.text,
                            message_id=str(uuid.uuid4()),
                            session_id=request.session_id,
                        )
                        await asyncio.sleep(0.01)  # Mobile optimization

# FastAPI dependency injection with SessionManager
from functools import lru_cache

@lru_cache()
def get_session_manager() -> SessionManager:
    """Singleton SessionManager instance."""
    return SessionManager()

def get_claude_service(request: Request) -> ClaudeService:
    """Dependency to provide enhanced Claude service with SessionManager."""
    project_root = request.app.state.project_root
    session_storage = request.app.state.session_storage
    session_manager = request.app.state.session_manager
    return ClaudeService(project_root, session_storage, session_manager)
```

### Integration Points

```yaml
SESSIONMANAGER_INTEGRATION:
  - initialization: "FastAPI lifespan events with working directory setup"
  - dependency_injection: "App state storage for singleton access across requests"
  - cleanup: "Graceful shutdown with proper ClaudeSDKClient disconnect"
  - monitoring: "Session manager statistics and health checking endpoints"

PERSISTENT_CLIENT_MANAGEMENT:
  - session_creation: "ClaudeSDKClient instances maintained for conversation continuity"
  - session_resumption: "resume parameter with persistent working directory context"
  - cleanup_strategy: "Configurable timeout with automatic inactive session removal"
  - resource_management: "Memory monitoring and client connection validation"

CONVERSATION_CONTINUITY:
  - context_preservation: "ClaudeSDKClient maintains conversation context across queries"
  - session_persistence: "Session metadata storage for resumption across backend restarts"
  - history_access: "Conversation history parsing for mobile UI display"
  - multi_session_isolation: "Independent ClaudeSDKClient instances prevent context bleeding"

MOBILE_OPTIMIZATION:
  - streaming_preservation: "Maintain existing SSE streaming with 0.01s mobile delays"
  - session_switching: "Fast session access through persistent client pools"
  - error_handling: "Clear session management error messages for mobile debugging"
  - performance_monitoring: "Session manager metrics for mobile performance optimization"
```

## Validation Loop

### Level 1: Syntax & Style (Immediate Feedback)

```bash
# Backend validation with SessionManager implementation
cd backend

# Activate virtual environment (create if doesn't exist)
if [ ! -d "venv" ]; then
    python3 -m venv venv
fi
source venv/bin/activate || echo "Please create virtual environment first"

# Install development dependencies
pip install ruff mypy pytest pytest-asyncio httpx

# Check linting and formatting
python3 -m ruff check app/ --fix
python3 -m mypy app/
python3 -m ruff format app/

# Expected: Zero errors. Fix any issues before proceeding.
```

### Level 2: Unit Tests (Component Validation)

```bash
# Test SessionManager and persistent client management
cd backend

# Test SessionManager functionality
python3 -m pytest tests/test_session_manager.py -v

# Test session persistence across restarts
python3 -m pytest tests/test_session_persistence.py -v

# Test conversation continuity
python3 -m pytest tests/test_conversation_continuity.py -v

# Test enhanced Claude service integration
python3 -m pytest tests/test_claude_service.py -v

# Full test suite with coverage
python3 -m pytest tests/ -v --cov=app --cov-report=term-missing

# Expected: All tests pass with >90% coverage on session management code
```

### Level 3: Integration Testing (System Validation)

```bash
# Backend startup and SessionManager integration validation
cd backend
docker-compose up -d
sleep 5

# Health check with SessionManager status
curl -f http://localhost:8000/health || echo "Backend health check failed"

# Session creation with persistent client
SESSION_ID=$(curl -s -X POST http://localhost:8000/claude/sessions \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test-user", "session_name": "Persistence Test"}' | jq -r .session_id)

echo "Created session: $SESSION_ID"

# Test conversation with context
curl -X POST http://localhost:8000/claude/stream \
  -H "Content-Type: application/json" \
  -d "{\"session_id\": \"$SESSION_ID\", \"query\": \"Remember: my favorite programming language is Python\", \"user_id\": \"test-user\"}"

# Test conversation continuity
curl -X POST http://localhost:8000/claude/stream \
  -H "Content-Type: application/json" \
  -d "{\"session_id\": \"$SESSION_ID\", \"query\": \"What is my favorite programming language?\", \"user_id\": \"test-user\"}"

# Restart backend to test session persistence
docker-compose restart claude-backend
sleep 5

# Test session resumption after restart
curl -X POST http://localhost:8000/claude/stream \
  -H "Content-Type: application/json" \
  -d "{\"session_id\": \"$SESSION_ID\", \"query\": \"What programming language did I mention earlier?\", \"user_id\": \"test-user\"}"

# Expected: Streaming response mentions "Python", demonstrating session persistence and context continuity
```

### Level 4: Creative & Domain-Specific Validation

```bash
# SessionManager and conversation continuity validation
cd backend

# Run session management diagnostics
python3 scripts/verify_sessions.py --detailed

# Multi-session isolation testing
# Create 5 concurrent sessions with different contexts
for i in {1..5}; do
  SESSION_ID=$(curl -s -X POST http://localhost:8000/claude/sessions \
    -H "Content-Type: application/json" \
    -d "{\"user_id\": \"user$i\", \"session_name\": \"Test Session $i\"}" | jq -r .session_id)

  echo "Created session $i: $SESSION_ID"

  # Give each session unique context
  curl -s -X POST http://localhost:8000/claude/stream \
    -H "Content-Type: application/json" \
    -d "{\"session_id\": \"$SESSION_ID\", \"query\": \"My lucky number is $i\", \"user_id\": \"user$i\"}" > /dev/null
done

# Verify session isolation - each should only remember its own number
echo "Testing session isolation..."

# Performance testing with SessionManager
# Test concurrent session access
echo '{"session_id": "'$SESSION_ID'", "query": "Quick test", "user_id": "perf-test"}' > /tmp/session_query.json
ab -n 100 -c 10 -T application/json -p /tmp/session_query.json http://localhost:8000/claude/stream

# Memory usage monitoring during extended session use
# Run long conversation in multiple sessions to test cleanup
python3 -c "
import asyncio
import aiohttp
import json

async def test_session_lifecycle():
    # Test session creation, conversation, and cleanup
    async with aiohttp.ClientSession() as session:
        # Create session
        async with session.post(
            'http://localhost:8000/claude/sessions',
            json={'user_id': 'lifecycle-test', 'session_name': 'Lifecycle Test'}
        ) as resp:
            session_data = await resp.json()
            session_id = session_data['session_id']

        # Extended conversation
        for i in range(10):
            async with session.post(
                'http://localhost:8000/claude/stream',
                json={
                    'session_id': session_id,
                    'query': f'This is message {i+1} in our conversation',
                    'user_id': 'lifecycle-test'
                }
            ) as resp:
                async for line in resp.content:
                    pass  # Consume stream

asyncio.run(test_session_lifecycle())
"

# Cleanup test files
rm -f /tmp/session_query.json

# Expected: All validations pass, sessions maintain isolation, memory usage stable
```

## Final Validation Checklist

### Technical Validation

- [ ] All 4 validation levels completed successfully
- [ ] SessionManager unit tests pass with >95% coverage
- [ ] Session persistence tests pass across backend restarts
- [ ] Conversation continuity tests demonstrate context preservation
- [ ] Multi-session isolation tests pass without context bleeding
- [ ] All tests pass: `cd backend && python3 -m pytest tests/ -v`
- [ ] No linting errors: `cd backend && python3 -m ruff check app/`
- [ ] No type errors: `cd backend && python3 -m mypy app/`
- [ ] SessionManager performance tests meet <200ms response times
- [ ] Session cleanup functionality prevents memory leaks

### Feature Validation

- [ ] iOS app session switching maintains full conversation history and context
- [ ] Sessions persist correctly across FastAPI backend restarts and Docker deployments
- [ ] Session resumption works reliably with ClaudeSDKClient resume functionality
- [ ] Multiple concurrent sessions (10+) work without interference or performance degradation
- [ ] Session lifecycle management prevents resource exhaustion and memory leaks
- [ ] Conversation history is accessible for mobile UI display (when implemented)
- [ ] Streaming responses maintain <100ms first chunk latency with session persistence
- [ ] Session cleanup occurs automatically for inactive sessions with configurable timeout
- [ ] Error handling provides clear debugging information for session management issues

### Code Quality Validation

- [ ] SessionManager follows singleton pattern with proper dependency injection
- [ ] ClaudeSDKClient instances properly managed with lifecycle cleanup
- [ ] Session metadata persistence integrated with SessionManager lifecycle
- [ ] File placement matches desired codebase tree structure
- [ ] All anti-patterns from previous implementations eliminated
- [ ] SSE streaming implementation preserves mobile optimization features
- [ ] Working directory consistency maintained for session storage

### Session Management Validation

- [ ] ClaudeSDKClient instances persist for conversation continuity
- [ ] Session creation uses persistent clients instead of standalone query()
- [ ] Session resumption works through SessionManager with proper client management
- [ ] Session cleanup prevents resource leaks with configurable timeouts
- [ ] Session registry integrates with SessionManager for complete lifecycle management
- [ ] Conversation context preserved across all session operations
- [ ] Session validation and debugging tools provide comprehensive monitoring

---

## Anti-Patterns to Avoid

### SessionManager & ClaudeSDKClient Anti-Patterns
- ❌ Don't mix standalone query() and ClaudeSDKClient for same session - use ClaudeSDKClient throughout
- ❌ Don't create new ClaudeSDKClient instances for existing sessions - use SessionManager persistence
- ❌ Don't skip proper ClaudeSDKClient disconnect during cleanup - causes resource leaks
- ❌ Don't ignore ClaudeSDKClient connection validation - detect and handle disconnected clients
- ❌ Don't use global variables for SessionManager - use FastAPI app state and dependency injection
- ❌ Don't skip SessionManager initialization in lifespan events - required for startup/shutdown

### Session Persistence Anti-Patterns
- ❌ Don't ignore working directory consistency - Claude SDK session resumption depends on it
- ❌ Don't skip session metadata persistence - required for resumption across backend restarts
- ❌ Don't assume ClaudeSDKClient.session_id is immediately available - wait for session initialization
- ❌ Don't skip session cleanup implementation - causes memory leaks and resource exhaustion
- ❌ Don't hardcode session timeouts - make them configurable for different deployment scenarios

### API Integration Anti-Patterns
- ❌ Don't break existing SSE streaming patterns - preserve mobile optimization delays
- ❌ Don't skip SessionManager dependency injection in API endpoints - breaks session management
- ❌ Don't ignore session validation in streaming endpoints - causes poor error handling
- ❌ Don't remove CORS configuration for mobile clients - breaks iOS app integration
- ❌ Don't skip error handling for SessionManager operations - causes poor debugging experience

### Conversation Continuity Anti-Patterns
- ❌ Don't create new sessions when resuming existing ones - breaks conversation context
- ❌ Don't skip conversation history considerations for mobile UI - limits user experience
- ❌ Don't ignore session isolation between users - causes security and privacy issues
- ❌ Don't assume session files are immediately available - implement proper validation
- ❌ Don't skip multi-session testing - concurrent sessions must work independently

### Performance & Resource Management Anti-Patterns
- ❌ Don't skip periodic session cleanup - causes memory leaks over time
- ❌ Don't ignore SessionManager performance monitoring - required for production deployment
- ❌ Don't create unlimited concurrent sessions - implement reasonable limits and cleanup
- ❌ Don't skip client connection validation - handle disconnected clients gracefully
- ❌ Don't ignore graceful shutdown procedures - properly cleanup all sessions on application exit