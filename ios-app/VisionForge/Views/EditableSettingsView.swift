//
//  EditableSettingsView.swift
//  Full backend configuration editing interface with liquid glass design.
//
//  Provides comprehensive settings management with real-time validation, connection testing,
//  multiple configuration management, and advanced options for Claude Code mobile client.
//  Enhanced with iOS 26 liquid glass effects, touch-responsive animations, and accessibility support.
//

import SwiftUI
import Combine

// MARK: - Editable Settings View

struct EditableSettingsView: View {

    // MARK: - Environment Objects

    @EnvironmentObject var networkManager: NetworkManager
    @Environment(\.presentationMode) var presentationMode

    // MARK: - Liquid Glass Dependencies

    @StateObject private var accessibilityManager = AccessibilityManager()
    @StateObject private var performanceMonitor = LiquidPerformanceMonitor()
    @StateObject private var deviceCapabilities = DeviceCapabilityDetector()

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

    // MARK: - Liquid Animation States

    @State private var sidebarItemScale: [SettingsSection: CGFloat] = [:]
    @State private var showSectionTransition: Bool = false

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
        NavigationView {
            HStack(spacing: 0) {
                // Liquid Glass Sidebar
                liquidGlassSidebar

                // Liquid Glass Divider
                liquidDivider

                // Main content with liquid effects
                liquidSettingsContent
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
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
                    .fontWeight(.semibold)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .environmentObject(accessibilityManager)
        .environmentObject(performanceMonitor)
        .environmentObject(deviceCapabilities)
        .onAppear {
            setupView()
            initializeLiquidEffects()
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

    // MARK: - Liquid Glass Sidebar

    private var liquidGlassSidebar: some View {
        ZStack {
            // Glass background
            RoundedRectangle(cornerRadius: 0)
                .fill(.clear)
                .background(.ultraThinMaterial)
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.05),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            VStack(alignment: .leading, spacing: 12) {
                ForEach(SettingsSection.allCases, id: \.rawValue) { section in
                    LiquidSidebarItem(
                        title: section.rawValue,
                        icon: section.icon,
                        isSelected: selectedSection == section,
                        action: {
                            withAnimation(.liquidTransition) {
                                selectedSection = section
                                showSectionTransition = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showSectionTransition = false
                            }
                        }
                    )
                    .environmentObject(accessibilityManager)
                    .scaleEffect(sidebarItemScale[section] ?? 1.0)
                    .animation(.liquidResponse, value: sidebarItemScale[section])
                }

                Spacer()

                // Version info with glass effect
                VStack(alignment: .leading, spacing: 4) {
                    Text("Version 1.0.0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("iOS 26 Liquid Glass")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            .padding(.top, 16)
        }
        .frame(minWidth: 160, idealWidth: 180, maxWidth: 200)
    }

    // MARK: - Liquid Divider

    private var liquidDivider: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.gray.opacity(0.2),
                        Color.gray.opacity(0.1),
                        Color.gray.opacity(0.2)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 1)
            .overlay(
                Rectangle()
                    .fill(Color.blue.opacity(showSectionTransition ? 0.3 : 0))
                    .animation(.liquidFlow, value: showSectionTransition)
            )
    }

    // MARK: - Liquid Settings Content

    @ViewBuilder
    private var liquidSettingsContent: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.systemGroupedBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .opacity(0.5)

            // Content with liquid transition
            Group {
                switch selectedSection {
                case .connection:
                    liquidConnectionSettingsView
                case .advanced:
                    liquidAdvancedSettingsView
                case .about:
                    liquidAboutView
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .animation(.liquidFlow, value: selectedSection)
        }
    }

    // MARK: - Liquid Connection Settings

    private var liquidConnectionSettingsView: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Current connection status with glass card
                LiquidSettingsCard(
                    title: "Current Connection",
                    icon: "wifi"
                ) {
                    liquidConnectionStatus
                }
                .environmentObject(accessibilityManager)
                .environmentObject(performanceMonitor)

                // Configuration form with glass card
                LiquidSettingsCard(
                    title: "Edit Configuration",
                    icon: "slider.horizontal.3"
                ) {
                    liquidConfigurationForm
                }
                .environmentObject(accessibilityManager)
                .environmentObject(performanceMonitor)

                // Connection testing with glass card
                LiquidSettingsCard(
                    title: "Connection Test",
                    icon: "antenna.radiowaves.left.and.right"
                ) {
                    liquidConnectionTestingSection
                }
                .environmentObject(accessibilityManager)
                .environmentObject(performanceMonitor)

                // Validation summary
                if validator.validationResults.isValid || validator.hasWarnings() {
                    LiquidSettingsCard {
                        liquidValidationSummary
                    }
                    .environmentObject(accessibilityManager)
                    .environmentObject(performanceMonitor)
                }

                // Saved Configurations section
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "folder")
                                .font(.callout)
                                .foregroundColor(.blue)

                            Text("Saved Configurations")
                                .font(.callout)
                                .fontWeight(.semibold)
                        }

                        Spacer()

                        Button(action: saveAsNewConfiguration) {
                            Label("Save", systemImage: "plus.circle")
                                .font(.caption)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(!validator.validationResults.isValid)
                    }
                    .padding(.horizontal, 4)

                    if savedConfigurations.isEmpty {
                        liquidEmptyConfigurationsView
                    } else {
                        liquidConfigurationsListView
                    }
                }
                .padding(.top, 8)

