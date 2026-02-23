import SwiftUI

private struct DashboardMetricSnapshot {
    var revenueCurrent: Double
    var revenuePrevious: Double
    var vatOutputCurrent: Double
    var vatInputCurrent: Double
    var vatPayableCurrent: Double
    var vatPayablePrevious: Double
    var paidCurrentMonthCount: Int
    var overdueCurrentMonthCount: Int
    var openCurrentMonthCount: Int
    var openPreviousMonthCount: Int
    var fixkostenCurrent: Double
    var fixkostenPrevious: Double
    var incomeCurrent: Double
    var incomePrevious: Double

    static let empty = DashboardMetricSnapshot(
        revenueCurrent: 0,
        revenuePrevious: 0,
        vatOutputCurrent: 0,
        vatInputCurrent: 0,
        vatPayableCurrent: 0,
        vatPayablePrevious: 0,
        paidCurrentMonthCount: 0,
        overdueCurrentMonthCount: 0,
        openCurrentMonthCount: 0,
        openPreviousMonthCount: 0,
        fixkostenCurrent: 0,
        fixkostenPrevious: 0,
        incomeCurrent: 0,
        incomePrevious: 0
    )
}

private struct MonthKey: Hashable {
    let year: Int
    let month: Int

    var id: String {
        String(format: "%04d-%02d", year, month)
    }
}

struct DashboardPage: View {
    @ObservedObject var router: BAAppRouter
    @ObservedObject var viewModel: DashboardViewModel
    @ObservedObject var debtsStore: DebtsStore
    @ObservedObject var ordersStore: OrdersStore
    @ObservedObject var customersStore: CustomersStore
    @Environment(\.uiDensityMode) private var density

    @AppStorage("dashboardSelectedMonth") private var selectedMonthKey = ""
    @AppStorage("savedLoginAccount") private var savedLoginAccount = ""

    @State private var showMonthPicker = false
    @State private var showDebtModal = false
    @State private var showOrderModal = false
    @State private var cachedMetricsByMonth: [String: DashboardMetricSnapshot] = [:]
    @State private var currentMetrics: DashboardMetricSnapshot = .empty
    @State private var pickerYear = Calendar.current.component(.year, from: Date())

    private let appVersion = AppVersionReader.readVersion()

    private var selectedMonth: Date {
        if let date = Self.monthFormatter.date(from: selectedMonthKey) { return date }
        return viewModel.startOfMonth(for: Date())
    }

    private var selectedMonthIdentity: MonthKey {
        let comps = Calendar.current.dateComponents([.year, .month], from: selectedMonth)
        return MonthKey(year: comps.year ?? 2000, month: comps.month ?? 1)
    }

