import SwiftUI
import AppKit

struct DashboardView: View {
    @ObservedObject var viewModel: DashboardViewModel
    let onLogout: () -> Void

    @State private var showFixkostenSheet = false
    @State private var showAddInvoiceSheet = false

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            NavigationSplitView {
                List {
                    Label("Dashboard", systemImage: "rectangle.grid.2x2")
                    Label("Rechnungen", systemImage: "doc.text")
                    Label("Fixkosten", systemImage: "eurosign.circle")
                }
                .navigationTitle("Menü")
            } detail: {
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

                        Button("Abmelden", action: onLogout)
                            .buttonStyle(.bordered)
                    }

                    Text("Umsatz = Netto aus Ausgangsrechnungen. Umsatzsteuer = Ausgangssteuer - Vorsteuer. Einnahmen = Umsatz - Zahllast - Kredite - Fixkosten.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(viewModel.cards) { card in
                            KPIButtonCard(card: card) {
                                if card.type == .fixkosten {
                                    showFixkostenSheet = true
                                }
                            }
                        }
                    }

                    HStack {
                        Text("Kredite/Leasing monatlich")
                        Spacer()
                        Text(viewModel.formatCurrency(viewModel.kreditUndDarlehenMonatlich))
                            .fontWeight(.semibold)
                    }
                    .padding(12)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Spacer()
                }
                .padding(24)
            }
        }
        .sheet(isPresented: $showFixkostenSheet) {
            FixkostenSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showAddInvoiceSheet) {
            AddInvoiceSheet(viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .interactiveDismissDisabled(false)
        }
        .onAppear {
            viewModel.recalculateAllMetrics()
        }
    }
}

private struct KPIButtonCard: View {
    let card: MetricCard
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(card.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if card.type == .fixkosten {
                        Image(systemName: "arrow.right.circle")
                            .foregroundStyle(.blue)
                    }
                }

                Text(card.value)
                    .font(.title3.weight(.semibold))

                Text(card.note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
            .padding(14)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
    @State private var isPaid = false
    @State private var pickedPDF = ""

    private var netAmount: Double {
        Double(netInput.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Neue Rechnung")
                    .font(.title3.bold())
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.bordered)
            }

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
                .textFieldStyle(.roundedBorder)

            TextField("Netto", text: $netInput)
                .textFieldStyle(.roundedBorder)

            Picker("MwSt", selection: $vatRate) {
                Text("19%").tag(0.19)
                Text("7%").tag(0.07)
                Text("0%").tag(0.0)
            }
            .pickerStyle(.segmented)

            Toggle("Bereits bezahlt", isOn: $isPaid)

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
                        isPaid: isPaid
                    )
                    viewModel.addInvoice(invoice)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(netAmount <= 0)
            }
        }
        .padding(20)
        .frame(width: 560)
    }
}

private struct FixkostenSheet: View {
    @ObservedObject var viewModel: DashboardViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showAddForm = false
    @State private var editingEntry: FixkostenEntry?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
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
    let onCancel: () -> Void
    let onSave: () -> Void
    let isSaveDisabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title3.bold())

            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)

            Picker("Intervall", selection: $cycle) {
                ForEach(BillingCycle.allCases) { interval in
                    Text(interval.rawValue).tag(interval)
                }
            }
            .pickerStyle(.segmented)

            Toggle("Automatische Abbuchung", isOn: $automaticDebit)

            TextField("Summe Netto", text: $netInput)
                .textFieldStyle(.roundedBorder)

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
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)

            HStack {
                Spacer()
                Button("Abbrechen", role: .cancel, action: onCancel)
                Button("Speichern", action: onSave)
                    .buttonStyle(.borderedProminent)
                    .disabled(isSaveDisabled)
            }
        }
        .padding(20)
        .frame(width: 500)
    }
}