                Spacer(minLength: 100)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    private var liquidConnectionStatus: some View {
        HStack(spacing: 16) {
            // Animated connection indicator
            ZStack {
                Circle()
                    .fill(networkManager.claudeService.isConnected ? Color.green : Color.red)
                    .frame(width: 16, height: 16)

                if networkManager.claudeService.isConnected {
                    Circle()
                        .stroke(Color.green, lineWidth: 2)
                        .frame(width: 24, height: 24)
                        .scaleEffect(1.5)
                        .opacity(0)
                        .animation(
                            Animation.easeOut(duration: 1.5)
                                .repeatForever(autoreverses: false),
                            value: networkManager.claudeService.isConnected
                        )
                }
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 6) {
                Text(networkManager.activeConfig.name)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(networkManager.activeConfig.displayURL)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(spacing: 4) {
                    Image(systemName: networkManager.connectionType.icon)
                        .font(.caption)
                        .foregroundColor(.blue)

                    Text(networkManager.connectionType.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("•")
                        .foregroundColor(.secondary)

                    Text(networkManager.claudeService.isConnected ? "Active" : "Inactive")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(networkManager.claudeService.isConnected ? .green : .orange)
                }
            }

            Spacer()

            LiquidButton(
                title: "Health Check",
                icon: "heart.text.square",
                style: .secondary,
                action: performHealthCheck
            )
            .environmentObject(accessibilityManager)
        }
    }

    private var liquidConfigurationForm: some View {
        VStack(spacing: 20) {
            // Configuration name with liquid text field
            LiquidTextField(
                title: "Configuration Name",
                placeholder: "My Server",
                text: $workingConfig.name,
                icon: "tag",
                validation: FieldValidation()
            )
            .environmentObject(accessibilityManager)

            // Host with liquid text field
            LiquidTextField(
                title: "Host",
                placeholder: "localhost or your-server.com",
                text: $workingConfig.host,
                icon: "server.rack",
                validation: validator.validationResults.hostValidation,
                onChange: validateCurrentConfiguration
            )
            .environmentObject(accessibilityManager)

            // Port with liquid text field
            LiquidTextField(
                title: "Port",
                placeholder: "8000",
                text: Binding(
                    get: { workingConfig.port == 0 ? "" : String(workingConfig.port) },
                    set: { workingConfig.port = Int($0) ?? 0 }
                ),
                icon: "number",
                validation: validator.validationResults.portValidation,
                keyboardType: .numberPad,
                onChange: validateCurrentConfiguration
            )
            .environmentObject(accessibilityManager)

            // Protocol selection with liquid buttons
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield")
                        .font(.body)
                        .foregroundColor(.blue)
                        .frame(width: 20)

                    Text("Protocol")
                        .font(.headline)
                }

                HStack(spacing: 12) {
                    LiquidButton(
                        title: "HTTP",
                        icon: "lock.open",
                        style: workingConfig.scheme == "http" ? .primary : .secondary,
                        action: {
                            withAnimation(.liquidResponse) {
                                workingConfig.scheme = "http"
                            }
                            validateCurrentConfiguration()
                        }
                    )
                    .environmentObject(accessibilityManager)

                    LiquidButton(
                        title: "HTTPS",
                        icon: "lock.fill",
                        style: workingConfig.scheme == "https" ? .primary : .secondary,
                        action: {
                            withAnimation(.liquidResponse) {
                                workingConfig.scheme = "https"
                            }
                            validateCurrentConfiguration()
                        }
                    )
                    .environmentObject(accessibilityManager)

                    Spacer()
                }

                if let warning = validator.validationResults.schemeValidation.warningMessage {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text(warning)
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.liquidFeedback, value: warning)
                }
            }

