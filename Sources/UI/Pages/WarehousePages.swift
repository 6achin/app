import SwiftUI

private enum WarehouseTab: String, CaseIterable, Identifiable {
    case items = "Artikel"
    case deliveries = "Lieferungen"

    var id: String { rawValue }
}

struct WarehousePage: View {
    @ObservedObject var router: BAAppRouter
    @ObservedObject var store: WarehouseStore

    @AppStorage("warehouseSelectedMonth") private var selectedMonthKey = ""
    @State private var tab: WarehouseTab = .items
    @State private var search = ""
    @State private var showMonthPicker = false
    @State private var showCreateDelivery = false

    private var selectedMonth: Date {
        if let d = Self.monthFormatter.date(from: selectedMonthKey) {
            return startOfMonth(for: d)
        }
        return startOfMonth(for: Date())
    }

    private var monthLabel: String {
        Self.monthLabelFormatter.string(from: selectedMonth)
    }

    private var filteredItems: [StockItem] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return store.items }
        return store.items.filter { item in
            [item.name, item.sku, item.ean, item.barcode ?? ""].joined(separator: " ").lowercased().contains(q)
        }
    }

    private var filteredDeliveries: [Delivery] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return store.deliveries.filter { d in
            guard Calendar.current.isDate(startOfMonth(for: d.date), equalTo: selectedMonth, toGranularity: .month) else {
                return false
            }
            guard !q.isEmpty else { return true }

            if d.supplierName.lowercased().contains(q) { return true }
            if d.supplierDocumentNumber.lowercased().contains(q) { return true }
            return d.lines.contains { line in
                [line.name, line.sku, line.ean, line.barcode ?? ""].joined(separator: " ").lowercased().contains(q)
            }
        }
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

    var body: some View {
        AppShell {
            VStack(alignment: .leading, spacing: 12) {
                header

                HStack(spacing: 10) {
                    TextField("Suche im Lager (Name, SKU, EAN, Barcode)", text: $search)
                        .dsInput()

                    monthSwitcher
                }

                Picker("Ansicht", selection: $tab) {
                    ForEach(WarehouseTab.allCases) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 340)

                Group {
                    switch tab {
                    case .items:
                        itemsView
                    case .deliveries:
                        deliveriesView
                    }
                }

                Spacer()
            }
            .padding(18)
        }
        .sheet(isPresented: $showCreateDelivery) {
            DeliveryCreateModal(store: store) { createdID in
                // Open detail after saving.
                DispatchQueue.main.async {
                    showCreateDelivery = false
                    router.push(.deliveryDetail(createdID))
                }
            }
        }
        .onAppear {
            if selectedMonthKey.isEmpty {
                selectedMonthKey = Self.monthFormatter.string(from: selectedMonth)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            DSBackButton(action: { router.setTop(.dashboard) })

            VStack(alignment: .leading, spacing: 2) {
                Text("Lager")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Bestand & Lieferungen")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            Button("Lieferung hinzufügen") { showCreateDelivery = true }
                .dsPrimaryButton()
        }
    }

    private var monthSwitcher: some View {
        HStack(spacing: 8) {
            Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
                .dsSecondaryButton()
            Button { showMonthPicker.toggle() } label: { Text(monthLabel) }
                .dsSecondaryButton()
                .popover(isPresented: $showMonthPicker) {
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { selectedMonth },
                            set: {
                                selectedMonthKey = Self.monthFormatter.string(from: $0)
                            }
                        ),
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .padding(12)
                    .frame(width: 320)
                }
            Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
                .dsSecondaryButton()
        }
    }

    private var itemsView: some View {
        Group {
            if filteredItems.isEmpty {
                DSCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Noch keine Artikel im Lager")
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                        Text("Füge eine Lieferung hinzu, um den Bestand aufzubauen.")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredItems) { item in
                            DSCard {
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(Theme.textPrimary)
                                        Text(metaLine(for: item))
                                            .font(.system(size: 11))
                                            .foregroundStyle(Theme.textSecondary)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("\(item.currentPieces) Stück")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(Theme.textPrimary)
                                            .monospacedDigit()
                                        Text(packagingLine(for: item))
                                            .font(.system(size: 11))
                                            .foregroundStyle(Theme.textSecondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var deliveriesView: some View {
        Group {
            if filteredDeliveries.isEmpty {
                DSCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Noch keine Lieferungen")
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                        Text("Für den ausgewählten Monat sind keine Lieferungen vorhanden.")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredDeliveries) { delivery in
                            Button {
                                router.push(.deliveryDetail(delivery.id))
                            } label: {
                                DSCard {
                                    HStack(spacing: 10) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(delivery.supplierName.isEmpty ? "Lieferung" : delivery.supplierName)
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundStyle(Theme.textPrimary)
                                            Text("\(Self.dayFormatter.string(from: delivery.date)) · \(delivery.lines.count) Positionen")
                                                .font(.system(size: 11))
                                                .foregroundStyle(Theme.textSecondary)
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text("+\(delivery.totalPieces) Stück")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundStyle(Theme.textPrimary)
                                                .monospacedDigit()
                                            if delivery.netTotal > 0 {
                                                Text(formatCurrency(delivery.grossTotal))
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(Theme.textSecondary)
                                                    .monospacedDigit()
                                            }
                                        }
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateStyle = .medium
        return f
    }()

    private func shiftMonth(_ delta: Int) {
        guard let next = Calendar.current.date(byAdding: .month, value: delta, to: selectedMonth) else { return }
        selectedMonthKey = Self.monthFormatter.string(from: next)
    }

    private func startOfMonth(for date: Date) -> Date {
        let comps = Calendar.current.dateComponents([.year, .month], from: date)
        return Calendar.current.date(from: comps) ?? date
    }

    private func metaLine(for item: StockItem) -> String {
        var parts: [String] = []
        if !item.sku.isEmpty { parts.append("SKU: \(item.sku)") }
        if !item.ean.isEmpty { parts.append("EAN: \(item.ean)") }
        if let b = item.barcode, !b.isEmpty { parts.append("Barcode: \(b)") }
        return parts.isEmpty ? "" : parts.joined(separator: " · ")
    }

    private func packagingLine(for item: StockItem) -> String {
        var parts: [String] = []
        if let d = item.piecesPerDisplay { parts.append("1 Display = \(d)") }
        if let b = item.piecesPerBox { parts.append("1 Karton = \(b)") }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "€ %.2f", value)
    }
}

// MARK: - Delivery Create

private struct DeliveryLineDraft: Identifiable {
    let id: UUID
    var name: String
    var sku: String
    var ean: String
    var barcode: String
    var unitType: WarehouseUnitType
    var quantity: Int
    var piecesPerUnit: Int
    var vatRate: Double
    var purchasePricePerUnit: Double?

    init(id: UUID = UUID(), defaultVatRate: Double) {
        self.id = id
        self.name = ""
        self.sku = ""
        self.ean = ""
        self.barcode = ""
        self.unitType = .piece
        self.quantity = 1
        self.piecesPerUnit = 1
        self.vatRate = defaultVatRate
        self.purchasePricePerUnit = nil
    }

    var totalPieces: Int { max(quantity, 0) * max(piecesPerUnit, 1) }
    var netTotal: Double {
        guard let p = purchasePricePerUnit else { return 0 }
        return Double(max(quantity, 0)) * p
    }
}

struct DeliveryCreateModal: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: WarehouseStore
    let onSaved: (UUID) -> Void

    @State private var supplierName = ""
    @State private var supplierDocNumber = ""
    @State private var date = Date()

    @State private var vatMode: VatMode = .vat19
    @State private var customVatText = ""
    @State private var lines: [DeliveryLineDraft] = []

    @State private var showValidationError = false

    private enum VatMode: String, CaseIterable, Identifiable {
        case vat19 = "19%"
        case vat7 = "7%"
        case vat0 = "0%"
        case custom = "Custom"
        var id: String { rawValue }
    }

    private var defaultVatRate: Double {
        switch vatMode {
        case .vat19: return 0.19
        case .vat7: return 0.07
        case .vat0: return 0.0
        case .custom:
            let v = Double(customVatText.replacingOccurrences(of: ",", with: ".")) ?? 0
            return max(0, v / 100)
        }
    }

    private var totalPieces: Int { lines.reduce(0) { $0 + $1.totalPieces } }
    private var netTotal: Double { lines.reduce(0) { $0 + $1.netTotal } }
    private var vatTotal: Double { lines.reduce(0) { $0 + ($1.netTotal * $1.vatRate) } }
    private var grossTotal: Double { netTotal + vatTotal }

    private var unitCountsLabel: String {
        let pieces = lines.filter { $0.unitType == .piece }.reduce(0) { $0 + max($1.quantity, 0) }
        let displays = lines.filter { $0.unitType == .display }.reduce(0) { $0 + max($1.quantity, 0) }
        let boxes = lines.filter { $0.unitType == .box }.reduce(0) { $0 + max($1.quantity, 0) }
        var parts: [String] = []
        if boxes > 0 { parts.append("Karton: \(boxes)") }
        if displays > 0 { parts.append("Display: \(displays)") }
        if pieces > 0 { parts.append("Stück: \(pieces)") }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }

    var body: some View {
        AppShell {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Lieferung hinzufügen")
                        .font(.headline)
                    Spacer()
                    Button("✕") { dismiss() }
                        .dsSecondaryButton()
                }

                DSCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            TextField("Von (Lieferant)", text: $supplierName)
                                .dsInput()
                            DatePicker("Datum", selection: $date, displayedComponents: [.date])
                                .labelsHidden()
                                .frame(width: 160)
                        }

                        HStack(spacing: 10) {
                            TextField("Lieferanten-Dokument Nr. (optional)", text: $supplierDocNumber)
                                .dsInput()

                            Picker("MwSt", selection: $vatMode) {
                                ForEach(VatMode.allCases) { m in
                                    Text(m.rawValue).tag(m)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 280)

                            if vatMode == .custom {
                                TextField("%", text: $customVatText)
                                    .dsInput()
                                    .frame(width: 90)
                            }
                        }
                    }
                }

                DSCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Positionen")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Button("+ Position") { addLine() }
                                .dsSecondaryButton()
                        }

                        if lines.isEmpty {
                            Text("Noch keine Positionen. Füge eine Position hinzu.")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textSecondary)
                        } else {
                            ScrollView(.horizontal) {
                                VStack(alignment: .leading, spacing: 8) {
                                    headerRow
                                    ForEach(lines.indices, id: \.self) { idx in
                                        lineRow(idx)
                                    }
                                }
                                .padding(.bottom, 4)
                            }
                        }

                        summaryRow
                    }
                }

                if showValidationError {
                    Text("Bitte Lieferant und mindestens eine Position mit Name & Menge eingeben.")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.danger)
                }

                HStack {
                    Spacer()
                    Button("Abbrechen") { dismiss() }
                        .dsSecondaryButton()
                    Button("Speichern") { save() }
                        .dsPrimaryButton()
                }
            }
            .padding(18)
            .frame(width: 1120)
        }
        .onAppear {
            if lines.isEmpty {
                lines = [DeliveryLineDraft(defaultVatRate: defaultVatRate)]
            }
        }
    }

    private var headerRow: some View {
        HStack(spacing: 8) {
            Text("Name").frame(width: 220, alignment: .leading)
            Text("SKU").frame(width: 120, alignment: .leading)
            Text("EAN").frame(width: 140, alignment: .leading)
            Text("Barcode").frame(width: 140, alignment: .leading)
            Text("Einheit").frame(width: 110, alignment: .leading)
            Text("Menge").frame(width: 80, alignment: .leading)
            Text("Stück/Einheit").frame(width: 110, alignment: .leading)
            Text("MwSt").frame(width: 120, alignment: .leading)
            Text("EK Preis/Einheit").frame(width: 140, alignment: .leading)
            Text("= Stück").frame(width: 90, alignment: .trailing)
            Spacer().frame(width: 34)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(Theme.textSecondary)
    }

    private func lineRow(_ idx: Int) -> some View {
        HStack(spacing: 8) {
            TextField("", text: Binding(get: { lines[idx].name }, set: { lines[idx].name = $0 }))
                .dsInput()
                .frame(width: 220)
            TextField("", text: Binding(get: { lines[idx].sku }, set: { lines[idx].sku = $0 }))
                .dsInput()
                .frame(width: 120)
            TextField("", text: Binding(get: { lines[idx].ean }, set: { lines[idx].ean = $0 }))
                .dsInput()
                .frame(width: 140)
            TextField("", text: Binding(get: { lines[idx].barcode }, set: { lines[idx].barcode = $0 }))
                .dsInput()
                .frame(width: 140)

            Picker("", selection: Binding(get: { lines[idx].unitType }, set: { newUnit in
                lines[idx].unitType = newUnit
                // Smart defaults
                switch newUnit {
                case .piece:
                    lines[idx].piecesPerUnit = 1
                case .display:
                    if lines[idx].piecesPerUnit <= 1 { lines[idx].piecesPerUnit = 10 }
                case .box:
                    if lines[idx].piecesPerUnit <= 1 { lines[idx].piecesPerUnit = 200 }
                }
            })) {
                ForEach(WarehouseUnitType.allCases) { u in
                    Text(u.rawValue).tag(u)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 110)

            TextField("", text: Binding(get: { String(lines[idx].quantity) }, set: { lines[idx].quantity = Int($0) ?? lines[idx].quantity }))
                .dsInput()
                .frame(width: 80)

            TextField("", text: Binding(get: { String(lines[idx].piecesPerUnit) }, set: { lines[idx].piecesPerUnit = max(Int($0) ?? lines[idx].piecesPerUnit, 1) }))
                .dsInput()
                .frame(width: 110)

            TextField("", text: Binding(
                get: { vatPercentText(lines[idx].vatRate) },
                set: { lines[idx].vatRate = vatRateFromPercentText($0) }
            ))
            .dsInput()
            .frame(width: 120)

            TextField("", text: Binding(get: {
                if let v = lines[idx].purchasePricePerUnit { return formatDecimal(v) }
                return ""
            }, set: { newVal in
                let normalized = newVal.replacingOccurrences(of: ",", with: ".")
                lines[idx].purchasePricePerUnit = Double(normalized)
            }))
            .dsInput()
            .frame(width: 140)

            Text("\(lines[idx].totalPieces)")
                .frame(width: 90, alignment: .trailing)
                .monospacedDigit()

            Button {
                removeLine(idx)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.danger)
            .frame(width: 26)
        }
        .font(.system(size: 12))
        .foregroundStyle(Theme.textPrimary)
    }

    private var summaryRow: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack {
                Spacer()
                Text("Gesamt Stück: \(totalPieces)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .monospacedDigit()
            }
            Text(unitCountsLabel)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
            if netTotal > 0 {
                Text("Netto: \(formatCurrency(netTotal))")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                Text("MwSt: \(formatCurrency(vatTotal))")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                Text("Brutto: \(formatCurrency(grossTotal))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.top, 4)
    }

    private func addLine() {
        lines.append(DeliveryLineDraft(defaultVatRate: defaultVatRate))
    }

    private func removeLine(_ idx: Int) {
        guard lines.indices.contains(idx) else { return }
        lines.remove(at: idx)
    }

    private func save() {
        let supplier = supplierName.trimmingCharacters(in: .whitespacesAndNewlines)
        let validLines = lines.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.quantity > 0 }
        guard !supplier.isEmpty, !validLines.isEmpty else {
            showValidationError = true
            return
        }
        showValidationError = false

        var deliveryLines: [DeliveryLine] = []
        deliveryLines.reserveCapacity(validLines.count)

        for draft in validLines {
            let item = store.upsertStockItemFromLineDraft(
                name: draft.name,
                sku: draft.sku,
                ean: draft.ean,
                barcode: draft.barcode.isEmpty ? nil : draft.barcode,
                unitType: draft.unitType,
                piecesPerUnit: draft.piecesPerUnit
            )

            let line = DeliveryLine(
                id: draft.id,
                stockItemId: item.id,
                name: draft.name,
                sku: draft.sku,
                ean: draft.ean,
                barcode: draft.barcode.isEmpty ? nil : draft.barcode,
                unitType: draft.unitType,
                quantity: draft.quantity,
                piecesPerUnit: draft.piecesPerUnit,
                vatRate: draft.vatRate,
                purchasePricePerUnit: draft.purchasePricePerUnit
            )
            deliveryLines.append(line)
        }

        let delivery = Delivery(
            supplierName: supplier,
            supplierDocumentNumber: supplierDocNumber,
            date: date,
            defaultVatRate: defaultVatRate,
            lines: deliveryLines
        )

        store.addDelivery(delivery)
        onSaved(delivery.id)
        dismiss()
    }

    private func vatPercentText(_ rate: Double) -> String {
        let p = rate * 100
        let rounded = (p * 10).rounded() / 10
        if abs(rounded.rounded() - rounded) < 0.00001 {
            return String(Int(rounded))
        }
        return String(rounded)
    }

    private func vatRateFromPercentText(_ text: String) -> Double {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "%", with: "")
            .replacingOccurrences(of: ",", with: ".")
        let v = Double(normalized) ?? 0
        return max(0, v / 100)
    }

    private func formatDecimal(_ v: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: NSNumber(value: v)) ?? String(format: "%.2f", v)
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "€ %.2f", value)
    }
}

