"""
FastAPI application lifecycle management with Claude SDK working directory setup.

Provides working directory management and Claude service initialization for
consistent session storage across FastAPI worker restarts and Docker deployments.
"""

import os
from pathlib import Path
from contextlib import asynccontextmanager
from datetime import datetime

from fastapi import FastAPI
from app.utils.logging import setup_logging, StructuredLogger
from app.utils.session_storage import PersistentSessionStorage
from app.services.session_manager import SessionManager


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Application lifespan management with working directory consistency.

    CRITICAL: Sets working directory before any Claude SDK operations to ensure
    consistent session storage location at ~/.claude/projects/{project-hash}/

    Args:
        app: FastAPI application instance

    Yields:
        Application context during runtime
    """
    # Startup
    # Initialize logging system first
    setup_logging()
    logger = StructuredLogger(__name__)

    logger.info(
        "Claude Code Mobile Backend starting up",
        category="lifecycle",
        operation="startup",
        timestamp=datetime.utcnow().isoformat(),
    )

    # CRITICAL: Set consistent working directory BEFORE any Claude SDK operations
    # Use environment variable if set, otherwise use parent project directory
    claude_project_root = os.environ.get("CLAUDE_PROJECT_ROOT")
    if claude_project_root:
        project_root = Path(claude_project_root)
    else:
        # Go to parent directory so Claude SDK uses Claude_Code-Mobile, not backend
        backend_root = Path(__file__).parent.parent.parent.absolute()
        project_root = backend_root.parent

    os.chdir(project_root)

    # Verify Claude session storage location using environment variables
    project_hash = str(project_root.absolute()).replace("/", "-")
    if not project_hash.startswith("-"):
        project_hash = f"-{project_hash}"

    claude_home = os.environ.get("CLAUDE_HOME", str(Path.home() / ".claude"))
    claude_sessions_path = Path(claude_home) / "projects" / project_hash

    # Store in app state for service access
    app.state.project_root = project_root
    app.state.claude_sessions_path = claude_sessions_path

    # Initialize persistent session storage for persistence across requests and restarts
    session_storage_file = project_root / ".claude_sessions.json"
    app.state.session_storage = PersistentSessionStorage(session_storage_file)

    # Initialize SessionManager for persistent ClaudeSDKClient management
    # Configure with reasonable defaults for mobile usage
    session_manager = SessionManager(
        session_timeout=3600,  # 1 hour inactivity timeout
        cleanup_interval=300,  # Check every 5 minutes
    )
    app.state.session_manager = session_manager

    logger.info(
        "Working directory, session storage, and SessionManager configured",
        category="lifecycle",
        operation="configure_directories",
        project_root=str(project_root),
        claude_sessions_path=str(claude_sessions_path),
        session_manager_initialized=True,
    )

    # Create Claude config directory if it doesn't exist
    claude_dir = Path(claude_home)
    if not claude_dir.exists():
        claude_dir.mkdir(parents=True, exist_ok=True)
        print(f"✅ Created Claude config directory: {claude_dir}")

    projects_dir = claude_dir / "projects"
    if not projects_dir.exists():
        projects_dir.mkdir(parents=True, exist_ok=True)
        print(f"✅ Created Claude projects directory: {projects_dir}")

    # Verify session storage directory access
    if claude_sessions_path.exists():
        session_files = list(claude_sessions_path.glob("*.jsonl"))
        print(f"✅ Found {len(session_files)} existing session files")
    else:
        print(f"✅ Session storage directory will be created: {claude_sessions_path}")

    yield

    # Shutdown
    logger.info(
        "Claude Code Mobile Backend shutting down",
        category="lifecycle",
        operation="shutdown_start",
        timestamp=datetime.utcnow().isoformat(),
    )

    # Cleanup SessionManager and all persistent clients
    if hasattr(app.state, "session_manager"):
        try:
            await app.state.session_manager.shutdown()
            logger.info(
                "SessionManager shutdown completed",
                category="lifecycle",
                operation="session_manager_shutdown",
            )
        except Exception as e:
            logger.error(
                f"Error during SessionManager shutdown: {e}",
                category="lifecycle",
                operation="session_manager_shutdown_error",
                error=str(e),
            )

    logger.info(
        "Claude Code Mobile Backend shutdown completed",
        category="lifecycle",
        operation="shutdown_complete",
        timestamp=datetime.utcnow().isoformat(),
    )


def initialize_claude_environment() -> Path:
    """
    Initialize Claude environment with consistent working directory.

    Returns:
        Path: Project root directory for Claude SDK operations

    Raises:
        RuntimeError: If working directory cannot be set correctly
    """
    # Use environment variable if set, otherwise use parent project directory
    claude_project_root = os.environ.get("CLAUDE_PROJECT_ROOT")
    if claude_project_root:
        project_root = Path(claude_project_root)
    else:
        # Go to parent directory so Claude SDK uses Claude_Code-Mobile, not backend
        backend_root = Path(__file__).parent.parent.parent.absolute()
        project_root = backend_root.parent

    try:
        os.chdir(project_root)
        current_cwd = Path.cwd()

        if current_cwd != project_root:
            raise RuntimeError(
                f"Working directory mismatch: {current_cwd} != {project_root}"
            )

        return project_root

    except Exception as e:
        raise RuntimeError(f"Failed to set working directory: {e}")


def verify_session_storage(project_root: Path) -> dict:
    """
    Verify Claude SDK session storage accessibility and provide debugging info.

    Args:
        project_root: Project root directory path

    Returns:
        dict: Session storage verification results
    """
    claude_home = os.environ.get("CLAUDE_HOME", str(Path.home() / ".claude"))
    claude_dir = Path(claude_home)
    projects_dir = claude_dir / "projects"

    project_hash = str(project_root.absolute()).replace("/", "-")
    if not project_hash.startswith("-"):
        project_hash = f"-{project_hash}"

    project_sessions_dir = projects_dir / project_hash

    verification_result = {
        "claude_dir_exists": claude_dir.exists(),
        "projects_dir_exists": projects_dir.exists(),
        "project_sessions_dir": str(project_sessions_dir),
        "project_sessions_dir_exists": project_sessions_dir.exists(),
        "session_files_count": 0,
        "session_files": [],
        "project_root": str(project_root),
        "current_working_directory": str(Path.cwd()),
        "working_directory_correct": Path.cwd() == project_root,
    }

    if project_sessions_dir.exists():
        session_files = list(project_sessions_dir.glob("*.jsonl"))
        verification_result["session_files_count"] = len(session_files)
        verification_result["session_files"] = [
            f.name for f in session_files[:10]
        ]  # Limit to first 10

    return verification_result
