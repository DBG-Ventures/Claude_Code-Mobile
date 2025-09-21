//
//  BackendSetupFlow.swift
//  Mandatory first-time backend configuration setup flow.
//
//  Provides comprehensive onboarding experience for Claude Code mobile client backend setup
//  with step-by-step configuration, real-time validation, and connection testing.
//

import SwiftUI
import Combine
import Observation

// MARK: - Backend Setup Flow

struct BackendSetupFlow: View {

    // MARK: - Environment Objects

    @Environment(NetworkManager.self) var networkManager

    // MARK: - State Properties

    @State private var validator = ConfigurationValidator()
    @State private var currentStep: SetupStep = .welcome
    @State private var configuration = BackendConfigBuilder()
    @State private var isCompleting = false
    @State private var setupComplete = false
    @State private var selectedTab: String = "local" // Track selected tab explicitly

    // MARK: - Setup Steps

    enum SetupStep: Int, CaseIterable {
        case welcome = 0
        case hostConfiguration = 1
        case connectionTest = 2
        case completion = 3

        var title: String {
            switch self {
            case .welcome:
                return "Welcome to Claude Code"
            case .hostConfiguration:
                return "Backend Configuration"
            case .connectionTest:
                return "Connection Test"
            case .completion:
                return "Setup Complete"
            }
        }

        var subtitle: String {
            switch self {
            case .welcome:
                return "Let's set up your backend connection"
            case .hostConfiguration:
                return "Configure your Claude Code backend server"
            case .connectionTest:
                return "Testing your connection"
            case .completion:
                return "You're ready to start chatting!"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                // Content
                VStack(spacing: 0) {
                    // Progress indicator
                    setupProgressView

                    // Step content
                    currentStepView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Navigation buttons
                    setupNavigationView
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                validator.clearValidation()
                // Start with Local Development selected by default
                selectedTab = "local"
                configuration.applyLocalDevelopment()
            }
        }
    }

    // MARK: - Progress View

    private var setupProgressView: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "laptopcomputer.and.iphone")
                    .font(.largeTitle)
                    .foregroundColor(.blue)

                Spacer()

