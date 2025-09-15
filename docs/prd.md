# SwiftUI Claude Code Client Product Requirements Document (PRD)

## Goals and Background Context

### Goals

- Enable secure, mobile-native access to Claude Code SDK functionality through SwiftUI clients on iPad, macOS, and VisionOS
- Provide zero-trust networking architecture that eliminates traditional network security vulnerabilities
- Deliver cross-platform SwiftUI experience with cutting-edge liquid glass design system (iOS 26+)
- Create open source solution with self-hosted FastAPI backend for maximum privacy and control
- Establish foundation for optional managed OpenZiti controller service ($5/month convenience tier)
- Support multiple concurrent Claude Code conversation sessions with persistent context management
- Enable seamless mobile extension of existing desktop Claude Code CLI workflows

### Background Context

Developers using Claude Code face fundamental architectural barriers when attempting mobile integration. The Claude Code SDK requires server-side execution with file system access and bash command capabilities, while iOS sandbox restrictions prevent direct SDK execution. Traditional client-server architectures require exposing backends through vulnerable networking solutions.

The SwiftUI Claude Code Client solves this through a two-phase approach: Phase 1 delivers immediate value via standard FastAPI backend integration with Claude Code SDK, enabling localhost/LAN deployment. Phase 2 enhances security through OpenZiti zero-trust networking, eliminating port exposure and firewall configuration complexity. This targets the early adopter segment of Claude Code CLI power users (~10,000-50,000 developers) who value privacy-first, self-hosted solutions with optional convenience services.

### Change Log

| Date | Version | Description | Author |
|------|---------|-------------|---------|
| 2025-01-15 | 1.0 | Initial PRD creation based on comprehensive project brief | John (PM) |

## Requirements

### Functional

1. **FR1:** The FastAPI backend SHALL wrap Claude Code SDK functionality through REST API endpoints that support `ClaudeSDKClient` session management and streaming responses
2. **FR2:** The system SHALL support multiple concurrent Claude Code conversation sessions with persistent context across app sessions and device restarts
3. **FR3:** The SwiftUI client SHALL provide real-time streaming of Claude Code responses using `async for message in client.receive_response()` pattern
4. **FR4:** The system SHALL support configuration-driven networking modes via environment variables (`NETWORKING_MODE=http` or `NETWORKING_MODE=ziti`)
5. **FR5:** The iOS client SHALL store conversation history locally and enable cross-app resume capability for interrupted sessions
6. **FR6:** The FastAPI backend SHALL provide session isolation ensuring multiple users require separate backend deployments for security
7. **FR7:** The system SHALL support core Claude Code feature parity including one-shot queries, multi-turn conversations, and basic tool access (read-only analysis, web search)
8. **FR8:** The SwiftUI client SHALL render technical responses with proper code syntax highlighting and formatting optimized for mobile screens
9. **FR9:** The system SHALL enable seamless device transition allowing users to continue Claude Code conversations when switching between iPad, macOS, and VisionOS
10. **FR10:** The backend SHALL provide health check endpoints and session management APIs for monitoring and debugging

### Non Functional

1. **NFR1:** The FastAPI backend SHALL achieve <200ms response time for Claude Code SDK wrapper endpoints under normal load conditions
2. **NFR2:** The SwiftUI client SHALL maintain smooth 60fps performance during real-time response streaming, even with complex liquid glass visual effects enabled
3. **NFR3:** The system SHALL operate within self-hosted infrastructure constraints, requiring no external dependencies beyond Anthropic API access
4. **NFR4:** The iOS client SHALL support iPad Pro M1+ hardware requirements for optimal liquid glass rendering performance
5. **NFR5:** The backend SHALL maintain backward compatibility when upgrading from Phase 1 HTTP mode to Phase 2 OpenZiti mode
6. **NFR6:** The system SHALL provide complete code transparency and customization capability through open source licensing
7. **NFR7:** The FastAPI backend SHALL support concurrent session management for up to 10 simultaneous Claude Code conversations per deployment instance
8. **NFR8:** The iOS client SHALL comply with iOS 26+ accessibility guidelines while utilizing liquid glass transparency and blur effects
9. **NFR9:** The system SHALL ensure Anthropic API credentials are stored only in backend, never in mobile client, with HTTPS enforcement for production deployments
10. **NFR10:** The solution SHALL enable setup and deployment by technical users through comprehensive documentation without requiring specialized infrastructure expertise

