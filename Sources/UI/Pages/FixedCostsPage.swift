import SwiftUI

struct FixedCostsPage: View {
    @ObservedObject var router: BAAppRouter
    @ObservedObject var viewModel: DashboardViewModel

    var body: some View {
        AppShell {
            VStack(alignment: .leading, spacing: 12) {
                PageHeader(title: "Fixkosten", subtitle: "Monatliche Kosten", onBack: { router.setTop(.dashboard) })

                HStack {
                    Spacer()
                    Button("Neue Position") { router.push(.addFixedCost) }
                        .dsPrimaryButton()
                }

                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.fixkostenEntries) { item in
                            Button {
                                router.push(.editFixedCost(item.id))
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name).foregroundStyle(Theme.textPrimary)
                                        Text(item.cycle.rawValue).font(.system(size: 12, weight: .regular)).foregroundStyle(Theme.textSecondary)
                                    }
                                    Spacer()
                                    Text(viewModel.formatCurrency(item.grossAmount)).monospacedDigit().foregroundStyle(Theme.textPrimary)
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

struct FixedCostEditPage: View {
    @ObservedObject var router: BAAppRouter
    @ObservedObject var viewModel: DashboardViewModel
    let entryID: UUID?

    @State private var name = ""
    @State private var cycle: BillingCycle = .monatlich
    @State private var amount = ""

    var isEditing: Bool { entryID != nil }

    var body: some View {
        AppShell {
            VStack(alignment: .leading, spacing: 12) {
                PageHeader(title: isEditing ? "Fixkosten bearbeiten" : "Neue Fixkosten", subtitle: nil, onBack: { router.pop() })
                DSCard {
                    VStack(spacing: 10) {
                        TextField("Name", text: $name).dsInput()
                        Picker("Intervall", selection: $cycle) {
                            ForEach(BillingCycle.allCases) { x in Text(x.rawValue).tag(x) }
                        }
                        .pickerStyle(.menu)
                        TextField("Netto", text: $amount).dsInput()
                        HStack {
                            Spacer()
                            Button("Abbrechen") { router.pop() }.dsSecondaryButton()
                            Button("Speichern") { save() }.dsPrimaryButton()
                        }
                    }
                }
                Spacer()
            }
            .padding(18)
            .onAppear(perform: preload)
        }
    }

    private func preload() {
        guard let entryID, let found = viewModel.fixkostenEntries.first(where: { $0.id == entryID }) else { return }
        name = found.name
        cycle = found.cycle
        amount = String(format: "%.2f", found.netAmount).replacingOccurrences(of: ".", with: ",")
    }

    private func save() {
        let net = Double(amount.replacingOccurrences(of: ",", with: ".")) ?? 0
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, net > 0 else { return }

        if let entryID {
            let updated = FixkostenEntry(id: entryID, name: name, cycle: cycle, automaticDebit: true, netAmount: net, vatRate: 0.19, description: "")
            viewModel.updateFixkostenEntry(updated)
        } else {
            let created = FixkostenEntry(name: name, cycle: cycle, automaticDebit: true, netAmount: net, vatRate: 0.19, description: "")
            viewModel.addFixkostenEntry(created)
        }
        router.pop()
    }
}
