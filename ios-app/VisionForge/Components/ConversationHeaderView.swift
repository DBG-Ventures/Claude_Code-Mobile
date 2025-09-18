//
//  ConversationHeaderView.swift
//  Centered conversation header component mimicking native iOS Messages app design.
//
//  Provides a centered glass effect bubble containing session name and status,
//  following iOS 26 liquid glass design patterns for modern chat interfaces.
//

import SwiftUI

struct ConversationHeaderView: View {
    let sessionName: String
    let status: SessionManagerConnectionStatus

    var body: some View {
        VStack(spacing: 2) {
            // Session name - bold and prominent like Messages contact name
            Text(sessionName)
                .font(.headline.bold())
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            // Compact status indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)

                Text(statusText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .glassEffect(
            .clear.tint(.primary.opacity(0.05)),
            in: RoundedRectangle(cornerRadius: 16)
        )
    }

    // MARK: - Computed Properties

    private var statusColor: Color {
        switch status {
        case .connected:
            return .green
        case .connecting:
            return .orange
        case .disconnected:
            return .red
        case .degraded:
            return .yellow
        case .error:
            return .red
        }
    }

    private var statusText: String {
        switch status {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting"
        case .disconnected:
            return "Disconnected"
        case .degraded:
            return "Degraded"
        case .error:
            return "Error"
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Connected state
        ConversationHeaderView(
            sessionName: "Claude Session",
            status: .connected
        )

        // Connecting state
        ConversationHeaderView(
            sessionName: "Mobile Chat Session",
            status: .connecting
        )

        // Long session name test
        ConversationHeaderView(
            sessionName: "Very Long Session Name That Should Truncate",
            status: .disconnected
        )

        // Error state
        ConversationHeaderView(
            sessionName: "Test Session",
            status: .error
        )
    }
    .padding()
    .background(Color(.systemBackground))
}