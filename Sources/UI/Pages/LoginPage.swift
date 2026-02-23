import SwiftUI

struct LoginPage: View {
    @ObservedObject var viewModel: AuthViewModel

    @AppStorage("rememberAccount") private var rememberAccount = true
    @AppStorage("savedLoginAccount") private var savedLoginAccount = ""
    @AppStorage("recentLoginAccounts") private var recentLoginAccountsRaw = ""

    @State private var showPassword = false

    private var recentAccounts: [String] {
        recentLoginAccountsRaw.split(separator: "|").map(String.init)
    }

    var body: some View {
        AppShell {
            VStack(spacing: 14) {
                Text("Business Buchhaltung")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)

                TextField("Email / Benutzername", text: $viewModel.username)
                    .textContentType(.username)
                    .dsInput()

                HStack(spacing: 8) {
                    Group {
                        if showPassword {
                            TextField("Passwort", text: $viewModel.password)
                                .textContentType(.password)
                        } else {
                            SecureField("Passwort", text: $viewModel.password)
                                .textContentType(.password)
                        }
                    }
                    .dsInput()

                    Button(showPassword ? "Hide" : "Show") { showPassword.toggle() }
                        .dsSecondaryButton()
                }

                Toggle("Remember me", isOn: $rememberAccount)
                    .toggleStyle(.switch)
                    .font(.system(size: 12))

                if !recentAccounts.isEmpty {
                    HStack(spacing: 6) {
                        Text("Recent:")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                        ForEach(recentAccounts, id: \.self) { account in
                            Button(account) { viewModel.username = account }
                                .buttonStyle(.plain)
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.accent)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(Theme.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button("Einloggen") {
                    viewModel.login()
                    if viewModel.isAuthenticated { saveAccount() }
                }
                .dsPrimaryButton()
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(24)
            .frame(maxWidth: 520)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )
            .onAppear {
                if rememberAccount, !savedLoginAccount.isEmpty {
                    viewModel.username = savedLoginAccount
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.horizontal, 16)
        }
    }

    private func saveAccount() {
        guard rememberAccount else {
            savedLoginAccount = ""
            return
        }

        let normalized = viewModel.username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }

        savedLoginAccount = normalized
        var recent = recentAccounts.filter { $0 != normalized }
        recent.insert(normalized, at: 0)
        recentLoginAccountsRaw = recent.prefix(5).joined(separator: "|")
    }
}
