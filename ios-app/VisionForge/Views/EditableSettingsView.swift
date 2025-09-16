//
//  EditableSettingsView.swift
//  Full backend configuration editing interface.
//
//  Provides comprehensive settings management with real-time validation, connection testing,
//  multiple configuration management, and advanced options for Claude Code mobile client.
//

import SwiftUI
import Combine

// MARK: - Editable Settings View

struct EditableSettingsView: View {

    // MARK: - Environment Objects

    @EnvironmentObject var networkManager: NetworkManager
    @Environment(\.presentationMode) var presentationMode

    // MARK: - State Properties

    @StateObject private var validator = ConfigurationValidator()
    @State private var workingConfig: BackendConfigBuilder = BackendConfigBuilder()
    @State private var savedConfigurations: [BackendConfig] = []
    @State private var selectedSection: SettingsSection = .connection
    @State private var showingDeleteAlert = false
    @State private var configToDelete: BackendConfig?
    @State private var showingResetAlert = false
    @State private var isTestingConnection = false
    @State private var isSaving = false

    // MARK: - Settings Sections

    enum SettingsSection: String, CaseIterable {
        case connection = "Connection"
        case configurations = "Saved Configurations"
        case advanced = "Advanced"
        case about = "About"

        var icon: String {
            switch self {
            case .connection:
                return "wifi"
            case .configurations:
                return "folder"
            case .advanced:
                return "gearshape.2"
            case .about:
                return "info.circle"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            HStack(spacing: 0) {
                // Sidebar for sections (iPad style)
                sectionSidebar

                Divider()

                // Main content
                settingsContent
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveCurrentConfiguration()
                    }
                    .disabled(!validator.validationResults.isValid || isSaving)
                }
            }
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

    // MARK: - Section Sidebar

