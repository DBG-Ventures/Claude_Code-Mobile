//
//  BackendConfigBuilder.swift
//  Configuration builder for backend setup parameters.
//
//  Handles backend configuration construction and validation logic
//  extracted from BackendSetupFlow for better separation of concerns.
//

import Foundation

// MARK: - Configuration Builder

class BackendConfigBuilder {
    var name: String = "Local Development"
    var host: String = "localhost"
    var port: Int = 8000
    var scheme: String = "http"
    var timeout: Double = 30.0

    var isLocalDevelopment: Bool {
        return host.lowercased().contains("localhost") || host == "127.0.0.1"
    }

    func applyLocalDevelopment() {
        name = "Local Development"
        host = "localhost"
        port = 8000
        scheme = "http"
        timeout = 30.0
    }

    func clearToCustom() {
        name = "Custom Server"
        // Don't clear host if it's already set to something other than localhost
        if host == "localhost" || host == "127.0.0.1" {
            host = ""
        }
        port = 8000
        scheme = "http"
        timeout = 30.0
    }

    func loadFrom(_ config: BackendConfig) {
        self.name = config.name
        self.host = config.host
        self.port = config.port
        self.scheme = config.scheme
        self.timeout = config.timeout
    }

    func build() -> BackendConfig {
        return BackendConfig(
            name: name.isEmpty ? (isLocalDevelopment ? "Local Development" : "Custom Server") : name,
            host: host,
            port: port,
            scheme: scheme,
            timeout: timeout
        )
    }
}