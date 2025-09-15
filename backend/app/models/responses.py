"""
Response models for the Claude Code FastAPI backend.

Pydantic models for API responses ensuring type safety and consistent data structures.
"""

from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
from datetime import datetime
from enum import Enum


class MessageRole(str, Enum):
    """Message role enumeration."""

    USER = "user"
    ASSISTANT = "assistant"
    SYSTEM = "system"


class SessionStatus(str, Enum):
    """Session status enumeration."""

    ACTIVE = "active"
    COMPLETED = "completed"
    ERROR = "error"
    PAUSED = "paused"


class ClaudeMessage(BaseModel):
    """Individual Claude message within a conversation."""

    id: str = Field(..., description="Unique message identifier")
    content: str = Field(..., description="Message content")
    role: MessageRole = Field(..., description="Message role (user/assistant/system)")
    timestamp: datetime = Field(..., description="Message timestamp")
    session_id: str = Field(..., description="Session identifier")
    metadata: Optional[Dict[str, Any]] = Field(
        default_factory=dict, description="Additional metadata"
    )


class StreamingChunk(BaseModel):
    """Individual chunk in a streaming response."""

    content: str = Field(..., description="Chunk content")
    chunk_type: str = Field(
        "delta", description="Type of chunk (delta, complete, error)"
    )
    message_id: Optional[str] = Field(None, description="Associated message ID")
    timestamp: datetime = Field(
        default_factory=datetime.utcnow, description="Chunk timestamp"
    )


class SessionResponse(BaseModel):
    """Response containing session information."""

    session_id: str = Field(..., description="Session identifier")
    user_id: str = Field(..., description="User identifier")
    session_name: Optional[str] = Field(None, description="Session name")
    status: SessionStatus = Field(..., description="Session status")
    messages: List[ClaudeMessage] = Field(
        default_factory=list, description="Session messages"
    )
    created_at: datetime = Field(..., description="Session creation timestamp")
    updated_at: datetime = Field(..., description="Last update timestamp")
    message_count: int = Field(0, description="Total message count")
    context: Optional[Dict[str, Any]] = Field(
        default_factory=dict, description="Session context"
    )


class SessionListResponse(BaseModel):
    """Response containing list of sessions."""

    sessions: List[SessionResponse] = Field(..., description="List of sessions")
    total_count: int = Field(..., description="Total number of sessions")
    has_more: bool = Field(..., description="Whether more sessions available")
    next_offset: Optional[int] = Field(None, description="Next pagination offset")


class ClaudeQueryResponse(BaseModel):
    """Response to a Claude query request."""

    session_id: str = Field(..., description="Session identifier")
    message: ClaudeMessage = Field(..., description="Claude's response message")
    status: str = Field("completed", description="Query status")
    processing_time: Optional[float] = Field(
        None, description="Processing time in seconds"
    )


class StreamingResponse(BaseModel):
    """Response for streaming endpoints."""

    stream_id: str = Field(..., description="Stream identifier")
    session_id: str = Field(..., description="Session identifier")
    status: str = Field("streaming", description="Stream status")
    start_time: datetime = Field(
        default_factory=datetime.utcnow, description="Stream start time"
    )


class ErrorResponse(BaseModel):
    """Standardized error response."""

    error: str = Field(..., description="Error type")
    message: str = Field(..., description="Human readable error message")
    details: Optional[Dict[str, Any]] = Field(
        None, description="Additional error details"
    )
    timestamp: datetime = Field(
        default_factory=datetime.utcnow, description="Error timestamp"
    )
    request_id: Optional[str] = Field(
        default=None, description="Request identifier for tracing"
    )


class HealthResponse(BaseModel):
    """Health check response."""

    status: str = Field("healthy", description="Service status")
    timestamp: datetime = Field(
        default_factory=datetime.utcnow, description="Health check timestamp"
    )
    version: Optional[str] = Field(None, description="Service version")
    dependencies: Optional[Dict[str, str]] = Field(
        default_factory=dict, description="Dependency status"
    )
