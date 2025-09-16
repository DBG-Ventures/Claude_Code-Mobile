"""
Session validation, recovery, and debugging utilities for Claude Code SDK integration.

Provides standalone functions for session management debugging and validation
that can be used independently or integrated into the ClaudeService, plus
SessionManager-aware utilities for enhanced session management.
"""

import json
import os
import time
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Any, Tuple

# Import for SessionManager integration
try:
    from claude_code_sdk import ClaudeSDKClient
    from app.utils.logging import StructuredLogger

    logger = StructuredLogger(__name__)
    SESSIONMANAGER_AVAILABLE = True
except ImportError:
    logger = None
    SESSIONMANAGER_AVAILABLE = False


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
        Path.home()
        / ".claude"
        / "projects"
        / f"-{str(project_root).replace('/', '-').replace('_', '-')}"
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
        Path.home()
        / ".claude"
        / "projects"
        / f"-{str(project_root).replace('/', '-').replace('_', '-')}"
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
        Path.home()
        / ".claude"
        / "projects"
        / f"-{str(project_root).replace('/', '-').replace('_', '-')}"
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
    project_hash = f"-{str(project_root).replace('/', '-').replace('_', '-')}"
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
    project_hash = f"-{str(project_root).replace('/', '-').replace('_', '-')}"
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
        Path.home()
        / ".claude"
        / "projects"
        / f"-{str(project_root).replace('/', '-').replace('_', '-')}"
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


# SessionManager-aware utilities (require SessionManager integration)


async def validate_session_client(client: ClaudeSDKClient) -> Dict[str, Any]:
    """
    Validate that a ClaudeSDKClient is healthy and functional.

    Args:
        client: ClaudeSDKClient instance to validate

    Returns:
        Dict with validation results and diagnostic information
    """
    if not SESSIONMANAGER_AVAILABLE:
        return {"error": "SessionManager utilities not available", "is_valid": False}

    validation_result = {
        "is_valid": False,
        "has_session": False,
        "is_connected": False,
        "session_id": None,
        "error": None,
        "timestamp": datetime.utcnow().isoformat(),
    }

    try:
        # Check if client has required attributes
        if not hasattr(client, "_session"):
            validation_result["error"] = "Client missing _session attribute"
            return validation_result

        validation_result["has_session"] = client._session is not None

        # Check if session ID is available
        if hasattr(client, "session_id"):
            validation_result["session_id"] = client.session_id

        # Check connection status
        validation_result["is_connected"] = client._session is not None

        # Overall validation
        validation_result["is_valid"] = (
            validation_result["has_session"] and validation_result["is_connected"]
        )

        if validation_result["is_valid"] and logger:
            logger.debug(
                "Session client validation successful",
                category="session_utils",
                operation="validate_client",
                session_id=validation_result["session_id"],
            )
        elif logger:
            logger.warning(
                "Session client validation failed",
                category="session_utils",
                operation="validate_client",
                validation_result=validation_result,
            )

    except Exception as e:
        validation_result["error"] = str(e)
        if logger:
            logger.error(
                f"Session client validation error: {e}",
                category="session_utils",
                operation="validate_client_error",
                error=str(e),
            )

    return validation_result


async def recover_session_with_manager(
    session_id: str,
    working_dir: str,
    session_manager,  # SessionManager type hint avoided for circular import
    force_reconnect: bool = False,
) -> Dict[str, Any]:
    """
    Attempt to recover a disconnected or problematic session using SessionManager.

    Args:
        session_id: Session ID to recover
        working_dir: Working directory for the session
        session_manager: SessionManager instance
        force_reconnect: Whether to force a reconnection

    Returns:
        Dict with recovery results and new client information
    """
    if not SESSIONMANAGER_AVAILABLE:
        return {"error": "SessionManager utilities not available", "success": False}

    recovery_result = {
        "success": False,
        "action_taken": None,
        "new_client_valid": False,
        "error": None,
        "timestamp": datetime.utcnow().isoformat(),
    }

    try:
        if logger:
            logger.info(
                "Attempting session recovery with SessionManager",
                category="session_utils",
                operation="recover_session",
                session_id=session_id,
                working_dir=working_dir,
                force_reconnect=force_reconnect,
            )

        # Check if session exists in SessionManager
        if session_manager.is_session_active(session_id):
            if force_reconnect:
                # Force cleanup and recreation
                await session_manager.cleanup_session(session_id)
                recovery_result["action_taken"] = "forced_cleanup_and_recreate"
            else:
                recovery_result["action_taken"] = "session_already_active"
                recovery_result["success"] = True
                return recovery_result

        # Attempt to create/recreate session
        try:
            user_id = session_manager.get_session_user(session_id) or "recovery_user"
            client = await session_manager.get_or_create_session(
                session_id=session_id,
                working_dir=working_dir,
                user_id=user_id,
                is_new_session=False,
            )

            # Validate the recovered client
            validation_result = await validate_session_client(client)
            recovery_result["new_client_valid"] = validation_result["is_valid"]

            if validation_result["is_valid"]:
                recovery_result["success"] = True
                recovery_result["action_taken"] = "session_recreated"
                if logger:
                    logger.info(
                        "Session recovery successful with SessionManager",
                        category="session_utils",
                        operation="recover_session_success",
                        session_id=session_id,
                    )
            else:
                recovery_result["error"] = (
                    f"Recovered client failed validation: {validation_result['error']}"
                )

        except Exception as create_error:
            recovery_result["error"] = (
                f"Failed to recreate session: {str(create_error)}"
            )

    except Exception as e:
        recovery_result["error"] = str(e)
        if logger:
            logger.error(
                f"Session recovery failed: {e}",
                category="session_utils",
                operation="recover_session_error",
                session_id=session_id,
                error=str(e),
            )

    return recovery_result


