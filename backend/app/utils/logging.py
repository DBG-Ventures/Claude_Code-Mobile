"""
Centralized logging utilities for Claude Code Mobile Backend.

Provides structured logging with consistent formatting and context management
for debugging session management and Claude SDK interactions.
"""

import logging
import sys
from typing import Dict, Any, Optional
from pythonjsonlogger import jsonlogger

from app.core.config import get_settings

settings = get_settings()


class ContextualFilter(logging.Filter):
    """Add contextual information to log records."""

    def filter(self, record: logging.LogRecord) -> bool:
        # Add default context if not present
        if not hasattr(record, "category"):
            record.category = "general"
        if not hasattr(record, "session_id"):
            record.session_id = None
        if not hasattr(record, "user_id"):
            record.user_id = None
        if not hasattr(record, "operation"):
            record.operation = None

        return True


def setup_logging() -> None:
    """Configure application-wide logging."""

    # Clear any existing handlers
    root_logger = logging.getLogger()
    for handler in root_logger.handlers[:]:
        root_logger.removeHandler(handler)

    # Create formatter based on configuration
    if settings.log_format.lower() == "json":
        formatter = jsonlogger.JsonFormatter(
            fmt="%(asctime)s %(name)s %(levelname)s %(category)s %(message)s %(session_id)s %(user_id)s %(operation)s",
            datefmt="%Y-%m-%dT%H:%M:%SZ",
        )
    else:
        formatter = logging.Formatter(
            fmt="%(asctime)s [%(levelname)s] %(category)s: %(message)s",
            datefmt="%Y-%m-%d %H:%M:%S",
        )

    # Create and configure handler
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(formatter)
    handler.addFilter(ContextualFilter())

    # Configure root logger
    root_logger.addHandler(handler)
    root_logger.setLevel(getattr(logging, settings.log_level.upper()))

    # Quiet down noisy libraries in production
    if settings.is_production:
        logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
        logging.getLogger("httpx").setLevel(logging.WARNING)


def get_logger(name: str) -> logging.Logger:
    """Get a logger instance with the given name."""
    return logging.getLogger(name)


class LogContext:
    """Context manager for adding structured context to logs."""

    def __init__(self, logger: logging.Logger, **context: Any):
        self.logger = logger
        self.context = context
        self.old_extra = getattr(logger, "_extra_context", {})

    def __enter__(self):
        # Merge with existing context
        merged_context = {**self.old_extra, **self.context}
        self.logger._extra_context = merged_context
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.logger._extra_context = self.old_extra


class StructuredLogger:
    """Enhanced logger with structured logging capabilities."""

    def __init__(self, name: str):
        self.logger = get_logger(name)
        self._extra_context: Dict[str, Any] = {}

    def _log(self, level: int, message: str, **kwargs) -> None:
        """Internal log method with context merging."""
        extra = {**self._extra_context, **kwargs}
        self.logger.log(level, message, extra=extra)

    def debug(self, message: str, **context) -> None:
        """Log debug message with context."""
        self._log(logging.DEBUG, message, **context)

    def info(self, message: str, **context) -> None:
        """Log info message with context."""
        self._log(logging.INFO, message, **context)

    def warning(self, message: str, **context) -> None:
        """Log warning message with context."""
        self._log(logging.WARNING, message, **context)

    def error(self, message: str, **context) -> None:
        """Log error message with context."""
        self._log(logging.ERROR, message, **context)

    def critical(self, message: str, **context) -> None:
        """Log critical message with context."""
        self._log(logging.CRITICAL, message, **context)

    def with_context(self, **context) -> LogContext:
        """Create a context manager for structured logging."""
        return LogContext(self, **context)


# Convenience functions for common log categories
def log_session_event(
    logger: StructuredLogger,
    message: str,
    session_id: str,
    user_id: str,
    operation: str,
    level: str = "info",
    **extra,
) -> None:
    """Log a session management event."""
    method = getattr(logger, level.lower())
    method(
        message,
        category="session_management",
        session_id=session_id,
        user_id=user_id,
        operation=operation,
        **extra,
    )


def log_claude_sdk_event(
    logger: StructuredLogger,
    message: str,
    session_id: str,
    operation: str,
    level: str = "info",
    **extra,
) -> None:
    """Log a Claude SDK interaction event."""
    method = getattr(logger, level.lower())
    method(
        message,
        category="claude_sdk",
        session_id=session_id,
        operation=operation,
        **extra,
    )


def log_streaming_event(
    logger: StructuredLogger,
    message: str,
    session_id: str,
    chunk_type: str,
    level: str = "debug",
    **extra,
) -> None:
    """Log a streaming event."""
    method = getattr(logger, level.lower())
    method(
        message,
        category="streaming",
        session_id=session_id,
        chunk_type=chunk_type,
        **extra,
    )


def log_networking_event(
    logger: StructuredLogger,
    message: str,
    endpoint: str,
    status_code: Optional[int] = None,
    level: str = "info",
    **extra,
) -> None:
    """Log a networking event."""
    method = getattr(logger, level.lower())
    method(
        message,
        category="networking",
        endpoint=endpoint,
        status_code=status_code,
        **extra,
    )


def log_performance_event(
    logger: StructuredLogger,
    message: str,
    operation: str,
    duration_ms: float,
    level: str = "info",
    **extra,
) -> None:
    """Log a performance measurement."""
    method = getattr(logger, level.lower())
    method(
        message,
        category="performance",
        operation=operation,
        duration_ms=duration_ms,
        **extra,
    )
