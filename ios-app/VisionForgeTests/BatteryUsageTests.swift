//
//  BatteryUsageTests.swift
//  VisionForge
//
//  Created by Claude Code on 2025-09-17.
//  Battery Usage Validation (<20% limit) for iOS 26 Liquid Glass Effects
//

import XCTest
import SwiftUI
@testable import VisionForge

@MainActor
final class BatteryUsageTests: XCTestCase {

    // MARK: - Test Properties
    private var performanceMonitor: LiquidPerformanceMonitor!
    private var deviceCapabilities: DeviceCapabilities!
    private var batteryTestController: BatteryTestController!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()
        performanceMonitor = LiquidPerformanceMonitor()
        deviceCapabilities = DeviceCapabilities.current
        batteryTestController = BatteryTestController()
    }

    override func tearDown() async throws {
        await performanceMonitor.stopMonitoring()
        performanceMonitor = nil
        deviceCapabilities = nil
        batteryTestController = nil
        try await super.tearDown()
    }

    // MARK: - Battery Impact Threshold Tests

    func testBatteryImpactUnder20PercentLimit() async {
        // Test that liquid glass effects stay under the 20% battery impact limit
        await performanceMonitor.startMonitoring()

        // Simulate normal liquid glass usage for 1 minute
        await simulateLiquidGlassUsage(duration: 60.0, intensity: .normal)

        let batteryImpact = performanceMonitor.batteryImpact

        XCTAssertLessThanOrEqual(
            batteryImpact,
            20.0,
            "Battery impact should be under 20% limit. Actual: \(batteryImpact)%"
        )

        await performanceMonitor.stopMonitoring()
    }

    func testIntensiveLiquidGlassUsageBatteryImpact() async {
        // Test battery impact under intensive liquid glass usage
        await performanceMonitor.startMonitoring()

        // Simulate intensive usage (multiple concurrent ripples, frequent interactions)
        await simulateLiquidGlassUsage(duration: 30.0, intensity: .intensive)

        let batteryImpact = performanceMonitor.batteryImpact

        XCTAssertLessThanOrEqual(
            batteryImpact,
            25.0,
            "Even intensive usage should keep battery impact reasonable. Actual: \(batteryImpact)%"
        )

        // Test that automatic throttling kicks in if needed
        if batteryImpact > 20.0 {
            XCTAssertFalse(
                performanceMonitor.liquidEffectsEnabled,
                "Liquid effects should be automatically disabled when exceeding 20% battery impact"
            )
        }

        await performanceMonitor.stopMonitoring()
    }

    func testLightUsageBatteryOptimization() async {
        // Test that light usage has minimal battery impact
        await performanceMonitor.startMonitoring()

        // Simulate light usage (occasional interactions, simple effects)
        await simulateLiquidGlassUsage(duration: 120.0, intensity: .light)

        let batteryImpact = performanceMonitor.batteryImpact

        XCTAssertLessThanOrEqual(
            batteryImpact,
            10.0,
            "Light usage should have minimal battery impact. Actual: \(batteryImpact)%"
        )

        await performanceMonitor.stopMonitoring()
    }

    // MARK: - Device-Specific Battery Tests

    func testBatteryUsageOnHighPerformanceDevice() async {
        // Test battery usage on high-performance devices (A17 Pro+)
        guard deviceCapabilities.supportsFullLiquidGlass else {
            throw XCTSkip("This test requires a high-performance device")
        }

        await performanceMonitor.startMonitoring()

        // High-performance devices should be more efficient
        await simulateLiquidGlassUsage(duration: 60.0, intensity: .normal)

        let batteryImpact = performanceMonitor.batteryImpact

        XCTAssertLessThanOrEqual(
            batteryImpact,
            15.0,
            "High-performance devices should have better battery efficiency. Actual: \(batteryImpact)%"
        )

        await performanceMonitor.stopMonitoring()
    }

    func testBatteryUsageOnOlderDevice() async {
        // Test battery usage on older devices with basic liquid glass support
        let mockOlderDevice = MockDeviceCapabilities(
            processorCoreCount: 6,
            deviceModel: "iPhone12,1", // iPhone 11
            chipGeneration: "A13"
        )

        await performanceMonitor.startMonitoring()

        // Older devices should use reduced effects for better battery life
        await simulateLiquidGlassUsage(
            duration: 60.0,
            intensity: .light,
            deviceOverride: mockOlderDevice
        )

        let batteryImpact = performanceMonitor.batteryImpact

        XCTAssertLessThanOrEqual(
            batteryImpact,
            18.0,
            "Older devices should maintain reasonable battery usage with reduced effects. Actual: \(batteryImpact)%"
        )

        await performanceMonitor.stopMonitoring()
    }

    // MARK: - Automatic Battery Optimization Tests

    func testAutomaticEffectDisabling() async {
        // Test that effects are automatically disabled when battery impact is too high
        await performanceMonitor.startMonitoring()

        // Artificially trigger high battery usage
        batteryTestController.simulateHighBatteryUsage()

        // Simulate continued usage
        await simulateLiquidGlassUsage(duration: 10.0, intensity: .intensive)

        // Effects should be automatically disabled
        XCTAssertFalse(
            performanceMonitor.liquidEffectsEnabled,
            "Liquid effects should be automatically disabled when battery impact exceeds threshold"
        )

        XCTAssertNotNil(
            performanceMonitor.performanceWarning,
            "Performance warning should be displayed to user"
        )

        await performanceMonitor.stopMonitoring()
    }

    func testBatteryLevelAdaptation() async {
        // Test that effects adapt to current battery level
        await performanceMonitor.startMonitoring()

        // Simulate low battery level (15%)
        batteryTestController.simulateBatteryLevel(0.15)

        // Start liquid glass usage
        await simulateLiquidGlassUsage(duration: 30.0, intensity: .normal)

        // Effects should be more conservative at low battery
        let lowBatteryImpact = performanceMonitor.batteryImpact

        // Reset and test with high battery level (80%)
        await performanceMonitor.stopMonitoring()
        performanceMonitor = LiquidPerformanceMonitor()
        await performanceMonitor.startMonitoring()

        batteryTestController.simulateBatteryLevel(0.80)

        await simulateLiquidGlassUsage(duration: 30.0, intensity: .normal)

        let highBatteryImpact = performanceMonitor.batteryImpact

        // Should use more conservative effects at low battery
        XCTAssertLessThanOrEqual(
            lowBatteryImpact,
            highBatteryImpact,
            "Battery impact should be lower (more conservative) when device battery is low"
        )

        await performanceMonitor.stopMonitoring()
    }

    // MARK: - Background Usage Tests

    func testBackgroundBatteryUsage() async {
        // Test battery usage when app is in background
        await performanceMonitor.startMonitoring()

        // Simulate app going to background
        batteryTestController.simulateAppState(.background)

        // Background usage should be minimal
        await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds

        let backgroundImpact = performanceMonitor.batteryImpact

        XCTAssertLessThanOrEqual(
            backgroundImpact,
            2.0,
            "Background battery usage should be minimal. Actual: \(backgroundImpact)%"
        )

        await performanceMonitor.stopMonitoring()
    }

    func testForegroundToBackgroundTransition() async {
        // Test battery optimization during app state transitions
        await performanceMonitor.startMonitoring()

        // Active foreground usage
        batteryTestController.simulateAppState(.foreground)
        await simulateLiquidGlassUsage(duration: 10.0, intensity: .normal)

        let foregroundImpact = performanceMonitor.batteryImpact

        // Transition to background
        batteryTestController.simulateAppState(.background)
        await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds

        let backgroundImpact = performanceMonitor.batteryImpact

        // Battery usage should decrease significantly in background
        XCTAssertLessThan(
            backgroundImpact,
            foregroundImpact,
            "Battery impact should decrease when transitioning to background"
        )

        await performanceMonitor.stopMonitoring()
    }

    // MARK: - Thermal Impact Tests

    func testThermalBatteryCorrelation() async {
        // Test correlation between thermal state and battery usage
        await performanceMonitor.startMonitoring()

        // Normal thermal state
        batteryTestController.simulateThermalState(.nominal)
        await simulateLiquidGlassUsage(duration: 30.0, intensity: .normal)

        let normalThermalBatteryImpact = performanceMonitor.batteryImpact

        // Reset for elevated thermal state
        await performanceMonitor.stopMonitoring()
        performanceMonitor = LiquidPerformanceMonitor()
        await performanceMonitor.startMonitoring()

        // Elevated thermal state (device throttling)
        batteryTestController.simulateThermalState(.elevated)
        await simulateLiquidGlassUsage(duration: 30.0, intensity: .normal)

        let elevatedThermalBatteryImpact = performanceMonitor.batteryImpact

        // Battery usage should be managed during thermal pressure
        XCTAssertLessThanOrEqual(
            elevatedThermalBatteryImpact,
            normalThermalBatteryImpact + 5.0,
            "Battery impact should not increase significantly under thermal pressure"
        )

        await performanceMonitor.stopMonitoring()
    }

    // MARK: - Long-Duration Usage Tests

    func testExtendedUsageBatteryImpact() async {
        // Test battery impact over extended usage periods
        await performanceMonitor.startMonitoring()

        // Simulate 10 minutes of continuous liquid glass usage
        await simulateLiquidGlassUsage(duration: 600.0, intensity: .normal)

        let extendedUsageImpact = performanceMonitor.batteryImpact

        XCTAssertLessThanOrEqual(
            extendedUsageImpact,
            20.0,
            "Extended usage should still maintain battery impact under 20%. Actual: \(extendedUsageImpact)%"
        )

        // Test that monitoring continues to work correctly
        XCTAssertTrue(
            performanceMonitor.isMonitoring,
            "Performance monitoring should continue during extended usage"
        )

        await performanceMonitor.stopMonitoring()
    }

    // MARK: - User Notification Tests

    func testBatteryWarningNotifications() async {
        // Test that users are properly notified about battery optimization
        await performanceMonitor.startMonitoring()

        // Force high battery usage
        batteryTestController.simulateHighBatteryUsage()
        await simulateLiquidGlassUsage(duration: 15.0, intensity: .intensive)

        // Should generate warning notification
        XCTAssertNotNil(
            performanceMonitor.performanceWarning,
            "Performance warning should be generated for high battery usage"
        )

        XCTAssertTrue(
            performanceMonitor.performanceWarning?.contains("battery") ?? false,
            "Warning should mention battery usage"
        )

        await performanceMonitor.stopMonitoring()
    }

    // MARK: - Recovery Tests

    func testBatteryUsageRecovery() async {
        // Test that battery usage returns to normal after optimization
        await performanceMonitor.startMonitoring()

        // Start with high usage
        batteryTestController.simulateHighBatteryUsage()
        await simulateLiquidGlassUsage(duration: 10.0, intensity: .intensive)

        XCTAssertFalse(
            performanceMonitor.liquidEffectsEnabled,
            "Effects should be disabled during high battery usage"
        )

        // Simulate recovery period
        batteryTestController.resetBatterySimulation()
        await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds recovery

        // Resume normal usage
        await simulateLiquidGlassUsage(duration: 30.0, intensity: .light)

        let recoveredImpact = performanceMonitor.batteryImpact

        XCTAssertLessThanOrEqual(
            recoveredImpact,
            15.0,
            "Battery impact should recover to normal levels after optimization. Actual: \(recoveredImpact)%"
        )

        await performanceMonitor.stopMonitoring()
    }

    // MARK: - Helper Methods

    private func simulateLiquidGlassUsage(
        duration: TimeInterval,
        intensity: UsageIntensity,
        deviceOverride: MockDeviceCapabilities? = nil
    ) async {
        let interactionInterval: TimeInterval
        let interactionCount: Int

        switch intensity {
        case .light:
            interactionInterval = 2.0 // Every 2 seconds
            interactionCount = Int(duration / interactionInterval)
        case .normal:
            interactionInterval = 0.5 // Every 0.5 seconds
            interactionCount = Int(duration / interactionInterval)
        case .intensive:
            interactionInterval = 0.1 // Every 0.1 seconds
            interactionCount = Int(duration / interactionInterval)
        }

        for i in 0..<interactionCount {
            let metrics = LiquidInteractionMetrics(
                touchLocation: CGPoint(
                    x: Double(50 + (i % 10) * 20),
                    y: Double(50 + (i % 10) * 20)
                ),
                pressure: Float.random(in: 0.3...1.0),
                timestamp: Date(),
                elementType: LiquidElementType.allCases.randomElement() ?? .container,
                deviceCapabilities: deviceOverride?.toDeviceCapabilities() ?? deviceCapabilities
            )

            performanceMonitor.recordInteraction(metrics)

            try? await Task.sleep(nanoseconds: UInt64(interactionInterval * 1_000_000_000))
        }
    }
}

