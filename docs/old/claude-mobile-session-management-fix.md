name: "Claude Code Mobile - Session Management Architecture Fix with Working Directory Specification"
description: |

---

## Goal

**Feature Goal**: Fix Claude Code Mobile session management to ensure conversation history persists correctly when switching between sessions in the iOS app through working directory specification and elimination of unnecessary session mapping layers.

**Deliverable**: Updated FastAPI backend with direct Claude Code SDK session management, consistent working directory handling, and reliable session persistence that maintains conversation context across session switches.

**Success Definition**: iOS app users can switch between multiple Claude Code conversation sessions without losing conversation history. Sessions resume with full context preservation, and session management works reliably across FastAPI worker restarts and Docker deployments.

## User Persona

**Target User**: Claude Code CLI Power Users extending workflows to mobile devices

**Use Case**: Multi-session mobile development workflow - creating separate Claude Code conversations for different technical topics (e.g., one session for architecture discussion, another for debugging, another for code review), switching between them seamlessly while maintaining full conversation context.

**User Journey**:
1. Create multiple Claude Code conversation sessions in iOS app
2. Have technical conversations in each session with Claude about different topics
3. Switch between sessions to continue different discussions
4. Expect each session to remember previous conversation context
5. Resume conversations across app restarts and device switches

**Pain Points Addressed**:
- Session history loss when switching between conversations
- Claude responding "This is the first message" when it should remember context
- Unreliable session persistence across app/backend restarts
- Inconsistent working directory causing session storage fragmentation

## Why

- **Critical Mobile UX Issue**: Session history loss breaks the core value proposition of mobile Claude Code access
- **SDK Integration Problem**: Current implementation fights against Claude Code SDK's native session management instead of leveraging it
- **Working Directory Dependency**: Claude SDK's file-based session storage requires consistent working directory for proper persistence
- **Production Reliability**: Current in-memory session mapping prevents reliable multi-user deployment and FastAPI scaling
- **Technical Debt Elimination**: Remove unnecessary abstraction layers that introduce failure points without adding value

## What

Fix session management architecture by:

1. **Direct Claude SDK Session Usage**: Eliminate unnecessary session mapping layer, use Claude Code SDK session IDs directly
2. **Working Directory Standardization**: Ensure consistent working directory specification for reliable session storage
3. **Native Session Persistence**: Leverage Claude SDK's file-based session storage instead of recreating persistence mechanisms
4. **FastAPI Integration Hardening**: Proper lifespan management and singleton patterns for reliable session service
5. **Session Creation with Working Directory Specification**: Enable working directory specification during session creation for organized session storage

### Success Criteria

- [ ] iOS app session switching maintains conversation history without context loss
- [ ] Sessions persist correctly across FastAPI backend restarts
- [ ] Working directory is consistent and specifiable during session creation
- [ ] Session resumption works reliably with <200ms response times
- [ ] Multiple concurrent sessions (10+) work without interference
- [ ] Docker deployment maintains session persistence across container restarts
- [ ] Session storage location is predictable and debuggable
- [ ] Backend API tests demonstrate reliable session continuity

## All Needed Context

### Context Completeness Check

_Validated: This PRP provides complete implementation guidance for fixing Claude Code SDK session management issues through extensive research of SDK architecture, current implementation analysis, and FastAPI integration patterns._

### Documentation & References

