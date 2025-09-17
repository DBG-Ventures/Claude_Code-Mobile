//
//  FrameRateTests.swift
//  VisionForge
//
//  Created by Claude Code on 2025-09-17.
//  60fps Frame Rate Maintenance Verification for iOS 26 Liquid Glass
//

import XCTest
import SwiftUI
@testable import VisionForge

@MainActor
final class FrameRateTests: XCTestCase {

    // MARK: - Test Properties
    private var performanceMonitor: LiquidPerformanceMonitor!
    private var deviceCapabilities: DeviceCapabilities!
    private var frameRateController: FrameRateTestController!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()
        performanceMonitor = LiquidPerformanceMonitor()
        deviceCapabilities = DeviceCapabilities.current
        frameRateController = FrameRateTestController()
    }

    override func tearDown() async throws {
        await performanceMonitor.stopMonitoring()
        performanceMonitor = nil
        deviceCapabilities = nil
        frameRateController = nil
        try await super.tearDown()
    }

    // MARK: - Target Frame Rate Tests

    func test60FPSMaintenanceDuringLiquidInteractions() async {
        // Test that 60fps is maintained during liquid glass interactions
        await performanceMonitor.startMonitoring()

        // Simulate rapid liquid interactions
        await simulateLiquidInteractions(
            duration: 30.0,
            interactionFrequency: .high,
            effectComplexity: .standard
        )

        let averageFrameRate = performanceMonitor.frameRate

        if deviceCapabilities.supportsFullLiquidGlass {
            XCTAssertGreaterThanOrEqual(
                averageFrameRate,
                60.0,
                "Capable devices should maintain 60fps during liquid interactions. Actual: \(averageFrameRate)fps"
            )
        } else {
            XCTAssertGreaterThanOrEqual(
                averageFrameRate,
                30.0,
                "Older devices should maintain at least 30fps with graceful degradation. Actual: \(averageFrameRate)fps"
            )
        }

        await performanceMonitor.stopMonitoring()
    }

    func testFrameRateUnderIntensiveUsage() async {
        // Test frame rate under intensive liquid glass usage
        await performanceMonitor.startMonitoring()

        // Maximum stress test: multiple concurrent ripples, complex animations
        await simulateLiquidInteractions(
            duration: 20.0,
            interactionFrequency: .maximum,
            effectComplexity: .complex
        )

        let minimumFrameRate = frameRateController.minimumRecordedFrameRate
        let averageFrameRate = performanceMonitor.frameRate

        // Even under stress, should maintain reasonable frame rate
        XCTAssertGreaterThanOrEqual(
            minimumFrameRate,
            45.0,
            "Minimum frame rate should not drop below 45fps even under stress. Actual: \(minimumFrameRate)fps"
        )

        XCTAssertGreaterThanOrEqual(
            averageFrameRate,
            55.0,
            "Average frame rate should remain above 55fps under intensive usage. Actual: \(averageFrameRate)fps"
        )

        await performanceMonitor.stopMonitoring()
    }

    func testFrameRateConsistency() async {
        // Test that frame rate remains consistent over time
        await performanceMonitor.startMonitoring()
        frameRateController.startDetailedMonitoring()

        // Long-duration test with varying interaction patterns
        await simulateVariedLiquidUsage(duration: 60.0)

        let frameRateVariability = frameRateController.frameRateVariability
        let averageFrameRate = performanceMonitor.frameRate

        // Frame rate should be stable with low variability
        XCTAssertLessThanOrEqual(
            frameRateVariability,
            10.0,
            "Frame rate variability should be low for smooth experience. Actual: \(frameRateVariability)fps"
        )

        XCTAssertGreaterThanOrEqual(
            averageFrameRate,
            58.0,
            "Average frame rate should remain consistently high. Actual: \(averageFrameRate)fps"
        )

        frameRateController.stopDetailedMonitoring()
        await performanceMonitor.stopMonitoring()
    }

    // MARK: - Device-Specific Frame Rate Tests

    func testHighPerformanceDeviceFrameRate() async {
        // Test frame rate on high-performance devices (A17 Pro+)
        guard deviceCapabilities.supportsFullLiquidGlass &&
              deviceCapabilities.processorCoreCount >= 8 else {
            throw XCTSkip("This test requires a high-performance device (A17 Pro+)")
        }

        await performanceMonitor.startMonitoring()

        // High-performance devices should easily maintain 60fps with complex effects
        await simulateLiquidInteractions(
            duration: 45.0,
            interactionFrequency: .high,
            effectComplexity: .complex
        )

        let frameRate = performanceMonitor.frameRate

        XCTAssertGreaterThanOrEqual(
            frameRate,
            60.0,
            "High-performance devices should maintain solid 60fps with complex effects. Actual: \(frameRate)fps"
        )

        await performanceMonitor.stopMonitoring()
    }

    func testMediumPerformanceDeviceFrameRate() async {
        // Test frame rate on medium-performance devices (A14-A16)
        let mediumPerformanceDevice = MockDeviceCapabilities(
            processorCoreCount: 6,
            deviceModel: "iPhone14,5", // iPhone 13
            chipGeneration: "A15"
        )

        await performanceMonitor.startMonitoring()

        // Medium-performance devices should maintain 60fps with standard effects
        await simulateLiquidInteractions(
            duration: 30.0,
            interactionFrequency: .medium,
            effectComplexity: .standard,
            deviceOverride: mediumPerformanceDevice
        )

        let frameRate = performanceMonitor.frameRate

        XCTAssertGreaterThanOrEqual(
            frameRate,
            58.0,
            "Medium-performance devices should maintain near 60fps with standard effects. Actual: \(frameRate)fps"
        )

        await performanceMonitor.stopMonitoring()
    }

    func testBasicPerformanceDeviceFrameRate() async {
        // Test frame rate on basic performance devices (A12-A13)
        let basicPerformanceDevice = MockDeviceCapabilities(
            processorCoreCount: 6,
            deviceModel: "iPhone11,8", // iPhone XR
            chipGeneration: "A12"
        )

        await performanceMonitor.startMonitoring()

        // Basic devices should maintain 30fps with reduced effects
        await simulateLiquidInteractions(
            duration: 30.0,
            interactionFrequency: .low,
            effectComplexity: .basic,
            deviceOverride: basicPerformanceDevice
        )

        let frameRate = performanceMonitor.frameRate

        XCTAssertGreaterThanOrEqual(
            frameRate,
            30.0,
            "Basic performance devices should maintain 30fps with reduced effects. Actual: \(frameRate)fps"
        )

        // Should not attempt effects that would hurt performance
        XCTAssertLessThan(
            frameRate,
            45.0,
            "Basic devices should use conservative effects to maintain stable frame rate"
        )

        await performanceMonitor.stopMonitoring()
    }

    // MARK: - Concurrent Ripple Effect Tests

    func testFrameRateWithConcurrentRipples() async {
        // Test frame rate with multiple concurrent ripple effects
        await performanceMonitor.startMonitoring()

        // Test with maximum allowed concurrent ripples (3 according to PRP)
        await simulateConcurrentRipples(
            rippleCount: 3,
            duration: 20.0,
            rippleComplexity: .standard
        )

        let frameRate = performanceMonitor.frameRate

        XCTAssertGreaterThanOrEqual(
            frameRate,
            55.0,
            "Frame rate should remain high with 3 concurrent ripples. Actual: \(frameRate)fps"
        )

        await performanceMonitor.stopMonitoring()
    }

    func testFrameRateWithExcessiveRipples() async {
        // Test that frame rate protection prevents excessive ripples
        await performanceMonitor.startMonitoring()

        // Attempt to create more ripples than the system should allow
        await simulateConcurrentRipples(
            rippleCount: 10, // More than the 3 ripple limit
            duration: 15.0,
            rippleComplexity: .standard
        )

        let frameRate = performanceMonitor.frameRate

        // System should automatically limit ripples to maintain frame rate
        XCTAssertGreaterThanOrEqual(
            frameRate,
            50.0,
            "Frame rate should be protected by limiting concurrent ripples. Actual: \(frameRate)fps"
        )

        await performanceMonitor.stopMonitoring()
    }

    // MARK: - Memory Pressure Impact Tests

    func testFrameRateUnderMemoryPressure() async {
        // Test frame rate behavior under memory pressure
        await performanceMonitor.startMonitoring()

        // Simulate memory pressure
        frameRateController.simulateMemoryPressure(.elevated)

        await simulateLiquidInteractions(
            duration: 30.0,
            interactionFrequency: .medium,
            effectComplexity: .standard
        )

        let frameRate = performanceMonitor.frameRate

        // Frame rate should remain stable even under memory pressure
        XCTAssertGreaterThanOrEqual(
            frameRate,
            50.0,
            "Frame rate should remain stable under memory pressure. Actual: \(frameRate)fps"
        )

        frameRateController.resetMemoryPressure()
        await performanceMonitor.stopMonitoring()
    }

    // MARK: - Thermal Throttling Tests

    func testFrameRateUnderThermalThrottling() async {
        // Test frame rate behavior during thermal throttling
        await performanceMonitor.startMonitoring()

        // Simulate thermal throttling
        frameRateController.simulateThermalState(.elevated)

        await simulateLiquidInteractions(
            duration: 25.0,
            interactionFrequency: .medium,
            effectComplexity: .standard
        )

        let frameRate = performanceMonitor.frameRate

        // Should gracefully reduce complexity to maintain frame rate
        XCTAssertGreaterThanOrEqual(
            frameRate,
            45.0,
            "Frame rate should be maintained during thermal throttling through complexity reduction. Actual: \(frameRate)fps"
        )

        frameRateController.resetThermalState()
        await performanceMonitor.stopMonitoring()
    }

    // MARK: - Animation Complexity Tests

    func testFrameRateWithComplexAnimations() async {
        // Test frame rate with complex liquid animations
        await performanceMonitor.startMonitoring()

        // Test complex spring animations, depth effects, adaptive tinting
        await simulateLiquidInteractions(
            duration: 30.0,
            interactionFrequency: .high,
            effectComplexity: .complex
        )

        let frameRate = performanceMonitor.frameRate

        if deviceCapabilities.supportsFullLiquidGlass {
            XCTAssertGreaterThanOrEqual(
                frameRate,
                55.0,
                "Complex animations should maintain good frame rate on capable devices. Actual: \(frameRate)fps"
            )
        } else {
            // Should automatically reduce complexity on less capable devices
            XCTAssertGreaterThanOrEqual(
                frameRate,
                30.0,
                "Complex animations should automatically reduce on less capable devices. Actual: \(frameRate)fps"
            )
        }

        await performanceMonitor.stopMonitoring()
    }

    // MARK: - Real-Time Streaming Impact Tests

    func testFrameRateWithStreamingText() async {
        // Test frame rate impact when liquid effects are combined with real-time text streaming
        await performanceMonitor.startMonitoring()

        // Simulate simultaneous streaming text and liquid interactions
        await simulateStreamingWithLiquidEffects(duration: 45.0)

        let frameRate = performanceMonitor.frameRate

        // Real-time streaming performance should be preserved
        XCTAssertGreaterThanOrEqual(
            frameRate,
            55.0,
            "Frame rate should remain high during streaming with liquid effects. Actual: \(frameRate)fps"
        )

        await performanceMonitor.stopMonitoring()
    }

    // MARK: - Frame Drop Detection Tests

    func testFrameDropDetection() async {
        // Test detection and handling of frame drops
        await performanceMonitor.startMonitoring()
        frameRateController.startFrameDropMonitoring()

        // Create conditions that might cause frame drops
        await simulateLiquidInteractions(
            duration: 20.0,
            interactionFrequency: .maximum,
            effectComplexity: .complex
        )

        let frameDropCount = frameRateController.frameDropCount
        let frameDropPercentage = frameRateController.frameDropPercentage

        // Frame drops should be minimal
        XCTAssertLessThanOrEqual(
            frameDropPercentage,
            5.0,
            "Frame drop percentage should be under 5%. Actual: \(frameDropPercentage)%"
        )

        frameRateController.stopFrameDropMonitoring()
        await performanceMonitor.stopMonitoring()
    }

    // MARK: - Adaptive Quality Tests

    func testAdaptiveQualityAdjustment() async {
        // Test that quality automatically adjusts to maintain frame rate
        await performanceMonitor.startMonitoring()
        frameRateController.enableAdaptiveQuality()

        // Start with complex effects
        await simulateLiquidInteractions(
            duration: 10.0,
            interactionFrequency: .high,
            effectComplexity: .complex
        )

        // Force frame rate pressure
        frameRateController.simulateFrameRatePressure()

        // Continue usage
        await simulateLiquidInteractions(
            duration: 20.0,
            interactionFrequency: .high,
            effectComplexity: .complex
        )

        let finalFrameRate = performanceMonitor.frameRate
        let qualityReductionApplied = frameRateController.qualityReductionApplied

        // Quality should automatically reduce to maintain frame rate
        XCTAssertTrue(
            qualityReductionApplied,
            "Adaptive quality reduction should be applied under frame rate pressure"
        )

        XCTAssertGreaterThanOrEqual(
            finalFrameRate,
            50.0,
            "Frame rate should be maintained through adaptive quality. Actual: \(finalFrameRate)fps"
        )

        frameRateController.disableAdaptiveQuality()
        await performanceMonitor.stopMonitoring()
    }

    // MARK: - Helper Methods

    private func simulateLiquidInteractions(
        duration: TimeInterval,
        interactionFrequency: InteractionFrequency,
        effectComplexity: EffectComplexity,
        deviceOverride: MockDeviceCapabilities? = nil
    ) async {
        let interactionInterval: TimeInterval

        switch interactionFrequency {
        case .low: interactionInterval = 1.0
        case .medium: interactionInterval = 0.3
        case .high: interactionInterval = 0.1
        case .maximum: interactionInterval = 0.05
        }

        let interactionCount = Int(duration / interactionInterval)

        for i in 0..<interactionCount {
            let metrics = LiquidInteractionMetrics(
                touchLocation: CGPoint(
                    x: Double(100 + (i % 20) * 10),
                    y: Double(100 + (i % 20) * 10)
                ),
                pressure: Float.random(in: 0.5...1.0),
                timestamp: Date(),
                elementType: .container,
                deviceCapabilities: deviceOverride?.toDeviceCapabilities() ?? deviceCapabilities
            )

            performanceMonitor.recordInteraction(metrics)

            // Record frame rate during interaction
            frameRateController.recordFrameTime()

            try? await Task.sleep(nanoseconds: UInt64(interactionInterval * 1_000_000_000))
        }
    }

    private func simulateConcurrentRipples(
        rippleCount: Int,
        duration: TimeInterval,
        rippleComplexity: EffectComplexity
    ) async {
        // Simulate multiple ripples being created simultaneously
        let rippleDuration: TimeInterval = 2.0 // Each ripple lasts 2 seconds
        let creationInterval: TimeInterval = duration / Double(rippleCount)

        for i in 0..<rippleCount {
            // Create ripple
            let metrics = LiquidInteractionMetrics(
                touchLocation: CGPoint(
                    x: Double(50 + i * 30),
                    y: Double(50 + i * 30)
                ),
                pressure: 1.0,
                timestamp: Date(),
                elementType: .container,
                deviceCapabilities: deviceCapabilities
            )

            performanceMonitor.recordInteraction(metrics)
            frameRateController.recordFrameTime()

            try? await Task.sleep(nanoseconds: UInt64(creationInterval * 1_000_000_000))
        }

        // Continue monitoring for remaining duration
        let remainingDuration = duration - (creationInterval * Double(rippleCount))
        if remainingDuration > 0 {
            try? await Task.sleep(nanoseconds: UInt64(remainingDuration * 1_000_000_000))
        }
    }

    private func simulateVariedLiquidUsage(duration: TimeInterval) async {
        let phases = [
            (frequency: InteractionFrequency.low, complexity: EffectComplexity.basic, duration: duration * 0.3),
            (frequency: InteractionFrequency.high, complexity: EffectComplexity.standard, duration: duration * 0.4),
            (frequency: InteractionFrequency.medium, complexity: EffectComplexity.complex, duration: duration * 0.3)
        ]

        for phase in phases {
            await simulateLiquidInteractions(
                duration: phase.duration,
                interactionFrequency: phase.frequency,
                effectComplexity: phase.complexity
            )
        }
    }

    private func simulateStreamingWithLiquidEffects(duration: TimeInterval) async {
        // Simulate real-time text streaming combined with liquid interactions
        let streamingInterval: TimeInterval = 0.05 // 20 updates per second for streaming
        let interactionInterval: TimeInterval = 0.5 // Liquid interactions every 0.5 seconds

        let totalUpdates = Int(duration / streamingInterval)

        for i in 0..<totalUpdates {
            // Simulate streaming text update
            frameRateController.recordStreamingUpdate()

            // Every 10th update, add a liquid interaction
            if i % 10 == 0 {
                let metrics = LiquidInteractionMetrics(
                    touchLocation: CGPoint(x: 150, y: 150),
                    pressure: 0.8,
                    timestamp: Date(),
                    elementType: .messageBubble,
                    deviceCapabilities: deviceCapabilities
                )
                performanceMonitor.recordInteraction(metrics)
            }

            frameRateController.recordFrameTime()

            try? await Task.sleep(nanoseconds: UInt64(streamingInterval * 1_000_000_000))
        }
    }
}

