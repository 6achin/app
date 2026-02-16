import SwiftUI

struct ModalSheetContainer<Content: View>: View {
    let title: String
    var onClose: (() -> Void)?
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title)
                    .font(.title3.bold())
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
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                 .fill(Color(red: 0.945, green: 0.945, blue: 0.955))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(red: 0.76, green: 0.76, blue: 0.79), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
    }
}

extension View {
    func appPrimaryButtonStyle() -> some View {
        buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .tint(Color(red: 0.17, green: 0.30, blue: 0.52))
    }

    func appSecondaryButtonStyle() -> some View {
        buttonStyle(.bordered)
            .controlSize(.regular)
            .foregroundStyle(Color(red: 0.18, green: 0.22, blue: 0.28))
            .tint(Color(red: 0.74, green: 0.74, blue: 0.78))
    }

    func closeIconButtonStyle() -> some View {
        buttonStyle(.plain)
            .padding(8)
             .background(Color(red: 0.86, green: 0.86, blue: 0.89), in: Circle())
             .overlay(Circle().stroke(Color(red: 0.70, green: 0.70, blue: 0.73), lineWidth: 1))
    }

    func modalEditorStyle() -> some View {
        textFieldStyle(.plain)
            .font(.system(size: 16, weight: .medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                     .fill(Color(red: 0.965, green: 0.965, blue: 0.975))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(red: 0.73, green: 0.73, blue: 0.77), lineWidth: 1)
            )
    }

    func appListStyle() -> some View {
        scrollContentBackground(.visible)
            .listStyle(.inset)
    }
}
