# Claude Code SDK Session Management Patterns for FastAPI Backend

## Critical Context & Working Directory Requirements

The Claude Code SDK uses file-based session storage with **working directory dependency**. This creates specific challenges for FastAPI backends that must be addressed for reliable session management.

### Session Storage Architecture

```
~/.claude/projects/{project-hash}/
├── {session-id}.jsonl     # Session transcripts
└── metadata files         # Session state and configuration
```

**Critical**: `{project-hash}` is generated from the **absolute path** of the working directory where Claude SDK is executed.

### Working Directory Impact

```python
# Different working directories = different session storage locations
os.chdir("/Users/user/project")      # → ~/.claude/projects/-Users-user-project/
os.chdir("/app")                     # → ~/.claude/projects/-app/
os.chdir("/code")                    # → ~/.claude/projects/-code/
```

## FastAPI Integration Patterns

### 1. Working Directory Management (CRITICAL)

```python
from fastapi import FastAPI
from contextlib import asynccontextmanager
import os
from pathlib import Path

@asynccontextmanager
async def lifespan(app: FastAPI):
    # CRITICAL: Set consistent working directory BEFORE any Claude SDK operations
    project_root = Path(__file__).parent.parent.parent.absolute()
    os.chdir(project_root)

    # Verify Claude session storage location
    claude_sessions_path = Path.home() / ".claude" / "projects" / f"-{str(project_root).replace('/', '-')}"
    print(f"✅ Claude sessions stored at: {claude_sessions_path}")

    # Store in app state for service access
    app.state.project_root = project_root
    app.state.claude_sessions_path = claude_sessions_path

    yield

app = FastAPI(lifespan=lifespan)
```

### 2. Direct SDK Session Usage (ANTI-PATTERN ELIMINATION)

**❌ PROBLEMATIC - Unnecessary Session Mapping:**
```python
class SessionManager:
    def __init__(self):
        self._claude_session_ids: Dict[str, str] = {}  # Redundant mapping layer

    def set_claude_session_id(self, session_id: str, claude_session_id: str):
        self._claude_session_ids[session_id] = claude_session_id  # Memory-only storage
```

**✅ CORRECT - Direct SDK Usage:**
```python
from claude_code_sdk import query
from claude_code_sdk.types import ClaudeCodeOptions

class ClaudeService:
    def __init__(self, project_root: Path):
        self.project_root = project_root

    async def create_session(self, request: SessionRequest) -> SessionResponse:
        # Initialize Claude SDK session with explicit working directory
        response = query(
            prompt="Session initialized",
            options=ClaudeCodeOptions(
                cwd=str(self.project_root),  # Explicit working directory
                permission_mode="bypassPermissions"
            )
        )

        # Extract session ID from Claude SDK response
        claude_session_id = await self._extract_session_id(response)

        return SessionResponse(
            session_id=claude_session_id,  # Use Claude SDK session ID directly
            user_id=request.user_id,
            session_name=request.session_name,
            created_at=datetime.utcnow()
        )

    async def resume_session(self, session_id: str, query_text: str):
        # Direct session resumption using Claude SDK session ID
        response = query(
            prompt=query_text,
            options=ClaudeCodeOptions(
                cwd=str(self.project_root),    # Consistent working directory
                resume=session_id,             # Direct Claude SDK session ID
                permission_mode="bypassPermissions"
            )
        )
        return response
```

### 3. Session ID Extraction Pattern

```python
async def _extract_session_id(self, response) -> str:
    """Extract Claude SDK session ID from response stream."""
    session_id = None

    async for message in response:
        if hasattr(message, 'subtype') and message.subtype == 'init':
            # Claude SDK provides session ID in init message
            if hasattr(message, 'data') and 'session_id' in message.data:
                session_id = message.data['session_id']
                break
        elif hasattr(message, 'system_message') and hasattr(message.system_message, 'session_id'):
            # Alternative session ID location
            session_id = message.system_message.session_id
            break

    if not session_id:
        raise RuntimeError("Failed to extract session ID from Claude SDK response")

    return session_id
```

### 4. FastAPI Service Integration

```python
# Dependency injection for Claude service
async def get_claude_service(request: Request) -> ClaudeService:
    """Get Claude service with consistent working directory."""
    project_root = request.app.state.project_root
    return ClaudeService(project_root)

# API endpoint implementation
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
    # Use session_id directly for resumption
    return await claude_service.resume_session(request.session_id, request.query)
```

## Session Persistence Strategies

### Option 1: Native SDK File Storage (Recommended)

```python
class ClaudeService:
    async def list_sessions(self) -> List[SessionMetadata]:
        """List available sessions from Claude SDK storage."""
        sessions_path = Path.home() / ".claude" / "projects" / f"-{str(self.project_root).replace('/', '-')}"

        sessions = []
        for session_file in sessions_path.glob("*.jsonl"):
            session_id = session_file.stem

            # Read session metadata from first line
            with open(session_file, 'r') as f:
                first_line = f.readline()
                if first_line:
                    metadata = json.loads(first_line)
                    sessions.append(SessionMetadata(
                        session_id=session_id,
                        created_at=metadata.get('timestamp'),
                        last_active=session_file.stat().st_mtime
                    ))

        return sessions
```

### Option 2: Database Session Metadata (Hybrid Approach)

