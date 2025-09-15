"""
Configuration management for Claude Code mobile backend.

Environment-based configuration using Pydantic settings for type safety
and validation.
"""

from typing import List, Optional
from pydantic import Field
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """
    Application settings with environment variable support.

    Supports both HTTP and OpenZiti networking modes with secure defaults.
    """

    # Application settings
    app_name: str = Field("Claude Code Mobile Backend", description="Application name")
    app_version: str = Field("1.0.0", description="Application version")
    environment: str = Field(
        "development", description="Environment (development/production)"
    )
    debug: bool = Field(False, description="Enable debug mode")

    # Server settings
    host: str = Field("0.0.0.0", description="Server bind host")
    port: int = Field(8000, description="Server bind port")
    workers: int = Field(1, description="Number of worker processes")

    # CORS settings
    cors_origins: List[str] = Field(
        default=["*"], description="Allowed CORS origins for mobile clients"
    )
    cors_allow_credentials: bool = Field(True, description="Allow CORS credentials")

    # Claude Code SDK settings
    claude_api_key: Optional[str] = Field(None, description="Claude API key")
    claude_model: str = Field(
        "claude-3-5-sonnet-20241022", description="Default Claude model"
    )
    claude_max_tokens: int = Field(8192, description="Default max tokens")
    claude_temperature: float = Field(0.7, description="Default temperature")
    claude_timeout: int = Field(60, description="Claude request timeout")

    # Session management
    max_sessions_per_user: int = Field(10, description="Maximum sessions per user")
    session_timeout: int = Field(3600, description="Session timeout in seconds")
    message_history_limit: int = Field(100, description="Max messages per session")

    # Networking mode configuration
    networking_mode: str = Field("http", description="Networking mode (http/ziti)")

    # OpenZiti settings (Phase 2)
    ziti_identity_file: Optional[str] = Field(
        None, description="Ziti identity file path"
    )
    ziti_service_name: Optional[str] = Field(
        "claude-api", description="Ziti service name"
    )

    # Security settings
    rate_limit_requests: int = Field(100, description="Rate limit per minute")
    rate_limit_window: int = Field(60, description="Rate limit window in seconds")

    # Logging settings
    log_level: str = Field("INFO", description="Logging level")
    log_format: str = Field("json", description="Log format (json/text)")

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = False

    @property
    def is_development(self) -> bool:
        """Check if running in development mode."""
        return self.environment.lower() == "development"

    @property
    def is_production(self) -> bool:
        """Check if running in production mode."""
        return self.environment.lower() == "production"

    @property
    def is_ziti_enabled(self) -> bool:
        """Check if OpenZiti networking is enabled."""
        return (
            self.networking_mode.lower() == "ziti"
            and self.ziti_identity_file is not None
        )

    def get_cors_origins(self) -> List[str]:
        """Get CORS origins based on environment."""
        if self.is_production:
            # Production: specific origins only
            return [
                "https://localhost:*",
                "capacitor://localhost",
                # Add production domains
            ]
        else:
            # Development: allow all for easier testing
            return ["*"]


# Global settings instance
settings = Settings()


def get_settings() -> Settings:
    """Get application settings instance."""
    return settings
