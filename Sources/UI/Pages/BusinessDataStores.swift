import Foundation
import Combine

struct CustomerItem: Identifiable, Hashable {
    let id: UUID
    var number: String
    var name: String
    var city: String
    var address: String
    var phone: String
    var email: String
}

final class CustomersStore: ObservableObject {
    @Published var customers: [CustomerItem] = [
        .init(id: UUID(), number: "K-1001", name: "Muster GmbH", city: "Berlin", address: "Hauptstr. 1", phone: "+491234567", email: "info@muster.de"),
        .init(id: UUID(), number: "K-1002", name: "Nord AG", city: "Hamburg", address: "Hafenweg 7", phone: "+494012345", email: "office@nord.de")
    ]

    func upsert(_ customer: CustomerItem) {
        if let idx = customers.firstIndex(where: { $0.id == customer.id }) { customers[idx] = customer } else { customers.append(customer) }
    }

    func find(by number: String) -> CustomerItem? {
        let n = number.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return customers.first { $0.number.lowercased().contains(n) }
    }
}

struct DebtItem: Identifiable, Hashable {
    enum Direction: String, CaseIterable, Identifiable { case iOwe = "I owe", owedToMe = "Owed to me"; var id: String { rawValue } }
    enum Status: String, CaseIterable, Identifiable { case active = "active", closed = "closed", overdue = "overdue"; var id: String { rawValue } }

    let id: UUID
    var direction: Direction
    var counterparty: String
    var amount: Double
    var currency: String
    var startDate: Date
    var dueDate: Date
    var interestEnabled: Bool
    var interestRate: Double?
    var taxIncluded: Bool
    var monthlyAmount: Double?
    var status: Status
    var notes: String
    var attachmentLink: String?
}

final class DebtsStore: ObservableObject {
    @Published var debts: [DebtItem] = [
        DebtItem(id: UUID(), direction: .iOwe, counterparty: "Leasing Partner", amount: 900, currency: "EUR", startDate: .now, dueDate: Calendar.current.date(byAdding: .month, value: 1, to: .now) ?? .now, interestEnabled: true, interestRate: 2.5, taxIncluded: false, monthlyAmount: 85, status: .active, notes: "", attachmentLink: nil)
    ]

    func upsert(_ item: DebtItem) {
        if let idx = debts.firstIndex(where: { $0.id == item.id }) { debts[idx] = item } else { debts.append(item) }
    }
}

struct OrderLine: Identifiable, Hashable {
    let id: UUID
    var sku: String
    var desc: String
    var qty: Double
    var unitPrice: Double
    var total: Double { qty * unitPrice }
}

struct OrderItem: Identifiable, Hashable {
    let id: UUID
    var customerID: UUID?
    var customerLabel: String
    var vatRate: Double
    var lines: [OrderLine]
    var createdAt: Date
    var status: String

    var netTotal: Double { lines.reduce(0) { $0 + $1.total } }
    var vatTotal: Double { netTotal * vatRate }
    var grossTotal: Double { netTotal + vatTotal }
}

final class OrdersStore: ObservableObject {
    @Published var orders: [OrderItem] = []

    func add(_ order: OrderItem) { orders.insert(order, at: 0) }
}
