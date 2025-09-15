"""
Claude Code SDK service wrapper with async session management.

Provides async interface to Claude Code SDK with proper context management,
session persistence, and streaming response support.
"""

import uuid
from datetime import datetime
from typing import Dict, Any, Optional, AsyncGenerator, List
from contextlib import asynccontextmanager

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
)

# Official Claude Code SDK
from claude_code_sdk import query, ClaudeSDKClient


class SessionManager:
    """Manages active Claude Code sessions."""

    def __init__(self):
        self._sessions: Dict[str, Dict[str, Any]] = {}
        self._user_sessions: Dict[str, List[str]] = {}

    def create_session(self, user_id: str, session_name: Optional[str] = None) -> str:
        """Create a new session for a user."""
        session_id = str(uuid.uuid4())
        now = datetime.utcnow()

        session_data = {
            "session_id": session_id,
            "user_id": user_id,
            "session_name": session_name
            or f"Session {len(self._user_sessions.get(user_id, [])) + 1}",
            "status": SessionStatus.ACTIVE,
            "messages": [],
            "created_at": now,
            "updated_at": now,
            "context": {},
        }

        self._sessions[session_id] = session_data

        if user_id not in self._user_sessions:
            self._user_sessions[user_id] = []
        self._user_sessions[user_id].append(session_id)

        return session_id

    def get_session(self, session_id: str) -> Optional[Dict[str, Any]]:
        """Get session data by ID."""
        return self._sessions.get(session_id)

    def get_user_sessions(
        self, user_id: str, limit: int = 10, offset: int = 0
    ) -> List[Dict[str, Any]]:
        """Get sessions for a user with pagination."""
        session_ids = self._user_sessions.get(user_id, [])
        paginated_ids = session_ids[offset : offset + limit]
        return [self._sessions[sid] for sid in paginated_ids if sid in self._sessions]

    def add_message(self, session_id: str, message: ClaudeMessage) -> bool:
        """Add a message to a session."""
        if session_id not in self._sessions:
            return False

        self._sessions[session_id]["messages"].append(message.model_dump())
        self._sessions[session_id]["updated_at"] = datetime.utcnow()
        return True

    def update_session_status(self, session_id: str, status: SessionStatus) -> bool:
        """Update session status."""
        if session_id not in self._sessions:
            return False

        self._sessions[session_id]["status"] = status
        self._sessions[session_id]["updated_at"] = datetime.utcnow()
        return True


