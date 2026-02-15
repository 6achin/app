import SwiftUI

@main
struct BusinessAccountingApp: App {
    @StateObject private var auth = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if auth.isAuthenticated {
                    DashboardView(viewModel: DashboardViewModel(), onLogout: auth.logout)
                } else {
                    LoginView(viewModel: auth)
                }
            }
            .frame(minWidth: 980, minHeight: 620)
        }
        .windowStyle(.automatic)
    }
}
