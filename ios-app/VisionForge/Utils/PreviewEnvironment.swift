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
        let claudeService = ClaudeService(baseURL: URL(string: "http://localhost:8000")!)
        let persistenceService = SessionPersistenceService()
        return SessionRepository(
            claudeService: claudeService,
            persistenceService: persistenceService,
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