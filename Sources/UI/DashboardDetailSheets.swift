import SwiftUI

struct OffeneRechnungenSheet: View {
    @ObservedObject var viewModel: DashboardViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var editingInvoice: InvoiceEntry?
    @State private var invoiceToDelete: InvoiceEntry?

    var body: some View {
        ModalSheetContainer(title: "Rechnungen offen", onClose: { dismiss() }) {

            Text("Ausgangsrechnungen")
                .font(.headline)
            List(viewModel.openInvoicesOutgoing) { invoice in
                openInvoiceRow(invoice)
            }
            .appListStyle()
            .foregroundStyle(AppPalette.textPrimary)
            .frame(minHeight: 180)

            Text("Eingangsrechnungen")
                .font(.headline)
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

    private func openInvoiceRow(_ invoice: InvoiceEntry) -> some View {
        HStack(spacing: 10) {
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

            Spacer(minLength: 12)

            Text(viewModel.formatCurrency(invoice.grossAmount))
                .fontWeight(.semibold)

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
            Button("Bearbeiten") {
                editingInvoice = invoice
            }
            .appSecondaryButtonStyle()

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
        .textSelection(.enabled)
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

    @State private var title: String
    @State private var invoiceNumber: String
    @State private var customerName: String
    @State private var netInput: String
    @State private var vatRate: Double
    @State private var issuedAt: Date

    init(viewModel: DashboardViewModel, invoice: InvoiceEntry) {
        self.viewModel = viewModel
        self.invoice = invoice
        _title = State(initialValue: invoice.title)
        _invoiceNumber = State(initialValue: invoice.invoiceNumber ?? "")
        _customerName = State(initialValue: invoice.customerName ?? "")
        _netInput = State(initialValue: String(format: "%.2f", invoice.netAmount).replacingOccurrences(of: ".", with: ","))
        _vatRate = State(initialValue: invoice.vatRate)
        _issuedAt = State(initialValue: invoice.issuedAt)
    }

    private var netAmount: Double {
        Double(netInput.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    var body: some View {
        ModalSheetContainer(title: "Rechnung bearbeiten", onClose: { dismiss() }) {
            VStack(alignment: .leading, spacing: 10) {
                TextField("Bezeichnung", text: $title)
                    .modalEditorStyle()

                TextField("Rechnungs-Nr.", text: $invoiceNumber)
                    .modalEditorStyle()

                TextField("Kunde", text: $customerName)
                    .modalEditorStyle()

                DatePicker("Rechnungsdatum", selection: $issuedAt, displayedComponents: .date)

                TextField("Netto", text: $netInput)
                    .modalEditorStyle()

                Picker("MwSt", selection: $vatRate) {
                    Text("19%").tag(0.19)
                    Text("7%").tag(0.07)
                    Text("0%").tag(0.0)
                }
                .appSegmentedStyle()

                HStack {
                    Spacer()
                    Button("Abbrechen", role: .cancel) { dismiss() }
                        .appSecondaryButtonStyle()
                    Button("Speichern") {
                        var updated = invoice
                        updated.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? invoice.title : title
                        updated.invoiceNumber = invoiceNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : invoiceNumber
                        updated.customerName = customerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : customerName
                        updated.netAmount = max(0, netAmount)
                        updated.vatRate = vatRate
                        updated.issuedAt = issuedAt
                        viewModel.updateInvoice(updated)
                        dismiss()
                    }
                    .appPrimaryButtonStyle()
                    .disabled(netAmount <= 0)
                }
            }
        }
        .frame(minWidth: 560)
    }
}
