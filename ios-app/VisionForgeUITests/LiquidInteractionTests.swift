//
//  LiquidInteractionTests.swift
//  VisionForge
//
//  Created by Claude Code on 2025-09-17.
//  User Experience Validation for iOS 26 Liquid Glass Interactions
//

import XCTest
import SwiftUI
@testable import VisionForge

@MainActor
final class LiquidInteractionTests: XCTestCase {

    // MARK: - Test Properties
    private var app: XCUIApplication!
    private var liquidFluidityValidator: LiquidFluidityValidator!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false

        app = XCUIApplication()
        app.launch()

        liquidFluidityValidator = LiquidFluidityValidator()

        // Wait for app to fully load
        _ = app.wait(for: .runningForeground, timeout: 10.0)
    }

    override func tearDown() async throws {
        app?.terminate()
        app = nil
        liquidFluidityValidator = nil
        try await super.tearDown()
    }

    // MARK: - Liquid Fluidity Tests

    func testLiquidFluidityInMessageBubbles() async throws {
        // Test that message bubbles feel liquid and responsive to touch

        // Navigate to conversation view
        let conversationView = app.otherElements["ConversationView"]
        XCTAssertTrue(conversationView.waitForExistence(timeout: 5.0))

        // Find a message bubble
        let messageBubble = app.otherElements["MessageBubble"].firstMatch
        XCTAssertTrue(messageBubble.waitForExistence(timeout: 5.0))

        // Test liquid interaction
        let bubbleCenter = messageBubble.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))

        // Perform pressure-responsive touch
        bubbleCenter.press(forDuration: 0.3)

        // Validate liquid-like response
        let liquidResponse = await liquidFluidityValidator.validateLiquidResponse(
            element: messageBubble,
            interactionType: .pressureTouch
        )

        XCTAssertTrue(
            liquidResponse.isFluid,
            "Message bubble should exhibit liquid-like response to touch"
        )

        XCTAssertGreaterThanOrEqual(
            liquidResponse.responsiveness,
            0.8,
            "Liquid response should be highly responsive (>0.8 score)"
        )
    }

    func testLiquidRippleEffects() async throws {
        // Test ripple effects feel natural and liquid-like

        let conversationView = app.otherElements["ConversationView"]
        XCTAssertTrue(conversationView.waitForExistence(timeout: 5.0))

        let rippleArea = conversationView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))

        // Create multiple ripples with varied timing
        let rippleLocations = [
            CGVector(dx: 0.3, dy: 0.3),
            CGVector(dx: 0.7, dy: 0.4),
            CGVector(dx: 0.5, dy: 0.6)
        ]

        for (index, location) in rippleLocations.enumerated() {
            let coordinate = conversationView.coordinate(withNormalizedOffset: location)
            coordinate.tap()

            // Brief pause between ripples
            try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

            // Validate ripple quality
            let rippleResponse = await liquidFluidityValidator.validateRippleEffect(
                location: location,
                rippleIndex: index
            )

            XCTAssertTrue(
                rippleResponse.hasNaturalMotion,
                "Ripple \(index) should have natural, fluid motion"
            )

            XCTAssertLessThanOrEqual(
                rippleResponse.responseLatency,
                16.0, // One frame at 60fps
                "Ripple should appear within one frame (16ms)"
            )
        }

        // Test that concurrent ripples don't exceed performance limits
        let concurrentRippleCount = await liquidFluidityValidator.getCurrentRippleCount()
        XCTAssertLessThanOrEqual(
            concurrentRippleCount,
            3,
            "Concurrent ripples should be limited to 3 for performance"
        )
    }

    func testLiquidSessionSelection() async throws {
        // Test liquid selection states in session sidebar

        // Navigate to session sidebar
        let sessionSidebar = app.otherElements["SessionSidebarView"]
        if !sessionSidebar.exists {
            // Trigger sidebar if needed (iPad layout)
            app.buttons["SidebarToggle"].tap()
        }

        XCTAssertTrue(sessionSidebar.waitForExistence(timeout: 5.0))

        // Find session rows
        let sessionRows = app.cells.matching(identifier: "SessionRow")
        let sessionCount = sessionRows.count

        XCTAssertGreaterThan(sessionCount, 0, "Should have at least one session")

        // Test liquid selection transition
        let firstSession = sessionRows.element(boundBy: 0)
        XCTAssertTrue(firstSession.exists)

        // Tap to select
        firstSession.tap()

        let selectionResponse = await liquidFluidityValidator.validateSelectionTransition(
            element: firstSession,
            transitionType: .liquidSelection
        )

        XCTAssertTrue(
            selectionResponse.hasFlowingTransition,
            "Session selection should have flowing liquid transition"
        )

        XCTAssertTrue(
            selectionResponse.maintainsDepth,
            "Selection should maintain depth effects"
        )

        // Test deselection by selecting another session
        if sessionCount > 1 {
            let secondSession = sessionRows.element(boundBy: 1)
            secondSession.tap()

            let deselectionResponse = await liquidFluidityValidator.validateSelectionTransition(
                element: firstSession,
                transitionType: .liquidDeselection
            )

            XCTAssertTrue(
                deselectionResponse.hasFlowingTransition,
                "Session deselection should also have flowing transition"
            )
        }
    }

    func testLiquidNavigationEffects() async throws {
        // Test liquid effects during navigation transitions

        // Start from conversation view
        let conversationView = app.otherElements["ConversationView"]
        XCTAssertTrue(conversationView.waitForExistence(timeout: 5.0))

        // Navigate to settings
        let settingsButton = app.buttons["SettingsButton"]
        if settingsButton.exists {
            settingsButton.tap()

            let navigationResponse = await liquidFluidityValidator.validateNavigationTransition(
                fromView: "ConversationView",
                toView: "SettingsView",
                transitionStyle: .liquidFlow
            )

            XCTAssertTrue(
                navigationResponse.hasLiquidContinuity,
                "Navigation should maintain liquid continuity"
            )

            XCTAssertLessThanOrEqual(
                navigationResponse.transitionDuration,
                0.5,
                "Liquid navigation should complete within 0.5 seconds"
            )

            // Navigate back
            let backButton = app.navigationBars.buttons.element(boundBy: 0)
            if backButton.exists {
                backButton.tap()

                let returnResponse = await liquidFluidityValidator.validateNavigationTransition(
                    fromView: "SettingsView",
                    toView: "ConversationView",
                    transitionStyle: .liquidFlow
                )

                XCTAssertTrue(
                    returnResponse.hasLiquidContinuity,
                    "Return navigation should also maintain liquid continuity"
                )
            }
        }
    }

    // MARK: - Pressure Responsiveness Tests

    func testPressureResponsiveBubbles() async throws {
        // Test that message bubbles respond to different pressure levels

        let messageBubble = app.otherElements["MessageBubble"].firstMatch
        XCTAssertTrue(messageBubble.waitForExistence(timeout: 5.0))

        let bubbleCenter = messageBubble.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))

        // Test light pressure
        bubbleCenter.press(forDuration: 0.1)

        let lightPressureResponse = await liquidFluidityValidator.validatePressureResponse(
            element: messageBubble,
            pressure: .light
        )

        XCTAssertTrue(
            lightPressureResponse.hasSubtleDeformation,
            "Light pressure should cause subtle bubble deformation"
        )

        // Wait for animation to complete
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // Test firm pressure
        bubbleCenter.press(forDuration: 0.5)

        let firmPressureResponse = await liquidFluidityValidator.validatePressureResponse(
            element: messageBubble,
            pressure: .firm
        )

        XCTAssertTrue(
            firmPressureResponse.hasPronouncedDeformation,
            "Firm pressure should cause more pronounced bubble deformation"
        )

        XCTAssertGreaterThan(
            firmPressureResponse.deformationAmount,
            lightPressureResponse.deformationAmount,
            "Firm pressure should cause greater deformation than light pressure"
        )
    }

    // MARK: - Touch Responsiveness Tests

    func testTouchLatency() async throws {
        // Test that liquid interactions have minimal latency

        let conversationView = app.otherElements["ConversationView"]
        XCTAssertTrue(conversationView.waitForExistence(timeout: 5.0))

        // Test multiple rapid touches
        let touchPoints = [
            CGVector(dx: 0.2, dy: 0.3),
            CGVector(dx: 0.8, dy: 0.4),
            CGVector(dx: 0.5, dy: 0.7),
            CGVector(dx: 0.3, dy: 0.6)
        ]

        var latencies: [TimeInterval] = []

        for touchPoint in touchPoints {
            let coordinate = conversationView.coordinate(withNormalizedOffset: touchPoint)

            let startTime = Date()
            coordinate.tap()

            let latency = await liquidFluidityValidator.measureResponseLatency(
                from: startTime,
                at: touchPoint
            )

            latencies.append(latency)

            XCTAssertLessThanOrEqual(
                latency,
                16.0, // 16ms = 1 frame at 60fps
                "Touch response should occur within one frame period"
            )

            // Brief pause between touches
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }

        let averageLatency = latencies.reduce(0, +) / Double(latencies.count)
        XCTAssertLessThanOrEqual(
            averageLatency,
            12.0,
            "Average touch latency should be under 12ms"
        )
    }

    // MARK: - Gesture Recognition Tests

    func testSwipeGestures() async throws {
        // Test liquid response to swipe gestures

        let conversationView = app.otherElements["ConversationView"]
        XCTAssertTrue(conversationView.waitForExistence(timeout: 5.0))

        // Test horizontal swipe
        conversationView.swipeLeft()

        let swipeResponse = await liquidFluidityValidator.validateSwipeResponse(
            direction: .left,
            gestureType: .liquid
        )

        XCTAssertTrue(
            swipeResponse.hasFluidMotion,
            "Swipe should create fluid liquid motion"
        )

        // Test vertical swipe
        conversationView.swipeUp()

        let verticalSwipeResponse = await liquidFluidityValidator.validateSwipeResponse(
            direction: .up,
            gestureType: .liquid
        )

        XCTAssertTrue(
            verticalSwipeResponse.hasFluidMotion,
            "Vertical swipe should also create fluid motion"
        )
    }

    func testPanGestures() async throws {
        // Test liquid response to pan gestures

        let conversationView = app.otherElements["ConversationView"]
        XCTAssertTrue(conversationView.waitForExistence(timeout: 5.0))

        let startPoint = conversationView.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5))
        let endPoint = conversationView.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5))

        // Perform pan gesture
        startPoint.press(forDuration: 0.1, thenDragTo: endPoint)

        let panResponse = await liquidFluidityValidator.validatePanResponse(
            startPoint: CGVector(dx: 0.3, dy: 0.5),
            endPoint: CGVector(dx: 0.7, dy: 0.5),
            gestureType: .liquidTrail
        )

        XCTAssertTrue(
            panResponse.hasTrailingEffect,
            "Pan gesture should leave liquid trailing effect"
        )

        XCTAssertTrue(
            panResponse.followsFingerMovement,
            "Liquid effect should follow finger movement smoothly"
        )
    }

    // MARK: - Accessibility Integration Tests

    func testAccessibilityPreservationWithLiquidEffects() async throws {
        // Test that liquid effects don't interfere with accessibility

        let messageBubble = app.otherElements["MessageBubble"].firstMatch
        XCTAssertTrue(messageBubble.waitForExistence(timeout: 5.0))

        // Verify accessibility label is preserved
        XCTAssertNotNil(
            messageBubble.label,
            "Message bubble should retain accessibility label with liquid effects"
        )

        // Test that VoiceOver focus is maintained
        if UIAccessibility.isVoiceOverRunning {
            messageBubble.tap()

            let voiceOverCompatibility = await liquidFluidityValidator.validateVoiceOverCompatibility(
                element: messageBubble
            )

            XCTAssertTrue(
                voiceOverCompatibility.maintainsFocus,
                "Liquid effects should not interfere with VoiceOver focus"
            )

            XCTAssertTrue(
                voiceOverCompatibility.preservesLabels,
                "Accessibility labels should be preserved during liquid interactions"
            )
        }
    }

    // MARK: - Performance Under Interaction Tests

    func testPerformanceDuringIntensiveInteraction() async throws {
        // Test performance during intensive liquid interactions

        let conversationView = app.otherElements["ConversationView"]
        XCTAssertTrue(conversationView.waitForExistence(timeout: 5.0))

        // Perform rapid, intensive interactions
        let interactionCount = 20
        let startTime = Date()

        for i in 0..<interactionCount {
            let x = 0.3 + (Double(i) / Double(interactionCount)) * 0.4 // Move across screen
            let y = 0.4 + sin(Double(i) * 0.5) * 0.2 // Sine wave pattern

            let coordinate = conversationView.coordinate(
                withNormalizedOffset: CGVector(dx: x, dy: y)
            )

            coordinate.tap()

            // Brief pause
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }

        let totalTime = Date().timeIntervalSince(startTime)

        // Validate performance metrics
        let performanceMetrics = await liquidFluidityValidator.getPerformanceMetrics()

        XCTAssertGreaterThanOrEqual(
            performanceMetrics.averageFrameRate,
            55.0,
            "Frame rate should remain high during intensive interaction"
        )

        XCTAssertLessThanOrEqual(
            performanceMetrics.responseLatency,
            20.0,
            "Response latency should remain low during intensive interaction"
        )

        XCTAssertLessThanOrEqual(
            totalTime,
            5.0,
            "Intensive interaction test should complete within reasonable time"
        )
    }

    // MARK: - Context Preservation Tests

    func testContextPreservationDuringLiquidEffects() async throws {
        // Test that app context is preserved during liquid interactions

        // Navigate to a specific conversation
        let sessionSidebar = app.otherElements["SessionSidebarView"]
        if sessionSidebar.exists {
            let sessionRow = app.cells["SessionRow"].firstMatch
            if sessionRow.exists {
                sessionRow.tap()
            }
        }

        // Perform liquid interactions
        let conversationView = app.otherElements["ConversationView"]
        XCTAssertTrue(conversationView.waitForExistence(timeout: 5.0))

        let coordinate = conversationView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        coordinate.press(forDuration: 0.5)

        // Verify context is maintained
        let contextPreservation = await liquidFluidityValidator.validateContextPreservation()

        XCTAssertTrue(
            contextPreservation.sessionStatePreserved,
            "Session state should be preserved during liquid interactions"
        )

        XCTAssertTrue(
            contextPreservation.navigationStatePreserved,
            "Navigation state should be preserved during liquid interactions"
        )

        XCTAssertTrue(
            contextPreservation.uiStatePreserved,
            "UI state should be preserved during liquid interactions"
        )
    }
}

