import SwiftUI

private struct InvoiceMonthKey: Hashable {
    let year: Int
    let month: Int

    var id: String { String(format: "%04d-%02d", year, month) }
}

private enum InlineField: Hashable {
    case dueDate
    case contact
    case status
}

private enum InvoiceInlineStatus: String, CaseIterable, Identifiable {
    case open = "Offen"
    case paid = "Bezahlt"
    case overdue = "Überfällig"

    var id: String { rawValue }
}

struct InvoicesPage: View {
    @ObservedObject var router: BAAppRouter
    @ObservedObject var viewModel: DashboardViewModel
    @Environment(\.uiDensityMode) private var density

    @AppStorage("invoicesSelectedMonth") private var selectedMonthKey = ""

    @State private var search = ""
    @State private var debouncedSearch = ""
    @State private var showMonthPicker = false
    @State private var pickerYear = Calendar.current.component(.year, from: Date())
    @State private var showAddInvoiceModal = false

    @State private var editingCell: (id: UUID, field: InlineField)?
    @State private var editingDueDate = Date()
    @State private var editingContact = ""
    @State private var editingStatus: InvoiceInlineStatus = .open
    @State private var savedFeedbackID: UUID?

    private static let monthStorageFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f
    }()

    private static let monthLabelFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "LLL yyyy"
        return f
    }()

    private var selectedMonth: Date {
        if let date = Self.monthStorageFormatter.date(from: selectedMonthKey) {
            return viewModel.startOfMonth(for: date)
        }
        if let routeMonth = router.invoiceMonthFilter {
            return viewModel.startOfMonth(for: routeMonth)
        }
        return viewModel.startOfMonth(for: Date())
    }

    private var selectedMonthIdentity: InvoiceMonthKey {
        let c = Calendar.current.dateComponents([.year, .month], from: selectedMonth)
        return InvoiceMonthKey(year: c.year ?? 2000, month: c.month ?? 1)
    }

    private var filtered: [InvoiceEntry] {
        let query = debouncedSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return viewModel.invoices.filter { invoice in
            guard Calendar.current.isDate(viewModel.startOfMonth(for: invoice.issuedAt), equalTo: selectedMonth, toGranularity: .month) else {
                return false
            }

            guard !query.isEmpty else { return true }
            let searchable = [
                invoice.invoiceNumber ?? "",
                invoice.customerName ?? "",
                invoice.customerPhone ?? "",
                invoice.customerAddress ?? "",
                invoice.customerNumber ?? "",
                invoice.referenceNumber ?? "",
                invoice.title,
                invoice.paymentTermsText ?? ""
            ]
            .joined(separator: " ")
            .lowercased()
            return searchable.contains(query)
        }
    }

    private var suggestions: [String] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard q.count >= 1 else { return [] }
        let values = filtered.flatMap { [
            $0.invoiceNumber ?? "",
            $0.customerName ?? "",
            $0.customerPhone ?? "",
            $0.customerAddress ?? "",
            $0.customerNumber ?? "",
            $0.title
        ] }
        return Array(Set(values.filter { !$0.isEmpty && $0.lowercased().contains(q) })).sorted().prefix(6).map { $0 }
    }

    private var monthTotalAmount: Double {
        filtered.reduce(0) { $0 + $1.grossAmount }
    }

    var body: some View {
        AppShell {
            VStack(alignment: .leading, spacing: density.spacing) {
                PageHeader(title: "Rechnungen", subtitle: "\(monthLabel(selectedMonth))", onBack: { router.setTop(.dashboard) })

                toolbar

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

                totalsBar
                tableHeader

                ScrollView([.vertical, .horizontal]) {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(filtered) { invoice in
                            invoiceRow(invoice)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .padding(.horizontal, density == .compact ? 14 : 20)
            .padding(.vertical, density == .compact ? 12 : 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .sheet(isPresented: $showAddInvoiceModal) {
            AddInvoiceModal(viewModel: viewModel)
        }
        .onAppear {
            if selectedMonthKey.isEmpty {
                selectedMonthKey = selectedMonthIdentity.id
            }
            pickerYear = selectedMonthIdentity.year
        }
        .task(id: search) {
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled else { return }
            debouncedSearch = search
        }
        .onExitCommand {
            cancelInlineEdit()
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            monthSwitcher
            Spacer()
            TextField("Suche", text: $search)
                .dsInput()
                .frame(width: 360)
            Button {
                showAddInvoiceModal = true
            } label: {
                Image(systemName: "plus")
            }
            .dsPrimaryButton()
            .help("Neue Rechnung")
        }
    }

    private var monthSwitcher: some View {
        HStack(spacing: 8) {
            Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
                .dsSecondaryButton()

            Button { showMonthPicker.toggle() } label: {
                Text(monthLabel(selectedMonth))
            }
            .dsSecondaryButton()
            .popover(isPresented: $showMonthPicker) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Button { pickerYear -= 1 } label: { Image(systemName: "chevron.left") }
                            .buttonStyle(.plain)
                        Text("\(pickerYear)")
                            .font(.headline)
                        Button { pickerYear += 1 } label: { Image(systemName: "chevron.right") }
                            .buttonStyle(.plain)
                        Spacer()
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: 8)], spacing: 8) {
                        ForEach(1...12, id: \.self) { month in
                            Button(shortMonthLabel(month)) {
                                setMonth(InvoiceMonthKey(year: pickerYear, month: month))
                                showMonthPicker = false
                            }
                            .dsSecondaryButton()
                        }
                    }

                    HStack {
                        Button("This month") {
                            let now = monthKey(for: Date())
                            pickerYear = now.year
                            setMonth(now)
                            showMonthPicker = false
                        }
                        .dsSecondaryButton()

                        Button("Last month") {
                            let lastMonthDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
                            let key = monthKey(for: lastMonthDate)
                            pickerYear = key.year
                            setMonth(key)
                            showMonthPicker = false
                        }
                        .dsSecondaryButton()
                    }
                }
                .padding(12)
                .frame(width: 360)
            }

            Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
                .dsSecondaryButton()
        }
    }

    private var totalsBar: some View {
        DSCard {
            HStack {
                Text("Rechnungen: \(filtered.count)")
                Spacer()
                Text("Summe: \(viewModel.formatCurrency(monthTotalAmount))")
                    .monospacedDigit()
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tableHeader: some View {
        DSCard {
            HStack(spacing: 10) {
                Text("Nr").frame(width: 96, alignment: .leading)
                Text("Name").frame(width: 180, alignment: .leading)
                Text("Adresse").frame(width: 220, alignment: .leading)
                Text("Kontakt").frame(width: 160, alignment: .leading)
                Text("Betrag").frame(width: 118, alignment: .trailing)
                Text("Frist").frame(width: 124, alignment: .leading)
                Text("Erstellt").frame(width: 96, alignment: .leading)
                Text("Bezahlt").frame(width: 96, alignment: .leading)
                Text("Status").frame(width: 108, alignment: .leading)
                Text("PDF").frame(width: 56, alignment: .center)
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func invoiceRow(_ invoice: InvoiceEntry) -> some View {
        let dueDate = viewModel.dueDate(for: invoice)
        let dueText = dueDate?.formatted(date: .numeric, time: .omitted) ?? "-"
        let created = invoice.issuedAt.formatted(date: .numeric, time: .omitted)
        let paid = invoice.paidAt?.formatted(date: .numeric, time: .omitted) ?? "-"
        let statusText = statusLabel(for: invoice)
        let statusColor = statusColor(for: invoice)

        return DSCard {
            HStack(spacing: 10) {
                Text(invoice.invoiceNumber ?? "-")
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: 96, alignment: .leading)

                Text(invoice.customerName ?? invoice.title)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: 180, alignment: .leading)

                Text((invoice.customerAddress ?? "-").replacingOccurrences(of: "\n", with: ", "))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: 220, alignment: .leading)

                contactCell(for: invoice)
                    .frame(width: 160, alignment: .leading)

                Text(viewModel.formatCurrency(invoice.grossAmount))
                    .monospacedDigit()
                    .lineLimit(1)
                    .frame(width: 118, alignment: .trailing)

                dueDateCell(for: invoice, dueDate: dueDate, dueText: dueText)
                    .frame(width: 124, alignment: .leading)

                Text(created).frame(width: 96, alignment: .leading)
                Text(paid).frame(width: 96, alignment: .leading)

                statusCell(for: invoice, statusText: statusText, statusColor: statusColor)
                    .frame(width: 108, alignment: .leading)

                Button("PDF") { viewModel.openStoredPDF(for: invoice) }
                    .dsSecondaryButton()
                    .frame(width: 56)
                    .disabled(invoice.pdfStoredFileName == nil)
            }
            .font(.system(size: 12))
            .foregroundStyle(Theme.textPrimary)
            .padding(.vertical, density == .compact ? 0 : 2)
            .overlay(alignment: .trailing) {
                if savedFeedbackID == invoice.id {
                    Text("Gespeichert")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.success)
                        .padding(.trailing, 66)
                }
            }
            .contentShape(Rectangle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func dueDateCell(for invoice: InvoiceEntry, dueDate: Date?, dueText: String) -> some View {
        if editingCell?.id == invoice.id, editingCell?.field == .dueDate {
            DatePicker("", selection: $editingDueDate, displayedComponents: .date)
                .labelsHidden()
                .onChange(of: editingDueDate) { _ in saveInlineEdit(for: invoice) }
        } else {
            Text(dueText)
                .lineLimit(1)
                .truncationMode(.tail)
                .onTapGesture(count: 2) {
                    editingCell = (invoice.id, .dueDate)
                    editingDueDate = dueDate ?? invoice.issuedAt
                }
        }
    }

    @ViewBuilder
    private func contactCell(for invoice: InvoiceEntry) -> some View {
        if editingCell?.id == invoice.id, editingCell?.field == .contact {
            TextField("Kontakt", text: $editingContact)
                .textFieldStyle(.plain)
                .onSubmit { saveInlineEdit(for: invoice) }
        } else {
            Text((invoice.customerPhone ?? "-").isEmpty ? "-" : (invoice.customerPhone ?? "-"))
                .lineLimit(1)
                .truncationMode(.tail)
                .onTapGesture(count: 2) {
                    editingCell = (invoice.id, .contact)
                    editingContact = invoice.customerPhone ?? ""
                }
        }
    }

    @ViewBuilder
    private func statusCell(for invoice: InvoiceEntry, statusText: String, statusColor: Color) -> some View {
        if editingCell?.id == invoice.id, editingCell?.field == .status {
            Picker("", selection: $editingStatus) {
                ForEach(InvoiceInlineStatus.allCases) { status in
                    Text(status.rawValue).tag(status)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .onChange(of: editingStatus) { _ in
                saveInlineEdit(for: invoice)
            }
        } else {
            Text(statusText)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(statusColor.opacity(0.12), in: Capsule())
                .foregroundStyle(statusColor)
                .onTapGesture(count: 2) {
                    editingCell = (invoice.id, .status)
                    editingStatus = inlineStatus(for: invoice)
                }
        }
    }

    private func inlineStatus(for invoice: InvoiceEntry) -> InvoiceInlineStatus {
        if invoice.isPaid { return .paid }
        if viewModel.dueState(for: invoice) == "overdue" { return .overdue }
        return .open
    }

    private func saveInlineEdit(for invoice: InvoiceEntry) {
        guard let edit = editingCell, edit.id == invoice.id else { return }

        var updated = invoice
        switch edit.field {
        case .dueDate:
            let days = Calendar.current.dateComponents([.day], from: updated.issuedAt, to: editingDueDate).day ?? 0
            updated.paymentTermDays = max(days, 0)
            if updated.paymentTermsText == nil || updated.paymentTermsText?.isEmpty == true {
                updated.paymentTermsText = "\(max(days, 0)) Tage"
            }
        case .contact:
            updated.customerPhone = editingContact.trimmingCharacters(in: .whitespacesAndNewlines)
        case .status:
            switch editingStatus {
            case .paid:
                updated.isPaid = true
                updated.paidAt = updated.paidAt ?? Date()
            case .open:
                updated.isPaid = false
                updated.paidAt = nil
                if updated.paymentTermDays == nil || (updated.paymentTermDays ?? 0) <= 0 {
                    updated.paymentTermDays = 14
                }
            case .overdue:
                updated.isPaid = false
                updated.paidAt = nil
                updated.paymentTermDays = 0
            }
        }

        viewModel.updateInvoice(updated)
        savedFeedbackID = invoice.id
        editingCell = nil

        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if savedFeedbackID == invoice.id {
                savedFeedbackID = nil
            }
        }
    }

    private func cancelInlineEdit() {
        editingCell = nil
    }

    private func statusLabel(for invoice: InvoiceEntry) -> String {
        invoice.isPaid ? "Bezahlt" : (viewModel.dueState(for: invoice) == "overdue" ? "Überfällig" : "Offen")
    }

    private func statusColor(for invoice: InvoiceEntry) -> Color {
        invoice.isPaid ? Theme.success : (viewModel.dueState(for: invoice) == "overdue" ? Theme.danger : Theme.textSecondary)
    }

    private func shiftMonth(_ delta: Int) {
        let date = Calendar.current.date(byAdding: .month, value: delta, to: selectedMonth) ?? selectedMonth
        let key = monthKey(for: date)
        pickerYear = key.year
        setMonth(key)
    }

    private func monthKey(for date: Date) -> InvoiceMonthKey {
        let c = Calendar.current.dateComponents([.year, .month], from: viewModel.startOfMonth(for: date))
        return InvoiceMonthKey(year: c.year ?? 2000, month: c.month ?? 1)
    }

    private func setMonth(_ key: InvoiceMonthKey) {
        selectedMonthKey = key.id
    }

    private func monthLabel(_ date: Date) -> String {
        Self.monthLabelFormatter.string(from: date).capitalized
    }

    private func shortMonthLabel(_ month: Int) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        return (f.shortMonthSymbols[safe: month - 1] ?? "M\(month)").capitalized
    }
}

private struct AddInvoiceModal: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: DashboardViewModel

    @State private var title = ""
    @State private var number = ""
    @State private var net = ""

    var body: some View {
        AppShell {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Neue Rechnung")
                        .font(.headline)
                    Spacer()
                    Button("✕") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                        .dsSecondaryButton()
                }

                DSCard {
                    VStack(spacing: 10) {
                        TextField("Bezeichnung", text: $title).dsInput()
                        TextField("Rechnungs-Nr.", text: $number).dsInput()
                        TextField("Netto", text: $net).dsInput()

                        HStack {
                            Spacer()
                            Button("Abbrechen") { dismiss() }.dsSecondaryButton()
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
                                dismiss()
                            }
                            .dsPrimaryButton()
                            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (Double(net.replacingOccurrences(of: ",", with: ".")) ?? 0) <= 0)
                        }
                    }
                }
            }
            .padding(18)
            .frame(width: 560)
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
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
