import SwiftUI

private struct DebtItem: Identifiable, Hashable {
    let id: UUID
    var title: String
    var amount: Double

    init(id: UUID = UUID(), title: String, amount: Double) {
        self.id = id
        self.title = title
        self.amount = amount
    }
}

struct DebtsPage: View {
    @ObservedObject var router: BAAppRouter
    @State private var debts: [DebtItem] = [
        DebtItem(title: "Leasing", amount: 900),
        DebtItem(title: "Kreditlinie", amount: 4200)
    ]

    var body: some View {
        AppShell {
            VStack(alignment: .leading, spacing: 12) {
                PageHeader(title: "Schulden", subtitle: "Verbindlichkeiten", onBack: { router.setTop(.dashboard) })
                HStack {
                    Spacer()
                    Button("Neu") { router.push(.addDebt) }.dsPrimaryButton()
                }
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(debts) { debt in
                            Button {
                                router.push(.debtDetail(debt.id))
                            } label: {
                                HStack {
                                    Text(debt.title)
                                    Spacer()
                                    Text("€ \(String(format: "%.2f", debt.amount))")
                                        .monospacedDigit()
                                }
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(18)
        }
    }
}

struct DebtDetailPage: View {
    @ObservedObject var router: BAAppRouter
    let debtID: UUID

    var body: some View {
        AppShell {
            VStack(alignment: .leading, spacing: 12) {
                PageHeader(title: "Schulden Detail", subtitle: debtID.uuidString.prefix(8).description, onBack: { router.pop() })
                DSCard {
                    Text("Detailansicht")
                        .foregroundStyle(Theme.textSecondary)
                }
                Button("Bearbeiten") { router.push(.editDebt(debtID)) }
                    .dsPrimaryButton()
                Spacer()
            }
            .padding(18)
        }
    }
}

enum DebtEditMode {
    case add
    case edit(UUID)
}

struct DebtEditPage: View {
    @ObservedObject var router: BAAppRouter
    let mode: DebtEditMode
    @State private var title = ""
    @State private var amount = ""

    var body: some View {
        AppShell {
            VStack(alignment: .leading, spacing: 12) {
                PageHeader(title: modeTitle, subtitle: nil, onBack: { router.pop() })
                DSCard {
                    VStack(spacing: 10) {
                        TextField("Titel", text: $title).dsInput()
                        TextField("Betrag", text: $amount).dsInput()
                        HStack {
                            Spacer()
                            Button("Abbrechen") { router.pop() }.dsSecondaryButton()
                            Button("Speichern") { router.pop() }.dsPrimaryButton()
                        }
                    }
                }
                Spacer()
            }
            .padding(18)
        }
    }

    private var modeTitle: String {
        switch mode {
        case .add: return "Schuld hinzufügen"
        case .edit: return "Schuld bearbeiten"
        }
    }
}
