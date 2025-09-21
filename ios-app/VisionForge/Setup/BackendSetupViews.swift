//
//  BackendSetupViews.swift
//  Supporting view components for backend setup flow.
//
//  Contains reusable UI components and form elements used throughout
//  the backend setup process, extracted for better modularity.
//

import SwiftUI

// MARK: - Supporting Views

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct QuickSetupCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .blue)

                VStack(spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(isSelected ? .white : .primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? Color.blue : Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
    }
}

struct ConfigurationField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let validation: FieldValidation
    let icon: String
    let keyboardType: UIKeyboardType
    let onEditingChanged: () -> Void

    init(
        title: String,
        placeholder: String,
        text: Binding<String>,
        validation: FieldValidation,
        icon: String,
        keyboardType: UIKeyboardType = .default,
        onEditingChanged: @escaping () -> Void
    ) {
        self.title = title
        self.placeholder = placeholder
        self._text = text
        self.validation = validation
        self.icon = icon
        self.keyboardType = keyboardType
        self.onEditingChanged = onEditingChanged
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .frame(width: 20)

                Text(title)
                    .font(.headline)
            }

            TextField(placeholder, text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(keyboardType)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .onChange(of: text) {
                    onEditingChanged()
                }

            if let error = validation.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            } else if let warning = validation.warningMessage {
                Text(warning)
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }
}

struct SchemeButton: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(isSelected ? .white : color)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(isSelected ? color : color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct ValidationStatusRow: View {
    let icon: String
    let message: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)

            Text(message)
                .font(.body)
                .foregroundColor(.primary)

            Spacer()
        }
    }
}

struct ConfigSummaryRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.body)
                .fontWeight(.medium)
        }
    }
}