## User Interface Design Goals

### Overall UX Vision
Create a cutting-edge mobile development companion that brings Claude Code's conversational AI capabilities to touch interfaces through Apple's liquid glass design system. The experience should feel like having a senior developer mentor available on mobile devices, with visual sophistication that matches the advanced AI capabilities underneath.

### Key Interaction Paradigms
- **Conversational Flow**: Natural chat interface optimized for technical discussions with code syntax highlighting
- **Touch-First Design**: iPad-optimized interactions with gesture-based navigation and touch-friendly code review
- **Spatial Computing**: VisionOS spatial windows for immersive code architecture discussions
- **Liquid Glass Effects**: iOS 26+ native blur, translucency, and depth layering for premium visual experience

### Core Screens and Views
- **Conversation Interface**: Primary chat view with streaming Claude Code responses
- **Session Manager**: Multiple concurrent conversation management and switching
- **Connection Setup**: Backend server configuration and authentication
- **Settings & Preferences**: Client configuration and liquid glass effect customization
- **Session History**: Local conversation persistence and search

### Accessibility: WCAG AA
Liquid glass transparency and blur effects must maintain WCAG AA compliance with high contrast alternatives and reduced motion options for users with visual impairments or motion sensitivity.

### Branding
Apple liquid glass design system with iOS 26+ native effects. Clean, technical aesthetic that emphasizes the sophisticated AI capabilities while maintaining Apple platform design consistency across iPadOS and VisionOS.

### Target Device and Platforms: Cross-Platform
iPadOS 26.0+ (primary), VisionOS 26.0+ (spatial interface), with future macOS and iPhone support in Phase 2.

## Technical Assumptions

### Repository Structure: Monorepo
Single repository containing FastAPI backend, SwiftUI multiplatform client, documentation, and deployment scripts for simplified development and coordination.

### Service Architecture
**Phase 1**: Monolithic FastAPI backend with embedded Claude Code SDK integration. **Phase 2**: Same monolith enhanced with OpenZiti zero-trust networking layer via decorator pattern. This approach minimizes architectural complexity while enabling networking evolution.

### Testing Requirements
Unit + Integration testing with emphasis on Claude Code SDK integration testing, SwiftUI UI tests for core conversation flows, and performance testing for liquid glass + streaming combinations. Manual testing convenience methods for self-hosted deployment validation.

### Additional Technical Assumptions and Requests

- **Backend Technology**: Python 3.10+, FastAPI 0.100+, Claude Code SDK latest stable version
- **Database**: SQLite for backend session persistence, SkipSQL for on-device session storage (lightweight, serverless approach)
- **Frontend Technology**: SwiftUI with iOS 26+ liquid glass APIs, targeting iPad Pro M1+ and Vision Pro hardware
- **Networking**: Environment variable driven mode switching (`NETWORKING_MODE=http|ziti`)
- **Authentication**: API key management in backend only, simple token-based client auth, HTTPS enforcement
- **Deployment**: Self-hosted FastAPI with Docker containerization for simplified setup
- **Development**: iOS 26+ beta access required for liquid glass API development and testing
- **Performance**: Real-time WebSocket streaming optimized for mobile clients with offline session persistence

## Epic List

**Epic 1: Foundation & FastAPI Backend Core** - Establish project infrastructure, FastAPI + Claude Code SDK integration, and basic conversation streaming functionality

**Epic 2: SwiftUI Client & Real-time Streaming** - Create iPad-optimized SwiftUI interface with liquid glass design, real-time response streaming, and session management

**Epic 3: Multi-Session & Cross-Device Experience** - Enable multiple concurrent conversations, session persistence, and seamless device switching capabilities

