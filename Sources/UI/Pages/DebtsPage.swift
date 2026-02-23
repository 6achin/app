import SwiftUI

struct DebtsPage: View {
    @ObservedObject var router: BAAppRouter
    @ObservedObject var store: DebtsStore

    @State private var showCreate = false

    var body: some View {
        AppShell {
            VStack(alignment: .leading, spacing: 12) {
                PageHeader(title: "Schulden", subtitle: "MVP", onBack: { router.setTop(.dashboard) })
                HStack { Spacer(); Button("Neu") { showCreate = true }.dsPrimaryButton() }

                DSCard {
                    HStack(spacing: 10) {
                        Text("Richtung").frame(width: 100, alignment: .leading)
                        Text("Gegenpartei").frame(width: 180, alignment: .leading)
                        Text("Betrag").frame(width: 120, alignment: .trailing)
                        Text("Fällig").frame(width: 100, alignment: .leading)
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
                                        Text(debt.counterparty).frame(width: 180, alignment: .leading)
                                        Text("\(debt.currency) \(String(format: "%.2f", debt.amount))").monospacedDigit().frame(width: 120, alignment: .trailing)
                                        Text(debt.dueDate.formatted(date: .numeric, time: .omitted)).frame(width: 100, alignment: .leading)
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
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .sheet(isPresented: $showCreate) {
            DebtFormModal(store: store)
        }
    }
}

struct DebtDetailPage: View {
    @ObservedObject var router: BAAppRouter
    @ObservedObject var store: DebtsStore
    let debtID: UUID

    @State private var showEdit = false

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
                            Text("Von/Bis: \(debt.startDate.formatted(date: .numeric, time: .omitted)) – \(debt.dueDate.formatted(date: .numeric, time: .omitted))")
                            Text("Status: \(debt.status.rawValue)")
                            Text("PDF: \(debt.attachmentLink ?? "-")")
                        }
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textPrimary)
                    }
                }
                Button("Bearbeiten") { showEdit = true }.dsPrimaryButton()
                Spacer()
            }
            .padding(18)
        }
        .sheet(isPresented: $showEdit) {
            DebtFormModal(store: store, editingID: debtID)
        }
    }
}

struct DebtFormModal: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: DebtsStore
    var editingID: UUID?

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

    init(store: DebtsStore, editingID: UUID? = nil) {
        _store = ObservedObject(wrappedValue: store)
        self.editingID = editingID
    }

    var body: some View {
        AppShell {
            VStack(alignment: .leading, spacing: 10) {
                HStack { Text(editingID == nil ? "Schuld hinzufügen" : "Schuld bearbeiten").font(.headline); Spacer(); Button("✕") { dismiss() }.dsSecondaryButton() }
                DSCard {
                    VStack(spacing: 10) {
                        Picker("Richtung", selection: $direction) { ForEach(DebtItem.Direction.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.menu)
                        TextField("Gegenpartei", text: $counterparty).dsInput()
                        HStack { TextField("Betrag", text: $amount).dsInput(); TextField("Währung", text: $currency).dsInput() }
                        HStack { DatePicker("Von", selection: $startDate, displayedComponents: .date); DatePicker("Bis", selection: $dueDate, displayedComponents: .date) }
                        Toggle("Zinsen aktiv", isOn: $interestEnabled)
                        if interestEnabled { TextField("Zinssatz %", text: $interestRate).dsInput() }
                        Toggle("Mit Steuer", isOn: $taxIncluded)
                        TextField("Monatsrate (optional)", text: $monthlyAmount).dsInput()
                        Picker("Status", selection: $status) { ForEach(DebtItem.Status.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.menu)
                        TextField("Notizen", text: $notes).dsInput()
                        TextField("PDF/Anhang Link", text: $attachmentLink).dsInput()
                        HStack { Spacer(); Button("Abbrechen") { dismiss() }.dsSecondaryButton(); Button("Speichern") { save() }.dsPrimaryButton() }
                    }
                }
            }
            .padding(18)
            .frame(width: 720)
            .onAppear(perform: preload)
        }
    }

    private func preload() {
        guard let editingID, let debt = store.debts.first(where: { $0.id == editingID }) else { return }
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
        guard let amountValue = Double(amount.replacingOccurrences(of: ",", with: ".")), !counterparty.isEmpty else { return }
        let id = editingID ?? UUID()
        let debt = DebtItem(id: id, direction: direction, counterparty: counterparty, amount: amountValue, currency: currency.isEmpty ? "EUR" : currency, startDate: startDate, dueDate: dueDate, interestEnabled: interestEnabled, interestRate: Double(interestRate.replacingOccurrences(of: ",", with: ".")), taxIncluded: taxIncluded, monthlyAmount: Double(monthlyAmount.replacingOccurrences(of: ",", with: ".")), status: status, notes: notes, attachmentLink: attachmentLink.isEmpty ? nil : attachmentLink)
        store.upsert(debt)
        dismiss()
    }
}

enum DebtEditMode { case add, edit(UUID) }

struct DebtEditPage: View {
    @ObservedObject var router: BAAppRouter
    @ObservedObject var store: DebtsStore
    let mode: DebtEditMode

    var body: some View {
        AppShell {
            VStack(alignment: .leading, spacing: 12) {
                PageHeader(title: "Schuld", subtitle: "Modal-basiert", onBack: { router.pop() })
                Button("Im Schulden-Tab erstellen") { router.setTop(.schulden) }.dsSecondaryButton()
                Spacer()
            }
            .padding(18)
        }
    }
}
