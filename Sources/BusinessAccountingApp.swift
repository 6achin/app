import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.windows.forEach { window in
                window.makeKeyAndOrderFront(nil)
            }
        }
    }
}

@main
struct BusinessAccountingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
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
