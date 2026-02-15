import SwiftUI
import AppKit

struct RootContentView: View {
    @ObservedObject var auth: AuthViewModel

    var body: some View {
        Group {
            if auth.isAuthenticated {
                DashboardView(viewModel: DashboardViewModel(), onLogout: auth.logout)
            } else {
                LoginView(viewModel: auth)
            }
        }
        .frame(minWidth: 980, minHeight: 620)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private let auth = AuthViewModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let rootView = RootContentView(auth: auth)
        let hostingView = NSHostingView(rootView: rootView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Business Accounting"
        window.center()
        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])

        self.window = window
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct BusinessAccountingBootstrap {
    private static let delegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        app.delegate = delegate
        app.run()
    }
}
