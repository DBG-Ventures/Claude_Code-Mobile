# Unified Logging System Plan - Claude Code Mobile

## Current Issue
- Backend `claude_service.py` has undefined `logger` references at lines 257-258
- Both frontend and backend use inconsistent `print()` statements
- No centralized logging for debugging session management issues

## Vision: Unified Logging with UI Visibility

Create a comprehensive logging system that provides:
- **Real-time debugging**: See what's happening during session creation/management
- **Historical analysis**: Review past issues and patterns
- **User support**: Export logs when reporting issues
- **Development**: Faster debugging of complex Claude SDK interactions

## Current State Analysis

### Backend Logging
- **Configuration**: Ready in `config.py` (`log_level`, `log_format`)
- **Dependencies**: `python-json-logger>=2.0.7` already in requirements
- **Current pattern**: `print()` statements with emoji prefixes (🎯, ✅, 🔍)
- **Missing**: Actual logger implementation

### Frontend Logging
- **Current pattern**: `print()` statements with structured emoji prefixes (✅, ❌, 🎯)
- **Locations**: Scattered across services, view models, app lifecycle
- **Missing**: Centralized logging and UI visibility

## Implementation Plan

### Phase 1: Quick Fix + Foundation (15 minutes)
**Priority: IMMEDIATE - Fixes session creation bug**

1. **Fix logger error**: Replace undefined `logger.debug()` calls in `claude_service.py`
2. **Add structured logger**: Implement proper Python logging
3. **Create log utilities**: Central logging configuration

**Files to modify:**
- `backend/app/services/claude_service.py` - Fix undefined logger
- `backend/app/utils/logging.py` - New logging utilities
- `backend/app/core/lifecycle.py` - Initialize logging

### Phase 2: Backend Log Aggregation (30 minutes)

1. **In-memory log storage**: Ring buffer for recent logs (1000 entries)
2. **API endpoints**:
   - `GET /logs` - Retrieve logs with filtering, pagination
   - `GET /logs/stream` - WebSocket for real-time updates
3. **Log context**: Add session_id, user_id, operation to all entries
4. **Log categories**: session_management, claude_sdk, streaming, networking

**Files to create/modify:**
- `backend/app/models/logging.py` - Log entry models
- `backend/app/services/log_service.py` - Log collection service
- `backend/app/api/logs.py` - Log API endpoints
- `backend/app/main.py` - Register logs router

### Phase 3: iOS Logs Viewer (45 minutes)

1. **Logs view**: SwiftUI interface with search/filter capabilities
2. **Real-time updates**: WebSocket connection for live log streaming
3. **Export functionality**: Share logs via email/files for debugging
4. **Settings integration**: Toggle log levels, categories, real-time updates

**Files to create/modify:**
- `ios-app/VisionForge/Views/LogsView.swift` - Main logs interface
- `ios-app/VisionForge/Services/LogService.swift` - Log fetching service
- `ios-app/VisionForge/Models/LogEntry.swift` - Log data models
- `ios-app/VisionForge/ViewModels/LogsViewModel.swift` - Logs view logic

## Log Structure Design

### Structured Log Entry Format
```json
{
  "timestamp": "2025-09-16T14:23:45Z",
  "level": "INFO",
  "category": "session_management",
  "message": "Session created successfully",
  "context": {
    "session_id": "abc123",
    "user_id": "mobile-user",
    "working_directory": "/path/to/project",
    "operation": "create_session",
    "duration_ms": 150
  },
  "source": "backend",
  "component": "ClaudeService.create_session"
}
```

### Log Categories
- **`session_management`**: Session creation, validation, restoration, cleanup
- **`claude_sdk`**: SDK interactions, responses, errors, timeouts
- **`streaming`**: Real-time response handling, SSE events, WebSocket
- **`networking`**: API calls, connection status, health checks
- **`ui_interaction`**: User actions, navigation, button presses
- **`persistence`**: Data storage, retrieval, cache operations
- **`security`**: Authentication, authorization, rate limiting
- **`performance`**: Response times, memory usage, optimization

### Log Levels
- **`DEBUG`**: Detailed diagnostic information
- **`INFO`**: General operational information
- **`WARN`**: Warning conditions that don't stop operation
- **`ERROR`**: Error conditions that may affect functionality
- **`CRITICAL`**: Critical conditions requiring immediate attention

