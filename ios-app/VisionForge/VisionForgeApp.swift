//
//  VisionForgeApp.swift
//  VisionForge
//
//  Created by Brian Pistone on 9/15/25.
//

import SwiftUI

@main
struct VisionForgeApp: App {
    @State private var networkManager: NetworkManager
    @State private var sessionRepository: SessionRepository

    init() {
        // Initialize network manager with saved configuration if available
        if let savedConfig = BackendConfig.loadFromKeychain() {
            _networkManager = State(initialValue: NetworkManager(config: savedConfig))
        } else {
            _networkManager = State(initialValue: NetworkManager())
        }

        // Initialize session persistence service (internal to repository)
        let persistenceService = SessionPersistenceService()

        // Initialize Claude service
        let claudeService = ClaudeService(baseURL: URL(string: "http://placeholder")!)

        // Initialize repository for unified session management
        _sessionRepository = State(initialValue: SessionRepository(
            claudeService: claudeService,
            persistenceService: persistenceService
        ))

        // Migrate any old credentials from UserDefaults
        KeychainManager.shared.migrateFromUserDefaults()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(networkManager)
                .environment(sessionRepository)
                .onAppear {
                    restoreSessionsOnLaunch()
                }
        }
    }

    private func restoreSessionsOnLaunch() {
        Task { @MainActor in
            // Load saved configuration from Keychain
            if let savedConfig = BackendConfig.loadFromKeychain() {
                await networkManager.updateConfiguration(savedConfig)
            }

            // Connect to backend if configuration exists
            if networkManager.activeConfig.baseURL != nil {
                do {
                    try await networkManager.claudeService.connect()
                    print("✅ Restored connection to backend")

                    // NOTE: Session restoration handled by SessionRepository
                    print("✅ Session restoration delegated to SessionRepository")
                } catch {
                    print("⚠️ Failed to restore connection: \(error)")
                }
            }
        }
    }
}