    private var displayName: String? {
        let normalized = savedLoginAccount.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        return normalized
            .split(separator: "@")
            .first?
            .split(separator: ".")
            .first?
            .capitalized
    }

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f
    }()

    private static let monthLabelFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "LLLL yyyy"
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

                LazyVGrid(columns: [GridItem(.adaptive(minimum: density == .compact ? 280 : 320), spacing: density.spacing)], spacing: density.spacing) {
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
            .padding(.horizontal, density == .compact ? 14 : 22)
            .padding(.vertical, density == .compact ? 12 : 18)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .sheet(isPresented: $showDebtModal) { DebtFormModal(store: debtsStore) }
        .sheet(isPresented: $showOrderModal) { OrderCreateModal(ordersStore: ordersStore, customersStore: customersStore) }
        .task(id: selectedMonthIdentity.id) {
            refreshMetrics(for: selectedMonth)
        }
        .onAppear {
            if selectedMonthKey.isEmpty { selectedMonthKey = selectedMonthIdentity.id }
            pickerYear = selectedMonthIdentity.year
        }
        .onChange(of: router.orderCreateModalRequestToken) { _ in
            guard router.top == .dashboard else { return }
            showOrderModal = true
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Dashboard")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(greetingText)
                    .font(.system(size: 16, weight: .medium))
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

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let prefix: String
        switch hour {
        case 5..<12: prefix = "Guten Morgen"
        case 12..<18: prefix = "Guten Tag"
        case 18..<23: prefix = "Guten Abend"
        default: prefix = "Hallo"
        }
        if let displayName { return "\(prefix), \(displayName) 👋" }
        return "\(prefix) 👋"
    }

    private var monthSwitcher: some View {
        HStack(spacing: 8) {
            Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }.dsSecondaryButton()
            Button { showMonthPicker.toggle() } label: { Text(labelForMonth(selectedMonth)) }
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
                                Button(monthLabel(month)) {
                                    setMonth(MonthKey(year: pickerYear, month: month))
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
            Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }.dsSecondaryButton()
            Spacer()
        }
    }

    private func kpiCard(_ type: MetricType) -> some View {
        let trend = trendInfo(for: type)
        return DSCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(title(for: type)).font(.footnote).foregroundStyle(Theme.textSecondary)
                Spacer(minLength: 0)
                Text(mainValue(for: type))
                    .font(.system(size: density == .compact ? 34 : 40, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                bottomLine(for: type, trend: trend)
            }
            .frame(maxWidth: .infinity, minHeight: density == .compact ? 128 : 146, alignment: .leading)
            .contentShape(Rectangle())
        }
    }

    private var debtCard: some View {
        let dueThisMonth = debtsStore.debts.filter { viewModel.startOfMonth(for: $0.dueDate) == selectedMonth && $0.status != .closed }.reduce(0) { $0 + $1.amount }
        let overdue = debtsStore.debts.filter { $0.status == .overdue }.reduce(0) { $0 + $1.amount }

        return DSCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Schulden").font(.footnote).foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Button(action: { showDebtModal = true }) { Image(systemName: "plus") }
                        .buttonStyle(.plain)
                        .foregroundStyle(Theme.accent)
                }
                Spacer(minLength: 0)
                Text("\(debtsStore.debts.filter { $0.status != .closed }.count)")
                    .font(.system(size: density == .compact ? 34 : 40, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                HStack {
                    Text("Due this month: \(currency(dueThisMonth))")
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer()
                    Text("Overdue: \(currency(overdue))")
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(overdue > 0 ? Theme.danger : Theme.textSecondary)
                }
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity, minHeight: density == .compact ? 128 : 146, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { router.setTop(.schulden) }
        }
    }

    @ViewBuilder
    private func bottomLine(for type: MetricType, trend: MoMTrend) -> some View {
        switch type {
        case .umsatzsteuer:
            HStack {
                Text("Ausgang: \(currency(currentMetrics.vatOutputCurrent)) · Eingang: \(currency(currentMetrics.vatInputCurrent))")
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 8)
                Text(trend.label).foregroundStyle(trend.color)
            }
            .font(.system(size: 12))
            .foregroundStyle(Theme.textSecondary)

        case .rechnungenOffen:
            HStack {
                Text("Bezahlt: \(currentMetrics.paidCurrentMonthCount)")
                Spacer(minLength: 8)
                Text("Überfällig: \(currentMetrics.overdueCurrentMonthCount)")
                    .foregroundStyle(currentMetrics.overdueCurrentMonthCount > 0 ? Theme.danger : Theme.textSecondary)
            }
            .font(.system(size: 12))
            .foregroundStyle(Theme.textSecondary)

        default:
            Text(trend.label)
                .font(.system(size: 12))
                .foregroundStyle(trend.color)
                .lineLimit(1)
                .truncationMode(.tail)
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
        let key = monthKey(for: date)
        pickerYear = key.year
        setMonth(key)
    }

    private func monthKey(for date: Date) -> MonthKey {
        let c = Calendar.current.dateComponents([.year, .month], from: viewModel.startOfMonth(for: date))
        return MonthKey(year: c.year ?? 2000, month: c.month ?? 1)
    }

    private func setMonth(_ key: MonthKey) {
        selectedMonthKey = key.id
    }

    private func labelForMonth(_ date: Date) -> String {
        Self.monthLabelFormatter.string(from: date).capitalized
    }

    private func monthLabel(_ month: Int) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        return (f.shortMonthSymbols[safe: month - 1] ?? "M\(month)").capitalized
    }

    private func refreshMetrics(for date: Date) {
        let key = monthKey(for: date).id
        if let cached = cachedMetricsByMonth[key] {
            currentMetrics = cached
            return
        }

        let selectedStart = viewModel.startOfMonth(for: date)
        let previousMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedStart) ?? selectedStart
        let currentInvoices = viewModel.invoices.filter { viewModel.startOfMonth(for: $0.issuedAt) == selectedStart }
        let previousInvoices = viewModel.invoices.filter { viewModel.startOfMonth(for: $0.issuedAt) == previousMonth }

        let revenueCurrent = currentInvoices.filter { $0.type == .ausgangsrechnung }.reduce(0) { $0 + $1.netAmount }
        let revenuePrevious = previousInvoices.filter { $0.type == .ausgangsrechnung }.reduce(0) { $0 + $1.netAmount }
        let vatOutputCurrent = currentInvoices.filter { $0.type == .ausgangsrechnung }.reduce(0) { $0 + $1.vatAmount }
        let vatInputCurrent = currentInvoices.filter { $0.type == .eingangsrechnung }.reduce(0) { $0 + $1.vatAmount }
        let vatOutputPrevious = previousInvoices.filter { $0.type == .ausgangsrechnung }.reduce(0) { $0 + $1.vatAmount }
        let vatInputPrevious = previousInvoices.filter { $0.type == .eingangsrechnung }.reduce(0) { $0 + $1.vatAmount }
        let vatPayableCurrent = vatOutputCurrent - vatInputCurrent
        let vatPayablePrevious = vatOutputPrevious - vatInputPrevious

        let fixkostenCurrent = viewModel.fixkostenEntries.reduce(0) { $0 + $1.grossAmount }
        let fixkostenPrevious = fixkostenCurrent
        let incomeCurrent = revenueCurrent - max(vatPayableCurrent, 0) - viewModel.kreditUndDarlehenMonatlich - fixkostenCurrent
        let incomePrevious = revenuePrevious - max(vatPayablePrevious, 0) - viewModel.kreditUndDarlehenMonatlich - fixkostenPrevious

        let snapshot = DashboardMetricSnapshot(
            revenueCurrent: revenueCurrent,
            revenuePrevious: revenuePrevious,
            vatOutputCurrent: vatOutputCurrent,
            vatInputCurrent: vatInputCurrent,
            vatPayableCurrent: vatPayableCurrent,
            vatPayablePrevious: vatPayablePrevious,
            paidCurrentMonthCount: currentInvoices.filter(\.isPaid).count,
            overdueCurrentMonthCount: currentInvoices.filter { viewModel.dueState(for: $0) == "overdue" }.count,
            openCurrentMonthCount: currentInvoices.filter { !$0.isPaid }.count,
            openPreviousMonthCount: previousInvoices.filter { !$0.isPaid }.count,
            fixkostenCurrent: fixkostenCurrent,
            fixkostenPrevious: fixkostenPrevious,
            incomeCurrent: incomeCurrent,
            incomePrevious: incomePrevious
        )

        currentMetrics = snapshot
        cachedMetricsByMonth[key] = snapshot
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
        case .umsatz: return currency(currentMetrics.revenueCurrent)
        case .umsatzsteuer: return currency(currentMetrics.vatPayableCurrent)
        case .rechnungenOffen: return "\(currentMetrics.openCurrentMonthCount)"
        case .einnahmen: return currency(currentMetrics.incomeCurrent)
        case .fixkosten: return currency(currentMetrics.fixkostenCurrent)
        }
    }

    private func trendInfo(for type: MetricType) -> MoMTrend {
        let t: Double
        switch type {
        case .umsatz: t = mom(current: currentMetrics.revenueCurrent, previous: currentMetrics.revenuePrevious)
        case .umsatzsteuer: t = mom(current: currentMetrics.vatPayableCurrent, previous: currentMetrics.vatPayablePrevious)
        case .rechnungenOffen: t = mom(current: Double(currentMetrics.openCurrentMonthCount), previous: Double(currentMetrics.openPreviousMonthCount))
        case .einnahmen: t = mom(current: currentMetrics.incomeCurrent, previous: currentMetrics.incomePrevious)
        case .fixkosten: t = mom(current: currentMetrics.fixkostenCurrent, previous: currentMetrics.fixkostenPrevious, lowerIsBetter: true)
        }
        return MoMTrend(value: t)
    }

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

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
