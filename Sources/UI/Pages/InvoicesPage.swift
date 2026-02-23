import SwiftUI
import UniformTypeIdentifiers
#if canImport(AppKit)
import AppKit
#endif

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

private enum DocumentNumberType: String, CaseIterable, Identifiable {
    case invoice = "Rechnungsnummer"
    case delivery = "Lieferscheinnummer"
    case other = "Sonstiges"

    var id: String { rawValue }
}

private enum PaymentTermPreset: String, CaseIterable, Identifiable {
    case cash = "Bar (Sofort)"
    case prepay7 = "Vorkasse (7 Tage)"
    case transfer7 = "Überweisung (7 Tage)"
    case transfer14 = "Überweisung (14 Tage)"

    var id: String { rawValue }

    var days: Int {
        switch self {
        case .cash: return 0
        case .prepay7: return 7
        case .transfer7: return 7
        case .transfer14: return 14
        }
    }

    var marksPaid: Bool {
        self == .cash
    }
}

struct InvoicesPage: View {
    @ObservedObject var router: BAAppRouter
    @ObservedObject var viewModel: DashboardViewModel
    @ObservedObject var customersStore: CustomersStore
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
                invoice.referenceNumber ?? "",
                invoice.customerName ?? "",
                invoice.customerPhone ?? "",
                invoice.customerEmail ?? "",
                invoice.customerAddress ?? "",
                invoice.customerNumber ?? "",
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
        let values = filtered.flatMap {
            [
                $0.invoiceNumber ?? "",
                $0.referenceNumber ?? "",
                $0.customerName ?? "",
                $0.customerPhone ?? "",
                $0.customerEmail ?? "",
                $0.customerAddress ?? "",
                $0.customerNumber ?? "",
                $0.title
            ]
        }
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
            AddInvoiceModal(viewModel: viewModel, customersStore: customersStore, defaultIssuedAt: selectedMonth)
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
                Text("Name").frame(width: 160, alignment: .leading)
                Text("Adresse").frame(width: 200, alignment: .leading)
                Text("Kontakt").frame(width: 150, alignment: .leading)
                Text("Netto").frame(width: 92, alignment: .trailing)
                Text("MwSt %").frame(width: 64, alignment: .trailing)
                Text("MwSt").frame(width: 92, alignment: .trailing)
                Text("Brutto").frame(width: 92, alignment: .trailing)
                Text("Frist").frame(width: 110, alignment: .leading)
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
        let contact = (invoice.customerPhone?.isEmpty == false ? invoice.customerPhone : invoice.customerEmail) ?? "-"

        return DSCard {
            HStack(spacing: 10) {
                Text(invoice.invoiceNumber ?? invoice.referenceNumber ?? "-")
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: 96, alignment: .leading)

                Text(invoice.customerName ?? invoice.title)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: 160, alignment: .leading)

