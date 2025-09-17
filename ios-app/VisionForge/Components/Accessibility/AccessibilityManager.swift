//
//  AccessibilityManager.swift
//  Environment value monitoring for accessibility compliance.
//
//  Mandatory support for reduceTransparency, reduceMotion, Dynamic Type, and VoiceOver compatibility.
//  Critical for App Store compliance and inclusive design principles.
//

import SwiftUI
import Combine

/// Accessibility state management for Liquid Glass effects
@MainActor
class AccessibilityManager: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var reduceTransparency: Bool = false
    @Published private(set) var reduceMotion: Bool = false
    @Published private(set) var dynamicTypeSize: DynamicTypeSize = .large
    @Published private(set) var isVoiceOverRunning: Bool = false
    @Published private(set) var accessibilityEffectLevel: AccessibilityEffectLevel = .full

    // MARK: - Derived State

    @Published private(set) var shouldUseSolidBackgrounds: Bool = false
    @Published private(set) var shouldDisableAnimations: Bool = false
    @Published private(set) var shouldUseHighContrast: Bool = false
    @Published private(set) var recommendedLiquidStyle: LiquidStyle = .full

    // MARK: - Dependencies

    private let deviceCapabilities: DeviceCapabilities

    // MARK: - Cancellables

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(deviceCapabilities: DeviceCapabilities = DeviceCapabilities.current) {
        self.deviceCapabilities = deviceCapabilities

        setupAccessibilityObservers()
        updateDerivedState()

        print("♿ AccessibilityManager initialized:")
        print("   Reduce Transparency: \(reduceTransparency)")
        print("   Reduce Motion: \(reduceMotion)")
        print("   Dynamic Type: \(dynamicTypeSize)")
        print("   VoiceOver: \(isVoiceOverRunning)")
        print("   Recommended Style: \(recommendedLiquidStyle)")
    }

    // MARK: - Environment Integration

    /// Update accessibility settings from SwiftUI environment
    func updateFromEnvironment(
        reduceTransparency: Bool,
        reduceMotion: Bool,
        dynamicTypeSize: DynamicTypeSize
    ) {
        var didChange = false

        if self.reduceTransparency != reduceTransparency {
            self.reduceTransparency = reduceTransparency
            didChange = true
        }

        if self.reduceMotion != reduceMotion {
            self.reduceMotion = reduceMotion
            didChange = true
        }

        if self.dynamicTypeSize != dynamicTypeSize {
            self.dynamicTypeSize = dynamicTypeSize
            didChange = true
        }

        if didChange {
            updateDerivedState()
            logAccessibilityChange()
        }
    }

    // MARK: - Private Methods

    private func setupAccessibilityObservers() {
        // Monitor VoiceOver status changes
        NotificationCenter.default.publisher(for: UIAccessibility.voiceOverStatusDidChangeNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateVoiceOverStatus()
                }
            }
            .store(in: &cancellables)

        // Monitor other accessibility changes
        NotificationCenter.default.publisher(for: UIAccessibility.reduceTransparencyStatusDidChangeNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateAccessibilitySettings()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIAccessibility.reduceMotionStatusDidChangeNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateAccessibilitySettings()
                }
            }
            .store(in: &cancellables)

        // Initial update
        updateVoiceOverStatus()
        updateAccessibilitySettings()
    }

    private func updateVoiceOverStatus() {
        let newVoiceOverStatus = UIAccessibility.isVoiceOverRunning
        if isVoiceOverRunning != newVoiceOverStatus {
            isVoiceOverRunning = newVoiceOverStatus
            updateDerivedState()
            print("♿ VoiceOver status changed: \(isVoiceOverRunning)")
        }
    }

    private func updateAccessibilitySettings() {
        let newReduceTransparency = UIAccessibility.isReduceTransparencyEnabled
        let newReduceMotion = UIAccessibility.isReduceMotionEnabled

        var didChange = false

        if reduceTransparency != newReduceTransparency {
            reduceTransparency = newReduceTransparency
            didChange = true
        }

        if reduceMotion != newReduceMotion {
            reduceMotion = newReduceMotion
            didChange = true
        }

        if didChange {
            updateDerivedState()
            logAccessibilityChange()
        }
    }

    private func updateDerivedState() {
        // Solid backgrounds required when transparency is reduced
        shouldUseSolidBackgrounds = reduceTransparency

        // Animations disabled when motion is reduced
        shouldDisableAnimations = reduceMotion

        // High contrast for VoiceOver users
        shouldUseHighContrast = isVoiceOverRunning

        // Determine accessibility effect level
        accessibilityEffectLevel = determineAccessibilityEffectLevel()

        // Determine recommended liquid style
        recommendedLiquidStyle = determineRecommendedLiquidStyle()

        print("♿ Accessibility state updated:")
        print("   Solid Backgrounds: \(shouldUseSolidBackgrounds)")
        print("   Disable Animations: \(shouldDisableAnimations)")
        print("   High Contrast: \(shouldUseHighContrast)")
        print("   Effect Level: \(accessibilityEffectLevel)")
        print("   Liquid Style: \(recommendedLiquidStyle)")
    }

    private func determineAccessibilityEffectLevel() -> AccessibilityEffectLevel {
        if reduceTransparency && reduceMotion {
            return .minimal
        } else if reduceTransparency || reduceMotion {
            return .reduced
        } else if isVoiceOverRunning {
            return .voiceOverOptimized
        } else {
            return .full
        }
    }

    private func determineRecommendedLiquidStyle() -> LiquidStyle {
        // Priority: Accessibility first, then device capabilities

        if shouldUseSolidBackgrounds {
            return .accessibility
        }

        if shouldDisableAnimations {
            return .reduced
        }

        if isVoiceOverRunning {
            // VoiceOver users benefit from reduced visual complexity
            return .reduced
        }

        // Consider device capabilities
        if deviceCapabilities.supportsFullLiquidGlass {
            return .full
        } else if deviceCapabilities.supportsBasicLiquidGlass {
            return .reduced
        } else {
            return .accessibility
        }
    }

    private func logAccessibilityChange() {
        print("♿ Accessibility preferences changed:")
        print("   Reduce Transparency: \(reduceTransparency)")
        print("   Reduce Motion: \(reduceMotion)")
        print("   VoiceOver: \(isVoiceOverRunning)")
        print("   → Recommended Liquid Style: \(recommendedLiquidStyle)")
    }

    // MARK: - Public Interface

    /// Get the appropriate glass effect for current accessibility settings
    func getGlassEffect() -> GlassEffect {
        if shouldUseSolidBackgrounds {
            return .clear
        } else {
            return .regular
        }
    }

    /// Get animation configuration for current accessibility settings
    func getAnimation<T>(_ baseAnimation: Animation, for value: T) -> Animation? {
        return shouldDisableAnimations ? nil : baseAnimation
    }

    /// Check if specific Liquid Glass feature should be enabled
    func shouldEnableFeature(_ feature: LiquidGlassFeature) -> Bool {
        switch feature {
        case .basicGlassEffect:
            return !shouldUseSolidBackgrounds
        case .interactiveEffects:
            return !shouldDisableAnimations && !shouldUseSolidBackgrounds
        case .depthLayers:
            return accessibilityEffectLevel == .full && !shouldUseSolidBackgrounds
        case .spatialEffects:
            return accessibilityEffectLevel == .full && !isVoiceOverRunning
        case .rippleAnimations:
            return !shouldDisableAnimations && accessibilityEffectLevel != .minimal
        }
    }

    /// Get color opacity for accessibility compliance
    func getAccessibilityOpacity(baseOpacity: Double) -> Double {
        if shouldUseHighContrast {
            return min(baseOpacity * 1.2, 1.0) // Increase contrast for VoiceOver
        } else if shouldUseSolidBackgrounds {
            return 0.95 // Near-opaque for reduce transparency
        } else {
            return baseOpacity
        }
    }

    /// Get font size adjustment for Dynamic Type
    func getFontSizeMultiplier() -> CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small:
            return 0.9
        case .medium, .large:
            return 1.0
        case .xLarge, .xxLarge:
            return 1.1
        case .xxxLarge:
            return 1.2
        case .accessibility1, .accessibility2:
            return 1.3
        case .accessibility3, .accessibility4:
            return 1.4
        case .accessibility5:
            return 1.5
        @unknown default:
            return 1.0
        }
    }
}

// MARK: - Accessibility Effect Levels

enum AccessibilityEffectLevel: String, CaseIterable {
    case full = "full"                          // No accessibility restrictions
    case reduced = "reduced"                    // Reduced motion or transparency
    case voiceOverOptimized = "voiceOverOptimized" // Optimized for VoiceOver
    case minimal = "minimal"                    // Both motion and transparency reduced

    var description: String {
        switch self {
        case .full:
            return "Full effects with no accessibility restrictions"
        case .reduced:
            return "Reduced effects for accessibility compliance"
        case .voiceOverOptimized:
            return "Optimized for VoiceOver users"
        case .minimal:
            return "Minimal effects for maximum accessibility"
        }
    }
}

// MARK: - Liquid Style Enum

enum LiquidStyle: String, CaseIterable {
    case full = "full"                   // Full liquid glass effects
    case reduced = "reduced"             // Basic liquid effects only
    case accessibility = "accessibility" // Solid backgrounds, minimal effects

    var description: String {
        switch self {
        case .full:
            return "Full liquid glass with all effects"
        case .reduced:
            return "Reduced liquid effects for accessibility"
        case .accessibility:
            return "Accessibility mode with solid backgrounds"
        }
    }
}

