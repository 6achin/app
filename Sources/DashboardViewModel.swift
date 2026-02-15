import Foundation
#if canImport(PDFKit)
import PDFKit
#endif
#if canImport(AppKit)
import AppKit
#endif

enum MetricType: String {
    case umsatz = "Umsatz"
    case umsatzsteuer = "Umsatzsteuer"
    case rechnungenOffen = "Rechnungen offen"
    case einnahmen = "Einnahmen"
    case fixkosten = "Fixkosten"
}

enum BillingCycle: String, CaseIterable, Identifiable, Codable {
    case monatlich = "Monatlich"
    case quartalsweise = "Quartalsweise"
    case halbjaehrlich = "Halbjährlich"
    case jaehrlich = "Jährlich"

    var id: String { rawValue }
}

enum InvoiceSource: String, CaseIterable, Identifiable, Codable {
    case pdf = "PDF-Rechnung"
    case manual = "Manuelle Eingabe"

    var id: String { rawValue }
}

enum InvoiceType: String, CaseIterable, Identifiable, Codable {
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

struct InvoiceEntry: Identifiable, Codable {
    let id: UUID
    var title: String
    var source: InvoiceSource
    var type: InvoiceType
    var netAmount: Double
    var vatRate: Double
    var isPaid: Bool
    var issuedAt: Date
    var paidAt: Date?
    var referenceNumber: String?
    var invoiceNumber: String?
    var customerNumber: String?
    var ustIdNr: String?
    var taxNumber: String?
    var customerName: String?
    var customerAddress: String?
    var customerPhone: String?
    var paymentTermDays: Int?
    var paymentTermsText: String?
    var pdfStoredFileName: String?

    init(
        id: UUID = UUID(),
        title: String,
        source: InvoiceSource,
        type: InvoiceType,
        netAmount: Double,
        vatRate: Double,
        isPaid: Bool,
        issuedAt: Date,
        paidAt: Date? = nil,
        referenceNumber: String? = nil,
        invoiceNumber: String? = nil,
        customerNumber: String? = nil,
        ustIdNr: String? = nil,
        taxNumber: String? = nil,
        customerName: String? = nil,
        customerAddress: String? = nil,
        customerPhone: String? = nil,
        paymentTermDays: Int? = nil,
        paymentTermsText: String? = nil,
        pdfStoredFileName: String? = nil
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
        self.referenceNumber = referenceNumber
        self.invoiceNumber = invoiceNumber
        self.customerNumber = customerNumber
        self.ustIdNr = ustIdNr
        self.taxNumber = taxNumber
        self.customerName = customerName
        self.customerAddress = customerAddress
        self.customerPhone = customerPhone
        self.paymentTermDays = paymentTermDays
        self.paymentTermsText = paymentTermsText
        self.pdfStoredFileName = pdfStoredFileName
    }

    var vatAmount: Double { netAmount * vatRate }
    var grossAmount: Double { netAmount + vatAmount }
}

struct FixkostenEntry: Identifiable, Codable {
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
    struct ParsedInvoiceLineItem: Identifiable {
        let id = UUID()
        var description: String
        var quantity: Double?
        var unitPrice: Double?
        var totalNet: Double?
    }

    struct ParsedInvoiceData {
        var title: String
        var referenceNumber: String?
        var invoiceNumber: String?
        var customerNumber: String?
        var ustIdNr: String?
        var taxNumber: String?
        var customerName: String?
        var customerAddress: String?
        var customerPhone: String?
        var issuedAt: Date?
        var netAmount: Double?
        var grossAmount: Double?
        var vatRate: Double?
        var lineItems: [ParsedInvoiceLineItem] = []
        var paymentTermDays: Int?
        var paymentTermsText: String?
        var storedPDFFileName: String?
    }

    private struct PersistedData: Codable {
        var invoices: [InvoiceEntry]
        var fixkostenEntries: [FixkostenEntry]
        var kreditUndDarlehenMonatlich: Double
    }

