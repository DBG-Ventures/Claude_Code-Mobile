"""
Comprehensive session management tests for Claude Code Mobile Backend.

Tests session creation, resumption, working directory consistency,
and Claude SDK integration with proper mocking for reliable testing.
"""

import pytest
import json
import asyncio
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch

from app.services.claude_service import ClaudeService
from app.models.requests import SessionRequest, ClaudeQueryRequest, ClaudeCodeOptions
from app.models.responses import SessionStatus, ChunkType
from app.utils.session_utils import (
    verify_session_exists,
    list_user_sessions,
    recover_session,
    get_session_diagnostics,
    validate_session_storage_setup
)


class TestClaudeService:
    """Test ClaudeService direct SDK integration."""

    @pytest.mark.asyncio
    async def test_create_session_success(self, claude_service, mock_claude_query, sample_session_request):
        """Test successful session creation with direct SDK integration."""
        # Arrange
        request = SessionRequest(**sample_session_request)

        # Act
        response = await claude_service.create_session(request)

        # Assert
        assert response.session_id == "test-session-123"
        assert response.user_id == request.user_id
        assert response.session_name == request.session_name
        assert response.status == SessionStatus.ACTIVE
        assert response.message_count == 0

        # Verify Claude SDK was called with correct parameters
        mock_claude_query.assert_called_once()
        call_args = mock_claude_query.call_args
        assert call_args[1]['options'].permission_mode == "bypassPermissions"

    @pytest.mark.asyncio
    async def test_create_session_with_working_directory(self, temp_project_root, mock_claude_query):
        """Test session creation with specific working directory."""
        # Arrange
        claude_service = ClaudeService(temp_project_root)
        custom_working_dir = str(temp_project_root / "custom")
        request = SessionRequest(
            user_id="test-user",
            session_name="Custom Dir Session",
            working_directory=custom_working_dir
        )

        # Act
        response = await claude_service.create_session(request)

        # Assert
        assert response.session_id == "test-session-123"
        mock_claude_query.assert_called_once()
        call_args = mock_claude_query.call_args
        assert call_args[1]['options'].cwd == custom_working_dir

    @pytest.mark.asyncio
    async def test_create_session_failure(self, claude_service, monkeypatch):
        """Test session creation failure handling."""
        # Arrange
        mock_query = AsyncMock(side_effect=RuntimeError("Claude SDK error"))
        monkeypatch.setattr("app.services.claude_service.query", mock_query)

        request = SessionRequest(user_id="test-user", session_name="Test Session")

        # Act & Assert
        with pytest.raises(RuntimeError, match="Failed to create Claude session"):
            await claude_service.create_session(request)

    @pytest.mark.asyncio
    async def test_query_with_session_resumption(self, claude_service, mock_claude_query, sample_query_request):
        """Test query execution with session resumption."""
        # Arrange
        request = ClaudeQueryRequest(**sample_query_request)
        options = ClaudeCodeOptions()

        # Act
        response = await claude_service.query(request, options)

        # Assert
        assert response.session_id == request.session_id
        assert response.message.content == "Test response from Claude"
        assert response.processing_time >= 0

        # Verify Claude SDK was called with resumption
        mock_claude_query.assert_called_once()
        call_args = mock_claude_query.call_args
        assert call_args[1]['options'].resume == request.session_id

    @pytest.mark.asyncio
    async def test_stream_response_with_mobile_optimization(self, claude_service, mock_claude_query, sample_query_request):
        """Test streaming response with mobile optimization delays."""
        # Arrange
        request = ClaudeQueryRequest(**sample_query_request)
        options = ClaudeCodeOptions()

        # Act
        chunks = []
        async for chunk in claude_service.stream_response(request, options):
            chunks.append(chunk)

        # Assert
        assert len(chunks) >= 3  # START, DELTA, COMPLETE
        assert chunks[0].chunk_type == ChunkType.START
        assert chunks[-1].chunk_type == ChunkType.COMPLETE

        # Verify session ID consistency
        for chunk in chunks:
            assert chunk.session_id == request.session_id

    @pytest.mark.asyncio
    async def test_session_exists_verification(self, claude_service, temp_project_root, mock_session_file):
        """Test session existence verification."""
        # Act
        exists = await claude_service.verify_session_exists("test-session-123")

        # Assert
        assert exists is True

        # Test non-existent session
        exists = await claude_service.verify_session_exists("non-existent-session")
        assert exists is False

    @pytest.mark.asyncio
    async def test_list_sessions(self, claude_service, temp_project_root, mock_session_file):
        """Test listing available sessions."""
        # Act
        session_ids = await claude_service.list_sessions()

        # Assert
        assert "test-session-123" in session_ids

    @pytest.mark.asyncio
    async def test_get_session(self, claude_service, temp_project_root, mock_session_file):
        """Test getting session details."""
        # Act
        session = await claude_service.get_session("test-session-123", "test-user")

        # Assert
        assert session is not None
        assert session.session_id == "test-session-123"
        assert session.user_id == "test-user"
        assert session.status == SessionStatus.ACTIVE

    @pytest.mark.asyncio
    async def test_working_directory_consistency(self, temp_project_root, monkeypatch):
        """Test working directory management."""
        # Arrange
        original_cwd = Path.cwd()
        different_dir = temp_project_root.parent

        # Change to different directory
        import os
        os.chdir(different_dir)

        # Act
        claude_service = ClaudeService(temp_project_root)

        # Assert
        assert Path.cwd() == temp_project_root

        # Restore
        os.chdir(original_cwd)


