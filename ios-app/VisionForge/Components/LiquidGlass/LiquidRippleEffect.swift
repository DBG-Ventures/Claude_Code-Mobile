//
//  LiquidRippleEffect.swift
//  Touch-responsive ripple system with performance optimization.
//
//  Advanced liquid ripple system with concurrent ripple management (max 3 concurrent),
//  pressure sensitivity, accessibility compliance, and performance monitoring.
//

import SwiftUI
import Combine

// MARK: - Notification Extensions

extension Notification.Name {
    static let liquidRippleTrigger = Notification.Name("liquidRippleTrigger")
}

/// Advanced liquid ripple effect system for touch interactions
struct LiquidRippleEffect: View {

    // MARK: - Configuration

    let maxConcurrentRipples: Int
    let rippleLifetime: TimeInterval
    let baseRippleSize: CGFloat
    let pressureSensitivity: CGFloat

    // MARK: - State

    @State private var activeRipples: [AdvancedLiquidRipple] = []
    @State private var rippleIdCounter: Int = 0

    // MARK: - Dependencies

    @ObservedObject var accessibilityManager: AccessibilityManager
    @ObservedObject var performanceMonitor: LiquidPerformanceMonitor

    // MARK: - Initialization

    init(
        maxConcurrentRipples: Int = 3,
        rippleLifetime: TimeInterval = 2.0,
        baseRippleSize: CGFloat = 200,
        pressureSensitivity: CGFloat = 1.5,
        accessibilityManager: AccessibilityManager,
        performanceMonitor: LiquidPerformanceMonitor
    ) {
        self.maxConcurrentRipples = maxConcurrentRipples
        self.rippleLifetime = rippleLifetime
        self.baseRippleSize = baseRippleSize
        self.pressureSensitivity = pressureSensitivity
        self.accessibilityManager = accessibilityManager
        self.performanceMonitor = performanceMonitor
    }

    var body: some View {
        ZStack {
            ForEach(activeRipples) { ripple in
                AdvancedLiquidRippleView(
                    ripple: ripple,
                    accessibilityManager: accessibilityManager
                )
                .allowsHitTesting(false)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .liquidRippleTrigger)) { notification in
            if let userInfo = notification.userInfo,
               let location = userInfo["location"] as? CGPoint,
               let pressure = userInfo["pressure"] as? Float {
                addRipple(at: location, pressure: pressure)
            }
        }
    }

    // MARK: - Public Interface

    /// Trigger a ripple at the specified location with pressure
    func addRipple(at location: CGPoint, pressure: Float = 1.0) {
        guard accessibilityManager.shouldEnableFeature(.rippleAnimations),
              performanceMonitor.liquidEffectsEnabled else {
            return
        }

        // Remove oldest ripples if at capacity
        if activeRipples.count >= maxConcurrentRipples {
            let oldestRipple = activeRipples.min(by: { $0.creationTime < $1.creationTime })
            if let oldest = oldestRipple {
                removeRipple(oldest)
            }
        }

        let ripple = AdvancedLiquidRipple(
            id: rippleIdCounter,
            center: location,
            pressure: pressure,
            baseSize: baseRippleSize,
            pressureSensitivity: pressureSensitivity,
            creationTime: Date(),
            lifetime: rippleLifetime
        )

        rippleIdCounter += 1
        activeRipples.append(ripple)

        // Schedule automatic removal
        DispatchQueue.main.asyncAfter(deadline: .now() + rippleLifetime) {
            removeRipple(ripple)
        }

        // Record performance metrics
        let metrics = LiquidInteractionMetrics(
            touchLocation: location,
            pressure: pressure,
            elementType: .rippleEffect,
            deviceCapabilities: DeviceCapabilities.current,
            duration: rippleLifetime
        )
        performanceMonitor.recordInteraction(metrics)
    }

    /// Remove all active ripples
    func clearAllRipples() {
        activeRipples.removeAll()
    }