```yaml
# MUST READ - Claude Code SDK Session Management
- docfile: PRPs/ai_docs/claude_sdk_session_management.md
  why: Comprehensive patterns for FastAPI + Claude Code SDK integration with working directory management
  section: Direct SDK Session Usage, Working Directory Management, Integration Patterns
  critical: Working directory consistency is required for session persistence

- url: https://docs.anthropic.com/en/docs/claude-code/sdk/sdk-sessions
  why: Official Claude Code SDK session management documentation
  pattern: Session storage in ~/.claude/projects/{project-hash}/ with working directory dependency
  critical: Project hash generated from absolute path of working directory

- url: https://docs.anthropic.com/en/docs/claude-code/sdk/sdk-python
  why: Python SDK reference for ClaudeCodeOptions and session resumption
  pattern: ClaudeCodeOptions(resume=session_id, cwd=working_directory)
  critical: cwd parameter required for consistent session storage location

# MUST READ - Current Implementation Analysis
- file: backend/app/services/claude_service.py
  why: Current session mapping implementation with identified issues
  pattern: SessionManager class with in-memory _claude_session_ids mapping
  gotcha: In-memory storage lost on FastAPI restart, unnecessary abstraction layer

- file: backend/app/api/claude.py
  why: FastAPI router implementation and singleton pattern
  pattern: Global _claude_service_instance with get_claude_service() function
  gotcha: Singleton may not work correctly across FastAPI workers

- file: SESSION_MANAGEMENT_ANALYSIS.md
  why: Detailed analysis of current session management issues and root causes
  section: Root Cause Analysis, SDK-Aligned Architecture recommendations
  critical: Session ID mapping persistence and working directory inconsistency identified

# MUST READ - FastAPI Integration Patterns
- url: https://fastapi.tiangolo.com/advanced/events/
  why: FastAPI lifespan events for working directory and service initialization
  pattern: @asynccontextmanager async def lifespan(app: FastAPI)
  critical: Set working directory before any Claude SDK operations

- url: https://fastapi.tiangolo.com/advanced/dependencies/dependencies-with-yield/
  why: Dependency injection patterns for service management
  pattern: Proper singleton pattern with yield dependencies
  gotcha: Global variables don't work reliably with multiple workers
```

### Current Codebase tree

```bash
Claude_Code-Mobile/
├── backend/
│   ├── app/
│   │   ├── main.py                   # FastAPI application entry point
│   │   ├── api/
│   │   │   └── claude.py             # Claude API endpoints with session management
│   │   ├── services/
│   │   │   └── claude_service.py     # Current session mapping implementation (NEEDS FIX)
│   │   ├── models/
│   │   │   ├── requests.py           # Pydantic request models
│   │   │   └── responses.py          # Pydantic response models
│   │   └── core/
│   │       └── config.py             # Configuration management
│   ├── requirements.txt              # Claude Code SDK dependencies
│   ├── Dockerfile                    # Container configuration
│   └── docker-compose.yml            # Docker deployment
├── ios-app/VisionForge/              # SwiftUI iOS client
├── docs/
│   └── SETUP.md                      # Deployment documentation
├── SESSION_MANAGEMENT_ANALYSIS.md   # Detailed issue analysis
└── PRPs/
    ├── ai_docs/
    │   └── claude_sdk_session_management.md  # Implementation patterns
    └── swiftui-claude-code-client.md  # Original PRP (BEING UPDATED)
```

### Desired Codebase tree with files to be added and responsibility of file

```bash
Claude_Code-Mobile/
├── backend/
│   ├── app/
│   │   ├── main.py                   # Updated with lifespan working directory management
│   │   ├── api/
│   │   │   └── claude.py             # Updated with direct SDK session usage
│   │   ├── services/
│   │   │   ├── claude_service.py     # Refactored for direct SDK usage
│   │   │   └── session_storage.py    # Optional: Session metadata storage (NEW)
│   │   ├── models/
│   │   │   ├── requests.py           # Updated with working directory specification
│   │   │   └── responses.py          # Updated response models
│   │   ├── core/
│   │   │   ├── config.py             # Updated with session storage configuration
│   │   │   └── lifecycle.py          # Working directory and service management (NEW)
│   │   └── utils/
│   │       └── session_utils.py      # Session validation and recovery utilities (NEW)
│   ├── tests/
│   │   ├── test_session_management.py    # Session continuity tests (NEW)
│   │   └── test_working_directory.py     # Working directory validation tests (NEW)
│   └── scripts/
│       └── verify_sessions.py        # Session storage debugging script (NEW)
```

