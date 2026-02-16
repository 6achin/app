import SwiftUI

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
    @State private var showClearDataAlert = false
    @State private var didInitialRefresh = false

    private let cardColumns = [GridItem(.adaptive(minimum: 250), spacing: 14)]

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
            Color.clear
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Dashboard")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(AppPalette.textPrimary)
                        Text("Willkommen zurück, bachin")
                            .font(.title3)
                            .foregroundStyle(AppPalette.textSecondary)
                    }

                    Spacer()

                    Button {
                        showAddInvoiceSheet = true
                    } label: {
                        Label("Hinzufügen", systemImage: "plus")
                    }
                    .appPrimaryButtonStyle()
                    .keyboardShortcut("n", modifiers: [.command])
                    .help("Neue Rechnung hinzufügen (⌘N)")

                    Button("Abmelden", action: onLogout)
                        .appSecondaryButtonStyle()

                    Button("Alle Daten löschen", role: .destructive) {
                        showClearDataAlert = true
                    }
                    .appSecondaryButtonStyle()
                }

                monthNavigation

                LazyVGrid(columns: cardColumns, spacing: 14) {
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
            .frame(maxWidth: 1280, maxHeight: .infinity, alignment: .topLeading)
        }
        .appBackgroundStyle()
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
            guard !didInitialRefresh else { return }
            didInitialRefresh = true
            viewModel.recalculateAllMetrics()
        }
        .alert("Alle Daten wirklich löschen?", isPresented: $showClearDataAlert) {
            Button("Löschen", role: .destructive) {
                viewModel.clearAllData()
                selectedMonthStart = availableMonths.first
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Diese Aktion entfernt alle Rechnungen und Fixkosten dauerhaft aus dem lokalen Speicher.")
        }
    }

    private var monthNavigation: some View {
        HStack(spacing: 10) {
            Button {
                selectPreviousMonth()
            } label: {
                Image(systemName: "chevron.left")
            }
            .appSecondaryButtonStyle()
            .disabled(!canSelectPreviousMonth)

            Text(viewModel.monthTitle(for: activeMonthStart))
                .font(.headline.weight(.semibold))
                .frame(minWidth: 220)
                .foregroundStyle(AppPalette.textPrimary)

            Button {
                selectNextMonth()
            } label: {
                Image(systemName: "chevron.right")
            }
            .appSecondaryButtonStyle()
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
}
