"""
Claude Code SDK service wrapper with native session management.

Uses Claude Code SDK's built-in session resumption for conversation continuity
across multiple queries, eliminating the need for manual session management.
"""

import uuid
import asyncio
from datetime import datetime
from typing import Dict, Any, Optional, AsyncGenerator, List

from app.models.requests import (
    ClaudeQueryRequest,
    SessionRequest,
    ClaudeCodeOptions as RequestOptions,
)
from app.models.responses import (
    ClaudeMessage,
    SessionResponse,
    StreamingChunk,
    MessageRole,
    SessionStatus,
    ClaudeQueryResponse,
    ChunkType,
)

# Official Claude Code SDK
from claude_code_sdk import query
from claude_code_sdk.types import ClaudeCodeOptions


class SessionManager:
    """Manages Claude Code SDK sessions using native session resumption."""

    def __init__(self):
        self._sessions: Dict[str, Dict[str, Any]] = {}
        self._user_sessions: Dict[str, List[str]] = {}
        self._claude_session_ids: Dict[str, str] = {}  # Maps our session_id to Claude SDK session_id

    def create_session(self, user_id: str, session_name: Optional[str] = None) -> str:
        """Create a new session metadata."""
        session_id = str(uuid.uuid4())
        now = datetime.utcnow()

        session_data = {
            "session_id": session_id,
            "user_id": user_id,
            "session_name": session_name
            or f"Session {len(self._user_sessions.get(user_id, [])) + 1}",
            "status": SessionStatus.ACTIVE,
            "created_at": now,
            "updated_at": now,
            "context": {},
            "message_count": 0,
        }

        self._sessions[session_id] = session_data

        # Track user sessions
        if user_id not in self._user_sessions:
            self._user_sessions[user_id] = []
        self._user_sessions[user_id].append(session_id)

        return session_id

    def get_session(self, session_id: str) -> Optional[Dict[str, Any]]:
        """Get session data by ID."""
        return self._sessions.get(session_id)

    def get_user_sessions(self, user_id: str) -> List[Dict[str, Any]]:
        """Get all sessions for a user."""
        session_ids = self._user_sessions.get(user_id, [])
        return [
            self._sessions[sid]
            for sid in session_ids
            if sid in self._sessions
        ]

    def set_claude_session_id(self, session_id: str, claude_session_id: str) -> None:
        """Map our session ID to Claude SDK session ID."""
        self._claude_session_ids[session_id] = claude_session_id

    def get_claude_session_id(self, session_id: str) -> Optional[str]:
        """Get Claude SDK session ID for resumption."""
        return self._claude_session_ids.get(session_id)

    def update_session_status(self, session_id: str, status: SessionStatus) -> None:
        """Update session status."""
        if session_id in self._sessions:
            self._sessions[session_id]["status"] = status
            self._sessions[session_id]["updated_at"] = datetime.utcnow()

    def increment_message_count(self, session_id: str) -> None:
        """Increment message count for a session."""
        if session_id in self._sessions:
            self._sessions[session_id]["message_count"] += 1
            self._sessions[session_id]["updated_at"] = datetime.utcnow()