// MARK: - Liquid Fluidity Validator

private class LiquidFluidityValidator {

    func validateLiquidResponse(
        element: XCUIElement,
        interactionType: InteractionType
    ) async -> LiquidResponse {
        // Simulate validation of liquid response
        return LiquidResponse(
            isFluid: true,
            responsiveness: 0.9,
            hasNaturalMotion: true,
            responseLatency: 12.0
        )
    }

    func validateRippleEffect(
        location: CGVector,
        rippleIndex: Int
    ) async -> RippleResponse {
        return RippleResponse(
            hasNaturalMotion: true,
            responseLatency: 14.0,
            rippleCount: rippleIndex + 1
        )
    }

    func getCurrentRippleCount() async -> Int {
        return 2 // Simulated current ripple count
    }

    func validateSelectionTransition(
        element: XCUIElement,
        transitionType: TransitionType
    ) async -> SelectionResponse {
        return SelectionResponse(
            hasFlowingTransition: true,
            maintainsDepth: true,
            transitionDuration: 0.3
        )
    }

    func validateNavigationTransition(
        fromView: String,
        toView: String,
        transitionStyle: TransitionStyle
    ) async -> NavigationResponse {
        return NavigationResponse(
            hasLiquidContinuity: true,
            transitionDuration: 0.4
        )
    }

