import SwiftUI
import AppKit

private enum DashboardSheet: Identifiable {
    case umsatz
    case umsatzsteuer
    case rechnungenOffen
    case einnahmen
    case fixkosten

    var id: String {
        switch self {
        case .umsatz: return "umsatz"
        case .umsatzsteuer: return "umsatzsteuer"
        case .rechnungenOffen: return "rechnungenOffen"
        case .einnahmen: return "einnahmen"
        case .fixkosten: return "fixkosten"
        }
    }
}

struct DashboardView: View {
    @ObservedObject var viewModel: DashboardViewModel
    let onLogout: () -> Void

    @State private var selectedSheet: DashboardSheet?
    @State private var showAddInvoiceSheet = false
    @State private var selectedMonthStart: Date?
    @State private var showClearDataAlert = false
    @State private var didInitialRefresh = false

    private let cardColumns = [GridItem(.adaptive(minimum: 250), spacing: 14)]

    private var availableMonths: [Date] {
        viewModel.availableMonths()
    }

    private var activeMonthStart: Date {
        if let selectedMonthStart, availableMonths.contains(selectedMonthStart) {
            return selectedMonthStart
        }
        return availableMonths.first ?? Calendar.current.startOfDay(for: Date())
    }

    private var displayedCards: [MetricCard] {
        viewModel.metricCards(for: activeMonthStart)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.white, Color(red: 0.96, green: 0.97, blue: 0.99)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
                .ignoresSafeArea()
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Dashboard")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.black.opacity(0.86))
                        Text("Willkommen zurück, bachin")
                            .font(.title3)
                            .foregroundStyle(Color.black.opacity(0.62))
                    }

                    Spacer()

                    Button {
                        showAddInvoiceSheet = true
                    } label: {
                        Label("Hinzufügen", systemImage: "plus")
                    }
                    .appPrimaryButtonStyle()
                    .keyboardShortcut("n", modifiers: [.command])
                    .help("Neue Rechnung hinzufügen (⌘N)")

                    Button("Abmelden", action: onLogout)
                        .appSecondaryButtonStyle()

