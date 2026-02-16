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
                colors: [Color(nsColor: .windowBackgroundColor), Color.accentColor.opacity(0.14)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "building.2.crop.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.primary)

                VStack(spacing: 4) {
                    Text("Business Buchhaltung")
                        .font(.system(size: 30, weight: .bold, design: .rounded))

                    Text("Sicher anmelden")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    TextField("Benutzername", text: $viewModel.username)
                        .loginInputStyle()
                        .focused($focusedField, equals: .username)

                    SecureField("Passwort", text: $viewModel.password)
                        .loginInputStyle()
                        .focused($focusedField, equals: .password)
                        .onSubmit(viewModel.login)
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                }

                Button("Einloggen", action: viewModel.login)
                    .buttonStyle(.borderedProminent)
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
            .background(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 10)
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
                    .fill(Color(nsColor: .textBackgroundColor).opacity(0.75))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            )
    }
}