// MARK: - Delivery Detail + Edit

struct DeliveryDetailPage: View {
    @ObservedObject var router: BAAppRouter
    @ObservedObject var store: WarehouseStore
    let deliveryID: UUID

    @State private var editingLine: DeliveryLine?
    @State private var showEditLine = false

    private var delivery: Delivery? {
        store.deliveries.first(where: { $0.id == deliveryID })
    }

    var body: some View {
        AppShell {
            VStack(alignment: .leading, spacing: 12) {
                PageHeader(
                    title: "Lieferung",
                    subtitle: delivery.map { "\($0.supplierName) · \(Self.dayFormatter.string(from: $0.date))" },
                    onBack: { router.pop() }
                )

                if let delivery {
                    headerCard(delivery)
                    linesCard(delivery)
                    movementsCard
                } else {
                    DSCard {
                        Text("Lieferung nicht gefunden")
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer()
            }
            .padding(18)
        }
        .sheet(isPresented: $showEditLine) {
            if let line = editingLine {
                DeliveryLineEditModal(
                    store: store,
                    deliveryID: deliveryID,
                    line: line
                ) {
                    showEditLine = false
                }
            }
        }
    }

    private func headerCard(_ delivery: Delivery) -> some View {
        DSCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(delivery.supplierName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        if !delivery.supplierDocumentNumber.isEmpty {
                            Text("Dokument: \(delivery.supplierDocumentNumber)")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Text(unitCountsLabel(for: delivery))
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("+\(delivery.totalPieces) Stück")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .monospacedDigit()
                        if delivery.netTotal > 0 {
                            Text(formatCurrency(delivery.grossTotal))
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.textSecondary)
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
    }

    private func linesCard(_ delivery: Delivery) -> some View {
        DSCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Positionen")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)

                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(delivery.lines) { line in
                            DSCard {
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(line.name)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(Theme.textPrimary)
                                        Text(metaLine(for: line))
                                            .font(.system(size: 11))
                                            .foregroundStyle(Theme.textSecondary)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("\(line.quantity) \(line.unitType.rawValue) · = \(line.totalPieces) Stück")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(Theme.textPrimary)
                                            .monospacedDigit()
                                        if line.netTotal > 0 {
                                            Text(formatCurrency(line.grossTotal))
                                                .font(.system(size: 11))
                                                .foregroundStyle(Theme.textSecondary)
                                                .monospacedDigit()
                                        }
                                    }
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) {
                                editingLine = line
                                showEditLine = true
                            }
                            .help("Doppelklick zum Bearbeiten")
                        }
                    }
                }
                .frame(maxHeight: 280)
            }
        }
    }

    private var movementsCard: some View {
        DSCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Bewegungen")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)

                let ms = store.movements(forDelivery: deliveryID)
                if ms.isEmpty {
                    Text("Keine Bewegungen")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(ms) { m in
                                HStack {
                                    Text(Self.timeFormatter.string(from: m.date))
                                        .frame(width: 90, alignment: .leading)
                                        .font(.system(size: 11))
                                        .foregroundStyle(Theme.textSecondary)
                                        .monospacedDigit()

                                    Text(store.item(for: m.stockItemId)?.name ?? "Artikel")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.textPrimary)
                                    Spacer()
                                    Text("\(m.deltaPieces >= 0 ? "+" : "")\(m.deltaPieces) Stück")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(m.deltaPieces >= 0 ? Theme.success : Theme.danger)
                                        .monospacedDigit()
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 220)
                }
            }
        }
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateStyle = .medium
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    private func metaLine(for line: DeliveryLine) -> String {
        var parts: [String] = []
        if !line.sku.isEmpty { parts.append("SKU: \(line.sku)") }
        if !line.ean.isEmpty { parts.append("EAN: \(line.ean)") }
        if let b = line.barcode, !b.isEmpty { parts.append("Barcode: \(b)") }
        return parts.isEmpty ? "" : parts.joined(separator: " · ")
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "€ %.2f", value)
    }

    private func unitCountsLabel(for delivery: Delivery) -> String {
        let pieces = delivery.lines.filter { $0.unitType == .piece }.reduce(0) { $0 + max($1.quantity, 0) }
        let displays = delivery.lines.filter { $0.unitType == .display }.reduce(0) { $0 + max($1.quantity, 0) }
        let boxes = delivery.lines.filter { $0.unitType == .box }.reduce(0) { $0 + max($1.quantity, 0) }
        var parts: [String] = []
        if boxes > 0 { parts.append("Karton: \(boxes)") }
        if displays > 0 { parts.append("Display: \(displays)") }
        if pieces > 0 { parts.append("Stück: \(pieces)") }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }
}

