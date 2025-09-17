//
//  DeviceCapabilityDetector.swift
//  Hardware capability detection for iOS 26 Liquid Glass feature enablement.
//
//  Provides automatic device detection with graceful degradation from full → reduced → accessibility modes.
//  Optimized for A14+ (iPhone 12+) full effects with fallback for older devices.
//

import Foundation
import UIKit
import Combine


/// Device capability detection service
class DeviceCapabilityDetector: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var currentCapabilities: DeviceCapabilities
    @Published private(set) var effectLevel: LiquidEffectLevel
    @Published private(set) var deviceModel: String
    @Published private(set) var processorInfo: String

    // MARK: - Initialization

    init() {
        let capabilities = Self.detectCurrentDevice()
        self.currentCapabilities = capabilities
        self.effectLevel = capabilities.recommendedEffectLevel
        self.deviceModel = capabilities.deviceModel
        self.processorInfo = Self.getProcessorDescription()

        print("🔍 DeviceCapabilityDetector initialized:")
        print("   Device: \(deviceModel)")
        print("   Processor: \(processorInfo)")
        print("   Effect Level: \(effectLevel.description)")
        print("   Full Liquid Glass: \(currentCapabilities.supportsFullLiquidGlass)")
    }

    // MARK: - Static Detection Methods

    static func detectCurrentDevice() -> DeviceCapabilities {
        let processorCoreCount = ProcessInfo.processInfo.processorCount
        let deviceModel = getDeviceModel()

        // A14 Bionic and newer (iPhone 12+) support full Liquid Glass
        let supportsFullLiquidGlass = processorCoreCount >= 6 && isA14OrNewer()

        // A12 Bionic and newer (iPhone XR+) support basic Liquid Glass
        let supportsBasicLiquidGlass = processorCoreCount >= 6

        // A16 Bionic and newer support enhanced depth effects
        let supportsDepthEffects = processorCoreCount >= 6 && isA16OrNewer()

        // A17 Pro and newer support spatial effects
        let supportsSpatialEffects = processorCoreCount >= 8 && isA17ProOrNewer()

        let recommendedLevel = determineRecommendedEffectLevel(
            fullSupport: supportsFullLiquidGlass,
            basicSupport: supportsBasicLiquidGlass,
            coreCount: processorCoreCount
        )

        return DeviceCapabilities(
            supportsFullLiquidGlass: supportsFullLiquidGlass,
            supportsBasicLiquidGlass: supportsBasicLiquidGlass,
            supportsDepthEffects: supportsDepthEffects,
            supportsSpatialEffects: supportsSpatialEffects,
            processorCoreCount: processorCoreCount,
            deviceModel: deviceModel,
            recommendedEffectLevel: recommendedLevel
        )
    }

    // MARK: - Processor Detection

    static func isA14OrNewer() -> Bool {
        // A14 Bionic introduced in iPhone 12 series (2020)
        // Check for specific device identifiers and core count
        let deviceModel = getDeviceModel()

        // iPhone 12 and newer device identifiers
        let a14OrNewerDevices = [
            "iPhone13,1", "iPhone13,2", "iPhone13,3", "iPhone13,4",  // iPhone 12 series
            "iPhone14,2", "iPhone14,3", "iPhone14,4", "iPhone14,5",  // iPhone 13 series
            "iPhone14,6", "iPhone14,7", "iPhone14,8",                // iPhone 13 mini, iPhone SE 3rd gen
            "iPhone15,2", "iPhone15,3", "iPhone15,4", "iPhone15,5",  // iPhone 14 series
            "iPhone16,1", "iPhone16,2"                               // iPhone 15 series
        ]

        return a14OrNewerDevices.contains { deviceModel.hasPrefix($0) } ||
               ProcessInfo.processInfo.processorCount >= 6
    }

    static func isA16OrNewer() -> Bool {
        // A16 Bionic introduced in iPhone 14 Pro series (2022)
        let deviceModel = getDeviceModel()

        let a16OrNewerDevices = [
            "iPhone15,3", "iPhone15,4",  // iPhone 14 Pro series
            "iPhone16,1", "iPhone16,2"   // iPhone 15 series
        ]

        return a16OrNewerDevices.contains { deviceModel.hasPrefix($0) }
    }

    static func isA17ProOrNewer() -> Bool {
        // A17 Pro introduced in iPhone 15 Pro series (2023)
        let deviceModel = getDeviceModel()

        let a17ProOrNewerDevices = [
            "iPhone16,1", "iPhone16,2"   // iPhone 15 Pro series
        ]

        return a17ProOrNewerDevices.contains { deviceModel.hasPrefix($0) } &&
               ProcessInfo.processInfo.processorCount >= 8
    }


    // MARK: - Device Model Detection

    static func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            let scalar = UnicodeScalar(UInt8(value))
            return identifier + String(scalar)
        }
        return identifier
    }

    private static func getProcessorDescription() -> String {
        let coreCount = ProcessInfo.processInfo.processorCount

        switch coreCount {
        case 8...:
            return "A17 Pro or newer (\(coreCount) cores)"
        case 6..<8:
            return "A14-A16 (\(coreCount) cores)"
        case 4..<6:
            return "A12-A13 (\(coreCount) cores)"
        default:
            return "Older processor (\(coreCount) cores)"
        }
    }

    // MARK: - Effect Level Determination

    static func determineRecommendedEffectLevel(
        fullSupport: Bool,
        basicSupport: Bool,
        coreCount: Int
    ) -> LiquidEffectLevel {
        if fullSupport {
            return .full
        } else if basicSupport {
            return .reduced
        } else if coreCount >= 4 {
            return .accessibility
        } else {
            return .disabled
        }
    }

    // MARK: - Public Interface

    /// Check if device supports full Liquid Glass effects
    func supportsFullLiquidGlass() -> Bool {
        return currentCapabilities.supportsFullLiquidGlass
    }

    /// Check if device supports basic Liquid Glass effects
    func supportsBasicLiquidGlass() -> Bool {
        return currentCapabilities.supportsBasicLiquidGlass
    }

    /// Get recommended effect level for current device
    func getRecommendedEffectLevel() -> LiquidEffectLevel {
        return effectLevel
    }

    /// Override effect level for testing or user preference
    @MainActor
    func setEffectLevel(_ level: LiquidEffectLevel) {
        effectLevel = level
        print("🔧 DeviceCapabilityDetector: Effect level manually set to \(level.description)")
    }

    /// Check if current effect level supports specific features
    func supportsFeature(_ feature: LiquidGlassFeature) -> Bool {
        switch feature {
        case .basicGlassEffect:
            return effectLevel != .disabled
        case .interactiveEffects:
            return effectLevel == .full || effectLevel == .reduced
        case .depthLayers:
            return effectLevel == .full && currentCapabilities.supportsDepthEffects
        case .spatialEffects:
            return effectLevel == .full && currentCapabilities.supportsSpatialEffects
        case .rippleAnimations:
            return effectLevel == .full || effectLevel == .reduced
        }
    }
}

