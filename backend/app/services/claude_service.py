"""
Claude Code SDK service with simplified session management.

Uses Claude SDK's native session management with working directories as project roots,
eliminating complex path computation and aligning with Claude CLI behavior.
"""

import uuid
import asyncio
import os
from pathlib import Path
from datetime import datetime
from typing import Optional, AsyncGenerator, List

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

# Structured logging
from app.utils.logging import StructuredLogger, log_session_event, log_claude_sdk_event


class ClaudeService:
    """
    Simplified Claude Code SDK service using native session management.

    Each working directory becomes its own Claude project root, allowing
    natural session persistence and working directory isolation.
    """

    def __init__(self, project_root: Path, session_registry: dict = None):
        self.project_root = project_root
        self.logger = StructuredLogger(__name__)

        # Use shared session registry from application state if provided,
        # otherwise create a local one (for backwards compatibility)
        self.active_sessions = session_registry if session_registry is not None else {}

        self.logger.info(
            "Claude service initialized with simplified session management",
            category="session_management",
            operation="init",
            project_root=str(project_root),
            registry_type="shared" if session_registry is not None else "local"
        )

    async def create_session(self, request: SessionRequest) -> SessionResponse:
        """Create a new Claude Code session with working directory as project root."""

        # Use specified working directory or default to project root
        working_dir = getattr(request, "working_directory", None) or str(self.project_root)

        # Expand user home directory (~) if present
        if working_dir and working_dir.startswith("~"):
            working_dir = str(Path(working_dir).expanduser())

        # Validate that the working directory exists
        if working_dir and not Path(working_dir).exists():
            raise ValueError(f"Working directory does not exist: {working_dir}")

        try:
            # Create Claude SDK session with specified working directory
            # Claude SDK will automatically create sessions in ~/.claude/projects/[working_dir_hash]
            self.logger.info(
                f"Creating Claude SDK session with working directory: {working_dir}",
                category="session_management",
                operation="create_session",
                working_directory=working_dir
            )

            response = query(
                prompt="Session initialized",
                options=ClaudeCodeOptions(
                    cwd=working_dir,
                    permission_mode="bypassPermissions"
                ),
            )

            # Extract the actual Claude SDK session ID
            claude_session_id = await self._extract_session_id(response)

            # Store session in registry for tracking
            session_response = SessionResponse(
                session_id=claude_session_id,
                user_id=request.user_id,
                session_name=getattr(request, "session_name", None) or f"Session {claude_session_id[:8]}",
                status=SessionStatus.ACTIVE,
                messages=[],
                created_at=datetime.utcnow(),
                updated_at=datetime.utcnow(),
                message_count=0,
                context={"working_directory": working_dir},
            )

            # Register session in memory for listing and validation
            self.active_sessions[claude_session_id] = {
                "user_id": request.user_id,
                "session_response": session_response,
                "working_directory": working_dir,
                "created_at": datetime.utcnow(),
            }

            self.logger.info(
                "Session created successfully and registered",
                category="session_management",
                session_id=claude_session_id,
                user_id=request.user_id,
                operation="create_session",
                working_directory=working_dir
            )

            return session_response

        except Exception as e:
            self.logger.error(
                f"Session creation failed: {e}",
                category="session_management",
                user_id=request.user_id,
                operation="create_session",
                working_directory=working_dir,
                error=str(e)
            )
            raise RuntimeError(f"Failed to create session: {e}")

    async def _extract_session_id(self, response) -> str:
        """Extract Claude SDK session ID from response.

        The session ID is available in the first SystemMessage with subtype 'init'
        in the data field as 'session_id'.
        """
        try:
            session_id = None

            async for message in response:
                # Check for SystemMessage with init subtype containing session ID
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
                    break

            if not session_id:
                raise RuntimeError("Failed to extract session ID from Claude SDK response - no init message found")

            return session_id

        except Exception as e:
            self.logger.error(
                f"Session ID extraction failed: {e}",
                category="session_management",
                operation="extract_session_id",
                error=str(e)
            )
            raise RuntimeError(f"Failed to extract session ID: {e}")

    async def query(
        self, request: ClaudeQueryRequest, options: RequestOptions
    ) -> ClaudeQueryResponse:
        """Send a query to Claude using session resumption with working directory."""

        try:
            start_time = datetime.utcnow()

            # Get working directory from session context (stored during creation)
            session_data = self.active_sessions.get(request.session_id)
            if not session_data:
                raise ValueError(f"Session {request.session_id} not found")

            working_dir = session_data["working_directory"]

            self.logger.info(
                f"Querying Claude SDK with session resumption",
                category="query_execution",
                session_id=request.session_id,
                user_id=request.user_id,
                working_directory=working_dir,
                operation="query"
            )

            # Create proper SDK options with session resumption and working directory
            sdk_options = ClaudeCodeOptions(
                cwd=working_dir,  # CRITICAL: Must specify working directory for session resumption
                model=options.model,
                resume=request.session_id,  # Claude SDK session resumption
                permission_mode="bypassPermissions",
            )

            # Send query to Claude SDK
            response = query(prompt=request.query, options=sdk_options)

            # Collect response content
            response_content = ""
            async for message in response:
                if hasattr(message, "content"):
                    for block in message.content:
                        if hasattr(block, "text"):
                            response_content += block.text

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
            self.logger.error(
                f"Query failed: {e}",
                category="query_execution",
                session_id=request.session_id,
                user_id=request.user_id,
                operation="query",
                error=str(e)
            )
            raise RuntimeError(f"Query failed for session {request.session_id}: {e}")

    async def stream_response(
        self, request: ClaudeQueryRequest, options: RequestOptions
    ) -> AsyncGenerator[StreamingChunk, None]:
        """Stream Claude's response using session resumption."""

        try:
            # Get working directory from session context (stored during creation)
            session_data = self.active_sessions.get(request.session_id)
            if not session_data:
                raise ValueError(f"Session {request.session_id} not found")

            working_dir = session_data["working_directory"]

            self.logger.info(
                f"Starting streaming response with session resumption",
                category="query_execution",
                session_id=request.session_id,
                user_id=request.user_id,
                working_directory=working_dir,
                operation="stream_response"
            )

            # Yield start chunk
            yield StreamingChunk(
                chunk_type=ChunkType.START,
                content=None,
                message_id=str(uuid.uuid4()),
                session_id=request.session_id,
            )

            # Create proper SDK options with session resumption and working directory
            sdk_options = ClaudeCodeOptions(
                cwd=working_dir,  # CRITICAL: Must specify working directory for session resumption
                model=options.model,
                resume=request.session_id,  # Claude SDK session resumption
                permission_mode="bypassPermissions",
            )

            # Send query to Claude SDK
            response = query(prompt=request.query, options=sdk_options)

            # Stream response chunks with mobile optimization
            async for message in response:
                if hasattr(message, "content"):
                    for block in message.content:
                        if hasattr(block, "text"):
                            chunk_text = block.text

                            yield StreamingChunk(
                                chunk_type=ChunkType.DELTA,
                                content=chunk_text,
                                message_id=str(uuid.uuid4()),
                                session_id=request.session_id,
                            )

                            # Mobile optimization - preserve existing pattern
                            await asyncio.sleep(0.01)

            # Yield completion chunk
            yield StreamingChunk(
                chunk_type=ChunkType.COMPLETE,
                content=None,
                message_id=str(uuid.uuid4()),
                session_id=request.session_id,
            )

        except Exception as e:
            self.logger.error(
                f"Streaming failed: {e}",
                category="query_execution",
                session_id=request.session_id,
                user_id=request.user_id,
                operation="stream_response",
                error=str(e)
            )

            # Yield error chunk
            yield StreamingChunk(
                chunk_type=ChunkType.ERROR,
                content=f"Streaming error: {str(e)}",
                message_id=str(uuid.uuid4()),
                session_id=request.session_id,
            )

    async def get_session(
        self, session_id: str, user_id: str
    ) -> Optional[SessionResponse]:
        """Get session details from in-memory registry."""

        try:
            # Check if session exists in our registry
            if session_id not in self.active_sessions:
                self.logger.debug(
                    "Session not found in registry",
                    category="session_management",
                    session_id=session_id,
                    user_id=user_id,
                    operation="get_session"
                )
                return None

            session_data = self.active_sessions[session_id]

            # Verify user access
            if session_data["user_id"] != user_id:
                self.logger.warning(
                    "Session access denied - user mismatch",
                    category="session_management",
                    session_id=session_id,
                    user_id=user_id,
                    session_user_id=session_data["user_id"],
                    operation="get_session"
                )
                return None

            self.logger.debug(
                "Session found and validated",
                category="session_management",
                session_id=session_id,
                user_id=user_id,
                operation="get_session"
            )

            return session_data["session_response"]

        except Exception as e:
            self.logger.error(
                f"Session lookup failed: {e}",
                category="session_management",
                session_id=session_id,
                user_id=user_id,
                operation="get_session",
                error=str(e)
            )
            return None

    async def list_user_sessions(
        self, user_id: str, limit: int = 10, offset: int = 0
    ) -> List[SessionResponse]:
        """List user sessions from in-memory registry."""

        try:
            # Filter sessions by user_id
            user_sessions = []
            for session_id, session_data in self.active_sessions.items():
                if session_data["user_id"] == user_id:
                    user_sessions.append(session_data["session_response"])

            # Sort by creation time (newest first)
            user_sessions.sort(key=lambda s: s.created_at, reverse=True)

            # Apply pagination
            paginated_sessions = user_sessions[offset:offset + limit]

            self.logger.debug(
                f"Found {len(user_sessions)} sessions for user, returning {len(paginated_sessions)}",
                category="session_management",
                user_id=user_id,
                total_sessions=len(user_sessions),
                returned_sessions=len(paginated_sessions),
                operation="list_user_sessions"
            )

            return paginated_sessions

        except Exception as e:
            self.logger.error(
                f"Session listing failed: {e}",
                category="session_management",
                user_id=user_id,
                operation="list_user_sessions",
                error=str(e)
            )
            return []