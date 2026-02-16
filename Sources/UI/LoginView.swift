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

            VStack(spacing: 20) {
                Image(systemName: "building.2.crop.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(AppPalette.primaryAction)

                VStack(spacing: 4) {
                    Text("Business Buchhaltung")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(AppPalette.textPrimary)

                    Text("Sicher anmelden")
                        .font(.title3)
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
                }

                Button("Einloggen", action: viewModel.login)
                    .appPrimaryButtonStyle()
                    .keyboardShortcut(.defaultAction)
                    .help("Einloggen (Enter)")
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)

                Text("Admin: bachin · Passwort: 12345")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(28)
            .frame(width: 460)
            .appSurface(cornerRadius: 24)
            .onAppear {
                focusedField = .username
            }
        }
        .appBackgroundStyle()
    }
}
