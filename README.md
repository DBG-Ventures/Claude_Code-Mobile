# SwiftUI Claude Code Client

<div align="center">
  <h3 align="center">Claude Code Mobile</h3>
  <p align="center">
    A cross-platform SwiftUI Claude Code client for iPad, macOS, and VisionOS
    <br />
    <strong>Secure, private access to Claude Code functionality with zero-trust networking</strong>
    <br />
    <br />
    <a href="#getting-started"><strong>Get Started »</strong></a>
    <br />
    <br />
    <a href="#usage">View Demo</a>
    ·
    <a href="https://github.com/BeardedWonderDev/Claude_Code-Mobile/issues">Report Bug</a>
    ·
    <a href="https://github.com/BeardedWonderDev/Claude_Code-Mobile/issues">Request Feature</a>
  </p>
</div>

## Table of Contents

- [About The Project](#about-the-project)
- [Built With](#built-with)
- [Project Status](#project-status)
- [Architecture](#architecture)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [Development Setup](#development-setup)
- [License](#license)
- [Contact](#contact)
- [Acknowledgments](#acknowledgments)

## About The Project

The SwiftUI Claude Code Client provides secure, mobile-native access to Claude Code capabilities without exposing your backend services to network vulnerabilities. This project eliminates the traditional trade-off between security and convenience by combining true privacy (code never leaves your machine), zero-configuration setup, and native Apple platform integration.

### Key Features

- **🔒 Privacy First**: Code never leaves your local infrastructure
- **📱 Native Experience**: Liquid glass design optimized for iPadOS 26+ and VisionOS 26+
- **⚡ Real-time Streaming**: Live Claude Code responses with async streaming
- **🌐 Zero-Trust Architecture**: OpenZiti integration for secure remote access (Phase 2)
- **🔄 Session Persistence**: Cross-device conversation continuity
- **🛠️ Self-Hosted**: Complete control over your development environment

### Problem Statement

Developers using Claude Code face fundamental barriers when attempting mobile integration:

- **Platform Limitations**: Claude Code SDK requires server-side execution with file system access
- **Security Challenges**: Traditional client-server architectures expose backends through vulnerable networking
- **Mobile Restrictions**: iOS sandbox prevents direct Claude Code SDK execution
- **Context Loss**: Mobile sessions lose access to project-wide analysis and conversation history

### Solution Architecture

**Phase 1: FastAPI Backend (Current)**
- Standard HTTP/HTTPS FastAPI server wrapping Claude Code SDK
- Real-time WebSocket streaming for live responses
- Self-hosted deployment for complete privacy
- Multi-session support for concurrent conversations

**Phase 2: Zero-Trust Enhancement (Planned)**
- OpenZiti integration for network invisibility
- Identity-based cryptographic authentication
- Hosted controller service ($5/month) for zero-config setup
- Dark service architecture with no exposed ports

### Built With

**Planned Frontend Technologies:**
- ![SwiftUI](https://img.shields.io/badge/SwiftUI-FA7343?style=for-the-badge&logo=swift&logoColor=white)
- ![iOS](https://img.shields.io/badge/iPadOS%2026+-000000?style=for-the-badge&logo=ios&logoColor=white)
- ![VisionOS](https://img.shields.io/badge/VisionOS%2026+-000000?style=for-the-badge&logo=apple&logoColor=white)

**Planned Backend Technologies:**
- ![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)
- ![FastAPI](https://img.shields.io/badge/FastAPI-005571?style=for-the-badge&logo=fastapi&logoColor=white)
- ![Claude Code SDK](https://img.shields.io/badge/Claude_Code_SDK-FF6B35?style=for-the-badge&logo=anthropic&logoColor=white)

**Future Security & Networking:**
- ![OpenZiti](https://img.shields.io/badge/OpenZiti-00D4AA?style=for-the-badge&logo=openziti&logoColor=white)

## Project Status

> **⚠️ Early Development Phase**: This project is in active planning and early development. No functional code exists yet.

**Current Status:** 📋 **Planning & Architecture**

- ✅ Project brief completed
- ✅ Technical architecture designed
- ✅ Repository structure planned
- 🚧 Seeking contributors for initial implementation
- 🚧 FastAPI backend development needed
- 🚧 SwiftUI mobile client development needed

**What's Available Now:**
- Comprehensive project documentation
- Technical architecture specifications
- Development roadmap and contribution guidelines
- Community discussion and planning

**What's Not Available Yet:**
- No working backend server
- No mobile application
- No installation or usage instructions (coming after MVP)

## Architecture

### Phase 1: HTTP Backend (Current Target)
```
┌─────────────────┐    HTTP/WebSocket    ┌──────────────────┐
│   SwiftUI App   │◄────────────────────►│  FastAPI Server  │
│   (iPad/Vision) │                      │ + Claude Code SDK │
└─────────────────┘                      └──────────────────┘
```

**Core Components Needed:**
- **FastAPI Backend**: Python server wrapping Claude Code SDK
- **SwiftUI Client**: Native iOS app with liquid glass design
- **WebSocket Streaming**: Real-time response streaming
- **Session Management**: Persistent conversation contexts

### Phase 2: Zero-Trust Enhancement (Future)
```
┌─────────────────┐    OpenZiti Network   ┌──────────────────┐
│   SwiftUI App   │◄────────────────────►│  Dark Service    │
│   (Multi-device)│                      │  (No open ports) │
└─────────────────┘                      └──────────────────┘
                           ▲
                           │ Identity Auth
                    ┌──────────────┐
                    │ Ziti Controller│
                    │   (Hosted)     │
                    └──────────────┘
```

## Roadmap

### Phase 1 (In Development) 🚧
**Target: MVP with basic functionality**
- [ ] FastAPI backend with Claude Code SDK integration
- [ ] SwiftUI iOS client (iPad primary)
- [ ] Real-time streaming responses
- [ ] Multi-session support
- [ ] Basic authentication & security
- [ ] Session persistence

### Phase 2 (Planned) 📋
**Target: Zero-trust networking & enhanced security**
- [ ] OpenZiti zero-trust integration
- [ ] Hosted controller service ($5/month)
- [ ] Identity-based authentication
- [ ] Dark service architecture
- [ ] macOS & iPhone support expansion

### Future Enhancements 🔮
**Target: Advanced features & enterprise adoption**
- [ ] VisionOS spatial interface optimization
- [ ] Voice command integration
- [ ] Advanced code visualization
- [ ] Team collaboration features
- [ ] Enterprise SSO integration
- [ ] Plugin architecture for community extensions

See the [open issues](https://github.com/BeardedWonderDev/Claude_Code-Mobile/issues) for a full list of proposed features and known issues.

## Contributing

🎯 **We're actively seeking contributors to help build this project from the ground up!**

This is an early-stage open-source project where every contribution makes a significant impact. We're looking for developers interested in mobile AI tools, SwiftUI development, Python backend development, and zero-trust networking.

### 🚀 How to Get Started

**Choose Your Track:**

**Backend Development (Python/FastAPI)**
- Implement Claude Code SDK integration
- Build WebSocket streaming for real-time responses
- Create session management system
- Design REST API endpoints

**iOS Development (SwiftUI)**
- Build liquid glass UI components
- Implement real-time conversation interface
- Create multi-device session sync
- Optimize for iPad Pro and VisionOS

**DevOps & Infrastructure**
- Set up CI/CD pipelines
- Create Docker containerization
- Build deployment automation
- Design testing frameworks

**Documentation & Community**
- Improve developer documentation
- Create setup tutorials
- Write API documentation
- Build community resources

### 📋 Contribution Process

1. **Check Current Issues**: Look at [open issues](https://github.com/BeardedWonderDev/Claude_Code-Mobile/issues) or create new ones
2. **Join Discussion**: Use [GitHub Discussions](https://github.com/BeardedWonderDev/Claude_Code-Mobile/discussions) for planning
3. **Fork & Develop**: 
   ```bash
   git clone https://github.com/your-username/Claude_Code-Mobile.git
   git checkout -b feature/your-feature-name
   ```
4. **Follow Standards**: See [Development Setup](#development-setup) below
5. **Submit PR**: Create detailed pull request with clear description

### 🛠️ Development Standards

**Code Quality:**
- **Python**: Follow PEP 8, use Black formatter, type hints required
- **Swift**: Follow Swift style guide, use SwiftLint, document public APIs
- **Git**: Conventional commits, descriptive messages, linear history preferred

**Testing Requirements:**
- Write unit tests for new functionality
- Integration tests for API endpoints
- UI tests for critical user flows
- Performance tests for streaming features

**Documentation:**
- Comment complex logic and architectural decisions
- Update README for significant changes
- API documentation for all endpoints
- Inline code documentation

### 🏗️ Current Priority Areas

**High Priority (Phase 1 MVP):**
1. **FastAPI Backend Foundation**: Core server with Claude Code SDK integration
2. **SwiftUI Conversation UI**: Basic chat interface with streaming support  
3. **WebSocket Implementation**: Real-time streaming between backend and client
4. **Session Management**: Persistent conversation contexts

**Medium Priority:**
1. **Authentication System**: Secure API key management
2. **Multi-session Support**: Concurrent conversation handling
3. **Error Handling**: Graceful degradation and retry logic
4. **Basic Testing**: Unit tests for core functionality

**Future Focus:**
1. **OpenZiti Integration**: Zero-trust networking (Phase 2)
2. **Advanced UI**: Liquid glass effects and VisionOS optimization
3. **Enterprise Features**: Team management and advanced security

### 💬 Community Guidelines

**Communication:**
- Be respectful and inclusive
- Use GitHub Discussions for architecture and planning
- Use Issues for specific bugs and features  
- Tag maintainers for urgent issues

**Collaboration:**
- Coordinate with other contributors to avoid duplicate work
- Share knowledge and help other contributors
- Review others' PRs constructively
- Document decisions and rationale

### 🎯 Contributor Recognition

Active contributors will be:
- Listed in project acknowledgments
- Given credit in release notes
- Invited to project planning discussions
- Considered for maintainer roles as project grows

## Development Setup

> **Note**: This section will be expanded as initial implementations are completed.

### Prerequisites

**For Backend Development:**
- Python 3.9+
- Claude Code CLI installed (`npm install -g @anthropic-ai/claude-code`)
- Anthropic API key
- Git and basic command line familiarity

**For iOS Development:**
- macOS with Xcode 15+
- iOS 17+ SDK (targeting iPadOS 26+ for liquid glass features)
- Basic SwiftUI knowledge
- iPad Pro or iOS Simulator for testing

**For Both:**
- Git workflow familiarity
- Understanding of REST APIs and WebSockets
- Familiarity with async/await patterns

### Repository Structure (Planned)

```
claude-code-mobile/
├── docs/                 # Project documentation
│   ├── brief.md         # Current project brief
│   ├── architecture.md  # Technical architecture (TBD)
│   └── api.md          # API documentation (TBD)
├── backend/             # FastAPI backend (TBD)
│   ├── app/            # Core application
│   ├── tests/          # Backend tests
│   └── requirements.txt
├── ios-app/            # SwiftUI mobile app (TBD)
│   ├── Shared/         # Shared business logic
│   ├── iPad/           # iPad-specific views
│   └── Vision/         # VisionOS-specific views
├── scripts/            # Development utilities (TBD)
└── .github/           # CI/CD workflows (TBD)
```

### Getting Involved

1. **Read the Project Brief**: Review `docs/brief.md` for complete technical context
2. **Choose Your Focus**: Pick backend, iOS, DevOps, or documentation
3. **Start Small**: Look for "good first issue" labels
4. **Ask Questions**: Use GitHub Discussions for technical questions
5. **Share Progress**: Update issues with your progress and blockers

### Local Development (Coming Soon)

Detailed setup instructions will be added as core components are implemented:
- Backend development server setup
- iOS app configuration and building
- Testing frameworks and procedures
- Development workflow and debugging tips

## License

Distributed under the MIT License. See `LICENSE` for more information.

```
MIT License

Copyright (c) 2024 Claude Code Mobile Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Contact

**Project Maintainer**: BeardedWonder
- GitHub: [@BeardedWonderDev](https://github.com/BeardedWonderDev)
- Project Link: [https://github.com/BeardedWonderDev/Claude_Code-Mobile](https://github.com/BeardedWonderDev/Claude_Code-Mobile)

**Community**
- GitHub Discussions: [Project Discussions](https://github.com/BeardedWonderDev/Claude_Code-Mobile/discussions)
- Issues: [Report Bugs/Request Features](https://github.com/BeardedWonderDev/Claude_Code-Mobile/issues)

## Acknowledgments

This project builds upon the excellent work of many open-source contributors:

- **[Anthropic](https://anthropic.com)** - Claude Code SDK and API
- **[OpenZiti](https://openziti.io)** - Zero-trust networking architecture
- **[FastAPI](https://fastapi.tiangolo.com)** - Modern Python web framework
- **[Apple SwiftUI](https://developer.apple.com/xcode/swiftui/)** - Declarative UI framework
- **[Best README Template](https://github.com/othneildrew/Best-README-Template)** - README structure inspiration

**Special Thanks:**
- Claude Code CLI community for feedback and feature suggestions
- Open-source contributors who make self-hosted development tools possible
- Apple's platform innovation enabling cutting-edge mobile development experiences

---

<div align="center">
  <strong>Built with ❤️ by the open-source community</strong>
  <br />
  <sub>Empowering secure, private, mobile-first AI development workflows</sub>
</div>