//
//  LiquidGlassTypes.swift
//  Shared types and enums for iOS 26 Liquid Glass system.
//
//  Central location for all Liquid Glass-related types to prevent circular imports
//  and ensure consistent type definitions across the system.
//

import Foundation
import SwiftUI

// MARK: - Device Capabilities

/// Device capabilities for Liquid Glass feature enablement
struct DeviceCapabilities {
    let supportsFullLiquidGlass: Bool
    let supportsBasicLiquidGlass: Bool
    let supportsDepthEffects: Bool
    let supportsSpatialEffects: Bool
    let processorCoreCount: Int
    let deviceModel: String
    let recommendedEffectLevel: LiquidEffectLevel

}

// MARK: - Effect Levels

/// Liquid Glass effect levels for graceful degradation
enum LiquidEffectLevel: String, CaseIterable {
    case full = "full"           // iPhone 12+ with A14 Bionic or newer
    case reduced = "reduced"     // iPhone XR+ with A12 Bionic or newer
    case accessibility = "accessibility" // Solid backgrounds for motion sensitivity
    case disabled = "disabled"   // Fallback for unsupported devices

    var description: String {
        switch self {
        case .full:
            return "Full Liquid Glass with all effects"
        case .reduced:
            return "Basic Liquid Glass with reduced effects"
        case .accessibility:
            return "Accessibility mode with solid backgrounds"
        case .disabled:
            return "Liquid effects disabled"
        }
    }
}

// MARK: - Glass Effects

/// Glass effect types for iOS 26 Liquid Glass system
enum GlassEffect: String, CaseIterable {
    case regular = "regular"     // Standard glass effect
    case clear = "clear"         // Enhanced clarity for accessibility

    var description: String {
        switch self {
        case .regular:
            return "Regular glass effect"
        case .clear:
            return "Clear glass effect for accessibility"
        }
    }
}

// MARK: - Liquid Glass Features

/// Specific Liquid Glass features for capability checking
enum LiquidGlassFeature {
    case basicGlassEffect      // Basic .glassEffect() modifier
    case interactiveEffects    // Touch-responsive interactions
    case depthLayers          // .depthLayer() effects
    case spatialEffects       // Advanced 3D effects
    case rippleAnimations     // Touch ripple effects
}

// MARK: - iOS 26 API Types

/// Adaptive tint for liquid glass
enum AdaptiveTint {
    case system
}

/// Depth layer for liquid glass
enum DepthLayer {
    case background
    case content
}

// MARK: - Performance Types

/// Performance status for liquid effects
enum PerformanceStatus: String, CaseIterable {
    case optimal = "optimal"     // All metrics within targets
    case degraded = "degraded"   // Performance reduced but functional
    case warning = "warning"     // Approaching limits
    case disabled = "disabled"   // Effects disabled for performance

    var description: String {
        switch self {
        case .optimal:
            return "Optimal performance"
        case .degraded:
            return "Performance degraded"
        case .warning:
            return "Performance warning"
        case .disabled:
            return "Effects disabled"
        }
    }

    var color: Color {
        switch self {
        case .optimal:
            return .green
        case .degraded:
            return .yellow
        case .warning:
            return .orange
        case .disabled:
            return .red
        }
    }
}

/// Liquid element types for performance tracking
enum LiquidElementType: String, CaseIterable {
    case messageBubble = "messageBubble"
    case sessionRow = "sessionRow"
    case navigationButton = "navigationButton"
    case container = "container"
    case rippleEffect = "rippleEffect"

    var description: String {
        switch self {
        case .messageBubble:
            return "Message Bubble"
        case .sessionRow:
            return "Session Row"
        case .navigationButton:
            return "Navigation Button"
        case .container:
            return "Liquid Container"
        case .rippleEffect:
            return "Ripple Effect"
        }
    }
}

// MARK: - Interaction Types

/// Liquid interaction metrics for performance analysis
struct LiquidInteractionMetrics {
    let touchLocation: CGPoint
    let pressure: Float
    let timestamp: Date
    let elementType: LiquidElementType
    let deviceCapabilities: DeviceCapabilities
    let duration: TimeInterval?

    init(
        touchLocation: CGPoint,
        pressure: Float,
        timestamp: Date = Date(),
        elementType: LiquidElementType,
        deviceCapabilities: DeviceCapabilities,
        duration: TimeInterval? = nil
    ) {
        self.touchLocation = touchLocation
        self.pressure = pressure
        self.timestamp = timestamp
        self.elementType = elementType
        self.deviceCapabilities = deviceCapabilities
        self.duration = duration
    }
}

// MARK: - Performance Metrics

/// Comprehensive performance metrics for liquid effects
struct LiquidPerformanceMetrics {
    var batteryDrainRate: Double = 0.0
    var memoryUsage: Double = 0.0
    var gpuUtilization: Double = 0.0
    var currentFrameRate: Double = 60.0
    var interactionsPerSecond: Double = 0.0
    var totalInteractions: Int = 0

    var lastBatteryUpdate: Date = Date()
    var lastMemoryUpdate: Date = Date()
    var lastGPUUpdate: Date = Date()
    var lastFrameRateUpdate: Date = Date()

    var isDataCurrent: Bool {
        let now = Date()
        return now.timeIntervalSince(lastBatteryUpdate) < 10.0 &&
               now.timeIntervalSince(lastFrameRateUpdate) < 2.0
    }
}

// MARK: - Accessibility Types

/// Liquid accessibility styles for user preferences
enum LiquidAccessibilityStyle: String, CaseIterable {
    case full = "full"                   // Full liquid effects
    case reduced = "reduced"             // Reduced motion/transparency
    case solidBackgrounds = "solid"      // Solid backgrounds only
    case highContrast = "contrast"       // High contrast mode

    var description: String {
        switch self {
        case .full:
            return "Full liquid effects"
        case .reduced:
            return "Reduced effects"
        case .solidBackgrounds:
            return "Solid backgrounds"
        case .highContrast:
            return "High contrast"
        }
    }
}

// MARK: - Ripple Types

/// Individual liquid ripple for touch interactions
struct LiquidRipple: Identifiable {
    let id: UUID
    let center: CGPoint
    let pressure: Float
    let timestamp: Date
}