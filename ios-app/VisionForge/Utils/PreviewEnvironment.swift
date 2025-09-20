//
//  PreviewEnvironment.swift
//  Shared preview environment configuration for SwiftUI previews.
//
//  Provides consistent environment setup for all preview providers,
//  eliminating duplication and simplifying preview configuration.
//

import SwiftUI

/// Shared preview environment configuration
struct PreviewEnvironment {
    static let networkManager: NetworkManager = {
        let config = BackendConfig(
            name: "Preview",
            host: "localhost",
            port: 8000,
            scheme: "http"
        )
        return NetworkManager(config: config)
    }()

    static let sessionRepository: SessionRepository = {
        let baseURL = URL(string: "http://localhost:8000")!
        let networkClient = ClaudeNetworkClient(baseURL: baseURL)
        let sessionDataSource = SessionAPIClient(networkClient: networkClient)
        let streamingService = ClaudeStreamingService(networkClient: networkClient)
        let queryService = ClaudeQueryService(
            networkClient: networkClient,
            streamingService: streamingService
        )

        let claudeService = ClaudeService(
            networkClient: networkClient,
            sessionDataSource: sessionDataSource,
            streamingService: streamingService,
            queryService: queryService
        )

        let persistenceService = SessionPersistenceService()
        let cacheManager = SessionCacheManager()
        let syncService = SessionSyncService(
            dataSource: sessionDataSource,
            userId: "preview-user"
        )
        let lifecycleManager = SessionLifecycleManager(
            persistenceService: persistenceService,
            syncService: syncService
        )

        return SessionRepository(
            claudeService: claudeService,
            persistenceService: persistenceService,
            cacheManager: cacheManager,
            syncService: syncService,
            lifecycleManager: lifecycleManager,
            userId: "preview-user"
        )
    }()
}

/// View modifier for applying preview environment
struct PreviewEnvironmentModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .environment(PreviewEnvironment.networkManager)
            .environment(PreviewEnvironment.sessionRepository)
    }
}

extension View {
    /// Apply standard preview environment configuration
    func previewEnvironment() -> some View {
        modifier(PreviewEnvironmentModifier())
    }
}