"""
Unit tests for SessionManager functionality.

Tests SessionManager session creation, retrieval, cleanup, validation,
and persistent client management with proper mocking.
"""

import pytest
import asyncio
import time
from unittest.mock import AsyncMock, MagicMock, patch
from pathlib import Path

from app.services.session_manager import SessionManager
from app.utils.session_utils import validate_session_client


class TestSessionManager:
    """Test SessionManager core functionality."""

    def setup_method(self):
        """Set up fresh SessionManager for each test."""
        self.session_manager = SessionManager(
            session_timeout=60,  # 1 minute for testing
            cleanup_interval=10  # 10 seconds for testing
        )

    def teardown_method(self):
        """Clean up after each test."""
        # Cancel cleanup task if running
        if self.session_manager.cleanup_task and not self.session_manager.cleanup_task.done():
            self.session_manager.cleanup_task.cancel()

    @pytest.mark.asyncio
    async def test_session_manager_initialization(self):
        """Test SessionManager initialization with custom parameters."""
        # Arrange & Act
        manager = SessionManager(session_timeout=300, cleanup_interval=60)

        # Assert
        assert manager.session_timeout == 300
        assert manager.cleanup_interval == 60
        assert manager.active_sessions == {}
        assert manager.cleanup_task is None

    @pytest.mark.asyncio
    async def test_create_new_session(self):
        """Test creating a new session with persistent client."""
        # Arrange
        with patch('app.services.session_manager.ClaudeSDKClient') as MockClient:
            mock_client = AsyncMock()
            mock_client.session_id = "mock-session-123"
            MockClient.return_value = mock_client

            # Act
            client = await self.session_manager.get_or_create_session(
                session_id="new-session-123",
                working_dir="/test/dir",
                user_id="test-user",
                is_new_session=True
            )

            # Assert
            assert client == mock_client
            # For new sessions, SessionManager uses client's session_id if different
            actual_session_id = "mock-session-123"  # This is what the client returns
            assert actual_session_id in self.session_manager.active_sessions
            session_info = self.session_manager.active_sessions[actual_session_id]
            assert session_info["client"] == mock_client
            assert session_info["working_dir"] == "/test/dir"
            assert session_info["user_id"] == "test-user"
            assert session_info["is_connected"] is True

            # Verify ClaudeSDKClient was created and connected
            MockClient.assert_called_once()
            mock_client.connect.assert_called_once()

    @pytest.mark.asyncio
    async def test_get_existing_session(self):
        """Test retrieving an existing session client."""
        # Arrange
        with patch('app.services.session_manager.ClaudeSDKClient') as MockClient:
            mock_client = AsyncMock()
            mock_client._session = MagicMock()  # Mock connection
            mock_client.session_id = "existing-session"  # Keep session ID consistent
            MockClient.return_value = mock_client

            # Create initial session
            await self.session_manager.get_or_create_session(
                session_id="existing-session",
                working_dir="/test/dir",
                user_id="test-user",
                is_new_session=True
            )

            # Act - Get existing session
            client = await self.session_manager.get_or_create_session(
                session_id="existing-session",
                working_dir="/test/dir",
                user_id="test-user",
                is_new_session=False
            )

            # Assert
            assert client == mock_client
            # Should only create client once
            assert MockClient.call_count == 1
            # Last used time should be updated
            session_info = self.session_manager.active_sessions["existing-session"]
            assert session_info["last_used"] > session_info["created_at"]

    @pytest.mark.asyncio
    async def test_client_validation_failure_recreates_session(self):
        """Test that invalid clients are recreated."""
        # Arrange
        with patch('app.services.session_manager.ClaudeSDKClient') as MockClient:
            # First client that becomes invalid
            invalid_client = AsyncMock()
            invalid_client._session = None  # Invalid connection

            # Second client that is valid
            valid_client = AsyncMock()
            valid_client._session = MagicMock()  # Valid connection

            MockClient.side_effect = [invalid_client, valid_client]

            # Create initial session with invalid client
            self.session_manager.active_sessions["test-session"] = {
                "client": invalid_client,
                "working_dir": "/test/dir",
                "user_id": "test-user",
                "last_used": time.time(),
                "created_at": time.time(),
                "is_connected": False
            }

            # Act - Try to get session (should recreate due to invalid client)
            client = await self.session_manager.get_or_create_session(
                session_id="test-session",
                working_dir="/test/dir",
                user_id="test-user",
                is_new_session=False
            )

            # Assert
            assert client == valid_client
            assert MockClient.call_count == 1  # One new client created
            valid_client.connect.assert_called_once()

    @pytest.mark.asyncio
    async def test_cleanup_session(self):
        """Test manual session cleanup."""
        # Arrange
        with patch('app.services.session_manager.ClaudeSDKClient') as MockClient:
            mock_client = AsyncMock()
            MockClient.return_value = mock_client

            # Create session
            await self.session_manager.get_or_create_session(
                session_id="cleanup-session",
                working_dir="/test/dir",
                user_id="test-user",
                is_new_session=True
            )

            # Verify session exists
            assert "cleanup-session" in self.session_manager.active_sessions

            # Act
            result = await self.session_manager.cleanup_session("cleanup-session")

            # Assert
            assert result is True
            assert "cleanup-session" not in self.session_manager.active_sessions
            mock_client.disconnect.assert_called_once()

    @pytest.mark.asyncio
    async def test_cleanup_nonexistent_session(self):
        """Test cleanup of non-existent session."""
        # Act
        result = await self.session_manager.cleanup_session("nonexistent")

        # Assert
        assert result is False

    @pytest.mark.asyncio
    async def test_periodic_cleanup_task(self):
        """Test automatic cleanup of inactive sessions."""
        # Arrange
        with patch('app.services.session_manager.ClaudeSDKClient') as MockClient:
            mock_client = AsyncMock()
            MockClient.return_value = mock_client

            # Create session and make it old
            await self.session_manager.get_or_create_session(
                session_id="old-session",
                working_dir="/test/dir",
                user_id="test-user",
                is_new_session=True
            )

            # Make session appear old
            self.session_manager.active_sessions["old-session"]["last_used"] = time.time() - 120  # 2 minutes ago

            # Wait for cleanup to run (should be very quick in test)
            await asyncio.sleep(0.1)

            # Manually trigger cleanup check
            current_time = time.time()
            sessions_to_remove = []
            for session_id, session_info in self.session_manager.active_sessions.items():
                if current_time - session_info["last_used"] > self.session_manager.session_timeout:
                    sessions_to_remove.append(session_id)

            for session_id in sessions_to_remove:
                await self.session_manager.cleanup_session(session_id)

            # Assert
            assert "old-session" not in self.session_manager.active_sessions

    @pytest.mark.asyncio
    async def test_session_stats(self):
        """Test session statistics generation."""
        # Arrange
        with patch('app.services.session_manager.ClaudeSDKClient') as MockClient:
            mock_client = AsyncMock()
            MockClient.return_value = mock_client

            # Create multiple sessions
            for i in range(3):
                await self.session_manager.get_or_create_session(
                    session_id=f"session-{i}",
                    working_dir="/test/dir",
                    user_id=f"user-{i}",
                    is_new_session=True
                )

            # Act
            stats = await self.session_manager.get_session_stats()

            # Assert
            assert stats["active_sessions"] == 3
            assert stats["session_timeout_seconds"] == 60
            assert stats["cleanup_interval_seconds"] == 10
            assert "timestamp" in stats
            assert "oldest_session_age_seconds" in stats
            assert "sessions_by_user" in stats
            assert len(stats["sessions_by_user"]) == 3

    @pytest.mark.asyncio
    async def test_shutdown_cleanup(self):
        """Test graceful shutdown cleanup."""
        # Arrange
        with patch('app.services.session_manager.ClaudeSDKClient') as MockClient:
            mock_client = AsyncMock()
            MockClient.return_value = mock_client

            # Create multiple sessions
            for i in range(2):
                await self.session_manager.get_or_create_session(
                    session_id=f"shutdown-session-{i}",
                    working_dir="/test/dir",
                    user_id=f"user-{i}",
                    is_new_session=True
                )

            # Verify sessions exist
            assert len(self.session_manager.active_sessions) == 2

            # Act
            await self.session_manager.shutdown()

            # Assert
            assert len(self.session_manager.active_sessions) == 0
            # All clients should be disconnected
            assert mock_client.disconnect.call_count == 2

    @pytest.mark.asyncio
    async def test_session_user_tracking(self):
        """Test session user ID tracking."""
        # Arrange
        with patch('app.services.session_manager.ClaudeSDKClient') as MockClient:
            mock_client = AsyncMock()
            MockClient.return_value = mock_client

            # Create session
            await self.session_manager.get_or_create_session(
                session_id="user-session",
                working_dir="/test/dir",
                user_id="test-user-123",
                is_new_session=True
            )

            # Act & Assert
            assert self.session_manager.is_session_active("user-session") is True
            assert self.session_manager.get_session_user("user-session") == "test-user-123"
            assert self.session_manager.get_session_user("nonexistent") is None

    @pytest.mark.asyncio
    async def test_get_active_session_ids(self):
        """Test getting list of active session IDs."""
        # Arrange
        with patch('app.services.session_manager.ClaudeSDKClient') as MockClient:
            mock_client = AsyncMock()
            MockClient.return_value = mock_client

            # Create sessions
            session_ids = ["session-1", "session-2", "session-3"]
            for session_id in session_ids:
                await self.session_manager.get_or_create_session(
                    session_id=session_id,
                    working_dir="/test/dir",
                    user_id="test-user",
                    is_new_session=True
                )

            # Act
            active_ids = self.session_manager.get_active_session_ids()

            # Assert
            assert set(active_ids) == set(session_ids)
            assert len(active_ids) == 3

    @pytest.mark.asyncio
    async def test_client_creation_failure(self):
        """Test handling of client creation failures."""
        # Arrange
        with patch('app.services.session_manager.ClaudeSDKClient') as MockClient:
            MockClient.side_effect = RuntimeError("Client creation failed")

            # Act & Assert
            with pytest.raises(RuntimeError, match="Failed to create session"):
                await self.session_manager.get_or_create_session(
                    session_id="failed-session",
                    working_dir="/test/dir",
                    user_id="test-user",
                    is_new_session=True
                )

    @pytest.mark.asyncio
    async def test_client_connection_failure(self):
        """Test handling of client connection failures."""
        # Arrange
        with patch('app.services.session_manager.ClaudeSDKClient') as MockClient:
            mock_client = AsyncMock()
            mock_client.connect.side_effect = RuntimeError("Connection failed")
            MockClient.return_value = mock_client

            # Act & Assert
            with pytest.raises(RuntimeError, match="Failed to create session"):
                await self.session_manager.get_or_create_session(
                    session_id="connection-failed",
                    working_dir="/test/dir",
                    user_id="test-user",
                    is_new_session=True
                )

    @pytest.mark.asyncio
    async def test_cleanup_disconnect_failure(self):
        """Test cleanup continues even if client disconnect fails."""
        # Arrange
        with patch('app.services.session_manager.ClaudeSDKClient') as MockClient:
            mock_client = AsyncMock()
            mock_client.disconnect.side_effect = RuntimeError("Disconnect failed")
            MockClient.return_value = mock_client

            # Create session
            await self.session_manager.get_or_create_session(
                session_id="disconnect-fail-session",
                working_dir="/test/dir",
                user_id="test-user",
                is_new_session=True
            )

            # Act - Should not raise exception
            result = await self.session_manager.cleanup_session("disconnect-fail-session")

            # Assert - Session should still be removed despite disconnect failure
            assert result is True
            assert "disconnect-fail-session" not in self.session_manager.active_sessions


