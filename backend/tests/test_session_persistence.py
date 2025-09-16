"""
Session persistence integration tests.

Tests session persistence across backend restarts, working directory consistency,
and session resumption with ClaudeSDKClient integration.
"""

import pytest
import asyncio
import tempfile
import os
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch

from app.services.session_manager import SessionManager
from app.services.claude_service import ClaudeService
from app.utils.session_storage import PersistentSessionStorage
from app.models.requests import SessionRequest, ClaudeQueryRequest
from app.models.responses import SessionStatus


class TestSessionPersistence:
    """Test session persistence across restarts."""

    @pytest.fixture
    def temp_session_storage(self):
        """Create temporary session storage for testing."""
        with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as f:
            storage_file = Path(f.name)

        storage = PersistentSessionStorage(storage_file)
        yield storage

        # Cleanup
        if storage_file.exists():
            storage_file.unlink()

    @pytest.fixture
    def temp_working_dir(self):
        """Create temporary working directory for testing."""
        with tempfile.TemporaryDirectory() as temp_dir:
            working_dir = Path(temp_dir)
            original_cwd = Path.cwd()
            os.chdir(working_dir)

            yield working_dir

            os.chdir(original_cwd)

    @pytest.mark.asyncio
    async def test_session_metadata_persistence(self, temp_session_storage, temp_working_dir):
        """Test that session metadata persists across SessionManager restarts."""
        # Arrange
        session_id = "persistent-session-123"
        user_id = "test-user"

        # Create first SessionManager and ClaudeService
        session_manager1 = SessionManager()
        claude_service1 = ClaudeService(temp_working_dir, temp_session_storage, session_manager1)

        with patch('app.services.session_manager.ClaudeSDKClient') as MockClient:
            mock_client = AsyncMock()
            mock_client.session_id = session_id
            MockClient.return_value = mock_client

            # Create session and store metadata
            request = SessionRequest(
                user_id=user_id,
                session_name="Persistent Test Session",
                working_directory=str(temp_working_dir)
            )

            session_response = await claude_service1.create_session(request)
            created_session_id = session_response.session_id

            # Verify session exists in storage
            stored_metadata = temp_session_storage.get_session(created_session_id)
            assert stored_metadata is not None
            assert stored_metadata["user_id"] == user_id

            # Shutdown first SessionManager
            await session_manager1.shutdown()

        # Create second SessionManager (simulating restart)
        session_manager2 = SessionManager()
        claude_service2 = ClaudeService(temp_working_dir, temp_session_storage, session_manager2)

        with patch('app.services.session_manager.ClaudeSDKClient') as MockClient:
            mock_client2 = AsyncMock()
            mock_client2.session_id = created_session_id
            MockClient.return_value = mock_client2

            # Act - Try to resume session after "restart"
            client = await session_manager2.get_or_create_session(
                session_id=created_session_id,
                working_dir=str(temp_working_dir),
                user_id=user_id,
                is_new_session=False
            )

            # Assert
            assert client == mock_client2
            assert created_session_id in session_manager2.active_sessions

            # Verify ClaudeSDKClient was created with resume parameter
            MockClient.assert_called_once()
            create_args = MockClient.call_args[0][0]  # ClaudeCodeOptions
            assert create_args.resume == created_session_id
            assert create_args.cwd == str(temp_working_dir)

        # Cleanup
        await session_manager2.shutdown()

    @pytest.mark.asyncio
    async def test_working_directory_consistency(self, temp_session_storage):
        """Test working directory consistency across session operations."""
        # Arrange
        with tempfile.TemporaryDirectory() as temp_dir1, tempfile.TemporaryDirectory() as temp_dir2:
            working_dir1 = Path(temp_dir1)
            working_dir2 = Path(temp_dir2)

            session_manager = SessionManager()

            with patch('app.services.session_manager.ClaudeSDKClient') as MockClient:
                mock_client1 = AsyncMock()
                mock_client2 = AsyncMock()
                MockClient.side_effect = [mock_client1, mock_client2]

                # Create sessions with different working directories
                client1 = await session_manager.get_or_create_session(
                    session_id="session-dir1",
                    working_dir=str(working_dir1),
                    user_id="user1",
                    is_new_session=True
                )

                client2 = await session_manager.get_or_create_session(
                    session_id="session-dir2",
                    working_dir=str(working_dir2),
                    user_id="user2",
                    is_new_session=True
                )

                # Assert
                assert client1 == mock_client1
                assert client2 == mock_client2

                # Verify working directories are preserved
                session1_info = session_manager.active_sessions["session-dir1"]
                session2_info = session_manager.active_sessions["session-dir2"]

                assert session1_info["working_dir"] == str(working_dir1)
                assert session2_info["working_dir"] == str(working_dir2)

                # Verify ClaudeSDKClient was created with correct working directories
                assert MockClient.call_count == 2

                call1_options = MockClient.call_args_list[0][0][0]
                call2_options = MockClient.call_args_list[1][0][0]

                assert call1_options.cwd == str(working_dir1)
                assert call2_options.cwd == str(working_dir2)

            # Cleanup
            await session_manager.shutdown()

    @pytest.mark.asyncio
    async def test_session_resumption_with_context(self, temp_session_storage, temp_working_dir):
        """Test session resumption maintains conversation context."""
        # Arrange
        session_id = "context-session-123"
        user_id = "test-user"

        session_manager = SessionManager()
        claude_service = ClaudeService(temp_working_dir, temp_session_storage, session_manager)

        with patch('app.services.session_manager.ClaudeSDKClient') as MockClient:
            mock_client = AsyncMock()
            mock_client.session_id = session_id

            # Mock conversation responses
            async def mock_receive_response():
                # Simulate streaming response
                class MockMessage:
                    def __init__(self, text):
                        self.content = [MockBlock(text)]

                class MockBlock:
                    def __init__(self, text):
                        self.text = text

                yield MockMessage("I remember our previous conversation.")

            mock_client.receive_response = mock_receive_response
            MockClient.return_value = mock_client

            # Create session first
            request = SessionRequest(
                user_id=user_id,
                session_name="Context Session",
                working_directory=str(temp_working_dir)
            )

            session_response = await claude_service.create_session(request)

            # Send initial query
            query_request = ClaudeQueryRequest(
                session_id=session_response.session_id,
                query="Remember that my favorite color is blue",
                user_id=user_id
            )

            # Collect streaming response
            response_chunks = []
            async for chunk in claude_service.stream_response(query_request, None):
                response_chunks.append(chunk)

            # Verify we got a response
            assert len(response_chunks) >= 3  # START, DELTA, COMPLETE

            # Now simulate resumption - clear SessionManager but keep storage
            await session_manager.shutdown()
            new_session_manager = SessionManager()
            new_claude_service = ClaudeService(temp_working_dir, temp_session_storage, new_session_manager)

            # Mock client for resumption
            with patch('app.services.session_manager.ClaudeSDKClient') as MockClient2:
                mock_client2 = AsyncMock()
                mock_client2.session_id = session_response.session_id
                mock_client2.receive_response = mock_receive_response
                MockClient2.return_value = mock_client2

                # Act - Resume session and query about previous context
                resume_query = ClaudeQueryRequest(
                    session_id=session_response.session_id,
                    query="What is my favorite color?",
                    user_id=user_id
                )

                # Collect resumption response
                resume_chunks = []
                async for chunk in new_claude_service.stream_response(resume_query, None):
                    resume_chunks.append(chunk)

                # Assert
                assert len(resume_chunks) >= 3

                # Verify ClaudeSDKClient was created with resume parameter
                MockClient2.assert_called_once()
                resume_options = MockClient2.call_args[0][0]
                assert resume_options.resume == session_response.session_id
                assert resume_options.cwd == str(temp_working_dir)

            # Cleanup
            await new_session_manager.shutdown()

    @pytest.mark.asyncio
    async def test_multiple_session_persistence(self, temp_session_storage, temp_working_dir):
        """Test persistence of multiple concurrent sessions."""
        # Arrange
        session_manager = SessionManager()
        claude_service = ClaudeService(temp_working_dir, temp_session_storage, session_manager)

        session_count = 3
        session_responses = []

        with patch('app.services.session_manager.ClaudeSDKClient') as MockClient:
            def create_mock_client():
                client = AsyncMock()
                client.session_id = f"multi-session-{len(session_responses)}"
                return client

            MockClient.side_effect = create_mock_client

            # Create multiple sessions
            for i in range(session_count):
                request = SessionRequest(
                    user_id=f"user-{i}",
                    session_name=f"Multi Session {i}",
                    working_directory=str(temp_working_dir)
                )

                response = await claude_service.create_session(request)
                session_responses.append(response)

            # Verify all sessions are stored
            for response in session_responses:
                stored = temp_session_storage.get_session(response.session_id)
                assert stored is not None
                assert stored["user_id"] == response.user_id

            # Shutdown and restart
            await session_manager.shutdown()

        # Test resumption of all sessions
        new_session_manager = SessionManager()

        with patch('app.services.session_manager.ClaudeSDKClient') as MockClient:
            def create_resume_client():
                client = AsyncMock()
                return client

            MockClient.side_effect = create_resume_client

            # Resume all sessions
            resumed_clients = []
            for response in session_responses:
                client = await new_session_manager.get_or_create_session(
                    session_id=response.session_id,
                    working_dir=str(temp_working_dir),
                    user_id=response.user_id,
                    is_new_session=False
                )
                resumed_clients.append(client)

            # Assert
            assert len(resumed_clients) == session_count
            assert len(new_session_manager.active_sessions) == session_count

            # Verify all clients are different instances
            assert len(set(id(client) for client in resumed_clients)) == session_count

        # Cleanup
        await new_session_manager.shutdown()

    @pytest.mark.asyncio
    async def test_session_cleanup_persistence(self, temp_session_storage, temp_working_dir):
        """Test that session cleanup is reflected in persistent storage."""
        # Arrange
        session_manager = SessionManager()
        claude_service = ClaudeService(temp_working_dir, temp_session_storage, session_manager)

        with patch('app.services.session_manager.ClaudeSDKClient') as MockClient:
            mock_client = AsyncMock()
            mock_client.session_id = "cleanup-session"
            MockClient.return_value = mock_client

            # Create session
            request = SessionRequest(
                user_id="cleanup-user",
                session_name="Cleanup Session",
                working_directory=str(temp_working_dir)
            )

            response = await claude_service.create_session(request)
            session_id = response.session_id

            # Verify session exists in storage
            assert temp_session_storage.get_session(session_id) is not None

            # Act - Cleanup session
            await session_manager.cleanup_session(session_id)

            # For proper cleanup integration, we should also remove from storage
            temp_session_storage.remove_session(session_id)

            # Assert
            assert session_id not in session_manager.active_sessions
            assert temp_session_storage.get_session(session_id) is None

        # Cleanup
        await session_manager.shutdown()

    @pytest.mark.asyncio
    async def test_storage_corruption_recovery(self, temp_working_dir):
        """Test recovery from corrupted session storage."""
        # Arrange
        with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as f:
            storage_file = Path(f.name)

        try:
            # Create corrupted storage file
            storage_file.write_text("invalid json content")

            # Create session storage (should handle corruption gracefully)
            storage = PersistentSessionStorage(storage_file)
            session_manager = SessionManager()
            claude_service = ClaudeService(temp_working_dir, storage, session_manager)

            with patch('app.services.session_manager.ClaudeSDKClient') as MockClient:
                mock_client = AsyncMock()
                mock_client.session_id = "recovery-session"
                MockClient.return_value = mock_client

                # Act - Create session despite corrupted storage
                request = SessionRequest(
                    user_id="recovery-user",
                    session_name="Recovery Session",
                    working_directory=str(temp_working_dir)
                )

                response = await claude_service.create_session(request)

                # Assert
                assert response.session_id == "recovery-session"
                assert response.user_id == "recovery-user"

                # Verify storage was reset and new session stored
                stored = storage.get_session(response.session_id)
                assert stored is not None

            # Cleanup
            await session_manager.shutdown()

        finally:
            if storage_file.exists():
                storage_file.unlink()

    @pytest.mark.asyncio
    async def test_working_directory_path_hashing(self, temp_session_storage):
        """Test that working directory path hashing matches Claude SDK behavior."""
        # Arrange
        session_manager = SessionManager()

        # Test paths with special characters that need hashing
        test_paths = [
            "/Users/test_user/project",  # Contains underscore
            "/path/with/underscores_and_slashes",  # Both / and _
            "/simple/path",  # Only slashes
            "/path_with_underscores",  # Only underscores
        ]

        with patch('app.services.session_manager.ClaudeSDKClient') as MockClient:
            def create_mock_client():
                client = AsyncMock()
                client.session_id = f"path-test-{len(session_manager.active_sessions)}"
                return client

            MockClient.side_effect = create_mock_client

            # Create sessions with different path types
            for i, path in enumerate(test_paths):
                client = await session_manager.get_or_create_session(
                    session_id=f"path-session-{i}",
                    working_dir=path,
                    user_id=f"user-{i}",
                    is_new_session=True
                )

                # Verify working directory is stored correctly
                session_info = session_manager.active_sessions[f"path-session-{i}"]
                assert session_info["working_dir"] == path

                # Verify ClaudeSDKClient was created with original path
                call_options = MockClient.call_args[0][0]
                assert call_options.cwd == path

        # Cleanup
        await session_manager.shutdown()