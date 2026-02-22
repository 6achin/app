import SwiftUI

struct DebtItem: Identifiable, Hashable {
    enum Direction: String, CaseIterable, Identifiable { case iOwe = "I owe", owedToMe = "Owed to me"; var id: String { rawValue } }
    enum Status: String, CaseIterable, Identifiable { case active = "active", closed = "closed", overdue = "overdue"; var id: String { rawValue } }

    let id: UUID
    var direction: Direction
    var counterparty: String
    var amount: Double
    var currency: String
    var startDate: Date
    var dueDate: Date
    var interestEnabled: Bool
    var interestRate: Double?
    var taxIncluded: Bool
    var monthlyAmount: Double?
    var status: Status
    var notes: String
    var attachmentLink: String?
}

final class DebtsStore: ObservableObject {
    @Published var debts: [DebtItem] = [
        DebtItem(id: UUID(), direction: .iOwe, counterparty: "Leasing Partner", amount: 900, currency: "EUR", startDate: .now, dueDate: Calendar.current.date(byAdding: .month, value: 12, to: .now) ?? .now, interestEnabled: true, interestRate: 2.5, taxIncluded: false, monthlyAmount: 85, status: .active, notes: "", attachmentLink: nil)
    ]

    func upsert(_ item: DebtItem) {
        if let idx = debts.firstIndex(where: { $0.id == item.id }) { debts[idx] = item } else { debts.append(item) }
    }
}

struct DebtsPage: View {
    @ObservedObject var router: BAAppRouter
    @ObservedObject var store: DebtsStore