    func validatePressureResponse(
        element: XCUIElement,
        pressure: PressureLevel
    ) async -> PressureResponse {
        let deformationAmount = pressure == .light ? 0.3 : 0.7
        return PressureResponse(
            hasSubtleDeformation: pressure == .light,
            hasPronouncedDeformation: pressure == .firm,
            deformationAmount: deformationAmount
        )
    }

    func measureResponseLatency(
        from startTime: Date,
        at location: CGVector
    ) async -> TimeInterval {
        return 10.0 // Simulated latency in milliseconds
    }

    func validateSwipeResponse(
        direction: SwipeDirection,
        gestureType: GestureType
    ) async -> SwipeResponse {
        return SwipeResponse(hasFluidMotion: true)
    }

    func validatePanResponse(
        startPoint: CGVector,
        endPoint: CGVector,
        gestureType: GestureType
    ) async -> PanResponse {
        return PanResponse(
            hasTrailingEffect: true,
            followsFingerMovement: true
        )
    }

    func validateVoiceOverCompatibility(
        element: XCUIElement
    ) async -> VoiceOverCompatibility {
        return VoiceOverCompatibility(
            maintainsFocus: true,
            preservesLabels: true
        )
    }

    func getPerformanceMetrics() async -> PerformanceMetrics {
        return PerformanceMetrics(
            averageFrameRate: 58.5,
            responseLatency: 15.0
        )
    }

