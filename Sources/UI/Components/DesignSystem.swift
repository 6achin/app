import SwiftUI

enum UIDensityMode: String, CaseIterable, Identifiable {
    case compact
    case comfortable

    var id: String { rawValue }
    var label: String { self == .compact ? "Compact" : "Comfortable" }
    var spacing: CGFloat { self == .compact ? 8 : 14 }
    var rowPadding: CGFloat { self == .compact ? 8 : 12 }
}

private struct UIDensityModeKey: EnvironmentKey {
    static let defaultValue: UIDensityMode = .comfortable
}

extension EnvironmentValues {
    var uiDensityMode: UIDensityMode {
        get { self[UIDensityModeKey.self] }
        set { self[UIDensityModeKey.self] = newValue }
    }
}

struct AppShell<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            content().frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

struct DSCard<Content: View>: View {
    @Environment(\.uiDensityMode) private var density
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(density == .compact ? 10 : 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )
    }
}

struct DSBackButton: View {
    let action: () -> Void
    var disabled = false

    var body: some View {
        Button(action: action) {
            Label("Zurück", systemImage: "chevron.left")
        }
        .buttonStyle(.plain)
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(disabled ? Theme.textSecondary.opacity(0.6) : Theme.textPrimary)
        .frame(height: Theme.controlHeight)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
        .disabled(disabled)
    }
}

struct PageHeader: View {
    let title: String
    let subtitle: String?
    let onBack: () -> Void
    var backDisabled = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            DSBackButton(action: onBack, disabled: backDisabled)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            Spacer()
        }
    }
}

extension View {
    func dsInput() -> some View {
        textFieldStyle(.plain)
            .font(.system(size: 14))
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 12)
            .frame(height: Theme.controlHeight)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )
    }

    func dsPrimaryButton() -> some View {
        buttonStyle(.plain)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .frame(height: Theme.controlHeight)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.accent)
            )
    }

    func dsSecondaryButton() -> some View {
        buttonStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Theme.textPrimary)
            .frame(height: Theme.controlHeight)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )
    }
}