    var body: some View {
        AppShell {
            VStack(alignment: .leading, spacing: 12) {
                PageHeader(title: "Schulden", subtitle: "MVP", onBack: { router.setTop(.dashboard) })
                HStack { Spacer(); Button("Neu") { router.push(.addDebt) }.dsPrimaryButton() }

                DSCard {
                    HStack(spacing: 10) {
                        Text("Richtung").frame(width: 100, alignment: .leading)
                        Text("Gegenpartei").frame(width: 160, alignment: .leading)
                        Text("Betrag").frame(width: 110, alignment: .trailing)
                        Text("Von/Bis").frame(width: 190, alignment: .leading)
                        Text("Status").frame(width: 80, alignment: .leading)
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                }

                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(store.debts) { debt in
                            Button {
                                router.push(.debtDetail(debt.id))
                            } label: {
                                DSCard {
                                    HStack(spacing: 10) {
                                        Text(debt.direction.rawValue).frame(width: 100, alignment: .leading)
                                        Text(debt.counterparty).frame(width: 160, alignment: .leading)
                                        Text("\(debt.currency) \(String(format: "%.2f", debt.amount))").monospacedDigit().frame(width: 110, alignment: .trailing)
                                        Text("\(debt.startDate.formatted(date: .numeric, time: .omitted)) – \(debt.dueDate.formatted(date: .numeric, time: .omitted))").frame(width: 190, alignment: .leading)
                                        Text(debt.status.rawValue).frame(width: 80, alignment: .leading)
                                    }
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.textPrimary)
                                }
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
    @ObservedObject var store: DebtsStore
    let debtID: UUID

    private var debt: DebtItem? { store.debts.first(where: { $0.id == debtID }) }

    var body: some View {
        AppShell {
            VStack(alignment: .leading, spacing: 12) {
                PageHeader(title: "Schulden Detail", subtitle: debt?.counterparty, onBack: { router.pop() })
                if let debt {
                    DSCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Richtung: \(debt.direction.rawValue)")
                            Text("Betrag: \(debt.currency) \(String(format: "%.2f", debt.amount))")
                            Text("Status: \(debt.status.rawValue)")
                            Text("Notiz: \(debt.notes.isEmpty ? "-" : debt.notes)")
                            Text("PDF: \(debt.attachmentLink ?? "-")")
                        }
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textPrimary)
                    }
                }
                Button("Bearbeiten") { router.push(.editDebt(debtID)) }.dsPrimaryButton()
                Spacer()
            }
            .padding(18)
        }
    }
}

enum DebtEditMode { case add, edit(UUID) }

struct DebtEditPage: View {
    @ObservedObject var router: BAAppRouter
    @ObservedObject var store: DebtsStore
    let mode: DebtEditMode

    @State private var direction: DebtItem.Direction = .iOwe
    @State private var counterparty = ""
    @State private var amount = ""
    @State private var currency = "EUR"
    @State private var startDate = Date()
    @State private var dueDate = Date()
    @State private var interestEnabled = false
    @State private var interestRate = ""
    @State private var taxIncluded = false
    @State private var monthlyAmount = ""
    @State private var status: DebtItem.Status = .active
    @State private var notes = ""
    @State private var attachmentLink = ""

    var body: some View {
        AppShell {
            VStack(alignment: .leading, spacing: 12) {
                PageHeader(title: modeTitle, subtitle: nil, onBack: { router.pop() })
                DSCard {
                    VStack(spacing: 10) {
                        Picker("Richtung", selection: $direction) { ForEach(DebtItem.Direction.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.menu)
                        TextField("Gegenpartei", text: $counterparty).dsInput()
                        HStack { TextField("Betrag", text: $amount).dsInput(); TextField("Währung", text: $currency).dsInput() }
                        HStack { DatePicker("Von", selection: $startDate, displayedComponents: .date); DatePicker("Bis", selection: $dueDate, displayedComponents: .date) }
                        Toggle("Zinsen aktiv", isOn: $interestEnabled)
                        if interestEnabled { TextField("Zinssatz %", text: $interestRate).dsInput() }
                        Toggle("Mit Steuer", isOn: $taxIncluded)
                        TextField("Monatsrate (optional)", text: $monthlyAmount).dsInput()
                        Picker("Status", selection: $status) { ForEach(DebtItem.Status.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.menu)
                        TextField("Notizen", text: $notes).dsInput()
                        TextField("PDF/Anhang Link", text: $attachmentLink).dsInput()
                        HStack { Spacer(); Button("Abbrechen") { router.pop() }.dsSecondaryButton(); Button("Speichern") { save() }.dsPrimaryButton() }
                    }
                }
                Spacer()
            }
            .padding(18)
            .onAppear(perform: preload)
        }
    }

    private var modeTitle: String { if case .add = mode { return "Schuld hinzufügen" } else { return "Schuld bearbeiten" } }

    private func preload() {
        guard case .edit(let id) = mode, let debt = store.debts.first(where: { $0.id == id }) else { return }
        direction = debt.direction
        counterparty = debt.counterparty
        amount = String(format: "%.2f", debt.amount)
        currency = debt.currency
        startDate = debt.startDate
        dueDate = debt.dueDate
        interestEnabled = debt.interestEnabled
        interestRate = debt.interestRate.map { String($0) } ?? ""
        taxIncluded = debt.taxIncluded
        monthlyAmount = debt.monthlyAmount.map { String($0) } ?? ""
        status = debt.status
        notes = debt.notes
        attachmentLink = debt.attachmentLink ?? ""
    }

    private func save() {
        guard let amountDouble = Double(amount.replacingOccurrences(of: ",", with: ".")), !counterparty.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let id: UUID = { if case .edit(let x) = mode { return x } else { return UUID() } }()
        let item = DebtItem(
            id: id,
            direction: direction,
            counterparty: counterparty,
            amount: amountDouble,
            currency: currency.isEmpty ? "EUR" : currency,
            startDate: startDate,
            dueDate: dueDate,
            interestEnabled: interestEnabled,
            interestRate: Double(interestRate.replacingOccurrences(of: ",", with: ".")),
            taxIncluded: taxIncluded,
            monthlyAmount: Double(monthlyAmount.replacingOccurrences(of: ",", with: ".")),
            status: status,
            notes: notes,
            attachmentLink: attachmentLink.isEmpty ? nil : attachmentLink
        )
        store.upsert(item)
        router.pop()
    }
}