                    Button("Alle Daten löschen", role: .destructive) {
                        showClearDataAlert = true
                    }
                    .appSecondaryButtonStyle()
                }

                monthNavigation

                LazyVGrid(columns: cardColumns, spacing: 14) {
                    ForEach(displayedCards) { card in
                        KPIButtonCard(card: card) {
                            switch card.type {
                            case .umsatz: selectedSheet = .umsatz
                            case .umsatzsteuer: selectedSheet = .umsatzsteuer
                            case .rechnungenOffen: selectedSheet = .rechnungenOffen
                            case .einnahmen: selectedSheet = .einnahmen
                            case .fixkosten: selectedSheet = .fixkosten
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(24)
            .frame(maxWidth: 1280, maxHeight: .infinity, alignment: .topLeading)
        }
        .sheet(item: $selectedSheet) { sheet in
            switch sheet {
            case .umsatz:
                UmsatzDetailsSheet(viewModel: viewModel)
            case .umsatzsteuer:
                UmsatzsteuerSheet(viewModel: viewModel)
            case .rechnungenOffen:
                OffeneRechnungenSheet(viewModel: viewModel)
            case .einnahmen:
                EinnahmenSheet(viewModel: viewModel)
            case .fixkosten:
                FixkostenSheet(viewModel: viewModel)
            }
        }
        .sheet(isPresented: $showAddInvoiceSheet) {
            AddInvoiceSheet(viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .interactiveDismissDisabled(false)
        }
        .onAppear {
            if selectedMonthStart == nil {
                selectedMonthStart = availableMonths.first
            }
            guard !didInitialRefresh else { return }
            didInitialRefresh = true
            viewModel.recalculateAllMetrics()
        }
        .alert("Alle Daten wirklich löschen?", isPresented: $showClearDataAlert) {
            Button("Löschen", role: .destructive) {
                viewModel.clearAllData()
                selectedMonthStart = availableMonths.first
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Diese Aktion entfernt alle Rechnungen und Fixkosten dauerhaft aus dem lokalen Speicher.")
        }
    }

    private var monthNavigation: some View {
        HStack(spacing: 10) {
            Button {
                selectPreviousMonth()
            } label: {
                Image(systemName: "chevron.left")
            }
            .appSecondaryButtonStyle()
            .disabled(!canSelectPreviousMonth)

            Text(viewModel.monthTitle(for: activeMonthStart))
                .font(.headline.weight(.semibold))
                .frame(minWidth: 220)

            Button {
                selectNextMonth()
            } label: {
                Image(systemName: "chevron.right")
            }
            .appSecondaryButtonStyle()
            .disabled(!canSelectNextMonth)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    if value.translation.width < -30 {
                        selectPreviousMonth()
                    } else if value.translation.width > 30 {
                        selectNextMonth()
                    }
                }
        )
    }

    private var canSelectPreviousMonth: Bool {
        guard let currentIndex = availableMonths.firstIndex(of: activeMonthStart) else { return false }
        return currentIndex < availableMonths.count - 1
    }

    private var canSelectNextMonth: Bool {
        guard let currentIndex = availableMonths.firstIndex(of: activeMonthStart) else { return false }
        return currentIndex > 0
    }

    private func selectPreviousMonth() {
        guard let currentIndex = availableMonths.firstIndex(of: activeMonthStart), currentIndex < availableMonths.count - 1 else { return }
        selectedMonthStart = availableMonths[currentIndex + 1]
    }

    private func selectNextMonth() {
        guard let currentIndex = availableMonths.firstIndex(of: activeMonthStart), currentIndex > 0 else { return }
        selectedMonthStart = availableMonths[currentIndex - 1]
    }

}

private struct KPIButtonCard: View {
    let card: MetricCard
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Text(card.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.black.opacity(0.72))
                Text(card.value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.9))
                    .minimumScaleFactor(0.85)
                Text(card.note)
                    .font(.callout)
                    .foregroundStyle(Color.black.opacity(0.62))
            }
            .frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(red: 0.975, green: 0.978, blue: 0.986))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.black.opacity(0.18), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

private enum AddInvoiceStep: String, CaseIterable, Identifiable {
    case basis = "Basis"
    case kunde = "Kunde"
    case betrag = "Betrag & Zahlung"

    var id: String { rawValue }
}

private struct AddInvoiceSheet: View {
    @ObservedObject var viewModel: DashboardViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var step: AddInvoiceStep = .basis
    @State private var source: InvoiceSource = .pdf
    @State private var type: InvoiceType = .ausgangsrechnung
    @State private var title = ""
    @State private var netInput = ""
    @State private var grossInput = ""
    @State private var vatRate = 0.19
    @State private var pickedPDF = ""
    @State private var issuedAt = Date()
    @State private var importedPDFFileName: String?
    @State private var parsedLineItemsCount = 0

    @State private var referenceNumber = ""
    @State private var invoiceNumber = ""
    @State private var customerNumber = ""
    @State private var ustIdNr = ""
    @State private var taxNumber = ""

    @State private var customerName = ""
    @State private var customerStreet = ""
    @State private var customerPostalCity = ""
    @State private var customerPhone = ""

    @State private var paymentTermDaysInput = "14"
    @State private var paymentTermsText = "14 Tage ab Rechnungsdatum."

