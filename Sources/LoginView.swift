import SwiftUI

struct LoginView: View {
    @ObservedObject var viewModel: AuthViewModel

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Business Accounting")
                    .font(.system(size: 28, weight: .semibold))

                Text("Вход в систему")
                    .foregroundStyle(.secondary)

                VStack(spacing: 14) {
                    TextField("Логин", text: $viewModel.username)
                        .textFieldStyle(.roundedBorder)

                    SecureField("Пароль", text: $viewModel.password)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(viewModel.login)
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                }

                Button("Войти", action: viewModel.login)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
            }
            .padding(30)
            .frame(width: 380)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}
