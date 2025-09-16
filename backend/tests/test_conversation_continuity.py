"""
End-to-end conversation continuity tests.

Tests full conversation flows with SessionManager, context preservation,
multi-session scenarios, and mobile streaming optimization.
"""

import pytest
import asyncio
import tempfile
import json
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch
from fastapi.testclient import TestClient

from app.main import app
from app.services.session_manager import SessionManager
from app.services.claude_service import ClaudeService
from app.utils.session_storage import PersistentSessionStorage
from app.models.requests import SessionRequest, ClaudeQueryRequest
from app.models.responses import ChunkType


class TestConversationContinuity:
    """Test end-to-end conversation continuity scenarios."""

    @pytest.fixture
    def mock_conversation_client(self):
        """Mock ClaudeSDKClient with conversation memory."""
        conversation_history = []

        class MockConversationClient:
            def __init__(self, options):
                self.options = options
                self.session_id = "conversation-session-123"
                self._session = MagicMock()  # Mock connected session
                self.conversation_history = conversation_history

            async def connect(self):
                pass

            async def disconnect(self):
                pass

            async def query(self, prompt):
                # Store user message
                self.conversation_history.append({"role": "user", "content": prompt})

                # Generate contextual response based on history
                if "favorite color" in prompt.lower():
                    for msg in reversed(self.conversation_history):
                        if msg["role"] == "user" and "blue" in msg["content"].lower():
                            self.conversation_history.append({
                                "role": "assistant",
                                "content": "I remember you mentioned that your favorite color is blue."
                            })
                            return

                self.conversation_history.append({
                    "role": "assistant",
                    "content": f"I understand your message: {prompt}"
                })

            async def receive_response(self):
                # Return the last assistant message
                for msg in reversed(self.conversation_history):
                    if msg["role"] == "assistant":
                        yield MockMessage(msg["content"])
                        break

        class MockMessage:
            def __init__(self, text):
                self.content = [MockBlock(text)]

        class MockBlock:
            def __init__(self, text):
                self.text = text

        return MockConversationClient

    @pytest.fixture
    def temp_app_setup(self):
        """Set up temporary app state for testing."""
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_root = Path(temp_dir)

            # Create session storage
            storage_file = temp_root / "test_sessions.json"
            session_storage = PersistentSessionStorage(storage_file)

            # Create SessionManager
            session_manager = SessionManager()

            # Set up app state
            app.state.project_root = temp_root
            app.state.session_storage = session_storage
            app.state.session_manager = session_manager

            yield {
                "project_root": temp_root,
                "session_storage": session_storage,
                "session_manager": session_manager
            }

            # Cleanup
            asyncio.create_task(session_manager.shutdown())

    @pytest.mark.asyncio
    async def test_simple_conversation_flow(self, temp_app_setup, mock_conversation_client):
        """Test a simple conversation flow with context preservation."""
        # Arrange
        session_manager = temp_app_setup["session_manager"]
        session_storage = temp_app_setup["session_storage"]
        project_root = temp_app_setup["project_root"]

        claude_service = ClaudeService(project_root, session_storage, session_manager)

        with patch('app.services.session_manager.ClaudeSDKClient', mock_conversation_client):
            # Create session
            request = SessionRequest(
                user_id="conversation-user",
                session_name="Simple Conversation",
                working_directory=str(project_root)
            )

            session_response = await claude_service.create_session(request)
            session_id = session_response.session_id

            # First message - establish context
            query1 = ClaudeQueryRequest(
                session_id=session_id,
                query="My favorite color is blue",
                user_id="conversation-user"
            )

            chunks1 = []
            async for chunk in claude_service.stream_response(query1, None):
                chunks1.append(chunk)

            # Verify we got a response
            assert len(chunks1) >= 3  # START, DELTA, COMPLETE
            assert any(chunk.chunk_type == ChunkType.DELTA for chunk in chunks1)

            # Second message - test context recall
            query2 = ClaudeQueryRequest(
                session_id=session_id,
                query="What is my favorite color?",
                user_id="conversation-user"
            )

            chunks2 = []
            async for chunk in claude_service.stream_response(query2, None):
                chunks2.append(chunk)

            # Verify context was maintained
            assert len(chunks2) >= 3

            # Check that the response contains reference to blue
            response_text = "".join(
                chunk.content for chunk in chunks2
                if chunk.chunk_type == ChunkType.DELTA and chunk.content
            )
            assert "blue" in response_text.lower()

    @pytest.mark.asyncio
    async def test_multi_session_isolation(self, temp_app_setup, mock_conversation_client):
        """Test that multiple sessions maintain isolated contexts."""
        # Arrange
        session_manager = temp_app_setup["session_manager"]
        session_storage = temp_app_setup["session_storage"]
        project_root = temp_app_setup["project_root"]

        claude_service = ClaudeService(project_root, session_storage, session_manager)

        # Create conversation histories for each mock client
        conversation_histories = [{}, {}]

        def create_isolated_client(options):
            # Determine which client this is based on resume parameter
            client_index = 0 if options.resume is None else 1

            class IsolatedClient:
                def __init__(self):
                    self.options = options
                    self.session_id = f"isolated-session-{client_index}"
                    self._session = MagicMock()
                    self.history = conversation_histories[client_index]

                async def connect(self):
                    pass

                async def disconnect(self):
                    pass

                async def query(self, prompt):
                    if "history" not in self.history:
                        self.history["history"] = []

                    self.history["history"].append({"role": "user", "content": prompt})

                    # Generate response based on this client's history only
                    if "favorite" in prompt.lower():
                        for msg in self.history["history"]:
                            if "red" in msg["content"].lower():
                                response = "I remember you mentioned red."
                                break
                            elif "green" in msg["content"].lower():
                                response = "I remember you mentioned green."
                                break
                        else:
                            response = "I don't recall you mentioning a favorite color."
                    else:
                        response = f"Client {client_index}: {prompt}"

                    self.history["history"].append({"role": "assistant", "content": response})

                async def receive_response(self):
                    if "history" in self.history and self.history["history"]:
                        last_msg = self.history["history"][-1]
                        if last_msg["role"] == "assistant":
                            yield MockMessage(last_msg["content"])

            return IsolatedClient()

        class MockMessage:
            def __init__(self, text):
                self.content = [MockBlock(text)]

        class MockBlock:
            def __init__(self, text):
                self.text = text

        with patch('app.services.session_manager.ClaudeSDKClient', create_isolated_client):
            # Create two sessions
            session1_request = SessionRequest(
                user_id="user1",
                session_name="Session 1",
                working_directory=str(project_root)
            )

            session2_request = SessionRequest(
                user_id="user2",
                session_name="Session 2",
                working_directory=str(project_root)
            )

            session1 = await claude_service.create_session(session1_request)
            session2 = await claude_service.create_session(session2_request)

            # Establish different contexts in each session
            query1_1 = ClaudeQueryRequest(
                session_id=session1.session_id,
                query="My favorite color is red",
                user_id="user1"
            )

            query2_1 = ClaudeQueryRequest(
                session_id=session2.session_id,
                query="My favorite color is green",
                user_id="user2"
            )

            # Send initial context messages
            async for _ in claude_service.stream_response(query1_1, None):
                pass

            async for _ in claude_service.stream_response(query2_1, None):
                pass

            # Test context recall in each session
            query1_2 = ClaudeQueryRequest(
                session_id=session1.session_id,
                query="What is my favorite color?",
                user_id="user1"
            )

            query2_2 = ClaudeQueryRequest(
                session_id=session2.session_id,
                query="What is my favorite color?",
                user_id="user2"
            )

            # Collect responses
            response1_chunks = []
            async for chunk in claude_service.stream_response(query1_2, None):
                response1_chunks.append(chunk)

            response2_chunks = []
            async for chunk in claude_service.stream_response(query2_2, None):
                response2_chunks.append(chunk)

            # Verify isolation
            response1_text = "".join(
                chunk.content for chunk in response1_chunks
                if chunk.chunk_type == ChunkType.DELTA and chunk.content
            )

            response2_text = "".join(
                chunk.content for chunk in response2_chunks
                if chunk.chunk_type == ChunkType.DELTA and chunk.content
            )

            # Each session should remember its own color, not the other's
            assert "red" in response1_text.lower()
            assert "green" not in response1_text.lower()

            assert "green" in response2_text.lower()
            assert "red" not in response2_text.lower()

    @pytest.mark.asyncio
    async def test_conversation_continuity_across_restart(self, temp_app_setup, mock_conversation_client):
        """Test conversation continuity across SessionManager restart."""
        # Arrange
        project_root = temp_app_setup["project_root"]
        session_storage = temp_app_setup["session_storage"]

        # Create initial SessionManager and service
        session_manager1 = SessionManager()
        claude_service1 = ClaudeService(project_root, session_storage, session_manager1)

        # Store conversation state globally to simulate persistence
        global_conversation_state = {"history": []}

        def create_persistent_client(options):
            class PersistentClient:
                def __init__(self):
                    self.options = options
                    self.session_id = "persistent-session-123"
                    self._session = MagicMock()
                    self.state = global_conversation_state

                async def connect(self):
                    pass

                async def disconnect(self):
                    pass

                async def query(self, prompt):
                    self.state["history"].append({"role": "user", "content": prompt})

                    if "favorite animal" in prompt.lower():
                        for msg in self.state["history"]:
                            if "cat" in msg["content"].lower():
                                response = "I remember you said your favorite animal is a cat."
                                break
                        else:
                            response = "I don't recall your favorite animal."
                    else:
                        response = f"Understood: {prompt}"

                    self.state["history"].append({"role": "assistant", "content": response})

                async def receive_response(self):
                    if self.state["history"]:
                        last_msg = self.state["history"][-1]
                        if last_msg["role"] == "assistant":
                            yield MockMessage(last_msg["content"])

            return PersistentClient()

        class MockMessage:
            def __init__(self, text):
                self.content = [MockBlock(text)]

        class MockBlock:
            def __init__(self, text):
                self.text = text

        with patch('app.services.session_manager.ClaudeSDKClient', create_persistent_client):
            # Create session and establish context
            request = SessionRequest(
                user_id="restart-user",
                session_name="Restart Test Session",
                working_directory=str(project_root)
            )

            session_response1 = await claude_service1.create_session(request)
            session_id = session_response1.session_id

            # Establish context
            context_query = ClaudeQueryRequest(
                session_id=session_id,
                query="My favorite animal is a cat",
                user_id="restart-user"
            )

            async for _ in claude_service1.stream_response(context_query, None):
                pass

            # Shutdown first SessionManager
            await session_manager1.shutdown()

        # Create new SessionManager (simulating restart)
        session_manager2 = SessionManager()
        claude_service2 = ClaudeService(project_root, session_storage, session_manager2)

        with patch('app.services.session_manager.ClaudeSDKClient', create_persistent_client):
            # Test context recall after restart
            recall_query = ClaudeQueryRequest(
                session_id=session_id,
                query="What is my favorite animal?",
                user_id="restart-user"
            )

            chunks = []
            async for chunk in claude_service2.stream_response(recall_query, None):
                chunks.append(chunk)

            # Verify context was preserved across restart
            response_text = "".join(
                chunk.content for chunk in chunks
                if chunk.chunk_type == ChunkType.DELTA and chunk.content
            )

            assert "cat" in response_text.lower()

        # Cleanup
        await session_manager2.shutdown()

    def test_api_conversation_flow_integration(self, temp_app_setup):
        """Test conversation flow through API endpoints."""
        # Arrange
        with TestClient(app) as client:
            # Mock ClaudeSDKClient for API testing
            conversation_state = {"messages": []}

            def create_api_client(options):
                class APIClient:
                    def __init__(self):
                        self.options = options
                        self.session_id = "api-session-123"
                        self._session = MagicMock()

                    async def connect(self):
                        pass

                    async def disconnect(self):
                        pass

                    async def query(self, prompt):
                        conversation_state["messages"].append({"user": prompt})

                        if "name is john" in prompt.lower():
                            response = "Nice to meet you, John!"
                        elif "my name" in prompt.lower():
                            for msg in conversation_state["messages"]:
                                if "john" in msg.get("user", "").lower():
                                    response = "Your name is John."
                                    break
                            else:
                                response = "I don't know your name."
                        else:
                            response = f"I heard: {prompt}"

                        conversation_state["messages"].append({"assistant": response})

                    async def receive_response(self):
                        if conversation_state["messages"]:
                            last_msg = conversation_state["messages"][-1]
                            if "assistant" in last_msg:
                                yield MockMessage(last_msg["assistant"])

                return APIClient()

            class MockMessage:
                def __init__(self, text):
                    self.content = [MockBlock(text)]

            class MockBlock:
                def __init__(self, text):
                    self.text = text

            with patch('app.services.session_manager.ClaudeSDKClient', create_api_client):
                # Create session via API
                session_response = client.post("/claude/sessions", json={
                    "user_id": "api-user",
                    "session_name": "API Test Session"
                })

                assert session_response.status_code == 200
                session_data = session_response.json()
                session_id = session_data["session_id"]

                # Establish context via streaming API
                context_response = client.post("/claude/stream", json={
                    "session_id": session_id,
                    "query": "My name is John",
                    "user_id": "api-user"
                })

                assert context_response.status_code == 200

                # Test context recall
                recall_response = client.post("/claude/stream", json={
                    "session_id": session_id,
                    "query": "What is my name?",
                    "user_id": "api-user"
                })

                assert recall_response.status_code == 200

                # Note: In a full test, we would parse SSE stream
                # For now, just verify the request was accepted

    @pytest.mark.asyncio
    async def test_mobile_streaming_optimization(self, temp_app_setup, mock_conversation_client):
        """Test that mobile streaming optimization is preserved."""
        # Arrange
        session_manager = temp_app_setup["session_manager"]
        session_storage = temp_app_setup["session_storage"]
        project_root = temp_app_setup["project_root"]

        claude_service = ClaudeService(project_root, session_storage, session_manager)

        # Mock client that yields multiple chunks
        def create_streaming_client(options):
            class StreamingClient:
                def __init__(self):
                    self.options = options
                    self.session_id = "streaming-session"
                    self._session = MagicMock()

                async def connect(self):
                    pass

                async def disconnect(self):
                    pass

                async def query(self, prompt):
                    pass

                async def receive_response(self):
                    # Yield multiple chunks to test streaming
                    chunks = ["This ", "is ", "a ", "streaming ", "response."]
                    for chunk in chunks:
                        yield MockMessage(chunk)

            return StreamingClient()

        class MockMessage:
            def __init__(self, text):
                self.content = [MockBlock(text)]

        class MockBlock:
            def __init__(self, text):
                self.text = text

        with patch('app.services.session_manager.ClaudeSDKClient', create_streaming_client):
            # Create session
            request = SessionRequest(
                user_id="streaming-user",
                session_name="Streaming Test",
                working_directory=str(project_root)
            )

            session_response = await claude_service.create_session(request)

            # Test streaming with timing
            import time
            start_time = time.time()

            query = ClaudeQueryRequest(
                session_id=session_response.session_id,
                query="Test streaming response",
                user_id="streaming-user"
            )

            chunks = []
            chunk_times = []

            async for chunk in claude_service.stream_response(query, None):
                chunks.append(chunk)
                chunk_times.append(time.time() - start_time)

            # Verify we got multiple chunks
            delta_chunks = [c for c in chunks if c.chunk_type == ChunkType.DELTA]
            assert len(delta_chunks) >= 5  # Multiple content chunks

            # Verify mobile optimization delays (should be at least 0.01s between chunks)
            if len(chunk_times) > 2:
                # Time between chunks should show delays
                time_diffs = [chunk_times[i+1] - chunk_times[i] for i in range(len(chunk_times)-1)]
                # Should have some measurable delays (accounting for test timing variance)
                assert any(diff >= 0.005 for diff in time_diffs)  # At least 5ms delays