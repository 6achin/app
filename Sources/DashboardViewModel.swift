import Foundation

enum MetricType: String {
    case umsatz = "Umsatz"
    case umsatzsteuer = "Umsatzsteuer"
    case rechnungenOffen = "Rechnungen offen"
    case einnahmen = "Einnahmen"
    case fixkosten = "Fixkosten"
}

struct MetricCard: Identifiable {
    let id: UUID
    let type: MetricType
    var value: String
    var note: String

    init(id: UUID = UUID(), type: MetricType, value: String, note: String) {
        self.id = id
        self.type = type
        self.value = value
        self.note = note
    }

    var title: String { type.rawValue }
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

struct FixkostenEntry: Identifiable {
    let id: UUID
    var name: String
    var bookingDate: Date
    var automaticDebit: Bool
    var netAmount: Double
    var description: String

    init(
        id: UUID = UUID(),
        name: String,
        bookingDate: Date,
        automaticDebit: Bool,
        netAmount: Double,
        description: String
    ) {
        self.id = id
        self.name = name
        self.bookingDate = bookingDate
        self.automaticDebit = automaticDebit
        self.netAmount = netAmount
        self.description = description
    }

    var vatAmount: Double {
        netAmount * 0.19
    }

    var grossAmount: Double {
        netAmount + vatAmount
    }
}

final class DashboardViewModel: ObservableObject {
    @Published var cards: [MetricCard] = [
        MetricCard(type: .umsatz, value: "€ 124.000", note: "+12 %"),
        MetricCard(type: .umsatzsteuer, value: "€ 23.560", note: "19 %"),
        MetricCard(type: .rechnungenOffen, value: "8", note: "€ 15.400"),
        MetricCard(type: .einnahmen, value: "€ 81.700", note: "monatlich"),
        MetricCard(type: .fixkosten, value: "€ 34.200", note: "monatlich")
    ]

    @Published var transactions: [TransactionItem] = [
        TransactionItem(date: "12.02.2026", category: "Einkauf", amount: "€ 5.400", status: "Bezahlt"),
        TransactionItem(date: "11.02.2026", category: "Marketing", amount: "€ 3.250", status: "Offen"),
        TransactionItem(date: "09.02.2026", category: "Logistik", amount: "€ 1.720", status: "Bezahlt")
    ]

    @Published var fixkostenEntries: [FixkostenEntry] = [
        FixkostenEntry(name: "Büromiete", bookingDate: Date(), automaticDebit: true, netAmount: 2000, description: "Monatliche Miete"),
        FixkostenEntry(name: "Software", bookingDate: Date(), automaticDebit: false, netAmount: 320, description: "Tools & Lizenzen")
    ]

    private let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.locale = Locale(identifier: "de_DE")
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    func addCard() {
        cards.append(MetricCard(type: .einnahmen, value: "€ 0", note: "neu"))
    }

    func addFixkostenEntry(_ entry: FixkostenEntry) {
        fixkostenEntries.append(entry)
        recalculateFixkostenCard()
    }

    func recalculateFixkostenCard() {
        let totalGross = fixkostenEntries.reduce(0) { $0 + $1.grossAmount }
        guard let index = cards.firstIndex(where: { $0.type == .fixkosten }) else { return }
        cards[index].value = formatCurrency(totalGross)
        cards[index].note = "\(fixkostenEntries.count) Positionen"
    }

    func formatCurrency(_ value: Double) -> String {
        currencyFormatter.string(from: NSNumber(value: value)) ?? "€ 0,00"
    }
}
