import SwiftUI

struct LoginView: View {
    @ObservedObject var viewModel: AuthViewModel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(nsColor: .windowBackgroundColor), Color.indigo.opacity(0.16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 22) {
                Image(systemName: "building.2.crop.circle")
                    .font(.system(size: 46))
                    .foregroundStyle(.indigo)

                Text("Business Buchhaltung")
                    .font(.system(size: 30, weight: .bold, design: .rounded))

                Text("Sicher anmelden")
                    .foregroundStyle(.secondary)

                VStack(spacing: 14) {
                    TextField("Benutzername", text: $viewModel.username)
                        .textFieldStyle(.roundedBorder)

                    SecureField("Passwort", text: $viewModel.password)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(viewModel.login)
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                }

                Button("Einloggen", action: viewModel.login)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)

                Text("Admin: bachin · Passwort: 12345")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(30)
            .frame(width: 420)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.15), radius: 18, x: 0, y: 10)
            )
        }
    }
}
