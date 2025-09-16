//
//  SessionSidebarView.swift
//  iPad-optimized sidebar navigation for session management.
//
//  Provides compact session switching interface for NavigationSplitView with session
//  management, search functionality, and settings access optimized for iPad use.
//

import SwiftUI
import Combine

// MARK: - Session Sidebar View

struct SessionSidebarView: View {

    // MARK: - Environment Objects

    @EnvironmentObject var networkManager: NetworkManager
    @EnvironmentObject var sessionViewModel: SessionListViewModel
    @EnvironmentObject var sessionStateManager: SessionStateManager  // NEW: SessionManager integration

    // MARK: - Binding Properties

    @Binding var selectedSessionId: String?

    // MARK: - State Properties
    @State private var searchText: String = ""
    @State private var showingNewSessionSheet: Bool = false
    @State private var showingSettings: Bool = false
    @State private var showingDeleteAlert: Bool = false
    @State private var sessionToDelete: SessionResponse?

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header section
            sidebarHeader

            // Search bar
            searchSection

            // Sessions list
            sessionsListSection

            Spacer()

            // Bottom toolbar
            bottomToolbar
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            setupViewModel()
        }
        .onReceive(sessionViewModel.$selectedSession) { selectedSession in
            if let sessionId = selectedSession?.sessionId {
                selectedSessionId = sessionId
            }
        }
        .sheet(isPresented: $showingNewSessionSheet) {
            NewSessionSheet()
                .environmentObject(networkManager)
                .environmentObject(sessionViewModel)
        }
        .sheet(isPresented: $showingSettings) {
            EditableSettingsView()
                .environmentObject(networkManager)
        }
        .alert("Delete Session", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let session = sessionToDelete {
                    sessionViewModel.deleteSession(session)
                    sessionToDelete = nil
                }
            }
        } message: {
            Text("Are you sure you want to delete this session? This action cannot be undone.")
        }
    }

    // MARK: - Header Section

    private var sidebarHeader: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Claude Code")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("\(sessionViewModel.sessions.count) sessions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: { showingNewSessionSheet = true }) {
                    Image(systemName: "plus")
                        .font(.title3)
                        .foregroundColor(.blue)
                        .frame(width: 32, height: 32)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Circle())
                }
                .disabled(sessionViewModel.isLoading)
            }

            // Connection status indicator
            connectionStatusIndicator
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGroupedBackground))
    }

    private var connectionStatusIndicator: some View {
        VStack(spacing: 6) {
            // Network Connection Status
            HStack(spacing: 8) {
                Circle()
                    .fill(networkManager.claudeService.isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)

                Text(networkManager.claudeService.isConnected ? "Network Connected" : "Network Disconnected")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if !networkManager.isNetworkAvailable {
                    Image(systemName: "wifi.slash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            // SessionManager Status
            HStack(spacing: 8) {
                Circle()
                    .fill(sessionManagerStatusColor)
                    .frame(width: 8, height: 8)

                Text(sessionManagerStatusText)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                // SessionManager statistics
                if sessionStateManager.sessionManagerStatus == .connected {
                    Text("\(sessionStateManager.activeSessions.count) active")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Search Section

    private var searchSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.body)

            TextField("Search sessions...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.body)

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.body)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Sessions List Section

    private var sessionsListSection: some View {
        Group {
            if sessionViewModel.isLoading {
                loadingView
            } else if filteredSessions.isEmpty {
                emptyStateView
            } else {
                sessionsList
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)

            Text("Loading sessions...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: searchText.isEmpty ? "message.badge" : "magnifyingglass")
                .font(.title)
                .foregroundColor(.secondary)

            VStack(spacing: 4) {
                Text(searchText.isEmpty ? "No Sessions" : "No Results")
                    .font(.headline)

                Text(searchText.isEmpty ?
                     "Start a new conversation" :
                     "Try a different search term")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            if searchText.isEmpty {
                Button(action: { showingNewSessionSheet = true }) {
                    Text("New Session")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 16)
    }

    private var sessionsList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 4) {
                ForEach(filteredSessions) { session in
                    SidebarSessionRow(
                        session: session,
                        isSelected: selectedSessionId == session.sessionId,
                        onSelect: { selectedSession in
                            selectedSessionId = selectedSession.sessionId
                            sessionViewModel.selectSession(selectedSession)
                        },
                        onDelete: { sessionToDelete in
                            self.sessionToDelete = sessionToDelete
                            self.showingDeleteAlert = true
                        }
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 16) {
                // Settings button
                Button(action: { showingSettings = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "gear")
                            .font(.body)

                        Text("Settings")
                            .font(.body)
                    }
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Quick actions menu
                Menu {
                    Button(action: { showingNewSessionSheet = true }) {
                        Label("New Session", systemImage: "plus")
                    }

                    Button(action: { refreshSessions() }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }

                    Button(action: { clearAllSessions() }) {
                        Label("Clear All", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body)
                        .foregroundColor(.blue)
                        .frame(width: 44, height: 44)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Computed Properties

    private var filteredSessions: [SessionResponse] {
        // Combine SessionManager sessions with legacy sessions
        let allSessions = combineSessionSources()

        if searchText.isEmpty {
            return allSessions
        } else {
            return allSessions.filter { session in
                session.sessionName?.localizedCaseInsensitiveContains(searchText) ?? false ||
                session.sessionId.localizedCaseInsensitiveContains(searchText) ||
                session.messages.contains { message in
                    message.content.localizedCaseInsensitiveContains(searchText)
                }
            }
        }
    }

    // SessionManager status indicators for connection display
    private var sessionManagerStatusColor: Color {
        switch sessionStateManager.sessionManagerStatus {
        case .connected:
            return .green
        case .connecting:
            return .orange
        case .disconnected:
            return .red
        case .degraded:
            return .yellow
        case .error:
            return .red
        }
    }

    private var sessionManagerStatusText: String {
        switch sessionStateManager.sessionManagerStatus {
        case .connected:
            return "SessionManager Connected"
        case .connecting:
            return "SessionManager Connecting"
        case .disconnected:
            return "SessionManager Disconnected"
        case .degraded:
            return "SessionManager Degraded"
        case .error:
            return "SessionManager Error"
        }
    }

    // MARK: - SessionManager Integration Methods

    private func combineSessionSources() -> [SessionResponse] {
        // Combine SessionManager sessions with legacy sessions for comprehensive display
        var combinedSessions: [SessionResponse] = []

        // Add SessionManager sessions (converted to SessionResponse format)
        let sessionManagerSessions = sessionStateManager.activeSessions.map { sessionManagerSession in
            convertToSessionResponse(sessionManagerSession)
        }
        combinedSessions.append(contentsOf: sessionManagerSessions)

        // Add legacy sessions (avoiding duplicates)
        for legacySession in sessionViewModel.sessions {
            if !combinedSessions.contains(where: { $0.sessionId == legacySession.sessionId }) {
                combinedSessions.append(legacySession)
            }
        }

        // Sort by most recent activity
        return combinedSessions.sorted { $0.updatedAt > $1.updatedAt }
    }

    // MARK: - Setup Methods

    private func setupViewModel() {
        // Setup legacy SessionListViewModel
        sessionViewModel.setClaudeService(networkManager.claudeService)

        // Setup SessionStateManager integration
        setupSessionManagerIntegration()

        // Load sessions from both sources
        loadAllSessions()
    }

    private func setupSessionManagerIntegration() {
        // Initialize SessionStateManager integration
        // SessionStateManager should already be configured via environment injection

        print("✅ SessionSidebarView SessionManager integration initialized")
    }

    private func loadAllSessions() {
        // Load from legacy source
        sessionViewModel.loadSessions()

        // Load from SessionManager
        Task {
            do {
                try await sessionStateManager.restoreSessionsFromPersistence()
            } catch {
                print("⚠️ Failed to restore sessions in sidebar: \(error)")
            }
        }
    }

    private func refreshSessions() {
        // Refresh both legacy and SessionManager sessions
        sessionViewModel.loadSessions()

        Task {
            do {
                try await sessionStateManager.refreshSessionsFromBackend()
            } catch {
                print("⚠️ Failed to refresh sessions in sidebar: \(error)")
            }
        }
    }

    private func clearAllSessions() {
        // Implementation would depend on session management requirements
        // This could show a confirmation dialog
        // For now, delegate to SessionStateManager for enhanced session cleanup
        Task {
            // TODO: Implement session cleanup through SessionStateManager
            // await sessionStateManager.clearExpiredSessions() // Method not yet implemented
            print("Session cleanup placeholder - not yet implemented")
        }
    }

    // MARK: - Type Conversion Methods

    private func convertToSessionResponse(_ sessionManagerResponse: SessionManagerResponse) -> SessionResponse {
        return SessionResponse(
            sessionId: sessionManagerResponse.sessionId,
            userId: sessionManagerResponse.userId,
            sessionName: sessionManagerResponse.sessionName,
            status: sessionManagerResponse.status,
            messages: sessionManagerResponse.conversationHistory?.map { convMessage in
                ClaudeMessage(
                    id: convMessage.messageId ?? convMessage.id,
                    content: convMessage.content,
                    role: convMessage.role,
                    timestamp: convMessage.timestamp,
                    sessionId: sessionManagerResponse.sessionId,
                    metadata: convMessage.sessionManagerContext ?? [:]
                )
            } ?? [],
            createdAt: sessionManagerResponse.createdAt,
            updatedAt: sessionManagerResponse.lastActiveAt,
            messageCount: sessionManagerResponse.messageCount,
            context: [:] // Default empty context
        )
    }
}

// MARK: - Enhanced Sidebar Session Row with SessionManager Integration

struct SidebarSessionRow: View {
    let session: SessionResponse
    let isSelected: Bool
    let onSelect: (SessionResponse) -> Void
    let onDelete: (SessionResponse) -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Enhanced status indicator with SessionManager benefits
            VStack(spacing: 2) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                // SessionManager persistent client indicator
                if isSessionManagerSession {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 6))
                        .foregroundColor(.orange)
                }
            }

            // Session content with SessionManager metadata
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(session.sessionName ?? "Untitled")
                        .font(.body)
                        .fontWeight(isSelected ? .semibold : .medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    // SessionManager instant switching indicator
                    if isSessionManagerSession {
                        Image(systemName: "speedometer")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }

                    Spacer()

                    Text(formatRelativeTime(session.updatedAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("\(session.messageCount)")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text("messages")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    // SessionManager session type indicator
                    if isSessionManagerSession {
                        Text("• Persistent")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }

                    Spacer()

                    // Delete button (only show when selected or on hover)
                    if isSelected {
                        Button(action: { onDelete(session) }) {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }

                // Last message preview with SessionManager context
                if let lastMessage = session.messages.last {
                    HStack {
                        Text(lastMessage.content)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        if isSessionManagerSession {
                            Spacer()
                            Text("✓ Context")
                                .font(.system(size: 9))
                                .foregroundColor(.green)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(rowBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(rowBorderColor, lineWidth: isSessionManagerSession ? 1 : 0)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect(session)
        }
    }

    private var statusColor: Color {
        switch session.status {
        case .active:
            return .green
        case .completed:
            return .blue
        case .error:
            return .red
        case .paused:
            return .orange
        }
    }

    // SessionManager session detection and visual indicators
    private var isSessionManagerSession: Bool {
        // Check if this session is from SessionManager (enhanced session features)
        return session.sessionName?.contains("SessionManager") == true ||
               session.sessionName?.contains("Mobile Session") == true
    }

    private var rowBackgroundColor: Color {
        if isSelected {
            return isSessionManagerSession ? Color.orange.opacity(0.15) : Color.blue.opacity(0.1)
        } else {
            return Color.clear
        }
    }

    private var rowBorderColor: Color {
        if isSelected {
            return isSessionManagerSession ? Color.orange.opacity(0.4) : Color.blue.opacity(0.3)
        } else {
            return isSessionManagerSession ? Color.orange.opacity(0.2) : Color.clear
        }
    }

    private func formatRelativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)

        if interval < 60 {
            return "now"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))h"
        } else {
            return "\(Int(interval / 86400))d"
        }
    }
}



// MARK: - Preview

#Preview {
    @Previewable @State var selectedSessionId: String? = nil

    return NavigationSplitView {
        SessionSidebarView(selectedSessionId: $selectedSessionId)
            .environmentObject(NetworkManager())
            .environmentObject(SessionListViewModel())
            .environmentObject(SessionStateManager(
                claudeService: ClaudeService(baseURL: URL(string: "http://localhost:8000")!),
                persistenceService: SessionPersistenceService()
            ))
    } detail: {
        Text("Select a session")
            .font(.title2)
            .foregroundColor(.secondary)
    }
}