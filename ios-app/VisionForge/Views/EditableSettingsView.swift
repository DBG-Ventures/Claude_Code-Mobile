//
//  EditableSettingsView.swift
//  Native iOS 26 settings interface with glass navigation.
//
//  Simplified settings management using NavigationSplitView with automatic glass adoption.
//  Standard SwiftUI Forms replace custom liquid glass components for native iOS 26 experience.
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

    // MARK: - Settings Sections
    enum SettingsSection: String, CaseIterable {
        case connection = "Connection"
        case advanced = "Advanced"
        case about = "About"

        var icon: String {
            switch self {
            case .connection:
                return "wifi"
            case .advanced:
                return "gearshape.2"
            case .about:
                return "info.circle"
            }
        }
    }

    // MARK: - Body
    var body: some View {
        NavigationSplitView {
            // Native glass sidebar with List
            List(SettingsSection.allCases, id: \.rawValue) { section in
                NavigationLink(destination: settingsDetailView(for: section)) {
                    Label(section.rawValue, systemImage: section.icon)
                }
            }
            .navigationTitle("Settings")
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 200)
        } detail: {
            // Settings content with native glass adoption
            connectionSettingsView
                .backgroundExtensionEffect()
                .navigationTitle("Settings")
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
                        .fontWeight(.semibold)
                        .buttonStyle(.borderedProminent)
                    }
                }
        }
        .navigationSplitViewStyle(.balanced)
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

    // MARK: - Connection Settings
    private var connectionSettingsView: some View {
        Form {
            Section("Current Connection") {
                connectionStatusRow
            }

            Section("Configuration") {
                TextField("Configuration Name", text: $workingConfig.name)
                TextField("Host", text: $workingConfig.host)
                    .onChange(of: workingConfig.host) { _, _ in
                        validateCurrentConfiguration()
                    }

                TextField("Port", text: Binding(
                    get: { workingConfig.port == 0 ? "" : String(workingConfig.port) },
                    set: { workingConfig.port = Int($0) ?? 0 }
                ))
                .keyboardType(.numberPad)
                .onChange(of: workingConfig.port) { _, _ in
                    validateCurrentConfiguration()
                }

                Picker("Protocol", selection: $workingConfig.scheme) {
                    Text("HTTP").tag("http")
                    Text("HTTPS").tag("https")
                }
                .pickerStyle(.segmented)
                .onChange(of: workingConfig.scheme) { _, _ in
                    validateCurrentConfiguration()
                }
            }

            Section("Connection Test") {
                HStack {
                    Button(action: testCurrentConfiguration) {
                        HStack {
                            if isTestingConnection {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isTestingConnection ? "Testing..." : "Test Connection")
                        }
                    }
                    .disabled(!validator.validationResults.isValid || isTestingConnection)
                    .buttonStyle(.borderedProminent)

                    Spacer()

                    Button("Reset to Defaults") {
                        showingResetAlert = true
                    }
                    .buttonStyle(.bordered)
                }

                if let result = validator.lastHealthCheckResult {
                    connectionTestResultRow(result)
                }
            }

            if !savedConfigurations.isEmpty {
                Section("Saved Configurations") {
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

            Section {
                Button("Save as New Configuration") {
                    saveAsNewConfiguration()
                }
                .disabled(!validator.validationResults.isValid)
                .buttonStyle(.borderedProminent)
            }
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

    private func connectionTestResultRow(_ result: HealthCheckResult) -> some View {
        HStack {
            Image(systemName: result.isHealthy ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(result.isHealthy ? .green : .red)

            VStack(alignment: .leading, spacing: 4) {
                Text(result.isHealthy ? "Connection Successful" : "Connection Failed")
                    .font(.headline)
                    .foregroundColor(result.isHealthy ? .green : .red)
                Text(result.statusDisplay)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Advanced Settings
    private var advancedSettingsView: some View {
        Form {
            Section("Network") {
                LabeledContent("Connection Retry Attempts", value: "3")
                LabeledContent("WebSocket Reconnect Delay", value: "5 seconds")
                LabeledContent("Request Timeout", value: "\(Int(workingConfig.timeout))s")
            }

            Section("Debugging") {
                Toggle("Enable Debug Logging", isOn: .constant(false))
                Toggle("Show Network Requests", isOn: .constant(false))
                Toggle("Log WebSocket Messages", isOn: .constant(false))
            }

            Section("Data Management") {
                Button("Export Configurations") {
                    exportConfigurations()
                }

                Button("Import Configurations") {
                    importConfigurations()
                }

                Button("Clear All Data", role: .destructive) {
                    clearAllData()
                }
            }
        }
    }

    // MARK: - About View
    private var aboutView: some View {
        Form {
            Section("Application Information") {
                LabeledContent("Version", value: "1.0.0")
                LabeledContent("Build", value: "2024.09.15")
                LabeledContent("Platform", value: "iOS/iPadOS")
                LabeledContent("Claude Code SDK", value: "Latest")
            }

            Section("iOS 26 Native Glass") {
                LabeledContent("Glass Effects", value: "Native")
                LabeledContent("Performance", value: "Optimized")
                LabeledContent("Accessibility", value: "Automatic")
            }
        }
    }

    // MARK: - Helper Methods
    @ViewBuilder
    private func settingsDetailView(for section: SettingsSection) -> some View {
        switch section {
        case .connection:
            connectionSettingsView
        case .advanced:
            advancedSettingsView
        case .about:
            aboutView
        }
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

// MARK: - Saved Configuration Row
struct SavedConfigurationRow: View {
    let config: BackendConfig
    let isActive: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(config.name)
                        .font(.headline)
                    if isActive {
                        Text("ACTIVE")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green, in: RoundedRectangle(cornerRadius: 4))
                    }
                }

                Text(config.displayURL)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if !isActive {
                Button("Select") {
                    onSelect()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Button("Delete", role: .destructive) {
                onDelete()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}

// MARK: - Preview
#Preview {
    EditableSettingsView()
        .environmentObject(NetworkManager())
}