def get_combined_session_stats(session_manager, session_storage) -> Dict[str, Any]:
    """
    Get comprehensive session statistics combining SessionManager and storage data.

    Args:
        session_manager: SessionManager instance
        session_storage: PersistentSessionStorage instance

    Returns:
        Dict with detailed session statistics
    """
    if not SESSIONMANAGER_AVAILABLE:
        return {"error": "SessionManager utilities not available"}

    try:
        # Get SessionManager stats
        manager_stats = {
            "active_sessions": len(session_manager.active_sessions),
            "session_timeout": session_manager.session_timeout,
            "cleanup_interval": session_manager.cleanup_interval,
            "cleanup_task_running": (
                session_manager.cleanup_task is not None
                and not session_manager.cleanup_task.done()
            ),
        }

        # Get storage stats
        storage_stats = session_storage.get_storage_stats()

        # Calculate session health metrics
        current_time = time.time()
        session_ages = []
        active_sessions_detail = []

        for session_id, session_info in session_manager.active_sessions.items():
            age = current_time - session_info["created_at"]
            last_used_ago = current_time - session_info["last_used"]

            session_ages.append(age)
            active_sessions_detail.append(
                {
                    "session_id": session_id[:8] + "...",  # Truncated for privacy
                    "user_id": session_info.get("user_id", "unknown"),
                    "age_seconds": age,
                    "last_used_ago_seconds": last_used_ago,
                    "working_dir": session_info.get("working_dir", "unknown"),
                }
            )

        # Health metrics
        health_metrics = {
            "oldest_session_age_seconds": max(session_ages) if session_ages else 0,
            "newest_session_age_seconds": min(session_ages) if session_ages else 0,
            "average_session_age_seconds": sum(session_ages) / len(session_ages)
            if session_ages
            else 0,
            "sessions_near_timeout": len(
                [
                    age
                    for age in session_ages
                    if (current_time - manager_stats["session_timeout"])
                    < age
                    < current_time
                ]
            ),
        }

        combined_stats = {
            "timestamp": datetime.utcnow().isoformat(),
            "session_manager": manager_stats,
            "session_storage": storage_stats,
            "health_metrics": health_metrics,
            "active_sessions_detail": active_sessions_detail,
        }

        if logger:
            logger.debug(
                "Generated combined session statistics",
                category="session_utils",
                operation="get_combined_session_stats",
                active_sessions=manager_stats["active_sessions"],
                storage_sessions=storage_stats.get("total_sessions", 0),
            )

        return combined_stats

    except Exception as e:
        if logger:
            logger.error(
                f"Failed to get combined session stats: {e}",
                category="session_utils",
                operation="get_combined_session_stats_error",
                error=str(e),
            )
        return {"error": str(e), "timestamp": datetime.utcnow().isoformat()}


