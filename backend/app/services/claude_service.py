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
        # Note: Claude Code SDK client constructor only accepts 'api_key' parameter
        # Other options like model, max_tokens, temperature, timeout are passed
        # to individual query methods, not the client constructor
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
        client = None

        try:
            print(f"🚀 Starting Claude streaming for session: {request.session_id}")
            print(f"🚀 Query: {request.query[:50]}...")
            print(f"🚀 SDK kwargs: {sdk_kwargs}")

            # Create client manually to avoid context manager exit issues
            from claude_code_sdk import ClaudeSDKClient
            client = ClaudeSDKClient(**sdk_kwargs)

            print(f"🚀 Claude client created successfully")
            # Connect to Claude Code SDK before using
            await client.connect()
            print(f"🚀 Claude client connected successfully")

            # Claude Code SDK streams automatically through receive_response()
            await client.query(request.query)
            print(f"🚀 Query sent to Claude, waiting for streaming response...")

            message_count = 0
            async for message in client.receive_response():
                message_count += 1
                print(f"🚀 Received message #{message_count}")
                print(f"🔍 Claude SDK message type: {type(message)}")

                # Extract content from ALL message types and determine chunk type
                chunk_content = None
                chunk_type = "delta"

                # Determine message type for UI indicators
                message_type_name = type(message).__name__.replace('Message', '')

                if hasattr(message, "content") and message.content:
                    print(f"🔍 Content blocks: {len(message.content)}")
                    for i, block in enumerate(message.content):
                        block_type = type(block).__name__
                        print(f"🔍 Block {i} type: {block_type}")

                        # Handle different block types
                        if hasattr(block, "text") and block.text.strip():
                            # TextBlock
                            chunk_content = block.text
                            full_response += chunk_content
                        elif hasattr(block, "name") and hasattr(block, "input"):
                            # ToolUseBlock
                            tool_name = block.name
                            tool_input = getattr(block, "input", {})
                            print(f"🔧 ToolUseBlock - name: {tool_name}, input: {tool_input}")
                            chunk_content = f"Using tool: {tool_name}"
                            if isinstance(tool_input, dict) and tool_input:
                                # Extract meaningful info from tool input
                                if "path" in tool_input:
                                    chunk_content += f" on {tool_input['path']}"
                                elif "pattern" in tool_input:
                                    chunk_content += f" searching for '{tool_input['pattern']}'"
                                elif "file_path" in tool_input:
                                    chunk_content += f" on {tool_input['file_path']}"
                                elif "command" in tool_input:
                                    cmd = tool_input['command']
                                    if len(cmd) > 50:
                                        chunk_content += f" command: {cmd[:50]}..."
                                    else:
                                        chunk_content += f" command: {cmd}"
                        elif hasattr(block, "content") and hasattr(block, "tool_use_id"):
                            # ToolResultBlock
                            tool_content = getattr(block, "content", "")
                            tool_use_id = getattr(block, "tool_use_id", "")
                            print(f"🛠️ ToolResultBlock - tool_use_id: {tool_use_id}, content type: {type(tool_content)}, content: {str(tool_content)[:100]}")
                            if isinstance(tool_content, str) and tool_content.strip():
                                # Truncate long tool results for UI
                                if len(tool_content) > 150:
                                    chunk_content = f"Tool result: {tool_content[:150]}..."
                                else:
                                    chunk_content = f"Tool result: {tool_content}"
                            elif isinstance(tool_content, (list, dict)):
                                # Handle structured tool results
                                chunk_content = f"Tool result: {str(tool_content)[:150]}..."

                        if chunk_content:
                            # Add message type prefix for visual distinction
                            if message_type_name == "Assistant":
                                if "tool" in chunk_content.lower():
                                    prefixed_content = f"🔧 {chunk_content}"
                                    chunk_type = "tool"
                                else:
                                    prefixed_content = f"🤖 {chunk_content}"
                                    chunk_type = "thinking" if "thinking" in chunk_content.lower() else "assistant"
                            elif message_type_name == "User":
                                prefixed_content = f"🛠️ {chunk_content}"
                                chunk_type = "tool"
                            else:
                                prefixed_content = f"📋 {chunk_content}"
                                chunk_type = "system"

                            print(f"🔍 Yielding {message_type_name} chunk: '{chunk_content[:50]}...'")

                            # Yield individual thinking step
                            yield StreamingChunk(
                                content=prefixed_content,
                                chunk_type=chunk_type,
                                message_id=f"{message_id}-{message_count}",
                                timestamp=datetime.utcnow(),
                            )
                            break  # Take first meaningful block

                # Check for other content patterns in different message types
                elif hasattr(message, "data") and message.data:
                    print(f"🔍 Message has data: {type(message.data)}")
                    if isinstance(message.data, str) and message.data.strip():
                        chunk_content = f"📊 {message.data}"
                        print(f"🔍 Yielding data chunk: '{message.data[:50]}...'")

                        yield StreamingChunk(
                            content=chunk_content,
                            chunk_type="system",
                            message_id=f"{message_id}-{message_count}",
                            timestamp=datetime.utcnow(),
                        )

                elif hasattr(message, "subtype"):
                    print(f"🔍 Message subtype: {message.subtype}")
                    # Log subtype for debugging but don't yield empty content

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
            print(f"❌ Claude streaming error: {type(e).__name__}: {str(e)}")
            import traceback
            print(f"❌ Full traceback: {traceback.format_exc()}")

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
        finally:
            # Properly close client if it exists
            if client:
                try:
                    await client.disconnect()
                except Exception as e:
                    print(f"⚠️ Error disconnecting Claude client: {e}")

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