                Text("Step \(currentStep.rawValue + 1) of \(SetupStep.allCases.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Progress bar
            HStack(spacing: 8) {
                ForEach(SetupStep.allCases, id: \.rawValue) { step in
                    RoundedRectangle(cornerRadius: 2)
                        .frame(height: 4)
                        .glassEffect(.clear.tint((step.rawValue <= currentStep.rawValue ? Color.blue : Color.gray).opacity(0.6)), in: RoundedRectangle(cornerRadius: 2))
                }
            }

            VStack(spacing: 4) {
                Text(currentStep.title)
                    .font(.title2)
                    .fontWeight(.bold)

                Text(currentStep.subtitle)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

    // MARK: - Current Step View

    @ViewBuilder
    private var currentStepView: some View {
        switch currentStep {
        case .welcome:
            welcomeStepView
        case .hostConfiguration:
            hostConfigurationStepView
        case .connectionTest:
            connectionTestStepView
        case .completion:
            completionStepView
        }
    }

    // MARK: - Welcome Step

    private var welcomeStepView: some View {
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

    private var hostConfigurationStepView: some View {
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

    private var quickSetupSection: some View {
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

    private var customConfigurationSection: some View {
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

    private var validationSummarySection: some View {
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

    private var connectionTestStepView: some View {
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

    private var completionStepView: some View {
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

    // MARK: - Navigation View

    private var setupNavigationView: some View {
        HStack(spacing: 16) {
            // Back button
            if currentStep != .welcome {
                Button(action: goToPreviousStep) {
                    Label("Back", systemImage: "chevron.left")
                        .font(.body)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            } else {
                Spacer()
            }

            Spacer()

            // Next/Complete button
            Button(action: nextStepAction) {
                Label(nextButtonTitle, systemImage: nextButtonIcon)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(nextButtonEnabled ? Color.blue : Color.gray)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!nextButtonEnabled || isCompleting)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Navigation Properties

    private var nextButtonTitle: String {
        switch currentStep {
        case .welcome:
            return "Get Started"
        case .hostConfiguration:
            return "Continue"
        case .connectionTest:
            return "Complete Setup"
        case .completion:
            return "Start Chatting"
        }
    }

    private var nextButtonIcon: String {
        switch currentStep {
        case .completion:
            return "message.fill"
        default:
            return "chevron.right"
        }
    }

    private var nextButtonEnabled: Bool {
        switch currentStep {
        case .welcome:
            return true
        case .hostConfiguration:
            return validator.validationResults.isValid
        case .connectionTest:
            return validator.lastHealthCheckResult?.isHealthy == true
        case .completion:
            return true
        }
    }

    // MARK: - Actions

    private func nextStepAction() {
        switch currentStep {
        case .welcome:
            goToNextStep()
        case .hostConfiguration:
            if validator.validationResults.isValid {
                goToNextStep()
            }
        case .connectionTest:
            if validator.lastHealthCheckResult?.isHealthy == true {
                goToNextStep()
            }
        case .completion:
            completeSetup()
        }
    }

    private func goToNextStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            if let nextStep = SetupStep(rawValue: currentStep.rawValue + 1) {
                currentStep = nextStep
                // Clear previous test results when entering connection test step
                if nextStep == .connectionTest {
                    validator.lastHealthCheckResult = nil
                }
            }
        }
    }

    private func goToPreviousStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            if let previousStep = SetupStep(rawValue: currentStep.rawValue - 1) {
                currentStep = previousStep
            }
        }
    }

    private func validateCurrentConfiguration() {
        let config = configuration.build()
        validator.validateConfiguration(config)
    }

    private func performConnectionTest() {
        let config = configuration.build()
        print("🔗 Starting connection test to: \(config.displayURL)")

        Task { @MainActor in
            // Clear previous result first
            validator.lastHealthCheckResult = nil

            // Perform the health check
            await validator.performHealthCheck(for: config)

            // Log the result for debugging
            if let result = validator.lastHealthCheckResult {
                print("✅ Health check completed: \(result.isHealthy ? "Success" : "Failed")")
                if let error = result.errorMessage {
                    print("❌ Error: \(error)")
                }
            } else {
                print("⚠️ No health check result received")
            }
        }
    }

    private func completeSetup() {
        isCompleting = true

        Task {
            let config = configuration.build()

            // Save configuration to UserDefaults
            if let configData = try? JSONEncoder().encode(config) {
                UserDefaults.standard.set(configData, forKey: "BackendConfiguration")
                UserDefaults.standard.set(true, forKey: "SetupCompleted")
            }

            // Update network manager
            await networkManager.updateConfiguration(config)

            await MainActor.run {
                isCompleting = false
                setupComplete = true

                // Post notification to trigger ContentView refresh
                NotificationCenter.default.post(name: .setupCompleted, object: nil)
            }
        }
    }
}

// MARK: - Configuration Builder

@Observable
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

// MARK: - Supporting Views

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct QuickSetupCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .blue)

                VStack(spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(isSelected ? .white : .primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? Color.blue : Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
    }
}

struct ConfigurationField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let validation: FieldValidation
    let icon: String
    let keyboardType: UIKeyboardType
    let onEditingChanged: () -> Void

    init(
        title: String,
        placeholder: String,
        text: Binding<String>,
        validation: FieldValidation,
        icon: String,
        keyboardType: UIKeyboardType = .default,
        onEditingChanged: @escaping () -> Void
    ) {
        self.title = title
        self.placeholder = placeholder
        self._text = text
        self.validation = validation
        self.icon = icon
        self.keyboardType = keyboardType
        self.onEditingChanged = onEditingChanged
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .frame(width: 20)

                Text(title)
                    .font(.headline)
            }

            TextField(placeholder, text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(keyboardType)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .onChange(of: text) {
                    onEditingChanged()
                }

            if let error = validation.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            } else if let warning = validation.warningMessage {
                Text(warning)
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }
}

struct SchemeButton: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(isSelected ? .white : color)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(isSelected ? color : color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct ValidationStatusRow: View {
    let icon: String
    let message: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)

            Text(message)
                .font(.body)
                .foregroundColor(.primary)

            Spacer()
        }
    }
}

struct ConfigSummaryRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.body)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Setup Detection

extension BackendSetupFlow {
    static func isSetupRequired() -> Bool {
        return !UserDefaults.standard.bool(forKey: "SetupCompleted")
    }

    static func getSavedConfiguration() -> BackendConfig? {
        guard let configData = UserDefaults.standard.data(forKey: "BackendConfiguration"),
              let config = try? JSONDecoder().decode(BackendConfig.self, from: configData) else {
            return nil
        }
        return config
    }
}

// MARK: - Preview

#Preview {
    BackendSetupFlow()
        .environment(NetworkManager())
}