    /// Get current ripple count for debugging
    func getCurrentRippleCount() -> Int {
        return activeRipples.count
    }

    // MARK: - Private Methods

    private func removeRipple(_ ripple: AdvancedLiquidRipple) {
        activeRipples.removeAll { $0.id == ripple.id }
    }
}

// MARK: - Advanced Liquid Ripple Model

struct AdvancedLiquidRipple: Identifiable {
    let id: Int
    let center: CGPoint
    let pressure: Float
    let baseSize: CGFloat
    let pressureSensitivity: CGFloat
    let creationTime: Date
    let lifetime: TimeInterval

    var maxSize: CGFloat {
        return baseSize * CGFloat(pressure) * pressureSensitivity
    }

    var pressureIntensity: Double {
        return Double(min(max(pressure, 0.1), 2.0)) // Clamp between 0.1 and 2.0
    }
}

// MARK: - Advanced Liquid Ripple View

struct AdvancedLiquidRippleView: View {
    let ripple: AdvancedLiquidRipple
    @ObservedObject var accessibilityManager: AccessibilityManager

    @State private var scale: CGFloat = 0.0
    @State private var opacity: Double = 1.0
    @State private var rotation: Angle = .zero
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Main ripple circle
            mainRippleCircle

            // Pressure enhancement ring
            if ripple.pressureIntensity > 1.0 && accessibilityManager.accessibilityEffectLevel == .full {
                pressureEnhancementRing
            }