    private var netAmount: Double {
        Double(netInput.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var grossAmountInput: Double {
        Double(grossInput.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var vatAmountCalculated: Double {
        max(0, netAmount * vatRate)
    }

    private var grossAmountCalculated: Double {
        max(0, netAmount + vatAmountCalculated)
    }

    private var grossCalculatedText: String {
        String(format: "%.2f", grossAmountCalculated).replacingOccurrences(of: ".", with: ",")
    }

    private var vatCalculatedText: String {
        String(format: "%.2f", vatAmountCalculated).replacingOccurrences(of: ".", with: ",")
    }

    private var customerAddress: String? {
        let joined = [customerStreet, customerPostalCity]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        return joined.isEmpty ? nil : joined
    }

    private var paymentTermDays: Int? {
        Int(paymentTermDaysInput.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var computedDueDateText: String? {
        guard type == .ausgangsrechnung, let days = paymentTermDays,
              let due = Calendar.current.date(byAdding: .day, value: days, to: issuedAt) else {
            return nil
        }
        return due.formatted(date: .numeric, time: .omitted)
    }

    private var missingRequiredFields: [String] {
        var fields: [String] = []
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { fields.append("Bezeichnung") }
        if invoiceNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { fields.append("Rechnungs-Nr.") }
        if customerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { fields.append("Kunde") }
        if netAmount <= 0 { fields.append("Zwischensumme (netto)") }
        if type == .ausgangsrechnung && paymentTermDays == nil { fields.append("Tage bis Fälligkeit") }
        return fields
    }

    private var hasDuplicateInvoiceNumber: Bool {
        let trimmedInvoiceNumber = invoiceNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInvoiceNumber.isEmpty else { return false }
        return viewModel.hasInvoiceNumber(trimmedInvoiceNumber)
    }

    private var normalizedPhoneHint: String? {
        guard let normalized = viewModel.normalizedPhoneForMessaging(customerPhone),
              normalized != customerPhone.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        return normalized
    }

    private var isSaveDisabled: Bool {
        !missingRequiredFields.isEmpty || hasDuplicateInvoiceNumber
    }

    var body: some View {
        ModalSheetContainer(title: "Neue Rechnung", onClose: { dismiss() }) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Picker("Quelle", selection: $source) {
                        ForEach(InvoiceSource.allCases) { value in
                            Text(value.rawValue).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Typ", selection: $type) {
                        ForEach(InvoiceType.allCases) { value in
                            Text(value.rawValue).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Picker("Schritt", selection: $step) {
                    ForEach(AddInvoiceStep.allCases) { value in
                        Text(value.rawValue).tag(value)
                    }
                }
                .pickerStyle(.segmented)

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        switch step {
                        case .basis:
                            basisStep
                        case .kunde:
                            customerStep
                        case .betrag:
                            amountStep
                        }
                    }
                }

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        if let due = computedDueDateText {
                            Label("Fällig am: \(due)", systemImage: "calendar.badge.clock")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        if !missingRequiredFields.isEmpty {
                            Label("Pflichtfelder fehlen: \(missingRequiredFields.joined(separator: ", "))", systemImage: "exclamationmark.triangle.fill")
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        }

                        if hasDuplicateInvoiceNumber {
                            Label("Rechnungs-Nr. existiert bereits.", systemImage: "doc.on.doc")
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }

                    Spacer()

                    Button("Abbrechen", role: .cancel) { dismiss() }
                    Button("Speichern") {
                        let normalizedNet = netAmount > 0 ? netAmount : (grossAmountInput > 0 ? grossAmountInput / (1 + vatRate) : 0)
                        let invoice = InvoiceEntry(
                            title: title.isEmpty ? "Neue Rechnung" : title,
                            source: source,
                            type: type,
                            netAmount: normalizedNet,
                            vatRate: vatRate,
                            isPaid: false,
                            issuedAt: issuedAt,
                            referenceNumber: referenceNumber.isEmpty ? nil : referenceNumber,
                            invoiceNumber: invoiceNumber.isEmpty ? nil : invoiceNumber,
                            customerNumber: customerNumber.isEmpty ? nil : customerNumber,
                            ustIdNr: ustIdNr.isEmpty ? nil : ustIdNr,
                            taxNumber: taxNumber.isEmpty ? nil : taxNumber,
                            customerName: customerName.isEmpty ? nil : customerName,
                            customerAddress: customerAddress,
                            customerPhone: viewModel.normalizedPhoneForMessaging(customerPhone),
                            paymentTermDays: type == .ausgangsrechnung ? paymentTermDays : nil,
                            paymentTermsText: paymentTermsText.isEmpty ? nil : paymentTermsText,
                            pdfStoredFileName: importedPDFFileName
                        )
                        viewModel.addInvoice(invoice)
                        dismiss()
                    }
                    .appPrimaryButtonStyle()
                    .disabled(isSaveDisabled)
                }
            }
            .font(.system(size: 15, weight: .regular))
        }
        .frame(width: 800, height: 720)
    }

    private var basisStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            if source == .pdf {
                GroupBox("PDF Import") {
                    HStack {
                        Text(pickedPDF.isEmpty ? "Keine PDF ausgewählt" : pickedPDF)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer()
                        Button("PDF wählen") { importFromPDF() }
                        Button("Aus Zwischenablage") { importFromClipboard() }
                    }

                    if parsedLineItemsCount > 0 {
                        Text("Positionen erkannt: \(parsedLineItemsCount)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if source == .manual {
                HStack {
                    Spacer()
                    Button("Vorlage kopieren") { copyInvoiceTemplateToClipboard() }
                    Button("Aus Zwischenablage einfügen") { importFromClipboard() }
                }
            }

            GroupBox("Rechnungsdaten") {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    TextField("Bezeichnung", text: $title).modalEditorStyle()
                    TextField("Bezug", text: $referenceNumber).modalEditorStyle()
                    TextField("Rechnungs-Nr.", text: $invoiceNumber).modalEditorStyle()
                    DatePicker("Rechnungsdatum", selection: $issuedAt, displayedComponents: .date)
                    TextField("Kunden-Nr.", text: $customerNumber).modalEditorStyle()
                    TextField("USt-IdNr.", text: $ustIdNr).modalEditorStyle()
                    TextField("Steuernummer", text: $taxNumber).modalEditorStyle()
                        .gridCellColumns(2)
                }
            }
        }
    }

    private var customerStep: some View {
        GroupBox("Firma/Kunde") {
            VStack(alignment: .leading, spacing: 8) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    TextField("Name", text: $customerName).modalEditorStyle()
                    TextField("Straße und Hausnummer", text: $customerStreet).modalEditorStyle()
                    TextField("PLZ und Stadt", text: $customerPostalCity).modalEditorStyle()
                    TextField("Telefon / WhatsApp", text: $customerPhone).modalEditorStyle()
                }

                if let normalizedPhoneHint {
                    Text("WhatsApp-Format: \(normalizedPhoneHint)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var amountStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            GroupBox("Beträge") {
                VStack(spacing: 8) {
                    TextField("Zwischensumme (netto)", text: $netInput).modalEditorStyle()
                    Picker("Ust.", selection: $vatRate) {
                        Text("19%").tag(0.19)
                        Text("7%").tag(0.07)
                        Text("0%").tag(0.0)
                    }
                    .pickerStyle(.segmented)

                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Steuer")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("€ \(vatCalculatedText)")
                                .font(.headline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color.black.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Brutto")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("€ \(grossCalculatedText)")
                                .font(.headline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color.black.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    TextField("Gesamtbetrag (auto)", text: $grossInput)
                        .modalEditorStyle()
                        .disabled(true)
                        .onAppear { grossInput = grossCalculatedText }
                        .onChange(of: netInput) { _ in grossInput = grossCalculatedText }
                        .onChange(of: vatRate) { _ in grossInput = grossCalculatedText }
                }
            }

            GroupBox("Zahlung") {
                VStack(spacing: 8) {
                    TextField("Zahlungsbedingungen", text: $paymentTermsText).modalEditorStyle()
                    TextField("Tage bis Fälligkeit (z.B. 14 oder 21)", text: $paymentTermDaysInput).modalEditorStyle()
                }
            }
        }
    }

    private func importFromPDF() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        pickedPDF = url.lastPathComponent
        if title.isEmpty { title = url.deletingPathExtension().lastPathComponent }

        #if canImport(PDFKit)
        guard let parsed = viewModel.importPDFInvoice(from: url) else { return }
        source = .pdf
        applyParsedInvoice(parsed)
        #endif
    }

    private func importFromClipboard() {
        #if canImport(AppKit)
        guard let clipboardText = NSPasteboard.general.string(forType: .string),
              let parsed = viewModel.importInvoiceFromClipboardText(clipboardText) else { return }
        source = .manual
        applyParsedInvoice(parsed)
        #endif
    }

    private func copyInvoiceTemplateToClipboard() {
        #if canImport(AppKit)
        let template = """
        Bezug:
        Rechnungs-Nr.:
        Rechnungsdatum:
        Kunden-Nr.:
        USt-IdNr.:
        Steuernummer:
        Name:
        Straße und Hausnummer:
        PLZ und Stadt:
        Telefon:
        Zwischensumme (netto):
        Ust. 19%:
        Gesamtbetrag:
        Zahlungsbedingungen: 14 Tage ab Rechnungsdatum.
        """
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(template, forType: .string)
        #endif
    }

    private func applyParsedInvoice(_ parsed: DashboardViewModel.ParsedInvoiceData) {
        type = .ausgangsrechnung
        title = parsed.title
        importedPDFFileName = parsed.storedPDFFileName
        if let net = parsed.netAmount {
            netInput = String(format: "%.2f", net).replacingOccurrences(of: ".", with: ",")
        }
        if let gross = parsed.grossAmount {
            grossInput = String(format: "%.2f", gross).replacingOccurrences(of: ".", with: ",")
        }
        if let parsedVatRate = parsed.vatRate {
            vatRate = parsedVatRate
        }
        issuedAt = parsed.issuedAt ?? Date()
        referenceNumber = parsed.referenceNumber ?? ""
        invoiceNumber = parsed.invoiceNumber ?? ""
        customerNumber = parsed.customerNumber ?? ""
        ustIdNr = parsed.ustIdNr ?? ""
        taxNumber = parsed.taxNumber ?? ""
        customerName = parsed.customerName ?? ""
        customerPhone = parsed.customerPhone ?? ""
        if let fullAddress = parsed.customerAddress {
            let parts = fullAddress.split(separator: ",", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
            customerStreet = parts.first ?? ""
            customerPostalCity = parts.count > 1 ? parts[1] : ""
        }
        paymentTermDaysInput = parsed.paymentTermDays.map(String.init) ?? paymentTermDaysInput
        paymentTermsText = parsed.paymentTermsText ?? paymentTermsText
        parsedLineItemsCount = parsed.lineItems.count
    }
}

private struct OffeneRechnungenSheet: View {
    @ObservedObject var viewModel: DashboardViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ModalSheetContainer(title: "Rechnungen offen", onClose: { dismiss() }) {

            Text("Ausgangsrechnungen")
                .font(.headline)
            List(viewModel.openInvoicesOutgoing) { invoice in
                openInvoiceRow(invoice)
            }
            .appListStyle()
            .frame(minHeight: 180)

            Text("Eingangsrechnungen")
                .font(.headline)
            List(viewModel.openInvoicesIncoming) { invoice in
                openInvoiceRow(invoice)
            }
            .appListStyle()
            .frame(minHeight: 180)
        }
        .frame(minWidth: 760, minHeight: 600)
    }

    private func openInvoiceRow(_ invoice: InvoiceEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(invoice.title)
                Text("\(invoice.type.rawValue) · \(invoice.source.rawValue)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if let number = invoice.invoiceNumber {
                    Text("Nr.: \(number)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let dueStatus = viewModel.dueStatusLabel(for: invoice) {
                    Text(dueStatus)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(viewModel.dueState(for: invoice) == "overdue" ? .red : .orange)
                }
            }
            Spacer()
            Text(viewModel.formatCurrency(invoice.grossAmount))
            if invoice.pdfStoredFileName != nil {
                Button("PDF") {
                    viewModel.openStoredPDF(for: invoice)
                }
                .appSecondaryButtonStyle()
            }
            if invoice.type == .ausgangsrechnung, !invoice.isPaid, invoice.customerPhone != nil {
                Button("WhatsApp") {
                    viewModel.openWhatsAppReminder(for: invoice)
                }
                .appSecondaryButtonStyle()
            }
            Button("Als bezahlt") {
                viewModel.markInvoicePaid(id: invoice.id)
            }
            .appSecondaryButtonStyle()
        }
        .textSelection(.enabled)
    }
}

private struct UmsatzDetailsSheet: View {
    @ObservedObject var viewModel: DashboardViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ModalSheetContainer(title: "Umsatz nach Monat und Gruppen", onClose: { dismiss() }) {
            List {
                ForEach(viewModel.groupedInvoicesByMonth()) { group in
                    Section(group.title) {
                        groupedEntries(for: .ausgangsrechnung, in: group.entries)
                        groupedEntries(for: .eingangsrechnung, in: group.entries)
                    }
                }
            }
            .appListStyle()
        }
        .frame(minWidth: 760, minHeight: 600)
    }

    @ViewBuilder
    private func groupedEntries(for type: InvoiceType, in entries: [InvoiceEntry]) -> some View {
        let filtered = entries.filter { $0.type == type }
        if !filtered.isEmpty {
            Text(type.rawValue)
                .font(.subheadline.weight(.semibold))
            ForEach(filtered) { entry in
                HStack {
                    Text(entry.title)
                    Spacer()
                    Text(viewModel.formatCurrency(entry.netAmount))
                }
                .font(.callout)
            }
        }
    }
}

private struct UmsatzsteuerSheet: View {
    @ObservedObject var viewModel: DashboardViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ModalSheetContainer(title: "Umsatzsteuer Übersicht", onClose: { dismiss() }) {
            List(viewModel.groupedInvoicesByMonth()) { group in
                let output = group.entries.filter { $0.type == .ausgangsrechnung }.reduce(0) { $0 + $1.vatAmount }
                let input = group.entries.filter { $0.type == .eingangsrechnung }.reduce(0) { $0 + $1.vatAmount }
                let payable = output - input
                HStack {
                    Text(group.title)
                    Spacer()
                    Text("Ausgang: \(viewModel.formatCurrency(output))")
                    Text("Eingang: \(viewModel.formatCurrency(input))")
                    Text("Zahllast: \(viewModel.formatCurrency(payable))")
                        .fontWeight(.semibold)
                }
                .font(.footnote)
            }
            .appListStyle()
        }
        .frame(minWidth: 760, minHeight: 520)
    }
}

private struct EinnahmenSheet: View {
    @ObservedObject var viewModel: DashboardViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ModalSheetContainer(title: "Einnahmen (bezahlt, netto)", onClose: { dismiss() }) {
            List(viewModel.paidOutgoingInvoices) { invoice in
                HStack {
                    VStack(alignment: .leading) {
                        Text(invoice.title)
                        Text("Bezahlt am: \((invoice.paidAt ?? invoice.issuedAt).formatted(date: .numeric, time: .omitted))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(viewModel.formatCurrency(invoice.netAmount))
                        .fontWeight(.semibold)
                }
            }
            .appListStyle()
        }
        .frame(minWidth: 760, minHeight: 520)
    }
}

private struct FixkostenSheet: View {
    @ObservedObject var viewModel: DashboardViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showAddForm = false
    @State private var editingEntry: FixkostenEntry?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Fixkosten")
                        .font(.title.bold())
                    Spacer()

                    Button {
                        showAddForm = true
                    } label: {
                        Label("Hinzufügen", systemImage: "plus")
                    }
                    .appPrimaryButtonStyle()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .closeIconButtonStyle()
                    .help("Schließen")
                }

                Text("Doppelklick auf eine Zeile, um sie zu bearbeiten.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                List {
                    ForEach(viewModel.fixkostenEntries) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.name)
                                .font(.headline)
                            Text(entry.description)
                                .foregroundStyle(.secondary)
                            Text("Netto: \(viewModel.formatCurrency(entry.netAmount)) · MwSt \(entry.vatLabel): \(viewModel.formatCurrency(entry.vatAmount)) · Brutto: \(viewModel.formatCurrency(entry.grossAmount))")
                                .font(.callout)
                            Text("Intervall: \(entry.cycle.rawValue) · Automatisch: \(entry.automaticDebit ? "Ja" : "Nein")")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            editingEntry = entry
                        }
                    }
                }
                .appListStyle()
            }
            .padding(20)
        }
        .frame(minWidth: 780, minHeight: 560)
        .sheet(isPresented: $showAddForm) {
            AddFixkostenForm(viewModel: viewModel)
                .presentationDetents([.medium])
                .interactiveDismissDisabled(false)
        }
        .sheet(item: $editingEntry) { entry in
            EditFixkostenForm(viewModel: viewModel, entry: entry)
                .presentationDetents([.medium])
                .interactiveDismissDisabled(false)
        }
    }
}

