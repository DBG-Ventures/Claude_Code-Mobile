//
//  ContentView.swift
//  Main app interface for Claude Code mobile client.
//
//  Root view managing navigation with NavigationSplitView for iPad optimization,
//  backend setup flow detection, and service coordination.
//

import SwiftUI

struct ContentView: View {

    // MARK: - State Properties

    @EnvironmentObject var networkManager: NetworkManager
    @StateObject private var sessionListViewModel = SessionListViewModel()
    @StateObject private var sessionStateManager: SessionStateManager
    @StateObject private var sessionPersistenceService = SessionPersistenceService()
    @State private var needsBackendSetup = false
    @State private var selectedSessionId: String?
    @State private var isInitializing = true
    @State private var restoredSessions: [PersistedSession] = []
    @State private var isCreatingSession = false
    @State private var showingNewSessionSheet = false

    // MARK: - Initialization

    init() {
        // Initialize persistence service first
        let persistenceService = SessionPersistenceService()
        _sessionPersistenceService = StateObject(wrappedValue: persistenceService)

        // Create SessionStateManager with placeholder - will be updated via environment
        _sessionStateManager = StateObject(wrappedValue: SessionStateManager(
            claudeService: ClaudeService(baseURL: URL(string: "http://placeholder")!),
            persistenceService: persistenceService
        ))
    }

    // MARK: - Body

    var body: some View {
        Group {
            if isInitializing {
                initializationView
            } else if needsBackendSetup {
                backendSetupView
            } else {
                mainInterface
            }
        }
        .environmentObject(sessionStateManager)  // Inject SessionStateManager following PRP pattern
        .environmentObject(sessionPersistenceService)
        .onAppear {
            initializeApp()
        }
        .task {
            // Check SessionManager connection status and load sessions
            await sessionStateManager.checkSessionManagerConnectionStatus()

            // Small delay to ensure UI is ready
            try? await Task.sleep(for: .milliseconds(50))

            // Select most recent active session if available
            await MainActor.run {
                if let recentSession = sessionStateManager.activeSessions.first(where: { $0.status == .active }) {
                    selectedSessionId = recentSession.sessionId
                } else if let firstSession = sessionStateManager.activeSessions.first {
                    // If no active session, select the first one
                    selectedSessionId = firstSession.sessionId
                }
            }
        }
    }

    // MARK: - Initialization View

    private var initializationView: some View {
        VStack(spacing: 16) {
            Image(systemName: "laptopcomputer.and.iphone")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("Claude Code")
                .font(.title)
                .fontWeight(.bold)

            ProgressView()
                .scaleEffect(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Backend Setup View

    private var backendSetupView: some View {
        BackendSetupFlow()
            .environmentObject(networkManager)
            .onReceive(NotificationCenter.default.publisher(for: .setupCompleted)) { _ in
                checkBackendConfiguration()
            }
    }

    // MARK: - Main Interface

    private var mainInterface: some View {
        NavigationSplitView {
            // Sidebar: Session management and navigation with SessionManager integration
            SessionSidebarView(selectedSessionId: $selectedSessionId)
                .environmentObject(networkManager)
                .environmentObject(sessionListViewModel)
                .environmentObject(sessionStateManager)  // NEW: SessionManager integration
                .navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 450)
        } detail: {
            // Detail: Current conversation with SessionManager session context
            if let sessionId = selectedSessionId {
                ConversationView(sessionId: sessionId)
                    .environmentObject(networkManager)
                    .environmentObject(sessionListViewModel)
                    .environmentObject(sessionStateManager)  // NEW: SessionManager integration
                    .id(sessionId)  // Force view refresh when session changes
            } else {
                conversationEmptyState
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            setupNetworkConnection()
            setupSessionManagement()
        }
        .sheet(isPresented: $showingNewSessionSheet) {
            NewSessionSheet()
                .environmentObject(networkManager)
                .environmentObject(sessionListViewModel)
                .environmentObject(sessionStateManager)
                .onDisappear {
                    // Select the newly created session if one was created
                    if let newSessionId = sessionStateManager.currentSessionId {
                        selectedSessionId = newSessionId
                    }
                }
        }
    }

    // MARK: - Empty State

    private var conversationEmptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "message.badge")
                .font(.system(size: 80))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text("No Session Selected")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Select a session from the sidebar or create a new one to start chatting with Claude.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button(action: createNewSession) {
                if isCreatingSession {
                    HStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                        Text("Creating...")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Label("New Session", systemImage: "plus")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .disabled(isCreatingSession)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Setup Methods

    private func initializeApp() {
        // Simulate brief initialization delay for smooth UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            checkBackendConfiguration()
            isInitializing = false
        }
    }

    private func checkBackendConfiguration() {
        // Check Keychain for stored backend configuration
        if let savedConfig = BackendConfig.loadFromKeychain() {
            needsBackendSetup = false
            Task {
                await networkManager.updateConfiguration(savedConfig)
                // Update SessionStateManager with the proper ClaudeService from NetworkManager
                await sessionStateManager.updateClaudeService(networkManager.claudeService)
                // Check SessionManager connection status after updating the service - this loads sessions
                await sessionStateManager.checkSessionManagerConnectionStatus()
                // No need to call restoreSessionsFromPersistence as checkSessionManagerConnectionStatus already loads sessions
            }
        } else {
            needsBackendSetup = BackendSetupFlow.isSetupRequired()
            if !needsBackendSetup {
                loadSavedConfiguration()
            }
        }
    }

    private func loadSavedConfiguration() {
        if let savedConfig = BackendSetupFlow.getSavedConfiguration() {
            Task {
                await networkManager.updateConfiguration(savedConfig)
                // Update SessionStateManager with the proper ClaudeService from NetworkManager
                await sessionStateManager.updateClaudeService(networkManager.claudeService)
                // Check SessionManager connection status after updating the service - this loads sessions
                await sessionStateManager.checkSessionManagerConnectionStatus()
                // Save to Keychain for future use
                try? savedConfig.saveToKeychain()
                // No need to call restoreSessionsFromPersistence as checkSessionManagerConnectionStatus already loads sessions
            }
        }
    }


    private func setupNetworkConnection() {
        guard !needsBackendSetup else { return }

        Task {
            do {
                try await networkManager.claudeService.connect()
                print("✅ Connected to Claude service")
            } catch {
                print("⚠️ Failed to connect to Claude service: \(error)")
                // Don't force setup flow here - connection might be temporary
            }
        }
    }

    private func setupSessionManagement() {
        // Initialize SessionStateManager integration with legacy SessionListViewModel
        sessionListViewModel.setClaudeService(networkManager.claudeService)

        // Setup session state monitoring for UI updates
        // SessionStateManager will be monitored through @Published properties automatically
        print("✅ SessionManager integration initialized")
    }

    private func createNewSession() {
        print("🔍 ContentView: createNewSession button pressed")
        showingNewSessionSheet = true
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let setupCompleted = Notification.Name("setupCompleted")
}


#Preview {
    ContentView()
}