## UI Features

### SwiftUI Logs Viewer Features
```swift
// Main logs view with filtering
LogsView()
├── SearchBar() - Filter by message content
├── FilterControls() - Level, category, time range
├── LogsList() - Scrollable list with virtual scrolling
└── ExportSheet() - Share logs functionality

// Real-time updates
└── LogsWebSocketService - Live log streaming
```

### Filter Options
- **Time Range**: Last hour, day, week, all time
- **Log Level**: Debug, Info, Warn, Error, Critical
- **Category**: All categories with toggle switches
- **Source**: Backend, Frontend, Combined
- **Session**: Filter by specific session ID

### Export Options
- **Format**: JSON, Plain text, CSV
- **Scope**: Filtered results, All logs, Current session
- **Destination**: Email, Files app, AirDrop, Copy to clipboard

## Backend API Design

### Endpoints

#### Get Logs
```http
GET /logs?level=INFO&category=session_management&limit=100&offset=0&since=2025-09-16T14:00:00Z
```

Response:
```json
{
  "logs": [...],
  "total": 1250,
  "has_more": true,
  "filters_applied": {
    "level": "INFO",
    "category": "session_management"
  }
}
```

#### Stream Logs (WebSocket)
```http
WS /logs/stream?level=INFO&categories=session_management,claude_sdk
```

Real-time log entries pushed as JSON messages.

### Performance Considerations
- **Ring Buffer**: Keep last 1000 log entries in memory
- **Efficient Filtering**: Index by timestamp, level, category
- **Rate Limiting**: Max 100 requests/minute for log endpoints
- **WebSocket Management**: Auto-disconnect idle connections after 5 minutes

## Integration Points

### Backend Integration
```python
# Centralized logger usage
from app.utils.logging import get_logger

logger = get_logger(__name__)

# Structured logging with context
logger.info(
    "Session created successfully",
    extra={
        "category": "session_management",
        "session_id": session_id,
        "user_id": user_id,
        "operation": "create_session",
        "working_directory": working_dir
    }
)
```

### Frontend Integration
```swift
// Log important events
LogService.shared.log(
    level: .info,
    category: .sessionManagement,
    message: "Session created successfully",
    context: [
        "session_id": sessionId,
        "user_id": userId,
        "operation": "create_session"
    ]
)
```

## Development Workflow

### Phase 1 Implementation Steps
1. **Fix immediate bug** (5 min)
2. **Add Python logging** (5 min)
3. **Test session creation** (5 min)

### Phase 2 Implementation Steps
1. **Create log models** (10 min)
2. **Implement log service** (15 min)
3. **Add API endpoints** (5 min)

### Phase 3 Implementation Steps
1. **SwiftUI logs view** (20 min)
2. **WebSocket integration** (15 min)
3. **Export functionality** (10 min)

## Success Metrics

### Immediate (Phase 1)
- [ ] Session creation works without logger errors
- [ ] Structured logs appear in backend console
- [ ] All print statements replaced with proper logging

### Short-term (Phase 2)
- [ ] `/logs` API returns structured log data
- [ ] Real-time log streaming via WebSocket
- [ ] Session management operations fully logged

### Long-term (Phase 3)
- [ ] iOS logs viewer shows backend and frontend logs
- [ ] Export functionality works for debugging
- [ ] Development debugging time reduced by 50%

## Future Enhancements

### Advanced Features (Future)
- **Log Analytics**: Patterns, trends, error rates
- **Performance Monitoring**: Response times, bottlenecks
- **Remote Logging**: Optional cloud log aggregation
- **Log Retention**: Configurable retention policies
- **Advanced Filtering**: Regex, complex queries
- **Log Visualization**: Charts, graphs, timelines

---

## Quick Start for Phase 1

To implement immediately:

1. **Fix the bug:**
```bash
cd backend/app/services
# Edit claude_service.py - replace logger.debug() calls
```

2. **Add structured logging:**
```bash
cd backend/app/utils
# Create logging.py with centralized logger setup
```

3. **Test:**
```bash
# Start backend, create session in iOS app
# Verify structured logs in console
```

This plan provides a clear path from quick bug fix to comprehensive logging system with UI visibility.