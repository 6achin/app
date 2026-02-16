import SwiftUI

enum AppPalette {
    static let backgroundTop = Color(red: 0.93, green: 0.93, blue: 0.94)
    static let backgroundBottom = Color(red: 0.88, green: 0.88, blue: 0.90)

    static let surface = Color(red: 0.945, green: 0.945, blue: 0.955)
    static let inputSurface = Color(red: 0.965, green: 0.965, blue: 0.975)
    static let darkCardSurface = Color(red: 0.17, green: 0.18, blue: 0.20)

    static let border = Color(red: 0.76, green: 0.76, blue: 0.79)
    static let borderStrong = Color(red: 0.73, green: 0.73, blue: 0.77)

    static let textPrimary = Color(red: 0.12, green: 0.14, blue: 0.18)
    static let textSecondary = Color(red: 0.24, green: 0.25, blue: 0.29)
    static let textMuted = Color(red: 0.18, green: 0.22, blue: 0.28)

    static let primaryAction = Color(red: 0.82, green: 0.83, blue: 0.86)
    static let secondaryAction = Color(red: 0.88, green: 0.88, blue: 0.91)
    static let segmentedActive = Color(red: 0.58, green: 0.58, blue: 0.62)
    static let positive = Color(red: 0.70, green: 0.93, blue: 0.76)
    static let closeBackground = Color(red: 0.86, green: 0.86, blue: 0.89)
    static let closeBorder = Color(red: 0.70, green: 0.70, blue: 0.73)

    static let cardNote = Color(red: 0.36, green: 0.37, blue: 0.41)
    static let darkCardBorder = Color(red: 0.24, green: 0.25, blue: 0.28)
}

struct ModalSheetContainer<Content: View>: View {
    let title: String
    var onClose: (() -> Void)?
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title)
                    .font(.title3.bold())
                    .foregroundStyle(AppPalette.textPrimary)
                Spacer()
                if let onClose {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                    }
                    .closeIconButtonStyle()
                    .help("Schließen")
                }
            }

            content()
        }
        .padding(20)
        .appSurface(cornerRadius: 18)
        .preferredColorScheme(.light)
    }
}

extension View {
    func appBackgroundStyle() -> some View {
        background(
            LinearGradient(
                colors: [AppPalette.backgroundTop, AppPalette.backgroundBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    func appSurface(cornerRadius: CGFloat = 16) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(AppPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(AppPalette.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
    }

    func appPrimaryButtonStyle() -> some View {
        buttonStyle(.plain)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(AppPalette.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppPalette.primaryAction)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppPalette.borderStrong, lineWidth: 1)
            )
    }

    func appSecondaryButtonStyle() -> some View {
        buttonStyle(.plain)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(AppPalette.textMuted)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppPalette.secondaryAction)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppPalette.border, lineWidth: 1)
            )
    }

    func closeIconButtonStyle() -> some View {
        buttonStyle(.plain)
            .padding(8)
            .background(AppPalette.closeBackground, in: Circle())
            .overlay(Circle().stroke(AppPalette.closeBorder, lineWidth: 1))
    }

    func modalEditorStyle() -> some View {
        textFieldStyle(.plain)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(AppPalette.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppPalette.inputSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppPalette.borderStrong, lineWidth: 1)
            )
    }

    func appSegmentedStyle() -> some View {
        pickerStyle(.segmented)
            .tint(AppPalette.segmentedActive)
            .foregroundStyle(AppPalette.textPrimary)
    }


    func appSmallActionButtonStyle() -> some View {
        buttonStyle(.plain)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(AppPalette.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppPalette.inputSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppPalette.borderStrong, lineWidth: 1)
            )
    }

    func appFormGroupStyle() -> some View {
        padding(8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppPalette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppPalette.border, lineWidth: 1)
            )
    }

    func appListStyle() -> some View {
        scrollContentBackground(.hidden)
            .background(AppPalette.surface)
            .listStyle(.inset)
            .environment(\.colorScheme, .light)
    }
}
