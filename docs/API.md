# Claude Code Mobile Backend API Documentation

Complete REST API reference for the Claude Code Mobile Backend with real-time streaming support.

## Base URL

```
Development: http://localhost:8000
Production: https://your-domain.com
```

## Authentication

### Phase 1: User ID Authentication
Include user identification in requests via:

**Headers:**
```http
X-User-ID: your-user-id
```

**Authorization Header:**
```http
Authorization: Bearer your-user-id
```

**Query Parameter:**
```http
GET /endpoint?user_id=your-user-id
```

### Phase 2: OpenZiti (Future)
Cryptographic device identity with zero-trust networking.

## Rate Limiting

- **Default:** 100 requests per minute per user
- **Headers:** Rate limit info included in response headers
- **Exceeded:** Returns `429 Too Many Requests`

## Response Format

### Success Response
```json
{
  "data": {...},
  "status": "success"
}
```

### Error Response
```json
{
  "error": "error_type",
  "message": "Human readable error message",
  "details": {...},
  "timestamp": "2024-01-01T12:00:00Z",
  "request_id": "optional-trace-id"
}
```

## Core Endpoints

### Health Check

#### GET /health
Check service health and dependencies.

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2024-01-01T12:00:00Z",
  "version": "1.0.0",
  "dependencies": {
    "claude_sdk": "available",
    "streaming": "available",
    "sessions": "available"
  }
}
```

**Status Codes:**
- `200` - Service healthy
- `503` - Service unavailable

---

## Session Management

### Create Session

#### POST /claude/sessions
Create a new Claude Code conversation session.

**Request Body:**
```json
{
  "user_id": "unique-user-identifier",
  "claude_options": {
    "api_key": "your-claude-api-key",
    "model": "claude-3-5-sonnet-20241022",
    "max_tokens": 8192,
    "temperature": 0.7,
    "timeout": 60
  },
  "session_name": "Optional Session Name",
  "context": {}
}
```

**Response:**
```json
{
  "session_id": "550e8400-e29b-41d4-a716-446655440000",
  "user_id": "unique-user-identifier",
  "session_name": "Session 1",
  "status": "active",
  "messages": [],
  "created_at": "2024-01-01T12:00:00Z",
  "updated_at": "2024-01-01T12:00:00Z",
  "message_count": 0,
  "context": {}
}
```

**Status Codes:**
- `201` - Session created successfully
- `400` - Invalid request data
- `500` - Internal server error

### List User Sessions

#### GET /claude/sessions
List sessions for the authenticated user with pagination.

**Query Parameters:**
- `user_id` (required): User identifier
- `limit` (optional): Maximum sessions to return (1-100, default: 10)
- `offset` (optional): Pagination offset (default: 0)

**Response:**
```json
{
  "sessions": [
    {
      "session_id": "550e8400-e29b-41d4-a716-446655440000",
      "user_id": "unique-user-identifier",
      "session_name": "Session 1",
      "status": "active",
      "messages": [...],
      "created_at": "2024-01-01T12:00:00Z",
      "updated_at": "2024-01-01T12:00:00Z",
      "message_count": 5,
      "context": {}
    }
  ],
  "total_count": 25,
  "has_more": true,
  "next_offset": 10
}
```

### Get Session Details

#### GET /claude/sessions/{session_id}
Retrieve full session details including message history.

**Path Parameters:**
- `session_id`: Session UUID

**Query Parameters:**
- `user_id` (required): User identifier

**Response:**
```json
{
  "session_id": "550e8400-e29b-41d4-a716-446655440000",
  "user_id": "unique-user-identifier",
  "session_name": "Session 1",
  "status": "active",
  "messages": [
    {
      "id": "msg-uuid",
      "content": "Hello Claude",
      "role": "user",
      "timestamp": "2024-01-01T12:00:00Z",
      "session_id": "550e8400-e29b-41d4-a716-446655440000",
      "metadata": {}
    },
    {
      "id": "msg-uuid-2",
      "content": "Hello! How can I help you today?",
      "role": "assistant",
      "timestamp": "2024-01-01T12:00:01Z",
      "session_id": "550e8400-e29b-41d4-a716-446655440000",
      "metadata": {}
    }
  ],
  "created_at": "2024-01-01T12:00:00Z",
  "updated_at": "2024-01-01T12:00:01Z",
  "message_count": 2,
  "context": {}
}
```

**Status Codes:**
- `200` - Session found
- `404` - Session not found or access denied
- `500` - Internal server error

---

## Claude Interaction

### Query Claude (Non-Streaming)

#### POST /claude/query
Send a query to Claude and receive the complete response.

**Request Body:**
```json
{
  "session_id": "550e8400-e29b-41d4-a716-446655440000",
  "user_id": "unique-user-identifier",
  "query": "Explain quantum computing",
  "stream": false,
  "context": {}
}
```

**Claude Options Body:**
```json
{
  "api_key": "your-claude-api-key",
  "model": "claude-3-5-sonnet-20241022",
  "max_tokens": 8192,
  "temperature": 0.7,
  "timeout": 60
}
```

**Response:**
```json
{
  "session_id": "550e8400-e29b-41d4-a716-446655440000",
  "message": {
    "id": "msg-uuid",
    "content": "Quantum computing is a revolutionary computing paradigm...",
    "role": "assistant",
    "timestamp": "2024-01-01T12:00:01Z",
    "session_id": "550e8400-e29b-41d4-a716-446655440000",
    "metadata": {}
  },
  "status": "completed",
  "processing_time": 2.34
}
```

### Stream Claude Response (Real-time)

#### POST /claude/stream
Stream Claude's response in real-time using Server-Sent Events (SSE).

**CRITICAL:** This is the main endpoint for mobile client streaming.

**Request Body:**
Same as `/claude/query`

**Response Type:** `text/event-stream`

**SSE Events:**
```
event: start
data: {"message":"Starting Claude response stream","session_id":"...","timestamp":"..."}

