"""
Session validation, recovery, and debugging utilities for Claude Code SDK integration.

Provides standalone functions for session management debugging and validation
that can be used independently or integrated into the ClaudeService.
"""

import json
import os
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Any, Tuple


def verify_session_exists(session_id: str, project_root: Path) -> bool:
    """
    Verify if a Claude SDK session exists by checking file system.

    Args:
        session_id: Claude SDK session identifier
        project_root: Project root directory path

    Returns:
        bool: True if session file exists, False otherwise
    """
    sessions_path = (
        Path.home() / ".claude" / "projects" / f"-{str(project_root).replace('/', '-')}"
    )
    session_file = sessions_path / f"{session_id}.jsonl"
    return session_file.exists()


def list_user_sessions(project_root: Path) -> List[Dict[str, Any]]:
    """
    List all available Claude SDK sessions from file system.

    Args:
        project_root: Project root directory path

    Returns:
        List[Dict]: Session metadata including ID, size, and timestamps
    """
    sessions_path = (
        Path.home() / ".claude" / "projects" / f"-{str(project_root).replace('/', '-')}"
    )

    if not sessions_path.exists():
        return []

    sessions = []
    for session_file in sessions_path.glob("*.jsonl"):
        try:
            stat = session_file.stat()
            session_metadata = {
                "session_id": session_file.stem,
                "file_path": str(session_file),
                "file_size_bytes": stat.st_size,
                "created_at": datetime.fromtimestamp(stat.st_ctime).isoformat(),
                "modified_at": datetime.fromtimestamp(stat.st_mtime).isoformat(),
                "readable": session_file.is_file() and os.access(session_file, os.R_OK),
            }

            # Try to read first line for additional metadata
            try:
                with open(session_file, "r") as f:
                    first_line = f.readline().strip()
                    if first_line:
                        first_message = json.loads(first_line)
                        session_metadata["first_message_timestamp"] = first_message.get(
                            "timestamp"
                        )
                        session_metadata["initial_prompt"] = first_message.get(
                            "content", ""
                        )[:100]
            except (json.JSONDecodeError, IOError):
                session_metadata["parse_error"] = True

            sessions.append(session_metadata)

        except Exception as e:
            sessions.append(
                {
                    "session_id": session_file.stem,
                    "file_path": str(session_file),
                    "error": str(e),
                }
            )

    # Sort by modification time, newest first
    return sorted(sessions, key=lambda x: x.get("modified_at", ""), reverse=True)


def recover_session(session_id: str, project_root: Path) -> Dict[str, Any]:
    """
    Attempt to recover a session by checking file system and validating content.

    Args:
        session_id: Claude SDK session identifier
        project_root: Project root directory path

    Returns:
        Dict: Recovery result with status and diagnostic information
    """
    sessions_path = (
        Path.home() / ".claude" / "projects" / f"-{str(project_root).replace('/', '-')}"
    )
    session_file = sessions_path / f"{session_id}.jsonl"

    recovery_result = {
        "session_id": session_id,
        "project_root": str(project_root),
        "sessions_directory": str(sessions_path),
        "session_file_path": str(session_file),
        "exists": session_file.exists(),
        "recoverable": False,
        "diagnostics": {},
    }

    if not session_file.exists():
        recovery_result["diagnostics"]["error"] = "Session file does not exist"
        return recovery_result

    try:
        # Check file permissions
        recovery_result["diagnostics"]["readable"] = os.access(session_file, os.R_OK)
        recovery_result["diagnostics"]["writable"] = os.access(session_file, os.W_OK)

        # Get file stats
        stat = session_file.stat()
        recovery_result["diagnostics"]["file_size"] = stat.st_size
        recovery_result["diagnostics"]["created_at"] = datetime.fromtimestamp(
            stat.st_ctime
        ).isoformat()
        recovery_result["diagnostics"]["modified_at"] = datetime.fromtimestamp(
            stat.st_mtime
        ).isoformat()

        # Validate JSON content
        line_count = 0
        valid_lines = 0
        invalid_lines = []

        with open(session_file, "r") as f:
            for line_num, line in enumerate(f, 1):
                line_count += 1
                try:
                    json.loads(line.strip())
                    valid_lines += 1
                except json.JSONDecodeError as e:
                    invalid_lines.append({"line": line_num, "error": str(e)})

        recovery_result["diagnostics"]["total_lines"] = line_count
        recovery_result["diagnostics"]["valid_lines"] = valid_lines
        recovery_result["diagnostics"]["invalid_lines"] = invalid_lines

        # Session is recoverable if file exists, is readable, and has valid JSON
        recovery_result["recoverable"] = (
            recovery_result["diagnostics"]["readable"]
            and valid_lines > 0
            and len(invalid_lines) == 0
        )

    except Exception as e:
        recovery_result["diagnostics"]["validation_error"] = str(e)

    return recovery_result


