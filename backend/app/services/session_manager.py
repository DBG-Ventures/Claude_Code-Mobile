"""
SessionManager for persistent ClaudeSDKClient management.

Manages long-lived ClaudeSDKClient instances for conversation continuity,
eliminating session creation overhead and maintaining context across queries.
"""

import asyncio
import time
from typing import Dict, Optional
from datetime import datetime

from claude_code_sdk import ClaudeSDKClient
from claude_code_sdk.types import ClaudeCodeOptions

from app.utils.logging import StructuredLogger


class SessionManager:
    """
    Manages persistent ClaudeSDKClient instances for conversation continuity.

    Key Features:
    - Persistent client instances eliminate session creation overhead
    - Automatic cleanup of inactive sessions prevents resource leaks
    - Session validation and recovery for disconnected clients
    - Configurable timeout and cleanup intervals
    - Proper async lifecycle management
    """

    def __init__(self, session_timeout: int = 3600, cleanup_interval: int = 300):
        """
        Initialize SessionManager with configurable timeouts.

        Args:
            session_timeout: Session inactivity timeout in seconds (default: 1 hour)
            cleanup_interval: Cleanup task interval in seconds (default: 5 minutes)
        """
        self.active_sessions: Dict[str, Dict] = {}
        # Structure: {
        #   "session_id": {
        #       "client": ClaudeSDKClient,
        #       "working_dir": str,
        #       "last_used": float,
        #       "created_at": float,
        #       "user_id": str,
        #       "is_connected": bool
        #   }
        # }
        self.cleanup_task = None
        self.session_timeout = session_timeout
        self.cleanup_interval = cleanup_interval
        self.logger = StructuredLogger(__name__)

        self.logger.info(
            "SessionManager initialized",
            category="session_manager",
            operation="init",
            session_timeout=session_timeout,
            cleanup_interval=cleanup_interval,
        )

    async def get_or_create_session(
        self,
        session_id: str,
        working_dir: str,
        user_id: str,
        is_new_session: bool = False,
    ) -> ClaudeSDKClient:
        """
        Get existing persistent session client or create new one.

        Args:
            session_id: Claude SDK session ID
            working_dir: Working directory for session storage
            user_id: User identifier for session ownership
            is_new_session: Whether this is a new session creation

        Returns:
            ClaudeSDKClient: Persistent client instance

        Raises:
            RuntimeError: If client creation or connection fails
        """

        # Check if session exists and client is still valid
        if session_id in self.active_sessions:
            session_info = self.active_sessions[session_id]
            client = session_info["client"]

            # Validate client is still connected
            if await self._validate_client(client):
                session_info["last_used"] = time.time()
                self.logger.debug(
                    "Reusing existing session client",
                    category="session_manager",
                    operation="get_session",
                    session_id=session_id,
                    user_id=user_id,
                )
                return client
            else:
                self.logger.warning(
                    "Session client disconnected, recreating",
                    category="session_manager",
                    operation="client_validation_failed",
                    session_id=session_id,
                )
                # Client disconnected, clean up and recreate
                await self.cleanup_session(session_id)

        # Create new persistent client
        try:
            self.logger.info(
                "Creating new session client",
                category="session_manager",
                operation="create_session",
                session_id=session_id,
                user_id=user_id,
                working_dir=working_dir,
                is_new_session=is_new_session,
            )

            # Configure Claude SDK options for persistent session
            options = ClaudeCodeOptions(
                cwd=working_dir,
                permission_mode="bypassPermissions",
                resume=None if is_new_session else session_id,
            )

            client = ClaudeSDKClient(options)
            await client.connect()

            # For new sessions, get session ID from client after initialization
            if is_new_session:
                # Wait briefly for session initialization
                await asyncio.sleep(0.1)
                actual_session_id = getattr(client, "session_id", session_id)
                if actual_session_id and actual_session_id != session_id:
                    session_id = actual_session_id
                    self.logger.info(
                        "Updated session ID from client",
                        category="session_manager",
                        operation="session_id_update",
                        original_session_id=session_id,
                        actual_session_id=actual_session_id,
                    )

            # Store session info
            self.active_sessions[session_id] = {
                "client": client,
                "working_dir": working_dir,
                "user_id": user_id,
                "last_used": time.time(),
                "created_at": time.time(),
                "is_connected": True,
            }

            # Start cleanup task if not running
            if self.cleanup_task is None or self.cleanup_task.done():
                self.cleanup_task = asyncio.create_task(self._cleanup_loop())
                self.logger.info(
                    "Started session cleanup task",
                    category="session_manager",
                    operation="start_cleanup_task",
                )

            self.logger.info(
                "Session client created successfully",
                category="session_manager",
                operation="session_created",
                session_id=session_id,
                user_id=user_id,
                active_sessions_count=len(self.active_sessions),
            )

            return client

        except Exception as e:
            self.logger.error(
                f"Failed to create session client: {e}",
                category="session_manager",
                operation="create_session_failed",
                session_id=session_id,
                user_id=user_id,
                error=str(e),
            )
            raise RuntimeError(f"Failed to create session {session_id}: {e}")

    async def _validate_client(self, client: ClaudeSDKClient) -> bool:
        """
        Validate that ClaudeSDKClient is still connected and functional.

        Args:
            client: ClaudeSDKClient instance to validate

        Returns:
            bool: True if client is valid and connected, False otherwise
        """
        try:
            # Check if client has required attributes and is connected
            # This is a lightweight check without sending actual queries
            if not hasattr(client, "_session"):
                return False

            # Additional connection validation could be added here
            # For now, we assume if client has session attribute, it's valid
            return client._session is not None

        except Exception as e:
            self.logger.debug(
                f"Client validation failed: {e}",
                category="session_manager",
                operation="validate_client",
                error=str(e),
            )
            return False

    async def cleanup_session(self, session_id: str) -> bool:
        """
        Manually cleanup a specific session with proper client disconnect.

        Args:
            session_id: Session ID to cleanup

        Returns:
            bool: True if cleanup successful, False if session not found
        """
        if session_id not in self.active_sessions:
            self.logger.debug(
                "Session not found for cleanup",
                category="session_manager",
                operation="cleanup_session",
                session_id=session_id,
            )
            return False

        session_info = self.active_sessions[session_id]
        client = session_info["client"]
        user_id = session_info.get("user_id", "unknown")

        try:
            await client.disconnect()
            self.logger.info(
                "Session client disconnected",
                category="session_manager",
                operation="client_disconnect",
                session_id=session_id,
                user_id=user_id,
            )
        except Exception as e:
            self.logger.warning(
                f"Error disconnecting client during cleanup: {e}",
                category="session_manager",
                operation="cleanup_disconnect_error",
                session_id=session_id,
                error=str(e),
            )
            # Continue cleanup even if disconnect fails

        del self.active_sessions[session_id]

        self.logger.info(
            "Session cleaned up successfully",
            category="session_manager",
            operation="session_cleanup",
            session_id=session_id,
            user_id=user_id,
            active_sessions_count=len(self.active_sessions),
        )

        return True

    async def _cleanup_loop(self):
        """
        Periodically cleanup inactive sessions to prevent resource leaks.

        Runs continuously until cancelled, checking for inactive sessions
        based on the configured timeout and cleanup interval.
        """
        self.logger.info(
            "Session cleanup loop started",
            category="session_manager",
            operation="cleanup_loop_start",
            session_timeout=self.session_timeout,
            cleanup_interval=self.cleanup_interval,
        )

        try:
            while True:
                await asyncio.sleep(self.cleanup_interval)

                current_time = time.time()
                sessions_to_remove = []

                # Identify inactive sessions
                for session_id, session_info in self.active_sessions.items():
                    if current_time - session_info["last_used"] > self.session_timeout:
                        sessions_to_remove.append(session_id)

                # Cleanup inactive sessions
                if sessions_to_remove:
                    self.logger.info(
                        f"Cleaning up {len(sessions_to_remove)} inactive sessions",
                        category="session_manager",
                        operation="cleanup_inactive_sessions",
                        inactive_sessions=len(sessions_to_remove),
                        total_sessions=len(self.active_sessions),
                    )

                    for session_id in sessions_to_remove:
                        await self.cleanup_session(session_id)
                else:
                    self.logger.debug(
                        "No inactive sessions to cleanup",
                        category="session_manager",
                        operation="cleanup_check",
                        active_sessions=len(self.active_sessions),
                    )

        except asyncio.CancelledError:
            self.logger.info(
                "Session cleanup loop cancelled",
                category="session_manager",
                operation="cleanup_loop_cancelled",
            )
            raise
        except Exception as e:
            self.logger.error(
                f"Cleanup loop error: {e}",
                category="session_manager",
                operation="cleanup_loop_error",
                error=str(e),
            )
            # Continue running despite errors

    async def get_session_stats(self) -> Dict:
        """
        Get current session manager statistics.

        Returns:
            Dict: Statistics about active sessions and manager state
        """
        current_time = time.time()

        stats = {
            "active_sessions": len(self.active_sessions),
            "session_timeout_seconds": self.session_timeout,
            "cleanup_interval_seconds": self.cleanup_interval,
            "cleanup_task_running": (
                self.cleanup_task is not None and not self.cleanup_task.done()
            ),
            "timestamp": datetime.utcnow().isoformat(),
        }

        # Add session age statistics
        if self.active_sessions:
            session_ages = [
                current_time - session_info["created_at"]
                for session_info in self.active_sessions.values()
            ]

            stats.update(
                {
                    "oldest_session_age_seconds": max(session_ages),
                    "newest_session_age_seconds": min(session_ages),
                    "average_session_age_seconds": sum(session_ages)
                    / len(session_ages),
                }
            )

            # Count sessions by user
            user_counts = {}
            for session_info in self.active_sessions.values():
                user_id = session_info.get("user_id", "unknown")
                user_counts[user_id] = user_counts.get(user_id, 0) + 1

            stats["sessions_by_user"] = user_counts

        return stats

    async def shutdown(self):
        """
        Cleanup all sessions and stop cleanup task on application shutdown.

        Ensures graceful shutdown of all persistent clients and cleanup tasks.
        """
        self.logger.info(
            "SessionManager shutdown initiated",
            category="session_manager",
            operation="shutdown_start",
            active_sessions=len(self.active_sessions),
        )

        # Cancel cleanup task
        if self.cleanup_task and not self.cleanup_task.done():
            self.cleanup_task.cancel()
            try:
                await self.cleanup_task
            except asyncio.CancelledError:
                pass
            self.logger.info(
                "Cleanup task cancelled",
                category="session_manager",
                operation="cleanup_task_cancelled",
            )

        # Cleanup all active sessions
        session_ids = list(self.active_sessions.keys())
        for session_id in session_ids:
            await self.cleanup_session(session_id)

        self.logger.info(
            "SessionManager shutdown completed",
            category="session_manager",
            operation="shutdown_complete",
            cleaned_sessions=len(session_ids),
        )

    def get_active_session_ids(self) -> list:
        """
        Get list of currently active session IDs.

        Returns:
            list: List of active session IDs
        """
        return list(self.active_sessions.keys())

    def is_session_active(self, session_id: str) -> bool:
        """
        Check if a session is currently active.

        Args:
            session_id: Session ID to check

        Returns:
            bool: True if session is active, False otherwise
        """
        return session_id in self.active_sessions

    def get_session_user(self, session_id: str) -> Optional[str]:
        """
        Get the user ID associated with a session.

        Args:
            session_id: Session ID to lookup

        Returns:
            Optional[str]: User ID if session exists, None otherwise
        """
        session_info = self.active_sessions.get(session_id)
        return session_info.get("user_id") if session_info else None
