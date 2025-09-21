//
//  ConfigurationValidator.swift
//  Real-time backend configuration validation service.
//
//  Provides comprehensive validation for backend configuration with real-time feedback,
//  health checking, and network validation for Claude Code mobile client setup.
//

import Foundation
import Network
import Combine
import Observation

// MARK: - Configuration Validator

@MainActor
@Observable
class ConfigurationValidator {

    // MARK: - Observable Properties

    var isValidating: Bool = false
    var validationResults: ValidationResults = ValidationResults()
    var lastHealthCheckResult: HealthCheckResult?

    // MARK: - Private Properties

    private nonisolated(unsafe) var cancellables = Set<AnyCancellable>()
    private let urlSession: URLSession
    private let networkMonitor: NWPathMonitor

    // MARK: - Initialization

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10.0
        config.timeoutIntervalForResource = 15.0
        self.urlSession = URLSession(configuration: config)
        self.networkMonitor = NWPathMonitor()

        setupNetworkMonitoring()
    }

    deinit {
        networkMonitor.cancel()
        cancellables.removeAll()
    }

    // MARK: - Network Monitoring

    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.validationResults.networkAvailable = path.status == .satisfied
            }
        }
        networkMonitor.start(queue: DispatchQueue.global(qos: .background))
    }

    // MARK: - Validation Methods

    func validateConfiguration(_ config: BackendConfig) {
        // Reset previous results
        validationResults = ValidationResults()

        // Validate individual fields
        validateHost(config.host)
        validatePort(config.port)
        validateScheme(config.scheme)
        validateBaseURL(config)

        // Update overall validity
        validationResults.isValid = validationResults.hostValidation.isValid &&
                                   validationResults.portValidation.isValid &&
                                   validationResults.schemeValidation.isValid &&
                                   validationResults.urlValidation.isValid
    }

    func validateHost(_ host: String) {
        var result = FieldValidation()

        guard !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            result.isValid = false
            result.errorMessage = "Host cannot be empty"
            validationResults.hostValidation = result
            return
        }

        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check for localhost variants
        let localhostPattern = #"^(localhost|127\.0\.0\.1|::1)$"#
        if let regex = try? NSRegularExpression(pattern: localhostPattern, options: .caseInsensitive) {
            let range = NSRange(location: 0, length: trimmedHost.count)
            if regex.firstMatch(in: trimmedHost, options: [], range: range) != nil {
                result.isValid = true
                result.warningMessage = "Using localhost - ensure backend is running locally"
                validationResults.hostValidation = result
                return
            }
        }

        // Check for valid IP address pattern
        let ipPattern = #"^(\d{1,3}\.){3}\d{1,3}$"#
        if let ipRegex = try? NSRegularExpression(pattern: ipPattern, options: []) {
            let range = NSRange(location: 0, length: trimmedHost.count)
            if ipRegex.firstMatch(in: trimmedHost, options: [], range: range) != nil {
                // Validate IP octets
                let octets = trimmedHost.split(separator: ".")
                let validOctets = octets.allSatisfy {
                    if let octet = Int($0), octet >= 0 && octet <= 255 {
                        return true
                    }
                    return false
                }

                if validOctets {
                    result.isValid = true
                    validationResults.hostValidation = result
                    return
                } else {
                    result.isValid = false
                    result.errorMessage = "Invalid IP address format"
                    validationResults.hostValidation = result
                    return
                }
            }
        }

        // Check for valid domain name pattern
        let domainPattern = #"^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$"#
        if let domainRegex = try? NSRegularExpression(pattern: domainPattern, options: []) {
            let range = NSRange(location: 0, length: trimmedHost.count)
            if domainRegex.firstMatch(in: trimmedHost, options: [], range: range) != nil {
                result.isValid = true
                validationResults.hostValidation = result
                return
            }
        }

        result.isValid = false
        result.errorMessage = "Invalid host format. Use IP address, domain name, or localhost"
        validationResults.hostValidation = result
    }

    func validatePort(_ port: Int) {
        var result = FieldValidation()

        guard port > 0 && port <= 65535 else {
            result.isValid = false
            result.errorMessage = "Port must be between 1 and 65535"
            validationResults.portValidation = result
            return
        }

        // Check for common well-known ports and provide warnings
        switch port {
        case 80:
            result.warningMessage = "Using HTTP port 80 - ensure scheme is 'http'"
        case 443:
            result.warningMessage = "Using HTTPS port 443 - ensure scheme is 'https'"
        case 8000...8999:
            result.warningMessage = "Using development port range"
        case 1...1023:
            result.warningMessage = "Using privileged port range - may require special permissions"
        default:
            break
        }

        result.isValid = true
        validationResults.portValidation = result
    }

    func validateScheme(_ scheme: String) {
        var result = FieldValidation()
        let lowercaseScheme = scheme.lowercased()

        guard ["http", "https"].contains(lowercaseScheme) else {
            result.isValid = false
            result.errorMessage = "Scheme must be 'http' or 'https'"
            validationResults.schemeValidation = result
            return
        }

        if lowercaseScheme == "http" {
            result.warningMessage = "HTTP is not encrypted - use HTTPS for production"
        }

        result.isValid = true
        validationResults.schemeValidation = result
    }

    func validateBaseURL(_ config: BackendConfig) {
        var result = FieldValidation()

        guard let baseURL = config.baseURL else {
            result.isValid = false
            result.errorMessage = "Cannot construct valid URL from configuration"
            validationResults.urlValidation = result
            return
        }

        // Additional URL validation
        guard let components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            result.isValid = false
            result.errorMessage = "Invalid URL components"
            validationResults.urlValidation = result
            return
        }

        guard components.host != nil && components.scheme != nil else {
            result.isValid = false
            result.errorMessage = "URL missing required components"
            validationResults.urlValidation = result
            return
        }

        result.isValid = true
        validationResults.urlValidation = result
    }

    // MARK: - Health Check

    func performHealthCheck(for config: BackendConfig) async {
        guard validationResults.isValid else {
            await MainActor.run {
                self.lastHealthCheckResult = HealthCheckResult(
                    isHealthy: false,
                    responseTime: 0,
                    statusCode: nil,
                    errorMessage: "Configuration validation failed",
                    timestamp: Date()
                )
            }
            return
        }

        await MainActor.run {
            self.isValidating = true
        }

        guard let baseURL = config.baseURL else {
            await MainActor.run {
                self.isValidating = false
                self.lastHealthCheckResult = HealthCheckResult(
                    isHealthy: false,
                    responseTime: 0,
                    statusCode: nil,
                    errorMessage: "Invalid base URL",
                    timestamp: Date()
                )
            }
            return
        }

        let healthURL = baseURL.appendingPathComponent("health")
        let startTime = Date()

        do {
            let (data, response) = try await urlSession.data(from: healthURL)
            let responseTime = Date().timeIntervalSince(startTime) * 1000 // Convert to milliseconds

            let httpResponse = response as? HTTPURLResponse
            let statusCode = httpResponse?.statusCode ?? 0

            let isHealthy = statusCode == 200
            var errorMessage: String?

            if !isHealthy {
                if let responseData = String(data: data, encoding: .utf8) {
                    errorMessage = "HTTP \(statusCode): \(responseData)"
                } else {
                    errorMessage = "HTTP \(statusCode): Health check failed"
                }
            }

            await MainActor.run {
                self.isValidating = false
                self.lastHealthCheckResult = HealthCheckResult(
                    isHealthy: isHealthy,
                    responseTime: responseTime,
                    statusCode: statusCode,
                    errorMessage: errorMessage,
                    timestamp: Date()
                )
            }

        } catch {
            let responseTime = Date().timeIntervalSince(startTime) * 1000

            await MainActor.run {
                self.isValidating = false
                self.lastHealthCheckResult = HealthCheckResult(
                    isHealthy: false,
                    responseTime: responseTime,
                    statusCode: nil,
                    errorMessage: error.localizedDescription,
                    timestamp: Date()
                )
            }
        }
    }

    // MARK: - Utility Methods

    func clearValidation() {
        validationResults = ValidationResults()
        lastHealthCheckResult = nil
    }

    func hasWarnings() -> Bool {
        return validationResults.hostValidation.warningMessage != nil ||
               validationResults.portValidation.warningMessage != nil ||
               validationResults.schemeValidation.warningMessage != nil
    }
}

