# Claude Code SDK Integration Patterns

## Overview

This document provides comprehensive patterns for integrating Claude Code SDK with FastAPI backends, based on extensive research and proven implementation examples.

## Core Integration Architecture

### Claude Code SDK Session Management

```python
from claude_code_sdk import ClaudeSDKClient, ClaudeCodeOptions
import asyncio
from typing import AsyncIterator

class ClaudeService:
    def __init__(self):
        self.active_sessions = {}

    async def create_session(self, session_id: str, options: ClaudeCodeOptions) -> str:
        """Create new Claude Code session with persistent context"""
        async with ClaudeSDKClient(options=options) as client:
            self.active_sessions[session_id] = client
            return session_id

    async def query_session(self, session_id: str, query: str) -> AsyncIterator[str]:
        """Send query to existing session and stream response"""
        if session_id not in self.active_sessions:
            raise ValueError(f"Session {session_id} not found")

        client = self.active_sessions[session_id]
        await client.query(query)

        async for message in client.receive_response():
            if hasattr(message, 'content'):
                for block in message.content:
                    if hasattr(block, 'text'):
                        yield block.text
```

## FastAPI Integration Patterns

### Critical Package Selection

**Use claude-code-sdk-shmaxi instead of official package:**
```bash
# WRONG: Official package has FastAPI subprocess issues
pip install claude-code-sdk

# CORRECT: Fixed fork for FastAPI compatibility
pip install claude-code-sdk-shmaxi
```

### Streaming Response Implementation

**Server-Sent Events (Recommended):**
```python
from sse_starlette.sse import EventSourceResponse
from fastapi import APIRouter
import json

router = APIRouter(prefix="/claude")

@router.get("/stream/{session_id}")
async def stream_claude_response(session_id: str, query: str):
    """Stream Claude Code responses via Server-Sent Events"""

    async def event_generator():
        try:
            claude_service = ClaudeService()
            async for text_chunk in claude_service.query_session(session_id, query):
                yield {
                    "data": json.dumps({
                        "content": text_chunk,
                        "type": "delta",
                        "session_id": session_id
                    })
                }
        except Exception as e:
            yield {
                "data": json.dumps({
                    "error": str(e),
                    "type": "error",
                    "session_id": session_id
                })
            }
        finally:
            yield {
                "data": json.dumps({
                    "type": "complete",
                    "session_id": session_id
                })
            }

    return EventSourceResponse(event_generator())
```

**WebSocket Alternative (Less Recommended):**
```python
from fastapi import WebSocket, WebSocketDisconnect

@router.websocket("/ws/{session_id}")
async def websocket_claude_stream(websocket: WebSocket, session_id: str):
    await websocket.accept()

    try:
        while True:
            query = await websocket.receive_text()
            claude_service = ClaudeService()

            async for text_chunk in claude_service.query_session(session_id, query):
                await websocket.send_json({
                    "content": text_chunk,
                    "type": "delta",
                    "session_id": session_id
                })

            await websocket.send_json({
                "type": "complete",
                "session_id": session_id
            })

    except WebSocketDisconnect:
        print(f"WebSocket disconnected for session {session_id}")
```

## Error Handling Patterns

### Robust Claude SDK Error Management

```python
from claude_code_sdk.exceptions import ClaudeSDKException
from fastapi import HTTPException
import logging

logger = logging.getLogger(__name__)

class ClaudeServiceWithErrorHandling:
    async def safe_query(self, session_id: str, query: str) -> AsyncIterator[dict]:
        try:
            async with ClaudeSDKClient(options=self.get_options()) as client:
                await client.query(query)

                async for message in client.receive_response():
                    if hasattr(message, 'content'):
                        for block in message.content:
                            if hasattr(block, 'text'):
                                yield {
                                    "type": "content",
                                    "data": block.text,
                                    "session_id": session_id
                                }

        except ClaudeSDKException as e:
            logger.error(f"Claude SDK error in session {session_id}: {e}")
            yield {
                "type": "error",
                "data": f"Claude Code SDK error: {str(e)}",
                "session_id": session_id
            }

        except Exception as e:
            logger.error(f"Unexpected error in session {session_id}: {e}")
            yield {
                "type": "error",
                "data": f"Service error: {str(e)}",
                "session_id": session_id
            }
```

## Multi-Session Management

### Concurrent Session Architecture

