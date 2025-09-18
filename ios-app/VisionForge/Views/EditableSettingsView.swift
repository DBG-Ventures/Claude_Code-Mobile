//
//  EditableSettingsView.swift
//  Unified iOS 26 settings interface following Liquid Glass design guidelines.
//
//  Implements proper separation between functional glass layer (header) and content layer (form).
//  Follows Apple's principle: "Liquid Glass seeks to bring attention to the underlying content."
//

import SwiftUI
import Combine

struct EditableSettingsView: View {
    // MARK: - Environment Objects
    @EnvironmentObject var networkManager: NetworkManager
    @Environment(\.presentationMode) var presentationMode

    // MARK: - State Properties
    @StateObject private var validator = ConfigurationValidator()
    @State private var workingConfig: BackendConfigBuilder = BackendConfigBuilder()
    @State private var savedConfigurations: [BackendConfig] = []
    @State private var showingDeleteAlert = false
    @State private var configToDelete: BackendConfig?
    @State private var showingResetAlert = false
    @State private var isTestingConnection = false
    @State private var isSaving = false

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // Header with glass effect (functional layer)
            HStack {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)

                Spacer()

                Text("Settings")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Button("Save") {
                    saveCurrentConfiguration()
                }
                .disabled(!validator.validationResults.isValid || isSaving)
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .fontWeight(.semibold)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 12))
            .ignoresSafeArea(edges: .top)

            // Content layer: Standard Form (NO glass effects on content)
            Form {
                connectionStatusSection
                configurationAndActionsSection
                savedConfigurationsSection // Always show, even if empty
                advancedOptionsSection
                aboutSection
            }
            .formStyle(.grouped)
        }
        .onAppear {
            setupView()
        }
        .alert("Delete Configuration", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let config = configToDelete {
                    deleteConfiguration(config)
                }
            }
        } message: {
            Text("Are you sure you want to delete this configuration? This action cannot be undone.")
        }
        .alert("Reset to Defaults", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                resetToDefaults()
            }
        } message: {
            Text("This will reset the current configuration to default values. Are you sure?")
        }
    }

    // MARK: - Form Sections (Content Layer - NO Glass Effects)

    private var connectionStatusSection: some View {
        Section("Current Connection") {
            connectionStatusRow
        }
    }

    private var configurationAndActionsSection: some View {
        Section("Configuration") {
            VStack(spacing: 16) {
                // Configuration Name
                HStack {
                    Text("Name")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(width: 60, alignment: .leading)

                    TextField("Configuration Name", text: $workingConfig.name)
                        .textFieldStyle(.roundedBorder)
                }

                // Host and Port in one row
                HStack(spacing: 12) {
                    HStack {
                        Text("Host")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(width: 35, alignment: .leading)

                        TextField("localhost", text: $workingConfig.host)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack {
                        Text("Port")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(width: 30, alignment: .leading)

                        TextField("8000", text: Binding(
                            get: { workingConfig.port == 0 ? "" : String(workingConfig.port) },
                            set: { workingConfig.port = Int($0) ?? 0 }
                        ))
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 80)
                    }
                }

                // Protocol picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Protocol")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Picker("Protocol", selection: $workingConfig.scheme) {
                        Text("HTTP").tag("http")
                        Text("HTTPS").tag("https")
                    }
                    .pickerStyle(.segmented)
                }

                // Test result if available
                if let result = validator.lastHealthCheckResult {
                    connectionTestResultCard(result)
                }

                // Single row of action buttons with glass effects
                HStack(spacing: 8) {
                    Button(action: testCurrentConfiguration) {
                        HStack(spacing: 4) {
                            if isTestingConnection {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                            Text(isTestingConnection ? "Testing" : "Test")
                        }
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(!validator.validationResults.isValid || isTestingConnection)
                    .buttonStyle(.glassProminent)
                    .controlSize(.small)

                    Button("Reset") {
                        showingResetAlert = true
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    .font(.caption)

                    Button("Save New") {
                        saveAsNewConfiguration()
                    }
                    .disabled(!validator.validationResults.isValid)
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    .font(.caption)
                }
            }
            .padding(.vertical, 8)
        }
        .onChange(of: workingConfig.host) { _, _ in validateCurrentConfiguration() }
        .onChange(of: workingConfig.port) { _, _ in validateCurrentConfiguration() }
        .onChange(of: workingConfig.scheme) { _, _ in validateCurrentConfiguration() }
    }


    private var savedConfigurationsSection: some View {
        Section {
            if savedConfigurations.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "externaldrive.badge.plus")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)

                    VStack(spacing: 4) {
                        Text("No Saved Configurations")
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text("Create and save configurations for quick switching between different backend servers.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ForEach(savedConfigurations) { config in
                    SavedConfigurationCard(
                        config: config,
                        isActive: config.id == networkManager.activeConfig.id,
                        onSelect: { selectConfiguration(config) },
                        onDelete: {
                            configToDelete = config
                            showingDeleteAlert = true
                        }
                    )
                }
            }
        } header: {
            Text("Saved Configurations")
        }
    }

    private var advancedOptionsSection: some View {
        Section("Advanced Options") {
            LabeledContent("Connection Retry Attempts", value: "3")
            LabeledContent("WebSocket Reconnect Delay", value: "5 seconds")
            LabeledContent("Request Timeout", value: "\(Int(workingConfig.timeout))s")

            Toggle("Enable Debug Logging", isOn: .constant(false))
            Toggle("Show Network Requests", isOn: .constant(false))
            Toggle("Log WebSocket Messages", isOn: .constant(false))
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: "1.0.0")
            LabeledContent("Build", value: "2024.09.18")
            LabeledContent("Platform", value: "iOS/iPadOS 26+")
            LabeledContent("Claude Code SDK", value: "Latest")
            LabeledContent("Liquid Glass", value: "Native iOS 26")
            LabeledContent("Performance", value: "Optimized")
        }
    }

    private var connectionStatusRow: some View {
        HStack {
            Circle()
                .fill(networkManager.claudeService.isConnected ? Color.green : Color.red)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 4) {
                Text(networkManager.activeConfig.name)
                    .font(.headline)
                Text(networkManager.activeConfig.displayURL)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Health Check") {
                performHealthCheck()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private func connectionTestResultCard(_ result: HealthCheckResult) -> some View {
        HStack(spacing: 12) {
            Image(systemName: result.isHealthy ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title2)
                .foregroundColor(result.isHealthy ? .green : .red)

            VStack(alignment: .leading, spacing: 4) {
                Text(result.isHealthy ? "Connection Successful" : "Connection Failed")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(result.isHealthy ? .green : .red)

                Text(result.statusDisplay)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(result.isHealthy ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(result.isHealthy ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }


    private func setupView() {
        loadSavedConfigurations()
        workingConfig.loadFrom(networkManager.activeConfig)
        validateCurrentConfiguration()
    }

    private func loadSavedConfigurations() {
        if let data = UserDefaults.standard.data(forKey: "SavedConfigurations"),
           let configs = try? JSONDecoder().decode([BackendConfig].self, from: data) {
            savedConfigurations = configs
        }
    }

    private func validateCurrentConfiguration() {
        let config = workingConfig.build()
        validator.validateConfiguration(config)
    }

    private func testCurrentConfiguration() {
        isTestingConnection = true
        let config = workingConfig.build()

        Task {
            await validator.performHealthCheck(for: config)
            await MainActor.run {
                isTestingConnection = false
            }
        }
    }

    private func performHealthCheck() {
        Task {
            let isHealthy = await networkManager.performHealthCheck()
            print(isHealthy ? "✅ Health check passed" : "❌ Health check failed")
        }
    }

    private func saveCurrentConfiguration() {
        guard validator.validationResults.isValid else { return }

        isSaving = true
        let config = workingConfig.build()

        Task {
            await networkManager.updateConfiguration(config)

            if let configData = try? JSONEncoder().encode(config) {
                UserDefaults.standard.set(configData, forKey: "BackendConfiguration")
            }

            await MainActor.run {
                isSaving = false
                presentationMode.wrappedValue.dismiss()
            }
        }
    }

    private func saveAsNewConfiguration() {
        guard validator.validationResults.isValid else { return }

        let config = workingConfig.build()
        savedConfigurations.append(config)
        saveSavedConfigurations()
    }

    private func selectConfiguration(_ config: BackendConfig) {
        workingConfig.loadFrom(config)
        validateCurrentConfiguration()
    }

    private func deleteConfiguration(_ config: BackendConfig) {
        savedConfigurations.removeAll { $0.id == config.id }
        saveSavedConfigurations()
        configToDelete = nil
    }

    private func saveSavedConfigurations() {
        if let data = try? JSONEncoder().encode(savedConfigurations) {
            UserDefaults.standard.set(data, forKey: "SavedConfigurations")
        }
    }

    private func resetToDefaults() {
        workingConfig = BackendConfigBuilder()
        workingConfig.applyLocalDevelopment()
        validateCurrentConfiguration()
    }

    private func exportConfigurations() {
        // Implementation for exporting configurations
    }

    private func importConfigurations() {
        // Implementation for importing configurations
    }

    private func clearAllData() {
        // Implementation for clearing all data
    }
}

// MARK: - Saved Configuration Card
struct SavedConfigurationCard: View {
    let config: BackendConfig
    let isActive: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Main content
            HStack(spacing: 12) {
                // Status indicator
                Circle()
                    .fill(isActive ? Color.green : Color.gray.opacity(0.4))
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(config.name)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        if isActive {
                            Text("ACTIVE")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green, in: RoundedRectangle(cornerRadius: 3))
                        }
                    }

                    Text(config.displayURL)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Action buttons
            if !isActive {
                Divider()

                HStack(spacing: 0) {
                    Button(action: onSelect) {
                        Text("Use Configuration")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }

                    Divider()
                        .frame(height: 20)

                    Button(action: onDelete) {
                        Text("Delete")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isActive ? Color.green.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Preview
#Preview {
    EditableSettingsView()
        .environmentObject(NetworkManager())
}
