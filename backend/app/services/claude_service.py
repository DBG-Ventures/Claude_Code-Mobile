"""
Claude Code SDK service with simplified session management.

Uses Claude SDK's native session management with working directories as project roots,
eliminating complex path computation and aligning with Claude CLI behavior.
"""

import uuid
import asyncio
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

# Structured logging
from app.utils.logging import StructuredLogger
from app.utils.session_storage import PersistentSessionStorage
from app.services.session_manager import SessionManager


class ClaudeService:
    """
    Enhanced Claude Code SDK service with persistent ClaudeSDKClient management.

    Uses SessionManager for persistent client instances, eliminating session creation
    overhead and maintaining conversation context across queries.
    """

    def __init__(
        self,
        project_root: Path,
        session_storage: PersistentSessionStorage,
        session_manager: SessionManager,
    ):
        self.project_root = project_root
        self.session_storage = session_storage
        self.session_manager = session_manager
        self.logger = StructuredLogger(__name__)

        self.logger.info(
            "Claude service initialized with SessionManager integration",
            category="session_management",
            operation="init",
            project_root=str(project_root),
            storage_type="persistent",
            session_manager_enabled=True,
        )

    async def create_session(self, request: SessionRequest) -> SessionResponse:
        """Create a new Claude Code session using SessionManager for persistent clients."""

        # Use specified working directory or default to project root
        working_dir = getattr(request, "working_directory", None) or str(
            self.project_root
        )

        # Expand user home directory (~) if present
        if working_dir and working_dir.startswith("~"):
            working_dir = str(Path(working_dir).expanduser())

        # Validate that the working directory exists
        if working_dir and not Path(working_dir).exists():
            raise ValueError(f"Working directory does not exist: {working_dir}")

        try:
            self.logger.info(
                f"Creating Claude SDK session with SessionManager: {working_dir}",
                category="session_management",
                operation="create_session",
                working_directory=working_dir,
                user_id=request.user_id,
            )

            # Generate a temporary session ID - will be replaced by Claude SDK's ID
            temp_session_id = str(uuid.uuid4())

            # Create persistent client through SessionManager
            # The SessionManager will return the Claude SDK's actual session ID
            client = await self.session_manager.get_or_create_session(
                session_id=temp_session_id,
                working_dir=working_dir,
                user_id=request.user_id,
                is_new_session=True,
            )

            # Get the actual session ID that Claude SDK created
            actual_session_id = temp_session_id
            if hasattr(client, "session_id") and client.session_id:
                actual_session_id = client.session_id
            # Also check if SessionManager stored a different ID
            elif temp_session_id in self.session_manager.active_sessions:
                session_info = self.session_manager.active_sessions[temp_session_id]
                if "claude_session_id" in session_info:
                    actual_session_id = session_info["claude_session_id"]

            self.logger.info(
                "SessionManager created persistent client",
                category="session_management",
                operation="session_manager_create",
                session_id=actual_session_id,
                user_id=request.user_id,
                working_directory=working_dir,
            )

            # Store session metadata persistently for UI listing
            session_name = (
                getattr(request, "session_name", None)
                or f"Session {actual_session_id[:8]}"
            )
            self.session_storage.store_session(
                session_id=actual_session_id,
                user_id=request.user_id,
                working_directory=working_dir,
                session_name=session_name,
                created_at=datetime.utcnow(),
            )

            # Create session response
            session_response = SessionResponse(
                session_id=actual_session_id,
                user_id=request.user_id,
                session_name=session_name,
                status=SessionStatus.ACTIVE,
                messages=[],
                created_at=datetime.utcnow(),
                updated_at=datetime.utcnow(),
                message_count=0,
                context={"working_directory": working_dir},
            )

            self.logger.info(
                "Session created successfully with SessionManager",
                category="session_management",
                session_id=actual_session_id,
                user_id=request.user_id,
                operation="create_session_complete",
                working_directory=working_dir,
            )

            return session_response

        except Exception as e:
            self.logger.error(
                f"Session creation failed: {e}",
                category="session_management",
                user_id=request.user_id,
                operation="create_session_failed",
                working_directory=working_dir,
                error=str(e),
            )
            raise RuntimeError(f"Failed to create session: {e}")

    async def query(
        self, request: ClaudeQueryRequest, options: RequestOptions
    ) -> ClaudeQueryResponse:
        """Send a query to Claude using persistent SessionManager clients."""

        try:
            start_time = datetime.utcnow()

            # Get working directory from persistent session storage
            session_metadata = self.session_storage.get_session(request.session_id)
            if not session_metadata:
                raise ValueError(f"Session {request.session_id} not found")

            working_dir = session_metadata["working_directory"]

            self.logger.info(
                "Querying Claude SDK with SessionManager persistent client",
                category="query_execution",
                session_id=request.session_id,
                user_id=request.user_id,
                working_directory=working_dir,
                operation="query",
            )

            # Get persistent client from SessionManager with retry logic
            max_retries = 2
            client = None
            for attempt in range(max_retries):
                try:
                    client = await self.session_manager.get_or_create_session(
                        session_id=request.session_id,
                        working_dir=working_dir,
                        user_id=request.user_id,
                        is_new_session=False,
                    )
                    break  # Success
                except Exception as e:
                    if attempt < max_retries - 1:
                        self.logger.warning(
                            f"Query attempt {attempt + 1} failed, retrying: {e}",
                            category="query_execution",
                            session_id=request.session_id,
                            attempt=attempt + 1,
                        )
                        await asyncio.sleep(0.5 * (attempt + 1))
                    else:
                        raise

            # Send query to persistent client
            await client.query(request.query)

            # Collect response content
            response_content = ""
            async for message in client.receive_response():
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

            self.logger.info(
                "Query completed successfully with SessionManager",
                category="query_execution",
                session_id=request.session_id,
                user_id=request.user_id,
                operation="query_complete",
                processing_time=processing_time,
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
                operation="query_failed",
                error=str(e),
            )
            raise RuntimeError(f"Query failed for session {request.session_id}: {e}")

    async def stream_response(
        self, request: ClaudeQueryRequest, options: RequestOptions
    ) -> AsyncGenerator[StreamingChunk, None]:
        """Stream Claude's response using persistent SessionManager clients."""

        try:
            # Get working directory from persistent session storage
            session_metadata = self.session_storage.get_session(request.session_id)
            if not session_metadata:
                raise ValueError(f"Session {request.session_id} not found")

            working_dir = session_metadata["working_directory"]

            self.logger.info(
                "Starting streaming response with SessionManager persistent client",
                category="query_execution",
                session_id=request.session_id,
                user_id=request.user_id,
                working_directory=working_dir,
                operation="stream_response",
            )

            # Yield start chunk
            yield StreamingChunk(
                chunk_type=ChunkType.START,
                content=None,
                message_id=str(uuid.uuid4()),
                session_id=request.session_id,
            )

            # Get persistent client from SessionManager with retry logic
            max_retries = 2
            client = None
            for attempt in range(max_retries):
                try:
                    client = await self.session_manager.get_or_create_session(
                        session_id=request.session_id,
                        working_dir=working_dir,
                        user_id=request.user_id,
                        is_new_session=False,
                    )
                    break  # Success
                except Exception as e:
                    if attempt < max_retries - 1:
                        self.logger.warning(
                            f"Stream attempt {attempt + 1} failed, retrying: {e}",
                            category="query_execution",
                            session_id=request.session_id,
                            attempt=attempt + 1,
                        )
                        await asyncio.sleep(0.5 * (attempt + 1))
                    else:
                        raise RuntimeError(f"Failed to get session after {max_retries} attempts: {e}")

            # Send query to persistent client with error handling
            try:
                await client.query(request.query)
            except Exception as e:
                self.logger.error(
                    f"Failed to send query to Claude SDK: {e}",
                    category="query_execution",
                    session_id=request.session_id,
                    error=str(e),
                )
                raise RuntimeError(f"Query failed: {e}")

            # Stream response chunks with mobile optimization
            async for message in client.receive_response():
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

            self.logger.info(
                "Streaming response completed successfully with SessionManager",
                category="query_execution",
                session_id=request.session_id,
                user_id=request.user_id,
                operation="stream_response_complete",
            )

        except Exception as e:
            self.logger.error(
                f"Streaming failed: {e}",
                category="query_execution",
                session_id=request.session_id,
                user_id=request.user_id,
                operation="stream_response_failed",
                error=str(e),
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
        """Get session details from persistent storage."""

        try:
            # Get session from persistent storage
            session_metadata = self.session_storage.get_session(session_id)
            if not session_metadata:
                self.logger.debug(
                    "Session not found in storage",
                    category="session_management",
                    session_id=session_id,
                    user_id=user_id,
                    operation="get_session",
                )
                return None

            # Verify user access
            if session_metadata.get("user_id") != user_id:
                self.logger.warning(
                    "Session access denied - user mismatch",
                    category="session_management",
                    session_id=session_id,
                    user_id=user_id,
                    session_user_id=session_metadata.get("user_id"),
                    operation="get_session",
                )
                return None

            self.logger.debug(
                "Session found and validated",
                category="session_management",
                session_id=session_id,
                user_id=user_id,
                operation="get_session",
            )

            # Convert metadata to SessionResponse
            from datetime import datetime

            session_response = SessionResponse(
                session_id=session_id,
                user_id=user_id,
                session_name=session_metadata.get(
                    "session_name", f"Session {session_id[:8]}"
                ),
                status=SessionStatus.ACTIVE,
                messages=[],  # Messages are handled by Claude SDK
                created_at=datetime.fromisoformat(session_metadata.get("created_at")),
                updated_at=datetime.fromisoformat(
                    session_metadata.get(
                        "updated_at", session_metadata.get("created_at")
                    )
                ),
                message_count=0,  # Will be populated from Claude SDK if needed
                context={
                    "working_directory": session_metadata.get("working_directory")
                },
            )

            return session_response

        except Exception as e:
            self.logger.error(
                f"Session lookup failed: {e}",
                category="session_management",
                session_id=session_id,
                user_id=user_id,
                operation="get_session",
                error=str(e),
            )
            return None

    async def list_user_sessions(
        self, user_id: str, limit: int = 10, offset: int = 0
    ) -> List[SessionResponse]:
        """List user sessions from persistent storage."""

        try:
            # Get sessions from persistent storage
            session_metadata_list = self.session_storage.list_user_sessions(
                user_id, limit, offset
            )

            # Convert to SessionResponse objects
            session_responses = []
            for session_metadata in session_metadata_list:
                try:
                    from datetime import datetime

                    session_response = SessionResponse(
                        session_id=session_metadata.get("session_id"),
                        user_id=session_metadata.get("user_id"),
                        session_name=session_metadata.get(
                            "session_name",
                            f"Session {session_metadata.get('session_id', '')[:8]}",
                        ),
                        status=SessionStatus.ACTIVE,
                        messages=[],  # Messages are handled by Claude SDK
                        created_at=datetime.fromisoformat(
                            session_metadata.get("created_at")
                        ),
                        updated_at=datetime.fromisoformat(
                            session_metadata.get(
                                "updated_at", session_metadata.get("created_at")
                            )
                        ),
                        message_count=0,  # Will be populated from Claude SDK if needed
                        context={
                            "working_directory": session_metadata.get(
                                "working_directory"
                            )
                        },
                    )
                    session_responses.append(session_response)
                except Exception as e:
                    self.logger.warning(
                        f"Failed to convert session metadata to response: {e}",
                        category="session_management",
                        session_id=session_metadata.get("session_id"),
                        operation="list_user_sessions",
                    )

            self.logger.debug(
                f"Found {len(session_metadata_list)} sessions for user, returning {len(session_responses)}",
                category="session_management",
                user_id=user_id,
                total_sessions=len(session_metadata_list),
                returned_sessions=len(session_responses),
                operation="list_user_sessions",
            )

            return session_responses

        except Exception as e:
            self.logger.error(
                f"Session listing failed: {e}",
                category="session_management",
                user_id=user_id,
                operation="list_user_sessions",
                error=str(e),
            )
            return []

    async def delete_session(self, session_id: str, user_id: str) -> bool:
        """Delete a session from persistent storage and SessionManager."""
        try:
            # First verify the session exists and user has access
            session = await self.get_session(session_id, user_id)
            if not session:
                self.logger.warning(
                    "Session not found or access denied",
                    category="session_management",
                    session_id=session_id,
                    user_id=user_id,
                    operation="delete_session",
                )
                return False

            # Remove from SessionManager if it exists there
            if self.session_manager:
                await self.session_manager.cleanup_session(session_id)
                self.logger.info(
                    "Removed session from SessionManager",
                    category="session_management",
                    session_id=session_id,
                    operation="delete_from_session_manager",
                )

            # Remove from persistent storage
            self.session_storage.remove_session(session_id)

            self.logger.info(
                "Session deleted successfully",
                category="session_management",
                session_id=session_id,
                user_id=user_id,
                operation="delete_session",
            )
            return True

        except Exception as e:
            self.logger.error(
                f"Failed to delete session: {e}",
                category="session_management",
                session_id=session_id,
                user_id=user_id,
                operation="delete_session",
                error=str(e),
            )
            raise
