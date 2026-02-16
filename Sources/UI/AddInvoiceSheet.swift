import SwiftUI
import AppKit

enum AddInvoiceStep: String, CaseIterable, Identifiable {
    case basis = "Basis"
    case kunde = "Kunde"
    case betrag = "Betrag & Zahlung"

    var id: String { rawValue }
}

struct AddInvoiceSheet: View {
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

    private var formColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 12, alignment: .top),
            GridItem(.flexible(), spacing: 12, alignment: .top)
        ]
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
                    .appSegmentedStyle()

                    Picker("Typ", selection: $type) {
                        ForEach(InvoiceType.allCases) { value in
                            Text(value.rawValue).tag(value)
                        }
                    }
                    .appSegmentedStyle()
                }

                Picker("Schritt", selection: $step) {
                    ForEach(AddInvoiceStep.allCases) { value in
                        Text(value.rawValue).tag(value)
                    }
                }
                .appSegmentedStyle()

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
                                .foregroundStyle(AppPalette.textSecondary)
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
                        .appSecondaryButtonStyle()
                        .frame(minWidth: 140)

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
                    .frame(minWidth: 140)
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
                            .foregroundStyle(AppPalette.textSecondary)
                            .lineLimit(1)
                        Spacer()
                        Button("PDF wählen") { importFromPDF() }
                            .appSmallActionButtonStyle()
                        Button("Aus Zwischenablage") { importFromClipboard() }
                            .appSmallActionButtonStyle()
                    }

                    if parsedLineItemsCount > 0 {
                        Text("Positionen erkannt: \(parsedLineItemsCount)")
                            .font(.footnote)
                            .foregroundStyle(AppPalette.textSecondary)
                    }
                }
                .appFormGroupStyle()
            }

            if source == .manual {
                HStack {
                    Spacer()
                    Button("Vorlage kopieren") { copyInvoiceTemplateToClipboard() }
                        .appSmallActionButtonStyle()
                    Button("Aus Zwischenablage einfügen") { importFromClipboard() }
                        .appSmallActionButtonStyle()
                }
            }

            GroupBox("Rechnungsdaten") {
                LazyVGrid(columns: formColumns, spacing: 10) {
                    TextField("Bezeichnung", text: $title).modalEditorStyle()
                    TextField("Bezug", text: $referenceNumber).modalEditorStyle()
                    TextField("Rechnungs-Nr.", text: $invoiceNumber).modalEditorStyle()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Rechnungsdatum")
                            .font(.callout.weight(.medium))
                            .foregroundStyle(AppPalette.textSecondary)
                        DatePicker("", selection: $issuedAt, displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.field)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(AppPalette.inputSurface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(AppPalette.borderStrong, lineWidth: 1)
                            )
                    }

                    TextField("Kunden-Nr.", text: $customerNumber).modalEditorStyle()
                    TextField("USt-IdNr.", text: $ustIdNr).modalEditorStyle()
                    TextField("Steuernummer", text: $taxNumber).modalEditorStyle()
                        .gridCellColumns(2)
                }
            }
            .appFormGroupStyle()
            .foregroundStyle(AppPalette.textPrimary)
        }
    }

    private var customerStep: some View {
        GroupBox("Firma/Kunde") {
            VStack(alignment: .leading, spacing: 8) {
                LazyVGrid(columns: formColumns, spacing: 10) {
                    TextField("Name", text: $customerName).modalEditorStyle()
                    TextField("Straße und Hausnummer", text: $customerStreet).modalEditorStyle()
                    TextField("PLZ und Stadt", text: $customerPostalCity).modalEditorStyle()
                    TextField("Telefon / WhatsApp", text: $customerPhone).modalEditorStyle()
                }

                if let normalizedPhoneHint {
                    Text("WhatsApp-Format: \(normalizedPhoneHint)")
                        .font(.footnote)
                        .foregroundStyle(AppPalette.textSecondary)
                }
            }
        }
        .appFormGroupStyle()
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
                    .appSegmentedStyle()

                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Steuer")
                                .font(.caption)
                                .foregroundStyle(AppPalette.textSecondary)
                            Text("€ \(vatCalculatedText)")
                                .font(.headline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(AppPalette.inputSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Brutto")
                                .font(.caption)
                                .foregroundStyle(AppPalette.textSecondary)
                            Text("€ \(grossCalculatedText)")
                                .font(.headline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(AppPalette.inputSurface)
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
            .appFormGroupStyle()

            GroupBox("Zahlung") {
                VStack(spacing: 8) {
                    TextField("Zahlungsbedingungen", text: $paymentTermsText).modalEditorStyle()
                    TextField("Tage bis Fälligkeit (z.B. 14 oder 21)", text: $paymentTermDaysInput).modalEditorStyle()
                }
            }
            .appFormGroupStyle()
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

