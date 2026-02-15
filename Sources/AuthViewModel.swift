import Foundation

final class AuthViewModel: ObservableObject {
    @Published var username = ""
    @Published var password = ""
    @Published var isAuthenticated = false
    @Published var errorMessage: String?

    private let allowedUsers = [
        "owner": "12345",
        "manager": "biz2026"
    ]

    func login() {
        let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanUsername.isEmpty, !password.isEmpty else {
            errorMessage = "Введите логин и пароль."
            return
        }

        if allowedUsers[cleanUsername] == password {
            isAuthenticated = true
            errorMessage = nil
        } else {
            errorMessage = "Неверный логин или пароль."
        }
    }

    func logout() {
        password = ""
        isAuthenticated = false
    }
}
