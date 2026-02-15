import Foundation

enum MetricType: String {
    case umsatz = "Umsatz"
    case umsatzsteuer = "Umsatzsteuer"
    case rechnungenOffen = "Rechnungen offen"
    case einnahmen = "Einnahmen"
    case fixkosten = "Fixkosten"
}

enum BillingCycle: String, CaseIterable, Identifiable {
    case monatlich = "Monatlich"
    case quartalsweise = "Quartalsweise"
    case halbjaehrlich = "Halbjährlich"
    case jaehrlich = "Jährlich"

    var id: String { rawValue }
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

struct FixkostenEntry: Identifiable {
    let id: UUID
    var name: String
    var cycle: BillingCycle
    var automaticDebit: Bool
    var netAmount: Double
    var vatRate: Double
    var description: String

    init(
        id: UUID = UUID(),
        name: String,
        cycle: BillingCycle,
        automaticDebit: Bool,
        netAmount: Double,
        vatRate: Double,
        description: String
    ) {
        self.id = id
        self.name = name
        self.cycle = cycle
        self.automaticDebit = automaticDebit
        self.netAmount = netAmount
        self.vatRate = vatRate
        self.description = description
    }

    var vatAmount: Double {
        netAmount * vatRate
    }

    var grossAmount: Double {
        netAmount + vatAmount
    }

    var vatLabel: String {
        "\(Int(vatRate * 100))%"
    }
}

final class DashboardViewModel: ObservableObject {
    @Published var cards: [MetricCard] = [
        MetricCard(type: .umsatz, value: "€ 124.000", note: "+12 %"),
        MetricCard(type: .umsatzsteuer, value: "€ 23.560", note: "variabel"),
        MetricCard(type: .rechnungenOffen, value: "8", note: "€ 15.400"),
        MetricCard(type: .einnahmen, value: "€ 81.700", note: "monatlich"),
        MetricCard(type: .fixkosten, value: "€ 34.200", note: "monatlich")
    ]

    @Published var fixkostenEntries: [FixkostenEntry] = [
        FixkostenEntry(name: "Büromiete", cycle: .monatlich, automaticDebit: true, netAmount: 2000, vatRate: 0.19, description: "Monatliche Miete"),
        FixkostenEntry(name: "Hosting", cycle: .halbjaehrlich, automaticDebit: false, netAmount: 600, vatRate: 0.19, description: "Server und Domain")
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

    func updateFixkostenEntry(_ entry: FixkostenEntry) {
        guard let index = fixkostenEntries.firstIndex(where: { $0.id == entry.id }) else { return }
        fixkostenEntries[index] = entry
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