### Known Gotchas of our codebase & Library Quirks

```python
# CRITICAL: Claude Code SDK working directory dependency
# Sessions stored in ~/.claude/projects/{project-hash}/ where project-hash = absolute working directory path
import os
os.chdir("/consistent/path")  # MUST be set before any Claude SDK operations

# CRITICAL: Claude SDK requires async context management
from claude_code_sdk import query
from claude_code_sdk.types import ClaudeCodeOptions

# CORRECT: Direct session usage with explicit working directory
response = query(
    prompt="Hello",
    options=ClaudeCodeOptions(
        cwd="/Users/beardedwonder/Development/DBGVentures/Claude_Code-Mobile",  # Explicit
        resume=session_id,  # Direct Claude SDK session ID
        permission_mode="bypassPermissions"
    )
)

# GOTCHA: Session ID extraction from Claude SDK response
# Extract from SystemMessage with 'init' subtype during first response
async for message in response:
    if hasattr(message, 'subtype') and message.subtype == 'init':
        session_id = message.data.get('session_id')

# GOTCHA: FastAPI singleton pattern with multiple workers
# Global variables don't work reliably - use dependency injection
from functools import lru_cache

@lru_cache()
def get_claude_service():
    return ClaudeService(project_root=PROJECT_ROOT)

# GOTCHA: claude-code-sdk-shmaxi package required for FastAPI subprocess handling
# pip install claude-code-sdk-shmaxi  # NOT claude-code-sdk

# CRITICAL: Working directory must be set in FastAPI lifespan events
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Set working directory BEFORE any Claude operations
    PROJECT_ROOT = Path(__file__).parent.parent.absolute()
    os.chdir(PROJECT_ROOT)
    yield
```

## Implementation Blueprint

### Data models and structure

Update request models to support working directory specification and eliminate session mapping.

```python
# Updated request models in backend/app/models/requests.py
from pydantic import BaseModel, Field
from pathlib import Path
from typing import Optional

class SessionRequest(BaseModel):
    user_id: str
    session_name: Optional[str] = None
    working_directory: Optional[str] = Field(None, description="Working directory for Claude SDK session storage")

class ClaudeQueryRequest(BaseModel):
    session_id: str  # Direct Claude SDK session ID (no mapping)
    query: str
    user_id: str

class SessionResponse(BaseModel):
    session_id: str  # Claude SDK session ID directly
    user_id: str
    session_name: str
    working_directory: str
    created_at: datetime
    status: str = "active"
```

### Implementation Tasks (ordered by dependencies)

