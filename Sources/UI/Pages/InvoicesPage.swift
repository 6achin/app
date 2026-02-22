import SwiftUI

struct InvoicesPage: View {
    @ObservedObject var router: BAAppRouter
    @ObservedObject var viewModel: DashboardViewModel
    @State private var search = ""

    private var baseFiltered: [InvoiceEntry] {
        let text = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return viewModel.invoices.filter { invoice in
            if let month = router.invoiceMonthFilter,
               !Calendar.current.isDate(viewModel.startOfMonth(for: invoice.issuedAt), equalTo: month, toGranularity: .month) {
                return false
            }

            switch router.invoiceFilterStatus {
            case .open:
                if invoice.isPaid { return false }
            case .paid:
                if !invoice.isPaid { return false }
            case .all:
                break
            }

            guard !text.isEmpty else { return true }
            let haystack = [
                invoice.title,
                invoice.invoiceNumber ?? "",
                invoice.customerName ?? "",
                invoice.customerAddress ?? "",
                invoice.customerPhone ?? ""
            ].joined(separator: " ").lowercased()
            return haystack.contains(text)
        }
    }

    private var monthlyOpenRows: [MonthlyOpenRow] {
        let grouped = Dictionary(grouping: viewModel.invoices) { viewModel.startOfMonth(for: $0.issuedAt) }

        return grouped.keys.sorted(by: >).map { month in
            let entries = grouped[month] ?? []
            let open = entries.filter { !$0.isPaid }
            let paid = entries.filter { $0.isPaid }
            let total = entries.reduce(0) { $0 + $1.grossAmount }
            return MonthlyOpenRow(monthStart: month, totalCount: entries.count, totalAmount: total, openCount: open.count, paidCount: paid.count)
        }
    }

    var body: some View {
        AppShell {
            VStack(alignment: .leading, spacing: 12) {
                PageHeader(title: "Rechnungen", subtitle: "Liste", onBack: { router.setTop(.dashboard) })

                HStack {
                    TextField("Suche", text: $search).dsInput()
                    Button("Neue Rechnung") { router.push(.addInvoice) }.dsPrimaryButton()
                }

                HStack(spacing: 8) {
                    filterButton("Offen", .open)
                    filterButton("Bezahlt", .paid)
                    filterButton("Alle", .all)
                    if router.invoiceMonthFilter != nil {
                        Button("Monat löschen") { router.invoiceMonthFilter = nil }
                            .dsSecondaryButton()
                    }
                }

                if router.invoiceOpenMonthlyMode {
                    monthlyOpenTable
                } else {
                    invoicesTable
                }
            }
            .padding(18)
        }
    }

    private var monthlyOpenTable: some View {
        DSCard {
            VStack(spacing: 0) {
                HStack {
                    Text("Monat (YYYY-MM)").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Rechnungen").frame(width: 100, alignment: .trailing)
                    Text("Summe").frame(width: 140, alignment: .trailing)
                    Text("Offen / Bezahlt").frame(width: 150, alignment: .trailing)
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .padding(.bottom, 8)

                ForEach(monthlyOpenRows) { row in
                    Button {
                        router.openInvoicesForOpenMonth(row.monthStart)
                    } label: {
                        HStack {
                            Text(row.label).frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(row.totalCount)").frame(width: 100, alignment: .trailing)
                            Text(viewModel.formatCurrency(row.totalAmount)).frame(width: 140, alignment: .trailing)
                            Text("\(row.openCount) / \(row.paidCount)").frame(width: 150, alignment: .trailing)
                        }
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)

                    Divider().overlay(Theme.border)
                }
            }
        }
    }

    private var invoicesTable: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                tableHeader
                ForEach(baseFiltered) { invoice in
                    invoiceRow(invoice)
                }
            }
        }
    }

    private var tableHeader: some View {
        DSCard {
            HStack(spacing: 10) {
                Text("Nr.").frame(width: 90, alignment: .leading)
                Text("Name").frame(width: 140, alignment: .leading)
                Text("Adresse").frame(width: 180, alignment: .leading)
                Text("Kontakt").frame(width: 120, alignment: .leading)
                Text("Betrag").frame(width: 110, alignment: .trailing)
                Text("Frist").frame(width: 120, alignment: .leading)
                Text("Erstellt").frame(width: 90, alignment: .leading)
                Text("Bezahlt").frame(width: 90, alignment: .leading)
                Text("Status").frame(width: 70, alignment: .leading)
                Text("PDF").frame(width: 54, alignment: .center)
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.textSecondary)
        }
    }

    private func invoiceRow(_ invoice: InvoiceEntry) -> some View {
        let dueLabel = viewModel.dueDate(for: invoice)?.formatted(date: .numeric, time: .omitted) ?? "-"
        let paidLabel = invoice.paidAt?.formatted(date: .numeric, time: .omitted) ?? "-"
        let createdLabel = invoice.issuedAt.formatted(date: .numeric, time: .omitted)
        let address = (invoice.customerAddress ?? "-").replacingOccurrences(of: "\n", with: ", ")
        let contact = invoice.customerPhone ?? "-"

        return DSCard {
            HStack(spacing: 10) {
                HStack(spacing: 10) {
                    Text(invoice.invoiceNumber ?? "-").frame(width: 90, alignment: .leading)
                    Text(invoice.customerName ?? invoice.title).frame(width: 140, alignment: .leading)
                    Text(address).lineLimit(1).frame(width: 180, alignment: .leading)
                    Text(contact).lineLimit(1).frame(width: 120, alignment: .leading)
                    Text(viewModel.formatCurrency(invoice.grossAmount)).monospacedDigit().frame(width: 110, alignment: .trailing)
                    Text(dueLabel).frame(width: 120, alignment: .leading)
                    Text(createdLabel).frame(width: 90, alignment: .leading)
                    Text(paidLabel).frame(width: 90, alignment: .leading)
                    Text(invoice.isPaid ? "Bezahlt" : "Offen")
                        .foregroundStyle(invoice.isPaid ? Theme.success : Theme.danger)
                        .frame(width: 70, alignment: .leading)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    router.push(.invoiceDetail(invoice.id))
                }

                Button("PDF") {
                    viewModel.openStoredPDF(for: invoice)
                }
                .dsSecondaryButton()
                .frame(width: 54)
                .disabled(invoice.pdfStoredFileName == nil)
            }
            .font(.system(size: 12))
            .foregroundStyle(Theme.textPrimary)
        }
    }

    private func filterButton(_ title: String, _ status: InvoiceFilterStatus) -> some View {
        Button(title) {
            router.invoiceFilterStatus = status
            router.invoiceOpenMonthlyMode = false
        }
        .dsSecondaryButton()
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(router.invoiceFilterStatus == status ? Theme.accent : .clear, lineWidth: 1)
        )
    }
}