class TestSessionUtils:
    """Test session utility functions."""

    def test_verify_session_exists(self, temp_project_root, mock_session_file):
        """Test session existence verification utility."""
        # Test existing session
        exists = verify_session_exists("test-session-123", temp_project_root)
        assert exists is True

        # Test non-existent session
        exists = verify_session_exists("non-existent", temp_project_root)
        assert exists is False

    def test_list_user_sessions(self, temp_project_root, mock_session_file):
        """Test listing user sessions utility."""
        # Act
        sessions = list_user_sessions(temp_project_root)

        # Assert
        assert len(sessions) >= 1
        session = sessions[0]
        assert session["session_id"] == "test-session-123"
        assert "file_size_bytes" in session
        assert "created_at" in session
        assert "modified_at" in session

    def test_recover_session(self, temp_project_root, mock_session_file):
        """Test session recovery utility."""
        # Act
        result = recover_session("test-session-123", temp_project_root)

        # Assert
        assert result["exists"] is True
        assert result["recoverable"] is True
        assert result["diagnostics"]["readable"] is True
        assert result["diagnostics"]["valid_lines"] > 0

    def test_get_session_diagnostics(self, temp_project_root, mock_session_file):
        """Test session diagnostics utility."""
        # Act
        diagnostics = get_session_diagnostics(temp_project_root)

        # Assert
        assert "timestamp" in diagnostics
        assert diagnostics["project_root"] == str(temp_project_root)
        assert "claude_config" in diagnostics
        assert "project_sessions" in diagnostics
        assert diagnostics["project_sessions"]["session_files_count"] >= 1

    def test_validate_session_storage_setup(self, temp_project_root):
        """Test session storage setup validation."""
        # Act
        is_valid, issues = validate_session_storage_setup(temp_project_root)

        # Assert
        # May have issues in test environment, but should not crash
        assert isinstance(is_valid, bool)
        assert isinstance(issues, list)


