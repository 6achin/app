import SwiftUI

struct InvoicesPage: View {
    @ObservedObject var router: BAAppRouter
    @ObservedObject var viewModel: DashboardViewModel
    @Environment(\.uiDensityMode) private var density

    @State private var search = ""
    @State private var debouncedSearch = ""

    @State private var showAddress = true
    @State private var showContact = true
    @State private var showCreated = true
    @State private var showPaid = true

    private var filtered: [InvoiceEntry] {
        let text = debouncedSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

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

            if router.invoiceOverdueOnly,
               viewModel.dueState(for: invoice) != "overdue" {
                return false
            }

            guard !text.isEmpty else { return true }
            let value = [invoice.invoiceNumber ?? "", invoice.customerName ?? "", invoice.customerAddress ?? "", invoice.customerPhone ?? "", invoice.title]
                .joined(separator: " ")
                .lowercased()
            return value.contains(text)
        }
    }


    private var suggestions: [String] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard q.count >= 1 else { return [] }
        let values = viewModel.invoices.flatMap { [
            $0.invoiceNumber ?? "",
            $0.customerName ?? "",
            $0.customerAddress ?? "",
            $0.customerPhone ?? "",
            $0.title
        ] }
        let uniq = Array(Set(values.filter { !$0.isEmpty && $0.lowercased().contains(q) })).sorted()
        return Array(uniq.prefix(6))
    }

    private var monthlyOpenRows: [MonthlyOpenRow] {
        let grouped = Dictionary(grouping: viewModel.invoices) { viewModel.startOfMonth(for: $0.issuedAt) }
        return grouped.keys.sorted(by: >).map { month in
            let entries = grouped[month] ?? []
            return MonthlyOpenRow(
                monthStart: month,
                totalCount: entries.count,
                totalAmount: entries.reduce(0) { $0 + $1.grossAmount },
                openCount: entries.filter { !$0.isPaid }.count,
                paidCount: entries.filter { $0.isPaid }.count
            )
        }
    }

    var body: some View {
        AppShell {
            VStack(alignment: .leading, spacing: density.spacing) {
                PageHeader(title: "Rechnungen", subtitle: "Liste", onBack: { router.setTop(.dashboard) })

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        TextField("Suche", text: $search)
                            .dsInput()
                            .task(id: search) {
                                try? await Task.sleep(nanoseconds: 250_000_000)
                                guard !Task.isCancelled else { return }
                                debouncedSearch = search
                            }

                        Button("Neue Rechnung") { router.push(.addInvoice) }
                            .dsPrimaryButton()
                    }

                    if !suggestions.isEmpty {
                        DSCard {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(suggestions, id: \.self) { item in
                                    Button(item) { search = item; debouncedSearch = item }
                                        .buttonStyle(.plain)
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.textPrimary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }
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
            .padding(density == .compact ? 14 : 20)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var monthlyOpenTable: some View {
        DSCard {
            VStack(spacing: 0) {
                HStack {
                    Text("Monat (YYYY-MM)").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Rechnungen").frame(width: 110, alignment: .trailing)
                    Text("Summe").frame(width: 140, alignment: .trailing)
                    Text("Offen / Bezahlt").frame(width: 150, alignment: .trailing)
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)

                ForEach(monthlyOpenRows) { row in
                    Button {
                        router.openInvoicesForOpenMonth(row.monthStart)
                    } label: {
                        HStack {
                            Text(row.label).frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(row.totalCount)").frame(width: 110, alignment: .trailing)
                            Text(viewModel.formatCurrency(row.totalAmount)).frame(width: 140, alignment: .trailing)
                            Text("\(row.openCount) / \(row.paidCount)").frame(width: 150, alignment: .trailing)
                        }
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.vertical, density.rowPadding)
                    }
                    .buttonStyle(.plain)

                    Divider().overlay(Theme.border)
                }
            }
        }
    }

    private var invoicesTable: some View {
        VStack(spacing: 8) {
            tableHeader

            ScrollView([.vertical, .horizontal]) {
                LazyVStack(spacing: 8) {
                    ForEach(filtered) { invoice in
                        invoiceRow(invoice)
                    }
                }
            }
        }
    }

    private var tableHeader: some View {
        DSCard {
            HStack(spacing: 10) {
                Text("Nr").frame(width: 90, alignment: .leading)
                Text("Name").frame(width: 160, alignment: .leading)
                if showAddress { Text("Adresse").frame(width: 190, alignment: .leading) }
                if showContact { Text("Kontakt").frame(width: 130, alignment: .leading) }
                Text("Betrag").frame(width: 110, alignment: .trailing)
                Text("Frist").frame(width: 110, alignment: .leading)
                if showCreated { Text("Erstellt").frame(width: 90, alignment: .leading) }
                if showPaid { Text("Bezahlt").frame(width: 90, alignment: .leading) }
                Text("Status").frame(width: 78, alignment: .leading)
                Text("PDF").frame(width: 56, alignment: .center)
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.textSecondary)
        }
    }

    private func invoiceRow(_ invoice: InvoiceEntry) -> some View {
        let due = viewModel.dueDate(for: invoice)?.formatted(date: .numeric, time: .omitted) ?? "-"
        let created = invoice.issuedAt.formatted(date: .numeric, time: .omitted)
        let paid = invoice.paidAt?.formatted(date: .numeric, time: .omitted) ?? "-"
        let statusText = invoice.isPaid ? "Bezahlt" : (viewModel.dueState(for: invoice) == "overdue" ? "Überfällig" : "Offen")
        let statusColor = invoice.isPaid ? Theme.success : (viewModel.dueState(for: invoice) == "overdue" ? Theme.danger : Theme.textSecondary)

        return DSCard {
            HStack(spacing: 10) {
                HStack(spacing: 10) {
                    Text(invoice.invoiceNumber ?? "-").frame(width: 90, alignment: .leading)
                    Text(invoice.customerName ?? invoice.title).lineLimit(1).frame(width: 160, alignment: .leading)
                    if showAddress {
                        Text((invoice.customerAddress ?? "-").replacingOccurrences(of: "\n", with: ", ")).lineLimit(1).frame(width: 190, alignment: .leading)
                    }
                    if showContact {
                        Text(invoice.customerPhone ?? "-").lineLimit(1).frame(width: 130, alignment: .leading)
                    }
                    Text(viewModel.formatCurrency(invoice.grossAmount)).monospacedDigit().frame(width: 110, alignment: .trailing)
                    Text(due).frame(width: 110, alignment: .leading)
                    if showCreated { Text(created).frame(width: 90, alignment: .leading) }
                    if showPaid { Text(paid).frame(width: 90, alignment: .leading) }
                    Text(statusText).foregroundStyle(statusColor).frame(width: 78, alignment: .leading)
                }
                .contentShape(Rectangle())
                .onTapGesture { router.push(.invoiceDetail(invoice.id)) }

                Button("PDF") { viewModel.openStoredPDF(for: invoice) }
                    .dsSecondaryButton()
                    .frame(width: 56)
                    .disabled(invoice.pdfStoredFileName == nil)
            }
            .font(.system(size: 12))
            .foregroundStyle(Theme.textPrimary)
            .padding(.vertical, density == .compact ? 0 : 2)
        }
    }

    private func filterButton(_ title: String, _ status: InvoiceFilterStatus) -> some View {
        Button(title) {
            router.invoiceFilterStatus = status
            router.invoiceOpenMonthlyMode = false
            router.invoiceOverdueOnly = false
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
