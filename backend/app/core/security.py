"""
Security and authentication configuration for Claude Code mobile backend.

Provides authentication, rate limiting, and security middleware setup.
Phase 1: Simple user_id based authentication
Phase 2: OpenZiti cryptographic device identity
"""

import time
from typing import Dict, Optional

from fastapi import Request, HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from app.core.config import get_settings, Settings


# Rate limiting storage (in-memory for development)
# In production, use Redis or similar distributed storage
_rate_limit_storage: Dict[str, Dict[str, int]] = {}


class RateLimiter:
    """
    Simple in-memory rate limiter for API protection.

    In production, replace with Redis-based distributed rate limiting.
    """

    def __init__(self, requests_per_minute: int = 100):
        self.requests_per_minute = requests_per_minute
        self.window_seconds = 60

    def is_allowed(self, identifier: str) -> bool:
        """Check if request is allowed based on rate limit."""
        current_time = int(time.time())
        window_start = current_time - self.window_seconds

        # Initialize storage for identifier if not exists
        if identifier not in _rate_limit_storage:
            _rate_limit_storage[identifier] = {}

        user_requests = _rate_limit_storage[identifier]

        # Clean old entries
        for timestamp in list(user_requests.keys()):
            if int(timestamp) < window_start:
                del user_requests[timestamp]

        # Count current window requests
        current_requests = sum(user_requests.values())

        if current_requests >= self.requests_per_minute:
            return False

        # Record this request
        current_minute = str(current_time // 60 * 60)
        user_requests[current_minute] = user_requests.get(current_minute, 0) + 1

        return True


# Global rate limiter instance
rate_limiter = RateLimiter()


class SimpleAuth:
    """
    Simple authentication system for Phase 1.

    Uses user_id based authentication. Phase 2 will integrate OpenZiti
    cryptographic device identity for zero-trust authentication.
    """

    def __init__(self):
        self.bearer = HTTPBearer(auto_error=False)

    async def authenticate_user(
        self,
        request: Request,
        credentials: Optional[HTTPAuthorizationCredentials] = None,
    ) -> str:
        """
        Authenticate user and return user_id.

        Phase 1: Simple user_id extraction from Authorization header or query param
        Phase 2: OpenZiti cryptographic identity verification
        """
        user_id = None

        # Try to get user_id from Authorization header
        if credentials and credentials.credentials:
            # Simple format: "Bearer user_id"
            user_id = credentials.credentials

        # Fallback: get from query parameter
        if not user_id:
            user_id = request.query_params.get("user_id")

        # Fallback: get from headers
        if not user_id:
            user_id = request.headers.get("X-User-ID")

        if not user_id:
            raise HTTPException(
                status_code=401,
                detail="Authentication required. Provide user_id via Authorization header, X-User-ID header, or user_id query parameter.",
            )

        # Validate user_id format (basic validation)
        if len(user_id) < 3 or len(user_id) > 100:
            raise HTTPException(status_code=401, detail="Invalid user_id format")

        return user_id

    async def get_current_user(
        self,
        request: Request,
        credentials: Optional[HTTPAuthorizationCredentials] = Depends(
            HTTPBearer(auto_error=False)
        ),
    ) -> str:
        """FastAPI dependency to get current authenticated user."""
        return await self.authenticate_user(request, credentials)


# Global auth instance
auth = SimpleAuth()


def check_rate_limit(request: Request, settings: Settings = Depends(get_settings)):
    """
    Rate limiting middleware dependency.

    Checks request rate limits and raises HTTPException if exceeded.
    """
    # Get client identifier (IP address for now)
    client_ip = request.client.host if request.client else "unknown"

    # Use user_id if available for more accurate rate limiting
    user_id = request.query_params.get("user_id") or request.headers.get("X-User-ID")
    identifier = user_id if user_id else client_ip

    if not rate_limiter.is_allowed(identifier):
        raise HTTPException(
            status_code=429,
            detail=f"Rate limit exceeded. Maximum {settings.rate_limit_requests} requests per minute.",
        )


class OpenZitiAuth:
    """
    OpenZiti cryptographic authentication for Phase 2.

    Provides zero-trust device identity verification using OpenZiti SDK.
    """

    def __init__(self):
        self.enabled = False  # Will be enabled in Phase 2

    async def verify_ziti_identity(self, request: Request) -> Dict[str, str]:
        """
        Verify OpenZiti device identity from request.

        Phase 2 implementation will:
        1. Extract Ziti identity from request headers
        2. Verify cryptographic signatures
        3. Return identity attributes (user_id, device_id, etc.)
        """
        if not self.enabled:
            raise HTTPException(
                status_code=501,
                detail="OpenZiti authentication not yet implemented (Phase 2)",
            )

        # Phase 2 implementation placeholder
        return {"user_id": "ziti_user", "device_id": "ziti_device"}


# OpenZiti auth instance (Phase 2)
ziti_auth = OpenZitiAuth()


def get_auth_dependencies(settings: Settings = Depends(get_settings)):
    """
    Get authentication dependencies based on networking mode.

    Returns appropriate auth system for current configuration.
    """
    if settings.is_ziti_enabled:
        # Phase 2: OpenZiti authentication
        return ziti_auth
    else:
        # Phase 1: Simple authentication
        return auth


# Security headers middleware
def add_security_headers(response):
    """Add security headers to response."""
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Strict-Transport-Security"] = (
        "max-age=31536000; includeSubDomains"
    )
    return response
