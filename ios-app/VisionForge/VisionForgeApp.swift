//
//  VisionForgeApp.swift
//  VisionForge
//
//  Created by Brian Pistone on 9/15/25.
//

import SwiftUI
import SwiftData

@main
struct VisionForgeApp: App {
    @StateObject private var persistenceManager: PersistenceManager
    @StateObject private var networkManager: NetworkManager

    init() {
        // Initialize persistence manager
        do {
            let manager = try PersistenceManager()
            _persistenceManager = StateObject(wrappedValue: manager)
        } catch {
            fatalError("Failed to initialize persistence: \(error)")
        }

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
                .environmentObject(persistenceManager)
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

            // Restore active sessions from SwiftData
            let recentSessions = persistenceManager.getRecentSessions(limit: 5)

            // Connect to backend if configuration exists
            if networkManager.activeConfig.baseURL != nil {
                do {
                    try await networkManager.claudeService.connect()
                    print("✅ Restored connection to backend")

                    // Restore the most recent active session if available
                    if let mostRecentSession = recentSessions.first(where: { $0.status == "active" }) {
                        print("✅ Restored session: \(mostRecentSession.name)")
                    }
                } catch {
                    print("⚠️ Failed to restore connection: \(error)")
                }
            }

            // Clean up old sessions (older than 30 days)
            persistenceManager.cleanupOldSessions(daysToKeep: 30)
        }
    }
}