def get_session_diagnostics(project_root: Path) -> Dict[str, Any]:
    """
    Get comprehensive session storage diagnostics for debugging.

    Args:
        project_root: Project root directory path

    Returns:
        Dict: Complete diagnostic information about session storage
    """
    claude_dir = Path.home() / ".claude"
    projects_dir = claude_dir / "projects"
    project_hash = f"-{str(project_root).replace('/', '-')}"
    project_sessions_dir = projects_dir / project_hash

    diagnostics = {
        "timestamp": datetime.utcnow().isoformat(),
        "project_root": str(project_root),
        "current_working_directory": str(Path.cwd()),
        "working_directory_correct": Path.cwd() == project_root,
        "claude_config": {
            "claude_dir": str(claude_dir),
            "claude_dir_exists": claude_dir.exists(),
            "projects_dir": str(projects_dir),
            "projects_dir_exists": projects_dir.exists(),
        },
        "project_sessions": {
            "project_hash": project_hash,
            "project_sessions_dir": str(project_sessions_dir),
            "project_sessions_dir_exists": project_sessions_dir.exists(),
            "session_files_count": 0,
            "session_files": [],
        },
        "permissions": {
            "claude_dir_writable": claude_dir.exists()
            and os.access(claude_dir, os.W_OK),
            "projects_dir_writable": projects_dir.exists()
            and os.access(projects_dir, os.W_OK),
        },
    }

    # Get session files information
    if project_sessions_dir.exists():
        session_files = list(project_sessions_dir.glob("*.jsonl"))
        diagnostics["project_sessions"]["session_files_count"] = len(session_files)

        for session_file in session_files[:10]:  # Limit to first 10 for performance
            try:
                stat = session_file.stat()
                file_info = {
                    "session_id": session_file.stem,
                    "file_size": stat.st_size,
                    "modified_at": datetime.fromtimestamp(stat.st_mtime).isoformat(),
                    "readable": os.access(session_file, os.R_OK),
                }
                diagnostics["project_sessions"]["session_files"].append(file_info)
            except Exception as e:
                diagnostics["project_sessions"]["session_files"].append(
                    {
                        "session_id": session_file.stem,
                        "error": str(e),
                    }
                )

    return diagnostics


def validate_session_storage_setup(project_root: Path) -> Tuple[bool, List[str]]:
    """
    Validate session storage setup and return issues if any.

    Args:
        project_root: Project root directory path

    Returns:
        Tuple[bool, List[str]]: (is_valid, list_of_issues)
    """
    issues = []

    # Check working directory
    if Path.cwd() != project_root:
        issues.append(f"Working directory mismatch: {Path.cwd()} != {project_root}")

    # Check Claude configuration directory
    claude_dir = Path.home() / ".claude"
    if not claude_dir.exists():
        issues.append(f"Claude configuration directory does not exist: {claude_dir}")
    elif not os.access(claude_dir, os.W_OK):
        issues.append(f"Claude configuration directory is not writable: {claude_dir}")

    # Check projects directory
    projects_dir = claude_dir / "projects"
    if not projects_dir.exists():
        issues.append(f"Claude projects directory does not exist: {projects_dir}")
    elif not os.access(projects_dir, os.W_OK):
        issues.append(f"Claude projects directory is not writable: {projects_dir}")

    # Check project-specific session directory
    project_hash = f"-{str(project_root).replace('/', '-')}"
    project_sessions_dir = projects_dir / project_hash
    if project_sessions_dir.exists() and not os.access(project_sessions_dir, os.W_OK):
        issues.append(
            f"Project sessions directory is not writable: {project_sessions_dir}"
        )

    return len(issues) == 0, issues


def cleanup_invalid_sessions(
    project_root: Path, dry_run: bool = True
) -> Dict[str, Any]:
    """
    Clean up invalid or corrupted session files.

    Args:
        project_root: Project root directory path
        dry_run: If True, only report what would be cleaned up without actually doing it

    Returns:
        Dict: Cleanup results with file counts and actions taken
    """
    sessions_path = (
        Path.home() / ".claude" / "projects" / f"-{str(project_root).replace('/', '-')}"
    )

    cleanup_result = {
        "dry_run": dry_run,
        "sessions_directory": str(sessions_path),
        "total_files": 0,
        "valid_files": 0,
        "invalid_files": 0,
        "empty_files": 0,
        "cleanup_actions": [],
    }

    if not sessions_path.exists():
        cleanup_result["error"] = "Sessions directory does not exist"
        return cleanup_result

    for session_file in sessions_path.glob("*.jsonl"):
        cleanup_result["total_files"] += 1

        try:
            stat = session_file.stat()

            # Check if file is empty
            if stat.st_size == 0:
                cleanup_result["empty_files"] += 1
                action = f"Remove empty file: {session_file.name}"
                cleanup_result["cleanup_actions"].append(action)

                if not dry_run:
                    session_file.unlink()
                continue

            # Validate JSON content
            is_valid = True
            with open(session_file, "r") as f:
                for line_num, line in enumerate(f, 1):
                    try:
                        json.loads(line.strip())
                    except json.JSONDecodeError:
                        is_valid = False
                        break

            if is_valid:
                cleanup_result["valid_files"] += 1
            else:
                cleanup_result["invalid_files"] += 1
                action = f"Remove corrupted file: {session_file.name}"
                cleanup_result["cleanup_actions"].append(action)

                if not dry_run:
                    session_file.unlink()

        except Exception as e:
            cleanup_result["cleanup_actions"].append(
                f"Error processing {session_file.name}: {e}"
            )

    return cleanup_result