    private static let defaultInvoices: [InvoiceEntry] = [
        InvoiceEntry(title: "Rechnung #1001", source: .manual, type: .ausgangsrechnung, netAmount: 8200, vatRate: 0.19, isPaid: true, issuedAt: Calendar.current.date(byAdding: .day, value: -24, to: Date())!, paidAt: Calendar.current.date(byAdding: .day, value: -10, to: Date())),
        InvoiceEntry(title: "Rechnung #1002", source: .manual, type: .ausgangsrechnung, netAmount: 5400, vatRate: 0.19, isPaid: false, issuedAt: Calendar.current.date(byAdding: .day, value: -12, to: Date())!),
        InvoiceEntry(title: "Lieferant #230", source: .manual, type: .eingangsrechnung, netAmount: 2200, vatRate: 0.19, isPaid: false, issuedAt: Calendar.current.date(byAdding: .day, value: -8, to: Date())!)
    ]

    private static let defaultFixkostenEntries: [FixkostenEntry] = [
        FixkostenEntry(name: "Büromiete", cycle: .monatlich, automaticDebit: true, netAmount: 2000, vatRate: 0.19, description: "Monatliche Miete"),
        FixkostenEntry(name: "Hosting", cycle: .halbjaehrlich, automaticDebit: false, netAmount: 600, vatRate: 0.19, description: "Server und Domain")
    ]

    @Published var cards: [MetricCard] = [
        MetricCard(type: .umsatz, value: "€ 0,00", note: "Netto aus Ausgangsrechnungen"),
        MetricCard(type: .umsatzsteuer, value: "€ 0,00", note: "Zahllast (Ausgang - Eingang)"),
        MetricCard(type: .rechnungenOffen, value: "0", note: "offene Rechnungen"),
        MetricCard(type: .einnahmen, value: "€ 0,00", note: "nach Steuer, Krediten, Fixkosten"),
        MetricCard(type: .fixkosten, value: "€ 0,00", note: "0 Positionen")
    ]

    @Published var invoices: [InvoiceEntry] = DashboardViewModel.defaultInvoices

    @Published var fixkostenEntries: [FixkostenEntry] = DashboardViewModel.defaultFixkostenEntries

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

    init() {
        loadPersistedData()
        recalculateAllMetrics()
    }

    func addInvoice(_ entry: InvoiceEntry) {
        invoices.append(entry)
        recalculateAllMetrics()
    }

