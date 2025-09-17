# Claude Code SDK Session Manager Implementation Plan

## Overview

This document outlines the implementation plan for fixing the critical session management issues in the Claude Code Mobile backend using a Session Manager architecture with persistent ClaudeSDKClient instances.

## Problem Analysis

### Current Issues
- **Root Cause**: Using wrong SDK methods - mixed standalone `query()` with `ClaudeSDKClient`
- **Session Resumption Failures**: "No conversation found with session ID" errors
- **Architecture Mismatch**: Stateless API with session-based SDK

### Key Requirements
- ✅ Eliminate wasteful initialization prompts
- ✅ Support multiple concurrent sessions (different app windows)
- ✅ Maintain continuous conversations with context
- ✅ Session persistence across server restarts
- ✅ Stateless API architecture compatibility

## Chosen Architecture: Session Manager with Persistent Clients

### Core Concept
- **SessionManager**: Singleton that maintains active ClaudeSDKClient instances
- **Per-Session Clients**: Each session gets its own long-lived ClaudeSDKClient
- **Lazy Initialization**: Sessions created on first use, no wasteful prompts
- **Automatic Cleanup**: Inactive sessions cleaned up periodically

## Implementation Plan

### Phase 1: Session Manager Core

#### 1.1 Create SessionManager Class
```python
# File: backend/app/services/session_manager.py

import asyncio
import time
from typing import Dict, Optional
from claude_code_sdk import ClaudeSDKClient
from claude_code_sdk.types import ClaudeCodeOptions

class SessionManager:
    """Manages persistent ClaudeSDKClient instances for continuous conversations."""

    def __init__(self):
        self.active_sessions: Dict[str, Dict] = {}
        # Structure: {
        #   "session_id": {
        #       "client": ClaudeSDKClient,
        #       "working_dir": str,
        #       "last_used": float,
        #       "created_at": float
        #   }
        # }
        self.cleanup_task = None
        self.session_timeout = 3600  # 1 hour inactivity timeout

    async def get_or_create_session(self, session_id: str, working_dir: str,
                                   is_new_session: bool = False) -> ClaudeSDKClient:
        """Get existing session or create new one. No wasteful initialization."""

        # Check if session exists and is valid
        if session_id in self.active_sessions:
            session_info = self.active_sessions[session_id]
            session_info["last_used"] = time.time()
            return session_info["client"]

        # Create new session
        options = ClaudeCodeOptions(
            cwd=working_dir,
            permission_mode="bypassPermissions",
            resume=None if is_new_session else session_id
        )

        client = ClaudeSDKClient(options)
        await client.connect()  # No initial prompt - saves tokens!

        # Store session info
        self.active_sessions[session_id] = {
            "client": client,
            "working_dir": working_dir,
            "last_used": time.time(),
            "created_at": time.time()
        }

        # Start cleanup task if not running
        if self.cleanup_task is None:
            self.cleanup_task = asyncio.create_task(self._cleanup_loop())

        return client

    async def cleanup_session(self, session_id: str):
        """Manually cleanup a specific session."""
        if session_id in self.active_sessions:
            client = self.active_sessions[session_id]["client"]
            await client.disconnect()
            del self.active_sessions[session_id]

    async def _cleanup_loop(self):
        """Periodically cleanup inactive sessions."""
        while True:
            await asyncio.sleep(300)  # Check every 5 minutes
            current_time = time.time()
            sessions_to_remove = []

            for session_id, session_info in self.active_sessions.items():
                if current_time - session_info["last_used"] > self.session_timeout:
                    sessions_to_remove.append(session_id)

            for session_id in sessions_to_remove:
                await self.cleanup_session(session_id)

    async def shutdown(self):
        """Cleanup all sessions on shutdown."""
        if self.cleanup_task:
            self.cleanup_task.cancel()

        for session_id in list(self.active_sessions.keys()):
            await self.cleanup_session(session_id)

# Global session manager instance
session_manager = SessionManager()
```

#### 1.2 Integrate with Application Lifecycle
```python
# File: backend/app/core/lifecycle.py

from app.services.session_manager import session_manager

@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup sessions on server shutdown."""
    await session_manager.shutdown()
```

### Phase 2: API Integration

#### 2.1 Update Session Creation Endpoint
```python
# File: backend/app/services/claude_service.py

async def create_session(self, request: SessionRequest) -> SessionResponse:
    """Create new session using Session Manager - no wasteful initialization."""
    try:
        working_dir = request.working_directory or self.project_root

        # Generate unique session ID
        session_id = str(uuid.uuid4())

        # Get session client (will create new one)
        client = await session_manager.get_or_create_session(
            session_id=session_id,
            working_dir=working_dir,
            is_new_session=True
        )

        # Store metadata for UI (separate from session management)
        session_response = SessionResponse(
            session_id=session_id,
            user_id=request.user_id,
            session_name=getattr(request, "session_name", None) or f"Session {session_id[:8]}",
            status=SessionStatus.ACTIVE,
            messages=[],
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow(),
            message_count=0,
            context={"working_directory": working_dir},
        )

        # Store in persistent storage for UI listing
        self.session_storage.store_session(
            session_id=session_id,
            user_id=request.user_id,
            working_directory=working_dir,
            session_name=getattr(request, "session_name", None) or f"Session {session_id[:8]}",
            created_at=datetime.utcnow()
        )

        return session_response

    except Exception as e:
        raise RuntimeError(f"Failed to create session: {e}")
```

