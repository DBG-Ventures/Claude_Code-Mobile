# Claude Code SDK Session Management Fix Plan

## Executive Summary

Critical fix required for Claude Code SDK session resumption failures. Root cause identified: **incomplete async generator consumption** during session creation prevents proper session establishment.

**Status**: Ready for implementation
**Priority**: CRITICAL - Blocking session resumption functionality
**Effort**: 2-3 hours implementation + testing

## Problem Analysis

### Root Cause
The `_extract_session_id` method in `claude_service.py` breaks early after finding the session ID, preventing Claude SDK from completing the session initialization process. This causes:

1. **Async cleanup errors** - Premature generator termination
2. **"No conversation found" errors** - Incomplete session context
3. **Session resumption failures** - Context not properly established

### Evidence
- Session files exist and contain proper conversation data
- Session IDs are correctly extracted and stored
- Working directories are consistent between creation/resumption
- Error: "No conversation found with session ID: [id]" during resumption attempts

## Solution Overview

### Core Fix: Async Generator Consumption
**Problem**: Early `break` statement prevents full response consumption
**Solution**: Remove break and consume entire response stream

### Validation Strategy
**Problem**: Need to verify session health without wasting tokens
**Solution**: File-based validation using Claude SDK session files

### Session Tracking Enhancement
**Problem**: UI needs robust session metadata for listing and resumption
**Solution**: Enhanced metadata with resumability status

## Implementation Plan

### Phase 1: Critical Fix (IMMEDIATE)

#### 1.1 Fix _extract_session_id Method

**File**: `backend/app/services/claude_service.py`
**Method**: `_extract_session_id` (lines 146-181)

**Change**:
```python
async def _extract_session_id(self, response) -> str:
    """Extract Claude SDK session ID and fully consume response for proper session establishment."""
    try:
        session_id = None

        # CRITICAL: Consume the entire async response to allow Claude SDK to complete session setup
        async for message in response:
            # Extract session ID when found, but DON'T break early
            if (hasattr(message, 'data') and
                hasattr(message, 'subtype') and
                message.subtype == 'init' and
                'session_id' in message.data):
                session_id = message.data['session_id']
                self.logger.info(
                    f"Extracted Claude SDK session ID: {session_id}",
                    category="session_management",
                    operation="extract_session_id"
                )
                # Continue consuming - don't break!

        if not session_id:
            raise RuntimeError("Failed to extract session ID from Claude SDK response")

        return session_id

    except Exception as e:
        self.logger.error(f"Session ID extraction failed: {e}")
        raise RuntimeError(f"Failed to extract session ID: {e}")
```

**Key Changes**:
- Remove `break` statement after session ID extraction
- Continue consuming async generator until completion
- Add debug logging for consumed messages

### Phase 2: Enhanced Validation (HIGH PRIORITY)

#### 2.1 Add File-Based Session Validation

**File**: `backend/app/services/claude_service.py`
**New Method**: Add after `_extract_session_id`

```python
def _validate_session_file_exists(self, session_id: str, working_dir: str) -> bool:
    """Validate session file exists without sending any prompts.

    Uses the working directory to determine the correct Claude SDK storage location.
    """
    try:
        # Claude SDK creates sessions in ~/.claude/projects/{working_dir_hash}/
        # We can compute the same hash to look in the right directory
        claude_home = os.environ.get("CLAUDE_HOME", str(Path.home() / ".claude"))

        # Use the same hashing logic as Claude SDK (convert slashes and underscores to dashes)
        project_hash = str(Path(working_dir).absolute()).replace("/", "-").replace("_", "-")
        if not project_hash.startswith("-"):
            project_hash = f"-{project_hash}"

        session_file = Path(claude_home) / "projects" / project_hash / f"{session_id}.jsonl"

        if session_file.exists():
            file_size = session_file.stat().st_size
            if file_size > 100:  # Reasonable minimum for a session with initialization
                self.logger.info(
                    f"Session file validated: {session_file}, size: {file_size}",
                    category="session_management",
                    operation="validate_session_file"
                )
                return True

        self.logger.warning(
            f"Session file not found: {session_file}",
            category="session_management",
            operation="validate_session_file"
        )
        return False

    except Exception as e:
        self.logger.error(f"Session file validation error: {e}")
        return False
```

