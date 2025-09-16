"""
Pytest configuration and fixtures for Claude Code Mobile Backend tests.

Provides test fixtures for FastAPI testing, temporary directories,
and Claude SDK mocking for reliable test execution.
"""

import pytest
import tempfile
import os
import sys
from pathlib import Path
from fastapi.testclient import TestClient
from unittest.mock import AsyncMock, MagicMock, patch

# Mock claude_code_sdk before importing app modules
claude_sdk_mock = MagicMock()
claude_types_mock = MagicMock()

# Mock ClaudeCodeOptions class to return proper objects
class MockClaudeCodeOptions:
    def __init__(self, cwd=None, model=None, resume=None, permission_mode=None, **kwargs):
        self.cwd = cwd
        self.model = model
        self.resume = resume
        self.permission_mode = permission_mode

claude_types_mock.ClaudeCodeOptions = MockClaudeCodeOptions
sys.modules['claude_code_sdk'] = claude_sdk_mock
sys.modules['claude_code_sdk.types'] = claude_types_mock

from app.main import app
from app.services.claude_service import ClaudeService
from app.core.lifecycle import initialize_claude_environment


@pytest.fixture
def temp_project_root():
    """Create temporary project root directory for testing."""
    with tempfile.TemporaryDirectory() as temp_dir:
        project_root = Path(temp_dir)
        # Set working directory to temp for testing
        original_cwd = Path.cwd()
        os.chdir(project_root)

        yield project_root

        # Restore original working directory
        os.chdir(original_cwd)


@pytest.fixture
def claude_service(temp_project_root):
    """Create ClaudeService instance with temporary project root."""
    return ClaudeService(temp_project_root)


@pytest.fixture
def test_client(temp_project_root):
    """Create FastAPI test client with temporary project root."""
    # Set up app state for testing
    app.state.project_root = temp_project_root
    app.state.claude_sessions_path = Path.home() / ".claude" / "projects" / f"-{str(temp_project_root).replace('/', '-')}"

    with TestClient(app) as client:
        yield client


@pytest.fixture
def mock_claude_response():
    """Mock Claude SDK response for testing."""
    class MockResponse:
        def __aiter__(self):
            return self

        async def __anext__(self):
            if not hasattr(self, '_messages_sent'):
                self._messages_sent = 0

            if self._messages_sent == 0:
                # Mock initialization message with session ID - use real objects, not MagicMock
                class MockInitMessage:
                    def __init__(self):
                        self.subtype = 'init'
                        self.data = {'session_id': 'test-session-123'}  # Real dict with string value

                self._messages_sent += 1
                return MockInitMessage()
            elif self._messages_sent == 1:
                # Mock content message - use real objects for content
                class MockContentMessage:
                    def __init__(self):
                        self.content = [MockContentItem()]

                class MockContentItem:
                    def __init__(self):
                        self.text = "Test response from Claude"

                self._messages_sent += 1
                return MockContentMessage()
            else:
                raise StopAsyncIteration

    return MockResponse()


@pytest.fixture
def mock_claude_query(monkeypatch, mock_claude_response):
    """Mock the claude_code_sdk.query function."""
    mock_query = MagicMock(return_value=mock_claude_response)
    monkeypatch.setattr("app.services.claude_service.query", mock_query)
    return mock_query


@pytest.fixture
def sample_session_request():
    """Sample session request for testing."""
    return {
        "user_id": "test-user-123",
        "session_name": "Test Session",
        "working_directory": None,
        "context": {"test": "data"}
    }


@pytest.fixture
def sample_query_request():
    """Sample query request for testing."""
    return {
        "query": "Hello Claude!",
        "session_id": "test-session-123",
        "user_id": "test-user-123",
        "stream": True,
        "options": {
            "model": None,
            "max_tokens": 8192,
            "temperature": 0.7
        }
    }


@pytest.fixture
def mock_session_file(temp_project_root):
    """Create a mock session file for testing."""
    sessions_dir = Path.home() / ".claude" / "projects" / f"-{str(temp_project_root).replace('/', '-')}"
    sessions_dir.mkdir(parents=True, exist_ok=True)

    session_file = sessions_dir / "test-session-123.jsonl"
    session_file.write_text('{"timestamp": "2023-01-01T00:00:00Z", "content": "Test session data"}\n')

    yield session_file

    # Cleanup
    if session_file.exists():
        session_file.unlink()


@pytest.fixture(autouse=True)
def cleanup_temp_files():
    """Automatically cleanup temporary files after each test."""
    yield
    # Cleanup logic can be added here if needed