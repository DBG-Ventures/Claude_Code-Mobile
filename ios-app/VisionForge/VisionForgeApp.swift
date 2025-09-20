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
        let networkManager: NetworkManager
        if let savedConfig = BackendConfig.loadFromKeychain() {
            networkManager = NetworkManager(config: savedConfig)
        } else {
            networkManager = NetworkManager()
        }
        _networkManager = State(initialValue: networkManager)

        // Initialize session persistence service
        let persistenceService = SessionPersistenceService()

        // Use NetworkManager's properly configured Claude service
        let claudeService = networkManager.claudeService

        // Initialize modular session repository with the NetworkManager's Claude service
        let cacheManager = SessionCacheManager()
        let syncService = SessionSyncService(
            dataSource: claudeService.sessionAPIClient,
            userId: "mobile-user"
        )
        let lifecycleManager = SessionLifecycleManager(
            persistenceService: persistenceService,
            syncService: syncService
        )

        _sessionRepository = State(initialValue: SessionRepository(
            claudeService: claudeService,
            persistenceService: persistenceService,
            cacheManager: cacheManager,
            syncService: syncService,
            lifecycleManager: lifecycleManager
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
                print("🔧 Loading saved backend configuration: \(savedConfig.host):\(savedConfig.port)")
                await networkManager.updateConfiguration(savedConfig)

                // CRITICAL: Update SessionRepository with the new ClaudeService
                await sessionRepository.updateClaudeService(networkManager.claudeService)
                print("✅ SessionRepository updated with configured ClaudeService")

                // Check SessionManager connection and load sessions
                await sessionRepository.checkSessionManagerConnectionStatus()
            } else {
                print("⚠️ No saved backend configuration found")
            }
        }
    }
}
