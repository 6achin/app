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
    var issuedAt: Date
    var paidAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        source: InvoiceSource,
        type: InvoiceType,
        netAmount: Double,
        vatRate: Double,
        isPaid: Bool,
        issuedAt: Date,
        paidAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.source = source
        self.type = type
        self.netAmount = netAmount
        self.vatRate = vatRate
        self.isPaid = isPaid
        self.issuedAt = issuedAt
        self.paidAt = paidAt
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

struct MonthGroup: Identifiable {
    let id = UUID()
    let title: String
    let monthStart: Date
    let entries: [InvoiceEntry]
}

struct MonthlyStat: Identifiable {
    let id = UUID()
    let title: String
    let monthStart: Date
    let umsatz: Double
    let einnahmen: Double
}

final class DashboardViewModel: ObservableObject {
    @Published var cards: [MetricCard] = [
        MetricCard(type: .umsatz, value: "€ 0,00", note: "Netto aus Ausgangsrechnungen"),
        MetricCard(type: .umsatzsteuer, value: "€ 0,00", note: "Zahllast (Ausgang - Eingang)"),
        MetricCard(type: .rechnungenOffen, value: "0", note: "offene Rechnungen"),
        MetricCard(type: .einnahmen, value: "€ 0,00", note: "nach Steuer, Krediten, Fixkosten"),
        MetricCard(type: .fixkosten, value: "€ 0,00", note: "0 Positionen")
    ]

    @Published var invoices: [InvoiceEntry] = [
        InvoiceEntry(title: "Rechnung #1001", source: .manual, type: .ausgangsrechnung, netAmount: 8200, vatRate: 0.19, isPaid: true, issuedAt: Calendar.current.date(byAdding: .day, value: -24, to: Date())!, paidAt: Calendar.current.date(byAdding: .day, value: -10, to: Date())),
        InvoiceEntry(title: "Rechnung #1002", source: .manual, type: .ausgangsrechnung, netAmount: 5400, vatRate: 0.19, isPaid: false, issuedAt: Calendar.current.date(byAdding: .day, value: -12, to: Date())!),
        InvoiceEntry(title: "Lieferant #230", source: .manual, type: .eingangsrechnung, netAmount: 2200, vatRate: 0.19, isPaid: false, issuedAt: Calendar.current.date(byAdding: .day, value: -8, to: Date())!)
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

    private let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()

    func addInvoice(_ entry: InvoiceEntry) {
        invoices.append(entry)
        recalculateAllMetrics()
    }

    func markInvoicePaid(id: UUID) {
        guard let index = invoices.firstIndex(where: { $0.id == id }) else { return }
        invoices[index].isPaid = true
        invoices[index].paidAt = Date()
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

    var openInvoicesOutgoing: [InvoiceEntry] {
        invoices.filter { !$0.isPaid && $0.type == .ausgangsrechnung }
    }

    var openInvoicesIncoming: [InvoiceEntry] {
        invoices.filter { !$0.isPaid && $0.type == .eingangsrechnung }
    }

    var paidOutgoingInvoices: [InvoiceEntry] {
        invoices.filter { $0.isPaid && $0.type == .ausgangsrechnung }.sorted(by: { $0.paidAt ?? $0.issuedAt > $1.paidAt ?? $1.issuedAt })
    }

    func groupedInvoicesByMonth() -> [MonthGroup] {
        let grouped = Dictionary(grouping: invoices) { startOfMonth(for: $0.issuedAt) }

        return grouped
            .map { month, entries in
                MonthGroup(
                    title: monthFormatter.string(from: month).capitalized,
                    monthStart: month,
                    entries: entries.sorted { $0.issuedAt > $1.issuedAt }
                )
            }
            .sorted { $0.monthStart > $1.monthStart }
    }

    func monthlyStats() -> [MonthlyStat] {
        let grouped = Dictionary(grouping: invoices) { startOfMonth(for: $0.issuedAt) }
        return grouped.map { month, entries in
            let umsatz = entries.filter { $0.type == .ausgangsrechnung }.reduce(0) { $0 + $1.netAmount }
            let outputVat = entries.filter { $0.type == .ausgangsrechnung }.reduce(0) { $0 + $1.vatAmount }
            let inputVat = entries.filter { $0.type == .eingangsrechnung }.reduce(0) { $0 + $1.vatAmount }
            let vatPayable = outputVat - inputVat
            let fixkosten = fixkostenEntries.reduce(0) { $0 + $1.grossAmount }
            let einnahmen = umsatz - max(vatPayable, 0) - kreditUndDarlehenMonatlich - fixkosten
            return MonthlyStat(title: monthFormatter.string(from: month).capitalized, monthStart: month, umsatz: umsatz, einnahmen: einnahmen)
        }
        .sorted { lhs, rhs in lhs.monthStart > rhs.monthStart }
    }

    func recalculateAllMetrics() {
        let umsatzNetto = invoices.filter { $0.type == .ausgangsrechnung }.reduce(0) { $0 + $1.netAmount }
        let outputVat = invoices.filter { $0.type == .ausgangsrechnung }.reduce(0) { $0 + $1.vatAmount }
        let inputVat = invoices.filter { $0.type == .eingangsrechnung }.reduce(0) { $0 + $1.vatAmount }
        let vatPayable = outputVat - inputVat
        let totalFixkostenBrutto = fixkostenEntries.reduce(0) { $0 + $1.grossAmount }
        let einnahmenNettoNachAbzug = umsatzNetto - max(vatPayable, 0) - kreditUndDarlehenMonatlich - totalFixkostenBrutto

        setCard(type: .umsatz, value: formatCurrency(umsatzNetto), note: "Netto aus Ausgangsrechnungen")
        setCard(type: .umsatzsteuer, value: formatCurrency(vatPayable), note: "Ausgang \(formatCurrency(outputVat)) - Eingang \(formatCurrency(inputVat))")
        setCard(type: .rechnungenOffen, value: "\(openInvoicesOutgoing.count + openInvoicesIncoming.count)", note: "Ausgang: \(openInvoicesOutgoing.count) · Eingang: \(openInvoicesIncoming.count)")
        setCard(type: .einnahmen, value: formatCurrency(einnahmenNettoNachAbzug), note: "nach Steuern, Krediten & Fixkosten")
        setCard(type: .fixkosten, value: formatCurrency(totalFixkostenBrutto), note: "\(fixkostenEntries.count) Positionen")
    }

    private func setCard(type: MetricType, value: String, note: String) {
        guard let index = cards.firstIndex(where: { $0.type == type }) else { return }
        cards[index].value = value
        cards[index].note = note
    }

    private func startOfMonth(for date: Date) -> Date {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: comps) ?? date
    }

    func formatCurrency(_ value: Double) -> String {
        currencyFormatter.string(from: NSNumber(value: value)) ?? "€ 0,00"
    }
}
