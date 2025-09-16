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
    @EnvironmentObject var persistenceManager: PersistenceManager
    @StateObject private var sessionListViewModel = SessionListViewModel()
    @State private var needsBackendSetup = false
    @State private var selectedSessionId: String?
    @State private var isInitializing = true
    @State private var restoredSessions: [PersistedSession] = []

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
        .onAppear {
            initializeApp()
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
            // Sidebar: Session management and navigation
            SessionSidebarView(selectedSessionId: $selectedSessionId)
                .environmentObject(networkManager)
                .environmentObject(sessionListViewModel)
                .navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 450)
        } detail: {
            // Detail: Current conversation or empty state
            if let sessionId = selectedSessionId {
                ConversationView(sessionId: sessionId)
                    .environmentObject(networkManager)
                    .environmentObject(sessionListViewModel)
                    .id(sessionId)  // Force view refresh when session changes
            } else {
                conversationEmptyState
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            setupNetworkConnection()
            sessionListViewModel.setClaudeService(networkManager.claudeService)
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
                Label("New Session", systemImage: "plus")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
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
                await restoreSessionsFromPersistence()
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
                // Save to Keychain for future use
                try? savedConfig.saveToKeychain()
                await restoreSessionsFromPersistence()
            }
        }
    }

    private func restoreSessionsFromPersistence() async {
        // Load recent sessions from SwiftData
        let recentSessions = persistenceManager.getRecentSessions(limit: 10)
        await MainActor.run {
            self.restoredSessions = recentSessions
        }

        // Select the most recent active session
        if let mostRecent = recentSessions.first(where: { $0.status == "active" }) {
            await MainActor.run {
                self.selectedSessionId = mostRecent.id
            }
        }

        print("✅ Restored \(recentSessions.count) sessions from persistence")
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

    private func createNewSession() {
        // This would trigger session creation
        // Implementation depends on session management approach
        print("Creating new session...")
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let setupCompleted = Notification.Name("setupCompleted")
}


#Preview {
    ContentView()
}
