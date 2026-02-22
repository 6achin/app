import SwiftUI

struct LoginPage: View {
    @ObservedObject var viewModel: AuthViewModel

    var body: some View {
        AppShell {
            VStack(spacing: 14) {
                Text("Business Buchhaltung")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)

                TextField("Benutzername", text: $viewModel.username)
                    .dsInput()
                SecureField("Passwort", text: $viewModel.password)
                    .dsInput()

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(Theme.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button("Einloggen") { viewModel.login() }
                    .dsPrimaryButton()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(24)
            .frame(width: 460)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
    }
}
