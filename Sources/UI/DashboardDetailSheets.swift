import SwiftUI

struct OffeneRechnungenSheet: View {
    @ObservedObject var viewModel: DashboardViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var editingInvoice: InvoiceEntry?
    @State private var invoiceToDelete: InvoiceEntry?

    private let amountColumnWidth: CGFloat = 150
    private let actionsColumnWidth: CGFloat = 320

    var body: some View {
        ModalSheetContainer(title: "Rechnungen offen", onClose: { dismiss() }) {

            Text("Doppelklick auf eine Rechnungszeile zum Bearbeiten.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text("Ausgangsrechnungen")
                .font(.headline)
            invoiceListHeader
            List(viewModel.openInvoicesOutgoing) { invoice in
                openInvoiceRow(invoice)
            }
            .appListStyle()
            .foregroundStyle(AppPalette.textPrimary)
            .frame(minHeight: 180)

            Text("Eingangsrechnungen")
                .font(.headline)
            invoiceListHeader
            List(viewModel.openInvoicesIncoming) { invoice in
                openInvoiceRow(invoice)
            }
            .appListStyle()
            .foregroundStyle(AppPalette.textPrimary)
            .frame(minHeight: 180)
        }
        .frame(minWidth: 860, minHeight: 620)
        .sheet(item: $editingInvoice) { invoice in
            EditInvoiceSheet(viewModel: viewModel, invoice: invoice)
                .presentationDetents([.medium, .large])
        }
        .alert("Rechnung löschen?", isPresented: Binding(get: { invoiceToDelete != nil }, set: { if !$0 { invoiceToDelete = nil } })) {
            Button("Löschen", role: .destructive) {
                if let id = invoiceToDelete?.id {
                    viewModel.deleteInvoice(id: id)
                }
                invoiceToDelete = nil
            }
            Button("Abbrechen", role: .cancel) { invoiceToDelete = nil }
        } message: {
            Text("Diese Rechnung wird dauerhaft gelöscht.")
        }
    }

    private var invoiceListHeader: some View {
        HStack(spacing: 10) {
            Text("Rechnung")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppPalette.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Betrag")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppPalette.textSecondary)
                .frame(width: amountColumnWidth, alignment: .trailing)

            Text("Aktionen")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppPalette.textSecondary)
                .frame(width: actionsColumnWidth, alignment: .trailing)
        }
        .padding(.horizontal, 8)
    }

    private func openInvoiceRow(_ invoice: InvoiceEntry) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(invoice.title)
                    .lineLimit(1)
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
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(viewModel.formatCurrency(invoice.grossAmount))
                .fontWeight(.semibold)
                .monospacedDigit()
                .frame(width: amountColumnWidth, alignment: .trailing)

            HStack(spacing: 8) {
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

                Button {
                    invoiceToDelete = invoice
                } label: {
                    Image(systemName: "xmark")
                }
                .closeIconButtonStyle()
                .help("Rechnung löschen")
            }
            .frame(width: actionsColumnWidth, alignment: .trailing)
        }
        .textSelection(.enabled)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            editingInvoice = invoice
        }
    }
}

struct UmsatzDetailsSheet: View {
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
            .foregroundStyle(AppPalette.textPrimary)
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

struct UmsatzsteuerSheet: View {
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
            .foregroundStyle(AppPalette.textPrimary)
        }
        .frame(minWidth: 760, minHeight: 520)
    }
}

struct EinnahmenSheet: View {
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
            .foregroundStyle(AppPalette.textPrimary)
        }
        .frame(minWidth: 760, minHeight: 520)
    }
}

private struct EditInvoiceSheet: View {
    @ObservedObject var viewModel: DashboardViewModel
    @Environment(\.dismiss) private var dismiss

    let invoice: InvoiceEntry

