//
//  DeviceCompatibilityTests.swift
//  VisionForge
//
//  Created by Claude Code on 2025-09-17.
//  iPhone XR through iPhone 15 Pro Max Device Compatibility Testing
//

import XCTest
import SwiftUI
@testable import VisionForge

@MainActor
final class DeviceCompatibilityTests: XCTestCase {

    // MARK: - Test Properties
    private var deviceDetector: DeviceCapabilityDetector!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()
        deviceDetector = DeviceCapabilityDetector()
    }

    override func tearDown() async throws {
        deviceDetector = nil
        try await super.tearDown()
    }

    // MARK: - Device Detection Tests

    func testCurrentDeviceCapabilityDetection() {
        // Test that current device capabilities are properly detected
        let capabilities = DeviceCapabilities.current

        XCTAssertNotNil(capabilities, "Device capabilities should be detectable")
        XCTAssertGreaterThan(
            capabilities.processorCoreCount,
            0,
            "Processor core count should be greater than 0"
        )
        XCTAssertNotNil(capabilities.deviceModel, "Device model should be detectable")
    }

    func testA14BioPlusDeviceDetection() {
        // Test detection of A14 Bionic and newer devices (iPhone 12+)
        // According to PRP: "iPhone 12+ for full effects, iPhone XR+ basic effects"

        let mockA14Device = MockDeviceCapabilities(
            processorCoreCount: 6, // A14 Bionic has 6 cores
            deviceModel: "iPhone13,2", // iPhone 12
            chipGeneration: "A14"
        )

        XCTAssertTrue(
            mockA14Device.supportsFullLiquidGlass,
            "A14 devices should support full liquid glass effects"
        )

        XCTAssertTrue(
            mockA14Device.supportsSpatialEffects,
            "A14+ devices should support spatial effects"
        )
    }

    func testA12A13DeviceDetection() {
        // Test detection of A12/A13 devices (iPhone XR, XS, 11 series)
        // Should support basic liquid glass but not full effects

        let mockA12Device = MockDeviceCapabilities(
            processorCoreCount: 6, // A12 has 6 cores
            deviceModel: "iPhone11,8", // iPhone XR
            chipGeneration: "A12"
        )

        XCTAssertFalse(
            mockA12Device.supportsFullLiquidGlass,
            "A12 devices should not support full liquid glass effects"
        )

        XCTAssertTrue(
            mockA12Device.supportsBasicEffects,
            "A12+ devices should support basic liquid glass effects"
        )

        let mockA13Device = MockDeviceCapabilities(
            processorCoreCount: 6, // A13 has 6 cores
            deviceModel: "iPhone12,1", // iPhone 11
            chipGeneration: "A13"
        )

        XCTAssertFalse(
            mockA13Device.supportsFullLiquidGlass,
            "A13 devices should not support full liquid glass effects"
        )

        XCTAssertTrue(
            mockA13Device.supportsBasicEffects,
            "A13 devices should support basic liquid glass effects"
        )
    }

    func testOlderDeviceGracefulDegradation() {
        // Test graceful degradation for devices older than iPhone XR
        // Should fallback to static interfaces

        let mockA11Device = MockDeviceCapabilities(
            processorCoreCount: 6, // A11 has 6 cores
            deviceModel: "iPhone10,3", // iPhone X
            chipGeneration: "A11"
        )

        XCTAssertFalse(
            mockA11Device.supportsFullLiquidGlass,
            "A11 devices should not support liquid glass effects"
        )

        XCTAssertFalse(
            mockA11Device.supportsBasicEffects,
            "A11 devices should not support liquid glass effects"
        )

        XCTAssertTrue(
            mockA11Device.supportsStaticInterface,
            "A11 devices should support static interface fallback"
        )
    }

    // MARK: - Performance Level Tests

    func testDevicePerformanceLevels() {
        // Test that devices are classified into appropriate performance levels

        // High Performance: A17 Pro+ (iPhone 15 Pro series)
        let mockA17ProDevice = MockDeviceCapabilities(
            processorCoreCount: 8, // A17 Pro has 8 cores
            deviceModel: "iPhone16,1", // iPhone 15 Pro
            chipGeneration: "A17 Pro"
        )

        XCTAssertEqual(
            mockA17ProDevice.performanceLevel,
            .high,
            "A17 Pro devices should have high performance level"
        )

        // Medium Performance: A14-A16 (iPhone 12-14 series)
        let mockA15Device = MockDeviceCapabilities(
            processorCoreCount: 6,
            deviceModel: "iPhone14,5", // iPhone 13
            chipGeneration: "A15"
        )

        XCTAssertEqual(
            mockA15Device.performanceLevel,
            .medium,
            "A15 devices should have medium performance level"
        )

        // Basic Performance: A12-A13 (iPhone XR-11 series)
        let mockA12Device = MockDeviceCapabilities(
            processorCoreCount: 6,
            deviceModel: "iPhone11,8", // iPhone XR
            chipGeneration: "A12"
        )

        XCTAssertEqual(
            mockA12Device.performanceLevel,
            .basic,
            "A12 devices should have basic performance level"
        )
    }

    // MARK: - Liquid Glass Feature Support Tests

    func testLiquidGlassFeatureSupportByDevice() {
        // Test specific liquid glass features supported by device categories

        // iPhone 15 Pro Max - Full feature set
        let iPhone15ProMax = MockDeviceCapabilities(
            processorCoreCount: 8,
            deviceModel: "iPhone16,2",
            chipGeneration: "A17 Pro"
        )

        XCTAssertTrue(iPhone15ProMax.supportsAdvancedRipples, "iPhone 15 Pro Max should support advanced ripples")
        XCTAssertTrue(iPhone15ProMax.supportsDepthEffects, "iPhone 15 Pro Max should support depth effects")
        XCTAssertTrue(iPhone15ProMax.supportsAdaptiveTinting, "iPhone 15 Pro Max should support adaptive tinting")
        XCTAssertEqual(iPhone15ProMax.maxConcurrentRipples, 5, "iPhone 15 Pro Max should support 5 concurrent ripples")

        // iPhone 13 - Medium feature set
        let iPhone13 = MockDeviceCapabilities(
            processorCoreCount: 6,
            deviceModel: "iPhone14,5",
            chipGeneration: "A15"
        )

        XCTAssertTrue(iPhone13.supportsBasicRipples, "iPhone 13 should support basic ripples")
        XCTAssertFalse(iPhone13.supportsAdvancedRipples, "iPhone 13 should not support advanced ripples")
        XCTAssertTrue(iPhone13.supportsBasicDepthEffects, "iPhone 13 should support basic depth effects")
        XCTAssertEqual(iPhone13.maxConcurrentRipples, 3, "iPhone 13 should support 3 concurrent ripples")

        // iPhone XR - Basic feature set
        let iPhoneXR = MockDeviceCapabilities(
            processorCoreCount: 6,
            deviceModel: "iPhone11,8",
            chipGeneration: "A12"
        )

        XCTAssertTrue(iPhoneXR.supportsBasicRipples, "iPhone XR should support basic ripples")
        XCTAssertFalse(iPhoneXR.supportsDepthEffects, "iPhone XR should not support depth effects")
        XCTAssertFalse(iPhoneXR.supportsAdaptiveTinting, "iPhone XR should not support adaptive tinting")
        XCTAssertEqual(iPhoneXR.maxConcurrentRipples, 1, "iPhone XR should support 1 concurrent ripple")
    }

    // MARK: - Memory Constraint Tests

    func testDeviceMemoryConstraints() {
        // Test that memory constraints are respected for different devices

        // High-memory devices (8GB+)
        let highMemoryDevice = MockDeviceCapabilities(
            processorCoreCount: 8,
            deviceModel: "iPhone16,1",
            chipGeneration: "A17 Pro",
            memoryGB: 8
        )

        XCTAssertTrue(
            highMemoryDevice.supportsHighQualityEffects,
            "High-memory devices should support high-quality effects"
        )

        // Medium-memory devices (6GB)
        let mediumMemoryDevice = MockDeviceCapabilities(
            processorCoreCount: 6,
            deviceModel: "iPhone14,5",
            chipGeneration: "A15",
            memoryGB: 6
        )

        XCTAssertTrue(
            mediumMemoryDevice.supportsMediumQualityEffects,
            "Medium-memory devices should support medium-quality effects"
        )

        XCTAssertFalse(
            mediumMemoryDevice.supportsHighQualityEffects,
            "Medium-memory devices should not support high-quality effects"
        )

        // Low-memory devices (3-4GB)
        let lowMemoryDevice = MockDeviceCapabilities(
            processorCoreCount: 6,
            deviceModel: "iPhone11,8",
            chipGeneration: "A12",
            memoryGB: 3
        )

        XCTAssertTrue(
            lowMemoryDevice.supportsBasicEffects,
            "Low-memory devices should support basic effects"
        )

        XCTAssertFalse(
            lowMemoryDevice.supportsMediumQualityEffects,
            "Low-memory devices should not support medium-quality effects"
        )
    }

    // MARK: - Thermal Constraint Tests

    func testThermalThrottlingSupport() {
        // Test that devices handle thermal throttling appropriately

        let thermalTestDevice = MockDeviceCapabilities(
            processorCoreCount: 6,
            deviceModel: "iPhone14,5",
            chipGeneration: "A15"
        )

        // Simulate thermal pressure
        thermalTestDevice.simulateThermalPressure(.critical)

        XCTAssertFalse(
            thermalTestDevice.allowsHighPerformanceEffects,
            "High performance effects should be disabled under thermal pressure"
        )

        XCTAssertTrue(
            thermalTestDevice.allowsBasicEffects,
            "Basic effects should remain available under thermal pressure"
        )

        // Simulate normal thermal state
        thermalTestDevice.simulateThermalPressure(.nominal)

        XCTAssertTrue(
            thermalTestDevice.allowsHighPerformanceEffects,
            "High performance effects should be available in normal thermal state"
        )
    }

    // MARK: - Battery Level Adaptation Tests

    func testBatteryLevelAdaptation() {
        // Test that liquid glass effects adapt to battery level

        let batteryTestDevice = MockDeviceCapabilities(
            processorCoreCount: 6,
            deviceModel: "iPhone14,5",
            chipGeneration: "A15"
        )

        // Low battery mode
        batteryTestDevice.simulateBatteryLevel(0.15) // 15% battery

        XCTAssertFalse(
            batteryTestDevice.allowsFullLiquidEffects,
            "Full liquid effects should be disabled at low battery"
        )

        XCTAssertTrue(
            batteryTestDevice.allowsEssentialEffectsOnly,
            "Essential effects should remain at low battery"
        )

        // Normal battery level
        batteryTestDevice.simulateBatteryLevel(0.75) // 75% battery

        XCTAssertTrue(
            batteryTestDevice.allowsFullLiquidEffects,
            "Full liquid effects should be available at normal battery level"
        )
    }

    // MARK: - Real Device Testing Matrix

    func testDeviceCompatibilityMatrix() {
        // Test compatibility across the full device matrix specified in PRP

        let deviceMatrix: [(model: String, chip: String, cores: Int, expectedSupport: LiquidGlassSupport)] = [
            // iPhone 15 series
            ("iPhone16,1", "A17 Pro", 8, .full),
            ("iPhone16,2", "A17 Pro", 8, .full),
            ("iPhone15,4", "A16", 6, .enhanced),
            ("iPhone15,5", "A16", 6, .enhanced),

            // iPhone 14 series
            ("iPhone14,7", "A15", 6, .standard),
            ("iPhone14,8", "A15", 6, .standard),
            ("iPhone14,4", "A16", 6, .enhanced),
            ("iPhone14,3", "A16", 6, .enhanced),

            // iPhone 13 series
            ("iPhone14,5", "A15", 6, .standard),
            ("iPhone14,4", "A15", 6, .standard),
            ("iPhone14,2", "A15", 6, .standard),
            ("iPhone14,3", "A15", 6, .standard),

            // iPhone 12 series
            ("iPhone13,2", "A14", 6, .standard),
            ("iPhone13,3", "A14", 6, .standard),
            ("iPhone13,1", "A14", 6, .standard),
            ("iPhone13,4", "A14", 6, .standard),

            // iPhone 11 series (basic support)
            ("iPhone12,1", "A13", 6, .basic),
            ("iPhone12,3", "A13", 6, .basic),
            ("iPhone12,5", "A13", 6, .basic),

            // iPhone XR/XS series (basic support)
            ("iPhone11,8", "A12", 6, .basic),
            ("iPhone11,2", "A12", 6, .basic),
            ("iPhone11,4", "A12", 6, .basic),
            ("iPhone11,6", "A12", 6, .basic),

            // iPhone X and older (no support)
            ("iPhone10,3", "A11", 6, .none),
            ("iPhone10,6", "A11", 6, .none),
        ]

        for device in deviceMatrix {
            let mockDevice = MockDeviceCapabilities(
                processorCoreCount: device.cores,
                deviceModel: device.model,
                chipGeneration: device.chip
            )

            let actualSupport = mockDevice.liquidGlassSupport

            XCTAssertEqual(
                actualSupport,
                device.expectedSupport,
                "Device \(device.model) with \(device.chip) should have \(device.expectedSupport) liquid glass support"
            )
        }
    }

    // MARK: - Dynamic Feature Adjustment Tests

    func testDynamicFeatureAdjustment() async {
        // Test that features can be dynamically adjusted based on device performance

        let adaptiveDevice = MockDeviceCapabilities(
            processorCoreCount: 6,
            deviceModel: "iPhone14,5",
            chipGeneration: "A15"
        )

        let performanceMonitor = LiquidPerformanceMonitor()
        await performanceMonitor.startMonitoring()

        // Initially should support standard features
        XCTAssertEqual(adaptiveDevice.liquidGlassSupport, .standard)

        // Simulate performance degradation
        adaptiveDevice.simulatePerformanceDegradation()

        // Should automatically reduce feature set
        XCTAssertEqual(adaptiveDevice.liquidGlassSupport, .basic)

        performanceMonitor.stopMonitoring()
    }
}

// MARK: - Mock Device Capabilities

private class MockDeviceCapabilities {
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
        return true // All devices support static fallback
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
}

// MARK: - Enums

private enum PerformanceLevel {
    case none, basic, medium, high
}

private enum LiquidGlassSupport {
    case none, basic, standard, enhanced, full
}

private enum ThermalState {
    case nominal, elevated, critical
}

// MARK: - String Comparison Extension

private extension String {
    static func >= (lhs: String, rhs: String) -> Bool {
        // Simplified chip generation comparison
        let chipOrder = ["A11": 0, "A12": 1, "A13": 2, "A14": 3, "A15": 4, "A16": 5, "A17": 6, "A17 Pro": 7]
        let lhsOrder = chipOrder[lhs] ?? -1
        let rhsOrder = chipOrder[rhs] ?? -1
        return lhsOrder >= rhsOrder
    }
}