                Text((invoice.customerAddress ?? "-").replacingOccurrences(of: "
", with: ", "))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: 200, alignment: .leading)

                contactCell(for: invoice, fallback: contact)
                    .frame(width: 150, alignment: .leading)

                Text(viewModel.formatCurrency(invoice.netAmount))
                    .monospacedDigit()
                    .lineLimit(1)
                    .frame(width: 92, alignment: .trailing)

                Text("\(Int((invoice.vatRate * 100).rounded()))%")
                    .monospacedDigit()
                    .frame(width: 64, alignment: .trailing)

                Text(viewModel.formatCurrency(invoice.vatAmount))
                    .monospacedDigit()
                    .lineLimit(1)
                    .frame(width: 92, alignment: .trailing)

                Text(viewModel.formatCurrency(invoice.grossAmount))
                    .monospacedDigit()
                    .lineLimit(1)
                    .frame(width: 92, alignment: .trailing)

                dueDateCell(for: invoice, dueDate: dueDate, dueText: dueText)
                    .frame(width: 110, alignment: .leading)

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
    private func contactCell(for invoice: InvoiceEntry, fallback: String) -> some View {
        if editingCell?.id == invoice.id, editingCell?.field == .contact {
            TextField("Kontakt", text: $editingContact)
                .textFieldStyle(.plain)
                .onSubmit { saveInlineEdit(for: invoice) }
        } else {
            Text(fallback)
                .lineLimit(1)
                .truncationMode(.tail)
                .onTapGesture(count: 2) {
                    editingCell = (invoice.id, .contact)
                    editingContact = fallback == "-" ? "" : fallback
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
            let clean = editingContact.trimmingCharacters(in: .whitespacesAndNewlines)
            if clean.contains("@") {
                updated.customerEmail = clean
                updated.customerPhone = nil
            } else {
                updated.customerPhone = clean
                if !clean.isEmpty { updated.customerEmail = nil }
            }
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
    @ObservedObject var customersStore: CustomersStore

    let defaultIssuedAt: Date

    @State private var invoiceType: InvoiceType = .ausgangsrechnung
    @State private var documentType: DocumentNumberType = .invoice
    @State private var documentNumber = ""

    @State private var customerNumber = ""
    @State private var company = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var street = ""
    @State private var postalCode = ""
    @State private var city = ""
    @State private var email = ""
    @State private var phone = ""

    @State private var taxNumber = ""
    @State private var vatId = ""

    @State private var issuedAt = Date()
    @State private var paymentTerm: PaymentTermPreset = .transfer14

    @State private var netInput = ""
    @State private var vatRate: Double = 0.19

    @State private var selectedPDFURL: URL?
    @State private var showPDFImporter = false
    @State private var showCreateCustomerModal = false

    private var foundCustomer: CustomerItem? {
        customersStore.find(by: customerNumber)
    }

    private var fullName: String {
        [firstName, lastName].joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var customerDisplayName: String {
        let manual = [company, fullName].filter { !$0.isEmpty }.joined(separator: company.isEmpty || fullName.isEmpty ? "" : " · ")
        return manual.isEmpty ? "-" : manual
    }

    private var customerAddressCombined: String {
        let first = street.trimmingCharacters(in: .whitespacesAndNewlines)
        let second = [postalCode, city].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.joined(separator: " ")
        return [first, second].filter { !$0.isEmpty }.joined(separator: ", ")
    }

    private var netAmount: Double {
        Double(netInput.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var vatAmount: Double {
        netAmount * vatRate
    }

    private var grossAmount: Double {
        netAmount + vatAmount
    }

    private var computedDueDate: Date {
        Calendar.current.date(byAdding: .day, value: paymentTerm.days, to: issuedAt) ?? issuedAt
    }

    private var saveDisabled: Bool {
        let hasDocument = !documentNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasAmount = netAmount > 0
        let hasCounterparty = !customerDisplayName.isEmpty && customerDisplayName != "-"
        let hasAddressBasics = !postalCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return !hasDocument || !hasAmount || !(hasCounterparty && hasAddressBasics)
    }

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

                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        DSCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Rechnungstyp").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.textSecondary)
                                Picker("Typ", selection: $invoiceType) {
                                    Text("Ausgang").tag(InvoiceType.ausgangsrechnung)
                                    Text("Eingang").tag(InvoiceType.eingangsrechnung)
                                }
                                .pickerStyle(.segmented)
                            }
                        }

                        DSCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("PDF Anhang").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.textSecondary)
                                HStack {
                                    Button(selectedPDFURL == nil ? "PDF hochladen" : "Ersetzen") {
                                        showPDFImporter = true
                                    }
                                    .dsSecondaryButton()

                                    if selectedPDFURL != nil {
                                        Button("Öffnen") { openSelectedPDF() }.dsSecondaryButton()
                                        Button("Entfernen") { selectedPDFURL = nil }.dsSecondaryButton()
                                    }
                                }
                                if let selectedPDFURL {
                                    Text(selectedPDFURL.lastPathComponent)
                                        .font(.system(size: 11))
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                        }

                        DSCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Kunde & Dokumentnummer").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.textSecondary)
                                TextField("Kundennummer", text: $customerNumber)
                                    .dsInput()
                                    .onChange(of: customerNumber) { _ in applyCustomerLookup() }

                                if let customer = foundCustomer {
                                    Text("Kunde: \(customer.name), \(customer.city)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Theme.textSecondary)
                                } else {
                                    HStack {
                                        Text("Kunde nicht gefunden")
                                            .font(.system(size: 11))
                                            .foregroundStyle(Theme.textSecondary)
                                        Spacer()
                                        Button("Kunde anlegen") { showCreateCustomerModal = true }
                                            .dsSecondaryButton()
                                    }
                                }

                                Picker("Dokumenttyp", selection: $documentType) {
                                    ForEach(DocumentNumberType.allCases) { type in
                                        Text(type.rawValue).tag(type)
                                    }
                                }
                                .pickerStyle(.menu)

                                TextField(documentType.rawValue, text: $documentNumber)
                                    .dsInput()
                            }
                        }

                        DSCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Gegenpartei").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.textSecondary)
                                TextField("Firma / Shopname", text: $company).dsInput()
                                HStack { TextField("Vorname", text: $firstName).dsInput(); TextField("Nachname", text: $lastName).dsInput() }
                                HStack { TextField("Straße + Hausnr.", text: $street).dsInput(); TextField("PLZ", text: $postalCode).dsInput() }
                                HStack { TextField("Stadt", text: $city).dsInput(); TextField("E-Mail", text: $email).dsInput() }
                                TextField("Telefon", text: $phone).dsInput()
                            }
                        }

                        DSCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Steuerdaten").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.textSecondary)
                                HStack { TextField("Steuernummer", text: $taxNumber).dsInput(); TextField("USt-IdNr.", text: $vatId).dsInput() }
                            }
                        }

