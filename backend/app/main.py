"""
FastAPI application entry point for Claude Code mobile backend.

Configures FastAPI application with CORS, middleware, exception handling,
and router registration for Claude Code mobile client support.
"""

import os
from datetime import datetime

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError

from app.api import claude
from app.models.responses import ErrorResponse, HealthResponse
from app.core.lifecycle import lifespan, verify_session_storage


# Create FastAPI application
app = FastAPI(
    title="Claude Code Mobile Backend",
    description="""
    FastAPI backend for Claude Code mobile client with real-time streaming support.

    Provides secure mobile access to Claude Code SDK functionality through
    REST API endpoints with Server-Sent Events (SSE) streaming.

    ## Features
    - 🔄 Real-time Claude response streaming via SSE
    - 📱 Mobile-optimized performance (<200ms response times)
    - 🗂️ Multiple concurrent session management
    - 💾 Session persistence across app launches
    - 🔒 CORS-enabled for iOS/macOS clients
    - 🐳 Docker-ready deployment

    ## Authentication
    Currently using user_id based authentication. Phase 2 will integrate
    OpenZiti zero-trust authentication with cryptographic device identity.
    """,
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
)

# CORS Configuration for iOS/mobile clients
# Configure origins based on environment
if os.getenv("ENVIRONMENT") == "production":
    allowed_origins = [
        "https://localhost:*",
        "capacitor://localhost",
        # Add your production domains here
    ]
else:
    # Development - allow all origins for easier testing
    allowed_origins = ["*"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
    expose_headers=["*"],
)


# Global exception handlers
@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    """Handle request validation errors with detailed response."""
    return JSONResponse(
        status_code=422,
        content=ErrorResponse(
            error="validation_error",
            message="Request validation failed",
            details={
                "errors": exc.errors(),
                "body": str(exc.body) if hasattr(exc, "body") else None,
            },
        ).model_dump(mode="json"),
    )


@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    """Handle HTTP exceptions with consistent error format."""
    return JSONResponse(
        status_code=exc.status_code,
        content=ErrorResponse(
            error="http_error",
            message=exc.detail,
            details={"status_code": exc.status_code},
        ).model_dump(mode="json"),
    )


@app.exception_handler(Exception)
async def general_exception_handler(request: Request, exc: Exception):
    """Handle unexpected exceptions with safe error response."""
    return JSONResponse(
        status_code=500,
        content=ErrorResponse(
            error="internal_error",
            message="An unexpected error occurred",
            details={"type": type(exc).__name__}
            if os.getenv("DEBUG") == "true"
            else None,
        ).model_dump(mode="json"),
    )


# Root endpoint
@app.get("/", response_model=HealthResponse)
async def root():
    """Root endpoint with service information."""
    return HealthResponse(
        status="healthy",
        timestamp=datetime.utcnow(),
        version="1.0.0",
        dependencies={
            "environment": os.getenv("ENVIRONMENT", "development"),
            "cors_origins": str(allowed_origins),
            "claude_sdk": "claude-code-sdk-shmaxi",
            "streaming": "sse-starlette",
        },
    )


# Health check endpoint
@app.get("/health", response_model=HealthResponse)
async def health(request: Request):
    """Comprehensive health check for monitoring and deployment."""
    # Get session storage verification if project_root is available
    session_info = {}
    if hasattr(request.app.state, "project_root"):
        try:
            session_verification = verify_session_storage(
                request.app.state.project_root
            )
            session_info = {
                "working_directory_correct": session_verification[
                    "working_directory_correct"
                ],
                "claude_sessions_dir_exists": session_verification[
                    "project_sessions_dir_exists"
                ],
                "session_files_count": session_verification["session_files_count"],
            }
        except Exception as e:
            session_info = {"session_verification_error": str(e)}

    return HealthResponse(
        status="healthy",
        timestamp=datetime.utcnow(),
        version="1.0.0",
        dependencies={
            "claude_sdk": "available",
            "streaming": "available",
            "sessions": "available",
            "session_storage": "available" if len(session_info) > 0 and not session_info.get("session_verification_error") else "error",
        },
    )


# Include API routers
app.include_router(claude.router)


# Development server info
if __name__ == "__main__":
    import uvicorn

    print("🔧 Running in development mode")
    print("📖 API Documentation: http://localhost:8000/docs")
    print("🔄 Interactive API: http://localhost:8000/redoc")

    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True, log_level="info")
