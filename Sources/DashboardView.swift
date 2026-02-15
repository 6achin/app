import SwiftUI

struct DashboardView: View {
    @ObservedObject var viewModel: DashboardViewModel
    let onLogout: () -> Void

    @State private var showFixkostenSheet = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(nsColor: .windowBackgroundColor), Color.blue.opacity(0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            NavigationSplitView {
                List {
                    Label("Dashboard", systemImage: "rectangle.grid.2x2")
                    Label("Umsatz", systemImage: "chart.bar.xaxis")
                    Label("Kosten", systemImage: "eurosign.circle")
                    Label("Berichte", systemImage: "doc.text")
                }
                .navigationTitle("Menü")
            } detail: {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    greetingPanel

                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                            ForEach(viewModel.cards) { card in
                                KPIButtonCard(card: card) {
                                    if card.type == .fixkosten {
                                        showFixkostenSheet = true
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 8)
                    }
                    .scrollIndicators(.hidden)

                    Spacer(minLength: 0)
                }
                .padding(24)
            }
        }
        .sheet(isPresented: $showFixkostenSheet) {
            FixkostenSheet(viewModel: viewModel)
        }
        .onAppear {
            viewModel.recalculateFixkostenCard()
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Geschäfts-Dashboard")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text("Schnell, übersichtlich und editierbar")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                viewModel.addCard()
            } label: {
                Label("Hinzufügen", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)

            Button("Abmelden", action: onLogout)
                .buttonStyle(.bordered)
        }
    }

    private var greetingPanel: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Willkommen zurück, bachin 👋")
                    .font(.title3.bold())
                Text("Hier siehst du deine wichtigsten Kennzahlen. Klicke auf Fixkosten, um Positionen zu verwalten.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.45))
        )
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
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundStyle(.blue)
                    }
                }

                Text(card.value)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(card.note)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
            )
        }
        .buttonStyle(.plain)
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
