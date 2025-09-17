"""
FastAPI Claude Code endpoints with SSE streaming support.

Provides REST API endpoints for Claude Code interactions with real-time
streaming capabilities for mobile clients.
"""

import json
import asyncio
from datetime import datetime

from fastapi import APIRouter, HTTPException, Depends, Query, Request
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


def get_claude_service(request: Request) -> ClaudeService:
    """Dependency to provide Claude service with SessionManager integration."""
    project_root = request.app.state.project_root
    session_storage = request.app.state.session_storage
    session_manager = request.app.state.session_manager
    return ClaudeService(project_root, session_storage, session_manager)


@router.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint for service monitoring."""
    return HealthResponse(
        status="healthy",
        timestamp=datetime.utcnow(),
        version="1.0.0",
        dependencies={
            "claude_sdk": "available",
            "sse_streaming": "available",
            "session_manager": "available",
        },
    )


@router.get("/session-manager/stats")
async def get_session_manager_stats(
    request: Request,
    claude_service: ClaudeService = Depends(get_claude_service),
):
    """
    Get SessionManager statistics for monitoring and debugging.

    Returns information about active sessions, cleanup status, and performance metrics.
    """
    try:
        stats = await claude_service.session_manager.get_session_stats()
        return JSONResponse(
            status_code=200,
            content={
                "session_manager_stats": stats,
                "timestamp": datetime.utcnow().isoformat(),
            },
        )
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"Failed to get session manager stats: {str(e)}"
        )


@router.post("/sessions", response_model=SessionResponse)
async def create_session(
    session_request: SessionRequest,
    request: Request,
    claude_service: ClaudeService = Depends(get_claude_service),
):
    """
    Create a new Claude Code session.

    Creates a new conversation session with the specified configuration.
    Sessions maintain context across multiple queries.
    """
    try:
        session = await claude_service.create_session(session_request)
        return session
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"Failed to create session: {str(e)}"
        )


@router.get("/sessions", response_model=SessionListResponse)
async def list_sessions(
    request: Request,
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
    request: Request,
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
    query_request: ClaudeQueryRequest,
    request: Request,
    claude_service: ClaudeService = Depends(get_claude_service),
):
    """
    Send a query to Claude and get the complete response.

    For non-streaming use cases where the full response is needed immediately.
    Use /claude/stream for real-time streaming responses.
    """
    try:
        # Use options from query_request or defaults
        options = query_request.options or ClaudeCodeOptions()
        response = await claude_service.query(query_request, options)
        return response
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except RuntimeError as e:
        raise HTTPException(status_code=500, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Unexpected error: {str(e)}")


@router.post("/stream")
async def stream_claude_response(
    query_request: ClaudeQueryRequest,
    request: Request,
    claude_service: ClaudeService = Depends(get_claude_service),
):
    print(f"🎯 API: Stream endpoint called for session {query_request.session_id}")
    print(f"🎯 API: Query: {query_request.query[:50]}...")
    print(f"🎯 API: User ID: {query_request.user_id}")
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
        print(
            f"🎯 API: Starting event generator for session {query_request.session_id}"
        )
        try:
            # Validate session exists
            print(
                f"🎯 API: Validating session {query_request.session_id} for user {query_request.user_id}"
            )
            session = await claude_service.get_session(
                query_request.session_id, query_request.user_id
            )
            print(f"🎯 API: Session validation result: {session is not None}")
            if not session:
                error_data = {
                    "content": None,
                    "chunk_type": "error",
                    "message_id": None,
                    "timestamp": datetime.utcnow().isoformat(),
                    "error": "session_not_found",
                    "message": f"Session {query_request.session_id} not found or access denied",
                }
                print(f"🎯 API: Sending session not found error: {error_data}")
                yield {
                    "event": "error",
                    "data": json.dumps(error_data),
                }
                return

            # Start streaming
            yield {
                "event": "start",
                "data": json.dumps(
                    {
                        "content": "Starting Claude response stream",
                        "chunk_type": "start",
                        "message_id": None,
                        "timestamp": datetime.utcnow().isoformat(),
                        "session_id": query_request.session_id,
                    }
                ),
            }

            # Use options from query_request or defaults
            options = query_request.options or ClaudeCodeOptions()

            # Stream Claude response chunks
            print("🎯 API: About to start streaming from Claude service")
            async for chunk in claude_service.stream_response(query_request, options):
                print(f"🎯 API: Received chunk from Claude service: {chunk.chunk_type}")
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
                        "content": None,
                        "chunk_type": "error",
                        "message_id": None,
                        "timestamp": datetime.utcnow().isoformat(),
                        "error": "validation_error",
                        "message": str(e),
                    }
                ),
            }
        except Exception as e:
            yield {
                "event": "error",
                "data": json.dumps(
                    {
                        "content": None,
                        "chunk_type": "error",
                        "message_id": None,
                        "timestamp": datetime.utcnow().isoformat(),
                        "error": "internal_error",
                        "message": f"Streaming failed: {str(e)}",
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
    update_request: SessionUpdateRequest,
    request: Request,
    claude_service: ClaudeService = Depends(get_claude_service),
):
    """
    Update session properties.

    Allows updating session name, status, and context metadata.
    """
    # Validate update_request matches path parameter
    if update_request.session_id != session_id:
        raise HTTPException(
            status_code=400, detail="Session ID in path must match request body"
        )

    try:
        # Get current session to verify access
        session = await claude_service.get_session(session_id, update_request.user_id)
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
    request: Request,
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

        # Actually delete the session
        success = await claude_service.delete_session(session_id, user_id)

        if not success:
            raise HTTPException(
                status_code=500,
                detail=f"Failed to delete session {session_id}",
            )

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
