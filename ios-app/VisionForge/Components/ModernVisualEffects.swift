//
//  ModernVisualEffects.swift
//  Modern SwiftUI visual effects for enhanced UI experience.
//
//  Provides glass morphism, gradient animations, and other modern visual effects
//  compatible with current SwiftUI (liquid glass effects reserved for future iOS versions).
//

import SwiftUI

// MARK: - Glass Morphism Effect

struct GlassMorphismModifier: ViewModifier {
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Base glass layer
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)

                    // Gradient overlay for depth
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.1),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    // Border for definition
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.6),
                                    Color.white.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .shadow(
                color: Color.black.opacity(0.1),
                radius: shadowRadius,
                x: 0,
                y: shadowRadius / 2
            )
    }
}

extension View {
    func glassMorphism(cornerRadius: CGFloat = 20, shadowRadius: CGFloat = 10) -> some View {
        modifier(GlassMorphismModifier(cornerRadius: cornerRadius, shadowRadius: shadowRadius))
    }
}

// MARK: - Animated Gradient Background

struct AnimatedGradientBackground: View {
    @State private var animateGradient = false
    let colors: [Color]
    let animation: Animation

    init(
        colors: [Color] = [.blue, .purple, .pink],
        animation: Animation = .easeInOut(duration: 3).repeatForever(autoreverses: true)
    ) {
        self.colors = colors
        self.animation = animation
    }

    var body: some View {
        LinearGradient(
            colors: colors,
            startPoint: animateGradient ? .topLeading : .bottomLeading,
            endPoint: animateGradient ? .bottomTrailing : .topTrailing
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(animation) {
                animateGradient.toggle()
            }
        }
    }
}

// MARK: - Shimmer Effect

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    let duration: Double
    let bounce: Bool

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.3),
                            Color.white.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 0.3)
                    .offset(x: phase * (geometry.size.width + geometry.size.width * 0.3))
                    .mask(content)
                }
            )
            .onAppear {
                withAnimation(
                    .linear(duration: duration)
                    .repeatForever(autoreverses: bounce)
                ) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer(duration: Double = 2, bounce: Bool = false) -> some View {
        modifier(ShimmerModifier(duration: duration, bounce: bounce))
    }
}

// MARK: - Pulse Effect

struct PulseModifier: ViewModifier {
    @State private var scale: CGFloat = 1
    @State private var opacity: Double = 1
    let minScale: CGFloat
    let maxScale: CGFloat
    let duration: Double

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: duration)
                    .repeatForever(autoreverses: true)
                ) {
                    scale = maxScale
                    opacity = 0.7
                }
            }
    }
}

extension View {
    func pulse(
        minScale: CGFloat = 0.95,
        maxScale: CGFloat = 1.05,
        duration: Double = 1.5
    ) -> some View {
        modifier(PulseModifier(
            minScale: minScale,
            maxScale: maxScale,
            duration: duration
        ))
    }
}

// MARK: - Glow Effect

struct GlowModifier: ViewModifier {
    let color: Color
    let radius: CGFloat
    @State private var isGlowing = false

    func body(content: Content) -> some View {
        content
            .shadow(
                color: isGlowing ? color.opacity(0.8) : color.opacity(0.3),
                radius: isGlowing ? radius : radius / 2
            )
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true)
                ) {
                    isGlowing = true
                }
            }
    }
}

extension View {
    func glow(color: Color = .blue, radius: CGFloat = 20) -> some View {
        modifier(GlowModifier(color: color, radius: radius))
    }
}

// MARK: - Floating Action Button

struct FloatingActionButton: View {
    let icon: String
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .glassMorphism(cornerRadius: 30, shadowRadius: 15)
                .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: .infinity,
            pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressing
                }
            },
            perform: {}
        )
    }
}

// MARK: - Modern Card View

struct ModernCard<Content: View>: View {
    let content: Content
    let padding: CGFloat

    init(
        padding: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(
                        color: Color.black.opacity(0.05),
                        radius: 10,
                        x: 0,
                        y: 5
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.gray.opacity(0.1),
                                Color.gray.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

// MARK: - Animated Loading Indicator

struct ModernLoadingIndicator: View {
    @State private var rotation = 0.0
    let gradient = LinearGradient(
        colors: [.blue, .purple],
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        Circle()
            .trim(from: 0.2, to: 1)
            .stroke(gradient, style: StrokeStyle(lineWidth: 4, lineCap: .round))
            .frame(width: 40, height: 40)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(
                    .linear(duration: 1)
                    .repeatForever(autoreverses: false)
                ) {
                    rotation = 360
                }
            }
    }
}

// MARK: - Success/Error Animation View

struct StatusAnimationView: View {
    enum Status {
        case success
        case error
        case warning
    }

    let status: Status
    @State private var scale: CGFloat = 0
    @State private var opacity: Double = 0

    private var icon: String {
        switch status {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }

    private var color: Color {
        switch status {
        case .success: return .green
        case .error: return .red
        case .warning: return .orange
        }
    }

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 60))
            .foregroundColor(color)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    scale = 1
                    opacity = 1
                }
            }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 30) {
            // Glass morphism card
            ModernCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Glass Morphism Card")
                        .font(.headline)
                    Text("This card uses modern glass morphism effects")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .glassMorphism()
            .padding()

            // Shimmer text
            Text("Shimmer Effect")
                .font(.largeTitle)
                .fontWeight(.bold)
                .shimmer()

            // Pulse button
            Button("Pulse Effect") {}
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .pulse()

            // Glow effect
            Image(systemName: "star.fill")
                .font(.system(size: 50))
                .foregroundColor(.yellow)
                .glow(color: .yellow)

            // Loading indicator
            ModernLoadingIndicator()

            // Status animations
            HStack(spacing: 30) {
                StatusAnimationView(status: .success)
                StatusAnimationView(status: .error)
                StatusAnimationView(status: .warning)
            }

            // Floating action button
            FloatingActionButton(icon: "plus") {
                print("FAB tapped")
            }
        }
        .padding()
    }
    .background(AnimatedGradientBackground())
}