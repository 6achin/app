import Foundation

struct MetricCard: Identifiable {
    let id: UUID
    var title: String
    var value: String
    var note: String

    init(id: UUID = UUID(), title: String, value: String, note: String) {
        self.id = id
        self.title = title
        self.value = value
        self.note = note
    }
}

struct TransactionItem: Identifiable {
    let id: UUID
    var date: String
    var category: String
    var amount: String
    var status: String

    init(id: UUID = UUID(), date: String, category: String, amount: String, status: String) {
        self.id = id
        self.date = date
        self.category = category
        self.amount = amount
        self.status = status
    }
}

final class DashboardViewModel: ObservableObject {
    @Published var cards: [MetricCard] = [
        MetricCard(title: "Umsatz", value: "€ 124.000", note: "+12 %"),
        MetricCard(title: "Umsatzsteuer", value: "€ 23.560", note: "19 %"),
        MetricCard(title: "Rechnungen offen", value: "8", note: "€ 15.400"),
        MetricCard(title: "Einnahmen", value: "€ 81.700", note: "monatlich"),
        MetricCard(title: "Fixkosten", value: "€ 34.200", note: "monatlich")
    ]

    @Published var transactions: [TransactionItem] = [
        TransactionItem(date: "12.02.2026", category: "Einkauf", amount: "€ 5.400", status: "Bezahlt"),
        TransactionItem(date: "11.02.2026", category: "Marketing", amount: "€ 3.250", status: "Offen"),
        TransactionItem(date: "09.02.2026", category: "Logistik", amount: "€ 1.720", status: "Bezahlt")
    ]

    func addCard() {
        cards.append(MetricCard(title: "Neue Kennzahl", value: "€ 0", note: "editierbar"))
    }

    func updateCard(id: UUID, title: String, value: String, note: String) {
        guard let index = cards.firstIndex(where: { $0.id == id }) else { return }
        cards[index].title = title
        cards[index].value = value
        cards[index].note = note
    }
}
