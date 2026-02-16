import SwiftUI

struct OffeneRechnungenSheet: View {
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
        }
        .frame(minWidth: 760, minHeight: 520)
    }
}

