//
//  BackendSetupSteps.swift
//  Step view components for backend setup flow.
//
//  Contains the individual step views and configuration screens
//  extracted from BackendSetupFlow for better organization.
//

import SwiftUI

// MARK: - Setup Step Views Extension

extension BackendSetupFlow {

    // MARK: - Welcome Step

    var welcomeStepView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Welcome icon
            Image(systemName: "message.badge.filled")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            VStack(spacing: 16) {
                Text("Mobile Claude Code Client")
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("Connect to your Claude Code backend server to start chatting with Claude on your mobile device.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            VStack(spacing: 12) {
                FeatureRow(
                    icon: "server.rack",
                    title: "Self-Hosted Backend",
                    description: "Connect to your own Claude Code server"
                )

                FeatureRow(
                    icon: "message.and.waveform",
                    title: "Real-Time Streaming",
                    description: "See Claude's responses as they're generated"
                )

                FeatureRow(
                    icon: "folder.badge",
                    title: "Multiple Sessions",
                    description: "Manage multiple conversations simultaneously"
                )
            }

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Host Configuration Step

    var hostConfigurationStepView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Quick setup options
                quickSetupSection

                // Custom configuration
                customConfigurationSection

                // Validation summary
                if validator.validationResults.isValid || validator.hasWarnings() {
                    validationSummarySection
                }

                Spacer(minLength: 100) // Space for navigation buttons
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }

    var quickSetupSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Setup")
                    .font(.headline)

                Text("Choose a preset configuration or create a custom one")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                QuickSetupCard(
                    title: "Local Development",
                    subtitle: "localhost:8000",
                    icon: "laptop",
                    isSelected: selectedTab == "local"
                ) {
                    selectedTab = "local"
                    configuration.applyLocalDevelopment()
                    validateCurrentConfiguration()
                }

                QuickSetupCard(
                    title: "Custom Server",
                    subtitle: "Configure manually",
                    icon: "server.rack",
                    isSelected: selectedTab == "custom"
                ) {
                    selectedTab = "custom"
                    // Only clear if we're switching from local to custom and have localhost values
                    if configuration.host == "localhost" || configuration.host.isEmpty {
                        configuration.clearToCustom()
                    }
                    validateCurrentConfiguration()
                }
            }
        }
    }

    var customConfigurationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Server Configuration")
                    .font(.headline)

                Text("Enter your Claude Code backend server details")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 16) {
                // Host input
                ConfigurationField(
                    title: "Host",
                    placeholder: "localhost or your-server.com",
                    text: $configuration.host,
                    validation: validator.validationResults.hostValidation,
                    icon: "server.rack"
                ) {
                    validateCurrentConfiguration()
                }

                // Port input
                ConfigurationField(
                    title: "Port",
                    placeholder: "8000",
                    text: Binding(
                        get: { configuration.port == 0 ? "" : String(configuration.port) },
                        set: { configuration.port = Int($0) ?? 0 }
                    ),
                    validation: validator.validationResults.portValidation,
                    icon: "number",
                    keyboardType: .numberPad
                ) {
                    validateCurrentConfiguration()
                }

                // Scheme selection
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "lock.shield")
                            .foregroundColor(.blue)
                            .frame(width: 20)

                        Text("Security")
                            .font(.headline)
                    }

                    HStack {
                        SchemeButton(
                            title: "HTTP",
                            isSelected: configuration.scheme == "http",
                            color: .orange
                        ) {
                            configuration.scheme = "http"
                            validateCurrentConfiguration()
                        }

                        SchemeButton(
                            title: "HTTPS",
                            isSelected: configuration.scheme == "https",
                            color: .green
                        ) {
                            configuration.scheme = "https"
                            validateCurrentConfiguration()
                        }
                    }

                    if let warning = validator.validationResults.schemeValidation.warningMessage {
                        Text(warning)
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }

                // URL preview
                if validator.validationResults.urlValidation.isValid {
                    HStack {
                        Image(systemName: "link")
                            .foregroundColor(.blue)

                        Text("Server URL: \(configuration.build().displayURL)")
                            .font(.body)
                            .foregroundColor(.secondary)

                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }

    var validationSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Configuration Status")
                .font(.headline)

            VStack(spacing: 8) {
                if validator.validationResults.isValid {
                    ValidationStatusRow(
                        icon: "checkmark.circle.fill",
                        message: "Configuration is valid",
                        color: .green
                    )
                }

                // Show warnings
                if let warning = validator.validationResults.hostValidation.warningMessage {
                    ValidationStatusRow(
                        icon: "exclamationmark.triangle.fill",
                        message: warning,
                        color: .orange
                    )
                }

                if let warning = validator.validationResults.portValidation.warningMessage {
                    ValidationStatusRow(
                        icon: "exclamationmark.triangle.fill",
                        message: warning,
                        color: .orange
                    )
                }

                if let warning = validator.validationResults.schemeValidation.warningMessage {
                    ValidationStatusRow(
                        icon: "exclamationmark.triangle.fill",
                        message: warning,
                        color: .orange
                    )
                }

                // Show errors
                ForEach(Array(Mirror(reflecting: validator.validationResults).children.enumerated()), id: \.offset) { _, child in
                    if let fieldValidation = child.value as? FieldValidation,
                       let error = fieldValidation.errorMessage {
                        ValidationStatusRow(
                            icon: "xmark.circle.fill",
                            message: error,
                            color: .red
                        )
                    }
                }
            }
        }
        .padding(.vertical, 12)
    }

    // MARK: - Connection Test Step

    var connectionTestStepView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Testing animation
            VStack(spacing: 16) {
                if validator.isValidating {
                    ProgressView()
                        .scaleEffect(1.5)
                } else if let result = validator.lastHealthCheckResult {
                    Image(systemName: result.isHealthy ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(result.isHealthy ? .green : .red)
                } else {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                }

                VStack(spacing: 8) {
                    if validator.isValidating {
                        Text("Testing Connection...")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Connecting to \(configuration.build().displayURL)")
                            .font(.body)
                            .foregroundColor(.secondary)
                    } else if let result = validator.lastHealthCheckResult {
                        Text(result.isHealthy ? "Connection Successful!" : "Connection Failed")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(result.isHealthy ? .green : .red)

                        Text(result.statusDisplay)
                            .font(.body)
                            .foregroundColor(.secondary)

                        if !result.isHealthy, let error = result.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    } else {
                        Text("Ready to Test")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Tap 'Test Connection' to verify your configuration")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Text("URL: \(configuration.build().displayURL)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Test button
            if !validator.isValidating {
                Button(action: performConnectionTest) {
                    Label(
                        validator.lastHealthCheckResult == nil ? "Test Connection" : "Test Again",
                        systemImage: "antenna.radiowaves.left.and.right"
                    )
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .glassEffect(.clear.tint(.blue.opacity(0.8)), in: RoundedRectangle(cornerRadius: 12))
                }
            }

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Completion Step

    var completionStepView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Success animation
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)

            VStack(spacing: 16) {
                Text("Setup Complete!")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Your Claude Code mobile client is ready to use. You can now start chatting with Claude!")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            // Configuration summary
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Configuration Summary")
                        .font(.headline)
                    Spacer()
                }

                ConfigSummaryRow(
                    title: "Server",
                    value: configuration.build().displayURL
                )

                ConfigSummaryRow(
                    title: "Security",
                    value: configuration.scheme.uppercased()
                )

                if let result = validator.lastHealthCheckResult {
                    ConfigSummaryRow(
                        title: "Status",
                        value: result.statusDisplay
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))

            Spacer()
        }
        .padding(.horizontal, 24)
    }
}