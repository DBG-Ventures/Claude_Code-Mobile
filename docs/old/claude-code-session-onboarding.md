# Claude Code Session Onboarding Prompt

## Quick Start Prompt for New Sessions

Copy and paste this prompt when starting a new Claude Code session to get up to speed quickly:

---

**ONBOARDING PROMPT START:**

```
I'm working on a Claude Code Mobile project - a FastAPI backend with iOS SwiftUI client for Claude Code SDK integration. You need to get up to speed on the current project status and critical implementation task.

PROJECT OVERVIEW:
- Location: /Users/beardedwonder/Development/DBGVentures/Claude_Code-Mobile
- Backend: FastAPI with Claude Code SDK integration for AI coding sessions
- Frontend: SwiftUI iOS app with liquid glass design for iPad/VisionOS
- Current Issue: Critical session resumption bug blocking core functionality

IMMEDIATE PRIORITY:
Read and follow the implementation plan in docs/session-management-fix-plan.md - this contains a detailed analysis and step-by-step fix for Claude Code SDK session resumption failures.

KEY PROJECT FILES TO REVIEW:
1. docs/session-management-fix-plan.md (CRITICAL - implementation roadmap)
2. backend/app/services/claude_service.py (core session management)
3. backend/app/utils/session_storage.py (persistent session metadata)
4. docs/prd.md (product requirements)
5. docs/API.md (backend API documentation)

CURRENT PROBLEM:
Session creation works but resumption fails with "No conversation found with session ID" errors. Root cause identified: incomplete async generator consumption in _extract_session_id method prevents proper Claude SDK session establishment.

TASK INSTRUCTIONS:
1. First, read docs/session-management-fix-plan.md thoroughly
2. Review the current claude_service.py implementation
3. Implement Phase 1 fixes from the plan (async generator consumption fix)
4. Test session creation and resumption
5. Proceed with Phase 2 enhancements if Phase 1 succeeds

WORKING STYLE:
- Use Archon MCP task management for tracking progress
- Focus on the specific implementation plan rather than redesigning
- Test thoroughly after each phase
- Maintain existing code patterns and error handling
- Priority: Fix the core issue, then enhance robustness

The fix plan is comprehensive and ready for implementation. Start by reading it and then begin Phase 1 implementation.
```

**ONBOARDING PROMPT END**

---

## Alternative Short Version

For quicker onboarding when you need immediate context:

```
Working on Claude Code Mobile (FastAPI + SwiftUI). Critical bug: session resumption failing.

Action needed: Read docs/session-management-fix-plan.md and implement the Phase 1 fix (remove break statement in _extract_session_id method in backend/app/services/claude_service.py).

Root cause: Incomplete async generator consumption prevents Claude SDK session establishment. Plan is documented and ready for implementation.
```

## Usage Instructions

1. **Start new Claude Code session** in the project directory
2. **Copy and paste** the full onboarding prompt above
3. **Verify Claude reads** the session management fix plan
4. **Begin implementation** following the documented phases
5. **Use Archon task management** to track progress throughout

## Benefits of This Approach

- **Immediate context**: Claude understands the project and priority
- **Clear direction**: Points directly to the implementation plan
- **Prevents scope creep**: Focuses on the specific documented solution
- **Maintains continuity**: Preserves analysis work done in previous sessions
- **Reduces ramp-up time**: No need to re-analyze the problem

## Session Continuity Tips

- Always reference the fix plan document for implementation details
- Use the Archon task management system to track which phases are complete
- Test each phase before moving to the next
- Document any deviations or discoveries in the fix plan comments
- Keep session focused on the implementation rather than re-analysis