private struct DeliveryLineEditModal: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: WarehouseStore
    let deliveryID: UUID
    let line: DeliveryLine
    let onClose: () -> Void

    @State private var name: String
    @State private var sku: String
    @State private var ean: String
    @State private var barcode: String
    @State private var unitType: WarehouseUnitType
    @State private var quantity: Int
    @State private var piecesPerUnit: Int
    @State private var vatText: String
    @State private var priceText: String

    init(store: WarehouseStore, deliveryID: UUID, line: DeliveryLine, onClose: @escaping () -> Void) {
        self.store = store
        self.deliveryID = deliveryID
        self.line = line
        self.onClose = onClose

        _name = State(initialValue: line.name)
        _sku = State(initialValue: line.sku)
        _ean = State(initialValue: line.ean)
        _barcode = State(initialValue: line.barcode ?? "")
        _unitType = State(initialValue: line.unitType)
        _quantity = State(initialValue: line.quantity)
        _piecesPerUnit = State(initialValue: line.piecesPerUnit)
        _vatText = State(initialValue: Self.vatPercentTextStatic(line.vatRate))
        if let p = line.purchasePricePerUnit {
            _priceText = State(initialValue: String(format: "%.2f", p))
        } else {
            _priceText = State(initialValue: "")
        }
    }

    var body: some View {
        AppShell {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Position bearbeiten")
                        .font(.headline)
                    Spacer()
                    Button("✕") { dismissAndClose() }
                        .dsSecondaryButton()
                }

                DSCard {
                    VStack(spacing: 10) {
                        TextField("Name", text: $name).dsInput()
                        HStack(spacing: 10) {
                            TextField("SKU", text: $sku).dsInput()
                            TextField("EAN", text: $ean).dsInput()
                            TextField("Barcode", text: $barcode).dsInput()
                        }
                        HStack(spacing: 10) {
                            Picker("Einheit", selection: $unitType) {
                                ForEach(WarehouseUnitType.allCases) { u in
                                    Text(u.rawValue).tag(u)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 360)

                            TextField("Menge", text: Binding(get: { String(quantity) }, set: { quantity = Int($0) ?? quantity }))
                                .dsInput()
                                .frame(width: 120)
                            TextField("Stück/Einheit", text: Binding(get: { String(piecesPerUnit) }, set: { piecesPerUnit = max(Int($0) ?? piecesPerUnit, 1) }))
                                .dsInput()
                                .frame(width: 160)
                        }
                        HStack(spacing: 10) {
                            TextField("MwSt %", text: $vatText)
                                .dsInput()
                                .frame(width: 160)
                            TextField("EK Preis/Einheit (optional)", text: $priceText)
                                .dsInput()
                        }
                    }
                }

                HStack {
                    Spacer()
                    Button("Abbrechen") { dismissAndClose() }
                        .dsSecondaryButton()
                    Button("Speichern") { save() }
                        .dsPrimaryButton()
                }
            }
            .padding(18)
            .frame(width: 760)
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let normalizedPrice = priceText.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        let price = Double(normalizedPrice)

        let vat = Self.vatRateFromPercentTextStatic(vatText)
        let updated = DeliveryLine(
            id: line.id,
            stockItemId: line.stockItemId,
            name: trimmedName,
            sku: sku,
            ean: ean,
            barcode: barcode.isEmpty ? nil : barcode,
            unitType: unitType,
            quantity: quantity,
            piecesPerUnit: piecesPerUnit,
            vatRate: vat,
            purchasePricePerUnit: price
        )

        store.updateDeliveryLine(deliveryId: deliveryID, lineId: line.id, updated: updated)
        dismissAndClose()
    }

    private func dismissAndClose() {
        dismiss()
        onClose()
    }

    private static func vatPercentTextStatic(_ rate: Double) -> String {
        let p = rate * 100
        let rounded = (p * 10).rounded() / 10
        if abs(rounded.rounded() - rounded) < 0.00001 {
            return String(Int(rounded))
        }
        return String(rounded)
    }

    private static func vatRateFromPercentTextStatic(_ text: String) -> Double {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "%", with: "")
            .replacingOccurrences(of: ",", with: ".")
        let v = Double(normalized) ?? 0
        return max(0, v / 100)
    }
}
