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
    @State private var showingDeleteError: Bool = false
    @State private var deleteErrorMessage: String = ""

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
        .onReceive(sessionStateManager.$activeSessions) { _ in
            // Force UI update when SessionManager sessions change
            // The filteredSessions computed property will automatically recalculate
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
                    Task {
                        do {
                            try await sessionStateManager.deleteSession(session.sessionId)
                            sessionToDelete = nil
                            // If deleted session was selected, clear selection
                            if selectedSessionId == session.sessionId {
                                selectedSessionId = nil
                            }
                        } catch {
                            // Show error to user instead of just printing
                            await MainActor.run {
                                deleteErrorMessage = "Failed to delete session. Please try again or check your connection."
                                showingDeleteError = true
                            }
                            print("⚠️ Failed to delete session: \(error)")
                        }
                    }
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
                    .environmentObject(sessionStateManager)
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
        // All sessions come from SessionManager backend now
        // Convert SessionManager sessions to SessionResponse format for display
        let sessionManagerSessions = sessionStateManager.activeSessions.map { sessionManagerSession in
            convertToSessionResponse(sessionManagerSession)
        }

        // Sort by most recent activity
        return sessionManagerSessions.sorted { $0.updatedAt > $1.updatedAt }
    }

    // MARK: - Setup Methods

    private func setupViewModel() {
        // Setup legacy SessionListViewModel
        sessionViewModel.setClaudeService(networkManager.claudeService)

        // Setup SessionStateManager integration
        setupSessionManagerIntegration()

        // Only load legacy sessions - SessionStateManager sessions are loaded by ContentView
        sessionViewModel.loadSessions()
    }

    private func setupSessionManagerIntegration() {
        // Initialize SessionStateManager integration
        // SessionStateManager should already be configured via environment injection

        print("✅ SessionSidebarView SessionManager integration initialized")
    }

    private func loadAllSessions() {
        // Load from legacy source
        sessionViewModel.loadSessions()

        // SessionStateManager sessions are already loaded by ContentView
        // No need to reload them here
    }

    private func refreshSessions() {
        // Refresh both legacy and SessionManager sessions
        sessionViewModel.loadSessions()

        Task {
            // Check connection and reload sessions from SessionManager
            await sessionStateManager.checkSessionManagerConnectionStatus()
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
    @EnvironmentObject var sessionStateManager: SessionStateManager

    // MARK: - Liquid Glass Enhancement State

    @State private var liquidScale: CGFloat = 1.0
    @State private var liquidGlow: Double = 0.0
    @State private var isPressed: Bool = false
    @State private var selectionProgress: Double = 0.0
    @State private var flowingHighlight: Bool = false

    // MARK: - System Integration

    @EnvironmentObject private var accessibilityManager: AccessibilityManager
    @EnvironmentObject private var performanceMonitor: LiquidPerformanceMonitor

    // MARK: - Environment

    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        HStack(spacing: 12) {
            // Liquid Enhanced Status Indicator
            liquidStatusIndicator

            // Liquid Enhanced Session Content
            liquidSessionContent

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(liquidRowBackground)
        .overlay(liquidRowOverlay)
        .scaleEffect(liquidScale)
        .shadow(
            color: liquidSelectionColor.opacity(liquidGlow * 0.4),
            radius: 15 * liquidGlow,
            x: 0,
            y: 8 * liquidGlow
        )
        .contentShape(Rectangle())
        .liquidRippleOverlay(
            accessibilityManager: accessibilityManager,
            performanceMonitor: performanceMonitor,
            maxRipples: 1
        )
        .onTapGesture { location in
            performLiquidSelection(at: location)
        }
        .onPressureTouch { location, pressure in
            handlePressureSelection(at: location, pressure: pressure)
        }
        .onAppear {
            setupLiquidRow()
        }
        .onChange(of: isSelected) { _, newValue in
            animateSelectionState(newValue)
        }
        .onChange(of: reduceTransparency) { _, newValue in
            updateAccessibilitySettings()
        }
        .onChange(of: reduceMotion) { _, newValue in
            updateAccessibilitySettings()
        }
    }

    // MARK: - Liquid Enhanced Components

    private var liquidStatusIndicator: some View {
        VStack(spacing: 2) {
            Circle()
                .fill(liquidStatusColor)
                .frame(width: 8, height: 8)
                .scaleEffect(isPressed ? 1.2 : 1.0)
                .liquidAnimation(.bubble, value: isPressed, accessibilityManager: accessibilityManager)

            // Enhanced SessionManager indicator with liquid effect
            if isSessionManagerSession {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 6))
                    .foregroundColor(.orange)
                    .opacity(flowingHighlight ? 1.0 : 0.7)
                    .liquidAnimation(.flow, value: flowingHighlight, accessibilityManager: accessibilityManager)
            }
        }
    }

    private var liquidSessionContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Session Header with Liquid Enhancement
            HStack {
                Text(session.sessionName ?? "Untitled")
                    .font(.body)
                    .fontWeight(isSelected ? .semibold : .medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                // Enhanced instant switching indicator
                if isSessionManagerSession {
                    Image(systemName: "speedometer")
                        .font(.caption2)
                        .foregroundColor(.green)
                        .opacity(flowingHighlight ? 1.0 : 0.8)
                        .liquidAnimation(.response, value: flowingHighlight, accessibilityManager: accessibilityManager)
                }

                Spacer()

                Text(formatRelativeTime(session.updatedAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Session Metadata with Liquid Enhancement
            HStack {
                Text("\(session.messageCount)")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text("messages")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                // Enhanced SessionManager session type indicator
                if isSessionManagerSession {
                    Text("• Persistent")
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .opacity(flowingHighlight ? 1.0 : 0.7)
                }

                Spacer()

                // Liquid Enhanced Delete Button
                if isSelected {
                    liquidDeleteButton
                }
            }

            // Enhanced Last Message Preview
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
                            .opacity(flowingHighlight ? 1.0 : 0.8)
                    }
                }
            }
        }
    }

    private var liquidDeleteButton: some View {
        Button(action: { onDelete(session) }) {
            Image(systemName: "trash")
                .font(.caption)
                .foregroundColor(.red)
                .scaleEffect(isPressed ? 0.9 : 1.0)
                .liquidAnimation(.feedback, value: isPressed, accessibilityManager: accessibilityManager)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var liquidRowBackground: some View {
        Group {
            if accessibilityManager.shouldUseSolidBackgrounds {
                // Accessibility: Solid background
                RoundedRectangle(cornerRadius: 8)
                    .fill(solidRowBackgroundColor)
                    .opacity(accessibilityManager.getAccessibilityOpacity(baseOpacity: 0.9))
            } else if performanceMonitor.liquidEffectsEnabled {
                // Liquid Glass Background
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.clear)
                        .background(.ultraThinMaterial)
                        .glassEffect(accessibilityManager.getGlassEffect())

                    // Flowing selection highlight
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        liquidSelectionColor.opacity(selectionProgress * 0.3),
                                        liquidSelectionColor.opacity(selectionProgress * 0.1),
                                        Color.clear
                                    ],
                                    startPoint: flowingHighlight ? .topLeading : .bottomLeading,
                                    endPoint: flowingHighlight ? .bottomTrailing : .topTrailing
                                )
                            )
                            .liquidAnimation(.flow, value: flowingHighlight, accessibilityManager: accessibilityManager)
                    }

                    // Pressure response overlay
                    if isPressed {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(liquidSelectionColor.opacity(0.1))
                            .liquidAnimation(.feedback, value: isPressed, accessibilityManager: accessibilityManager)
                    }
                }
            } else {
                // Fallback background
                RoundedRectangle(cornerRadius: 8)
                    .fill(solidRowBackgroundColor)
            }
        }
    }

    private var liquidRowOverlay: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(liquidBorderColor, lineWidth: liquidBorderWidth)
            .liquidAnimation(.transition, value: isSelected, accessibilityManager: accessibilityManager)
    }

    // MARK: - Liquid Interaction Methods

    private func setupLiquidRow() {
        // Initialize accessibility manager
        updateAccessibilitySettings()

        // Start performance monitoring
        performanceMonitor.startMonitoring()

        // Set initial selection state
        selectionProgress = isSelected ? 1.0 : 0.0

        // Start flowing animation for selected state
        if isSelected {
            startFlowingAnimation()
        }
    }

    private func performLiquidSelection(at location: CGPoint) {
        guard accessibilityManager.shouldEnableFeature(.interactiveEffects),
              performanceMonitor.liquidEffectsEnabled else {
            // Fallback selection for accessibility
            onSelect(session)
            return
        }

        isPressed = true

        // Trigger liquid ripple
        LiquidRippleEffect.triggerRipple(at: location, pressure: 1.0)

        // Liquid selection animation
        if let animation = Animation.liquid(.response, accessibilityManager: accessibilityManager) {
            withAnimation(animation) {
                liquidScale = 0.98
                liquidGlow = 0.8
            }

            withAnimation(animation.delay(0.1)) {
                liquidScale = 1.0
                liquidGlow = 0.0
                isPressed = false
            }
        }

        // Perform selection
        onSelect(session)

        // Record interaction metrics
        let metrics = LiquidInteractionMetrics(
            touchLocation: location,
            pressure: 1.0,
            elementType: .sessionRow,
            deviceCapabilities: DeviceCapabilities.current
        )
        performanceMonitor.recordInteraction(metrics)
    }

    private func handlePressureSelection(at location: CGPoint, pressure: Float) {
        guard accessibilityManager.shouldEnableFeature(.interactiveEffects),
              performanceMonitor.liquidEffectsEnabled else {
            return
        }

        // Enhanced pressure feedback
        if pressure > 1.3 {
            LiquidRippleEffect.triggerRipple(at: location, pressure: pressure)

            if let animation = Animation.liquid(.feedback, accessibilityManager: accessibilityManager) {
                withAnimation(animation) {
                    liquidScale = 0.95 + CGFloat(pressure - 1.0) * 0.05
                    liquidGlow = Double(pressure - 1.0) * 0.3
                }
            }
        }

        // Record pressure interaction
        let metrics = LiquidInteractionMetrics(
            touchLocation: location,
            pressure: pressure,
            elementType: .sessionRow,
            deviceCapabilities: DeviceCapabilities.current
        )
        performanceMonitor.recordInteraction(metrics)
    }

    private func animateSelectionState(_ selected: Bool) {
        guard accessibilityManager.shouldEnableFeature(.interactiveEffects) else {
            selectionProgress = selected ? 1.0 : 0.0
            return
        }

        let targetProgress = selected ? 1.0 : 0.0

        if let animation = Animation.liquid(.transition, accessibilityManager: accessibilityManager) {
            withAnimation(animation) {
                selectionProgress = targetProgress
                liquidGlow = selected ? 0.6 : 0.0
            }
        }

        if selected {
            startFlowingAnimation()
        } else {
            stopFlowingAnimation()
        }
    }

    private func startFlowingAnimation() {
        guard accessibilityManager.shouldEnableFeature(.spatialEffects) else { return }

        flowingHighlight = true

        if let animation = Animation.liquid(.flow, accessibilityManager: accessibilityManager) {
            withAnimation(animation.repeatForever(autoreverses: true)) {
                flowingHighlight.toggle()
            }
        }
    }

    private func stopFlowingAnimation() {
        flowingHighlight = false
    }

    private func updateAccessibilitySettings() {
        accessibilityManager.updateFromEnvironment(
            reduceTransparency: reduceTransparency,
            reduceMotion: reduceMotion,
            dynamicTypeSize: .large
        )
    }

    // MARK: - Liquid Computed Properties

    private var liquidStatusColor: Color {
        let baseColor = statusColor

        if isSelected && accessibilityManager.shouldEnableFeature(.interactiveEffects) {
            return baseColor.opacity(0.9 + selectionProgress * 0.1)
        } else {
            return baseColor
        }
    }

    private var liquidSelectionColor: Color {
        if isSessionManagerSession {
            return .orange
        } else {
            return .blue
        }
    }

    private var liquidBorderColor: Color {
        if isSelected {
            let baseColor = liquidSelectionColor
            return baseColor.opacity(0.4 + selectionProgress * 0.2)
        } else {
            return Color.clear
        }
    }

    private var liquidBorderWidth: CGFloat {
        if isSelected {
            return 1.0 + selectionProgress * 0.5
        } else {
            return 0.0
        }
    }

    private var solidRowBackgroundColor: Color {
        if isSelected {
            return liquidSelectionColor.opacity(0.15)
        } else {
            return Color.clear
        }
    }

    // MARK: - Legacy Computed Properties

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
        // All sessions are from SessionManager backend now
        return true
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