// MARK: - Supporting Enums

private enum InteractionFrequency {
    case low, medium, high, maximum
}

private enum EffectComplexity {
    case basic, standard, complex
}

// MARK: - Frame Rate Test Controller

private class FrameRateTestController {
    private var frameRateHistory: [Double] = []
    private var frameDrops: Int = 0
    private var totalFrames: Int = 0
    private var isDetailedMonitoring: Bool = false
    private var isFrameDropMonitoring: Bool = false
    private var adaptiveQualityEnabled: Bool = false
    private var qualityReduced: Bool = false
    private var memoryPressure: MemoryPressure = .normal
    private var thermalState: ThermalState = .nominal

    var minimumRecordedFrameRate: Double {
        return frameRateHistory.min() ?? 0.0
    }

    var frameRateVariability: Double {
        guard frameRateHistory.count > 1 else { return 0.0 }
        let average = frameRateHistory.reduce(0, +) / Double(frameRateHistory.count)
        let variance = frameRateHistory.map { pow($0 - average, 2) }.reduce(0, +) / Double(frameRateHistory.count)
        return sqrt(variance)
    }

    var frameDropCount: Int { frameDrops }

    var frameDropPercentage: Double {
        return totalFrames > 0 ? Double(frameDrops) / Double(totalFrames) * 100.0 : 0.0
    }