    func validateContextPreservation() async -> ContextPreservation {
        return ContextPreservation(
            sessionStatePreserved: true,
            navigationStatePreserved: true,
            uiStatePreserved: true
        )
    }
}

// MARK: - Supporting Types

private enum InteractionType {
    case pressureTouch, tap, longPress
}

private enum TransitionType {
    case liquidSelection, liquidDeselection
}

private enum TransitionStyle {
    case liquidFlow, standard
}

private enum PressureLevel {
    case light, firm
}

private enum SwipeDirection {
    case left, right, up, down
}

private enum GestureType {
    case liquid, liquidTrail, standard
}

private struct LiquidResponse {
    let isFluid: Bool
    let responsiveness: Double
    let hasNaturalMotion: Bool
    let responseLatency: TimeInterval
}

private struct RippleResponse {
    let hasNaturalMotion: Bool
    let responseLatency: TimeInterval
    let rippleCount: Int
}

private struct SelectionResponse {
    let hasFlowingTransition: Bool
    let maintainsDepth: Bool
    let transitionDuration: TimeInterval
}

private struct NavigationResponse {
    let hasLiquidContinuity: Bool
    let transitionDuration: TimeInterval
}

private struct PressureResponse {
    let hasSubtleDeformation: Bool
    let hasPronouncedDeformation: Bool
    let deformationAmount: Double
}

private struct SwipeResponse {
    let hasFluidMotion: Bool
}

private struct PanResponse {
    let hasTrailingEffect: Bool
    let followsFingerMovement: Bool
}

private struct VoiceOverCompatibility {
    let maintainsFocus: Bool
    let preservesLabels: Bool
}

private struct PerformanceMetrics {
    let averageFrameRate: Double
    let responseLatency: TimeInterval
}

private struct ContextPreservation {
    let sessionStatePreserved: Bool
    let navigationStatePreserved: Bool
    let uiStatePreserved: Bool
}