import SwiftUI

struct DashboardPage: View {
    @ObservedObject var router: BAAppRouter
    @ObservedObject var viewModel: DashboardViewModel

    var body: some View {
        AppShell {
            VStack(alignment: .leading, spacing: 14) {
                PageHeader(
                    title: "Dashboard",
                    subtitle: "CRM Übersicht",
                    onBack: { router.pop() },
                    backDisabled: true
                )

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                    ForEach(viewModel.cards) { card in
                        DSCard {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(card.title)
                                    .font(.footnote)
                                    .foregroundStyle(Theme.textSecondary)
                                Text(card.value)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(Theme.textPrimary)
                                    .monospacedDigit()
                                Text(card.note)
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                }

                DSCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Schnellzugriff")
                            .font(.headline)
                        HStack(spacing: 10) {
                            Button("Rechnungen") { router.setTop(.rechnungen) }.dsSecondaryButton()
                            Button("Umsatz") { router.setTop(.umsatz) }.dsSecondaryButton()
                            Button("USt") { router.setTop(.umsatzsteuer) }.dsSecondaryButton()
                            Button("Fixkosten") { router.setTop(.fixkosten) }.dsSecondaryButton()
                            Button("Einnahmen") { router.setTop(.einnahmen) }.dsSecondaryButton()
                            Button("Schulden") { router.setTop(.schulden) }.dsSecondaryButton()
                        }
                    }
                }
                Spacer()
            }
            .padding(18)
        }
    }
}
