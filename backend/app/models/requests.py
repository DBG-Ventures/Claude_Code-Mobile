"""
Request models for the Claude Code FastAPI backend.

Pydantic models for validating incoming API requests following FastAPI best practices.
"""

from pydantic import BaseModel, Field
from typing import Dict, Optional, Any


class ClaudeCodeOptions(BaseModel):
    """Claude Code SDK options configuration."""

    api_key: Optional[str] = Field(None, description="Claude API key")
    model: Optional[str] = Field(
        None, description="Claude model to use (defaults to latest)"
    )
    max_tokens: Optional[int] = Field(8192, description="Maximum tokens in response")
    temperature: Optional[float] = Field(0.7, description="Response creativity level")
    timeout: Optional[int] = Field(60, description="Request timeout in seconds")


class SessionRequest(BaseModel):
    """Request to create a new Claude Code session."""

    user_id: str = Field(..., description="Unique user identifier")
    claude_options: Optional[ClaudeCodeOptions] = Field(
        default_factory=ClaudeCodeOptions, description="Claude SDK configuration"
    )
    session_name: Optional[str] = Field(None, description="Optional session name")
    context: Optional[Dict[str, Any]] = Field(
        default_factory=dict, description="Additional context"
    )


class ClaudeQueryRequest(BaseModel):
    """Request to send a query to Claude within a session."""

    query: str = Field(..., min_length=1, description="Query text for Claude")
    session_id: Optional[str] = Field(None, description="Session identifier")
    user_id: Optional[str] = Field("default_user", description="User making the request")
    stream: bool = Field(True, description="Whether to stream the response")
    options: Optional[ClaudeCodeOptions] = Field(
        default_factory=ClaudeCodeOptions, description="Claude Code options"
    )
    context: Optional[Dict[str, Any]] = Field(
        default_factory=dict, description="Additional query context"
    )


class SessionListRequest(BaseModel):
    """Request to list user sessions."""

    user_id: str = Field(..., description="User identifier")
    limit: Optional[int] = Field(
        10, ge=1, le=100, description="Maximum sessions to return"
    )
    offset: Optional[int] = Field(0, ge=0, description="Pagination offset")
    status_filter: Optional[str] = Field(None, description="Filter by session status")


class SessionUpdateRequest(BaseModel):
    """Request to update session properties."""

    session_id: str = Field(..., description="Session identifier")
    user_id: str = Field(..., description="User making the request")
    session_name: Optional[str] = Field(None, description="New session name")
    status: Optional[str] = Field(None, description="New session status")
    context: Optional[Dict[str, Any]] = Field(None, description="Updated context")