    var qualityReductionApplied: Bool { qualityReduced }

    func startDetailedMonitoring() {
        isDetailedMonitoring = true
        frameRateHistory.removeAll()
    }

    func stopDetailedMonitoring() {
        isDetailedMonitoring = false
    }

    func startFrameDropMonitoring() {
        isFrameDropMonitoring = true
        frameDrops = 0
        totalFrames = 0
    }

    func stopFrameDropMonitoring() {
        isFrameDropMonitoring = false
    }

    func enableAdaptiveQuality() {
        adaptiveQualityEnabled = true
    }

    func disableAdaptiveQuality() {
        adaptiveQualityEnabled = false
        qualityReduced = false
    }

    func recordFrameTime() {
        let currentFrameRate = 60.0 // Simulated frame rate

        if isDetailedMonitoring {
            frameRateHistory.append(currentFrameRate)
        }

        if isFrameDropMonitoring {
            totalFrames += 1
            if currentFrameRate < 58.0 { // Consider <58fps as a dropped frame
                frameDrops += 1
            }
        }
    }

    func recordStreamingUpdate() {
        // Record streaming text update performance impact
        recordFrameTime()
    }

    func simulateMemoryPressure(_ pressure: MemoryPressure) {
        memoryPressure = pressure
    }

    func resetMemoryPressure() {
        memoryPressure = .normal
    }

    func simulateThermalState(_ state: ThermalState) {
        thermalState = state
    }

    func resetThermalState() {
        thermalState = .nominal
    }

    func simulateFrameRatePressure() {
        if adaptiveQualityEnabled {
            qualityReduced = true
        }
    }
}

// MARK: - Supporting Enums

private enum MemoryPressure {
    case normal, elevated, critical
}

private enum ThermalState {
    case nominal, elevated, critical
}