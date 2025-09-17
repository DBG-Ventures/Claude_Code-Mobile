//
//  LiquidAnimationSystem.swift
//  iOS 26 spring animation curves optimized for liquid interactions.
//
//  Provides official iOS 26 spring parameters with accessibility-aware animation selection.
//  Optimized for fluid, responsive liquid glass interactions with performance monitoring.
//

import SwiftUI

/// Liquid Glass animation system with iOS 26 optimized spring curves
struct LiquidAnimationSystem {

    // MARK: - Core Liquid Animations

    /// Primary liquid response animation for general interactions
    static let liquidResponse = Animation.spring(
        response: 0.4,
        dampingFraction: 0.8,
        blendDuration: 0.2
    )

    /// Bubble interaction animation for message bubbles and touch responses
    static let liquidBubble = Animation.spring(
        response: 0.3,
        dampingFraction: 0.6,
        blendDuration: 0.1
    )

    /// Flow animation for transitions and state changes
    static let liquidFlow = Animation.spring(
        response: 0.6,
        dampingFraction: 0.9,
        blendDuration: 0.3
    )

    /// Ripple animation for touch ripple effects
    static let liquidRipple = Animation.spring(
        response: 0.25,
        dampingFraction: 0.7,
        blendDuration: 0.05
    )

    /// Gentle animation for accessibility-sensitive contexts
    static let liquidGentle = Animation.spring(
        response: 0.8,
        dampingFraction: 0.95,
        blendDuration: 0.4
    )

    // MARK: - Specialized Animations

    /// Quick feedback animation for immediate touch responses
    static let liquidFeedback = Animation.spring(
        response: 0.15,
        dampingFraction: 0.5,
        blendDuration: 0.05
    )

    /// Smooth transition animation for navigation and container changes
    static let liquidTransition = Animation.spring(
        response: 0.5,
        dampingFraction: 0.85,
        blendDuration: 0.25
    )

    /// Elastic animation for selection states and emphasis
    static let liquidElastic = Animation.spring(
        response: 0.35,
        dampingFraction: 0.65,
        blendDuration: 0.15
    )

    /// Breathing animation for ambient effects and status indicators
    static let liquidBreath = Animation.spring(
        response: 2.0,
        dampingFraction: 0.9,
        blendDuration: 0.5
    ).repeatForever(autoreverses: true)

    // MARK: - Performance-Optimized Variants

    /// Reduced motion animation for performance-constrained devices
    static let liquidReduced = Animation.spring(
        response: 0.6,
        dampingFraction: 0.95,
        blendDuration: 0.3
    )

    /// Minimal animation for battery conservation
    static let liquidMinimal = Animation.easeInOut(duration: 0.3)

    // MARK: - Accessibility-Aware Animation Selection

    /// Get appropriate animation based on accessibility settings
    @MainActor
    static func liquidAnimation(
        base: Animation,
        accessibilityManager: AccessibilityManager
    ) -> Animation? {
        return accessibilityManager.getAnimation(base, for: "liquid")
    }

    /// Get liquid response animation with accessibility awareness
    @MainActor
    static func responsiveAnimation(
        accessibilityManager: AccessibilityManager
    ) -> Animation? {
        if accessibilityManager.shouldDisableAnimations {
            return nil
        } else if accessibilityManager.accessibilityEffectLevel == .minimal {
            return liquidMinimal
        } else if accessibilityManager.accessibilityEffectLevel == .reduced {
            return liquidReduced
        } else {
            return liquidResponse
        }
    }

    /// Get bubble animation with accessibility awareness
    @MainActor
    static func bubbleAnimation(
        accessibilityManager: AccessibilityManager
    ) -> Animation? {
        if accessibilityManager.shouldDisableAnimations {
            return nil
        } else if accessibilityManager.isVoiceOverRunning {
            return liquidGentle
        } else {
            return liquidBubble
        }
    }

    /// Get ripple animation with accessibility awareness
    @MainActor
    static func rippleAnimation(
        accessibilityManager: AccessibilityManager
    ) -> Animation? {
        if accessibilityManager.shouldDisableAnimations {
            return nil
        } else if accessibilityManager.accessibilityEffectLevel == .minimal {
            return nil // No ripples for minimal accessibility
        } else {
            return liquidRipple
        }
    }

    // MARK: - Timing and Duration Constants

    /// Standard timing values for liquid interactions
    enum Timing {
        static let quickFeedback: TimeInterval = 0.15
        static let standardResponse: TimeInterval = 0.4
        static let gentleTransition: TimeInterval = 0.6
        static let breathingCycle: TimeInterval = 2.0
        static let rippleLifetime: TimeInterval = 2.0
        static let longFlow: TimeInterval = 1.2
    }

    /// Spring curve parameters optimized for different interaction types
    enum SpringCurves {
        // Interactive feedback curves
        static let snappy = (response: 0.3, damping: 0.6)
        static let bouncy = (response: 0.35, damping: 0.65)
        static let smooth = (response: 0.4, damping: 0.8)

        // Transition curves
        static let flowing = (response: 0.6, damping: 0.9)
        static let gentle = (response: 0.8, damping: 0.95)

        // Special effects curves
        static let elastic = (response: 0.35, damping: 0.65)
        static let fluid = (response: 0.25, damping: 0.7)
    }
}

// MARK: - Animation Builder

/// Builder for creating custom liquid animations with accessibility support
struct LiquidAnimationBuilder {
    private var baseAnimation: Animation
    private var accessibilityManager: AccessibilityManager?

