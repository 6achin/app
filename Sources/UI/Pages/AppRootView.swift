import SwiftUI

struct AppRootView: View {
    @ObservedObject var auth: AuthViewModel
    @StateObject private var router = BAAppRouter()
    @StateObject private var dashboard = DashboardViewModel()
    @StateObject private var debtsStore = DebtsStore()
    @StateObject private var ordersStore = OrdersStore()
    @StateObject private var customersStore = CustomersStore()
    @AppStorage("uiDensityMode") private var densityRaw = UIDensityMode.comfortable.rawValue

    @State private var showWelcomeModal = false
    @State private var didShowWelcomeInSession = false

    private var density: UIDensityMode {
        UIDensityMode(rawValue: densityRaw) ?? .comfortable
    }

    var body: some View {
        Group {
            if auth.isAuthenticated {
                NavigationStack(path: $router.path) {
                    routeView(router.path.first ?? .dashboard)
                        .navigationDestination(for: BAAppRoute.self) { route in
                            routeView(route)
                        }
                }
                .environment(\.uiDensityMode, density)
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        Picker("Bereich", selection: Binding(
                            get: { router.top },
                            set: { router.setTop($0) }
                        )) {
                            ForEach(BATopDestination.allCases) { item in
                                Text(item.rawValue).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 560)
                    }
                    ToolbarItem(placement: .automatic) {
                        Picker("Dichte", selection: $densityRaw) {
                            ForEach(UIDensityMode.allCases) { mode in
                                Text(mode.label).tag(mode.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 220)
                    }
                    ToolbarItem(placement: .automatic) {
                        Button("Abmelden") { auth.logout() }
                    }
                }
                .preferredColorScheme(.light)
                .sheet(isPresented: $showWelcomeModal) {
                    WelcomeFocusModal(
                        dashboard: dashboard,
                        debtsStore: debtsStore,
                        ordersStore: ordersStore,
                        username: auth.username,
                        onShowOverdue: {
                            showWelcomeModal = false
                            router.openOverdueInvoices()
                        },
                        onAddInvoice: {
                            showWelcomeModal = false
                            router.setTop(.dashboard)
                            router.push(.addInvoice)
                        },
                        onAddOrder: {
                            showWelcomeModal = false
                            router.requestOrderCreateModal()
                        }
                    )
                }
            } else {
                LoginPage(viewModel: auth)
            }
        }
        .frame(minWidth: 1100, minHeight: 700)
        .onChange(of: auth.isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                if !didShowWelcomeInSession {
                    didShowWelcomeInSession = true
                    showWelcomeModal = true
                }
            } else {
                didShowWelcomeInSession = false
                showWelcomeModal = false
            }
        }
    }

    @ViewBuilder
    private func routeView(_ route: BAAppRoute) -> some View {
        switch route {
        case .dashboard:
            DashboardPage(router: router, viewModel: dashboard, debtsStore: debtsStore, ordersStore: ordersStore, customersStore: customersStore)
        case .invoices:
            InvoicesPage(router: router, viewModel: dashboard)
        case .invoiceDetail(let id):
            InvoiceDetailPage(router: router, viewModel: dashboard, invoiceID: id)
        case .addInvoice:
            AddInvoicePage(router: router, viewModel: dashboard)
        case .debts:
            DebtsPage(router: router, store: debtsStore)
        case .debtDetail(let id):
            DebtDetailPage(router: router, store: debtsStore, debtID: id)
        case .orders:
            OrdersPage(router: router, ordersStore: ordersStore)
        case .orderDetail(let id):
            OrderDetailPage(router: router, ordersStore: ordersStore, orderID: id)
        case .customers:
            CustomersPage(router: router, customersStore: customersStore)
        case .customerDetail(let id):
            CustomerDetailPage(router: router, customersStore: customersStore, customerID: id)
        case .vatOverview:
            VATOverviewPage(router: router, viewModel: dashboard)
        case .revenueByMonth:
            RevenueByMonthPage(router: router, viewModel: dashboard)
        case .fixedCosts:
            FixedCostsPage(router: router, viewModel: dashboard)
        case .addFixedCost:
            FixedCostEditPage(router: router, viewModel: dashboard, entryID: nil)
        case .editFixedCost(let id):
            FixedCostEditPage(router: router, viewModel: dashboard, entryID: id)
        case .income:
            IncomePage(router: router, viewModel: dashboard)
        }
    }
}

private struct WelcomeFocusModal: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var dashboard: DashboardViewModel
    @ObservedObject var debtsStore: DebtsStore
    @ObservedObject var ordersStore: OrdersStore

    let username: String
    let onShowOverdue: () -> Void
    let onAddInvoice: () -> Void
    let onAddOrder: () -> Void

    private var title: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let greeting: String
        switch hour {
        case 5..<12: greeting = "Guten Morgen"
        case 12..<18: greeting = "Guten Tag"
        case 18..<23: greeting = "Guten Abend"
        default: greeting = "Hallo"
        }

        let clean = username.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty { return "\(greeting) 👋" }
        let display = clean.split(separator: "@").first.map(String.init) ?? clean
        return "\(greeting), \(display.capitalized) 👋"
    }

    private var overdueInvoices: [InvoiceEntry] {
        dashboard.invoices.filter { dashboard.dueState(for: $0) == "overdue" && !$0.isPaid }
    }

    private var openInvoices: [InvoiceEntry] {
        dashboard.invoices.filter { !$0.isPaid }
    }

    private var debtsDueThisMonth: Double {
        let monthStart = dashboard.startOfMonth(for: Date())
        return debtsStore.debts
            .filter { dashboard.startOfMonth(for: $0.dueDate) == monthStart && $0.status != .closed }
            .reduce(0) { $0 + $1.amount }
    }

    private var debtsOverdue: Double {
        debtsStore.debts
            .filter { $0.status == .overdue }
            .reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        AppShell {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title)
                        .font(.title3.weight(.semibold))
                    Spacer()
                    Button("✕") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                        .dsSecondaryButton()
                }

                DSCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Heute im Fokus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("Überfällige Rechnungen: \(overdueInvoices.count) (\(dashboard.formatCurrency(overdueInvoices.reduce(0) { $0 + $1.grossAmount })))")
                        Text("Offene Rechnungen: \(openInvoices.count) (\(dashboard.formatCurrency(openInvoices.reduce(0) { $0 + $1.grossAmount })))")
                        Text("Offene Aufträge: \(ordersStore.orders.count)")
                        Text("Schulden fällig diesen Monat: \(dashboard.formatCurrency(debtsDueThisMonth)) · Überfällig: \(dashboard.formatCurrency(debtsOverdue))")
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                }

                HStack {
                    Button("Überfällige Rechnungen ansehen") { onShowOverdue() }
                        .dsSecondaryButton()
                    Button("Neue Rechnung") { onAddInvoice() }
                        .dsPrimaryButton()
                    Button("Neuer Auftrag") { onAddOrder() }
                        .dsSecondaryButton()
                }

                HStack {
                    Spacer()
                    Button("Später") { dismiss() }
                        .dsSecondaryButton()
                }
            }
            .padding(18)
            .frame(width: 760)
        }
    }
}
