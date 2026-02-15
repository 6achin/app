import SwiftUI

struct DashboardView: View {
    @ObservedObject var viewModel: DashboardViewModel
    let onLogout: () -> Void

    @State private var showFixkostenSheet = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(nsColor: .windowBackgroundColor), Color.blue.opacity(0.08)],
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
                    }
                    .scrollIndicators(.hidden)

                    transactionsSection
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

    private var transactionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Letzte Buchungen")
                .font(.headline)

            List {
                ForEach($viewModel.transactions) { $item in
                    HStack(spacing: 8) {
                        TextField("Datum", text: $item.date)
                        TextField("Kategorie", text: $item.category)
                        TextField("Betrag", text: $item.amount)
                        TextField("Status", text: $item.status)
                    }
                    .textFieldStyle(.roundedBorder)
                    .padding(.vertical, 2)
                }
            }
            .frame(minHeight: 220)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
    @State private var showAddForm = false

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
                }

                List {
                    ForEach(viewModel.fixkostenEntries) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.name)
                                .font(.headline)
                            Text(entry.description)
                                .foregroundStyle(.secondary)
                            Text("Netto: \(viewModel.formatCurrency(entry.netAmount)) · MwSt 19%: \(viewModel.formatCurrency(entry.vatAmount)) · Brutto: \(viewModel.formatCurrency(entry.grossAmount))")
                                .font(.callout)
                            Text("Datum: \(entry.bookingDate.formatted(date: .numeric, time: .omitted)) · Automatisch: \(entry.automaticDebit ? "Ja" : "Nein")")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding(20)
        }
        .frame(minWidth: 760, minHeight: 520)
        .sheet(isPresented: $showAddForm) {
            AddFixkostenForm(viewModel: viewModel)
        }
    }
}

private struct AddFixkostenForm: View {
    @ObservedObject var viewModel: DashboardViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var bookingDate = Date()
    @State private var automaticDebit = true
    @State private var netInput = ""
    @State private var description = ""

    private var netAmount: Double {
        Double(netInput.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var vatAmount: Double {
        netAmount * 0.19
    }

    private var grossAmount: Double {
        netAmount + vatAmount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Neue Fixkosten")
                .font(.title3.bold())

            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)

            DatePicker("Datum", selection: $bookingDate, displayedComponents: .date)

            Toggle("Automatische Abbuchung", isOn: $automaticDebit)

            TextField("Summe Netto", text: $netInput)
                .textFieldStyle(.roundedBorder)

            HStack {
                Text("MwSt 19%")
                Spacer()
                Text(viewModel.formatCurrency(vatAmount))
            }

            HStack {
                Text("Brutto")
                Spacer()
                Text(viewModel.formatCurrency(grossAmount))
                    .fontWeight(.semibold)
            }

            TextField("Beschreibung", text: $description, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)

            HStack {
                Spacer()
                Button("Abbrechen") { dismiss() }

                Button("Speichern") {
                    let entry = FixkostenEntry(
                        name: name.isEmpty ? "Neue Position" : name,
                        bookingDate: bookingDate,
                        automaticDebit: automaticDebit,
                        netAmount: netAmount,
                        description: description
                    )
                    viewModel.addFixkostenEntry(entry)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(netAmount <= 0)
            }
        }
        .padding(20)
        .frame(width: 460)
    }
}
