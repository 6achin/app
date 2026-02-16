import SwiftUI

struct LoginView: View {
    @ObservedObject var viewModel: AuthViewModel

    @FocusState private var focusedField: Field?

    private enum Field {
        case username
        case password
    }

    var body: some View {
        ZStack {
            Color.clear
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "building.2.crop.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(AppPalette.primaryAction)
                    .padding(10)
                    .background(
                        Circle()
                            .fill(AppPalette.inputSurface)
                    )

                VStack(spacing: 6) {
                    Text("Business Buchhaltung")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(AppPalette.textPrimary)

                    Text("Bitte melden Sie sich an")
                        .font(.subheadline)
                        .foregroundStyle(AppPalette.textSecondary)
                }

                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Benutzername")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppPalette.textSecondary)

                        TextField("Benutzername", text: $viewModel.username)
                            .modalEditorStyle()
                            .focused($focusedField, equals: .username)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Passwort")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppPalette.textSecondary)

                        SecureField("Passwort", text: $viewModel.password)
                            .modalEditorStyle()
                            .focused($focusedField, equals: .password)
                            .onSubmit(viewModel.login)
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button("Einloggen", action: viewModel.login)
                    .appPrimaryButtonStyle()
                    .keyboardShortcut(.defaultAction)
                    .help("Einloggen (Enter)")
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)

                Text("Anmeldedaten sind aus Sicherheitsgründen nicht sichtbar.")
                    .font(.caption)
                    .foregroundStyle(AppPalette.textSecondary)
            }
            .padding(30)
            .frame(width: 500)
            .appSurface(cornerRadius: 24)
            .onAppear {
                focusedField = .username
            }
        }
        .appBackgroundStyle()
    }
}