                        DSCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Datum & Zahlungsbedingungen").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.textSecondary)
                                DatePicker("Erstellt am", selection: $issuedAt, displayedComponents: .date)
                                Picker("Zahlungsart", selection: $paymentTerm) {
                                    ForEach(PaymentTermPreset.allCases) { term in
                                        Text(term.rawValue).tag(term)
                                    }
                                }
                                .pickerStyle(.menu)
                                HStack {
                                    Text("Fällig am")
                                    Spacer()
                                    Text(computedDueDate.formatted(date: .numeric, time: .omitted))
                                        .foregroundStyle(Theme.textSecondary)
                                }
                                .font(.system(size: 12))
                            }
                        }

                        DSCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Beträge").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.textSecondary)
                                TextField("Betrag (Netto)", text: $netInput).dsInput()
                                Picker("MwSt", selection: $vatRate) {
                                    Text("19 %").tag(0.19)
                                    Text("7 %").tag(0.07)
                                    Text("0 %").tag(0.0)
                                }
                                .pickerStyle(.segmented)

                                HStack {
                                    stat("Netto", viewModel.formatCurrency(netAmount))
                                    stat("MwSt", viewModel.formatCurrency(vatAmount))
                                    stat("Brutto", viewModel.formatCurrency(grossAmount))
                                }
                            }
                        }
                    }
                }

                HStack {
                    Spacer()
                    Button("Abbrechen") { dismiss() }.dsSecondaryButton()
                    Button("Rechnung erstellen") { save() }
                        .dsPrimaryButton()
                        .disabled(saveDisabled)
                }
            }
            .padding(18)
            .frame(width: 860, height: 760)
        }
        .sheet(isPresented: $showCreateCustomerModal) {
            CustomerFormModal(customersStore: customersStore)
        }
        .fileImporter(isPresented: $showPDFImporter, allowedContentTypes: [.pdf], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result {
                selectedPDFURL = urls.first
            }
        }
        .onAppear {
            issuedAt = defaultIssuedAt
            applyCustomerLookup()
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func applyCustomerLookup() {
        guard let customer = foundCustomer else { return }
        company = customer.name
        firstName = ""
        lastName = ""
        street = customer.address
        city = customer.city
        email = customer.email
        phone = customer.phone
    }

    private func openSelectedPDF() {
#if canImport(AppKit)
        guard let selectedPDFURL else { return }
        NSWorkspace.shared.open(selectedPDFURL)
#endif
    }

    private func save() {
        let pdfFileName = selectedPDFURL.flatMap { viewModel.storePDFForInvoice(from: $0) }

        var invoice = InvoiceEntry(
            title: documentNumber,
            source: selectedPDFURL == nil ? .manual : .pdfImport,
            type: invoiceType,
            netAmount: netAmount,
            vatRate: vatRate,
            isPaid: paymentTerm.marksPaid,
            issuedAt: issuedAt,
            paidAt: paymentTerm.marksPaid ? issuedAt : nil,
            referenceNumber: documentType == .invoice ? nil : documentNumber,
            invoiceNumber: documentType == .invoice ? documentNumber : nil,
            customerNumber: customerNumber.isEmpty ? nil : customerNumber,
            ustIdNr: vatId.isEmpty ? nil : vatId,
            taxNumber: taxNumber.isEmpty ? nil : taxNumber,
            customerName: customerDisplayName,
            customerAddress: customerAddressCombined.isEmpty ? nil : customerAddressCombined,
            customerPhone: phone.isEmpty ? nil : phone,
            customerEmail: email.isEmpty ? nil : email,
            paymentTermDays: paymentTerm.days,
            paymentTermsText: paymentTerm.rawValue,
            pdfStoredFileName: pdfFileName
        )

        if paymentTerm.marksPaid {
            invoice.paymentTermDays = 0
        }

        viewModel.addInvoice(invoice)
        dismiss()
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
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
