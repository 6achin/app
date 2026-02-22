import SwiftUI

struct DashboardPage: View {
    @ObservedObject var router: BAAppRouter
    @ObservedObject var viewModel: DashboardViewModel
    @ObservedObject var debtsStore: DebtsStore
    @ObservedObject var ordersStore: OrdersStore
    @ObservedObject var customersStore: CustomersStore
    @Environment(\.uiDensityMode) private var density

    @AppStorage("dashboardSelectedMonth") private var selectedMonthKey = ""

    @State private var showMonthPicker = false
    @State private var showDebtModal = false
    @State private var showOrderModal = false

    private let appVersion = AppVersionReader.readVersion()

    private var selectedMonth: Date {
        if let date = Self.monthFormatter.date(from: selectedMonthKey) { return date }
        return viewModel.startOfMonth(for: Date())
    }

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f
    }()

    private var kpiCards: [MetricType] {
        [.umsatz, .umsatzsteuer, .rechnungenOffen, .einnahmen, .fixkosten]
    }

    var body: some View {
        AppShell {
            VStack(alignment: .leading, spacing: density.spacing) {
                header
                monthSwitcher

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: density.spacing)], spacing: density.spacing) {
                    ForEach(kpiCards, id: \.self) { type in
                        Button { open(type) } label: { kpiCard(type) }
                            .buttonStyle(.plain)
                    }
                    debtCard
                }

                DSCard {
                    Button {
                        router.setTop(.auftraege)
                    } label: {
                        HStack {
                            Text("Orders to process")
                                .font(.headline)
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Text("\(ordersStore.orders.count)")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(Theme.textPrimary)
                        }
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
                Text("App-Version: v\(appVersion)")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(density == .compact ? 14 : 20)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .sheet(isPresented: $showDebtModal) { DebtFormModal(store: debtsStore) }
        .sheet(isPresented: $showOrderModal) { OrderCreateModal(ordersStore: ordersStore, customersStore: customersStore) }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Dashboard")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("CRM Übersicht")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Button("Neuer Auftrag") { showOrderModal = true }
                .dsSecondaryButton()
            Button("Neue Rechnung") { router.push(.addInvoice) }
                .dsPrimaryButton()
        }
    }

    private var monthSwitcher: some View {
        HStack(spacing: 8) {
            Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }.dsSecondaryButton()
            Button {
                showMonthPicker.toggle()
            } label: {
                Text(labelForMonth(selectedMonth))
            }
            .dsSecondaryButton()
            .popover(isPresented: $showMonthPicker) {
                VStack(alignment: .leading, spacing: 8) {
                    DatePicker("Monat", selection: Binding(get: { selectedMonth }, set: { setMonth($0) }), displayedComponents: [.date])
                        .datePickerStyle(.graphical)
                    HStack {
                        Button("This month") { setMonth(viewModel.startOfMonth(for: Date())); showMonthPicker = false }.dsSecondaryButton()
                        Button("Last month") {
                            setMonth(Calendar.current.date(byAdding: .month, value: -1, to: viewModel.startOfMonth(for: Date())) ?? Date())
                            showMonthPicker = false
                        }
                        .dsSecondaryButton()
                    }
                }
                .padding(12)
                .frame(width: 300)
            }
            Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }.dsSecondaryButton()
            Spacer()
        }
    }

    private func kpiCard(_ type: MetricType) -> some View {
        let trend = trendInfo(for: type)
        return DSCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(title(for: type)).font(.footnote).foregroundStyle(Theme.textSecondary)
                Spacer(minLength: 0)
                Text(mainValue(for: type))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .monospacedDigit()
                bottomLine(for: type, trend: trend)
            }
            .frame(maxWidth: .infinity, minHeight: density == .compact ? 96 : 112, alignment: .leading)
        }
    }

    private var debtCard: some View {
        let dueThisMonth = debtsStore.debts.filter { viewModel.startOfMonth(for: $0.dueDate) == selectedMonth && $0.status != .closed }.reduce(0) { $0 + $1.amount }
        let overdue = debtsStore.debts.filter { $0.status == .overdue }.reduce(0) { $0 + $1.amount }

        return DSCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Schulden").font(.footnote).foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Button(action: { showDebtModal = true }) { Image(systemName: "plus") }
                        .buttonStyle(.plain)
                        .foregroundStyle(Theme.accent)
                }
                Spacer(minLength: 0)
                Text("\(debtsStore.debts.filter { $0.status != .closed }.count)")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                HStack {
                    Text("Due this month: \(currency(dueThisMonth))")
                    Spacer()
                    Text("Overdue: \(currency(overdue))")
                        .foregroundStyle(overdue > 0 ? Theme.danger : Theme.textSecondary)
                }
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity, minHeight: density == .compact ? 96 : 112, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { router.setTop(.schulden) }
        }
    }

    @ViewBuilder
    private func bottomLine(for type: MetricType, trend: MoMTrend) -> some View {
        switch type {
        case .umsatzsteuer:
            HStack {
                Text("Ausgang: \(currency(vatOutputCurrent)) · Eingang: \(currency(vatInputCurrent))")
                Spacer(minLength: 8)
                Text(trend.label).foregroundStyle(trend.color)
            }
            .font(.system(size: 11))
            .foregroundStyle(Theme.textSecondary)

        case .rechnungenOffen:
            HStack {
                Text("Bezahlt: \(paidCurrentMonthCount)")
                Spacer(minLength: 8)
                Text("Überfällig: \(overdueCurrentMonthCount)")
                    .foregroundStyle(overdueCurrentMonthCount > 0 ? Theme.danger : Theme.textSecondary)
            }
            .font(.system(size: 11))
            .foregroundStyle(Theme.textSecondary)

        default:
            Text(trend.label)
                .font(.system(size: 11))
                .foregroundStyle(trend.color)
        }
    }

    private func open(_ type: MetricType) {
        switch type {
        case .umsatz: router.setTop(.umsatz)
        case .umsatzsteuer: router.setTop(.umsatzsteuer)
        case .rechnungenOffen: router.openInvoicesFromOpenKPI(month: selectedMonth)
        case .einnahmen: router.setTop(.einnahmen)
        case .fixkosten: router.setTop(.fixkosten)
        }
    }

    private func shiftMonth(_ delta: Int) {
        let date = Calendar.current.date(byAdding: .month, value: delta, to: selectedMonth) ?? selectedMonth
        setMonth(date)
    }

    private func setMonth(_ date: Date) {
        selectedMonthKey = Self.monthFormatter.string(from: viewModel.startOfMonth(for: date))
    }

    private func labelForMonth(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "LLLL yyyy"
        return f.string(from: date).capitalized
    }

    private func title(for type: MetricType) -> String {
        switch type {
        case .umsatz: return "Umsatz"
        case .umsatzsteuer: return "Umsatzsteuer"
        case .rechnungenOffen: return "Rechnungen offen"
        case .einnahmen: return "Einnahmen"
        case .fixkosten: return "Fixkosten"
        }
    }

    private func mainValue(for type: MetricType) -> String {
        switch type {
        case .umsatz: return currency(revenueCurrent)
        case .umsatzsteuer: return currency(vatPayableCurrent)
        case .rechnungenOffen: return "\(openCurrentMonthCount)"
        case .einnahmen: return currency(incomeCurrent)
        case .fixkosten: return currency(fixkostenCurrent)
        }
    }

    private func trendInfo(for type: MetricType) -> MoMTrend {
        let t: Double
        switch type {
        case .umsatz: t = mom(current: revenueCurrent, previous: revenuePrevious)
        case .umsatzsteuer: t = mom(current: vatPayableCurrent, previous: vatPayablePrevious)
        case .rechnungenOffen: t = mom(current: Double(openCurrentMonthCount), previous: Double(openPreviousMonthCount))
        case .einnahmen: t = mom(current: incomeCurrent, previous: incomePrevious)
        case .fixkosten: t = mom(current: fixkostenCurrent, previous: fixkostenPrevious, lowerIsBetter: true)
        }
        return MoMTrend(value: t)
    }

    private var previousMonth: Date { Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth }
    private var currentInvoices: [InvoiceEntry] { viewModel.invoices.filter { viewModel.startOfMonth(for: $0.issuedAt) == selectedMonth } }
    private var previousInvoices: [InvoiceEntry] { viewModel.invoices.filter { viewModel.startOfMonth(for: $0.issuedAt) == previousMonth } }

    private var revenueCurrent: Double { currentInvoices.filter { $0.type == .ausgangsrechnung }.reduce(0) { $0 + $1.netAmount } }
    private var revenuePrevious: Double { previousInvoices.filter { $0.type == .ausgangsrechnung }.reduce(0) { $0 + $1.netAmount } }

    private var vatOutputCurrent: Double { currentInvoices.filter { $0.type == .ausgangsrechnung }.reduce(0) { $0 + $1.vatAmount } }
    private var vatInputCurrent: Double { currentInvoices.filter { $0.type == .eingangsrechnung }.reduce(0) { $0 + $1.vatAmount } }
    private var vatPayableCurrent: Double { vatOutputCurrent - vatInputCurrent }

    private var vatOutputPrevious: Double { previousInvoices.filter { $0.type == .ausgangsrechnung }.reduce(0) { $0 + $1.vatAmount } }
    private var vatInputPrevious: Double { previousInvoices.filter { $0.type == .eingangsrechnung }.reduce(0) { $0 + $1.vatAmount } }
    private var vatPayablePrevious: Double { vatOutputPrevious - vatInputPrevious }

    private var paidCurrentMonthCount: Int { currentInvoices.filter { $0.isPaid }.count }
    private var overdueCurrentMonthCount: Int { currentInvoices.filter { viewModel.dueState(for: $0) == "overdue" }.count }
    private var openCurrentMonthCount: Int { currentInvoices.filter { !$0.isPaid }.count }
    private var openPreviousMonthCount: Int { previousInvoices.filter { !$0.isPaid }.count }

    private var fixkostenCurrent: Double { viewModel.fixkostenEntries.reduce(0) { $0 + $1.grossAmount } }
    private var fixkostenPrevious: Double { fixkostenCurrent }

    private var incomeCurrent: Double { revenueCurrent - max(vatPayableCurrent, 0) - viewModel.kreditUndDarlehenMonatlich - fixkostenCurrent }
    private var incomePrevious: Double { revenuePrevious - max(vatPayablePrevious, 0) - viewModel.kreditUndDarlehenMonatlich - fixkostenPrevious }

    private func mom(current: Double, previous: Double, lowerIsBetter: Bool = false) -> Double {
        guard abs(previous) > 0.0001 else { return .infinity }
        let raw = ((current - previous) / abs(previous)) * 100
        return lowerIsBetter ? -raw : raw
    }

    private func currency(_ value: Double) -> String { viewModel.formatCurrency(value) }
}