#### 2.2 Update Session Creation Flow

**File**: `backend/app/services/claude_service.py`
**Method**: `create_session` (lines 67-144)

**Changes**:
1. Update initialization prompt to be minimal but meaningful
2. Add delayed file validation after session creation
3. Store metadata only after basic validation

```python
# Replace session creation prompt (line 91):
response = query(
    prompt="Starting new coding session",  # Minimal but meaningful
    options=ClaudeCodeOptions(
        cwd=working_dir,
        permission_mode="bypassPermissions"
    ),
)

# After session ID extraction, add validation:
# Wait briefly for Claude SDK to write session file
await asyncio.sleep(0.5)  # Give Claude SDK time to write file

# Validate session file exists without sending prompts
if not self._validate_session_file_exists(claude_session_id, working_dir):
    self.logger.warning(
        f"Session {claude_session_id} file not ready, storing metadata anyway",
        category="session_management"
    )
```

### Phase 3: Enhanced Session Metadata (MEDIUM PRIORITY)

#### 3.1 Add Resumability Status Checking

**File**: `backend/app/utils/session_storage.py`
**New Method**: Add to `PersistentSessionStorage` class

```python
def get_session_resumability_status(self, session_id: str) -> Dict[str, Any]:
    """Check if session is resumable using file system only.

    Uses stored working directory to efficiently locate the correct session file.
    """
    session_metadata = self.get_session(session_id)
    if not session_metadata:
        return {"resumable": False, "reason": "metadata_not_found"}

    working_dir = session_metadata.get("working_directory")
    if not working_dir:
        return {"resumable": False, "reason": "no_working_directory"}

    # Check if working directory still exists
    if not Path(working_dir).exists():
        return {"resumable": False, "reason": "working_directory_missing"}

    # Check Claude SDK session file using known working directory
    claude_home = os.environ.get("CLAUDE_HOME", str(Path.home() / ".claude"))

    # Use the same hashing logic as Claude SDK (convert slashes and underscores to dashes)
    project_hash = str(Path(working_dir).absolute()).replace("/", "-").replace("_", "-")
    if not project_hash.startswith("-"):
        project_hash = f"-{project_hash}"

    session_file = Path(claude_home) / "projects" / project_hash / f"{session_id}.jsonl"

    if not session_file.exists():
        return {"resumable": False, "reason": "session_file_missing"}

    file_size = session_file.stat().st_size
    if file_size < 100:
        return {"resumable": False, "reason": "session_file_too_small"}

    return {
        "resumable": True,
        "file_size": file_size,
        "file_path": str(session_file),
        "working_directory": working_dir
    }

def list_resumable_sessions(self, user_id: str, limit: int = 10) -> List[Dict[str, Any]]:
    """List only sessions that are actually resumable."""
    all_sessions = self.list_user_sessions(user_id, limit * 2)  # Get more to filter
    resumable_sessions = []

    for session_metadata in all_sessions:
        session_id = session_metadata.get("session_id")
        if session_id:
            status = self.get_session_resumability_status(session_id)
            if status.get("resumable"):
                resumable_sessions.append({
                    **session_metadata,
                    **status
                })

        if len(resumable_sessions) >= limit:
            break

    return resumable_sessions
```

## Testing Strategy

### Phase 1 Testing: Core Fix Verification
1. **Session Creation Test**
   - Create new session
   - Verify no async cleanup errors in logs
   - Confirm session file exists with content

2. **Session Resumption Test**
   - Create session with meaningful prompt
   - Immediately test resumption in same process
   - Test resumption after server restart

3. **Error Monitoring**
   - Monitor for "No conversation found" errors
   - Check for async cleanup exceptions
   - Verify session file integrity

### Phase 2 Testing: Validation Enhancement
1. **File Validation Test**
   - Test with valid session files
   - Test with missing session files
   - Test with corrupt/empty session files

2. **Working Directory Validation**
   - Test with existing working directories
   - Test with moved/deleted working directories
   - Test with permission issues

### Phase 3 Testing: UI Integration
1. **Session Listing Test**
   - List all sessions for user
   - List only resumable sessions
   - Verify metadata accuracy