// MARK: - DeviceCapabilities Extension

extension DeviceCapabilities {
    static var current: DeviceCapabilities {
        // Create a synchronous version for immediate access
        let processorCoreCount = ProcessInfo.processInfo.processorCount
        let deviceModel = DeviceCapabilityDetector.getDeviceModel()

        let supportsFullLiquidGlass = processorCoreCount >= 6 && DeviceCapabilityDetector.isA14OrNewer()
        let supportsBasicLiquidGlass = processorCoreCount >= 6
        let supportsDepthEffects = processorCoreCount >= 6 && DeviceCapabilityDetector.isA16OrNewer()
        let supportsSpatialEffects = processorCoreCount >= 8 && DeviceCapabilityDetector.isA17ProOrNewer()

        let recommendedLevel = DeviceCapabilityDetector.determineRecommendedEffectLevel(
            fullSupport: supportsFullLiquidGlass,
            basicSupport: supportsBasicLiquidGlass,
            coreCount: processorCoreCount
        )

        return DeviceCapabilities(
            supportsFullLiquidGlass: supportsFullLiquidGlass,
            supportsBasicLiquidGlass: supportsBasicLiquidGlass,
            supportsDepthEffects: supportsDepthEffects,
            supportsSpatialEffects: supportsSpatialEffects,
            processorCoreCount: processorCoreCount,
            deviceModel: deviceModel,
            recommendedEffectLevel: recommendedLevel
        )
    }
}

