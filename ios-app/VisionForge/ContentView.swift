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

    @Environment(NetworkManager.self) var networkManager
    @Environment(SessionRepository.self) var sessionRepository
    @Environment(KeychainManager.self) var keychainManager
    @State private var needsBackendSetup = false
    @State private var selectedSessionId: String?
    @State private var isInitializing = true
    @State private var restoredSessions: [PersistedSession] = []
    @State private var isCreatingSession = false
    @State private var showingNewSessionSheet = false


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
        .task {
            // Check SessionManager connection status and load sessions
            await sessionRepository.checkSessionManagerConnectionStatus()

            // Small delay to ensure UI is ready
            try? await Task.sleep(for: .milliseconds(50))

            // Select most recent active session if available
            await MainActor.run {
                if let recentSession = sessionRepository.activeSessions.first(where: { $0.status == .active }) {
                    selectedSessionId = recentSession.sessionId
                } else if let firstSession = sessionRepository.activeSessions.first {
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
            .onReceive(NotificationCenter.default.publisher(for: .setupCompleted)) { _ in
                checkBackendConfiguration()
            }
    }

    // MARK: - Main Interface

    private var mainInterface: some View {
        NavigationSplitView {
            // Sidebar: Session management and navigation with SessionManager integration
            SessionSidebarView(selectedSessionId: $selectedSessionId)
                .navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 450)
        } detail: {
            // Detail: Current conversation with SessionManager session context
            Group {
                if let sessionId = selectedSessionId {
                    ConversationView(sessionId: sessionId)
                        .id(sessionId)  // Force view refresh when session changes
                } else {
                    conversationEmptyState
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            setupNetworkConnection()
            setupSessionManagement()
        }
        .sheet(isPresented: $showingNewSessionSheet) {
            NewSessionSheet()
                .onDisappear {
                    // Select the newly created session if one was created
                    if let newSessionId = sessionRepository.currentSessionId {
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
        if let savedConfig = BackendConfig.loadFromKeychain(using: keychainManager) {
            needsBackendSetup = false
            Task {
                await networkManager.updateConfiguration(savedConfig)
                // Update SessionRepository with the proper ClaudeService from NetworkManager
                await sessionRepository.updateClaudeService(networkManager.claudeService)
                // Check SessionManager connection status after updating the service - this loads sessions
                await sessionRepository.checkSessionManagerConnectionStatus()
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
                // Update SessionRepository with the proper ClaudeService from NetworkManager
                await sessionRepository.updateClaudeService(networkManager.claudeService)
                // Check SessionManager connection status after updating the service - this loads sessions
                await sessionRepository.checkSessionManagerConnectionStatus()
                // Save to Keychain for future use
                try? savedConfig.saveToKeychain(using: keychainManager)
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
        // SessionRepository handles all session management now
        // It will be monitored through @Observable properties automatically
        print("✅ SessionRepository integration initialized")
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