**Epic 4: Production Deployment & OpenZiti Integration** - Add HTTPS security, Docker deployment, and Phase 2 zero-trust networking capabilities

## Epic Details

### Epic 1: Foundation & FastAPI Backend Core

Establish project infrastructure with Git repository, CI/CD pipeline, and core FastAPI application integrated with Claude Code SDK. Deliver basic conversation functionality through REST API endpoints with streaming support, enabling immediate validation of the core technical approach.

#### Story 1.1: Project Repository & Development Environment Setup

As a developer,
I want a properly configured project repository with development tooling,
so that I can begin building the FastAPI backend with standardized practices.

**Acceptance Criteria:**
1. Monorepo structure created with `/backend` and `/ios-app` directories
2. Python virtual environment configured with FastAPI and Claude Code SDK dependencies
3. Git repository initialized with `.gitignore` and basic README documentation
4. Development scripts created for local FastAPI server startup and testing
5. Basic health check endpoint returns 200 OK with project information

#### Story 1.2: Claude Code SDK Integration & Basic API Wrapper

As a mobile client,
I want to access Claude Code SDK functionality through REST API endpoints,
so that I can send queries and receive responses from Claude Code.

**Acceptance Criteria:**
1. FastAPI application wraps `ClaudeSDKClient` with session management
2. POST `/claude/query` endpoint accepts query text and returns Claude Code response
3. Environment variable configuration for Anthropic API credentials (never in client)
4. Error handling for invalid queries and Claude Code SDK failures
5. API response includes conversation context and streaming preparation

#### Story 1.3: Real-time Response Streaming Implementation

As a mobile user,
I want to see Claude Code responses appear in real-time as they're generated,
so that I can engage with long responses without waiting for completion.

**Acceptance Criteria:**
1. WebSocket endpoint `/claude/stream` enables real-time bidirectional communication
2. Server streams Claude Code responses using `async for message in client.receive_response()` pattern
3. Client can send new queries while previous responses are still streaming
4. Streaming maintains conversation context across multiple exchanges
5. Graceful handling of connection drops with reconnection support

### Epic 2: SwiftUI Client & Real-time Streaming

Create iPad-optimized SwiftUI application with liquid glass design system integration, real-time streaming conversation interface, and local session persistence. Deliver a production-quality mobile experience that rivals desktop Claude Code CLI workflows.

#### Story 2.1: SwiftUI Multiplatform Project & Basic UI Structure

As an iPad user,
I want a native SwiftUI application with liquid glass design,
so that I can access Claude Code through a beautiful mobile interface.

**Acceptance Criteria:**
1. SwiftUI multiplatform project targeting iPadOS 26.0+ and VisionOS 26.0+
2. Main conversation view with liquid glass background effects using iOS 26 APIs
3. Basic navigation structure supporting multiple conversation sessions
4. Configuration screen for backend server connection settings
5. App launches successfully on iPad Pro and displays liquid glass effects smoothly

#### Story 2.2: Conversation Interface & Message Display

As a mobile developer,
I want to have technical conversations with Claude Code in a touch-optimized interface,
so that I can discuss code architecture and get development guidance on mobile.

**Acceptance Criteria:**
1. Conversation view displays messages in scrollable chat interface
2. Code syntax highlighting for technical responses with mobile-optimized formatting
3. Touch interactions for code selection, copying, and sharing
4. Message input field with send button and keyboard management
5. Loading states and error handling for backend communication

#### Story 2.3: Real-time Streaming Integration & WebSocket Client

As a user,
I want to see Claude Code responses stream in real-time from the FastAPI backend,
so that I can engage with responses as they develop rather than waiting.

**Acceptance Criteria:**
1. WebSocket client connects to FastAPI streaming endpoint
2. Real-time message chunks display progressively in conversation view
3. Streaming performance maintains 60fps scrolling with liquid glass effects
4. Connection status indicators show backend connectivity state
5. Automatic reconnection logic handles temporary network interruptions

