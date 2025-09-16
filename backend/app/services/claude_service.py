"""
Claude Code SDK service with direct session management and working directory consistency.

Eliminates unnecessary session mapping layer and uses Claude SDK session IDs directly
for reliable session persistence across FastAPI worker restarts and Docker deployments.
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


class ClaudeService:
    """
    Service for interacting with Claude Code SDK with direct session usage.

    Eliminates session mapping layer and uses Claude SDK session IDs directly
    for reliable session persistence with consistent working directory management.
    """

    def __init__(self, project_root: Path):
        self.project_root = project_root
        self._ensure_working_directory()

    def _ensure_working_directory(self):
        """Ensure working directory is set correctly before Claude SDK operations."""
        current_cwd = Path.cwd()
        if current_cwd != self.project_root:
            print(
                f"⚠️  Working directory mismatch: {current_cwd} != {self.project_root}"
            )
            os.chdir(self.project_root)
            print(f"✅ Working directory corrected to: {self.project_root}")

    async def create_session(self, request: SessionRequest) -> SessionResponse:
        """Create a new Claude Code session using direct SDK integration."""
        # Ensure working directory consistency
        self._ensure_working_directory()

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
            # Initialize Claude SDK session with explicit working directory
            response = query(
                prompt="Session initialized",
                options=ClaudeCodeOptions(
                    cwd=working_dir, permission_mode="bypassPermissions"
                ),
            )

            # Extract Claude SDK session ID directly
            claude_session_id = await self._extract_session_id(response)

            return SessionResponse(
                session_id=claude_session_id,  # Use Claude SDK session ID directly
                user_id=request.user_id,
                session_name=request.session_name or f"Session {claude_session_id[:8]}",
                status=SessionStatus.ACTIVE,
                messages=[],
                created_at=datetime.utcnow(),
                updated_at=datetime.utcnow(),
                message_count=0,
                context=getattr(request, "context", {}),
            )

        except Exception as e:
            raise RuntimeError(f"Failed to create Claude session: {e}")

    async def query(
        self, request: ClaudeQueryRequest, options: RequestOptions
    ) -> ClaudeQueryResponse:
        """
        Send a query to Claude using direct SDK session resumption.

        Uses Claude SDK session ID directly without mapping layer.
        """
        # Ensure working directory consistency
        self._ensure_working_directory()

        try:
            start_time = datetime.utcnow()

            # Create proper SDK options object with direct session resumption
            sdk_options = ClaudeCodeOptions(
                cwd=str(self.project_root),
                model=options.model,  # Use default model if None
                resume=request.session_id,  # Direct Claude SDK session ID
                permission_mode="bypassPermissions",  # Allow all tools for mobile use
            )

            # Send query to Claude SDK
            response = query(prompt=request.query, options=sdk_options)

            # Collect response content
            response_content = ""

            async for message in response:
                # Extract text content
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
            raise RuntimeError(f"Query failed for session {request.session_id}: {e}")

    async def stream_response(
        self, request: ClaudeQueryRequest, options: RequestOptions
    ) -> AsyncGenerator[StreamingChunk, None]:
        """
        Stream Claude's response using direct SDK session resumption with mobile optimization.

        Preserves 0.01s delays for mobile optimization as specified in PRP.
        """
        # Ensure working directory consistency
        self._ensure_working_directory()

        try:
            # Yield start chunk
            yield StreamingChunk(
                chunk_type=ChunkType.START,
                content=None,
                message_id=str(uuid.uuid4()),
                session_id=request.session_id,
            )

            # Create proper SDK options object with direct session resumption
            sdk_options = ClaudeCodeOptions(
                cwd=str(self.project_root),
                model=options.model,  # Use default model if None
                resume=request.session_id,  # Direct Claude SDK session ID
                permission_mode="bypassPermissions",  # Allow all tools for mobile use
            )

            # Send query to Claude SDK
            response = query(prompt=request.query, options=sdk_options)

            # Stream response chunks with mobile optimization
            async for message in response:
                # Extract and yield text content
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
            # Yield error chunk
            yield StreamingChunk(
                chunk_type=ChunkType.ERROR,
                content=None,
                error=str(e),
                message_id=str(uuid.uuid4()),
                session_id=request.session_id,
            )
            raise e

    async def _extract_session_id(self, response) -> str:
        """Extract Claude SDK session ID from response stream."""
        session_id = None

        async for message in response:
            if hasattr(message, "subtype") and message.subtype == "init":
                if hasattr(message, "data") and "session_id" in message.data:
                    session_id = message.data["session_id"]
                    break
            elif hasattr(message, "system_message") and hasattr(
                message.system_message, "session_id"
            ):
                session_id = message.system_message.session_id
                break

        if not session_id:
            raise RuntimeError("Failed to extract session ID from Claude SDK response")

        return session_id

    async def verify_session_exists(self, session_id: str) -> bool:
        """Verify if a Claude SDK session exists by checking file system."""
        # Use the actual Claude session directory structure
        sessions_path = (
            Path.home()
            / ".claude"
            / "projects"
            / f"--{str(self.project_root).replace('/', '-')}"
        )
        session_file = sessions_path / f"{session_id}.jsonl"

        # Debug logging
        logger.debug(f"🔍 Session validation - Looking for session file: {session_file}")
        logger.debug(f"🔍 Session file exists: {session_file.exists()}")

        return session_file.exists()

    async def list_sessions(self) -> List[str]:
        """List available Claude SDK session IDs from file system."""
        sessions_path = (
            Path.home()
            / ".claude"
            / "projects"
            / f"--{str(self.project_root).replace('/', '-')}"
        )

        if not sessions_path.exists():
            return []

        session_files = list(sessions_path.glob("*.jsonl"))
        return [f.stem for f in session_files]

    async def get_session(
        self, session_id: str, user_id: str
    ) -> Optional[SessionResponse]:
        """Get session details by verifying existence in Claude SDK storage."""
        if await self.verify_session_exists(session_id):
            return SessionResponse(
                session_id=session_id,
                user_id=user_id,
                session_name=f"Session {session_id[:8]}",
                status=SessionStatus.ACTIVE,
                messages=[],  # Messages are handled by Claude SDK file storage
                created_at=datetime.utcnow(),  # Could be read from file metadata
                updated_at=datetime.utcnow(),
                message_count=0,  # Could be calculated from file content
                context={},
            )
        return None

    async def list_user_sessions(
        self, user_id: str, limit: int = 10, offset: int = 0
    ) -> List[SessionResponse]:
        """List sessions from Claude SDK storage with pagination."""
        all_session_ids = await self.list_sessions()

        # Apply pagination
        paginated_session_ids = all_session_ids[offset : offset + limit]

        sessions = []
        for session_id in paginated_session_ids:
            session = await self.get_session(session_id, user_id)
            if session:
                sessions.append(session)

        return sessions