private struct MonthlyOpenRow: Identifiable {
    let id = UUID()
    let monthStart: Date
    let totalCount: Int
    let totalAmount: Double
    let openCount: Int
    let paidCount: Int

    var label: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: monthStart)
    }
}

struct InvoiceDetailPage: View {
    @ObservedObject var router: BAAppRouter
    @ObservedObject var viewModel: DashboardViewModel
    let invoiceID: UUID

    private var invoice: InvoiceEntry? {
        viewModel.invoices.first(where: { $0.id == invoiceID })
    }

    var body: some View {
        AppShell {
            VStack(alignment: .leading, spacing: 12) {
                PageHeader(title: "Rechnungsdetail", subtitle: invoice?.title, onBack: { router.pop() })
                if let invoice {
                    DSCard {
                        VStack(alignment: .leading, spacing: 8) {
                            row("Nummer", invoice.invoiceNumber ?? "-")
                            row("Typ", invoice.type.rawValue)
                            row("Quelle", invoice.source.rawValue)
                            row("Netto", viewModel.formatCurrency(invoice.netAmount))
                            row("Brutto", viewModel.formatCurrency(invoice.grossAmount))
                        }
                    }
                }
                Spacer()
            }
            .padding(18)
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value).foregroundStyle(Theme.textPrimary)
        }
    }
}

struct AddInvoicePage: View {
    @ObservedObject var router: BAAppRouter
    @ObservedObject var viewModel: DashboardViewModel

    @State private var title = ""
    @State private var number = ""
    @State private var net = ""

    var body: some View {
        AppShell {
            VStack(alignment: .leading, spacing: 12) {
                PageHeader(title: "Neue Rechnung", subtitle: "Anlegen", onBack: { router.pop() })
                DSCard {
                    VStack(spacing: 10) {
                        TextField("Bezeichnung", text: $title).dsInput()
                        TextField("Rechnungs-Nr.", text: $number).dsInput()
                        TextField("Netto", text: $net).dsInput()

                        HStack {
                            Spacer()
                            Button("Abbrechen") { router.pop() }.dsSecondaryButton()
                            Button("Speichern") {
                                let amount = Double(net.replacingOccurrences(of: ",", with: ".")) ?? 0
                                let invoice = InvoiceEntry(
                                    title: title.isEmpty ? "Neue Rechnung" : title,
                                    source: .manual,
                                    type: .ausgangsrechnung,
                                    netAmount: amount,
                                    vatRate: 0.19,
                                    isPaid: false,
                                    issuedAt: Date(),
                                    invoiceNumber: number.isEmpty ? nil : number
                                )
                                viewModel.addInvoice(invoice)
                                router.pop()
                            }
                            .dsPrimaryButton()
                            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (Double(net.replacingOccurrences(of: ",", with: ".")) ?? 0) <= 0)
                        }
                    }
                }
                Spacer()
            }
            .padding(18)
        }
    }
}