event: delta
data: {"content":"Quantum","chunk_type":"delta","message_id":"...","timestamp":"..."}

event: delta
data: {"content":" computing","chunk_type":"delta","message_id":"...","timestamp":"..."}

event: complete
data: {"content":"","chunk_type":"complete","message_id":"...","timestamp":"..."}
```

**Event Types:**
- `start` - Stream initialization
- `delta` - Content chunk
- `complete` - Stream completion
- `error` - Error occurred

**Headers:**
```http
Content-Type: text/event-stream
Cache-Control: no-cache
Connection: keep-alive
Access-Control-Allow-Origin: *
```

**JavaScript Client Example:**
```javascript
const eventSource = new EventSource('/claude/stream');

eventSource.addEventListener('delta', (event) => {
  const chunk = JSON.parse(event.data);
  appendToChat(chunk.content);
});

eventSource.addEventListener('complete', (event) => {
  console.log('Stream completed');
  eventSource.close();
});

eventSource.addEventListener('error', (event) => {
  const error = JSON.parse(event.data);
  console.error('Stream error:', error);
});
```

---

## Session Operations

### Update Session

#### PUT /claude/sessions/{session_id}
Update session properties like name or status.

**Path Parameters:**
- `session_id`: Session UUID

**Request Body:**
```json
{
  "session_id": "550e8400-e29b-41d4-a716-446655440000",
  "user_id": "unique-user-identifier",
  "session_name": "New Session Name",
  "status": "active",
  "context": {}
}
```

**Response:**
Updated session object (same format as GET /claude/sessions/{session_id})

### Delete Session

#### DELETE /claude/sessions/{session_id}
Permanently delete a session and all associated messages.

**Path Parameters:**
- `session_id`: Session UUID

**Query Parameters:**
- `user_id` (required): User identifier

**Response:**
```json
{
  "message": "Session 550e8400-e29b-41d4-a716-446655440000 deleted successfully",
  "timestamp": "2024-01-01T12:00:00Z"
}
```

---

## Data Models

### Claude Message
```json
{
  "id": "unique-message-id",
  "content": "Message content",
  "role": "user|assistant|system",
  "timestamp": "2024-01-01T12:00:00Z",
  "session_id": "session-uuid",
  "metadata": {}
}
```

### Session Status Values
- `active` - Session is active and accepting queries
- `completed` - Session completed successfully
- `error` - Session encountered an error
- `paused` - Session temporarily paused

### Message Roles
- `user` - Message from the user
- `assistant` - Response from Claude
- `system` - System/internal message

---

## Error Handling

### Common Error Codes

#### 400 Bad Request
```json
{
  "error": "validation_error",
  "message": "Request validation failed",
  "details": {
    "errors": [
      {
        "field": "user_id",
        "message": "Field required"
      }
    ]
  },
  "timestamp": "2024-01-01T12:00:00Z"
}
```

#### 401 Unauthorized
```json
{
  "error": "authentication_error",
  "message": "Authentication required. Provide user_id via Authorization header, X-User-ID header, or user_id query parameter.",
  "timestamp": "2024-01-01T12:00:00Z"
}
```

#### 404 Not Found
```json
{
  "error": "not_found",
  "message": "Session 550e8400-e29b-41d4-a716-446655440000 not found or access denied",
  "timestamp": "2024-01-01T12:00:00Z"
}
```

#### 429 Too Many Requests
```json
{
  "error": "rate_limit_exceeded",
  "message": "Rate limit exceeded. Maximum 100 requests per minute.",
  "details": {
    "limit": 100,
    "window": 60,
    "retry_after": 30
  },
  "timestamp": "2024-01-01T12:00:00Z"
}
```

#### 500 Internal Server Error
```json
{
  "error": "internal_error",
  "message": "An unexpected error occurred",
  "timestamp": "2024-01-01T12:00:00Z"
}
```

---

## Mobile Client Integration

### iOS Swift Example

```swift
import Foundation