    @State private var source: InvoiceSource
    @State private var type: InvoiceType
    @State private var title: String
    @State private var referenceNumber: String
    @State private var invoiceNumber: String
    @State private var customerNumber: String
    @State private var ustIdNr: String
    @State private var taxNumber: String
    @State private var customerName: String
    @State private var customerAddress: String
    @State private var customerPhone: String
    @State private var netInput: String
    @State private var vatRate: Double
    @State private var issuedAt: Date
    @State private var paymentTermDaysInput: String
    @State private var paymentTermsText: String

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 12, alignment: .top),
        GridItem(.flexible(), spacing: 12, alignment: .top)
    ]

    init(viewModel: DashboardViewModel, invoice: InvoiceEntry) {
        self.viewModel = viewModel
        self.invoice = invoice
        _source = State(initialValue: invoice.source)
        _type = State(initialValue: invoice.type)
        _title = State(initialValue: invoice.title)
        _referenceNumber = State(initialValue: invoice.referenceNumber ?? "")
        _invoiceNumber = State(initialValue: invoice.invoiceNumber ?? "")
        _customerNumber = State(initialValue: invoice.customerNumber ?? "")
        _ustIdNr = State(initialValue: invoice.ustIdNr ?? "")
        _taxNumber = State(initialValue: invoice.taxNumber ?? "")
        _customerName = State(initialValue: invoice.customerName ?? "")
        _customerAddress = State(initialValue: invoice.customerAddress ?? "")
        _customerPhone = State(initialValue: invoice.customerPhone ?? "")
        _netInput = State(initialValue: String(format: "%.2f", invoice.netAmount).replacingOccurrences(of: ".", with: ","))
        _vatRate = State(initialValue: invoice.vatRate)
        _issuedAt = State(initialValue: invoice.issuedAt)
        _paymentTermDaysInput = State(initialValue: invoice.paymentTermDays.map(String.init) ?? "")
        _paymentTermsText = State(initialValue: invoice.paymentTermsText ?? "")
    }

    private var netAmount: Double {
        Double(netInput.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var paymentTermDays: Int? {
        let trimmed = paymentTermDaysInput.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : Int(trimmed)
    }

    private var isTitleInvalid: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isInvoiceNumberInvalid: Bool {
        invoiceNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isCustomerNameInvalid: Bool {
        customerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isNetAmountInvalid: Bool {
        netAmount <= 0
    }

    private var isPaymentTermDaysInvalid: Bool {
        type == .ausgangsrechnung && paymentTermDays == nil
    }

    private var isSaveDisabled: Bool {
        isTitleInvalid || isInvoiceNumberInvalid || isCustomerNameInvalid || isNetAmountInvalid || isPaymentTermDaysInvalid
    }

    var body: some View {
        ModalSheetContainer(title: "Rechnung bearbeiten", onClose: { dismiss() }) {
            VStack(alignment: .leading, spacing: 12) {
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

                GroupBox("Rechnungsdaten") {
                    LazyVGrid(columns: columns, spacing: 10) {
                        TextField("Bezeichnung", text: $title)
                            .modalEditorStyle()
                            .appValidationHighlight(isTitleInvalid)
                        TextField("Bezug", text: $referenceNumber)
                            .modalEditorStyle()

                        TextField("Rechnungs-Nr.", text: $invoiceNumber)
                            .modalEditorStyle()
                            .appValidationHighlight(isInvoiceNumberInvalid)
                        DatePicker("Rechnungsdatum", selection: $issuedAt, displayedComponents: .date)

                        TextField("Kunden-Nr.", text: $customerNumber)
                            .modalEditorStyle()
                        TextField("USt-IdNr.", text: $ustIdNr)
                            .modalEditorStyle()

                        TextField("Steuernummer", text: $taxNumber)
                            .modalEditorStyle()
                            .gridCellColumns(2)
                    }
                }
                .appFormGroupStyle()

                GroupBox("Kunde") {
                    VStack(spacing: 10) {
                        TextField("Name", text: $customerName)
                            .modalEditorStyle()
                            .appValidationHighlight(isCustomerNameInvalid)
                        TextField("Adresse", text: $customerAddress)
                            .modalEditorStyle()
                        TextField("Telefon", text: $customerPhone)
                            .modalEditorStyle()
                    }
                }
                .appFormGroupStyle()

                GroupBox("Betrag & Zahlung") {
                    VStack(spacing: 10) {
                        TextField("Netto", text: $netInput)
                            .modalEditorStyle()
                            .appValidationHighlight(isNetAmountInvalid)

                        Picker("MwSt", selection: $vatRate) {
                            Text("19%").tag(0.19)
                            Text("7%").tag(0.07)
                            Text("0%").tag(0.0)
                        }
                        .appSegmentedStyle()

                        TextField("Zahlungsbedingungen", text: $paymentTermsText)
                            .modalEditorStyle()

                        TextField("Tage bis Fälligkeit", text: $paymentTermDaysInput)
                            .modalEditorStyle()
                            .appValidationHighlight(isPaymentTermDaysInvalid)
                    }
                }
                .appFormGroupStyle()

                HStack {
                    Spacer()
                    Button("Abbrechen", role: .cancel) { dismiss() }
                        .appSecondaryButtonStyle()
                    Button("Speichern") {
                        var updated = invoice
                        updated.source = source
                        updated.type = type
                        updated.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? invoice.title : title
                        updated.referenceNumber = referenceNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : referenceNumber
                        updated.invoiceNumber = invoiceNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : invoiceNumber
                        updated.customerNumber = customerNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : customerNumber
                        updated.ustIdNr = ustIdNr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : ustIdNr
                        updated.taxNumber = taxNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : taxNumber
                        updated.customerName = customerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : customerName
                        updated.customerAddress = customerAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : customerAddress
                        updated.customerPhone = viewModel.normalizedPhoneForMessaging(customerPhone)
                        updated.netAmount = max(0, netAmount)
                        updated.vatRate = vatRate
                        updated.issuedAt = issuedAt
                        updated.paymentTermsText = paymentTermsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : paymentTermsText
                        updated.paymentTermDays = paymentTermDays
                        viewModel.updateInvoice(updated)
                        dismiss()
                    }
                    .appPrimaryButtonStyle()
                    .disabled(isSaveDisabled)
                }
            }
        }
        .frame(minWidth: 720)
    }
}