struct OrderCreateModal: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var ordersStore: OrdersStore
    @ObservedObject var customersStore: CustomersStore

    @State private var customerNumber = ""
    @State private var resolvedCustomer: CustomerItem?
    @State private var showCustomerCreate = false

    @State private var vatRate = 0.19
    @State private var lines: [OrderLine] = [OrderLine(id: UUID(), sku: "", desc: "", qty: 1, unitPrice: 0)]

    var netTotal: Double { lines.reduce(0) { $0 + $1.total } }
    var vatTotal: Double { netTotal * vatRate }
    var grossTotal: Double { netTotal + vatTotal }

    var body: some View {
        AppShell {
            VStack(alignment: .leading, spacing: 10) {
                HStack { Text("Neuer Auftrag").font(.headline); Spacer(); Button("✕") { dismiss() }.dsSecondaryButton() }
                DSCard {
                    VStack(spacing: 10) {
                        TextField("Kunden-Nr.", text: $customerNumber)
                            .dsInput()
                            .onChange(of: customerNumber) { value in resolvedCustomer = customersStore.find(by: value) }

                        if let customer = resolvedCustomer {
                            Text("\(customer.name) · \(customer.city)")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            HStack {
                                Text("Kein Kunde gefunden")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.textSecondary)
                                Spacer()
                                Button("Create customer") { showCustomerCreate = true }
                                    .dsSecondaryButton()
                            }
                        }

                        ForEach(lines.indices, id: \.self) { idx in
                            HStack(spacing: 8) {
                                TextField("SKU", text: Binding(get: { lines[idx].sku }, set: { lines[idx].sku = $0 })).dsInput()
                                TextField("Description", text: Binding(get: { lines[idx].desc }, set: { lines[idx].desc = $0 })).dsInput()
                                TextField("Qty", text: Binding(get: { String(lines[idx].qty) }, set: { lines[idx].qty = Double($0.replacingOccurrences(of: ",", with: ".")) ?? lines[idx].qty })).dsInput()
                                TextField("Unit", text: Binding(get: { String(lines[idx].unitPrice) }, set: { lines[idx].unitPrice = Double($0.replacingOccurrences(of: ",", with: ".")) ?? lines[idx].unitPrice })).dsInput()
                                Text(String(format: "%.2f", lines[idx].total)).frame(width: 70, alignment: .trailing).monospacedDigit()
                            }
                        }

                        HStack {
                            Button("+ Zeile") { lines.append(OrderLine(id: UUID(), sku: "", desc: "", qty: 1, unitPrice: 0)) }
                                .dsSecondaryButton()
                            Spacer()
                            Picker("VAT", selection: $vatRate) {
                                Text("19%").tag(0.19); Text("7%").tag(0.07); Text("0%").tag(0.0)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 180)
                        }

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Netto: \(String(format: "€ %.2f", netTotal))")
                            Text("VAT: \(String(format: "€ %.2f", vatTotal))")
                            Text("Brutto: \(String(format: "€ %.2f", grossTotal))").fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)

                        HStack { Spacer(); Button("Abbrechen") { dismiss() }.dsSecondaryButton(); Button("Speichern") { save() }.dsPrimaryButton() }
                    }
                }
            }
            .padding(18)
            .frame(width: 860)
        }
        .sheet(isPresented: $showCustomerCreate) {
            CustomerFormModal(customersStore: customersStore)
        }
    }

    private func save() {
        let order = OrderItem(id: UUID(), customerID: resolvedCustomer?.id, customerLabel: resolvedCustomer?.name ?? customerNumber, vatRate: vatRate, lines: lines, createdAt: Date(), status: "pending")
        ordersStore.add(order)
        dismiss()
    }
}

private struct MoMTrend {
    let value: Double

    var color: Color {
        guard value.isFinite else { return Theme.textSecondary }
        if abs(value) <= 1 { return Theme.textSecondary }
        return value > 0 ? Theme.success : Theme.danger
    }

    var label: String {
        guard value.isFinite else { return "vs last month: —" }
        if abs(value) <= 1 { return "vs last month: 0%" }
        return String(format: "vs last month: %@%.1f%%", value > 0 ? "+" : "", value)
    }
}

private enum AppVersionReader {
    static func readVersion() -> String {
        let candidates = [
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("package.json"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).deletingLastPathComponent().appendingPathComponent("package.json")
        ]

        for url in candidates {
            guard let data = try? Data(contentsOf: url),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let version = json["version"] as? String,
                  !version.isEmpty else { continue }
            return version
        }

        return "0.0.0"
    }
}
