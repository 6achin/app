import SwiftUI

struct DashboardView: View {
    @ObservedObject var viewModel: DashboardViewModel
    let onLogout: () -> Void

    @State private var selectedCard: MetricCard?
    @State private var editedTitle = ""
    @State private var editedValue = ""
    @State private var editedNote = ""

    var body: some View {
        NavigationSplitView {
            List {
                Button("Dashboard") {}
                Button("Umsatz") {}
                Button("Ausgaben") {}
                Button("Berichte") {}
            }
            .buttonStyle(.plain)
            .navigationTitle("Menü")
        } detail: {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Geschäftsübersicht")
                            .font(.largeTitle.bold())
                        Text("Minimalistisch, klickbar und editierbar")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Hinzufügen") {
                        viewModel.addCard()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Abmelden", action: onLogout)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(viewModel.cards) { card in
                        Button {
                            selectedCard = card
                            editedTitle = card.title
                            editedValue = card.value
                            editedNote = card.note
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(card.title)
                                    .foregroundStyle(.secondary)
                                Text(card.value)
                                    .font(.title3.bold())
                                Text(card.note)
                                    .font(.callout)
                                    .foregroundStyle(.blue)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Letzte Buchungen (editierbar)")
                        .font(.headline)

                    List {
                        ForEach($viewModel.transactions) { $item in
                            HStack(spacing: 12) {
                                TextField("Datum", text: $item.date)
                                TextField("Kategorie", text: $item.category)
                                TextField("Betrag", text: $item.amount)
                                TextField("Status", text: $item.status)
                            }
                            .textFieldStyle(.roundedBorder)
                            .padding(.vertical, 4)
                        }
                    }
                    .frame(minHeight: 250)
                }

                Spacer()
            }
            .padding(24)
        }
        .sheet(item: $selectedCard) { card in
            VStack(alignment: .leading, spacing: 14) {
                Text("Karte bearbeiten")
                    .font(.headline)

                TextField("Titel", text: $editedTitle)
                    .textFieldStyle(.roundedBorder)
                TextField("Wert", text: $editedValue)
                    .textFieldStyle(.roundedBorder)
                TextField("Notiz", text: $editedNote)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Spacer()
                    Button("Abbrechen") { selectedCard = nil }
                    Button("Speichern") {
                        viewModel.updateCard(id: card.id, title: editedTitle, value: editedValue, note: editedNote)
                        selectedCard = nil
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(20)
            .frame(width: 420)
        }
    }
}