class TestAPIEndpoints:
    """Test API endpoints with session management."""

    def test_create_session_endpoint(self, test_client, mock_claude_query, sample_session_request):
        """Test session creation endpoint."""
        # Act
        response = test_client.post("/claude/sessions", json=sample_session_request)

        # Assert
        assert response.status_code == 200
        data = response.json()
        assert data["session_id"] == "test-session-123"
        assert data["user_id"] == sample_session_request["user_id"]
        assert data["status"] == "active"

    def test_health_endpoint_with_session_diagnostics(self, test_client, temp_project_root):
        """Test health endpoint includes session diagnostics."""
        # Act
        response = test_client.get("/health")

        # Assert
        assert response.status_code == 200
        data = response.json()
        assert "dependencies" in data
        assert "session_storage" in data["dependencies"]

    def test_stream_endpoint_session_validation(self, test_client, mock_claude_query, sample_query_request):
        """Test streaming endpoint validates session existence."""
        # Create session first
        session_response = test_client.post("/claude/sessions", json={
            "user_id": "test-user-123",
            "session_name": "Test Session"
        })
        assert session_response.status_code == 200

        # Test streaming with valid session
        response = test_client.post("/claude/stream", json=sample_query_request)
        assert response.status_code == 200

    def test_stream_endpoint_invalid_session(self, test_client, sample_query_request):
        """Test streaming endpoint handles invalid session."""
        # Modify to use non-existent session
        invalid_request = sample_query_request.copy()
        invalid_request["session_id"] = "non-existent-session"

        # Act
        response = test_client.post("/claude/stream", json=invalid_request)

        # Assert
        assert response.status_code == 200  # SSE returns 200 but sends error event


class TestErrorHandling:
    """Test error handling and edge cases."""

    @pytest.mark.asyncio
    async def test_session_extraction_failure(self, claude_service, monkeypatch):
        """Test handling of session ID extraction failure."""
        # Arrange
        async def mock_response_no_session():
            message = MagicMock()
            message.content = [MagicMock()]
            message.content[0].text = "Response without session ID"
            yield message

        mock_query = AsyncMock(return_value=mock_response_no_session())
        monkeypatch.setattr("app.services.claude_service.query", mock_query)

        request = SessionRequest(user_id="test-user", session_name="Test")

        # Act & Assert
        with pytest.raises(RuntimeError, match="Failed to create Claude session"):
            await claude_service.create_session(request)

    @pytest.mark.asyncio
    async def test_streaming_error_handling(self, claude_service, monkeypatch, sample_query_request):
        """Test streaming error handling."""
        # Arrange
        mock_query = AsyncMock(side_effect=RuntimeError("Streaming error"))
        monkeypatch.setattr("app.services.claude_service.query", mock_query)

        request = ClaudeQueryRequest(**sample_query_request)
        options = ClaudeCodeOptions()

        # Act
        chunks = []
        with pytest.raises(RuntimeError):
            async for chunk in claude_service.stream_response(request, options):
                chunks.append(chunk)

        # Assert
        # Should have at least START and ERROR chunks
        assert any(chunk.chunk_type == ChunkType.START for chunk in chunks)
        assert any(chunk.chunk_type == ChunkType.ERROR for chunk in chunks)


class TestConcurrentSessions:
    """Test concurrent session management."""

    @pytest.mark.asyncio
    async def test_multiple_concurrent_sessions(self, claude_service, mock_claude_query):
        """Test creating multiple concurrent sessions."""
        # Arrange
        session_requests = [
            SessionRequest(user_id=f"user-{i}", session_name=f"Session {i}")
            for i in range(5)
        ]

        # Act
        tasks = [claude_service.create_session(req) for req in session_requests]
        responses = await asyncio.gather(*tasks)

        # Assert
        assert len(responses) == 5
        session_ids = [resp.session_id for resp in responses]
        assert len(set(session_ids)) == 5  # All unique session IDs

    @pytest.mark.asyncio
    async def test_session_isolation(self, claude_service, mock_claude_query, temp_project_root):
        """Test that sessions are properly isolated."""
        # This would require more complex mocking to test true isolation
        # For now, verify that different sessions get different IDs
        request1 = SessionRequest(user_id="user1", session_name="Session 1")
        request2 = SessionRequest(user_id="user2", session_name="Session 2")

        response1 = await claude_service.create_session(request1)
        response2 = await claude_service.create_session(request2)

        assert response1.session_id != response2.session_id
        assert response1.user_id != response2.user_id