```yaml
Task 1: UPDATE backend/app/core/lifecycle.py
  - IMPLEMENT: Working directory management and Claude service lifecycle
  - CREATE: @asynccontextmanager lifespan function for FastAPI
  - FOLLOW pattern: PRPs/ai_docs/claude_sdk_session_management.md (Working Directory Management)
  - NAMING: lifespan(), initialize_claude_environment(), verify_session_storage()
  - PLACEMENT: New core module for application lifecycle management

Task 2: REFACTOR backend/app/services/claude_service.py
  - REMOVE: SessionManager class and _claude_session_ids mapping
  - IMPLEMENT: Direct Claude SDK session usage with working directory specification
  - FOLLOW pattern: PRPs/ai_docs/claude_sdk_session_management.md (Direct SDK Usage)
  - NAMING: ClaudeService with create_session(), resume_session(), extract_session_id()
  - DEPENDENCIES: Updated models from requests.py
  - CRITICAL: Use ClaudeCodeOptions(cwd=working_directory, resume=session_id)

Task 3: UPDATE backend/app/models/requests.py
  - ADD: working_directory field to SessionRequest
  - REMOVE: Any session mapping related fields
  - FOLLOW pattern: existing Pydantic models with Field descriptions
  - NAMING: working_directory with Optional[str] type
  - VALIDATION: Path validation for working_directory field

Task 4: UPDATE backend/app/api/claude.py
  - REMOVE: Global singleton _claude_service_instance
  - IMPLEMENT: Proper dependency injection with get_claude_service()
  - FOLLOW pattern: FastAPI dependency injection with @lru_cache
  - MODIFY: All endpoints to use direct Claude SDK session IDs
  - DEPENDENCIES: Updated ClaudeService from Task 2

Task 5: UPDATE backend/app/main.py
  - INTEGRATE: Lifespan management from Task 1
  - MODIFY: FastAPI application initialization
  - FOLLOW pattern: FastAPI lifespan events documentation
  - ADD: Working directory verification and session storage debugging
  - DEPENDENCIES: lifecycle.py from Task 1

Task 6: CREATE backend/app/utils/session_utils.py
  - IMPLEMENT: Session validation, recovery, and debugging utilities
  - FUNCTIONS: verify_session_exists(), list_user_sessions(), recover_session()
  - FOLLOW pattern: Utility module pattern with standalone functions
  - NAMING: Descriptive function names with session_ prefix
  - USAGE: Debugging and validation support for session management

Task 7: CREATE backend/tests/test_session_management.py
  - IMPLEMENT: Comprehensive session continuity tests
  - TESTS: Session creation, resumption, working directory consistency
  - FOLLOW pattern: pytest async test patterns
  - COVERAGE: Happy path, error cases, working directory scenarios
  - VALIDATION: End-to-end session persistence verification

Task 8: CREATE backend/scripts/verify_sessions.py
  - IMPLEMENT: Session storage debugging and verification script
  - FUNCTIONALITY: List sessions, verify storage locations, test session resumption
  - USAGE: Debugging tool for production session issues
  - OUTPUT: Clear session storage status and recommendations
```

### Implementation Patterns & Key Details

```python
# Working directory management pattern
from contextlib import asynccontextmanager
import os
from pathlib import Path

@asynccontextmanager
async def lifespan(app: FastAPI):
    # CRITICAL: Set working directory before any Claude SDK operations
    project_root = Path(__file__).parent.parent.absolute()
    os.chdir(project_root)

    # Verify Claude session storage location
    claude_sessions_path = Path.home() / ".claude" / "projects" / f"-{str(project_root).replace('/', '-')}"
    app.state.project_root = project_root
    app.state.claude_sessions_path = claude_sessions_path

    print(f"✅ Claude sessions stored at: {claude_sessions_path}")
    yield

# Direct Claude SDK session usage pattern
class ClaudeService:
    def __init__(self, project_root: Path):
        self.project_root = project_root

    async def create_session(self, request: SessionRequest) -> SessionResponse:
        # Use specified working directory or default to project root
        working_dir = request.working_directory or str(self.project_root)

        # Initialize Claude SDK session with explicit working directory
        response = query(
            prompt="Session initialized",
            options=ClaudeCodeOptions(
                cwd=working_dir,
                permission_mode="bypassPermissions"
            )
        )

        # Extract Claude SDK session ID directly
        session_id = await self._extract_session_id(response)

        return SessionResponse(
            session_id=session_id,  # Direct Claude SDK session ID
            user_id=request.user_id,
            session_name=request.session_name or f"Session {session_id[:8]}",
            working_directory=working_dir,
            created_at=datetime.utcnow()
        )

    async def resume_session(self, session_id: str, query_text: str, working_directory: str):
        # Direct session resumption with consistent working directory
        response = query(
            prompt=query_text,
            options=ClaudeCodeOptions(
                cwd=working_directory,
                resume=session_id,
                permission_mode="bypassPermissions"
            )
        )
        return response

# Session ID extraction pattern
async def _extract_session_id(self, response) -> str:
    """Extract Claude SDK session ID from response stream."""
    session_id = None

    async for message in response:
        if hasattr(message, 'subtype') and message.subtype == 'init':
            if hasattr(message, 'data') and 'session_id' in message.data:
                session_id = message.data['session_id']
                break

    if not session_id:
        raise RuntimeError("Failed to extract session ID from Claude SDK response")

    return session_id

# FastAPI dependency injection pattern
from functools import lru_cache

@lru_cache()
def get_claude_service(request: Request) -> ClaudeService:
    """Get Claude service with consistent project root."""
    project_root = request.app.state.project_root
    return ClaudeService(project_root)

# Updated API endpoints
@router.post("/sessions", response_model=SessionResponse)
async def create_session(
    request: SessionRequest,
    claude_service: ClaudeService = Depends(get_claude_service)
):
    return await claude_service.create_session(request)

@router.post("/query", response_model=QueryResponse)
async def query_claude(
    request: ClaudeQueryRequest,
    claude_service: ClaudeService = Depends(get_claude_service)
):
    # Use session_id directly for resumption - no mapping needed
    return await claude_service.resume_session(
        session_id=request.session_id,
        query_text=request.query,
        working_directory=app.state.project_root  # Use consistent working directory
    )
```

