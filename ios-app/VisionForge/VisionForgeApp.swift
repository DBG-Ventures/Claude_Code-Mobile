//
//  VisionForgeApp.swift
//  VisionForge
//
//  Created by Brian Pistone on 9/15/25.
//

import SwiftUI

@main
struct VisionForgeApp: App {
    @StateObject private var networkManager: NetworkManager

    init() {

        // Initialize network manager with saved configuration if available
        if let savedConfig = BackendConfig.loadFromKeychain() {
            _networkManager = StateObject(wrappedValue: NetworkManager(config: savedConfig))
        } else {
            _networkManager = StateObject(wrappedValue: NetworkManager())
        }

        // Migrate any old credentials from UserDefaults
        KeychainManager.shared.migrateFromUserDefaults()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(networkManager)
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

            // NOTE: Session restoration moved to SessionPersistenceService (CoreData)
            // SessionManager handles session persistence

            // Connect to backend if configuration exists
            if networkManager.activeConfig.baseURL != nil {
                do {
                    try await networkManager.claudeService.connect()
                    print("✅ Restored connection to backend")

                    // NOTE: Session restoration moved to SessionManager
                    print("✅ Session restoration delegated to SessionManager")
                } catch {
                    print("⚠️ Failed to restore connection: \(error)")
                }
            }

            // NOTE: Session cleanup moved to SessionPersistenceService (CoreData)
            // Cleanup handled by SessionManager
        }
    }
}