class ClaudeService:
    """
    Service wrapper for Claude Code SDK with async session management.

    Provides high-level interface for Claude interactions with proper
    resource management and session persistence.
    """

    def __init__(self):
        self.session_manager = SessionManager()

    def _prepare_sdk_kwargs(self, options: RequestOptions) -> dict:
        """Convert request options to SDK keyword arguments."""
        sdk_kwargs = {}
        if options.api_key:
            sdk_kwargs['api_key'] = options.api_key
        if options.model:
            sdk_kwargs['model'] = options.model
        if options.max_tokens:
            sdk_kwargs['max_tokens'] = options.max_tokens
        if options.temperature:
            sdk_kwargs['temperature'] = options.temperature
        if options.timeout:
            sdk_kwargs['timeout'] = options.timeout
        return sdk_kwargs

    @asynccontextmanager
    async def _get_claude_client(self, sdk_kwargs: dict):
        """
        Async context manager for Claude SDK client.

        CRITICAL: Uses async with pattern required for proper resource cleanup.
        """
        async with ClaudeSDKClient(**sdk_kwargs) as client:
            yield client

    async def create_session(self, request: SessionRequest) -> SessionResponse:
        """Create a new Claude Code session."""
        session_id = self.session_manager.create_session(
            user_id=request.user_id, session_name=request.session_name
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
        Send a query to Claude and return the complete response.

        For non-streaming use cases where the full response is needed.
        """
        session = self.session_manager.get_session(request.session_id)
        if not session:
            raise ValueError(f"Session {request.session_id} not found")

        # Add user message to session
        user_message = ClaudeMessage(
            id=str(uuid.uuid4()),
            content=request.query,
            role=MessageRole.USER,
            timestamp=datetime.utcnow(),
            session_id=request.session_id,
        )
        self.session_manager.add_message(request.session_id, user_message)

        # Get Claude response
        sdk_kwargs = self._prepare_sdk_kwargs(options)

        try:
            async with self._get_claude_client(sdk_kwargs) as client:
                start_time = datetime.utcnow()

                # Send query to Claude
                await client.query(request.query)

                # Collect full response
                response_content = ""
                async for message in client.receive_response():
                    if hasattr(message, "content"):
                        for block in message.content:
                            if hasattr(block, "text"):
                                response_content += block.text

                processing_time = (datetime.utcnow() - start_time).total_seconds()

                # Create assistant message
                assistant_message = ClaudeMessage(
                    id=str(uuid.uuid4()),
                    content=response_content,
                    role=MessageRole.ASSISTANT,
                    timestamp=datetime.utcnow(),
                    session_id=request.session_id,
                )

                # Add to session
                self.session_manager.add_message(request.session_id, assistant_message)

                return ClaudeQueryResponse(
                    session_id=request.session_id,
                    message=assistant_message,
                    status="completed",
                    processing_time=processing_time,
                )

        except Exception as e:
            self.session_manager.update_session_status(
                request.session_id, SessionStatus.ERROR
            )
            raise RuntimeError(f"Claude query failed: {str(e)}")

    async def stream_response(
        self, request: ClaudeQueryRequest, options: RequestOptions
    ) -> AsyncGenerator[StreamingChunk, None]:
        """
        Stream Claude's response in real-time chunks.

        CRITICAL: This is the main method for mobile client streaming.
        Yields StreamingChunk objects for SSE transmission.
        """
        session = self.session_manager.get_session(request.session_id)
        if not session:
            raise ValueError(f"Session {request.session_id} not found")

        # Add user message to session
        user_message = ClaudeMessage(
            id=str(uuid.uuid4()),
            content=request.query,
            role=MessageRole.USER,
            timestamp=datetime.utcnow(),
            session_id=request.session_id,
        )
        self.session_manager.add_message(request.session_id, user_message)

        # Start streaming response
        message_id = str(uuid.uuid4())
        sdk_kwargs = self._prepare_sdk_kwargs(options)
        full_response = ""

        try:
            async with self._get_claude_client(sdk_kwargs) as client:
                await client.query(request.query)

                async for message in client.receive_response():
                    if hasattr(message, "content"):
                        for block in message.content:
                            if hasattr(block, "text"):
                                chunk_content = block.text
                                full_response += chunk_content

                                # Yield streaming chunk
                                yield StreamingChunk(
                                    content=chunk_content,
                                    chunk_type="delta",
                                    message_id=message_id,
                                    timestamp=datetime.utcnow(),
                                )

                # Add complete assistant message to session
                assistant_message = ClaudeMessage(
                    id=message_id,
                    content=full_response,
                    role=MessageRole.ASSISTANT,
                    timestamp=datetime.utcnow(),
                    session_id=request.session_id,
                )
                self.session_manager.add_message(request.session_id, assistant_message)

                # Send completion chunk
                yield StreamingChunk(
                    content="",
                    chunk_type="complete",
                    message_id=message_id,
                    timestamp=datetime.utcnow(),
                )

        except Exception as e:
            self.session_manager.update_session_status(
                request.session_id, SessionStatus.ERROR
            )

            # Send error chunk
            yield StreamingChunk(
                content=f"Error: {str(e)}",
                chunk_type="error",
                message_id=message_id,
                timestamp=datetime.utcnow(),
            )

    async def get_session(
        self, session_id: str, user_id: str
    ) -> Optional[SessionResponse]:
        """Get session details with messages."""
        session_data = self.session_manager.get_session(session_id)
        if not session_data or session_data["user_id"] != user_id:
            return None

        messages = [ClaudeMessage(**msg_data) for msg_data in session_data["messages"]]

        return SessionResponse(
            session_id=session_data["session_id"],
            user_id=session_data["user_id"],
            session_name=session_data["session_name"],
            status=session_data["status"],
            messages=messages,
            created_at=session_data["created_at"],
            updated_at=session_data["updated_at"],
            message_count=len(messages),
            context=session_data["context"],
        )

    async def list_user_sessions(
        self, user_id: str, limit: int = 10, offset: int = 0
    ) -> List[SessionResponse]:
        """List sessions for a user with pagination."""
        sessions_data = self.session_manager.get_user_sessions(user_id, limit, offset)

        sessions = []
        for session_data in sessions_data:
            messages = [
                ClaudeMessage(**msg_data) for msg_data in session_data["messages"]
            ]

            sessions.append(
                SessionResponse(
                    session_id=session_data["session_id"],
                    user_id=session_data["user_id"],
                    session_name=session_data["session_name"],
                    status=session_data["status"],
                    messages=messages,
                    created_at=session_data["created_at"],
                    updated_at=session_data["updated_at"],
                    message_count=len(messages),
                    context=session_data["context"],
                )
            )

        return sessions