### Integration Points

```yaml
WORKING_DIRECTORY:
  - lifespan: "Set in FastAPI lifespan events before Claude operations"
  - consistency: "Same working directory for all session operations"
  - storage: "Claude sessions at ~/.claude/projects/{project-hash}/"
  - debugging: "Verify storage location with verify_sessions.py script"

FASTAPI_LIFECYCLE:
  - startup: "Initialize working directory and verify Claude session storage"
  - dependency: "Use lru_cache for singleton Claude service instances"
  - monitoring: "Log session storage location and availability"

DOCKER_DEPLOYMENT:
  - volumes: "Mount ~/.claude for session persistence across container restarts"
  - working_dir: "Set WORKDIR /code in Dockerfile for consistent project root"
  - environment: "CLAUDE_PROJECT_ROOT environment variable for configuration"

IOS_CLIENT:
  - session_ids: "Use Claude SDK session IDs directly in API calls"
  - persistence: "Store session metadata locally with Claude SDK session IDs"
  - working_directory: "Allow users to specify project context during session creation"
```

## Validation Loop

### Level 1: Syntax & Style (Immediate Feedback)

```bash
# Backend validation with virtual environment
cd backend && source venv/bin/activate

# Check linting and formatting
python -m ruff check app/ --fix
python -m mypy app/
python -m ruff format app/

# Expected: Zero errors. Fix any issues before proceeding.
```

### Level 2: Unit Tests (Component Validation)

```bash
# Test session management components
cd backend && source venv/bin/activate

# Test direct SDK integration
python -m pytest tests/test_session_management.py -v

# Test working directory handling
python -m pytest tests/test_working_directory.py -v

# Test Claude service refactoring
python -m pytest app/services/ -v

# Full test suite
python -m pytest app/ -v --cov=app --cov-report=term-missing

# Expected: All tests pass with >90% coverage on session management code
```

### Level 3: Integration Testing (System Validation)

```bash
# Backend startup and session persistence validation
cd backend
docker-compose up -d
sleep 5

# Health check
curl -f http://localhost:8000/health || echo "Backend health check failed"

# Session creation with working directory specification
curl -X POST http://localhost:8000/claude/sessions \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "test-user",
    "session_name": "Test Session",
    "working_directory": "/Users/beardedwonder/Development/DBGVentures/Claude_Code-Mobile"
  }' | jq .

# Store session ID for testing
SESSION_ID=$(curl -s -X POST http://localhost:8000/claude/sessions \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test", "session_name": "Context Test"}' | jq -r .session_id)

# Test session continuity
curl -X POST http://localhost:8000/claude/query \
  -H "Content-Type: application/json" \
  -d "{\"session_id\": \"$SESSION_ID\", \"query\": \"Remember my favorite color is purple\", \"user_id\": \"test\"}"

# Restart backend to test persistence
docker-compose restart claude-backend
sleep 5

# Test session resumption after restart
curl -X POST http://localhost:8000/claude/query \
  -H "Content-Type: application/json" \
  -d "{\"session_id\": \"$SESSION_ID\", \"query\": \"What is my favorite color?\", \"user_id\": \"test\"}" | jq .

# Expected: Response mentions "purple", demonstrating session persistence
```