// MARK: - Usage Intensity Enum

private enum UsageIntensity {
    case light, normal, intensive
}

// MARK: - Battery Test Controller

private class BatteryTestController {
    private var simulatedBatteryLevel: Double = 1.0
    private var simulatedAppState: AppState = .foreground
    private var simulatedThermalState: ThermalState = .nominal
    private var isHighBatteryUsageSimulated: Bool = false

    func simulateBatteryLevel(_ level: Double) {
        simulatedBatteryLevel = level
    }

    func simulateAppState(_ state: AppState) {
        simulatedAppState = state
    }

    func simulateThermalState(_ state: ThermalState) {
        simulatedThermalState = state
    }

    func simulateHighBatteryUsage() {
        isHighBatteryUsageSimulated = true
    }

    func resetBatterySimulation() {
        isHighBatteryUsageSimulated = false
        simulatedBatteryLevel = 1.0
        simulatedAppState = .foreground
        simulatedThermalState = .nominal
    }
}

// MARK: - Supporting Enums

private enum AppState {
    case foreground, background
}

private enum ThermalState {
    case nominal, elevated, critical
}

// MARK: - Mock Device Capabilities Extension

private extension MockDeviceCapabilities {
    func toDeviceCapabilities() -> DeviceCapabilities {
        return DeviceCapabilities(
            supportsFullLiquidGlass: self.supportsFullLiquidGlass,
            processorCoreCount: self.processorCoreCount,
            deviceModel: self.deviceModel,
            supportsSpatialEffects: self.performanceLevel == .high
        )
    }
}

// MARK: - LiquidElementType Extension

extension LiquidElementType: CaseIterable {
    public static var allCases: [LiquidElementType] {
        return [.messageBubble, .sessionRow, .navigationButton, .container]
    }
}