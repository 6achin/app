import SwiftUI
import AppKit

private enum DashboardSheet: Identifiable {
    case umsatz
    case umsatzsteuer
    case rechnungenOffen
    case einnahmen
    case fixkosten

    var id: String {
        switch self {
        case .umsatz: return "umsatz"
        case .umsatzsteuer: return "umsatzsteuer"
        case .rechnungenOffen: return "rechnungenOffen"
        case .einnahmen: return "einnahmen"
        case .fixkosten: return "fixkosten"
        }
    }
}

struct DashboardView: View {
    @ObservedObject var viewModel: DashboardViewModel
    let onLogout: () -> Void

    @State private var selectedSheet: DashboardSheet?
    @State private var showAddInvoiceSheet = false
    @State private var selectedMonthStart: Date?

    private let cardColumns = [GridItem(.adaptive(minimum: 220), spacing: 10)]

    private var availableMonths: [Date] {
        viewModel.availableMonths()
    }

    private var activeMonthStart: Date {
        if let selectedMonthStart, availableMonths.contains(selectedMonthStart) {
            return selectedMonthStart
        }
        return availableMonths.first ?? Calendar.current.startOfDay(for: Date())
    }

    private var displayedCards: [MetricCard] {
        viewModel.metricCards(for: activeMonthStart)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(nsColor: .windowBackgroundColor), Color.accentColor.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
                .ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Dashboard")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                        Text("Willkommen zurück, bachin")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        showAddInvoiceSheet = true
                    } label: {
                        Label("Hinzufügen", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut("n", modifiers: [.command])
                    .help("Neue Rechnung hinzufügen (⌘N)")

                    Button("Abmelden", action: onLogout)
                        .buttonStyle(.bordered)
                }

                monthlyOverview

                monthNavigation

                LazyVGrid(columns: cardColumns, spacing: 10) {
                    ForEach(displayedCards) { card in
                        KPIButtonCard(card: card) {
                            switch card.type {
                            case .umsatz: selectedSheet = .umsatz
                            case .umsatzsteuer: selectedSheet = .umsatzsteuer
                            case .rechnungenOffen: selectedSheet = .rechnungenOffen
                            case .einnahmen: selectedSheet = .einnahmen
                            case .fixkosten: selectedSheet = .fixkosten
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(24)
            .frame(maxWidth: 1120, maxHeight: .infinity, alignment: .topLeading)
        }
        .sheet(item: $selectedSheet) { sheet in
            switch sheet {
            case .umsatz:
                UmsatzDetailsSheet(viewModel: viewModel)
            case .umsatzsteuer:
                UmsatzsteuerSheet(viewModel: viewModel)
            case .rechnungenOffen:
                OffeneRechnungenSheet(viewModel: viewModel)
            case .einnahmen:
                EinnahmenSheet(viewModel: viewModel)
            case .fixkosten:
                FixkostenSheet(viewModel: viewModel)
            }
        }
        .sheet(isPresented: $showAddInvoiceSheet) {
            AddInvoiceSheet(viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .interactiveDismissDisabled(false)
        }
        .onAppear {
            if selectedMonthStart == nil {
                selectedMonthStart = availableMonths.first
            }
            viewModel.recalculateAllMetrics()
        }
    }

    private var monthNavigation: some View {
        HStack(spacing: 10) {
            Button {
                selectPreviousMonth()
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.bordered)
            .disabled(!canSelectPreviousMonth)

            Text(viewModel.monthTitle(for: activeMonthStart))
                .font(.subheadline.weight(.semibold))
                .frame(minWidth: 170)

            Button {
                selectNextMonth()
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.bordered)
            .disabled(!canSelectNextMonth)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    if value.translation.width < -30 {
                        selectPreviousMonth()
                    } else if value.translation.width > 30 {
                        selectNextMonth()
                    }
                }
        )
    }

    private var canSelectPreviousMonth: Bool {
        guard let currentIndex = availableMonths.firstIndex(of: activeMonthStart) else { return false }
        return currentIndex < availableMonths.count - 1
    }

    private var canSelectNextMonth: Bool {
        guard let currentIndex = availableMonths.firstIndex(of: activeMonthStart) else { return false }
        return currentIndex > 0
    }

    private func selectPreviousMonth() {
        guard let currentIndex = availableMonths.firstIndex(of: activeMonthStart), currentIndex < availableMonths.count - 1 else { return }
        selectedMonthStart = availableMonths[currentIndex + 1]
    }

    private func selectNextMonth() {
        guard let currentIndex = availableMonths.firstIndex(of: activeMonthStart), currentIndex > 0 else { return }
        selectedMonthStart = availableMonths[currentIndex - 1]
    }

    private var monthlyOverview: some View {
        let stat = viewModel.monthlyStat(for: activeMonthStart)

        return VStack(alignment: .leading, spacing: 10) {
            Text("Monatsstatistik")
                .font(.headline.weight(.semibold))

            HStack(spacing: 16) {
                Text("Monat")
                Spacer()
                Text("Umsatz")
                    .frame(width: 140, alignment: .trailing)
                Text("Einnahmen")
                    .frame(width: 140, alignment: .trailing)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Divider()

            ForEach([stat]) { stat in
                HStack(spacing: 16) {
                    Text(stat.title)
                    Spacer()
                    Text(viewModel.formatCurrency(stat.umsatz))
                        .fontWeight(.medium)
                        .frame(width: 140, alignment: .trailing)
                    Text(viewModel.formatCurrency(stat.einnahmen))
                        .fontWeight(.semibold)
                        .frame(width: 140, alignment: .trailing)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.vertical, 2)
            }
        }
        .padding(16)
        .background(.regularMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct KPIButtonCard: View {
    let card: MetricCard
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Text(card.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(card.value)
                    .font(.title2.weight(.bold))
                Text(card.note)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
            .padding(14)
            .background(.regularMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}

private struct AddInvoiceSheet: View {
    @ObservedObject var viewModel: DashboardViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var source: InvoiceSource = .pdf
    @State private var type: InvoiceType = .ausgangsrechnung
    @State private var title = ""
    @State private var netInput = ""
    @State private var vatRate = 0.19
    @State private var pickedPDF = ""

    private var netAmount: Double {
        Double(netInput.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    var body: some View {
        ModalSheetContainer(title: "Neue Rechnung", onClose: { dismiss() }) {

            Picker("Quelle", selection: $source) {
                ForEach(InvoiceSource.allCases) { value in
                    Text(value.rawValue).tag(value)
                }
            }
            .pickerStyle(.segmented)

            Picker("Typ", selection: $type) {
                ForEach(InvoiceType.allCases) { value in
                    Text(value.rawValue).tag(value)
                }
            }
            .pickerStyle(.segmented)

            if source == .pdf {
                HStack {
                    Text(pickedPDF.isEmpty ? "Keine PDF ausgewählt" : pickedPDF)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Button("PDF wählen") {
                        let panel = NSOpenPanel()
                        panel.allowedContentTypes = [.pdf]
                        panel.canChooseFiles = true
                        panel.canChooseDirectories = false
                        panel.allowsMultipleSelection = false
                        if panel.runModal() == .OK, let url = panel.url {
                            pickedPDF = url.lastPathComponent
                            if title.isEmpty { title = url.deletingPathExtension().lastPathComponent }
                        }
                    }
                }
            }

            TextField("Bezeichnung", text: $title)
                .modalEditorStyle()

            TextField("Netto", text: $netInput)
                .modalEditorStyle()

            Picker("MwSt", selection: $vatRate) {
                Text("19%").tag(0.19)
                Text("7%").tag(0.07)
                Text("0%").tag(0.0)
            }
            .pickerStyle(.segmented)

            HStack {
                Spacer()
                Button("Abbrechen", role: .cancel) { dismiss() }
                Button("Speichern") {
                    let invoice = InvoiceEntry(
                        title: title.isEmpty ? "Neue Rechnung" : title,
                        source: source,
                        type: type,
                        netAmount: netAmount,
                        vatRate: vatRate,
                        isPaid: false,
                        issuedAt: Date()
                    )
                    viewModel.addInvoice(invoice)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(netAmount <= 0)
            }
        }
        .frame(width: 560)
    }
}

private struct OffeneRechnungenSheet: View {
    @ObservedObject var viewModel: DashboardViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ModalSheetContainer(title: "Rechnungen offen", onClose: { dismiss() }) {

            Text("Ausgangsrechnungen")
                .font(.headline)
            List(viewModel.openInvoicesOutgoing) { invoice in
                openInvoiceRow(invoice)
            }
            .frame(minHeight: 180)

            Text("Eingangsrechnungen")
                .font(.headline)
            List(viewModel.openInvoicesIncoming) { invoice in
                openInvoiceRow(invoice)
            }
            .frame(minHeight: 180)
        }
        .frame(minWidth: 760, minHeight: 600)
    }

    private func openInvoiceRow(_ invoice: InvoiceEntry) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(invoice.title)
                Text("\(invoice.type.rawValue) · \(invoice.source.rawValue)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(viewModel.formatCurrency(invoice.grossAmount))
            Button("Als bezahlt") {
                viewModel.markInvoicePaid(id: invoice.id)
            }
            .buttonStyle(.bordered)
        }
    }
}

private struct UmsatzDetailsSheet: View {
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

private struct UmsatzsteuerSheet: View {
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
        }
        .frame(minWidth: 760, minHeight: 520)
    }
}

private struct EinnahmenSheet: View {
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
        }
        .frame(minWidth: 760, minHeight: 520)
    }
}

private struct FixkostenSheet: View {
    @ObservedObject var viewModel: DashboardViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showAddForm = false
    @State private var editingEntry: FixkostenEntry?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Fixkosten")
                        .font(.title.bold())
                    Spacer()

                    Button {
                        showAddForm = true
                    } label: {
                        Label("Hinzufügen", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.bordered)
                    .help("Schließen")
                }

                Text("Doppelklick auf eine Zeile, um sie zu bearbeiten.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                List {
                    ForEach(viewModel.fixkostenEntries) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.name)
                                .font(.headline)
                            Text(entry.description)
                                .foregroundStyle(.secondary)
                            Text("Netto: \(viewModel.formatCurrency(entry.netAmount)) · MwSt \(entry.vatLabel): \(viewModel.formatCurrency(entry.vatAmount)) · Brutto: \(viewModel.formatCurrency(entry.grossAmount))")
                                .font(.callout)
                            Text("Intervall: \(entry.cycle.rawValue) · Automatisch: \(entry.automaticDebit ? "Ja" : "Nein")")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            editingEntry = entry
                        }
                    }
                }
            }
            .padding(20)
        }
        .frame(minWidth: 780, minHeight: 560)
        .sheet(isPresented: $showAddForm) {
            AddFixkostenForm(viewModel: viewModel)
                .presentationDetents([.medium])
                .interactiveDismissDisabled(false)
        }
        .sheet(item: $editingEntry) { entry in
            EditFixkostenForm(viewModel: viewModel, entry: entry)
                .presentationDetents([.medium])
                .interactiveDismissDisabled(false)
        }
    }
}

private struct AddFixkostenForm: View {
    @ObservedObject var viewModel: DashboardViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var cycle: BillingCycle = .monatlich
    @State private var automaticDebit = true
    @State private var netInput = ""
    @State private var vatRate: Double = 0.19
    @State private var description = ""