private struct AddFixkostenForm: View {
    @ObservedObject var viewModel: DashboardViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var cycle: BillingCycle = .monatlich
    @State private var automaticDebit = true
    @State private var netInput = ""
    @State private var vatRate: Double = 0.19
    @State private var description = ""

    private var netAmount: Double {
        Double(netInput.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var vatAmount: Double {
        netAmount * vatRate
    }

    private var grossAmount: Double {
        netAmount + vatAmount
    }

    var body: some View {
        FixkostenFormContent(
            title: "Neue Fixkosten",
            name: $name,
            cycle: $cycle,
            automaticDebit: $automaticDebit,
            netInput: $netInput,
            vatRate: $vatRate,
            description: $description,
            vatAmountText: viewModel.formatCurrency(vatAmount),
            grossAmountText: viewModel.formatCurrency(grossAmount),
            onClose: { dismiss() },
            onCancel: { dismiss() },
            onSave: {
                let entry = FixkostenEntry(
                    name: name.isEmpty ? "Neue Position" : name,
                    cycle: cycle,
                    automaticDebit: automaticDebit,
                    netAmount: netAmount,
                    vatRate: vatRate,
                    description: description
                )
                viewModel.addFixkostenEntry(entry)
                dismiss()
            },
            isSaveDisabled: netAmount <= 0
        )
    }
}

private struct EditFixkostenForm: View {
    @ObservedObject var viewModel: DashboardViewModel
    @Environment(\.dismiss) private var dismiss

    let entry: FixkostenEntry

    @State private var name = ""
    @State private var cycle: BillingCycle = .monatlich
    @State private var automaticDebit = true
    @State private var netInput = ""
    @State private var vatRate: Double = 0.19
    @State private var description = ""

    private var netAmount: Double {
        Double(netInput.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var vatAmount: Double {
        netAmount * vatRate
    }

    private var grossAmount: Double {
        netAmount + vatAmount
    }

    var body: some View {
        FixkostenFormContent(
            title: "Fixkosten bearbeiten",
            name: $name,
            cycle: $cycle,
            automaticDebit: $automaticDebit,
            netInput: $netInput,
            vatRate: $vatRate,
            description: $description,
            vatAmountText: viewModel.formatCurrency(vatAmount),
            grossAmountText: viewModel.formatCurrency(grossAmount),
            onClose: { dismiss() },
            onCancel: { dismiss() },
            onSave: {
                let updated = FixkostenEntry(
                    id: entry.id,
                    name: name,
                    cycle: cycle,
                    automaticDebit: automaticDebit,
                    netAmount: netAmount,
                    vatRate: vatRate,
                    description: description
                )
                viewModel.updateFixkostenEntry(updated)
                dismiss()
            },
            isSaveDisabled: name.isEmpty || netAmount <= 0
        )
        .onAppear {
            name = entry.name
            cycle = entry.cycle
            automaticDebit = entry.automaticDebit
            netInput = String(format: "%.2f", entry.netAmount).replacingOccurrences(of: ".", with: ",")
            vatRate = entry.vatRate
            description = entry.description
        }
    }
}

private struct FixkostenFormContent: View {
    let title: String

    @Binding var name: String
    @Binding var cycle: BillingCycle
    @Binding var automaticDebit: Bool
    @Binding var netInput: String
    @Binding var vatRate: Double
    @Binding var description: String

    let vatAmountText: String
    let grossAmountText: String
    let onClose: () -> Void
    let onCancel: () -> Void
    let onSave: () -> Void
    let isSaveDisabled: Bool

    var body: some View {
        ModalSheetContainer(title: title, onClose: onClose) {

            TextField("Name", text: $name)
                .modalEditorStyle()

            Picker("Intervall", selection: $cycle) {
                ForEach(BillingCycle.allCases) { interval in
                    Text(interval.rawValue).tag(interval)
                }
            }
            .pickerStyle(.segmented)

            Toggle("Automatische Abbuchung", isOn: $automaticDebit)

            TextField("Summe Netto", text: $netInput)
                .modalEditorStyle()

            Picker("MwSt", selection: $vatRate) {
                Text("19%").tag(0.19)
                Text("7%").tag(0.07)
                Text("0%").tag(0.0)
            }
            .pickerStyle(.segmented)

            HStack {
                Text("MwSt")
                Spacer()
                Text(vatAmountText)
            }

            HStack {
                Text("Brutto")
                Spacer()
                Text(grossAmountText)
                    .fontWeight(.semibold)
            }

            TextField("Beschreibung", text: $description, axis: .vertical)
                .modalEditorStyle()
                .lineLimit(2...4)

            HStack {
                Spacer()
                Button("Abbrechen", role: .cancel, action: onCancel)
                Button("Speichern", action: onSave)
                    .appPrimaryButtonStyle()
                    .disabled(isSaveDisabled)
            }
        }
        .frame(width: 500)
    }
}

private struct ModalSheetContainer<Content: View>: View {
    let title: String
    var onClose: (() -> Void)?
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title)
                    .font(.title3.bold())
                Spacer()
                if let onClose {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                    }
                    .closeIconButtonStyle()
                    .help("Schließen")
                }
            }

            content()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.975, green: 0.978, blue: 0.986))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
}

private extension View {
    func appPrimaryButtonStyle() -> some View {
        buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .tint(Color(red: 0.24, green: 0.33, blue: 0.47))
    }

    func appSecondaryButtonStyle() -> some View {
        buttonStyle(.bordered)
            .controlSize(.regular)
            .foregroundStyle(Color.black.opacity(0.8))
    }

    func closeIconButtonStyle() -> some View {
        buttonStyle(.plain)
            .padding(8)
            .background(Color.black.opacity(0.06), in: Circle())
    }

    func modalEditorStyle() -> some View {
        textFieldStyle(.plain)
            .font(.system(size: 16, weight: .medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(red: 0.985, green: 0.988, blue: 0.995))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.black.opacity(0.16), lineWidth: 1)
            )
    }

    func appListStyle() -> some View {
        scrollContentBackground(.hidden)
            .background(Color.clear)
            .listStyle(.inset)
    }
}