2. **Resumability Status Test**
   - Check resumable sessions return true
   - Check broken sessions return false with reason
   - Verify file size and path information

## Success Criteria

### Critical Success Metrics
- ✅ **Zero "No conversation found" errors** during session resumption
- ✅ **Zero async cleanup exceptions** during session creation
- ✅ **100% session resumption success** for properly created sessions
- ✅ **Consistent session behavior** across server restarts

### Quality Metrics
- ✅ **No token waste** from validation prompts
- ✅ **Fast session creation** (< 2 seconds)
- ✅ **Accurate resumability status** for UI display
- ✅ **Robust error handling** with clear error messages

### Performance Metrics
- ✅ **Session creation time** remains under 2 seconds
- ✅ **Validation checks** complete under 100ms
- ✅ **Memory usage** stable during session operations
- ✅ **File I/O efficiency** for session metadata operations

## Risk Mitigation

### Implementation Risks
- **Risk**: Async changes break existing session creation
  **Mitigation**: Incremental testing with rollback plan

- **Risk**: File validation adds latency
  **Mitigation**: Asynchronous validation with timeout

- **Risk**: Session metadata grows too large
  **Mitigation**: Periodic cleanup of old sessions

### Deployment Risks
- **Risk**: Existing sessions become invalid
  **Mitigation**: Backward compatibility in session metadata

- **Risk**: Working directory changes break resumption
  **Mitigation**: Graceful degradation with clear error messages

## Implementation Checklist

### Phase 1: Critical Fix
- [ ] Remove break statement from `_extract_session_id`
- [ ] Test session creation with full response consumption
- [ ] Verify async cleanup errors are eliminated
- [ ] Test session resumption functionality
- [ ] Monitor logs for successful session establishment

### Phase 2: Enhanced Validation
- [ ] Implement `_validate_session_file_exists` method
- [ ] Add file validation to session creation flow
- [ ] Update session creation prompt to be minimal
- [ ] Test file validation edge cases
- [ ] Add proper error logging for validation failures

### Phase 3: UI-Ready Metadata
- [ ] Implement `get_session_resumability_status` method
- [ ] Add `list_resumable_sessions` method
- [ ] Update API endpoints to use enhanced metadata
- [ ] Test session listing with resumability status
- [ ] Verify UI integration with session metadata

### Final Testing
- [ ] End-to-end session lifecycle testing
- [ ] Performance benchmarking
- [ ] Error handling validation
- [ ] UI integration testing
- [ ] Production deployment readiness check

## Dependencies

### Internal Dependencies
- `backend/app/services/claude_service.py` - Core session management
- `backend/app/utils/session_storage.py` - Persistent metadata storage
- `backend/app/core/lifecycle.py` - Application lifecycle and working directory setup

### External Dependencies
- Claude Code SDK v1.0.115 - Session management and file storage
- FastAPI - Web framework for session endpoints
- Uvicorn - ASGI server for development

### Environment Dependencies
- `CLAUDE_HOME` environment variable (optional, defaults to `~/.claude`)
- Working directory permissions for session file access
- Persistent storage location for session metadata JSON files

---

## Claude SDK Path Hashing Logic

**Important**: Claude SDK converts working directory paths using this pattern:
- Original: `/Users/beardedwonder/Development/DBGVentures/Claude_Code-Mobile`
- Step 1: Replace `/` with `-` → `-Users-beardedwonder-Development-DBGVentures-Claude_Code-Mobile`
- Step 2: Replace `_` with `-` → `-Users-beardedwonder-Development-DBGVentures-Claude-Code-Mobile`
- Final: `-Users-beardedwonder-Development-DBGVentures-Claude-Code-Mobile`

**Key insight**: Claude SDK converts **both slashes AND underscores** to hyphens for consistent directory naming.

Our validation code must use the same conversion logic:
```python
project_hash = str(Path(working_dir).absolute()).replace("/", "-").replace("_", "-")
if not project_hash.startswith("-"):
    project_hash = f"-{project_hash}"
```

---

**Document Version**: 1.1
**Last Updated**: 2025-09-16
**Status**: Ready for Implementation