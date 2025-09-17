# Claude Code Mobile - Session Management Analysis

## 📋 **Executive Summary**

This document details the current state of session management in the Claude Code Mobile application, the recent implementation changes, ongoing issues, and recommendations for resolution.

**Current Status**: ❌ **Session history is not persisting when switching between sessions in the iOS app**

## 🏗️ **Architecture Overview**

### **Backend Implementation (Recently Updated)**

The backend has been completely refactored to use Claude Code SDK's native session management:

```python
# New Implementation in app/services/claude_service.py
from claude_code_sdk import query
from claude_code_sdk.types import ClaudeCodeOptions

class SessionManager:
    def __init__(self):
        self._sessions: Dict[str, Dict[str, Any]] = {}
        self._claude_session_ids: Dict[str, str] = {}  # Maps our session_id to Claude SDK session_id

class ClaudeService:
    async def query(self, request: ClaudeQueryRequest, options: RequestOptions):
        # Get Claude session ID if available for resumption
        claude_session_id = self.session_manager.get_claude_session_id(request.session_id)

        # Create proper SDK options object
        sdk_options = ClaudeCodeOptions(
            model=options.model,  # Use default model if None
            resume=claude_session_id,  # This enables session resumption
            permission_mode="bypassPermissions",
        )

        # Send query to Claude SDK
        response = query(prompt=request.query, options=sdk_options)
```

### **Key Changes Made**

1. **Removed Manual Message Storage**: No longer storing conversation history in backend database
2. **Added Claude SDK Session Mapping**: Maps our session IDs to Claude SDK session IDs
3. **Implemented Session Resumption**: Uses `ClaudeCodeOptions(resume=claude_session_id)`
4. **Fixed Model Deprecation**: Changed from `claude-3-5-sonnet-20241022` to default model

### **Frontend Implementation (Updated)**

The iOS frontend has been updated to work with the new backend:

```swift
// ConversationViewModel.swift - Updated session loading
private func loadSessionData(sessionId: String) async {
    let sessionResponse = try await claudeService.getSession(sessionId: sessionId, userId: userId)

    await MainActor.run {
        self.currentSession = sessionResponse
        // Note: With Claude SDK session management, conversation history is maintained
        // by the SDK itself through session resumption. The UI starts fresh but
        // Claude will remember the conversation context when new messages are sent.
        self.messages = []  // Clear UI but Claude SDK maintains context
    }
}
```

## 🧪 **Testing Results**

### **✅ Direct SDK Testing (Working)**

```bash
# test_session_extraction.py - SUCCESSFUL
=== Testing Session ID Extraction and Resumption ===

1. First query to get session ID...
   ✅ Session ID extracted: 7335ac67-3f92-48cd-b083-1ede98880d3b
   First response: I'll acknowledge that your favorite animal is a dolphin! 🐬

2. Second query using session resumption...
   Second response: Your favorite animal is a dolphin.

✅ SUCCESS: Session context maintained!
```

### **✅ Backend API Testing (Working)**

```bash
# test_sdk_session_resumption.py - SUCCESSFUL
=== Testing SDK Session Resumption ===

1. Creating session...
   ✅ Session created: d7f7f6c9-34cf-4e14-85d2-156036514fe1

2. Sending first query...
   ✅ First response: Acknowledged - your favorite color is blue....

3. Sending follow-up query to test resumption...
   ✅ Second response: Your favorite color is blue....

✅ SUCCESS: Session context maintained! Claude remembered the favorite color.

4. Testing streaming with session resumption...
   📡 Streaming response: The very first thing you told me in this conversation was to remember that your favorite color is blue...

✅ SUCCESS: Streaming maintains session context!
```

### **❌ iOS App Testing (Not Working)**

When switching between sessions in the iOS app:
- User asks: "What was the last question I asked?"
- Claude responds: "This is the first message"
- **Issue**: Session context is not being maintained

## 🔍 **Root Cause Analysis**

### **Confirmed Working Components**

1. ✅ **Claude SDK Session Resumption**: Direct SDK calls maintain context perfectly
2. ✅ **Backend API Session Management**: HTTP API calls maintain context correctly
3. ✅ **Session ID Mapping**: Backend correctly maps our session IDs to Claude SDK session IDs
4. ✅ **Model Configuration**: Using default model instead of deprecated one

### **Suspected Issues**

#### **1. Session ID Mapping Persistence**

**Problem**: The `_claude_session_ids` mapping may not persist between API calls in the FastAPI backend.

