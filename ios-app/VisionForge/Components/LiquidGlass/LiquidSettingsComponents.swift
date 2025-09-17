//
//  LiquidSettingsComponents.swift
//  Reusable liquid glass components for settings interface.
//
//  Provides glass-styled UI components with liquid animations, touch feedback,
//  and accessibility compliance for the settings view.
//

import SwiftUI
import Combine

// MARK: - Liquid Settings Card

struct LiquidSettingsCard<Content: View>: View {
    let content: Content
    let title: String?
    let icon: String?

    @State private var isPressed: Bool = false
    @State private var rippleLocation: CGPoint = .zero
    @State private var showRipple: Bool = false

    @EnvironmentObject var accessibilityManager: AccessibilityManager
    @EnvironmentObject var performanceMonitor: LiquidPerformanceMonitor
    @Environment(\.colorScheme) var colorScheme

    init(
        title: String? = nil,
        icon: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header if provided
            if title != nil || icon != nil {
                cardHeader
            }

            // Content
            content
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(cardBackground)
        // Removed touch animations and gestures to improve scrolling
    }

    private var cardHeader: some View {
        HStack(spacing: 8) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.callout)
                    .foregroundColor(.blue)
                    .frame(width: 18)
            }

            if let title = title {
                Text(title)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }

            Spacer()
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(.thinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        Color.white.opacity(colorScheme == .dark ? 0.08 : 0.15),
                        lineWidth: 0.5
                    )
            )
            .shadow(
                color: Color.black.opacity(0.05),
                radius: 3,
                x: 0,
                y: 1
            )
    }

    private func handleTap(at location: CGPoint) {
        // Disabled tap handling to improve scrolling
    }
}

// MARK: - Liquid Text Field

struct LiquidTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let icon: String?
    let validation: FieldValidation?
    let keyboardType: UIKeyboardType
    let onChange: () -> Void

    @State private var isFocused: Bool = false
    @State private var showValidationAnimation: Bool = false
    @FocusState private var textFieldFocus: Bool

    @EnvironmentObject var accessibilityManager: AccessibilityManager
    @Environment(\.colorScheme) var colorScheme

    init(
        title: String,
        placeholder: String,
        text: Binding<String>,
        icon: String? = nil,
        validation: FieldValidation? = nil,
        keyboardType: UIKeyboardType = .default,
        onChange: @escaping () -> Void = {}
    ) {
        self.title = title
        self.placeholder = placeholder
        self._text = text
        self.icon = icon
        self.validation = validation
        self.keyboardType = keyboardType
        self.onChange = onChange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Label
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.subheadline)
                        .foregroundColor(isFocused ? .blue : .secondary)
                        .frame(width: 16)
                }

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isFocused ? .primary : .secondary)
            }
            .animation(.liquidFeedback, value: isFocused)

            // Text field container
            HStack {
                TextField(placeholder, text: $text)
                    .textFieldStyle(PlainTextFieldStyle())
                    .keyboardType(keyboardType)
                    .focused($textFieldFocus)
                    .onChange(of: text) { _, _ in
                        onChange()
                        triggerValidationAnimation()
                    }

                // Validation indicator
                if let validation = validation {
                    validationIndicator(validation)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(textFieldBackground)
            .overlay(textFieldBorder)
            .scaleEffect(showValidationAnimation ? 1.02 : 1.0)
            .animation(.liquidFeedback, value: showValidationAnimation)

            // Validation messages
            if let validation = validation {
                validationMessages(validation)
            }
        }
        .onChange(of: textFieldFocus) { _, newValue in
            withAnimation(.liquidResponse) {
                isFocused = newValue
            }
        }
    }

    private var textFieldBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.clear)
            .background(
                isFocused ? AnyView(Color.blue.opacity(0.05)) : AnyView(Color(.systemGray6))
            )
            .animation(.liquidResponse, value: isFocused)
    }

    private var textFieldBorder: some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(
                borderColor,
                lineWidth: isFocused ? 2 : 1
            )
            .animation(.liquidResponse, value: isFocused)
    }

    private var borderColor: Color {
        if let validation = validation {
            if validation.errorMessage != nil {
                return .red
            } else if validation.warningMessage != nil {
                return .orange
            }
        }
        return isFocused ? .blue : Color(.systemGray4)
    }

    @ViewBuilder
    private func validationIndicator(_ validation: FieldValidation) -> some View {
        if validation.errorMessage != nil {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
                .transition(.scale.combined(with: .opacity))
        } else if validation.warningMessage != nil {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .transition(.scale.combined(with: .opacity))
        } else if validation.isValid {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .transition(.scale.combined(with: .opacity))
        }
    }

    @ViewBuilder
    private func validationMessages(_ validation: FieldValidation) -> some View {
        if let error = validation.errorMessage {
            Text(error)
                .font(.caption)
                .foregroundColor(.red)
                .transition(.move(edge: .top).combined(with: .opacity))
        } else if let warning = validation.warningMessage {
            Text(warning)
                .font(.caption)
                .foregroundColor(.orange)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func triggerValidationAnimation() {
        showValidationAnimation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            showValidationAnimation = false
        }
    }
}

