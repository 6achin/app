import Foundation
import Combine

enum BATopDestination: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case rechnungen = "Rechnungen"
    case umsatzsteuer = "USt"
    case umsatz = "Umsatz"
    case fixkosten = "Fixkosten"
    case einnahmen = "Einnahmen"
    case schulden = "Schulden"
    case auftraege = "Aufträge"
    case kunden = "Kunden"

    var id: String { rawValue }
}

enum BAAppRoute: Hashable {
    case dashboard
    case invoices
    case invoiceDetail(UUID)
    case addInvoice

    case debts
    case debtDetail(UUID)

    case orders
    case orderDetail(UUID)

    case customers
    case customerDetail(UUID)

    case vatOverview
    case revenueByMonth
    case fixedCosts
    case addFixedCost
    case editFixedCost(UUID)
    case income
}

final class BAAppRouter: ObservableObject {
    @Published var path: [BAAppRoute] = [.dashboard]
    @Published var top: BATopDestination = .dashboard

    @Published var invoiceFilterStatus: InvoiceFilterStatus = .all
    @Published var invoiceMonthFilter: Date?
    @Published var invoiceOpenMonthlyMode = false

    func setTop(_ destination: BATopDestination) {
        top = destination
        path = [rootRoute(for: destination)]

        if destination != .rechnungen {
            resetInvoiceFilters()
        }
    }

    func push(_ route: BAAppRoute) {
        path.append(route)
    }

    func pop() {
        guard path.count > 1 else { return }
        path.removeLast()
    }

    func openInvoicesFromOpenKPI(month: Date?) {
        top = .rechnungen
        invoiceFilterStatus = .open
        invoiceMonthFilter = month
        invoiceOpenMonthlyMode = month == nil
        path = [.invoices]
    }

    func openInvoicesForOpenMonth(_ monthStart: Date) {
        top = .rechnungen
        invoiceFilterStatus = .open
        invoiceMonthFilter = monthStart
        invoiceOpenMonthlyMode = false
        path = [.invoices]
    }

    private func resetInvoiceFilters() {
        invoiceFilterStatus = .all
        invoiceMonthFilter = nil
        invoiceOpenMonthlyMode = false
    }

    private func rootRoute(for destination: BATopDestination) -> BAAppRoute {
        switch destination {
        case .dashboard: return .dashboard
        case .rechnungen: return .invoices
        case .umsatzsteuer: return .vatOverview
        case .umsatz: return .revenueByMonth
        case .fixkosten: return .fixedCosts
        case .einnahmen: return .income
        case .schulden: return .debts
        case .auftraege: return .orders
        case .kunden: return .customers
        }
    }
}

typealias BAAAppRouter = BAAppRouter
typealias BAAAppRoute = BAAppRoute
