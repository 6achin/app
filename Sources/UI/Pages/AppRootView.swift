import SwiftUI

struct AppRootView: View {
    @ObservedObject var auth: AuthViewModel
    @StateObject private var router = BAAppRouter()
    @StateObject private var dashboard = DashboardViewModel()
    @StateObject private var debtsStore = DebtsStore()
    @StateObject private var ordersStore = OrdersStore()
    @StateObject private var customersStore = CustomersStore()
    @AppStorage("uiDensityMode") private var densityRaw = UIDensityMode.comfortable.rawValue

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
            } else {
                LoginPage(viewModel: auth)
            }
        }
        .frame(minWidth: 1100, minHeight: 700)
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