    private var netAmount: Double {
        Double(netInput.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var vatAmount: Double {
        netAmount * vatRate
    }

    private var grossAmount: Double {
        netAmount + vatAmount
    }

    var body: some View {
        FixkostenFormContent(
            title: "Neue Fixkosten",
            name: $name,
            cycle: $cycle,
            automaticDebit: $automaticDebit,
            netInput: $netInput,
            vatRate: $vatRate,
            description: $description,
            vatAmountText: viewModel.formatCurrency(vatAmount),
            grossAmountText: viewModel.formatCurrency(grossAmount),
            onClose: { dismiss() },
            onCancel: { dismiss() },
            onSave: {
                let entry = FixkostenEntry(
                    name: name.isEmpty ? "Neue Position" : name,
                    cycle: cycle,
                    automaticDebit: automaticDebit,
                    netAmount: netAmount,
                    vatRate: vatRate,
                    description: description
                )
                viewModel.addFixkostenEntry(entry)
                dismiss()
            },
            isSaveDisabled: netAmount <= 0
        )
    }
}

private struct EditFixkostenForm: View {
    @ObservedObject var viewModel: DashboardViewModel
    @Environment(\.dismiss) private var dismiss

    let entry: FixkostenEntry

    @State private var name = ""
    @State private var cycle: BillingCycle = .monatlich
    @State private var automaticDebit = true
    @State private var netInput = ""
    @State private var vatRate: Double = 0.19
    @State private var description = ""

    private var netAmount: Double {
        Double(netInput.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var vatAmount: Double {
        netAmount * vatRate
    }

    private var grossAmount: Double {
        netAmount + vatAmount
    }

    var body: some View {
        FixkostenFormContent(
            title: "Fixkosten bearbeiten",
            name: $name,
            cycle: $cycle,
            automaticDebit: $automaticDebit,
            netInput: $netInput,
            vatRate: $vatRate,
            description: $description,
            vatAmountText: viewModel.formatCurrency(vatAmount),
            grossAmountText: viewModel.formatCurrency(grossAmount),
            onClose: { dismiss() },
            onCancel: { dismiss() },
            onSave: {
                let updated = FixkostenEntry(
                    id: entry.id,
                    name: name,
                    cycle: cycle,
                    automaticDebit: automaticDebit,
                    netAmount: netAmount,
                    vatRate: vatRate,
                    description: description
                )
                viewModel.updateFixkostenEntry(updated)
                dismiss()
            },
            isSaveDisabled: name.isEmpty || netAmount <= 0
        )
        .onAppear {
            name = entry.name
            cycle = entry.cycle
            automaticDebit = entry.automaticDebit
            netInput = String(format: "%.2f", entry.netAmount).replacingOccurrences(of: ".", with: ",")
            vatRate = entry.vatRate
            description = entry.description
        }
    }
}

private struct FixkostenFormContent: View {
    let title: String

    @Binding var name: String
    @Binding var cycle: BillingCycle
    @Binding var automaticDebit: Bool
    @Binding var netInput: String
    @Binding var vatRate: Double
    @Binding var description: String

    let vatAmountText: String
    let grossAmountText: String
    let onClose: () -> Void
    let onCancel: () -> Void
    let onSave: () -> Void
    let isSaveDisabled: Bool

    var body: some View {
        ModalSheetContainer(title: title, onClose: onClose) {

            TextField("Name", text: $name)
                .modalEditorStyle()

            Picker("Intervall", selection: $cycle) {
                ForEach(BillingCycle.allCases) { interval in
                    Text(interval.rawValue).tag(interval)
                }
            }
            .pickerStyle(.segmented)

            Toggle("Automatische Abbuchung", isOn: $automaticDebit)

            TextField("Summe Netto", text: $netInput)
                .modalEditorStyle()

            Picker("MwSt", selection: $vatRate) {
                Text("19%").tag(0.19)
                Text("7%").tag(0.07)
                Text("0%").tag(0.0)
            }
            .pickerStyle(.segmented)

            HStack {
                Text("MwSt")
                Spacer()
                Text(vatAmountText)
            }

            HStack {
                Text("Brutto")
                Spacer()
                Text(grossAmountText)
                    .fontWeight(.semibold)
            }

            TextField("Beschreibung", text: $description, axis: .vertical)
                .modalEditorStyle()
                .lineLimit(2...4)

            HStack {
                Spacer()
                Button("Abbrechen", role: .cancel, action: onCancel)
                Button("Speichern", action: onSave)
                    .buttonStyle(.borderedProminent)
                    .disabled(isSaveDisabled)
            }
        }
        .frame(width: 500)
    }
}

private struct ModalSheetContainer<Content: View>: View {
    let title: String
    var onClose: (() -> Void)?
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title)
                    .font(.title3.bold())
                Spacer()
                if let onClose {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .background(Color.primary.opacity(0.08), in: Circle())
                    .help("Schließen")
                }
            }

            content()
        }
        .padding(20)
        .background(.regularMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private extension View {
    func modalEditorStyle() -> some View {
        textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor).opacity(0.7))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            )
    }
}
