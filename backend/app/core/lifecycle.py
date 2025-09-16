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
    print("🚀 Claude Code Mobile Backend starting up...")
    print(f"⏰ Startup time: {datetime.utcnow().isoformat()}")

    # CRITICAL: Set consistent working directory BEFORE any Claude SDK operations
    project_root = Path(__file__).parent.parent.parent.absolute()
    os.chdir(project_root)

    # Verify Claude session storage location
    claude_sessions_path = (
        Path.home() / ".claude" / "projects" / f"-{str(project_root).replace('/', '-')}"
    )

    # Store in app state for service access
    app.state.project_root = project_root
    app.state.claude_sessions_path = claude_sessions_path

    print(f"✅ Working directory set to: {project_root}")
    print(f"✅ Claude sessions stored at: {claude_sessions_path}")
    print("✅ Claude service ready for direct SDK session usage")

    # Create Claude config directory if it doesn't exist
    claude_dir = Path.home() / ".claude"
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
    print("🛑 Claude Code Mobile Backend shutting down...")
    print(f"⏰ Shutdown time: {datetime.utcnow().isoformat()}")


def initialize_claude_environment() -> Path:
    """
    Initialize Claude environment with consistent working directory.

    Returns:
        Path: Project root directory for Claude SDK operations

    Raises:
        RuntimeError: If working directory cannot be set correctly
    """
    project_root = Path(__file__).parent.parent.parent.absolute()

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
    claude_dir = Path.home() / ".claude"
    projects_dir = claude_dir / "projects"
    project_hash = f"-{str(project_root).replace('/', '-')}"
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
