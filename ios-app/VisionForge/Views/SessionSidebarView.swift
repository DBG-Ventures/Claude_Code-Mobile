//
//  SessionSidebarView.swift
//  Native iOS 26 sidebar navigation with floating glass elements.
//
//  Implements liquid glass design using glassEffect modifier and GlassEffectContainer
//  for proper iOS 26 floating functional layer implementation.
//

import SwiftUI
import Combine

struct SessionSidebarView: View {
    // MARK: - Environment Objects
    @Environment(NetworkManager.self) var networkManager
    @Environment(SessionRepository.self) var sessionRepository

    // MARK: - Binding Properties
    @Binding var selectedSessionId: String?

    // MARK: - State Properties
    @State private var searchText: String = ""
    @State private var showingNewSessionSheet: Bool = false
    @State private var showingSettings: Bool = false
    @State private var showingDeleteAlert: Bool = false
    @State private var sessionToDelete: SessionManagerResponse?
    @State private var showingDeleteError: Bool = false
    @State private var deleteErrorMessage: String = ""

    // MARK: - Body
    var body: some View {
        ZStack {
            // Base layer: Sessions list that extends edge-to-edge
            ScrollView {
                LazyVStack(spacing: 8) {
                    // Top padding to account for floating header with status bar
                    Color.clear
                        .frame(height: 160) // Space for header + search + status bar

                    if sessionRepository.isLoading {
                        loadingView
                    } else if filteredSessions.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(filteredSessions) { session in
                            SessionRow(
                                session: session,
                                isSelected: selectedSessionId == session.sessionId,
                                onSelect: { selectSession(session) },
                                onDelete: { deleteSession(session) }
                            )
                            .padding(.horizontal, 16)
                        }
                    }
                }
            }

            // Floating glass layer: Header and toolbar
            VStack {
                // Floating header with glass effect
                GlassEffectContainer {
                    VStack(spacing: 12) {
                        VStack(spacing: 0) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Claude Code")
                                        .font(.title2)
                                        .fontWeight(.bold)

                                    Text("\(filteredSessions.count) sessions")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Button(action: { showingNewSessionSheet = true }) {
                                    Image(systemName: "plus")
                                        .font(.title3)
                                        .foregroundColor(.blue)
                                        .frame(width: 32, height: 32)
                                        .glassEffect(.clear.tint(.blue.opacity(0.1)), in: Circle())
                                }
                                .disabled(sessionRepository.isLoading)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 50)

                            // Connection status indicator
                            connectionStatusIndicator
                                .padding(.horizontal, 16)
                        }
                        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 8))

                        // Search bar
                        searchSection
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                    }
                }
                .ignoresSafeArea(edges: .top)

                Spacer()

                // Floating bottom toolbar
                GlassEffectContainer {
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
                            .glassEffect(.clear.tint(.blue.opacity(0.1)), in: RoundedRectangle(cornerRadius: 8))
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
                                .glassEffect(.clear.tint(.blue.opacity(0.1)), in: Circle())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 5)
                }
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .onAppear {
            setupViewModel()
        }
        .sheet(isPresented: $showingNewSessionSheet) {
            NewSessionSheet()
        }
        .sheet(isPresented: $showingSettings) {
            EditableSettingsView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .alert("Delete Session", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let session = sessionToDelete {
                    deleteSessionAction(session)
                }
            }
        } message: {
            Text("Are you sure you want to delete this session? This action cannot be undone.")
        }
        .alert("Delete Failed", isPresented: $showingDeleteError) {
            Button("OK", role: .cancel) {
                deleteErrorMessage = ""
            }
        } message: {
            Text(deleteErrorMessage)
        }
    }

    // MARK: - Connection Status Indicator
    private var connectionStatusIndicator: some View {
        VStack(spacing: 6) {
            // Network Connection Status
            HStack(spacing: 8) {
                Circle()
                    .frame(width: 8, height: 8)
                    .foregroundColor(networkManager.claudeService.isConnected ? .green : .red)

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
                    .frame(width: 8, height: 8)
                    .foregroundColor(sessionManagerStatusColor)

                Text(sessionManagerStatusText)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if sessionRepository.sessionManagerStatus == .connected {
                    Text("\(sessionRepository.activeSessions.count) active")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Search Section
    private var searchSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.body)

            TextField("Search sessions...", text: $searchText)
                .textFieldStyle(.plain)
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
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Loading View
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

    // MARK: - Empty State View
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

    // MARK: - Computed Properties
    private var filteredSessions: [SessionManagerResponse] {
        let allSessions = sessionRepository.sessions

        if searchText.isEmpty {
            return allSessions
        } else {
            return allSessions.filter { session in
                (session.sessionName ?? "").localizedCaseInsensitiveContains(searchText) ||
                session.sessionId.localizedCaseInsensitiveContains(searchText) ||
                (session.conversationHistory?.contains { message in
                    message.content.localizedCaseInsensitiveContains(searchText)
                } ?? false)
            }
        }
    }

    private var sessionManagerStatusColor: Color {
        switch sessionRepository.sessionManagerStatus {
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
        switch sessionRepository.sessionManagerStatus {
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

    // MARK: - Helper Methods
    private func combineSessionSources() -> [SessionManagerResponse] {
        // No longer needed - using sessionRepository.sessions directly
        return sessionRepository.sessions.sorted { $0.lastActiveAt > $1.lastActiveAt }
    }

    private func setupViewModel() {
        // Repository is already initialized with claudeService
        Task {
            do {
                _ = try await sessionRepository.getAllSessions()
            } catch {
                print("⚠️ Failed to load sessions: \(error)")
            }
        }
    }

    private func selectSession(_ session: SessionManagerResponse) {
        selectedSessionId = session.sessionId
        sessionRepository.selectSession(session)
    }

    private func deleteSession(_ session: SessionManagerResponse) {
        sessionToDelete = session
        showingDeleteAlert = true
    }

    private func deleteSessionAction(_ session: SessionManagerResponse) {
        Task {
            do {
                try await sessionRepository.deleteSession(session.sessionId)
                sessionToDelete = nil
                if selectedSessionId == session.sessionId {
                    selectedSessionId = nil
                }
            } catch {
                await MainActor.run {
                    deleteErrorMessage = "Failed to delete session. Please try again or check your connection."
                    showingDeleteError = true
                }
                print("⚠️ Failed to delete session: \(error)")
            }
        }
    }

    private func refreshSessions() {
        sessionRepository.refreshSessions()

        Task {
            await sessionRepository.checkSessionManagerConnectionStatus()
        }
    }

    private func clearAllSessions() {
        Task {
            print("Session cleanup placeholder - not yet implemented")
        }
    }

    // convertToSessionResponse no longer needed - using SessionManagerResponse directly
}

// MARK: - Session Row
struct SessionRow: View {
    let session: SessionManagerResponse
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .frame(width: 8, height: 8)
                .foregroundColor(statusColor)

            // Session content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(session.sessionName ?? "Untitled")
                        .font(.body)
                        .fontWeight(isSelected ? .semibold : .medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Spacer()

                    Text(formatRelativeTime(session.lastActiveAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("\(session.messageCount) messages")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Spacer()

                    if isSelected {
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                }

                if let lastMessage = session.conversationHistory?.last {
                    Text(lastMessage.content)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
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

    NavigationSplitView {
        SessionSidebarView(selectedSessionId: $selectedSessionId)
            .previewEnvironment()
    } detail: {
        Text("Select a session")
            .font(.title2)
            .foregroundColor(.secondary)
    }
}
