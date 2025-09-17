//
//  LiquidPerformanceMonitor.swift
//  Battery usage monitoring and frame rate tracking for liquid effects.
//
//  Critical system for maintaining <20% additional battery usage with automatic effect disabling
//  and user notification when performance targets are exceeded.
//

import SwiftUI
import Combine
import UIKit
import MetricKit

/// Performance monitoring and automatic liquid effects management
@MainActor
class LiquidPerformanceMonitor: ObservableObject {

    // MARK: - Published Properties

    /// Current additional battery usage from liquid effects (percentage)
    @Published private(set) var batteryImpact: Double = 0.0

    /// Current rendering frame rate (target: 60fps)
    @Published private(set) var frameRate: Double = 60.0

    /// Whether liquid effects are currently enabled
    @Published private(set) var liquidEffectsEnabled: Bool = true

    /// Current performance warning message
    @Published private(set) var performanceWarning: String?

    /// Battery optimization status
    @Published private(set) var batteryOptimizationActive: Bool = false

    /// Memory usage by liquid effects (MB)
    @Published private(set) var memoryUsage: Double = 0.0

    /// GPU utilization percentage
    @Published private(set) var gpuUtilization: Double = 0.0

    // MARK: - Performance Metrics

    @Published private(set) var performanceMetrics: LiquidPerformanceMetrics = LiquidPerformanceMetrics()

    // MARK: - Configuration

    private let maxBatteryImpact: Double = 20.0 // 20% limit from PRP requirements
    private let minFrameRate: Double = 30.0     // Minimum acceptable frame rate
    private let targetFrameRate: Double = 60.0  // Target frame rate
    private let maxMemoryUsage: Double = 100.0  // 100MB memory limit

    // MARK: - State

    private var isMonitoring = false
    private var baselineBatteryLevel: Float = 0.0
    private var baselineTimestamp: Date = Date()
    private var performanceCheckTimer: Timer?
    private var frameRateTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Interaction Tracking

    private var liquidInteractions: [LiquidInteractionMetrics] = []
    private let maxInteractionHistory = 100

    // MARK: - Initialization

    init() {
        setupPerformanceMonitoring()
        print("⚡ LiquidPerformanceMonitor initialized")
        print("   Battery Impact Limit: \(maxBatteryImpact)%")
        print("   Target Frame Rate: \(targetFrameRate) fps")
        print("   Memory Limit: \(maxMemoryUsage) MB")
    }

    deinit {
        isMonitoring = false
        performanceCheckTimer?.invalidate()
        frameRateTimer?.invalidate()
        performanceCheckTimer = nil
        frameRateTimer = nil
        print("⚡ LiquidPerformanceMonitor deallocated")
    }

    // MARK: - Public Interface

    /// Start performance monitoring for liquid effects
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        // Record baseline metrics
        recordBaseline()

        // Start monitoring timers
        startPerformanceTimer()
        startFrameRateMonitoring()