### Epic 3: Multi-Session & Cross-Device Experience

Enable multiple concurrent Claude Code conversations with persistent session management and cross-device synchronization. Deliver enterprise-grade session handling that supports complex development workflows across iPad, VisionOS, and future platform expansions.

#### Story 3.1: Multiple Concurrent Session Management

As a developer,
I want to maintain multiple simultaneous Claude Code conversations,
so that I can work on different technical topics without losing context.

**Acceptance Criteria:**
1. Backend supports up to 10 concurrent Claude Code sessions per deployment
2. Session manager UI allows creating, switching, and closing conversation sessions
3. Each session maintains independent conversation context and history
4. Session tabs or navigation clearly indicate active vs background sessions
5. Resource management prevents memory leaks from abandoned sessions

#### Story 3.2: Local Session Persistence & History

As a mobile user,
I want my Claude Code conversations to persist across app sessions,
so that I can continue technical discussions after closing and reopening the app.

**Acceptance Criteria:**
1. SkipSQL database stores conversation history locally on device
2. Session restoration recreates conversation context when app reopens
3. Search functionality enables finding previous technical discussions
4. Export capability for sharing conversation logs or code snippets
5. Privacy controls for automatic history cleanup and data retention

#### Story 3.3: Cross-Device Session Synchronization

As a multi-device user,
I want to continue Claude Code conversations when switching between iPad and VisionOS,
so that I can maintain workflow continuity across Apple devices.

**Acceptance Criteria:**
1. Backend SQLite database stores session state accessible by multiple clients
2. Session synchronization API enables device handoff for active conversations
3. Conflict resolution handles simultaneous edits from multiple devices
4. VisionOS spatial interface provides alternative view of same conversation data
5. Device identification and authentication prevents unauthorized session access

### Epic 4: Production Deployment & OpenZiti Integration

Add production-ready security, deployment automation, and Phase 2 zero-trust networking capabilities. Enable self-hosted deployment by technical users while preparing foundation for managed OpenZiti controller service.

#### Story 4.1: HTTPS Security & Production Configuration

As a self-hosting user,
I want secure HTTPS communication between my iOS client and FastAPI backend,
so that my Claude Code conversations remain private on my network.

**Acceptance Criteria:**
1. HTTPS/TLS configuration for production FastAPI deployment
2. SSL certificate management and renewal automation
3. API authentication tokens replace simple development authentication
4. Security headers and CORS configuration for mobile client access
5. Production logging and monitoring for security event detection

#### Story 4.2: Docker Deployment & Setup Documentation

As a technical user,
I want streamlined deployment of the FastAPI backend through Docker,
so that I can self-host Claude Code mobile access without complex configuration.

**Acceptance Criteria:**
1. Dockerfile and docker-compose.yml for single-command backend deployment
2. Environment variable configuration for all deployment settings
3. Comprehensive setup documentation with troubleshooting guide
4. Database initialization and migration scripts for clean deployment
5. Health check endpoints and deployment validation procedures

#### Story 4.3: OpenZiti Zero-Trust Integration (Phase 2)

As a security-conscious user,
I want zero-trust networking that eliminates exposed ports and firewall configuration,
so that I can access Claude Code securely without traditional network vulnerabilities.

**Acceptance Criteria:**
1. OpenZiti `@zitify` decorator integration activated via `NETWORKING_MODE=ziti`
2. Identity-based authentication replaces traditional API keys
3. Backend becomes completely private with no exposed network ports
4. iOS Swift OpenZiti SDK integration for cryptographic device identity
5. Backward compatibility maintained with HTTP mode for development usage

## Checklist Results Report

### Executive Summary

- **Overall PRD Completeness:** 85% - Strong foundation with clear technical vision
- **MVP Scope Appropriateness:** Just Right - Well-scoped for complexity while delivering core value
- **Readiness for Architecture Phase:** Nearly Ready - One critical gap needs addressing
- **Most Critical Concern:** Missing user research validation and competitive analysis

### Category Analysis Table

