//
//  TestUtilities.swift
//  VisionForgeTests
//
//  Created by Claude Code on 2025-09-17.
//  Shared test utilities and mock classes for liquid glass testing
//

import Foundation
import XCTest
@testable import VisionForge

// MARK: - Mock Device Capabilities

class MockDeviceCapabilities {
    let processorCoreCount: Int
    let deviceModel: String
    let chipGeneration: String
    let memoryGB: Int
    private var thermalState: ThermalState = .nominal
    private var batteryLevel: Double = 1.0
    private var isPerformanceDegraded: Bool = false

    init(
        processorCoreCount: Int,
        deviceModel: String,
        chipGeneration: String,
        memoryGB: Int = 6
    ) {
        self.processorCoreCount = processorCoreCount
        self.deviceModel = deviceModel
        self.chipGeneration = chipGeneration
        self.memoryGB = memoryGB
    }

    var supportsFullLiquidGlass: Bool {
        return chipGeneration >= "A14" && !isPerformanceDegraded
    }

    var supportsBasicEffects: Bool {
        return chipGeneration >= "A12"
    }

    var supportsStaticInterface: Bool {
        return true
    }

    var performanceLevel: PerformanceLevel {
        if chipGeneration >= "A17" {
            return .high
        } else if chipGeneration >= "A14" {
            return .medium
        } else if chipGeneration >= "A12" {
            return .basic
        } else {
            return .none
        }
    }

    var liquidGlassSupport: LiquidGlassSupport {
        if chipGeneration >= "A17" && !isPerformanceDegraded {
            return .full
        } else if chipGeneration >= "A16" && !isPerformanceDegraded {
            return .enhanced
        } else if chipGeneration >= "A14" && !isPerformanceDegraded {
            return .standard
        } else if chipGeneration >= "A12" {
            return .basic
        } else {
            return .none
        }
    }

    // Feature support properties
    var supportsAdvancedRipples: Bool { chipGeneration >= "A17" }
    var supportsBasicRipples: Bool { chipGeneration >= "A12" }
    var supportsDepthEffects: Bool { chipGeneration >= "A15" }
    var supportsBasicDepthEffects: Bool { chipGeneration >= "A14" }
    var supportsAdaptiveTinting: Bool { chipGeneration >= "A16" }

    var maxConcurrentRipples: Int {
        switch chipGeneration {
        case let gen where gen >= "A17": return 5
        case let gen where gen >= "A14": return 3
        case let gen where gen >= "A12": return 1
        default: return 0
        }
    }

    // Memory constraint properties
    var supportsHighQualityEffects: Bool { memoryGB >= 8 }
    var supportsMediumQualityEffects: Bool { memoryGB >= 6 }

    // Thermal and battery properties
    var allowsHighPerformanceEffects: Bool {
        return thermalState != .critical && batteryLevel > 0.2
    }

    var allowsBasicEffects: Bool {
        return thermalState != .critical
    }

    var allowsFullLiquidEffects: Bool {
        return batteryLevel > 0.2 && thermalState == .nominal
    }

    var allowsEssentialEffectsOnly: Bool {
        return batteryLevel <= 0.2
    }

    // Simulation methods
    func simulateThermalPressure(_ state: ThermalState) {
        thermalState = state
    }

    func simulateBatteryLevel(_ level: Double) {
        batteryLevel = level
    }

    func simulatePerformanceDegradation() {
        isPerformanceDegraded = true
    }

    func toDeviceCapabilities() -> DeviceCapabilities {
        return DeviceCapabilities(
            supportsFullLiquidGlass: self.supportsFullLiquidGlass,
            processorCoreCount: self.processorCoreCount,
            deviceModel: self.deviceModel,
            supportsSpatialEffects: self.performanceLevel == .high
        )
    }
}

// MARK: - Enums

enum PerformanceLevel {
    case none, basic, medium, high
}

enum LiquidGlassSupport {
    case none, basic, standard, enhanced, full
}

enum ThermalState {
    case nominal, elevated, critical
}

// MARK: - String Comparison Extension

extension String {
    static func >= (lhs: String, rhs: String) -> Bool {
        let chipOrder = ["A11": 0, "A12": 1, "A13": 2, "A14": 3, "A15": 4, "A16": 5, "A17": 6, "A17 Pro": 7]
        let lhsOrder = chipOrder[lhs] ?? -1
        let rhsOrder = chipOrder[rhs] ?? -1
        return lhsOrder >= rhsOrder
    }
}

// MARK: - LiquidElementType Extension

extension LiquidElementType: CaseIterable {
    public static var allCases: [LiquidElementType] {
        return [.messageBubble, .sessionRow, .navigationButton, .container]
    }
}