```python
# Store session metadata in database, leverage SDK for conversation history
class SessionMetadata(BaseModel):
    session_id: str          # Claude SDK session ID (primary key)
    user_id: str
    session_name: str
    created_at: datetime
    last_active: datetime
    status: str              # active, archived, deleted

class ClaudeService:
    def __init__(self, project_root: Path, db: AsyncSession):
        self.project_root = project_root
        self.db = db

    async def create_session_with_metadata(self, request: SessionRequest):
        # Create Claude SDK session
        response = query(
            prompt="Session initialized",
            options=ClaudeCodeOptions(cwd=str(self.project_root), permission_mode="bypassPermissions")
        )

        claude_session_id = await self._extract_session_id(response)

        # Store metadata in database
        session_metadata = SessionMetadata(
            session_id=claude_session_id,  # Use Claude SDK session ID as primary key
            user_id=request.user_id,
            session_name=request.session_name,
            created_at=datetime.utcnow(),
            last_active=datetime.utcnow(),
            status="active"
        )

        self.db.add(session_metadata)
        await self.db.commit()

        return session_metadata
```

## Docker Deployment Considerations

### Working Directory in Containers

```dockerfile
FROM python:3.11-slim

# Set consistent working directory
WORKDIR /code

# Create claude config directory with proper permissions
RUN mkdir -p /root/.claude/projects && \
    chmod 755 /root/.claude/projects

# Copy application
COPY ./app /code/app

# Ensure working directory is /code for Claude SDK
CMD ["python", "-m", "app.main"]
```

### Docker Compose with Session Persistence

```yaml
services:
  claude-backend:
    build: .
    working_dir: /code  # Explicit working directory
    volumes:
      # Persist Claude SDK sessions across container restarts
      - claude_sessions:/root/.claude
      # Application code (development)
      - ./app:/code/app
    environment:
      - CLAUDE_PROJECT_ROOT=/code
      - CLAUDE_API_KEY=${CLAUDE_API_KEY}

volumes:
  claude_sessions:
    driver: local
```

## Testing & Validation Patterns

### Session Storage Verification

```python
async def verify_claude_session_storage(project_root: Path) -> bool:
    """Verify Claude SDK session storage is accessible and functional."""
    claude_dir = Path.home() / ".claude"
    if not claude_dir.exists():
        raise RuntimeError("Claude configuration directory not found")

    projects_dir = claude_dir / "projects"
    if not projects_dir.exists():
        projects_dir.mkdir(parents=True)

    project_hash = f"-{str(project_root).replace('/', '-')}"
    project_sessions_dir = projects_dir / project_hash

    print(f"Claude project sessions directory: {project_sessions_dir}")
    print(f"Exists: {project_sessions_dir.exists()}")

    if project_sessions_dir.exists():
        session_files = list(project_sessions_dir.glob("*.jsonl"))
        print(f"Existing session files: {len(session_files)}")
        for session_file in session_files[:5]:  # Show first 5
            print(f"  - {session_file.name}")

    return True
```

### Integration Test Pattern

```python
async def test_session_continuity():
    """Test session continuity with working directory consistency."""
    project_root = Path("/code")
    os.chdir(project_root)

    # Create session
    response1 = query(
        prompt="Remember: my favorite color is blue",
        options=ClaudeCodeOptions(
            cwd=str(project_root),
            permission_mode="bypassPermissions"
        )
    )

    session_id = await extract_session_id(response1)
    print(f"Created session: {session_id}")

    # Resume session in same working directory
    response2 = query(
        prompt="What is my favorite color?",
        options=ClaudeCodeOptions(
            cwd=str(project_root),
            resume=session_id,
            permission_mode="bypassPermissions"
        )
    )

    # Should respond with "blue"
    async for message in response2:
        if hasattr(message, 'content'):
            for block in message.content:
                if hasattr(block, 'text'):
                    assert "blue" in block.text.lower()
                    print("✅ Session continuity verified")
                    return

    raise AssertionError("Session continuity failed")
```

## Error Handling & Recovery

### Working Directory Recovery

```python
class ClaudeService:
    def __init__(self, project_root: Path):
        self.project_root = project_root
        self._ensure_working_directory()

    def _ensure_working_directory(self):
        """Ensure working directory is set correctly before Claude SDK operations."""
        current_cwd = Path.cwd()
        if current_cwd != self.project_root:
            print(f"⚠️  Working directory mismatch: {current_cwd} != {self.project_root}")
            os.chdir(self.project_root)
            print(f"✅ Working directory corrected to: {self.project_root}")

    async def _with_working_directory(self, operation):
        """Execute operation with guaranteed working directory."""
        self._ensure_working_directory()
        try:
            return await operation()
        except Exception as e:
            # Log working directory context for debugging
            print(f"Error in working directory {Path.cwd()}: {e}")
            raise
```

### Session Recovery

```python
async def recover_session(session_id: str, project_root: Path) -> bool:
    """Attempt to recover a session by checking file system."""
    sessions_path = Path.home() / ".claude" / "projects" / f"-{str(project_root).replace('/', '-')}"
    session_file = sessions_path / f"{session_id}.jsonl"

    if session_file.exists():
        print(f"✅ Session {session_id} found in file system")
        return True
    else:
        print(f"❌ Session {session_id} not found in file system")
        print(f"Expected location: {session_file}")
        return False
```

## Key Takeaways

1. **Working Directory is Critical**: Claude SDK session storage depends on consistent working directory
2. **Eliminate Session Mapping**: Use Claude SDK session IDs directly instead of creating mapping layers
3. **Set Working Directory Early**: Use FastAPI lifespan events to set working directory before any Claude operations
4. **Leverage Native Storage**: Claude SDK's file-based storage is reliable when working directory is consistent
5. **Docker Considerations**: Use volumes for session persistence and explicit working directory configuration
6. **Test Session Continuity**: Verify session resumption works across FastAPI worker restarts

This approach eliminates the session mapping complexity while ensuring reliable session persistence through proper working directory management.