    init(baseAnimation: Animation) {
        self.baseAnimation = baseAnimation
    }

    /// Set accessibility manager for automatic adaptation
    func withAccessibility(_ manager: AccessibilityManager) -> LiquidAnimationBuilder {
        var builder = self
        builder.accessibilityManager = manager
        return builder
    }

    /// Build the final animation with accessibility considerations
    @MainActor
    func build() -> Animation? {
        guard let accessibilityManager = accessibilityManager else {
            return baseAnimation
        }

        return accessibilityManager.getAnimation(baseAnimation, for: "custom")
    }

    /// Build with delay for sequenced animations
    @MainActor
    func buildWithDelay(_ delay: TimeInterval) -> Animation? {
        guard let animation = build() else { return nil }
        return animation.delay(delay)
    }
}

// MARK: - SwiftUI Animation Extensions

extension Animation {

    // MARK: - Liquid Glass Animation Presets

    /// Primary liquid response animation
    static var liquidResponse: Animation {
        LiquidAnimationSystem.liquidResponse
    }

    /// Bubble interaction animation
    static var liquidBubble: Animation {
        LiquidAnimationSystem.liquidBubble
    }

    /// Flow transition animation
    static var liquidFlow: Animation {
        LiquidAnimationSystem.liquidFlow
    }

    /// Ripple touch animation
    static var liquidRipple: Animation {
        LiquidAnimationSystem.liquidRipple
    }

    /// Gentle accessibility animation
    static var liquidGentle: Animation {
        LiquidAnimationSystem.liquidGentle
    }

    /// Quick feedback animation
    static var liquidFeedback: Animation {
        LiquidAnimationSystem.liquidFeedback
    }

    /// Smooth transition animation
    static var liquidTransition: Animation {
        LiquidAnimationSystem.liquidTransition
    }

    /// Elastic selection animation
    static var liquidElastic: Animation {
        LiquidAnimationSystem.liquidElastic
    }

    /// Breathing ambient animation
    static var liquidBreath: Animation {
        LiquidAnimationSystem.liquidBreath
    }

    // MARK: - Performance Variants

    /// Reduced motion animation
    static var liquidReduced: Animation {
        LiquidAnimationSystem.liquidReduced
    }

    /// Minimal animation for battery conservation
    static var liquidMinimal: Animation {
        LiquidAnimationSystem.liquidMinimal
    }

    // MARK: - Accessibility-Aware Factory Methods

    /// Create animation with accessibility awareness
    @MainActor
    static func liquid(
        _ type: LiquidAnimationType,
        accessibilityManager: AccessibilityManager
    ) -> Animation? {
        switch type {
        case .response:
            return LiquidAnimationSystem.responsiveAnimation(accessibilityManager: accessibilityManager)
        case .bubble:
            return LiquidAnimationSystem.bubbleAnimation(accessibilityManager: accessibilityManager)
        case .ripple:
            return LiquidAnimationSystem.rippleAnimation(accessibilityManager: accessibilityManager)
        case .flow:
            return LiquidAnimationSystem.liquidAnimation(base: liquidFlow, accessibilityManager: accessibilityManager)
        case .transition:
            return LiquidAnimationSystem.liquidAnimation(base: liquidTransition, accessibilityManager: accessibilityManager)
        case .feedback:
            return LiquidAnimationSystem.liquidAnimation(base: liquidFeedback, accessibilityManager: accessibilityManager)
        }
    }
}

// MARK: - Liquid Animation Types

enum LiquidAnimationType {
    case response    // General interactions
    case bubble      // Touch and message bubbles
    case ripple      // Touch ripples
    case flow        // State transitions
    case transition  // Navigation changes
    case feedback    // Immediate responses
}

// MARK: - View Extensions for Liquid Animations

extension View {

    /// Apply liquid animation with accessibility awareness
    func liquidAnimation<T: Equatable>(
        _ type: LiquidAnimationType,
        value: T,
        accessibilityManager: AccessibilityManager
    ) -> some View {
        if let animation = Animation.liquid(type, accessibilityManager: accessibilityManager) {
            return AnyView(self.animation(animation, value: value))
        } else {
            return AnyView(self) // No animation for accessibility
        }
    }

    /// Apply liquid spring animation with custom parameters
    func liquidSpring<T: Equatable>(
        response: Double = 0.4,
        dampingFraction: Double = 0.8,
        blendDuration: Double = 0.2,
        value: T,
        accessibilityManager: AccessibilityManager
    ) -> some View {
        let springAnimation = Animation.spring(
            response: response,
            dampingFraction: dampingFraction,
            blendDuration: blendDuration
        )

        if let animation = accessibilityManager.getAnimation(springAnimation, for: value) {
            return AnyView(self.animation(animation, value: value))
        } else {
            return AnyView(self)
        }
    }

    /// Apply breathing animation for ambient effects
    func liquidBreathing(
        accessibilityManager: AccessibilityManager,
        scale: ClosedRange<CGFloat> = 0.98...1.02
    ) -> some View {
        if accessibilityManager.shouldDisableAnimations {
            return AnyView(self)
        } else {
            return AnyView(
                self.scaleEffect(
                    accessibilityManager.accessibilityEffectLevel == .full ? scale.upperBound : 1.0
                )
                .animation(.liquidBreath, value: UUID()) // Continuous breathing animation
            )
        }
    }
}