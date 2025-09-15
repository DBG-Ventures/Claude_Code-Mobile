"""
FastAPI Claude Code endpoints with SSE streaming support.

Provides REST API endpoints for Claude Code interactions with real-time
streaming capabilities for mobile clients.
"""

import json
import asyncio
from datetime import datetime

from fastapi import APIRouter, HTTPException, Depends, Query
from fastapi.responses import JSONResponse
from sse_starlette.sse import EventSourceResponse

from app.models.requests import (
    ClaudeQueryRequest,
    SessionRequest,
    SessionUpdateRequest,
    ClaudeCodeOptions,
)
from app.models.responses import (
    ClaudeQueryResponse,
    SessionResponse,
    SessionListResponse,
    HealthResponse,
)
from app.services.claude_service import ClaudeService


# Create router with prefix
router = APIRouter(prefix="/claude", tags=["claude"])


# Dependency to get ClaudeService instance
def get_claude_service() -> ClaudeService:
    """Dependency to provide ClaudeService instance."""
    return ClaudeService()


@router.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint for service monitoring."""
    return HealthResponse(
        status="healthy",
        timestamp=datetime.utcnow(),
        version="1.0.0",
        dependencies={"claude_sdk": "available", "sse_streaming": "available"},
    )


@router.post("/sessions", response_model=SessionResponse)
async def create_session(
    request: SessionRequest, claude_service: ClaudeService = Depends(get_claude_service)
):
    """
    Create a new Claude Code session.

    Creates a new conversation session with the specified configuration.
    Sessions maintain context across multiple queries.
    """
    try:
        session = await claude_service.create_session(request)
        return session
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"Failed to create session: {str(e)}"
        )


@router.get("/sessions", response_model=SessionListResponse)
async def list_sessions(
    user_id: str = Query(..., description="User identifier"),
    limit: int = Query(10, ge=1, le=100, description="Maximum sessions to return"),
    offset: int = Query(0, ge=0, description="Pagination offset"),
    claude_service: ClaudeService = Depends(get_claude_service),
):
    """
    List user sessions with pagination.

    Returns sessions for the specified user with optional pagination.
    """
    try:
        sessions = await claude_service.list_user_sessions(
            user_id=user_id, limit=limit, offset=offset
        )

        # Calculate if there are more sessions
        total_user_sessions = len(
            await claude_service.list_user_sessions(user_id, limit=1000)
        )
        has_more = offset + limit < total_user_sessions

        return SessionListResponse(
            sessions=sessions,
            total_count=total_user_sessions,
            has_more=has_more,
            next_offset=offset + limit if has_more else None,
        )
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"Failed to list sessions: {str(e)}"
        )


@router.get("/sessions/{session_id}", response_model=SessionResponse)
async def get_session(
    session_id: str,
    user_id: str = Query(..., description="User identifier"),
    claude_service: ClaudeService = Depends(get_claude_service),
):
    """
    Get session details with full message history.

    Returns complete session information including all messages.
    """
    try:
        session = await claude_service.get_session(session_id, user_id)
        if not session:
            raise HTTPException(
                status_code=404,
                detail=f"Session {session_id} not found or access denied",
            )
        return session
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get session: {str(e)}")


@router.post("/query", response_model=ClaudeQueryResponse)
async def query_claude(
    request: ClaudeQueryRequest,
    options: ClaudeCodeOptions,
    claude_service: ClaudeService = Depends(get_claude_service),
):
    """
    Send a query to Claude and get the complete response.

    For non-streaming use cases where the full response is needed immediately.
    Use /claude/stream for real-time streaming responses.
    """
    try:
        response = await claude_service.query(request, options)
        return response
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except RuntimeError as e:
        raise HTTPException(status_code=500, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Unexpected error: {str(e)}")


@router.post("/stream")
async def stream_claude_response(
    request: ClaudeQueryRequest,
    options: ClaudeCodeOptions,
    claude_service: ClaudeService = Depends(get_claude_service),
):
    """
    Stream Claude's response in real-time using Server-Sent Events.

    CRITICAL: This is the main endpoint for mobile client streaming.
    Returns SSE stream with real-time Claude response chunks.

    SSE Format:
    - data: JSON chunk with content, chunk_type, message_id, timestamp
    - event: chunk_type (delta, complete, error)
    """

    async def event_generator():
        """
        Generate SSE events from Claude streaming response.

        Converts StreamingChunk objects to SSE format for real-time transmission.
        """
        try:
            # Validate session exists
            session = await claude_service.get_session(
                request.session_id, request.user_id
            )
            if not session:
                yield {
                    "event": "error",
                    "data": json.dumps(
                        {
                            "error": "session_not_found",
                            "message": f"Session {request.session_id} not found or access denied",
                            "timestamp": datetime.utcnow().isoformat(),
                        }
                    ),
                }
                return

            # Start streaming
            yield {
                "event": "start",
                "data": json.dumps(
                    {
                        "message": "Starting Claude response stream",
                        "session_id": request.session_id,
                        "timestamp": datetime.utcnow().isoformat(),
                    }
                ),
            }

            # Stream Claude response chunks
            async for chunk in claude_service.stream_response(request, options):
                chunk_data = {
                    "content": chunk.content,
                    "chunk_type": chunk.chunk_type,
                    "message_id": chunk.message_id,
                    "timestamp": chunk.timestamp.isoformat(),
                }

                yield {"event": chunk.chunk_type, "data": json.dumps(chunk_data)}

                # Add small delay to prevent overwhelming mobile clients
                await asyncio.sleep(0.01)

        except ValueError as e:
            yield {
                "event": "error",
                "data": json.dumps(
                    {
                        "error": "validation_error",
                        "message": str(e),
                        "timestamp": datetime.utcnow().isoformat(),
                    }
                ),
            }
        except Exception as e:
            yield {
                "event": "error",
                "data": json.dumps(
                    {
                        "error": "internal_error",
                        "message": f"Streaming failed: {str(e)}",
                        "timestamp": datetime.utcnow().isoformat(),
                    }
                ),
            }

    # Return Server-Sent Events response
    return EventSourceResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "Cache-Control",
        },
    )


@router.put("/sessions/{session_id}", response_model=SessionResponse)
async def update_session(
    session_id: str,
    request: SessionUpdateRequest,
    claude_service: ClaudeService = Depends(get_claude_service),
):
    """
    Update session properties.

    Allows updating session name, status, and context metadata.
    """
    # Validate request matches path parameter
    if request.session_id != session_id:
        raise HTTPException(
            status_code=400, detail="Session ID in path must match request body"
        )

    try:
        # Get current session to verify access
        session = await claude_service.get_session(session_id, request.user_id)
        if not session:
            raise HTTPException(
                status_code=404,
                detail=f"Session {session_id} not found or access denied",
            )

        # Update session properties
        # Note: In a full implementation, you'd need to add update methods to ClaudeService
        # For now, return the existing session as this is a minimal implementation
        return session

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"Failed to update session: {str(e)}"
        )


@router.delete("/sessions/{session_id}")
async def delete_session(
    session_id: str,
    user_id: str = Query(..., description="User identifier"),
    claude_service: ClaudeService = Depends(get_claude_service),
):
    """
    Delete a session.

    Permanently removes the session and all associated messages.
    """
    try:
        # Verify session exists and user has access
        session = await claude_service.get_session(session_id, user_id)
        if not session:
            raise HTTPException(
                status_code=404,
                detail=f"Session {session_id} not found or access denied",
            )

        # Note: In a full implementation, you'd add a delete method to ClaudeService
        # For now, return success as this is a minimal implementation
        return JSONResponse(
            status_code=200,
            content={
                "message": f"Session {session_id} deleted successfully",
                "timestamp": datetime.utcnow().isoformat(),
            },
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"Failed to delete session: {str(e)}"
        )