            // Timeout setting with liquid slider
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.body)
                        .foregroundColor(.blue)
                        .frame(width: 20)

                    Text("Timeout")
                        .font(.headline)

                    Spacer()

                    Text("\(Int(workingConfig.timeout))s")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.regularMaterial)
                        )
                }

                HStack {
                    Text("5s")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Slider(
                        value: $workingConfig.timeout,
                        in: 5...60,
                        step: 5
                    )
                    .tint(.blue)

                    Text("60s")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var liquidConnectionTestingSection: some View {
        VStack(spacing: 16) {
            if let result = validator.lastHealthCheckResult {
                liquidConnectionTestResult(result)
            }

            HStack(spacing: 12) {
                LiquidButton(
                    title: isTestingConnection ? "Testing..." : "Test Connection",
                    icon: "antenna.radiowaves.left.and.right",
                    style: .primary,
                    action: testCurrentConfiguration
                )
                .disabled(!validator.validationResults.isValid || isTestingConnection)
                .environmentObject(accessibilityManager)
                .overlay(
                    Group {
                        if isTestingConnection {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                                .padding(.trailing, 8)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                )

                Spacer()

                LiquidButton(
                    title: "Reset to Defaults",
                    icon: "arrow.counterclockwise",
                    style: .destructive,
                    action: {
                        showingResetAlert = true
                    }
                )
                .environmentObject(accessibilityManager)
            }
        }
    }

    private func liquidConnectionTestResult(_ result: HealthCheckResult) -> some View {
        HStack(spacing: 16) {
            // Animated status icon
            ZStack {
                Circle()
                    .fill(result.isHealthy ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: result.isHealthy ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(result.isHealthy ? .green : .red)
                    .scaleEffect(result.isHealthy ? 1.0 : 0.9)
                    .animation(.liquidElastic, value: result.isHealthy)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(result.isHealthy ? "Connection Successful" : "Connection Failed")
                    .font(.headline)
                    .foregroundColor(result.isHealthy ? .green : .red)

                Text(result.statusDisplay)
                    .font(.subheadline)
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
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            result.isHealthy ? Color.green.opacity(0.3) : Color.red.opacity(0.3),
                            lineWidth: 1
                        )
                )
        )
        .transition(.asymmetric(
            insertion: .scale.combined(with: .opacity),
            removal: .scale.combined(with: .opacity)
        ))
    }

    private var liquidValidationSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.shield")
                    .font(.callout)
                    .foregroundColor(.blue)

                Text("Validation Summary")
                    .font(.callout)
                    .fontWeight(.semibold)
            }

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


    private var liquidEmptyConfigurationsView: some View {
        LiquidSettingsCard {
            VStack(spacing: 16) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 48))
                    .foregroundColor(.blue.opacity(0.6))

                Text("No Saved Configurations")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("Save your current configuration to quickly switch between different servers.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
        .environmentObject(accessibilityManager)
        .environmentObject(performanceMonitor)
    }

    private var liquidConfigurationsListView: some View {
        VStack(spacing: 12) {
            ForEach(savedConfigurations) { config in
                LiquidSavedConfigurationRow(
                    config: config,
                    isActive: config.id == networkManager.activeConfig.id,
                    onSelect: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectConfiguration(config)
                        }
                    },
                    onDelete: {
                        configToDelete = config
                        showingDeleteAlert = true
                    }
                )
                .environmentObject(accessibilityManager)
                .environmentObject(performanceMonitor)
            }
        }
    }

    // MARK: - Liquid Advanced Settings

    private var liquidAdvancedSettingsView: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Network settings card
                LiquidSettingsCard(
                    title: "Network Configuration",
                    icon: "network"
                ) {
                    liquidNetworkAdvancedSettings
                }
                .environmentObject(accessibilityManager)
                .environmentObject(performanceMonitor)

                // Debugging settings card
                LiquidSettingsCard(
                    title: "Debugging",
                    icon: "ant.fill"
                ) {
                    liquidDebuggingSettings
                }
                .environmentObject(accessibilityManager)
                .environmentObject(performanceMonitor)

                // Data management card
                LiquidSettingsCard(
                    title: "Data Management",
                    icon: "externaldrive.fill"
                ) {
                    liquidDataManagementSettings
                }
                .environmentObject(accessibilityManager)
                .environmentObject(performanceMonitor)

                Spacer(minLength: 100)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    private var liquidNetworkAdvancedSettings: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Connection Retry Attempts")
                    .font(.body)
                Spacer()
                Text("3")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.blue.opacity(0.1))
                    )
            }

            Divider()
                .opacity(0.3)

            HStack {
                Text("WebSocket Reconnect Delay")
                    .font(.body)
                Spacer()
                Text("5 seconds")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.blue.opacity(0.1))
                    )
            }

            Divider()
                .opacity(0.3)

            HStack {
                Text("Request Timeout")
                    .font(.body)
                Spacer()
                Text("\(Int(workingConfig.timeout))s")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.blue.opacity(0.1))
                    )
            }
        }
    }

    private var liquidDebuggingSettings: some View {
        VStack(spacing: 16) {
            LiquidToggle(
                title: "Enable Debug Logging",
                isOn: .constant(false),
                icon: "doc.text.magnifyingglass"
            )
            .environmentObject(accessibilityManager)

            Divider()
                .opacity(0.3)

            LiquidToggle(
                title: "Show Network Requests",
                isOn: .constant(false),
                icon: "network.badge.shield.half.filled"
            )
            .environmentObject(accessibilityManager)

            Divider()
                .opacity(0.3)

            LiquidToggle(
                title: "Log WebSocket Messages",
                isOn: .constant(false),
                icon: "message.badge.waveform"
            )
            .environmentObject(accessibilityManager)
        }
    }

    private var liquidDataManagementSettings: some View {
        VStack(spacing: 16) {
            LiquidButton(
                title: "Export Configurations",
                icon: "square.and.arrow.up",
                style: .secondary,
                action: exportConfigurations
            )
            .environmentObject(accessibilityManager)

            LiquidButton(
                title: "Import Configurations",
                icon: "square.and.arrow.down",
                style: .secondary,
                action: importConfigurations
            )
            .environmentObject(accessibilityManager)

            Divider()
                .opacity(0.3)
                .padding(.vertical, 4)

            LiquidButton(
                title: "Clear All Data",
                icon: "trash",
                style: .destructive,
                action: clearAllData
            )
            .environmentObject(accessibilityManager)
        }
    }

    // MARK: - Liquid About View

    private var liquidAboutView: some View {
        ScrollView {
            VStack(spacing: 28) {
                // App info card
                LiquidSettingsCard(
                    title: "Application Information",
                    icon: "info.circle"
                ) {
                    VStack(spacing: 16) {
                        liquidAboutInfoRow(title: "Version", value: "1.0.0", icon: "number.circle")
                        Divider().opacity(0.3)
                        liquidAboutInfoRow(title: "Build", value: "2024.09.15", icon: "hammer.circle")
                        Divider().opacity(0.3)
                        liquidAboutInfoRow(title: "Platform", value: "iOS/iPadOS", icon: "ipad.and.iphone")
                        Divider().opacity(0.3)
                        liquidAboutInfoRow(title: "Claude Code SDK", value: "Latest", icon: "cpu")
                    }
                }
                .environmentObject(accessibilityManager)
                .environmentObject(performanceMonitor)

                // Liquid Glass info card
                LiquidSettingsCard(
                    title: "Liquid Glass System",
                    icon: "sparkles"
                ) {
                    VStack(spacing: 16) {
                        liquidAboutInfoRow(title: "Effect Level", value: deviceCapabilities.getRecommendedEffectLevel().rawValue, icon: "wand.and.stars")
                        Divider().opacity(0.3)
                        liquidAboutInfoRow(title: "Device Support", value: deviceCapabilities.supportsFullLiquidGlass() ? "Full" : "Basic", icon: "checkmark.shield")
                        Divider().opacity(0.3)
                        liquidAboutInfoRow(title: "Performance", value: performanceMonitor.liquidEffectsEnabled ? "Optimized" : "Reduced", icon: "speedometer")
                    }
                }
                .environmentObject(accessibilityManager)
                .environmentObject(performanceMonitor)

                Spacer(minLength: 100)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    private func liquidAboutInfoRow(title: String, value: String, icon: String? = nil) -> some View {
        HStack(spacing: 12) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(.blue)
                    .frame(width: 24)
            }

            Text(title)
                .font(.body)
                .foregroundColor(.primary)

            Spacer()

            Text(value)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.blue.opacity(0.1))
                )
        }
    }

    // MARK: - Setup Methods

    private func setupView() {
        loadSavedConfigurations()
        workingConfig.loadFrom(networkManager.activeConfig)
        validateCurrentConfiguration()
    }

    private func initializeLiquidEffects() {
        // Initialize sidebar item scales
        for section in SettingsSection.allCases {
            sidebarItemScale[section] = 1.0
        }

        // Start performance monitoring
        performanceMonitor.startMonitoring()

        // Configure accessibility manager
        accessibilityManager.updateFromEnvironment(
            reduceTransparency: false,
            reduceMotion: false,
            dynamicTypeSize: .medium
        )
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

// MARK: - Liquid Saved Configuration Row

struct LiquidSavedConfigurationRow: View {
    let config: BackendConfig
    let isActive: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    @State private var isPressed: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    @EnvironmentObject var performanceMonitor: LiquidPerformanceMonitor

    var body: some View {
        HStack(spacing: 16) {
            // Status indicator
            ZStack {
                Circle()
                    .fill(isActive ? Color.green.opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 40, height: 40)

                Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isActive ? .green : .gray)
                    .animation(.liquidBubble, value: isActive)
            }

            // Configuration details
            VStack(alignment: .leading, spacing: 6) {
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
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.green, Color.green.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                            .transition(.scale.combined(with: .opacity))
                    }

                    Spacer()
                }

                Text(config.displayURL)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    Label(
                        config.scheme.uppercased(),
                        systemImage: config.isSecure ? "lock.fill" : "lock.open"
                    )
                    .font(.caption)
                    .foregroundColor(config.isSecure ? .green : .orange)

                    Text("•")
                        .foregroundColor(.secondary)

                    Label(
                        "\(Int(config.timeout))s",
                        systemImage: "clock"
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }

            // Action buttons
            VStack(spacing: 10) {
                if !isActive {
                    Button(action: onSelect) {
                        Image(systemName: "checkmark.circle")
                            .font(.title3)
                            .foregroundColor(.blue)
                            .frame(width: 30, height: 30)
                            .background(
                                Circle()
                                    .fill(Color.blue.opacity(0.1))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Button(action: {
                    showDeleteConfirmation = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if showDeleteConfirmation {
                            onDelete()
                            showDeleteConfirmation = false
                        }
                    }
                }) {
                    Image(systemName: showDeleteConfirmation ? "trash.fill" : "trash")
                        .font(.title3)
                        .foregroundColor(.red)
                        .frame(width: 30, height: 30)
                        .background(
                            Circle()
                                .fill(Color.red.opacity(showDeleteConfirmation ? 0.2 : 0.1))
                        )
                        .scaleEffect(showDeleteConfirmation ? 0.9 : 1.0)
                        .animation(.liquidFeedback, value: showDeleteConfirmation)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            isActive ? Color.green.opacity(0.3) : Color.gray.opacity(0.2),
                            lineWidth: isActive ? 2 : 1
                        )
                )
                .shadow(
                    color: isActive ? Color.green.opacity(0.1) : Color.black.opacity(0.05),
                    radius: isActive ? 8 : 4,
                    x: 0,
                    y: 2
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if !isActive {
                onSelect()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    EditableSettingsView()
        .environmentObject(NetworkManager())
}