// MARK: - Validation Results

struct ValidationResults {
    var isValid: Bool = false
    var networkAvailable: Bool = true
    var hostValidation: FieldValidation = FieldValidation()
    var portValidation: FieldValidation = FieldValidation()
    var schemeValidation: FieldValidation = FieldValidation()
    var urlValidation: FieldValidation = FieldValidation()
}

struct FieldValidation {
    var isValid: Bool = false
    var errorMessage: String?
    var warningMessage: String?
}

struct HealthCheckResult {
    let isHealthy: Bool
    let responseTime: Double // in milliseconds
    let statusCode: Int?
    let errorMessage: String?
    let timestamp: Date

    var responseTimeDisplay: String {
        return String(format: "%.0fms", responseTime)
    }

    var statusDisplay: String {
        if isHealthy {
            return "✅ Healthy (\(responseTimeDisplay))"
        } else if let statusCode = statusCode {
            return "❌ HTTP \(statusCode) (\(responseTimeDisplay))"
        } else {
            return "❌ Connection Failed"
        }
    }
}

// MARK: - Extensions

extension BackendConfig {
    var isLocalhost: Bool {
        let localhostPatterns = ["localhost", "127.0.0.1", "::1"]
        return localhostPatterns.contains { host.lowercased().contains($0) }
    }

    var isSecure: Bool {
        return scheme.lowercased() == "https"
    }

    var displayURL: String {
        return "\(scheme)://\(host):\(port)"
    }
}