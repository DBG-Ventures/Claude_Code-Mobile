"""
Persistent session metadata storage for Claude Code Mobile backend.

Provides file-based storage for session metadata that persists across server restarts,
enabling proper Claude SDK session resumption by maintaining working directory context.
"""

import json
from datetime import datetime
from pathlib import Path
from typing import Dict, Optional, Any
from threading import Lock

from app.utils.logging import StructuredLogger


class PersistentSessionStorage:
    """
    File-based session metadata storage that persists across server restarts.

    Stores session metadata (working directories, user IDs) in a JSON file
    to enable proper Claude SDK session resumption.
    """

    def __init__(self, storage_file: Path):
        self.storage_file = storage_file
        self.logger = StructuredLogger(__name__)
        self._lock = Lock()  # Thread safety for file operations

        # Ensure storage directory exists
        self.storage_file.parent.mkdir(parents=True, exist_ok=True)

        # Load existing sessions or create empty storage
        self._ensure_storage_file()

        self.logger.info(
            "Persistent session storage initialized",
            category="session_storage",
            operation="init",
            storage_file=str(self.storage_file),
        )

    def _ensure_storage_file(self):
        """Ensure the storage file exists with valid JSON structure."""
        try:
            if not self.storage_file.exists():
                self._write_storage({})
                self.logger.info(
                    "Created new session storage file",
                    category="session_storage",
                    operation="create_storage_file",
                    storage_file=str(self.storage_file),
                )
            else:
                # Validate existing file
                self._read_storage()
                self.logger.info(
                    "Loaded existing session storage",
                    category="session_storage",
                    operation="load_storage_file",
                    storage_file=str(self.storage_file),
                )
        except Exception as e:
            self.logger.error(
                f"Failed to initialize storage file: {e}",
                category="session_storage",
                operation="init_storage_file",
                error=str(e),
            )
            # Create new file if corrupted
            self._write_storage({})

    def _read_storage(self) -> Dict[str, Any]:
        """Read session data from storage file."""
        try:
            with open(self.storage_file, "r") as f:
                return json.load(f)
        except (json.JSONDecodeError, FileNotFoundError) as e:
            self.logger.warning(
                f"Failed to read storage file, using empty storage: {e}",
                category="session_storage",
                operation="read_storage",
                error=str(e),
            )
            return {}

    def _write_storage(self, data: Dict[str, Any]):
        """Write session data to storage file."""
        try:
            # Write to temporary file first, then atomic rename
            temp_file = self.storage_file.with_suffix(".tmp")
            with open(temp_file, "w") as f:
                json.dump(data, f, indent=2, default=str)

            # Atomic rename
            temp_file.replace(self.storage_file)

        except Exception as e:
            self.logger.error(
                f"Failed to write storage file: {e}",
                category="session_storage",
                operation="write_storage",
                error=str(e),
            )
            raise

    def store_session(
        self,
        session_id: str,
        user_id: str,
        working_directory: str,
        session_name: str = None,
        created_at: datetime = None,
    ) -> bool:
        """
        Store session metadata persistently.

        Args:
            session_id: Claude SDK session ID
            user_id: User identifier
            working_directory: Working directory for the session
            session_name: Optional session name
            created_at: Session creation timestamp

        Returns:
            bool: True if successful, False otherwise
        """
        try:
            with self._lock:
                data = self._read_storage()

                session_metadata = {
                    "session_id": session_id,
                    "user_id": user_id,
                    "working_directory": working_directory,
                    "session_name": session_name or f"Session {session_id[:8]}",
                    "created_at": (created_at or datetime.utcnow()).isoformat(),
                    "updated_at": datetime.utcnow().isoformat(),
                }

                data[session_id] = session_metadata
                self._write_storage(data)

                self.logger.info(
                    "Session metadata stored",
                    category="session_storage",
                    operation="store_session",
                    session_id=session_id,
                    user_id=user_id,
                    working_directory=working_directory,
                )

                return True

        except Exception as e:
            self.logger.error(
                f"Failed to store session metadata: {e}",
                category="session_storage",
                operation="store_session",
                session_id=session_id,
                user_id=user_id,
                error=str(e),
            )
            return False

    def get_session(self, session_id: str) -> Optional[Dict[str, Any]]:
        """
        Retrieve session metadata by session ID.

        Args:
            session_id: Claude SDK session ID

        Returns:
            Dict containing session metadata or None if not found
        """
        try:
            with self._lock:
                data = self._read_storage()
                session_metadata = data.get(session_id)

                if session_metadata:
                    self.logger.debug(
                        "Session metadata retrieved",
                        category="session_storage",
                        operation="get_session",
                        session_id=session_id,
                    )
                else:
                    self.logger.debug(
                        "Session metadata not found",
                        category="session_storage",
                        operation="get_session",
                        session_id=session_id,
                    )

                return session_metadata

        except Exception as e:
            self.logger.error(
                f"Failed to retrieve session metadata: {e}",
                category="session_storage",
                operation="get_session",
                session_id=session_id,
                error=str(e),
            )
            return None

    def list_user_sessions(
        self, user_id: str, limit: int = 10, offset: int = 0
    ) -> list:
        """
        List sessions for a specific user.

        Args:
            user_id: User identifier
            limit: Maximum number of sessions to return
            offset: Pagination offset

        Returns:
            List of session metadata dictionaries
        """
        try:
            with self._lock:
                data = self._read_storage()

                # Filter sessions by user_id
                user_sessions = []
                for session_id, session_metadata in data.items():
                    if session_metadata.get("user_id") == user_id:
                        user_sessions.append(session_metadata)

                # Sort by creation time (newest first)
                user_sessions.sort(key=lambda s: s.get("created_at", ""), reverse=True)

                # Apply pagination
                paginated_sessions = user_sessions[offset : offset + limit]

                self.logger.debug(
                    f"Found {len(user_sessions)} sessions for user, returning {len(paginated_sessions)}",
                    category="session_storage",
                    operation="list_user_sessions",
                    user_id=user_id,
                    total_sessions=len(user_sessions),
                    returned_sessions=len(paginated_sessions),
                )

                return paginated_sessions

        except Exception as e:
            self.logger.error(
                f"Failed to list user sessions: {e}",
                category="session_storage",
                operation="list_user_sessions",
                user_id=user_id,
                error=str(e),
            )
            return []

    def remove_session(self, session_id: str) -> bool:
        """
        Remove session metadata.

        Args:
            session_id: Claude SDK session ID

        Returns:
            bool: True if removed or didn't exist, False on error
        """
        try:
            with self._lock:
                data = self._read_storage()

                if session_id in data:
                    del data[session_id]
                    self._write_storage(data)

                    self.logger.info(
                        "Session metadata removed",
                        category="session_storage",
                        operation="remove_session",
                        session_id=session_id,
                    )

                return True

        except Exception as e:
            self.logger.error(
                f"Failed to remove session metadata: {e}",
                category="session_storage",
                operation="remove_session",
                session_id=session_id,
                error=str(e),
            )
            return False

    def cleanup_old_sessions(self, max_age_days: int = 30) -> int:
        """
        Remove session metadata older than specified days.

        Args:
            max_age_days: Maximum age in days

        Returns:
            int: Number of sessions cleaned up
        """
        try:
            from datetime import timedelta

            cutoff_date = datetime.utcnow() - timedelta(days=max_age_days)

            with self._lock:
                data = self._read_storage()
                sessions_to_remove = []

                for session_id, session_metadata in data.items():
                    created_at_str = session_metadata.get("created_at")
                    if created_at_str:
                        try:
                            created_at = datetime.fromisoformat(
                                created_at_str.replace("Z", "+00:00")
                            )
                            if created_at < cutoff_date:
                                sessions_to_remove.append(session_id)
                        except (ValueError, TypeError):
                            # Invalid date format, consider for removal
                            sessions_to_remove.append(session_id)

                # Remove old sessions
                for session_id in sessions_to_remove:
                    del data[session_id]

                if sessions_to_remove:
                    self._write_storage(data)

                self.logger.info(
                    f"Cleaned up {len(sessions_to_remove)} old sessions",
                    category="session_storage",
                    operation="cleanup_old_sessions",
                    cleaned_count=len(sessions_to_remove),
                    max_age_days=max_age_days,
                )

                return len(sessions_to_remove)

        except Exception as e:
            self.logger.error(
                f"Failed to cleanup old sessions: {e}",
                category="session_storage",
                operation="cleanup_old_sessions",
                error=str(e),
            )
            return 0

    def get_storage_stats(self) -> Dict[str, Any]:
        """
        Get storage statistics.

        Returns:
            Dict with storage statistics
        """
        try:
            with self._lock:
                data = self._read_storage()

                stats = {
                    "total_sessions": len(data),
                    "storage_file": str(self.storage_file),
                    "file_exists": self.storage_file.exists(),
                    "file_size_bytes": self.storage_file.stat().st_size
                    if self.storage_file.exists()
                    else 0,
                }

                # User count
                users = set()
                for session_metadata in data.values():
                    user_id = session_metadata.get("user_id")
                    if user_id:
                        users.add(user_id)

                stats["unique_users"] = len(users)

                return stats

        except Exception as e:
            self.logger.error(
                f"Failed to get storage stats: {e}",
                category="session_storage",
                operation="get_storage_stats",
                error=str(e),
            )
            return {"error": str(e)}