| Category                         | Status  | Critical Issues |
| -------------------------------- | ------- | --------------- |
| 1. Problem Definition & Context  | PARTIAL | No user research validation, market sizing speculative |
| 2. MVP Scope Definition          | PASS    | Well-defined Phase 1/2 approach, clear boundaries |
| 3. User Experience Requirements  | PASS    | Comprehensive liquid glass vision, accessibility considered |
| 4. Functional Requirements       | PASS    | Specific, testable requirements with clear technical scope |
| 5. Non-Functional Requirements   | PASS    | Performance targets defined, security model clear |
| 6. Epic & Story Structure        | PASS    | Logical sequencing, appropriate story sizing |
| 7. Technical Guidance            | PASS    | Clear tech stack, architecture decisions documented |
| 8. Cross-Functional Requirements | PARTIAL | Missing operational monitoring and deployment details |
| 9. Clarity & Communication       | PASS    | Well-structured, consistent terminology |

### Top Issues by Priority

**BLOCKERS:**
- **User Research Gap**: No validation of 10K-50K Claude Code CLI user base claims or mobile workflow needs
- **iOS 26 Dependency Risk**: Entire liquid glass design depends on unconfirmed iOS 26 APIs

**HIGH:**
- **Operational Requirements Missing**: No monitoring, logging, or production support strategy defined
- **Market Competition Analysis**: Limited competitive landscape understanding

**MEDIUM:**
- **Enterprise Requirements**: Self-hosted enterprise features undefined for future phases
- **Performance Testing Strategy**: No clear approach for liquid glass + streaming performance validation

### MVP Scope Assessment

**Appropriately Scoped:**
- Phase 1 HTTP-first approach reduces complexity risk
- Multiple concurrent sessions adds value without over-engineering
- Clear technical boundaries between MVP and future enhancements

**Potential Complexity Concerns:**
- Liquid glass design system may require significant iOS 26 beta validation effort
- Real-time streaming + visual effects performance testing needed early

### Technical Readiness

**Strong Technical Foundation:**
- Clear architecture with FastAPI + Claude Code SDK integration
- Well-defined technology stack and deployment approach
- Sensible two-phase networking evolution (HTTP → OpenZiti)

**Areas Needing Architect Investigation:**
- iOS 26 liquid glass API validation and fallback strategies
- WebSocket streaming performance optimization techniques
- OpenZiti integration patterns with async FastAPI

### Recommendations

**Before Architecture Phase:**
1. **Conduct Claude Code CLI User Survey**: Validate mobile workflow needs and iOS 26 adoption timeline
2. **iOS 26 Beta Research**: Investigate liquid glass API availability and document fallback design approach
3. **Define Operational Requirements**: Add monitoring, logging, and production deployment strategy

**For Architecture Phase:**
1. Focus on Phase 1 HTTP implementation with Phase 2 OpenZiti upgrade path
2. Prioritize performance testing strategy for liquid glass + streaming combination
3. Design fallback UI patterns if iOS 26 liquid glass APIs differ from expectations

### Final Decision

**NEARLY READY FOR ARCHITECT** - The PRD provides comprehensive technical guidance and well-structured epic breakdown. Address user research validation and iOS 26 dependency risks, then proceed to architecture phase with confidence in the technical approach.

## Next Steps

### UX Expert Prompt

Please review the attached SwiftUI Claude Code Client PRD and create detailed UI/UX specifications for the liquid glass design system integration. Focus on iOS 26+ native effects, iPad-optimized conversation interface, and VisionOS spatial computing adaptations. Address the performance requirements for real-time streaming + visual effects, and provide fallback design patterns if liquid glass APIs differ from expectations.

### Architect Prompt

Please review the attached SwiftUI Claude Code Client PRD and create the technical architecture specification. Prioritize the Phase 1 FastAPI + Claude Code SDK integration with WebSocket streaming, then design the Phase 2 OpenZiti zero-trust networking upgrade path. Address the monorepo structure, concurrent session management, and cross-platform SwiftUI deployment strategy for iPadOS/VisionOS targeting.