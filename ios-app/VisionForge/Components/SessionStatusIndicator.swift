//
//  SessionStatusIndicator.swift
//  SwiftUI component for SessionManager connection status.
//
//  Provides visual indicators for SessionManager connection status, session health,
//  and SessionManager availability with modern iOS design patterns.
//

import SwiftUI

// MARK: - Session Status Indicator

struct SessionStatusIndicator: View {
    let status: SessionManagerConnectionStatus
    let sessionManagerStats: SessionManagerStats?
    let isCompact: Bool

    init(status: SessionManagerConnectionStatus,
         sessionManagerStats: SessionManagerStats? = nil,
         isCompact: Bool = false) {
        self.status = status
        self.sessionManagerStats = sessionManagerStats
        self.isCompact = isCompact
    }

    var body: some View {
        if isCompact {
            compactStatusView
        } else {
            fullStatusView
        }
    }

    // MARK: - Compact Status View

    private var compactStatusView: some View {
        HStack(spacing: 4) {
            statusIndicatorDot

            if !isCompact {
                Text(status.displayName)
                    .font(.caption2)
                    .foregroundColor(statusTextColor)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(statusBackgroundColor.opacity(0.1))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(statusBackgroundColor.opacity(0.3), lineWidth: 0.5)
        )
    }

    // MARK: - Full Status View

    private var fullStatusView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with status
            HStack(spacing: 8) {
                statusIndicatorDot

                VStack(alignment: .leading, spacing: 2) {
                    Text("SessionManager")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(status.displayName)
                        .font(.caption)
                        .foregroundColor(statusTextColor)
                }

                Spacer()

                if status.isHealthy {
                    healthyIndicator
                }
            }

            // Statistics (if available)
            if let stats = sessionManagerStats {
                statsView(stats)
            }

            // Connection details
            connectionDetailsView
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(statusBackgroundColor.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(statusBackgroundColor.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Status Indicator Dot

    private var statusIndicatorDot: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
            .overlay(
                Circle()
                    .stroke(statusColor.opacity(0.3), lineWidth: 1)
                    .scaleEffect(status == .connecting ? 1.5 : 1.0)
                    .opacity(status == .connecting ? 0.6 : 0.0)
                    .animation(
                        status == .connecting ?
                        .easeInOut(duration: 1.0).repeatForever(autoreverses: true) :
                        .default,
                        value: status
                    )
            )
    }

    // MARK: - Healthy Indicator

    private var healthyIndicator: some View {
        Image(systemName: "checkmark.circle.fill")
            .foregroundColor(.green)
            .font(.caption)
    }

    // MARK: - Statistics View

    private func statsView(_ stats: SessionManagerStats) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                statsItem("Sessions", value: "\(stats.activeSessions)")
                Spacer()
                statsItem("Memory", value: String(format: "%.1fMB", stats.memoryUsageMB))
                Spacer()
                statsItem("Created", value: "\(stats.totalSessionsCreated)")
            }

            if !stats.isMemoryUsageHealthy {
                warningView("Memory usage high")
            }
        }
    }

    private func statsItem(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }

    private func warningView(_ message: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.caption2)

            Text(message)
                .font(.caption2)
                .foregroundColor(.orange)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.orange.opacity(0.1))
        .clipShape(Capsule())
    }

    // MARK: - Connection Details View

    private var connectionDetailsView: some View {
        VStack(alignment: .leading, spacing: 2) {
            switch status {
            case .connected:
                connectionDetail("Connected to SessionManager", systemImage: "link")
                if let stats = sessionManagerStats {
                    connectionDetail("Last cleanup: \(timeAgoString(stats.cleanupLastRun))", systemImage: "clock")
                }

            case .connecting:
                connectionDetail("Connecting to SessionManager...", systemImage: "antenna.radiowaves.left.and.right")

            case .disconnected:
                connectionDetail("Disconnected from SessionManager", systemImage: "link.slash")

            case .degraded:
                connectionDetail("SessionManager degraded performance", systemImage: "exclamationmark.triangle")

            case .error:
                connectionDetail("SessionManager connection error", systemImage: "xmark.circle")
            }
        }
    }

    private func connectionDetail(_ text: String, systemImage: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .foregroundColor(.secondary)
                .font(.caption2)

            Text(text)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Color Computed Properties

    private var statusColor: Color {
        switch status {
        case .connected:
            return .green
        case .connecting:
            return .blue
        case .disconnected:
            return .gray
        case .degraded:
            return .orange
        case .error:
            return .red
        }
    }

    private var statusTextColor: Color {
        switch status {
        case .connected:
            return .green
        case .connecting:
            return .blue
        case .disconnected:
            return .secondary
        case .degraded:
            return .orange
        case .error:
            return .red
        }
    }

    private var statusBackgroundColor: Color {
        statusColor
    }

    // MARK: - Helper Methods

    private func timeAgoString(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Session Manager Status Bar

struct SessionManagerStatusBar: View {
    @Environment(SessionRepository.self) var sessionRepository: SessionRepository

    var body: some View {
        HStack {
            SessionStatusIndicator(
                status: sessionRepository.sessionManagerStatus,
                sessionManagerStats: nil, // Stats available via sessionRepository if needed
                isCompact: true
            )

            Spacer()

            if sessionRepository.isLoading {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Loading...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            if sessionRepository.sessionCacheSize > 0 {
                Text("\(sessionRepository.sessionCacheSize) cached")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .glassEffect(.clear)
    }
}

// MARK: - Session Health Widget

struct SessionHealthWidget: View {
    let sessionManagerStats: SessionManagerStats?
    let connectionStatus: SessionManagerConnectionStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Session Health")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                SessionStatusIndicator(
                    status: connectionStatus,
                    isCompact: true
                )
            }

            // Health metrics
            if let stats = sessionManagerStats {
                healthMetrics(stats)
            } else {
                Text("No health data available")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .glassEffect(.clear)
    }

    private func healthMetrics(_ stats: SessionManagerStats) -> some View {
        VStack(spacing: 8) {
            // Memory usage bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Memory Usage")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(stats.memoryUsageMB, specifier: "%.1f") MB")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(stats.isMemoryUsageHealthy ? .primary : .orange)
                }

                ProgressView(value: Double(stats.memoryUsageMB), total: 500.0)
                    .tint(stats.isMemoryUsageHealthy ? .green : .orange)
            }

            // Session efficiency
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Cleanup Efficiency")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(stats.cleanupEfficiency * 100, specifier: "%.1f")%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }

                ProgressView(value: stats.cleanupEfficiency, total: 1.0)
                    .tint(.blue)
            }
        }
    }
}

// MARK: - Preview

struct SessionStatusIndicator_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Compact indicators
            HStack(spacing: 12) {
                SessionStatusIndicator(status: .connected, isCompact: true)
                SessionStatusIndicator(status: .connecting, isCompact: true)
                SessionStatusIndicator(status: .disconnected, isCompact: true)
                SessionStatusIndicator(status: .error, isCompact: true)
            }

            // Full status view
            SessionStatusIndicator(
                status: .connected,
                sessionManagerStats: SessionManagerStats(
                    activeSessions: 5,
                    totalSessionsCreated: 25,
                    memoryUsageMB: 145.8,
                    cleanupLastRun: Date().addingTimeInterval(-300),
                    sessionTimeoutSeconds: 3600
                ),
                isCompact: false
            )

            // Health widget
            SessionHealthWidget(
                sessionManagerStats: SessionManagerStats(
                    activeSessions: 3,
                    totalSessionsCreated: 15,
                    memoryUsageMB: 89.2,
                    cleanupLastRun: Date().addingTimeInterval(-600),
                    sessionTimeoutSeconds: 3600
                ),
                connectionStatus: .connected
            )

            Spacer()
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