#### 2.2 Update Query Method
```python
async def query(self, request: ClaudeQueryRequest, options: RequestOptions) -> ClaudeQueryResponse:
    """Send query using persistent session client."""
    try:
        start_time = datetime.utcnow()

        # Get session metadata for working directory
        session_metadata = self.session_storage.get_session(request.session_id)
        if not session_metadata:
            raise ValueError(f"Session {request.session_id} not found")

        working_dir = session_metadata["working_directory"]

        # Get persistent session client
        client = await session_manager.get_or_create_session(
            session_id=request.session_id,
            working_dir=working_dir,
            is_new_session=False
        )

        # Send query to persistent client
        await client.query(request.query)

        # Collect response
        response_content = ""
        async for message in client.receive_response():
            if isinstance(message, AssistantMessage):
                for block in message.content:
                    if isinstance(block, TextBlock):
                        response_content += block.text

        # Create response
        processing_time = (datetime.utcnow() - start_time).total_seconds()
        assistant_message = ClaudeMessage(
            id=str(uuid.uuid4()),
            content=response_content,
            role=MessageRole.ASSISTANT,
            timestamp=datetime.utcnow(),
            session_id=request.session_id,
        )

        return ClaudeQueryResponse(
            session_id=request.session_id,
            message=assistant_message,
            processing_time=processing_time,
        )

    except Exception as e:
        raise RuntimeError(f"Query failed for session {request.session_id}: {e}")
```

#### 2.3 Update Streaming Method
```python
async def stream_response(self, request: ClaudeQueryRequest, options: RequestOptions) -> AsyncGenerator[StreamingChunk, None]:
    """Stream response using persistent session client."""
    try:
        # Get session metadata
        session_metadata = self.session_storage.get_session(request.session_id)
        if not session_metadata:
            raise ValueError(f"Session {request.session_id} not found")

        working_dir = session_metadata["working_directory"]

        # Yield start chunk
        yield StreamingChunk(
            chunk_type=ChunkType.START,
            content=None,
            message_id=str(uuid.uuid4()),
            session_id=request.session_id,
        )

        # Get persistent session client
        client = await session_manager.get_or_create_session(
            session_id=request.session_id,
            working_dir=working_dir,
            is_new_session=False
        )

        # Send query and stream response
        await client.query(request.query)

        async for message in client.receive_response():
            if isinstance(message, AssistantMessage):
                for block in message.content:
                    if isinstance(block, TextBlock):
                        yield StreamingChunk(
                            chunk_type=ChunkType.DELTA,
                            content=block.text,
                            message_id=str(uuid.uuid4()),
                            session_id=request.session_id,
                        )
                        await asyncio.sleep(0.01)  # Mobile optimization

        # Yield completion chunk
        yield StreamingChunk(
            chunk_type=ChunkType.COMPLETE,
            content=None,
            message_id=str(uuid.uuid4()),
            session_id=request.session_id,
        )

    except Exception as e:
        yield StreamingChunk(
            chunk_type=ChunkType.ERROR,
            content=str(e),
            message_id=str(uuid.uuid4()),
            session_id=request.session_id,
        )
```

### Phase 3: Session Lifecycle Management

#### 3.1 Enhanced Error Handling
- Handle disconnected clients gracefully
- Automatic reconnection with resume for dropped sessions
- Proper error messaging for invalid sessions

#### 3.2 Session Cleanup Strategies
- **Inactivity Timeout**: 1 hour default, configurable
- **Memory Management**: Monitor and limit concurrent sessions
- **Graceful Shutdown**: Properly disconnect all clients

#### 3.3 Monitoring and Logging
- Session creation/destruction logging
- Active session count metrics
- Performance monitoring for session operations

## Benefits of This Approach

### ✅ Addresses All Key Issues
- **No Wasteful Initialization**: Sessions start with first real user message
- **Multi-Session Support**: Each session gets independent persistent client
- **Continuous Conversations**: Full context preservation via persistent clients
- **Stateless API**: Session Manager handles state, API remains stateless

### ✅ Performance Benefits
- Eliminates client creation overhead per request
- Maintains conversation context efficiently
- Reduces token usage (no initialization prompts)

### ✅ Operational Benefits
- Automatic session cleanup prevents memory leaks
- Graceful error handling for disconnected sessions
- Easy to monitor and debug session lifecycle

## Testing Strategy

### Unit Tests
- SessionManager session creation/retrieval
- Session cleanup logic
- Error handling scenarios

### Integration Tests
- Full API workflow with persistent sessions
- Multiple concurrent sessions
- Session resumption after inactivity

### Performance Tests
- Memory usage under load
- Session cleanup effectiveness
- Response time with persistent clients

## Migration Path

1. **Phase 1**: Implement SessionManager alongside existing code
2. **Phase 2**: Update API endpoints to use SessionManager
3. **Phase 3**: Remove old standalone query() implementations
4. **Phase 4**: Add monitoring and cleanup enhancements

## Success Criteria

- ✅ No "No conversation found" errors
- ✅ Multiple app windows can maintain independent sessions
- ✅ Session context preserved across conversations
- ✅ No wasteful token usage on session creation
- ✅ Automatic cleanup prevents resource leaks
- ✅ Server restart resilience via resume parameter

---

**Status**: Ready for Implementation
**Priority**: CRITICAL - Blocking core functionality
**Estimated Effort**: 1-2 days implementation + testing
**Last Updated**: 2025-09-16