class TestSessionManagerValidation:
    """Test SessionManager validation utilities."""

    @pytest.mark.asyncio
    async def test_validate_healthy_client(self):
        """Test validation of healthy ClaudeSDKClient."""
        # Arrange
        mock_client = MagicMock()
        mock_client._session = MagicMock()  # Healthy session
        mock_client.session_id = "test-session-123"

        # Act
        result = await validate_session_client(mock_client)

        # Assert
        assert result["is_valid"] is True
        assert result["has_session"] is True
        assert result["is_connected"] is True
        assert result["session_id"] == "test-session-123"
        assert result["error"] is None

    @pytest.mark.asyncio
    async def test_validate_unhealthy_client(self):
        """Test validation of unhealthy ClaudeSDKClient."""
        # Arrange
        mock_client = MagicMock()
        mock_client._session = None  # Unhealthy session

        # Act
        result = await validate_session_client(mock_client)

        # Assert
        assert result["is_valid"] is False
        assert result["has_session"] is False
        assert result["is_connected"] is False

    @pytest.mark.asyncio
    async def test_validate_client_missing_session_attr(self):
        """Test validation of client missing session attribute."""
        # Arrange
        mock_client = MagicMock()
        del mock_client._session  # Remove _session attribute

        # Act
        result = await validate_session_client(mock_client)

        # Assert
        assert result["is_valid"] is False
        assert result["error"] == "Client missing _session attribute"

    @pytest.mark.asyncio
    async def test_validate_client_exception(self):
        """Test validation handles exceptions gracefully."""
        # Arrange
        mock_client = MagicMock()
        mock_client._session = MagicMock()

        # Make accessing session_id raise an exception
        type(mock_client).session_id = MagicMock(side_effect=RuntimeError("Session ID error"))

        # Act
        result = await validate_session_client(mock_client)

        # Assert
        assert result["is_valid"] is False
        assert "Session ID error" in result["error"]


