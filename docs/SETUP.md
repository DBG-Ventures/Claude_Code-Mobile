# Claude Code Mobile - Complete Setup Guide

Complete deployment and configuration guide for the Claude Code Mobile solution, including FastAPI backend with real-time streaming and SwiftUI iOS client with liquid glass design.

## Quick Start

```bash
# 1. Clone and navigate to backend
cd backend

# 2. Configure environment
cp .env.example .env
# Edit .env with your Claude API key

# 3. Deploy with Docker
docker-compose up -d

# 4. Verify deployment
curl http://localhost:8000/health
```

## Prerequisites

### System Requirements
- **Docker**: 20.10+ and Docker Compose 2.0+
- **Node.js**: 18.x or higher (for Claude Code SDK)
- **Python**: 3.11+ (if running without Docker)
- **Memory**: 4GB RAM minimum, 8GB recommended for production
- **Storage**: 10GB disk space for Docker images, logs, and session storage
- **Network**: Port 8000 available (configurable)

### Required Credentials
- **Claude API Key**: From [Anthropic Console](https://console.anthropic.com/)
- **Claude Code OAuth Token**: Authentication for Claude Code SDK integration

### For iOS Client Development
- **macOS**: Sonoma 14+ with Xcode 15+
- **iOS Targets**: iPadOS 17+, macOS 14+, visionOS 1+
- **Hardware**: M1+ iPad Pro recommended for liquid glass effects
- **Apple Developer**: Account required for device testing and App Store deployment

### For Phase 2 OpenZiti (Optional)
- **OpenZiti Network**: Controller access and service configuration
- **Network Admin**: Privileges for identity enrollment and service setup
- **Certificates**: Valid identity certificates for zero-trust networking

## Environment Configuration

### 1. Create Environment File

```bash
cp .env.example .env
```

### 2. Essential Settings

Edit `.env` with your configuration:

```env
# REQUIRED: Your Claude API key
CLAUDE_API_KEY=your_claude_api_key_here

# Environment (development/production)
ENVIRONMENT=production

# CORS origins for mobile clients
CORS_ORIGINS=["https://localhost:*","capacitor://localhost"]
```

### 3. Advanced Configuration

```env
# Server settings
WORKERS=4                    # Adjust based on CPU cores
MEMORY_LIMIT=1G             # Docker memory limit
CPU_LIMIT=1.0               # Docker CPU limit

# Session management
MAX_SESSIONS_PER_USER=10    # Concurrent sessions per user
SESSION_TIMEOUT=3600        # Session timeout in seconds

# Rate limiting
RATE_LIMIT_REQUESTS=100     # Requests per minute
RATE_LIMIT_WINDOW=60        # Rate limit window in seconds

# Logging
LOG_LEVEL=INFO              # DEBUG, INFO, WARNING, ERROR
LOG_FORMAT=json             # json or text
```

## Deployment Options

### Option 1: Production Deployment (Recommended)

```bash
# Start production services
docker-compose up -d

# View logs
docker-compose logs -f claude-backend

# Check status
docker-compose ps
```

### Option 2: Development Mode

```bash
# Start in development mode with live reload
ENVIRONMENT=development docker-compose up

# Or use override
docker-compose -f docker-compose.yml -f docker-compose.override.yml up
```

### Option 3: Production with SSL/TLS

```bash
# 1. Place SSL certificates in ./ssl/
# 2. Enable nginx profile
docker-compose --profile production up -d
```

## API Endpoints

### Health Check
```bash
curl http://localhost:8000/health
```

### Create Session
```bash
curl -X POST http://localhost:8000/claude/sessions \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "test-user",
    "claude_options": {
      "api_key": "your-key"
    }
  }'
```

### Stream Claude Response
```bash
curl -N http://localhost:8000/claude/stream \
  -H "Accept: text/event-stream" \
  -H "Content-Type: application/json" \
  -d '{
    "session_id": "session-uuid",
    "user_id": "test-user",
    "query": "Hello Claude"
  }'
```

### API Documentation
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## iOS Client Setup

### Prerequisites

- **Xcode 15+** with iOS 17+ SDK
- **iPad Pro M1+** (recommended for liquid glass effects)
- **macOS 14+** for development
- **Apple Developer Account** for device testing

### Quick Setup (5 minutes)

```bash
# 1. Navigate to iOS project
cd ios-app

# 2. Open in Xcode
open SwiftUIClaudeClient.xcodeproj

# 3. Configure project
# - Select project in navigator
# - Update Bundle Identifier to unique value
# - Select your development team
# - Update backend URL if not using localhost:8000
```

### Configuration

**1. Backend URL Configuration**

In `ContentView.swift`, update the development URL:

```swift
case .development:
    return URL(string: "http://localhost:8000")  // Update if different

// For simulator on different machine:
case .development:
    return URL(string: "http://192.168.1.100:8000")  // Your computer's IP
```

**2. Build and Test**

1. Select iPad simulator or connected iPad
2. Build and run (⌘+R)
3. Test backend connection in Settings tab
4. Create test session and verify streaming works

### iOS App Features

- **🎨 Liquid Glass UI**: iPad Pro M1+ optimized design
- **⚡ Real-time Streaming**: SSE-based Claude response streaming
- **📱 Multi-Session**: Manage up to 10 concurrent conversations
- **💾 Session Persistence**: Conversations survive app restarts
- **🔄 Auto-Reconnection**: Handles network transitions gracefully
- **⚙️ Settings Management**: Backend configuration and testing

## Production Deployment

### Backend Production

**1. Environment Configuration**

```env
# Production settings
ENVIRONMENT=production
DEBUG=false
LOG_LEVEL=INFO
WORKERS=4

# Security
CORS_ORIGINS=["https://yourdomain.com"]
RATE_LIMIT_REQUESTS=100

# Performance
MEMORY_LIMIT=2G
CPU_LIMIT=2.0
```

**2. Deploy with SSL**

```bash
# 1. Prepare SSL certificates
mkdir -p ssl
# Copy your SSL cert and key files to ssl/

# 2. Deploy with nginx
docker-compose --profile production up -d
```

**3. Health Monitoring**

```bash
# Check service status
docker-compose ps

# Monitor resource usage  
docker stats claude-backend

# View detailed logs
docker-compose logs -f claude-backend
```

### iOS Production

**1. Update Production URLs**

```swift
// Update backend URLs for production
case .production(let url):
    return URL(string: "https://your-production-domain.com")
```

**2. App Store Deployment**

1. Archive build (Product → Archive)
2. Upload to App Store Connect
3. Configure metadata and screenshots
4. Submit for review

## Integration Testing

### Backend Testing

```bash
# 1. Health check
curl http://localhost:8000/health

# 2. Create test session
curl -X POST http://localhost:8000/claude/sessions \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test", "claude_options": {"api_key": "your-key"}}'

# 3. Test streaming
curl -N http://localhost:8000/claude/stream \
  -H "Accept: text/event-stream" \
  -d '{"session_id": "session-id", "user_id": "test", "query": "Hello"}'
```

### iOS Testing

**Connection Test:**
1. Open iOS app → Settings tab
2. Verify "Connected" status (green indicator)
3. Tap "Test Connection" → should show ✅ success

**Streaming Test:**
1. Go to Sessions tab → create new session
2. Switch to Chat tab
3. Send message: "Hello Claude!"
4. Verify real-time streaming response

**Multi-Session Test:**
1. Create multiple sessions with different names
2. Switch between sessions
3. Verify conversation history persists
4. Test up to 10 concurrent sessions

## iOS Client Setup

### 1. System Requirements
- iPad Pro with M1+ chip (for liquid glass effects)
- iOS 16+ or iPadOS 16+
- Xcode 14+ for development

### 2. Configure iOS Client
```swift
// Update NetworkConfig.swift with your backend URL
struct NetworkConfig {
    static let baseURL = "http://your-backend-host:8000"
    static let streamURL = "\(baseURL)/claude/stream"
}
```

### 3. CORS Configuration
Ensure your `.env` file includes your iOS client origins:
```env
CORS_ORIGINS=["capacitor://localhost","https://localhost:*"]
```

## Security Configuration

### Phase 1: HTTP Authentication
- User ID based authentication via headers
- Rate limiting by IP/user
- CORS protection for mobile clients

```bash
# Test with user authentication
curl -H "X-User-ID: test-user" http://localhost:8000/claude/sessions
```

### Phase 2: OpenZiti Zero-Trust (Advanced)

```env
# Enable OpenZiti mode
NETWORKING_MODE=ziti
ZITI_IDENTITY_FILE=/app/ziti/client-identity.json
ZITI_SERVICE_NAME=claude-api
```

1. **Setup Ziti Identity**:
   ```bash
   # Create ziti directory
   mkdir -p ./ziti

   # Copy your Ziti identity file
   cp /path/to/client-identity.json ./ziti/
   ```

2. **Deploy with Ziti**:
   ```bash
   docker-compose up -d
   ```

## Monitoring & Logs

### Application Logs
```bash
# Follow real-time logs
docker-compose logs -f claude-backend

# View recent logs
docker-compose logs --tail=100 claude-backend
```

### Health Monitoring
```bash
# Check service health
curl http://localhost:8000/health

# Detailed health with dependencies
curl http://localhost:8000/claude/health
```

### Resource Monitoring
```bash
# Container stats
docker stats

# Service status
docker-compose ps
```

## Troubleshooting

### Common Issues

#### 1. Backend Won't Start
```bash
# Check logs for errors
docker-compose logs claude-backend

# Common fixes:
# - Verify CLAUDE_API_KEY is set
# - Check port 8000 isn't in use
# - Ensure Docker has enough memory
```

#### 2. Claude API Errors
```bash
# Test API key manually
curl -H "Authorization: Bearer $CLAUDE_API_KEY" \
  https://api.anthropic.com/v1/messages

# Verify API key in logs (no personal data logged)
docker-compose logs claude-backend | grep -i claude
```

#### 3. CORS Issues
```bash
# Check CORS settings
curl -H "Origin: capacitor://localhost" \
  -H "Access-Control-Request-Method: POST" \
  -X OPTIONS \
  http://localhost:8000/claude/sessions
```

#### 4. Performance Issues
```bash
# Check resource usage
docker stats claude-backend

# Adjust workers in .env
WORKERS=8  # Increase for more concurrent requests

# Check rate limiting
curl -I http://localhost:8000/claude/health
```

#### 5. Claude Code SDK Issues
```bash
# Verify Claude Code SDK installation
docker exec claude-backend npm list -g @anthropic-ai/claude-code

# Check SDK authentication
docker exec claude-backend claude-code --version

# Test SDK connection
curl -X POST http://localhost:8000/claude/sessions \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test", "working_directory": "/tmp"}'
```

#### 6. Session Management Issues
```bash
# Check session storage
docker exec claude-backend ls -la /app/logs/sessions/

# Verify session persistence
curl http://localhost:8000/claude/sessions/list?user_id=test

# Reset session storage
docker exec claude-backend rm -rf /app/logs/sessions/*
docker-compose restart claude-backend
```

### Debug Mode
```bash
# Enable debug logging
echo "DEBUG=true" >> .env
echo "LOG_LEVEL=DEBUG" >> .env

# Restart with debug
docker-compose up -d
```

### Reset Environment
```bash
# Complete reset
docker-compose down -v
docker-compose up -d
```

## Performance Tuning

### Resource Allocation
```env
# High-traffic settings
WORKERS=8
MEMORY_LIMIT=2G
CPU_LIMIT=2.0
MAX_SESSIONS_PER_USER=20
```

### Rate Limiting
```env
# Adjust for your use case
RATE_LIMIT_REQUESTS=200    # Higher for power users
RATE_LIMIT_WINDOW=60       # Per minute window
```

### Session Management
```env
SESSION_TIMEOUT=7200       # 2 hours for long sessions
MESSAGE_HISTORY_LIMIT=200  # More context for conversations
```

## Scaling & Production

### Load Balancing
```yaml
# Add to docker-compose.yml
services:
  claude-backend:
    deploy:
      replicas: 3
```

### External Database (Phase 2)
```env
# Redis for session storage
REDIS_PORT=6379
REDIS_PASSWORD=secure-password
```

### SSL/TLS Termination
```yaml
# nginx service in docker-compose.yml
nginx:
  image: nginx:alpine
  ports:
    - "443:443"
  volumes:
    - ./ssl:/etc/ssl/certs:ro
```

## Backup & Recovery

### Data Backup
```bash
# Backup session data (if using Redis)
docker exec redis redis-cli BGSAVE

# Backup logs
tar -czf backup-$(date +%Y%m%d).tar.gz logs/
```

### Recovery
```bash
# Restore from backup
docker-compose down
# Restore data files
docker-compose up -d
```

## Updating

### Update Backend
```bash
# Pull latest changes
git pull origin main

# Rebuild and deploy
docker-compose build --no-cache
docker-compose up -d
```

### Update Dependencies
```bash
# Update requirements.txt
pip install -r requirements.txt --upgrade

# Rebuild Docker image
docker-compose build --no-cache claude-backend
```

## Support

### Logs for Support
```bash
# Generate support bundle
mkdir support-$(date +%Y%m%d)
docker-compose logs > support-$(date +%Y%m%d)/logs.txt
docker-compose config > support-$(date +%Y%m%d)/config.yml
cp .env support-$(date +%Y%m%d)/env.example
tar -czf support-$(date +%Y%m%d).tar.gz support-$(date +%Y%m%d)/
```

### Performance Metrics
```bash
# Test response times
curl -w "@curl-format.txt" -o /dev/null -s http://localhost:8000/health

# Load testing (optional)
ab -n 100 -c 10 http://localhost:8000/health
```

## Success Criteria Checklist

- [ ] Backend starts successfully with `docker-compose up -d`
- [ ] Health check returns 200: `curl http://localhost:8000/health`
- [ ] API documentation accessible at `/docs`
- [ ] Session creation works with valid Claude API key
- [ ] Real-time streaming functions via SSE
- [ ] CORS configured for mobile clients
- [ ] Response times < 200ms for health checks
- [ ] iOS client can connect and stream responses
- [ ] Multiple concurrent sessions supported
- [ ] Session persistence across container restarts

Your Claude Code Mobile Backend is ready when all checkboxes are complete!