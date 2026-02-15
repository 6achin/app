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

enum InvoiceSource: String, CaseIterable, Identifiable {
    case pdf = "PDF-Rechnung"
    case manual = "Manuelle Eingabe"

    var id: String { rawValue }
}

enum InvoiceType: String, CaseIterable, Identifiable {
    case eingangsrechnung = "Eingangsrechnung"
    case ausgangsrechnung = "Ausgangsrechnung"

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

struct InvoiceEntry: Identifiable {
    let id: UUID
    var title: String
    var source: InvoiceSource
    var type: InvoiceType
    var netAmount: Double
    var vatRate: Double
    var isPaid: Bool

    init(
        id: UUID = UUID(),
        title: String,
        source: InvoiceSource,
        type: InvoiceType,
        netAmount: Double,
        vatRate: Double,
        isPaid: Bool
    ) {
        self.id = id
        self.title = title
        self.source = source
        self.type = type
        self.netAmount = netAmount
        self.vatRate = vatRate
        self.isPaid = isPaid
    }

    var vatAmount: Double { netAmount * vatRate }
    var grossAmount: Double { netAmount + vatAmount }
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

    var vatAmount: Double { netAmount * vatRate }
    var grossAmount: Double { netAmount + vatAmount }
    var vatLabel: String { "\(Int(vatRate * 100))%" }
}

final class DashboardViewModel: ObservableObject {
    @Published var cards: [MetricCard] = [
        MetricCard(type: .umsatz, value: "€ 0,00", note: "Netto aus Ausgangsrechnungen"),
        MetricCard(type: .umsatzsteuer, value: "€ 0,00", note: "Zahllast (Ausgang - Eingang)"),
        MetricCard(type: .rechnungenOffen, value: "0", note: "offene Ausgangsrechnungen"),
        MetricCard(type: .einnahmen, value: "€ 0,00", note: "nach Steuer, Krediten, Fixkosten"),
        MetricCard(type: .fixkosten, value: "€ 0,00", note: "0 Positionen")
    ]

    @Published var invoices: [InvoiceEntry] = [
        InvoiceEntry(title: "Rechnung #1001", source: .manual, type: .ausgangsrechnung, netAmount: 8200, vatRate: 0.19, isPaid: true),
        InvoiceEntry(title: "Rechnung #1002", source: .manual, type: .ausgangsrechnung, netAmount: 5400, vatRate: 0.19, isPaid: false),
        InvoiceEntry(title: "Lieferant #230", source: .manual, type: .eingangsrechnung, netAmount: 2200, vatRate: 0.19, isPaid: true)
    ]

    @Published var fixkostenEntries: [FixkostenEntry] = [
        FixkostenEntry(name: "Büromiete", cycle: .monatlich, automaticDebit: true, netAmount: 2000, vatRate: 0.19, description: "Monatliche Miete"),
        FixkostenEntry(name: "Hosting", cycle: .halbjaehrlich, automaticDebit: false, netAmount: 600, vatRate: 0.19, description: "Server und Domain")
    ]

    @Published var kreditUndDarlehenMonatlich: Double = 900

    private let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.locale = Locale(identifier: "de_DE")
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    func addInvoice(_ entry: InvoiceEntry) {
        invoices.append(entry)
        recalculateAllMetrics()
    }

    func addFixkostenEntry(_ entry: FixkostenEntry) {
        fixkostenEntries.append(entry)
        recalculateAllMetrics()
    }

    func updateFixkostenEntry(_ entry: FixkostenEntry) {
        guard let index = fixkostenEntries.firstIndex(where: { $0.id == entry.id }) else { return }
        fixkostenEntries[index] = entry
        recalculateAllMetrics()
    }

    func recalculateAllMetrics() {
        let umsatzNetto = invoices
            .filter { $0.type == .ausgangsrechnung }
            .reduce(0) { $0 + $1.netAmount }

        let outputVat = invoices
            .filter { $0.type == .ausgangsrechnung }
            .reduce(0) { $0 + $1.vatAmount }

        let inputVat = invoices
            .filter { $0.type == .eingangsrechnung }
            .reduce(0) { $0 + $1.vatAmount }

        let vatPayable = outputVat - inputVat

        let offeneAusgangsrechnungen = invoices.filter { $0.type == .ausgangsrechnung && !$0.isPaid }

        let totalFixkostenBrutto = fixkostenEntries.reduce(0) { $0 + $1.grossAmount }

        let einnahmenNettoNachAbzug = umsatzNetto
            - max(vatPayable, 0)
            - kreditUndDarlehenMonatlich
            - totalFixkostenBrutto

        setCard(type: .umsatz, value: formatCurrency(umsatzNetto), note: "Netto aus Ausgangsrechnungen")
        setCard(type: .umsatzsteuer, value: formatCurrency(vatPayable), note: "Ausgang \(formatCurrency(outputVat)) - Eingang \(formatCurrency(inputVat))")
        setCard(type: .rechnungenOffen, value: "\(offeneAusgangsrechnungen.count)", note: formatCurrency(offeneAusgangsrechnungen.reduce(0) { $0 + $1.grossAmount }))
        setCard(type: .einnahmen, value: formatCurrency(einnahmenNettoNachAbzug), note: "nach Steuern, Krediten & Fixkosten")
        setCard(type: .fixkosten, value: formatCurrency(totalFixkostenBrutto), note: "\(fixkostenEntries.count) Positionen")
    }

    private func setCard(type: MetricType, value: String, note: String) {
        guard let index = cards.firstIndex(where: { $0.type == type }) else { return }
        cards[index].value = value
        cards[index].note = note
    }

    func formatCurrency(_ value: Double) -> String {
        currencyFormatter.string(from: NSNumber(value: value)) ?? "€ 0,00"
    }
}
