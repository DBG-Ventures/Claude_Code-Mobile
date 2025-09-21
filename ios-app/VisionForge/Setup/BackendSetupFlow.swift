//
//  BackendSetupFlow.swift
//  Main backend configuration setup flow coordinator.
//
//  Provides comprehensive onboarding experience for Claude Code mobile client backend setup
//  with step-by-step configuration, real-time validation, and connection testing.
//
//  Components split for better maintainability:
//  - BackendConfigBuilder: Configuration logic
//  - BackendSetupViews: Reusable UI components
//  - BackendSetupSteps: Step-specific views
//

import SwiftUI
import Combine
import Observation

// MARK: - Backend Setup Flow

struct BackendSetupFlow: View {

    // MARK: - Environment Objects

    @Environment(NetworkManager.self) var networkManager

    // MARK: - State Properties

    @State internal var validator = ConfigurationValidator()
    @State private var currentStep: SetupStep = .welcome
    @State internal var configuration = BackendConfigBuilder()
    @State private var isCompleting = false
    @State private var setupComplete = false
    @State internal var selectedTab: String = "local" // Track selected tab explicitly

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
                return "Let's get your mobile client connected"
            case .hostConfiguration:
                return "Configure your Claude Code server"
            case .connectionTest:
                return "Testing connection to your server"
            case .completion:
                return "Ready to start chatting!"
            }
        }
    }

    // MARK: - Main Body

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

    internal func validateCurrentConfiguration() {
        let config = configuration.build()
        validator.validateConfiguration(config)
    }

    internal func performConnectionTest() {
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