    private var sectionSidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(SettingsSection.allCases, id: \.rawValue) { section in
                Button(action: { selectedSection = section }) {
                    HStack(spacing: 12) {
                        Image(systemName: section.icon)
                            .font(.body)
                            .foregroundColor(selectedSection == section ? .white : .blue)
                            .frame(width: 20)

                        Text(section.rawValue)
                            .font(.body)
                            .foregroundColor(selectedSection == section ? .white : .primary)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedSection == section ? Color.blue : Color.clear)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }

            Spacer()
        }
        .frame(width: 200)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemGroupedBackground))
    }

    // MARK: - Settings Content

    @ViewBuilder
    private var settingsContent: some View {
        switch selectedSection {
        case .connection:
            connectionSettingsView
        case .configurations:
            savedConfigurationsView
        case .advanced:
            advancedSettingsView
        case .about:
            aboutView
        }
    }

    // MARK: - Connection Settings

    private var connectionSettingsView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Current connection status
                currentConnectionStatus

                // Configuration form
                configurationForm

                // Connection testing
                connectionTestingSection

                // Validation summary
                if validator.validationResults.isValid || validator.hasWarnings() {
                    validationSummary
                }

                Spacer(minLength: 100)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }

    private var currentConnectionStatus: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Current Connection")
                .font(.title2)
                .fontWeight(.bold)

            HStack(spacing: 16) {
                // Connection status indicator
                VStack(spacing: 8) {
                    Circle()
                        .fill(networkManager.claudeService.isConnected ? Color.green : Color.red)
                        .frame(width: 12, height: 12)

                    Text(networkManager.claudeService.isConnected ? "Connected" : "Disconnected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(networkManager.activeConfig.name)
                        .font(.headline)

                    Text(networkManager.activeConfig.displayURL)
                        .font(.body)
                        .foregroundColor(.secondary)

                    HStack {
                        Image(systemName: networkManager.connectionType.icon)
                            .font(.caption)
                            .foregroundColor(.blue)

                        Text(networkManager.connectionType.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Button("Health Check") {
                    performHealthCheck()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }

    private var configurationForm: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Edit Configuration")
                .font(.title2)
                .fontWeight(.bold)

            VStack(spacing: 16) {
                // Configuration name
                ConfigurationField(
                    title: "Configuration Name",
                    placeholder: "My Server",
                    text: $workingConfig.name,
                    validation: FieldValidation(), // Name doesn't need validation
                    icon: "tag"
                ) {
                    // No validation needed for name
                }

                // Host
                ConfigurationField(
                    title: "Host",
                    placeholder: "localhost or your-server.com",
                    text: $workingConfig.host,
                    validation: validator.validationResults.hostValidation,
                    icon: "server.rack"
                ) {
                    validateCurrentConfiguration()
                }

                // Port
                ConfigurationField(
                    title: "Port",
                    placeholder: "8000",
                    text: Binding(
                        get: { workingConfig.port == 0 ? "" : String(workingConfig.port) },
                        set: { workingConfig.port = Int($0) ?? 0 }
                    ),
                    validation: validator.validationResults.portValidation,
                    icon: "number",
                    keyboardType: .numberPad
                ) {
                    validateCurrentConfiguration()
                }

                // Scheme selection
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "lock.shield")
                            .foregroundColor(.blue)
                            .frame(width: 20)

                        Text("Protocol")
                            .font(.headline)
                    }

                    HStack {
                        SchemeButton(
                            title: "HTTP",
                            isSelected: workingConfig.scheme == "http",
                            color: .orange
                        ) {
                            workingConfig.scheme = "http"
                            validateCurrentConfiguration()
                        }

                        SchemeButton(
                            title: "HTTPS",
                            isSelected: workingConfig.scheme == "https",
                            color: .green
                        ) {
                            workingConfig.scheme = "https"
                            validateCurrentConfiguration()
                        }

                        Spacer()
                    }

                    if let warning = validator.validationResults.schemeValidation.warningMessage {
                        Text(warning)
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }

                // Timeout setting
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.blue)
                            .frame(width: 20)

                        Text("Timeout (seconds)")
                            .font(.headline)
                    }

                    HStack {
                        Slider(
                            value: $workingConfig.timeout,
                            in: 5...60,
                            step: 5
                        ) {
                            Text("Timeout")
                        } minimumValueLabel: {
                            Text("5s")
                                .font(.caption)
                        } maximumValueLabel: {
                            Text("60s")
                                .font(.caption)
                        }

                        Text("\(Int(workingConfig.timeout))s")
                            .font(.body)
                            .fontWeight(.medium)
                            .frame(width: 40)
                    }
                }
            }
        }
    }

    private var connectionTestingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Connection Test")
                .font(.title2)
                .fontWeight(.bold)

            if let result = validator.lastHealthCheckResult {
                connectionTestResult(result)
            }

            HStack {
                Button(action: testCurrentConfiguration) {
                    Label(
                        isTestingConnection ? "Testing..." : "Test Connection",
                        systemImage: "antenna.radiowaves.left.and.right"
                    )
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(validator.validationResults.isValid ? Color.blue : Color.gray)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .disabled(!validator.validationResults.isValid || isTestingConnection)

                Spacer()

                Button("Reset to Defaults") {
                    showingResetAlert = true
                }
                .foregroundColor(.red)
            }
        }
    }

    private func connectionTestResult(_ result: HealthCheckResult) -> some View {
        HStack(spacing: 12) {
            Image(systemName: result.isHealthy ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title2)
                .foregroundColor(result.isHealthy ? .green : .red)

            VStack(alignment: .leading, spacing: 4) {
                Text(result.isHealthy ? "Connection Successful" : "Connection Failed")
                    .font(.headline)
                    .foregroundColor(result.isHealthy ? .green : .red)

                Text(result.statusDisplay)
                    .font(.body)
                    .foregroundColor(.secondary)

                if !result.isHealthy, let error = result.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(3)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(result.isHealthy ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        )
    }

    private var validationSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Validation Summary")
                .font(.title2)
                .fontWeight(.bold)

            VStack(spacing: 8) {
                if validator.validationResults.isValid {
                    ValidationStatusRow(
                        icon: "checkmark.circle.fill",
                        message: "Configuration is valid",
                        color: .green
                    )
                }

                // Show any warnings or errors
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
    }

    // MARK: - Saved Configurations

    private var savedConfigurationsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Saved Configurations")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Button("Save Current") {
                    saveAsNewConfiguration()
                }
                .disabled(!validator.validationResults.isValid)
            }

            if savedConfigurations.isEmpty {
                emptyConfigurationsView
            } else {
                configurationsListView
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var emptyConfigurationsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Saved Configurations")
                .font(.headline)

            Text("Save your current configuration to quickly switch between different servers.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxHeight: .infinity)
    }

    private var configurationsListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(savedConfigurations) { config in
                    SavedConfigurationRow(
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
        }
    }

    // MARK: - Advanced Settings

    private var advancedSettingsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Advanced Settings")
                    .font(.title2)
                    .fontWeight(.bold)

                // Network settings
                networkAdvancedSettings

                // Debugging settings
                debuggingSettings

                // Data management
                dataManagementSettings

                Spacer(minLength: 100)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }

    private var networkAdvancedSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Network Configuration")
                .font(.headline)

            VStack(spacing: 12) {
                HStack {
                    Text("Connection Retry Attempts")
                    Spacer()
                    Text("3")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("WebSocket Reconnect Delay")
                    Spacer()
                    Text("5 seconds")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Request Timeout")
                    Spacer()
                    Text("\(Int(workingConfig.timeout)) seconds")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var debuggingSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Debugging")
                .font(.headline)

            VStack(spacing: 12) {
                Toggle("Enable Debug Logging", isOn: .constant(false))
                Toggle("Show Network Requests", isOn: .constant(false))
                Toggle("Log WebSocket Messages", isOn: .constant(false))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var dataManagementSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Data Management")
                .font(.headline)

            VStack(spacing: 12) {
                Button("Export Configurations") {
                    exportConfigurations()
                }
                .foregroundColor(.blue)

                Button("Import Configurations") {
                    importConfigurations()
                }
                .foregroundColor(.blue)

                Button("Clear All Data") {
                    clearAllData()
                }
                .foregroundColor(.red)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - About View

    private var aboutView: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("About")
                .font(.title2)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 16) {
                aboutInfoRow(title: "Version", value: "1.0.0")
                aboutInfoRow(title: "Build", value: "2024.09.15")
                aboutInfoRow(title: "Platform", value: "iOS/iPadOS")
                aboutInfoRow(title: "Claude Code SDK", value: "Latest")
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private func aboutInfoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.body)
            Spacer()
            Text(value)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Setup Methods

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

            // Save to UserDefaults
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

// MARK: - Configuration Builder Extension

extension BackendConfigBuilder {
    // Extension methods can be added here if needed in the future
}

// MARK: - Saved Configuration Row

struct SavedConfigurationRow: View {
    let config: BackendConfig
    let isActive: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(config.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    if isActive {
                        Text("ACTIVE")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }

                    Spacer()
                }

                Text(config.displayURL)
                    .font(.body)
                    .foregroundColor(.secondary)

                HStack {
                    Text(config.scheme.uppercased())
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(config.isSecure ? .green : .orange)

                    Text("•")
                        .foregroundColor(.secondary)

                    Text("\(Int(config.timeout))s timeout")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            VStack(spacing: 8) {
                Button("Select") {
                    onSelect()
                }
                .font(.caption)
                .foregroundColor(.blue)

                Button("Delete") {
                    onDelete()
                }
                .font(.caption)
                .foregroundColor(.red)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isActive ? Color.green : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Preview

#Preview {
    EditableSettingsView()
        .environmentObject(NetworkManager())
}