async def cleanup_orphaned_sessions(
    session_manager, session_storage, dry_run: bool = True
) -> Dict[str, Any]:
    """
    Identify and optionally cleanup orphaned sessions between SessionManager and storage.

    Args:
        session_manager: SessionManager instance
        session_storage: PersistentSessionStorage instance
        dry_run: If True, only identify orphaned sessions without cleanup

    Returns:
        Dict with cleanup results
    """
    if not SESSIONMANAGER_AVAILABLE:
        return {"error": "SessionManager utilities not available"}

    cleanup_result = {
        "orphaned_in_manager": [],
        "orphaned_in_storage": [],
        "cleaned_up": [],
        "errors": [],
        "dry_run": dry_run,
        "timestamp": datetime.utcnow().isoformat(),
    }

    try:
        # Get active sessions from SessionManager
        active_session_ids = set(session_manager.get_active_session_ids())

        # Get sessions from storage
        storage_data = session_storage._read_storage()
        storage_session_ids = set(storage_data.keys())

        # Find orphaned sessions
        orphaned_in_manager = active_session_ids - storage_session_ids
        orphaned_in_storage = storage_session_ids - active_session_ids

        cleanup_result["orphaned_in_manager"] = list(orphaned_in_manager)
        cleanup_result["orphaned_in_storage"] = list(orphaned_in_storage)

        if not dry_run:
            # Cleanup orphaned sessions in SessionManager
            for session_id in orphaned_in_manager:
                try:
                    await session_manager.cleanup_session(session_id)
                    cleanup_result["cleaned_up"].append(f"manager:{session_id}")
                except Exception as e:
                    cleanup_result["errors"].append(
                        f"Failed to cleanup {session_id} from manager: {str(e)}"
                    )

            # Cleanup orphaned sessions in storage
            for session_id in orphaned_in_storage:
                try:
                    session_storage.remove_session(session_id)
                    cleanup_result["cleaned_up"].append(f"storage:{session_id}")
                except Exception as e:
                    cleanup_result["errors"].append(
                        f"Failed to cleanup {session_id} from storage: {str(e)}"
                    )

        if logger:
            logger.info(
                "Orphaned session cleanup completed",
                category="session_utils",
                operation="cleanup_orphaned_sessions",
                dry_run=dry_run,
                orphaned_manager=len(orphaned_in_manager),
                orphaned_storage=len(orphaned_in_storage),
                cleaned_up=len(cleanup_result["cleaned_up"]),
            )

    except Exception as e:
        cleanup_result["errors"].append(str(e))
        if logger:
            logger.error(
                f"Orphaned session cleanup error: {e}",
                category="session_utils",
                operation="cleanup_orphaned_sessions_error",
                error=str(e),
            )

    return cleanup_result


def generate_session_health_report(session_manager, session_storage) -> Dict[str, Any]:
    """
    Generate a comprehensive session health report for debugging.

    Args:
        session_manager: SessionManager instance
        session_storage: PersistentSessionStorage instance

    Returns:
        Dict with comprehensive health report
    """
    if not SESSIONMANAGER_AVAILABLE:
        return {"error": "SessionManager utilities not available"}

    try:
        # Get basic stats
        stats = get_combined_session_stats(session_manager, session_storage)

        # Add health assessment
        health_report = {
            "overall_health": "unknown",
            "issues": [],
            "recommendations": [],
            "stats": stats,
            "timestamp": datetime.utcnow().isoformat(),
        }

        # Assess overall health
        active_sessions = stats["session_manager"]["active_sessions"]
        cleanup_running = stats["session_manager"]["cleanup_task_running"]

        issues = []
        recommendations = []

        # Check for issues
        if not cleanup_running:
            issues.append(
                "Cleanup task not running - sessions may not be cleaned up automatically"
            )
            recommendations.append("Restart SessionManager or check for task failures")

        if active_sessions > 50:
            issues.append(
                f"High number of active sessions ({active_sessions}) - potential memory concern"
            )
            recommendations.append(
                "Consider reducing session timeout or investigating session leaks"
            )

        if stats["health_metrics"]["sessions_near_timeout"] > 10:
            issues.append(
                "Many sessions approaching timeout - possible client inactivity"
            )
            recommendations.append(
                "Review session timeout configuration and client usage patterns"
            )

        # Determine overall health
        if not issues:
            health_report["overall_health"] = "healthy"
        elif len(issues) <= 2:
            health_report["overall_health"] = "warning"
        else:
            health_report["overall_health"] = "critical"

        health_report["issues"] = issues
        health_report["recommendations"] = recommendations

        if logger:
            logger.info(
                "Generated session health report",
                category="session_utils",
                operation="generate_health_report",
                overall_health=health_report["overall_health"],
                issues_count=len(issues),
            )

        return health_report

    except Exception as e:
        if logger:
            logger.error(
                f"Failed to generate health report: {e}",
                category="session_utils",
                operation="generate_health_report_error",
                error=str(e),
            )
        return {
            "overall_health": "error",
            "error": str(e),
            "timestamp": datetime.utcnow().isoformat(),
        }