            // Secondary ripple for depth
            if accessibilityManager.shouldEnableFeature(.depthLayers) {
                secondaryRipple
            }
        }
        .position(ripple.center)
        .onAppear {
            animateRipple()
        }
    }

    // MARK: - Ripple Components

    private var mainRippleCircle: some View {
        Circle()
            .stroke(
                LinearGradient(
                    colors: rippleColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: rippleLineWidth
            )
            .frame(width: ripple.baseSize, height: ripple.baseSize)
            .scaleEffect(scale)
            .opacity(opacity)
            .rotationEffect(rotation)
            .scaleEffect(pulseScale)
    }

    private var pressureEnhancementRing: some View {
        Circle()
            .stroke(
                RadialGradient(
                    colors: [
                        Color.white.opacity(0.4),
                        Color.blue.opacity(0.2),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: ripple.baseSize / 2
                ),
                lineWidth: 2
            )
            .frame(width: ripple.baseSize * 0.8, height: ripple.baseSize * 0.8)
            .scaleEffect(scale * 0.9)
            .opacity(opacity * 0.6)
    }

    private var secondaryRipple: some View {
        Circle()
            .stroke(
                Color.white.opacity(0.15),
                lineWidth: 1
            )
            .frame(width: ripple.baseSize * 1.2, height: ripple.baseSize * 1.2)
            .scaleEffect(scale * 1.1)
            .opacity(opacity * 0.4)
    }

    // MARK: - Computed Properties

    private var rippleColors: [Color] {
        let baseOpacity = accessibilityManager.getAccessibilityOpacity(baseOpacity: 0.6)

        switch accessibilityManager.accessibilityEffectLevel {
        case .full:
            return [
                Color.blue.opacity(baseOpacity),
                Color.cyan.opacity(baseOpacity * 0.8),
                Color.white.opacity(baseOpacity * 0.4),
                Color.clear
            ]
        case .reduced, .voiceOverOptimized:
            return [
                Color.primary.opacity(baseOpacity * 0.8),
                Color.primary.opacity(baseOpacity * 0.4),
                Color.clear
            ]
        case .minimal:
            return [
                Color.primary.opacity(baseOpacity * 0.5),
                Color.clear
            ]
        }
    }

    private var rippleLineWidth: CGFloat {
        let baseLine: CGFloat = 3.0
        let pressureMultiplier = CGFloat(ripple.pressureIntensity)

        switch accessibilityManager.accessibilityEffectLevel {
        case .full:
            return baseLine * pressureMultiplier
        case .reduced, .voiceOverOptimized:
            return baseLine * 0.8
        case .minimal:
            return baseLine * 0.5
        }
    }

    // MARK: - Animation

    private func animateRipple() {
        let targetScale = ripple.maxSize / ripple.baseSize
        let animationDuration = ripple.lifetime

        // Main expansion animation
        if let animation = accessibilityManager.getAnimation(.liquidRipple, for: scale) {
            withAnimation(animation.speed(1.0 / animationDuration)) {
                scale = targetScale
                opacity = 0.0
            }
        } else {
            // Instant for accessibility
            scale = targetScale
            opacity = 0.0
        }

        // Rotation animation for full effects
        if accessibilityManager.accessibilityEffectLevel == .full {
            if let rotationAnimation = accessibilityManager.getAnimation(.liquidFlow, for: rotation) {
                withAnimation(rotationAnimation.speed(0.5 / animationDuration)) {
                    rotation = .degrees(360 * ripple.pressureIntensity)
                }
            }
        }

        // Pulse animation for pressure feedback
        if ripple.pressureIntensity > 1.2 && accessibilityManager.shouldEnableFeature(.interactiveEffects) {
            if let pulseAnimation = accessibilityManager.getAnimation(.liquidBubble, for: pulseScale) {
                withAnimation(pulseAnimation.repeatCount(2, autoreverses: true)) {
                    pulseScale = 1.0 + CGFloat(ripple.pressureIntensity - 1.0) * 0.1
                }
            }
        }
    }
}

// MARK: - Static Ripple Trigger

extension LiquidRippleEffect {
    /// Static method to trigger ripples from anywhere in the app
    static func triggerRipple(at location: CGPoint, pressure: Float = 1.0) {
        NotificationCenter.default.post(
            name: .liquidRippleTrigger,
            object: nil,
            userInfo: [
                "location": location,
                "pressure": pressure
            ]
        )
    }
}


// MARK: - View Extension for Easy Integration

extension View {
    /// Add liquid ripple effect overlay to any view
    func liquidRippleOverlay(
        accessibilityManager: AccessibilityManager,
        performanceMonitor: LiquidPerformanceMonitor,
        maxRipples: Int = 3
    ) -> some View {
        self.overlay(
            LiquidRippleEffect(
                maxConcurrentRipples: maxRipples,
                accessibilityManager: accessibilityManager,
                performanceMonitor: performanceMonitor
            )
            .allowsHitTesting(false)
        )
    }

    /// Add touch-to-ripple gesture
    func onLiquidTouch(
        accessibilityManager: AccessibilityManager,
        performanceMonitor: LiquidPerformanceMonitor,
        pressure: Float = 1.0
    ) -> some View {
        self.onTapGesture { location in
            if accessibilityManager.shouldEnableFeature(.rippleAnimations) {
                LiquidRippleEffect.triggerRipple(at: location, pressure: pressure)
            }
        }
    }
}

// MARK: - Pressure Touch Detection (iOS 13+)

#if os(iOS)
struct PressureTouch: ViewModifier {
    let onPressureChange: (CGPoint, Float) -> Void
    @State private var pressureValue: Float = 0.0

    func body(content: Content) -> some View {
        content
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        // Simulate pressure based on velocity (actual force touch would use UITouch.force)
                        let velocity = sqrt(pow(value.velocity.width, 2) + pow(value.velocity.height, 2))
                        let pressure = min(Float(velocity / 1000.0), 2.0)
                        pressureValue = max(pressure, 0.1)
                        onPressureChange(value.location, pressureValue)
                    }
            )
    }
}

extension View {
    func onPressureTouch(_ action: @escaping (CGPoint, Float) -> Void) -> some View {
        modifier(PressureTouch(onPressureChange: action))
    }
}
#endif