### Level 4: Creative & Domain-Specific Validation

```bash
# Claude SDK session storage verification
cd backend
python scripts/verify_sessions.py

# iOS client integration testing
cd ios-app/VisionForge
xcodebuild -scheme VisionForge test -destination 'platform=iOS Simulator,name=iPad Pro'

# Multi-session testing
# Create 5 concurrent sessions and verify each maintains independent context
for i in {1..5}; do
  SESSION_ID=$(curl -s -X POST http://localhost:8000/claude/sessions \
    -H "Content-Type: application/json" \
    -d "{\"user_id\": \"user$i\", \"session_name\": \"Session $i\"}" | jq -r .session_id)

  curl -X POST http://localhost:8000/claude/query \
    -H "Content-Type: application/json" \
    -d "{\"session_id\": \"$SESSION_ID\", \"query\": \"Remember: my number is $i\", \"user_id\": \"user$i\"}"
done

# Verify session isolation
# Each session should only remember its own number

# Working directory consistency testing
# Test sessions created with different working directories
curl -X POST http://localhost:8000/claude/sessions \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "dir-test",
    "session_name": "Custom Directory Test",
    "working_directory": "/tmp/claude-test"
  }'

# Performance testing - Session switching simulation
ab -n 50 -c 5 -T application/json -p session_query.json http://localhost:8000/claude/query

# Expected: All validations pass, consistent session behavior across scenarios
```

## Final Validation Checklist

### Technical Validation

- [ ] All 4 validation levels completed successfully
- [ ] All tests pass: `cd backend && python -m pytest app/ -v`
- [ ] No linting errors: `cd backend && python -m ruff check app/`
- [ ] No type errors: `cd backend && python -m mypy app/`
- [ ] Working directory consistency verified with debug script

### Feature Validation

- [ ] Session switching in iOS app maintains conversation history
- [ ] Sessions persist across FastAPI backend restarts
- [ ] Working directory specification works during session creation
- [ ] Multiple concurrent sessions work without interference (tested with 10+ sessions)
- [ ] Session resumption responds in <200ms consistently
- [ ] Docker deployment maintains session persistence

### Code Quality Validation

- [ ] Session mapping layer completely removed from codebase
- [ ] Direct Claude SDK session usage implemented throughout
- [ ] Working directory management follows FastAPI lifespan patterns
- [ ] File placement matches desired codebase tree structure
- [ ] All anti-patterns from original implementation eliminated

### Session Management Validation

- [ ] Session IDs are Claude SDK session IDs used directly (no mapping)
- [ ] Working directory is consistent and specifiable
- [ ] Session storage location is predictable: ~/.claude/projects/{project-hash}/
- [ ] Session files exist and are accessible for debugging
- [ ] Session recovery works after backend/container restarts
- [ ] iOS client session switching demonstrates full conversation context retention

---

## Anti-Patterns to Avoid

- ❌ Don't create session mapping layers - use Claude SDK session IDs directly
- ❌ Don't ignore working directory - Claude SDK session storage depends on it
- ❌ Don't use global variables for singleton patterns - use FastAPI dependency injection
- ❌ Don't skip lifespan events - working directory must be set before any Claude operations
- ❌ Don't assume session persistence without testing - verify with actual session switching
- ❌ Don't hardcode working directories - make them configurable and explicit
- ❌ Don't mix async/await patterns incorrectly with Claude SDK streaming responses
- ❌ Don't skip Docker volume mounting for session persistence in production
- ❌ Don't forget to use claude-code-sdk-shmaxi package for FastAPI compatibility
- ❌ Don't implement session cleanup without understanding Claude SDK session lifecycle