    #if canImport(PDFKit)
    func importPDFInvoice(from url: URL) -> ParsedInvoiceData? {
        guard let pdf = PDFDocument(url: url), let text = pdf.string, !text.isEmpty else {
            return nil
        }

        let storedFileName = storePDFLocally(from: url)

        var parsed = ParsedInvoiceData(title: url.deletingPathExtension().lastPathComponent)
        parsed.storedPDFFileName = storedFileName
        parsed.referenceNumber = firstNonNil([
            firstMatch(in: text, pattern: #"Bezug:\s*([A-Z0-9\-]+)"#),
            firstMatch(in: text, pattern: #"\b(LS-[0-9]{4}-[0-9]{2}-[0-9]{3,5})\b"#),
            adjacentValue(in: text, labelPattern: #"Bezug"#, valuePattern: #"[A-Z0-9\-]{4,}"#)
        ])

        parsed.invoiceNumber = firstNonNil([
            firstMatch(in: text, pattern: #"Rechnungs-Nr\.\s*:\s*([A-Z0-9\-]+)"#),
            firstMatch(in: text, pattern: #"\b(RE-[0-9]{4}-[0-9]{2}-[0-9]{3,5})\b"#),
            adjacentValue(in: text, labelPattern: #"Rechnungs-Nr\.?"#, valuePattern: #"[A-Z]{1,4}-[0-9]{4}-[0-9]{2}-[0-9]{3,5}"#)
        ])

        parsed.customerNumber = firstNonNil([
            firstMatch(in: text, pattern: #"Kunden-Nr\.\s*:\s*([A-Z0-9\-]+)"#),
            firstMatch(in: text, pattern: #"\b(K[0-9]{2,6})\b"#),
            adjacentValue(in: text, labelPattern: #"Kunden-Nr\.?"#, valuePattern: #"[A-Z0-9\-]{2,}"#)
        ])

        parsed.ustIdNr = firstNonNil([
            firstMatch(in: text, pattern: #"USt-IdNr\.\s*:\s*([^\n\r]+)"#)?.trimmingCharacters(in: .whitespaces),
            adjacentValue(in: text, labelPattern: #"USt-IdNr\.?"#, valuePattern: #"[A-Z]{2}[A-Z0-9\-]{6,}"#)
        ])

        parsed.taxNumber = firstNonNil([
            firstMatch(in: text, pattern: #"Steuernummer:\s*([0-9/\-]+)"#),
            adjacentValue(in: text, labelPattern: #"Steuernummer"#, valuePattern: #"[0-9/\-]{6,}"#)
        ])

        if let inv = parsed.invoiceNumber {
            parsed.title = inv
        } else if let ref = parsed.referenceNumber {
            parsed.title = ref
        }

        if let dateText = firstMatch(in: text, pattern: #"Rechnungsdatum\s*:?\s*([0-9]{2}\.[0-9]{2}\.[0-9]{2,4})"#) {
            parsed.issuedAt = parseDate(dateText)
        }

        if let vatPercentText = firstMatch(in: text, pattern: #"(?:Ust\.|MwSt\.)\s*([0-9]{1,2})\s*%"#), let vatPercent = Double(vatPercentText) {
            parsed.vatRate = vatPercent / 100
        }

        if let netText = firstNonNil([
            firstMatch(in: text, pattern: #"(?:(?:Zwischensumme|Zwieschensumme)\s*\(netto\)|Summe\s*netto|Netto\s*gesamt)\s*([0-9\.,]+)"#),
            adjacentValue(in: text, labelPattern: #"(?:Zwischensumme|Zwieschensumme)\s*\(netto\)|Summe\s*netto|Netto\s*gesamt"#, valuePattern: #"[0-9\.]+,[0-9]{2}"#)
        ]) {
            parsed.netAmount = parseGermanNumber(netText)
        }

        if let grossText = firstNonNil([
            firstMatch(in: text, pattern: #"(?:Rechnungsbetrag|Gesamtbetrag|Brutto\s*gesamt)\s*([0-9\.,]+)"#),
            adjacentValue(in: text, labelPattern: #"Rechnungsbetrag|Gesamtbetrag|Brutto\s*gesamt"#, valuePattern: #"[0-9\.]+,[0-9]{2}"#)
        ]) {
            parsed.grossAmount = parseGermanNumber(grossText)
        }

        parsed.lineItems = parseLineItems(in: text)
        if parsed.netAmount == nil {
            parsed.netAmount = parsed.lineItems.compactMap(\.totalNet).reduce(0, +)
        }

        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        if let recipientBlock = extractRecipientBlock(from: lines) {
            parsed.customerName = recipientBlock.name
            parsed.customerAddress = recipientBlock.address
            parsed.customerPhone = recipientBlock.phone
        } else if let telIndex = lines.firstIndex(where: { $0.lowercased().contains("tel") }) {
            let start = max(0, telIndex - 4)
            let customerLines = Array(lines[start..<telIndex])
            parsed.customerName = customerLines.first
            parsed.customerAddress = customerLines.dropFirst().joined(separator: ", ")
            parsed.customerPhone = lines[telIndex].replacingOccurrences(of: "Tel.:", with: "").trimmingCharacters(in: .whitespaces)
        }

        parsed.paymentTermsText = firstMatch(in: text, pattern: #"Zahlungsbedingungen:\s*([^\n\r]+)"#)
        if let terms = parsed.paymentTermsText {
            parsed.paymentTermDays = extractPaymentDays(from: terms)
        }

        if parsed.vatRate == nil, let net = parsed.netAmount, let gross = parsed.grossAmount, net > 0 {
            parsed.vatRate = max(0, (gross - net) / net)
        }

        if parsed.paymentTermDays == nil {
            parsed.paymentTermDays = 14
            parsed.paymentTermsText = "14 Tage ab Rechnungsdatum."
        }

        return parsed
    }
    #endif

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

    func clearAllData() {
        invoices = []
        fixkostenEntries = []
        kreditUndDarlehenMonatlich = 0
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

    func availableMonths() -> [Date] {
        let months = Set(invoices.map { startOfMonth(for: $0.issuedAt) })
        if months.isEmpty {
            return [startOfMonth(for: Date())]
        }
        return months.sorted(by: >)
    }

    func monthTitle(for monthStart: Date) -> String {
        monthFormatter.string(from: monthStart).capitalized
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

    func metricCards(for monthStart: Date?) -> [MetricCard] {
        let monthFiltered: [InvoiceEntry]
        if let monthStart {
            monthFiltered = invoices.filter { startOfMonth(for: $0.issuedAt) == monthStart }
        } else {
            monthFiltered = invoices
        }

        let umsatzNetto = monthFiltered.filter { $0.type == .ausgangsrechnung }.reduce(0) { $0 + $1.netAmount }
        let outputVat = monthFiltered.filter { $0.type == .ausgangsrechnung }.reduce(0) { $0 + $1.vatAmount }
        let inputVat = monthFiltered.filter { $0.type == .eingangsrechnung }.reduce(0) { $0 + $1.vatAmount }
        let vatPayable = outputVat - inputVat
        let totalFixkostenBrutto = fixkostenEntries.reduce(0) { $0 + $1.grossAmount }
        let einnahmenNettoNachAbzug = umsatzNetto - max(vatPayable, 0) - kreditUndDarlehenMonatlich - totalFixkostenBrutto
        let offeneAusgang = monthFiltered.filter { !$0.isPaid && $0.type == .ausgangsrechnung }.count
        let offeneEingang = monthFiltered.filter { !$0.isPaid && $0.type == .eingangsrechnung }.count

        return cards.map { card in
            switch card.type {
            case .umsatz:
                return MetricCard(id: card.id, type: .umsatz, value: formatCurrency(umsatzNetto), note: "Netto aus Ausgangsrechnungen")
            case .umsatzsteuer:
                return MetricCard(id: card.id, type: .umsatzsteuer, value: formatCurrency(vatPayable), note: "Ausgang \(formatCurrency(outputVat)) - Eingang \(formatCurrency(inputVat))")
            case .rechnungenOffen:
                return MetricCard(id: card.id, type: .rechnungenOffen, value: "\(offeneAusgang + offeneEingang)", note: "Ausgang: \(offeneAusgang) · Eingang: \(offeneEingang)")
            case .einnahmen:
                return MetricCard(id: card.id, type: .einnahmen, value: formatCurrency(einnahmenNettoNachAbzug), note: "nach Steuern, Krediten & Fixkosten")
            case .fixkosten:
                return MetricCard(id: card.id, type: .fixkosten, value: formatCurrency(totalFixkostenBrutto), note: "\(fixkostenEntries.count) Positionen")
            }
        }
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

        persistData()
    }

    private var persistenceURL: URL {
        let fileManager = FileManager.default
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser
        let folderURL = baseURL.appendingPathComponent("BusinessAccountingApp", isDirectory: true)
        if !fileManager.fileExists(atPath: folderURL.path) {
            try? fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }
        return folderURL.appendingPathComponent("dashboard-data.json")
    }

    private var storedPDFsFolderURL: URL {
        let folderURL = persistenceURL.deletingLastPathComponent().appendingPathComponent("pdfs", isDirectory: true)
        if !FileManager.default.fileExists(atPath: folderURL.path) {
            try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }
        return folderURL
    }

    func storedPDFURL(for invoice: InvoiceEntry) -> URL? {
        guard let fileName = invoice.pdfStoredFileName else { return nil }
        return storedPDFsFolderURL.appendingPathComponent(fileName)
    }

    #if canImport(AppKit)
    func openStoredPDF(for invoice: InvoiceEntry) {
        guard let url = storedPDFURL(for: invoice), FileManager.default.fileExists(atPath: url.path) else { return }
        NSWorkspace.shared.open(url)
    }

    func openWhatsAppReminder(for invoice: InvoiceEntry) {
        guard let phoneRaw = invoice.customerPhone else { return }
        let phone = phoneRaw.filter { $0.isNumber }
        guard !phone.isEmpty else { return }
        let due = dueDate(for: invoice)?.formatted(date: .numeric, time: .omitted) ?? "bald"
        let invoiceNo = invoice.invoiceNumber ?? invoice.referenceNumber ?? invoice.title
        let message = "Hallo, kurze Erinnerung zur Rechnung \(invoiceNo). Fällig am \(due). Vielen Dank."
        guard let encoded = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://wa.me/\(phone)?text=\(encoded)") else { return }
        NSWorkspace.shared.open(url)
    }
    #else
    func openStoredPDF(for invoice: InvoiceEntry) {
        _ = invoice
    }

    func openWhatsAppReminder(for invoice: InvoiceEntry) {
        _ = invoice
    }
    #endif


    private func firstNonNil(_ values: [String?]) -> String? {
        values.compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })
    }

    private func adjacentValue(in text: String, labelPattern: String, valuePattern: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let labelRegex = try? NSRegularExpression(pattern: labelPattern, options: [.caseInsensitive])
        else { return nil }

        for (index, line) in lines.enumerated() {
            let lineRange = NSRange(line.startIndex..., in: line)
            guard labelRegex.firstMatch(in: line, options: [], range: lineRange) != nil else { continue }

            if let value = firstMatch(in: line, pattern: "(?:\(labelPattern))\\s*:?\\s*(\(valuePattern))") {
                return value
            }

            if let sameLineValue = firstMatch(in: line, pattern: "(\(valuePattern))") {
                return sameLineValue
            }

            if index + 1 < lines.count,
               let nextLineValue = firstMatch(in: lines[index + 1], pattern: "(\(valuePattern))") {
                return nextLineValue
            }
        }

        return nil
    }

    private func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range), match.numberOfRanges > 1,
              let valueRange = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseGermanNumber(_ text: String) -> Double? {
        let cleaned = text
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(cleaned)
    }

    private func parseDate(_ text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "dd.MM.yy"
        if let date = formatter.date(from: text) {
            return date
        }
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.date(from: text)
    }

    private func parseLineItems(in text: String) -> [ParsedInvoiceLineItem] {
        let pattern = #"([\p{L}0-9\-/\(\),\.\s]{3,}?)\s+([0-9]+(?:,[0-9]+)?)\s+(?:Stk\.?|x)?\s*([0-9\.]+,[0-9]{2})\s+([0-9\.]+,[0-9]{2})"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }

        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, options: [], range: range).compactMap { match in
            guard
                match.numberOfRanges >= 5,
                let descriptionRange = Range(match.range(at: 1), in: text),
                let quantityRange = Range(match.range(at: 2), in: text),
                let unitRange = Range(match.range(at: 3), in: text),
                let totalRange = Range(match.range(at: 4), in: text)
            else {
                return nil
            }

            let description = String(text[descriptionRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let quantity = parseGermanNumber(String(text[quantityRange]))
            let unitPrice = parseGermanNumber(String(text[unitRange]))
            let totalNet = parseGermanNumber(String(text[totalRange]))

            return ParsedInvoiceLineItem(description: description, quantity: quantity, unitPrice: unitPrice, totalNet: totalNet)
        }
    }

    private func extractRecipientBlock(from lines: [String]) -> (name: String?, address: String?, phone: String?)? {
        let recipientMarker = lines.firstIndex(where: { line in
            line.range(of: #"^(?:an|kunde|rechnung\s+an)\b"#, options: [.regularExpression, .caseInsensitive]) != nil
        })

        guard let recipientMarker else { return nil }

        let candidateLines = Array(lines.dropFirst(recipientMarker + 1).prefix(6))
        guard !candidateLines.isEmpty else { return nil }

        let name = candidateLines.first
        var phone: String?
        var addressParts: [String] = []

        for line in candidateLines.dropFirst() {
            if line.lowercased().contains("tel") {
                phone = line
                    .replacingOccurrences(of: "Tel.:", with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: "Telefon:", with: "", options: .caseInsensitive)
                    .trimmingCharacters(in: .whitespaces)
            } else {
                addressParts.append(line)
            }
        }

        return (name, addressParts.isEmpty ? nil : addressParts.joined(separator: ", "), phone)
    }

    private func extractPaymentDays(from terms: String) -> Int? {
        guard let match = terms.range(of: #"([0-9]{1,2})\s*Tage"#, options: [.regularExpression, .caseInsensitive]) else {
            return nil
        }
        let digits = terms[match].filter(\.isNumber)
        return Int(digits)
    }

    func dueDate(for invoice: InvoiceEntry) -> Date? {
        guard invoice.type == .ausgangsrechnung, let days = invoice.paymentTermDays else { return nil }
        return Calendar.current.date(byAdding: .day, value: days, to: invoice.issuedAt)
    }

    func dueState(for invoice: InvoiceEntry, now: Date = Date()) -> String {
        guard !invoice.isPaid, let dueDate = dueDate(for: invoice) else { return "normal" }
        if now > dueDate { return "overdue" }
        guard let days = invoice.paymentTermDays else { return "normal" }
        guard let halfDate = Calendar.current.date(byAdding: .day, value: max(1, days / 2), to: invoice.issuedAt) else { return "normal" }
        if now >= halfDate { return "warning" }
        return "normal"
    }

    func dueStatusLabel(for invoice: InvoiceEntry, now: Date = Date()) -> String? {
        guard !invoice.isPaid, let dueDate = dueDate(for: invoice) else { return nil }
        let state = dueState(for: invoice, now: now)
        switch state {
        case "overdue":
            return "Überfällig seit \(dueDate.formatted(date: .numeric, time: .omitted))"
        case "warning":
            return "Fällig bis \(dueDate.formatted(date: .numeric, time: .omitted))"
        default:
            return nil
        }
    }

    private func storePDFLocally(from sourceURL: URL) -> String? {
        let fileName = "\(UUID().uuidString).pdf"
        let targetURL = storedPDFsFolderURL.appendingPathComponent(fileName)
        do {
            if FileManager.default.fileExists(atPath: targetURL.path) {
                try FileManager.default.removeItem(at: targetURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: targetURL)
            return fileName
        } catch {
            return nil
        }
    }

    private func persistData() {
        let data = PersistedData(
            invoices: invoices,
            fixkostenEntries: fixkostenEntries,
            kreditUndDarlehenMonatlich: kreditUndDarlehenMonatlich
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let encoded = try? encoder.encode(data) else { return }
        try? encoded.write(to: persistenceURL, options: .atomic)
    }

    private func loadPersistedData() {
        let url = persistenceURL
        guard let raw = try? Data(contentsOf: url) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let decoded = try? decoder.decode(PersistedData.self, from: raw) else { return }
        invoices = decoded.invoices
        fixkostenEntries = decoded.fixkostenEntries
        kreditUndDarlehenMonatlich = decoded.kreditUndDarlehenMonatlich
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
