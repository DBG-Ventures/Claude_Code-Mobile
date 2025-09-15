# Multi-stage Docker build for Claude Code Mobile Backend
# Optimized for production deployment with minimal attack surface

# Build stage
FROM python:3.11-slim as builder

# Set build arguments
ARG DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Set work directory
WORKDIR /app

# Copy requirements first for better layer caching
COPY requirements.txt .

# Create virtual environment and install dependencies
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Upgrade pip and install dependencies
RUN pip install --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Production stage
FROM python:3.11-slim as production

# Set production environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH" \
    ENVIRONMENT=production

# Create non-root user for security
RUN groupadd -r claude && \
    useradd -r -g claude -u 1001 claude

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Copy virtual environment from builder stage
COPY --from=builder /opt/venv /opt/venv

# Set work directory and copy application code
WORKDIR /app
COPY --chown=claude:claude . .

# Create logs directory
RUN mkdir -p /app/logs && chown claude:claude /app/logs

# Switch to non-root user
USER claude

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Production command with gunicorn + uvicorn workers
CMD ["gunicorn", "app.main:app", \
     "--worker-class", "uvicorn.workers.UvicornWorker", \
     "--workers", "4", \
     "--bind", "0.0.0.0:8000", \
     "--timeout", "120", \
     "--keep-alive", "2", \
     "--max-requests", "1000", \
     "--max-requests-jitter", "100", \
     "--access-logfile", "/app/logs/access.log", \
     "--error-logfile", "/app/logs/error.log", \
     "--log-level", "info"]

# Development stage (for development use)
FROM python:3.11-slim as development

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    ENVIRONMENT=development

# Install development dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy requirements and install dependencies
COPY requirements.txt .
RUN pip install --upgrade pip && \
    pip install -r requirements.txt && \
    pip install uvicorn[standard] watchfiles

# Copy application code
COPY . .

# Expose port
EXPOSE 8000

# Development command with auto-reload
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]