```python
from typing import Dict, Optional
import uuid
import asyncio

class SessionManager:
    def __init__(self, max_sessions: int = 10):
        self.max_sessions = max_sessions
        self.sessions: Dict[str, ClaudeSDKClient] = {}
        self.session_locks: Dict[str, asyncio.Lock] = {}

    async def create_session(self, options: ClaudeCodeOptions) -> str:
        if len(self.sessions) >= self.max_sessions:
            raise HTTPException(
                status_code=429,
                detail=f"Maximum sessions ({self.max_sessions}) exceeded"
            )

        session_id = str(uuid.uuid4())
        self.session_locks[session_id] = asyncio.Lock()

        # Initialize Claude client
        client = ClaudeSDKClient(options=options)
        await client.__aenter__()
        self.sessions[session_id] = client

        return session_id

    async def get_session(self, session_id: str) -> Optional[ClaudeSDKClient]:
        return self.sessions.get(session_id)

    async def close_session(self, session_id: str):
        if session_id in self.sessions:
            client = self.sessions[session_id]
            await client.__aexit__(None, None, None)
            del self.sessions[session_id]
            del self.session_locks[session_id]

    async def query_with_lock(self, session_id: str, query: str) -> AsyncIterator[str]:
        """Thread-safe session querying"""
        async with self.session_locks[session_id]:
            client = await self.get_session(session_id)
            if not client:
                raise HTTPException(status_code=404, detail="Session not found")

            await client.query(query)
            async for message in client.receive_response():
                if hasattr(message, 'content'):
                    for block in message.content:
                        if hasattr(block, 'text'):
                            yield block.text
```

## Configuration Patterns

### Environment-Based Configuration

```python
from pydantic import BaseSettings
from typing import Optional

class ClaudeSettings(BaseSettings):
    # Claude Code SDK Configuration
    anthropic_api_key: str
    claude_model: str = "claude-4-sonnet"
    max_tokens: int = 4096
    max_sessions: int = 10
    session_timeout: int = 3600  # 1 hour

    # Networking Mode Configuration
    networking_mode: str = "http"  # "http" or "ziti"

    # OpenZiti Configuration (Phase 2)
    ziti_identity_file: Optional[str] = None
    ziti_service_name: Optional[str] = None

    class Config:
        env_file = ".env"

# Usage in FastAPI
settings = ClaudeSettings()

def get_claude_options() -> ClaudeCodeOptions:
    return ClaudeCodeOptions(
        api_key=settings.anthropic_api_key,
        model=settings.claude_model,
        max_tokens=settings.max_tokens
    )
```

## Performance Optimization

### Connection Pooling and Resource Management

```python
import asyncio
from contextlib import asynccontextmanager

class OptimizedClaudeService:
    def __init__(self, pool_size: int = 5):
        self.pool_size = pool_size
        self.connection_pool = asyncio.Queue(maxsize=pool_size)
        self.initialized = False

    async def initialize_pool(self):
        """Initialize connection pool on startup"""
        for _ in range(self.pool_size):
            client = ClaudeSDKClient(options=get_claude_options())
            await client.__aenter__()
            await self.connection_pool.put(client)
        self.initialized = True

    @asynccontextmanager
    async def get_client(self):
        """Get client from pool with automatic return"""
        if not self.initialized:
            await self.initialize_pool()

        client = await self.connection_pool.get()
        try:
            yield client
        finally:
            await self.connection_pool.put(client)

    async def optimized_query(self, query: str) -> AsyncIterator[str]:
        """Query using pooled connection"""
        async with self.get_client() as client:
            await client.query(query)
            async for message in client.receive_response():
                if hasattr(message, 'content'):
                    for block in message.content:
                        if hasattr(block, 'text'):
                            yield block.text
```

## Testing Patterns

### Unit Testing Claude Service

```python
import pytest
from unittest.mock import AsyncMock, MagicMock
from claude_service import ClaudeService

@pytest.fixture
async def claude_service():
    return ClaudeService()

@pytest.fixture
def mock_claude_client():
    client = AsyncMock()
    client.query = AsyncMock()
    client.receive_response = AsyncMock()
    return client

@pytest.mark.asyncio
async def test_stream_response(claude_service, mock_claude_client):
    # Mock streaming response
    mock_message = MagicMock()
    mock_block = MagicMock()
    mock_block.text = "Test response"
    mock_message.content = [mock_block]

    mock_claude_client.receive_response.return_value = AsyncIterator([mock_message])

    # Test streaming
    chunks = []
    async for chunk in claude_service.query_session("test_session", "Hello"):
        chunks.append(chunk)

    assert chunks == ["Test response"]
    mock_claude_client.query.assert_called_once_with("Hello")
```

## Best Practices Summary

1. **Always use async context management** with Claude Code SDK
2. **Prefer Server-Sent Events over WebSockets** for unidirectional streaming
3. **Use claude-code-sdk-shmaxi** for FastAPI compatibility
4. **Implement proper error handling** for Claude SDK exceptions
5. **Use connection pooling** for production deployments
6. **Limit concurrent sessions** to prevent resource exhaustion
7. **Configure environment-based settings** for deployment flexibility
8. **Implement comprehensive testing** for all integration points

## Common Pitfalls to Avoid

- Don't forget async context management (`async with ClaudeSDKClient()`)
- Don't use blocking I/O in async endpoints
- Don't skip error handling for network/API failures
- Don't ignore session cleanup and resource management
- Don't hardcode configuration values
- Don't skip testing streaming functionality
- Don't use official claude-code-sdk with FastAPI (use shmaxi fork)

This document provides the complete patterns needed for robust Claude Code SDK integration with FastAPI backends supporting mobile clients.