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
            LinearGradient(
                colors: [Color(red: 0.94, green: 0.95, blue: 0.97), Color(red: 0.90, green: 0.92, blue: 0.95)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "building.2.crop.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color(red: 0.17, green: 0.30, blue: 0.52))

                VStack(spacing: 4) {
                    Text("Business Buchhaltung")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.12, green: 0.14, blue: 0.18))

                    Text("Sicher anmelden")
                        .font(.title3)
                        .foregroundStyle(Color(red: 0.28, green: 0.31, blue: 0.36))
                }

                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Benutzername")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color(red: 0.24, green: 0.28, blue: 0.35))
                        TextField("Benutzername", text: $viewModel.username)
                            .loginInputStyle()
                            .focused($focusedField, equals: .username)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Passwort")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color(red: 0.24, green: 0.28, blue: 0.35))
                        SecureField("Passwort", text: $viewModel.password)
                            .loginInputStyle()
                            .focused($focusedField, equals: .password)
                            .onSubmit(viewModel.login)
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                }

                Button("Einloggen", action: viewModel.login)
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.17, green: 0.30, blue: 0.52))
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
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color(red: 0.74, green: 0.78, blue: 0.84), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 3)
            .onAppear {
                focusedField = .username
            }
        }
    }
}

private extension View {
    func loginInputStyle() -> some View {
        textFieldStyle(.plain)
            .font(.system(size: 16, weight: .medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(red: 0.71, green: 0.75, blue: 0.82), lineWidth: 1)
            )
    }
}