class ClaudeService:
    """
    Service for interacting with Claude Code SDK using native session management.

    Uses Claude SDK's built-in session resumption to maintain conversation
    context across multiple queries without manual session management.
    """

    def __init__(self):
        self.session_manager = SessionManager()

    async def create_session(self, request: SessionRequest) -> SessionResponse:
        """Create a new Claude Code session."""
        session_id = self.session_manager.create_session(
            user_id=request.user_id,
            session_name=request.session_name
        )

        session_data = self.session_manager.get_session(session_id)
        if not session_data:
            raise ValueError("Failed to create session")

        return SessionResponse(
            session_id=session_data["session_id"],
            user_id=session_data["user_id"],
            session_name=session_data["session_name"],
            status=session_data["status"],
            messages=[],
            created_at=session_data["created_at"],
            updated_at=session_data["updated_at"],
            message_count=0,
            context=session_data["context"],
        )

    async def query(
        self, request: ClaudeQueryRequest, options: RequestOptions
    ) -> ClaudeQueryResponse:
        """
        Send a query to Claude using SDK native session resumption.

        Uses Claude SDK's built-in session management to maintain conversation context.
        """
        session = self.session_manager.get_session(request.session_id)
        if not session:
            raise ValueError(f"Session {request.session_id} not found")

        try:
            start_time = datetime.utcnow()

            # Get Claude session ID if available for resumption
            claude_session_id = self.session_manager.get_claude_session_id(request.session_id)

            # Create proper SDK options object
            sdk_options = ClaudeCodeOptions(
                model=options.model,  # Use default model if None
                resume=claude_session_id,  # This enables session resumption
                permission_mode="bypassPermissions",  # Allow all tools for mobile use
            )

            # Send query to Claude SDK
            response = query(
                prompt=request.query,
                options=sdk_options
            )

            # Collect response and extract session ID
            response_content = ""
            new_claude_session_id = None

            async for message in response:
                # Extract session ID from SystemMessage with init subtype
                if hasattr(message, 'subtype') and message.subtype == 'init':
                    if hasattr(message, 'data') and 'session_id' in message.data:
                        new_claude_session_id = message.data['session_id']

                # Extract text content
                if hasattr(message, "content"):
                    for block in message.content:
                        if hasattr(block, "text"):
                            response_content += block.text

            # Store Claude session ID for future resumption
            if new_claude_session_id:
                self.session_manager.set_claude_session_id(request.session_id, new_claude_session_id)

            # Increment message count (user + assistant)
            self.session_manager.increment_message_count(request.session_id)
            self.session_manager.increment_message_count(request.session_id)

            processing_time = (datetime.utcnow() - start_time).total_seconds()

            # Create assistant message response
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
            self.session_manager.update_session_status(
                request.session_id, SessionStatus.ERROR
            )
            raise e

    async def stream_response(
        self, request: ClaudeQueryRequest, options: RequestOptions
    ) -> AsyncGenerator[StreamingChunk, None]:
        """
        Stream Claude's response using SDK native session resumption.

        Uses Claude SDK's built-in session management to maintain conversation context.
        """
        session = self.session_manager.get_session(request.session_id)
        if not session:
            raise ValueError(f"Session {request.session_id} not found")

        try:
            # Yield start chunk
            yield StreamingChunk(
                chunk_type=ChunkType.START,
                content=None,
                message_id=str(uuid.uuid4()),
                session_id=request.session_id,
            )

            # Get Claude session ID if available for resumption
            claude_session_id = self.session_manager.get_claude_session_id(request.session_id)

            # Create proper SDK options object
            sdk_options = ClaudeCodeOptions(
                model=options.model,  # Use default model if None
                resume=claude_session_id,  # This enables session resumption
                permission_mode="bypassPermissions",  # Allow all tools for mobile use
            )

            # Send query to Claude SDK
            response = query(
                prompt=request.query,
                options=sdk_options
            )

            # Stream response chunks
            accumulated_content = ""
            new_claude_session_id = None

            async for message in response:
                # Extract session ID from SystemMessage with init subtype
                if hasattr(message, 'subtype') and message.subtype == 'init':
                    if hasattr(message, 'data') and 'session_id' in message.data:
                        new_claude_session_id = message.data['session_id']

                # Extract and yield text content
                if hasattr(message, "content"):
                    for block in message.content:
                        if hasattr(block, "text"):
                            chunk_text = block.text
                            accumulated_content += chunk_text

                            yield StreamingChunk(
                                chunk_type=ChunkType.DELTA,
                                content=chunk_text,
                                message_id=str(uuid.uuid4()),
                                session_id=request.session_id,
                            )

            # Store Claude session ID for future resumption
            if new_claude_session_id:
                self.session_manager.set_claude_session_id(request.session_id, new_claude_session_id)

            # Increment message count (user + assistant)
            self.session_manager.increment_message_count(request.session_id)
            self.session_manager.increment_message_count(request.session_id)

            # Yield completion chunk
            yield StreamingChunk(
                chunk_type=ChunkType.COMPLETE,
                content=None,
                message_id=str(uuid.uuid4()),
                session_id=request.session_id,
            )

        except Exception as e:
            # Yield error chunk
            yield StreamingChunk(
                chunk_type=ChunkType.ERROR,
                content=None,
                error=str(e),
                message_id=str(uuid.uuid4()),
                session_id=request.session_id,
            )

            self.session_manager.update_session_status(
                request.session_id, SessionStatus.ERROR
            )
            raise e

    async def get_sessions(self, user_id: str) -> List[SessionResponse]:
        """Get all sessions for a user."""
        sessions_data = self.session_manager.get_user_sessions(user_id)

        return [
            SessionResponse(
                session_id=session["session_id"],
                user_id=session["user_id"],
                session_name=session["session_name"],
                status=session["status"],
                messages=[],  # Messages are handled by Claude SDK
                created_at=session["created_at"],
                updated_at=session["updated_at"],
                message_count=session["message_count"],
                context=session["context"],
            )
            for session in sessions_data
        ]

    async def get_session(
        self, session_id: str, user_id: str
    ) -> Optional[SessionResponse]:
        """Get session details."""
        session_data = self.session_manager.get_session(session_id)
        if not session_data or session_data["user_id"] != user_id:
            return None

        return SessionResponse(
            session_id=session_data["session_id"],
            user_id=session_data["user_id"],
            session_name=session_data["session_name"],
            status=session_data["status"],
            messages=[],  # Messages are handled by Claude SDK
            created_at=session_data["created_at"],
            updated_at=session_data["updated_at"],
            message_count=session_data["message_count"],
            context=session_data["context"],
        )

    async def list_user_sessions(
        self, user_id: str, limit: int = 10, offset: int = 0
    ) -> List[SessionResponse]:
        """List sessions for a user with pagination."""
        sessions_data = self.session_manager.get_user_sessions(user_id)

        # Apply pagination
        paginated_sessions = sessions_data[offset:offset + limit]

        return [
            SessionResponse(
                session_id=session["session_id"],
                user_id=session["user_id"],
                session_name=session["session_name"],
                status=session["status"],
                messages=[],  # Messages are handled by Claude SDK
                created_at=session["created_at"],
                updated_at=session["updated_at"],
                message_count=session["message_count"],
                context=session["context"],
            )
            for session in paginated_sessions
        ]


# Global service instance
claude_service = ClaudeService()