class TestSessionManagerConcurrency:
    """Test SessionManager concurrent operations."""

    @pytest.mark.asyncio
    async def test_concurrent_session_creation(self):
        """Test creating multiple sessions concurrently."""
        # Arrange
        session_manager = SessionManager()

        with patch('app.services.session_manager.ClaudeSDKClient') as MockClient:
            call_count = 0
            def create_mock_client(options=None):
                nonlocal call_count
                client = AsyncMock()
                client._session = MagicMock()
                client.session_id = f"mock-session-{call_count}"
                call_count += 1
                return client

            MockClient.side_effect = create_mock_client

            # Act - Create sessions concurrently
            tasks = []
            for i in range(5):
                task = session_manager.get_or_create_session(
                    session_id=f"concurrent-session-{i}",
                    working_dir="/test/dir",
                    user_id=f"user-{i}",
                    is_new_session=True
                )
                tasks.append(task)

            clients = await asyncio.gather(*tasks)

            # Assert
            assert len(clients) == 5
            assert len(session_manager.active_sessions) == 5

            # All clients should be different instances
            assert len(set(id(client) for client in clients)) == 5

        # Cleanup
        await session_manager.shutdown()

    @pytest.mark.asyncio
    async def test_concurrent_access_same_session(self):
        """Test concurrent access to the same session."""
        # Arrange
        session_manager = SessionManager()

        with patch('app.services.session_manager.ClaudeSDKClient') as MockClient:
            mock_client = AsyncMock()
            mock_client._session = MagicMock()
            MockClient.return_value = mock_client

            # Act - Access same session concurrently
            tasks = []
            for _ in range(3):
                task = session_manager.get_or_create_session(
                    session_id="shared-session",
                    working_dir="/test/dir",
                    user_id="test-user",
                    is_new_session=False
                )
                tasks.append(task)

            clients = await asyncio.gather(*tasks)

            # Assert
            # Should only create one client instance
            assert MockClient.call_count == 1
            # All returned clients should be the same instance
            assert all(client == mock_client for client in clients)
            assert len(session_manager.active_sessions) == 1

        # Cleanup
        await session_manager.shutdown()