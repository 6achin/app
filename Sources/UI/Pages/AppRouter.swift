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

    var id: String { rawValue }
}

enum BAAppRoute: Hashable {
    case dashboard
    case invoices
    case invoiceDetail(UUID)
    case addInvoice

    case debts
    case debtDetail(UUID)
    case addDebt
    case editDebt(UUID)

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

    func setTop(_ destination: BATopDestination) {
        top = destination
        path = [rootRoute(for: destination)]
    }

    func push(_ route: BAAppRoute) {
        path.append(route)
    }

    func pop() {
        guard path.count > 1 else { return }
        path.removeLast()
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
        }
    }
}

// Compatibility aliases

typealias BAAAppRouter = BAAppRouter
typealias BAAAppRoute = BAAppRoute