// MARK: - Liquid Toggle

struct LiquidToggle: View {
    let title: String
    @Binding var isOn: Bool
    let icon: String?

    @State private var isPressed: Bool = false
    @EnvironmentObject var accessibilityManager: AccessibilityManager

    init(title: String, isOn: Binding<Bool>, icon: String? = nil) {
        self.title = title
        self._isOn = isOn
        self.icon = icon
    }

    var body: some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(.blue)
                    .frame(width: 24)
            }

            Text(title)
                .font(.body)

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .animation(.liquidFeedback, value: isPressed)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.liquidFeedback) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.liquidFeedback) {
                        isPressed = false
                    }
                }
        )
    }
}

// MARK: - Liquid Button

struct LiquidButton: View {
    let title: String
    let icon: String?
    let style: ButtonStyle
    let action: () -> Void

    @State private var isPressed: Bool = false
    @State private var showRipple: Bool = false
    @EnvironmentObject var accessibilityManager: AccessibilityManager

    enum ButtonStyle {
        case primary
        case secondary
        case destructive
        case subtle
    }

    init(
        title: String,
        icon: String? = nil,
        style: ButtonStyle = .primary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
    }

    var body: some View {
        Button(action: {
            triggerHapticFeedback()
            action()
        }) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.subheadline)
                }

                Text(title)
                    .font(.subheadline)
                    .fontWeight(style == .primary ? .medium : .regular)
            }
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(backgroundView)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:
            return .white
        case .secondary:
            return .blue
        case .destructive:
            return .white
        case .subtle:
            return .secondary
        }
    }

    private var backgroundView: some View {
        Group {
            switch style {
            case .primary:
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.blue)
            case .secondary:
                RoundedRectangle(cornerRadius: 10)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.blue.opacity(0.2), lineWidth: 0.5)
                    )
            case .destructive:
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.red.opacity(0.9))
            case .subtle:
                RoundedRectangle(cornerRadius: 10)
                    .fill(.ultraThinMaterial)
            }
        }
    }

    private func triggerHapticFeedback() {
        if accessibilityManager.shouldEnableHapticFeedback {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        }

        showRipple = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showRipple = false
        }
    }
}

// MARK: - Liquid Sidebar Item

struct LiquidSidebarItem: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered: Bool = false
    @EnvironmentObject var accessibilityManager: AccessibilityManager

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(isSelected ? .white : .blue)
                    .frame(width: 20)

                Text(title)
                    .font(.callout)
                    .foregroundColor(isSelected ? .white : .primary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(itemBackground)
            .scaleEffect(isHovered ? 0.98 : 1.0)
            .animation(.liquidResponse, value: isHovered)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.liquidFeedback) {
                isHovered = hovering
            }
        }
    }

    private var itemBackground: some View {
        ZStack {
            if isSelected {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                Color.white.opacity(0.2),
                                lineWidth: 1
                            )
                    )
            } else if isHovered {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.1))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.clear)
            }
        }
    }
}

// MARK: - Supporting Types

// Note: LiquidInteractionMetrics.ElementType is defined elsewhere
// We'll use the existing types from the main liquid glass system

// MARK: - Accessibility Helpers

extension AccessibilityManager {
    var shouldEnableHapticFeedback: Bool {
        return !isVoiceOverRunning
    }
}