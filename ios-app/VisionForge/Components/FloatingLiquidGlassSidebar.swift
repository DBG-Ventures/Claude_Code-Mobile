//
//  FloatingLiquidGlassSidebar.swift
//  VisionForge
//
//  Floating liquid glass sidebar that overlays on top of content following iOS 26 design principles.
//  This creates a distinct functional layer above the content layer as specified in Apple's Liquid Glass guidelines.
//

import SwiftUI
import Combine

struct FloatingLiquidGlassSidebar: View {
    // MARK: - Environment Objects
    @Environment(NetworkManager.self) var networkManager
    @Environment(SessionListViewModel.self) var sessionViewModel
    @Environment(SessionStateManager.self) var sessionStateManager

    // MARK: - Binding Properties
    @Binding var selectedSessionId: String?

    // MARK: - State Properties
    @State private var isSidebarVisible: Bool = true
    @State private var dragOffset: CGFloat = 0
    @State private var searchText: String = ""
    @State private var showingNewSessionSheet: Bool = false
    @State private var showingSettings: Bool = false
    @State private var showingDeleteAlert: Bool = false
    @State private var sessionToDelete: SessionResponse?
    @State private var showingDeleteError: Bool = false
    @State private var deleteErrorMessage: String = ""

    // MARK: - Constants
    private let sidebarWidth: CGFloat = 360
    private let edgePadding: CGFloat = 16
    private let topPadding: CGFloat = 60

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Invisible drag area to show sidebar from edge
                if !isSidebarVisible {
                    HStack {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: 20)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        if value.translation.width > 50 {
                                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                                isSidebarVisible = true
                                            }
                                        }
                                    }
                            )
                        Spacer()
                    }
                }

                // Floating sidebar with glass effect
                if isSidebarVisible {
                    HStack(spacing: 0) {
                        // Glass sidebar container
                        VStack(spacing: 0) {
                            // Drag handle for hiding
                            HStack {
                                Spacer()
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.secondary.opacity(0.5))
                                    .frame(width: 36, height: 5)
                                    .padding(.vertical, 8)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        dragOffset = min(0, value.translation.width)
                                    }
                                    .onEnded { value in
                                        if value.translation.width < -100 {
                                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                                isSidebarVisible = false
                                            }
                                        }
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                            dragOffset = 0
                                        }
                                    }
                            )

                            // Header section
                            sidebarHeader

                            // Search bar
                            searchSection
                                .padding(.horizontal, edgePadding)
                                .padding(.bottom, 12)

                            Divider()
                                .background(Color.secondary.opacity(0.2))

                            // Sessions list
                            ScrollView {
                                LazyVStack(spacing: 8) {
                                    if sessionViewModel.isLoading {
                                        loadingView
                                    } else if filteredSessions.isEmpty {
                                        emptyStateView
                                    } else {
                                        ForEach(filteredSessions) { session in
                                            FloatingSessionRow(
                                                session: session,
                                                isSelected: selectedSessionId == session.sessionId,
                                                onSelect: { selectSession(session) },
                                                onDelete: { deleteSession(session) }
                                            )
                                            .padding(.horizontal, edgePadding)
                                        }
                                    }
                                }
                                .padding(.vertical, 12)
                            }

                            Divider()
                                .background(Color.secondary.opacity(0.2))

                            // Bottom toolbar
                            bottomToolbar
                        }
                        .frame(width: sidebarWidth)
                        .frame(maxHeight: .infinity)
                        .glassEffect(
                            .regular,
                            in: RoundedRectangle(cornerRadius: 20)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 20, x: 10, y: 0)
                        .offset(x: dragOffset)
                        .padding(.top, topPadding)
                        .padding(.bottom, 20)
                        .padding(.leading, edgePadding)

                        Spacer()
                    }
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }

                // Floating toggle button when sidebar is hidden
                if !isSidebarVisible {
                    VStack {
                        Button(action: {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                isSidebarVisible = true
                            }
                        }) {
                            Image(systemName: "sidebar.left")
                                .font(.title2)
                                .foregroundColor(.primary)
                                .frame(width: 44, height: 44)
                                .glassEffect(.regular, in: Circle())
                                .shadow(color: .black.opacity(0.15), radius: 10)
                        }
                        .padding(.top, topPadding + 20)
                        .padding(.leading, edgePadding)

                        Spacer()
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .onAppear {
            setupViewModel()
        }
        .sheet(isPresented: $showingNewSessionSheet) {
            NewSessionSheet()
                .environmentObject(networkManager)
                .environmentObject(sessionViewModel)
                .environmentObject(sessionStateManager)
        }
        .sheet(isPresented: $showingSettings) {
            EditableSettingsView()
                .environmentObject(networkManager)
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

    // MARK: - Header Section
    private var sidebarHeader: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sessions")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    HStack(spacing: 8) {
                        Circle()
                            .fill(networkManager.claudeService.isConnected ? Color.green : Color.red)
                            .frame(width: 8, height: 8)

                        Text("\(filteredSessions.count) active")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Button(action: { showingNewSessionSheet = true }) {
                    Image(systemName: "plus")
                        .font(.title3)
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.blue)
                        .clipShape(Circle())
                }
                .disabled(sessionViewModel.isLoading)
            }
        }
        .padding(.horizontal, edgePadding)
        .padding(.bottom, 8)
    }

    // MARK: - Search Section
    private var searchSection: some View {
        HStack(spacing: 12) {
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
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: searchText.isEmpty ? "message.badge" : "magnifyingglass")
                .font(.largeTitle)
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
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Bottom Toolbar
    private var bottomToolbar: some View {
        HStack(spacing: 12) {
            Button(action: { showingSettings = true }) {
                Label("Settings", systemImage: "gear")
                    .font(.body)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)

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
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, edgePadding)
        .padding(.vertical, 12)
    }

    // MARK: - Computed Properties
    private var filteredSessions: [SessionResponse] {
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

    // MARK: - Helper Methods
    private func combineSessionSources() -> [SessionResponse] {
        let sessionManagerSessions = sessionStateManager.activeSessions.map { sessionManagerSession in
            convertToSessionResponse(sessionManagerSession)
        }

        return sessionManagerSessions.sorted { $0.updatedAt > $1.updatedAt }
    }

    private func setupViewModel() {
        sessionViewModel.setClaudeService(networkManager.claudeService)
        sessionViewModel.loadSessions()
    }

    private func selectSession(_ session: SessionResponse) {
        selectedSessionId = session.sessionId
        sessionViewModel.selectSession(session)
    }

    private func deleteSession(_ session: SessionResponse) {
        sessionToDelete = session
        showingDeleteAlert = true
    }

    private func deleteSessionAction(_ session: SessionResponse) {
        Task {
            do {
                try await sessionStateManager.deleteSession(session.sessionId)
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
        sessionViewModel.loadSessions()

        Task {
            await sessionStateManager.checkSessionManagerConnectionStatus()
        }
    }

    private func clearAllSessions() {
        Task {
            print("Session cleanup placeholder - not yet implemented")
        }
    }

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
            context: [:]
        )
    }
}

// MARK: - Floating Session Row
struct FloatingSessionRow: View {
    let session: SessionResponse
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            // Session content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(session.sessionName ?? "Untitled")
                        .font(.body)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Spacer()

                    Text(formatRelativeTime(session.updatedAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                if let lastMessage = session.messages.last {
                    Text(lastMessage.content)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
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

#Preview {
    @Previewable @State var selectedSessionId: String? = nil

    ZStack {
        // Background content to show glass effect
        LinearGradient(
            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        FloatingLiquidGlassSidebar(selectedSessionId: $selectedSessionId)
            .environmentObject(NetworkManager())
            .environmentObject(SessionListViewModel())
            .environmentObject(SessionStateManager(
                claudeService: ClaudeService(baseURL: URL(string: "http://localhost:8000")!),
                persistenceService: SessionPersistenceService()
            ))
    }
}