```python
class SessionManager:
    def __init__(self):
        self._claude_session_ids: Dict[str, str] = {}  # In-memory only!
```

**Evidence**: Each API request may create a new SessionManager instance, losing the Claude session ID mapping.

#### **2. FastAPI Singleton Pattern**

**Current Implementation**:
```python
# app/api/claude.py
_claude_service_instance: Optional[ClaudeService] = None

def get_claude_service() -> ClaudeService:
    global _claude_service_instance
    if _claude_service_instance is None:
        _claude_service_instance = ClaudeService()
    return _claude_service_instance
```

**Potential Issue**: The singleton may not be working correctly, causing new instances and lost session mappings.

#### **3. Claude SDK Session Storage Location**

**Question**: Where does the Claude SDK store session data?
- File system?
- Environment-specific?
- Process-specific?

If Claude SDK sessions are process-specific or stored in temporary locations, they may not persist between API calls.

## 📊 **Current System Flow**

### **Expected Flow (Not Working)**
1. iOS app creates session → Backend creates session A → Maps to Claude SDK session X
2. User sends message 1 → Backend uses Claude SDK session X → Claude remembers context
3. User switches to different session → Backend maps to Claude SDK session Y
4. User switches back to session A → Backend should resume Claude SDK session X
5. User asks "What was my last question?" → Claude should remember message 1

### **Actual Flow (Current Behavior)**
1. iOS app creates session → Backend creates session A → Maps to Claude SDK session X
2. User sends message 1 → Backend uses Claude SDK session X → Claude remembers context
3. User switches to different session → Backend maps to Claude SDK session Y
4. User switches back to session A → **Backend may create NEW Claude SDK session Z**
5. User asks "What was my last question?" → Claude responds "This is the first message"

## 🚨 **CRITICAL: SDK Documentation Analysis & Gaps**

After reviewing the official Claude Code SDK documentation at https://docs.anthropic.com/en/docs/claude-code/sdk/sdk-sessions, there are **fundamental misalignments** between our current implementation and the SDK's intended usage.

### **SDK Architecture vs Current Implementation**

**Official SDK Architecture (from documentation):**
```
~/.config/claude/
├── sessions/
│   └── sessions.json          # Session metadata and state
└── projects/
    └── {project-hash}/
        └── {session-id}.jsonl # Session transcript
```

**Current Implementation (MISALIGNED):**
```python
class SessionManager:
    def __init__(self):
        self._claude_session_ids: Dict[str, str] = {}  # ❌ In-memory mapping
```

### **Critical Gaps Identified**

#### **Gap 1: Unnecessary Session Mapping Layer**
**Current Problem**: We maintain a mapping between "our session IDs" and "Claude SDK session IDs"
```python
self._claude_session_ids[session_id] = claude_session_id  # ❌ Unnecessary abstraction
```

**SDK Documentation**: The SDK manages sessions natively with unique session IDs - no mapping needed.

#### **Gap 2: Ignoring SDK's Native File Storage**
**Current Problem**: We're trying to create database/file storage for session mappings
**SDK Reality**: The SDK already provides file-based persistence in `~/.config/claude/`

#### **Gap 3: Working Directory Dependency**
**SDK Documentation**: Sessions are stored relative to project path and working directory
**Current Problem**: FastAPI backend may not run from consistent working directory, causing session storage issues

### **SDK-Aligned Architecture (RECOMMENDED)**

Instead of our current session mapping approach, we should:

```python
# ✅ SDK-Aligned Implementation
class ClaudeService:
    async def create_session(self, request: CreateSessionRequest):
        # Let SDK generate and manage session ID directly
        response = query(prompt="Initialize session", options=ClaudeCodeOptions())
        claude_session_id = response.session_id  # Use this directly as our session ID

        return {
            "session_id": claude_session_id,  # No mapping needed!
            "user_id": request.user_id,
            "session_name": request.session_name
        }

    async def query(self, request: ClaudeQueryRequest):
        # Use session ID directly for resumption
        sdk_options = ClaudeCodeOptions(
            resume=request.session_id,  # Direct SDK session ID
            permission_mode="bypassPermissions"
        )
        return query(prompt=request.query, options=sdk_options)
```

### **Required Implementation Changes**

#### **1. Remove Session Mapping Layer**
```python
# ❌ Remove this entirely
class SessionManager:
    def __init__(self):
        self._claude_session_ids: Dict[str, str] = {}  # DELETE
```