class ClaudeService: ObservableObject {
    private let baseURL = "http://localhost:8000"

    func createSession() async throws -> SessionResponse {
        let request = SessionRequest(
            user_id: "ios-user",
            claude_options: ClaudeCodeOptions(api_key: "your-key"),
            session_name: "iOS Session"
        )

        // POST request to /claude/sessions
        // Handle response and return SessionResponse
    }

    func streamResponse(sessionId: String, query: String) {
        let url = URL(string: "\(baseURL)/claude/stream")!

        // Server-Sent Events implementation
        let eventSource = EventSource(url: url)

        eventSource.onMessage { [weak self] id, event, data in
            if event == "delta" {
                // Parse JSON and update UI
                self?.handleStreamChunk(data)
            }
        }
    }
}
```

### WebSocket Alternative (Custom)
For applications requiring bidirectional communication, implement WebSocket endpoints following similar patterns.

---

## Testing

### Health Check
```bash
curl http://localhost:8000/health
```

### Session Creation
```bash
curl -X POST http://localhost:8000/claude/sessions \
  -H "Content-Type: application/json" \
  -H "X-User-ID: test-user" \
  -d '{
    "user_id": "test-user",
    "claude_options": {"api_key": "your-key"}
  }'
```

### Streaming Test
```bash
curl -N http://localhost:8000/claude/stream \
  -H "Accept: text/event-stream" \
  -H "Content-Type: application/json" \
  -H "X-User-ID: test-user" \
  -d '{
    "session_id": "your-session-id",
    "user_id": "test-user",
    "query": "Hello Claude"
  }'
```

---

## Performance Notes

- **Response Times:** Target <200ms for non-streaming endpoints
- **Streaming Latency:** <50ms for initial chunk delivery
- **Concurrent Sessions:** Up to 10 per user by default
- **Rate Limiting:** 100 requests/minute per user
- **Session Persistence:** Sessions maintained across server restarts
- **Memory Usage:** ~50MB per active session with full message history

## Interactive API Documentation

Access the full interactive API documentation at:
- **Swagger UI:** `http://your-backend:8000/docs`
- **ReDoc:** `http://your-backend:8000/redoc`