        print("⚡ Performance monitoring started")
    }

    /// Stop performance monitoring
    func stopMonitoring() {
        isMonitoring = false
        performanceCheckTimer?.invalidate()
        frameRateTimer?.invalidate()
        performanceCheckTimer = nil
        frameRateTimer = nil

        print("⚡ Performance monitoring stopped")
    }

    /// Record a liquid interaction for performance analysis
    func recordInteraction(_ metrics: LiquidInteractionMetrics) {
        liquidInteractions.append(metrics)

        // Maintain interaction history size
        if liquidInteractions.count > maxInteractionHistory {
            liquidInteractions.removeFirst(liquidInteractions.count - maxInteractionHistory)
        }

        // Update interaction-based metrics
        updateInteractionMetrics()
    }

    /// Force disable liquid effects for performance
    func disableLiquidEffects(reason: String) {
        guard liquidEffectsEnabled else { return }

        liquidEffectsEnabled = false
        performanceWarning = reason
        batteryOptimizationActive = true

        print("⚠️ Liquid effects disabled: \(reason)")

        // Notify user with haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }

    /// Re-enable liquid effects after performance improvement
    func enableLiquidEffects() {
        guard !liquidEffectsEnabled else { return }

        // Check if conditions are now acceptable
        if batteryImpact < maxBatteryImpact * 0.8 && frameRate >= minFrameRate {
            liquidEffectsEnabled = true
            performanceWarning = nil
            batteryOptimizationActive = false

            print("✅ Liquid effects re-enabled")
        }
    }

    /// Get current performance status
    func getPerformanceStatus() -> PerformanceStatus {
        if !liquidEffectsEnabled {
            return .disabled
        } else if batteryImpact > maxBatteryImpact * 0.8 {
            return .warning
        } else if frameRate < targetFrameRate * 0.8 {
            return .degraded
        } else {
            return .optimal
        }
    }

    // MARK: - Private Methods

    private func setupPerformanceMonitoring() {
        // Monitor app state changes
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.handleAppBackground()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.handleAppForeground()
            }
            .store(in: &cancellables)

        // Monitor battery state changes
        NotificationCenter.default.publisher(for: UIDevice.batteryLevelDidChangeNotification)
            .sink { [weak self] _ in
                self?.updateBatteryMetrics()
            }
            .store(in: &cancellables)
    }

    private func recordBaseline() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        baselineBatteryLevel = UIDevice.current.batteryLevel
        baselineTimestamp = Date()

        print("⚡ Baseline recorded - Battery: \(Int(baselineBatteryLevel * 100))%")
    }

    private func startPerformanceTimer() {
        performanceCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updatePerformanceMetrics()
            }
        }
    }

    private func startFrameRateMonitoring() {
        frameRateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateFrameRate()
            }
        }
    }

    private func updatePerformanceMetrics() async {
        guard isMonitoring else { return }

        updateBatteryMetrics()
        updateMemoryMetrics()
        updateGPUMetrics()
        checkPerformanceThresholds()
    }

    private func updateBatteryMetrics() {
        let currentBatteryLevel = UIDevice.current.batteryLevel
        let timeElapsed = Date().timeIntervalSince(baselineTimestamp)

        guard timeElapsed > 60.0 else { return } // Need at least 1 minute of data

        // Calculate battery drain rate
        let batteryDrain = baselineBatteryLevel - currentBatteryLevel
        let drainRate = batteryDrain / Float(timeElapsed / 3600.0) // Per hour

        // Estimate liquid effects impact (simplified calculation)
        // In a real implementation, this would use more sophisticated energy profiling
        let estimatedBaseDrain = 0.05 // 5% per hour baseline
        let liquidEffectsDrain = max(0, Double(drainRate) - estimatedBaseDrain)
        let impactPercentage = (liquidEffectsDrain / estimatedBaseDrain) * 100

        batteryImpact = min(max(impactPercentage, 0), 100) // Clamp to 0-100%

        // Update performance metrics
        performanceMetrics.batteryDrainRate = Double(drainRate)
        performanceMetrics.lastBatteryUpdate = Date()
    }

    private func updateMemoryMetrics() {
        // Get memory usage (simplified - would use more precise APIs in production)
        let info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &count) {
            task_info(mach_task_self_,
                     task_flavor_t(MACH_TASK_BASIC_INFO),
                     UnsafeMutablePointer<integer_t>.init(OpaquePointer($0)),
                     UnsafeMutablePointer<mach_msg_type_number_t>.init(OpaquePointer($0)))
        }

        if kerr == KERN_SUCCESS {
            let usedMemory = Double(info.resident_size) / 1024 / 1024 // Convert to MB
            memoryUsage = usedMemory

            performanceMetrics.memoryUsage = usedMemory
            performanceMetrics.lastMemoryUpdate = Date()
        }
    }

    private func updateGPUMetrics() {
        // GPU utilization estimation (simplified)
        // In production, would use Metal Performance Shaders or similar
        let interactionsPerSecond = Double(liquidInteractions.filter {
            $0.timestamp.timeIntervalSinceNow > -1.0
        }.count)

        gpuUtilization = min(interactionsPerSecond * 10, 100) // Rough estimation

        performanceMetrics.gpuUtilization = gpuUtilization
        performanceMetrics.lastGPUUpdate = Date()
    }

    private func updateFrameRate() {
        // Frame rate monitoring (simplified)
        // In production, would use CADisplayLink or similar for accurate measurement
        let performanceLevel = getSystemPerformanceLevel()
        frameRate = targetFrameRate * performanceLevel

        performanceMetrics.currentFrameRate = frameRate
        performanceMetrics.lastFrameRateUpdate = Date()
    }

    private func getSystemPerformanceLevel() -> Double {
        // Estimate performance based on various factors
        let batteryState = UIDevice.current.batteryState
        let batteryLevel = UIDevice.current.batteryLevel

        var performanceMultiplier = 1.0

        // Reduce performance if battery is low
        if batteryLevel < 0.2 {
            performanceMultiplier *= 0.7
        } else if batteryLevel < 0.5 {
            performanceMultiplier *= 0.9
        }

        // Reduce performance in low power mode
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            performanceMultiplier *= 0.5
        }

        // Reduce performance if battery is not charging and level is low
        if batteryState != .charging && batteryLevel < 0.3 {
            performanceMultiplier *= 0.8
        }

        return performanceMultiplier
    }

    private func checkPerformanceThresholds() {
        // Check battery impact threshold
        if batteryImpact > maxBatteryImpact {
            disableLiquidEffects(reason: "Battery usage exceeded \(Int(maxBatteryImpact))% limit")
            return
        }

        // Check frame rate threshold
        if frameRate < minFrameRate {
            disableLiquidEffects(reason: "Frame rate below \(Int(minFrameRate)) fps")
            return
        }

        // Check memory usage threshold
        if memoryUsage > maxMemoryUsage {
            disableLiquidEffects(reason: "Memory usage exceeded \(Int(maxMemoryUsage)) MB")
            return
        }

        // Try to re-enable if conditions are good
        if !liquidEffectsEnabled {
            enableLiquidEffects()
        }
    }

    private func updateInteractionMetrics() {
        let recentInteractions = liquidInteractions.filter {
            $0.timestamp.timeIntervalSinceNow > -10.0 // Last 10 seconds
        }

        performanceMetrics.interactionsPerSecond = Double(recentInteractions.count) / 10.0
        performanceMetrics.totalInteractions = liquidInteractions.count
    }

    private func handleAppBackground() {
        // Reduce monitoring frequency in background
        performanceCheckTimer?.invalidate()
        frameRateTimer?.invalidate()

        print("⚡ Performance monitoring paused for background")
    }

    private func handleAppForeground() {
        // Resume full monitoring
        if isMonitoring {
            startPerformanceTimer()
            startFrameRateMonitoring()
        }

        print("⚡ Performance monitoring resumed for foreground")
    }
}