#### **2. Use SDK Session IDs Directly**
```python
# ✅ Simplified session creation
async def create_session(self, request: CreateSessionRequest):
    # Initialize with Claude SDK, get session ID
    response = query(prompt="", options=ClaudeCodeOptions())
    session_id = response.session_id

    # Store in our database with SDK session ID as primary key
    session_data = {
        "session_id": session_id,  # Claude SDK session ID
        "user_id": request.user_id,
        "session_name": request.session_name,
        "created_at": datetime.utcnow()
    }
    return session_data
```

#### **3. Ensure Consistent Working Directory**
```python
# ✅ Set working directory for SDK session storage
import os
os.chdir("/path/to/project/root")  # Ensure consistent Claude session storage location
```

#### **4. Update iOS App Session Handling**
```swift
// ✅ Store Claude SDK session IDs directly
struct Session {
    let sessionId: String  // This is now the Claude SDK session ID directly
    let userId: String
    let sessionName: String
}
```

## 🛠️ **Recommended Solutions (UPDATED - SDK-ALIGNED)**

### **Solution 1: Remove Session Mapping (PRIORITY 1)**

**Replace current implementation with SDK-native approach:**

```python
# ❌ OLD: Complex mapping system
class SessionManager:
    def __init__(self):
        self._sessions: Dict[str, Dict[str, Any]] = {}
        self._claude_session_ids: Dict[str, str] = {}

# ✅ NEW: Direct SDK usage
class ClaudeService:
    def __init__(self):
        # Ensure consistent working directory for Claude sessions
        import os
        self.project_root = os.path.abspath(".")
        os.chdir(self.project_root)
```

### **Solution 2: Update Session Creation Flow**

```python
# ✅ SDK-aligned session creation
async def create_session(self, request: CreateSessionRequest):
    # Let Claude SDK handle session creation and ID generation
    initial_response = query(
        prompt="Session initialized",
        options=ClaudeCodeOptions(permission_mode="bypassPermissions")
    )

    claude_session_id = initial_response.session_id

    # Store session metadata using Claude session ID as key
    session_data = {
        "session_id": claude_session_id,  # Use Claude SDK session ID directly
        "user_id": request.user_id,
        "session_name": request.session_name,
        "created_at": datetime.utcnow()
    }

    # Store in database if needed (optional - SDK handles persistence)
    await self.store_session_metadata(session_data)

    return session_data
```

### **Solution 3: Verify SDK Session Storage Location**

```python
# ✅ Add debugging to check SDK session storage
async def debug_claude_sessions():
    import os
    import glob

    # Check Claude SDK session storage
    home_dir = os.path.expanduser("~")
    claude_config_dir = os.path.join(home_dir, ".config", "claude")

    print(f"Claude config directory: {claude_config_dir}")
    print(f"Exists: {os.path.exists(claude_config_dir)}")

    # Check for session files
    session_files = glob.glob(f"{claude_config_dir}/**/*.json*", recursive=True)
    print(f"Session files found: {session_files}")

    # Check current working directory (affects session storage)
    print(f"Current working directory: {os.getcwd()}")
```

## 🛠️ **Original Recommended Solutions (DEPRECATED)**

### **Solution 1: Persistent Session Storage (Recommended)**

Add database or file-based storage for Claude session ID mappings:

```python
# Option A: SQLite Database
class PersistentSessionManager:
    def __init__(self):
        self.db_path = "sessions.db"
        self.init_database()

    def set_claude_session_id(self, session_id: str, claude_session_id: str):
        # Store in database
        pass

    def get_claude_session_id(self, session_id: str) -> Optional[str]:
        # Retrieve from database
        pass

# Option B: JSON File Storage
class FileBasedSessionManager:
    def __init__(self):
        self.sessions_file = "claude_sessions.json"

    def save_sessions(self):
        with open(self.sessions_file, 'w') as f:
            json.dump(self._claude_session_ids, f)

    def load_sessions(self):
        if os.path.exists(self.sessions_file):
            with open(self.sessions_file, 'r') as f:
                self._claude_session_ids = json.load(f)
```

### **Solution 2: Verify Singleton Pattern**

Add logging to confirm singleton behavior:

```python
class SessionManager:
    def __init__(self):
        print(f"🔍 SessionManager created at {datetime.now()}")
        self._sessions: Dict[str, Dict[str, Any]] = {}
        self._claude_session_ids: Dict[str, str] = {}

    def set_claude_session_id(self, session_id: str, claude_session_id: str):
        print(f"🔍 Mapping {session_id} → {claude_session_id}")
        self._claude_session_ids[session_id] = claude_session_id

    def get_claude_session_id(self, session_id: str) -> Optional[str]:
        result = self._claude_session_ids.get(session_id)
        print(f"🔍 Looking up {session_id} → {result}")
        return result
```

### **Solution 3: Claude SDK Session Investigation**

Investigate where Claude SDK stores session data:

```python
# Add debugging to understand Claude SDK behavior
async def debug_claude_sdk_sessions():
    print("🔍 Claude SDK session storage investigation")

    # Check current working directory
    print(f"CWD: {os.getcwd()}")

    # Check for Claude session files
    for root, dirs, files in os.walk("."):
        for file in files:
            if "session" in file.lower() or "claude" in file.lower():
                print(f"Found: {os.path.join(root, file)}")
```

## 📁 **File Structure**

### **Backend Files Modified**
```
backend/
├── app/
│   ├── services/
│   │   ├── claude_service.py              # ✅ Completely refactored
│   │   └── claude_service_original.py     # 📁 Backup of old implementation
│   ├── models/
│   │   └── requests.py                    # ✅ Updated ClaudeCodeOptions
│   └── main.py                           # ✅ Removed cleanup calls
├── test_sdk_session_resumption.py        # ✅ Working test
├── test_session_extraction.py            # ✅ Working test
└── test_raw_sdk.py                       # ✅ Working test
```

### **Frontend Files Modified**
```
ios-app/VisionForge/VisionForge/
├── ViewModels/
│   ├── ConversationViewModel.swift        # ✅ Updated session loading logic
│   └── SessionListViewModel.swift        # ✅ Fixed deprecated model
└── Models/
    └── ClaudeMessage.swift               # ✅ Made model optional
```

## 🔬 **Debugging Steps for Next Session**

### **Step 1: Add Comprehensive Logging**

```python
# Add to claude_service.py
import logging
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

class SessionManager:
    def __init__(self):
        logger.debug(f"SessionManager.__init__() called at {datetime.now()}")
        logger.debug(f"Instance ID: {id(self)}")
```

### **Step 2: Test Session Persistence**

```bash
# Create test script to verify session mapping persistence
curl -X POST "http://localhost:8000/claude/sessions" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test-user", "session_name": "Debug Session"}'

# Send first message
curl -X POST "http://localhost:8000/claude/query" \
  -H "Content-Type: application/json" \
  -d '{"session_id": "SESSION_ID", "query": "Remember my name is Alice", "user_id": "test-user"}'

# Send second message (should remember Alice)
curl -X POST "http://localhost:8000/claude/query" \
  -H "Content-Type: application/json" \
  -d '{"session_id": "SESSION_ID", "query": "What is my name?", "user_id": "test-user"}'
```

### **Step 3: Investigate Claude SDK Storage**

```python
# Add to debugging script
import os
import glob

# Check for Claude-related files
claude_files = glob.glob("**/*claude*", recursive=True)
session_files = glob.glob("**/*session*", recursive=True)

print("Claude-related files:", claude_files)
print("Session-related files:", session_files)

# Check environment variables
claude_env_vars = {k: v for k, v in os.environ.items() if 'claude' in k.lower()}
print("Claude environment variables:", claude_env_vars)
```

## 🎯 **Success Criteria**

The session management system will be considered working when:

1. ✅ User creates session A and sends message "Remember my favorite color is blue"
2. ✅ User creates session B and sends message "Remember my pet is a cat"
3. ✅ User switches back to session A
4. ✅ User asks "What is my favorite color?" → Claude responds "Blue"
5. ✅ User switches to session B
6. ✅ User asks "What is my pet?" → Claude responds "Cat"

## 📞 **Contact & Next Steps**

**Current Implementation Status**:
- ✅ Claude SDK integration working
- ✅ Backend API session resumption working
- ❌ iOS app session switching not maintaining history

**Priority**: High - Core functionality for mobile app

**Estimated Fix Time**: 2-4 hours (assuming session mapping persistence is the issue)

**Files to Focus On**:
1. `backend/app/services/claude_service.py` - Add persistent session storage
2. `backend/app/api/claude.py` - Verify singleton pattern
3. Test scripts - Add comprehensive debugging

---
*Document created: 2025-09-16*
*Last updated: 2025-09-16*
*Status: Session resumption partially working - needs persistence layer*