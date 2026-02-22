import SwiftUI

struct DashboardPage: View {
    @ObservedObject var router: BAAppRouter
    @ObservedObject var viewModel: DashboardViewModel

    private let appVersion = AppVersionReader.readVersion()

    private var kpiCards: [MetricCard] {
        viewModel.cards.filter {
            [.umsatz, .umsatzsteuer, .rechnungenOffen, .einnahmen, .fixkosten].contains($0.type)
        }
    }

    var body: some View {
        AppShell {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dashboard")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("CRM Übersicht")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                    }

                    Spacer()

                    Button("Neuer Auftrag") { router.push(.addDebt) }
                        .dsSecondaryButton()
                    Button("Neue Rechnung") { router.push(.addInvoice) }
                        .dsPrimaryButton()
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 12) {
                    ForEach(kpiCards) { card in
                        Button {
                            open(card.type)
                        } label: {
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
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.textSecondary)
                                }
                                .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)
                        .help("Öffnen")
                    }
                }

                Spacer()

                Text("App-Version: v\(appVersion)")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(18)
        }
    }

    private func open(_ type: MetricType) {
        switch type {
        case .umsatz:
            router.setTop(.umsatz)
        case .umsatzsteuer:
            router.setTop(.umsatzsteuer)
        case .rechnungenOffen:
            router.openInvoicesFromOpenKPI()
        case .einnahmen:
            router.setTop(.einnahmen)
        case .fixkosten:
            router.setTop(.fixkosten)
        }
    }
}

private enum AppVersionReader {
    static func readVersion() -> String {
        let candidates = [
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("package.json"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).deletingLastPathComponent().appendingPathComponent("package.json")
        ]

        for url in candidates {
            guard let data = try? Data(contentsOf: url),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let version = json["version"] as? String,
                  !version.isEmpty else { continue }
            return version
        }

        return "0.0.0"
    }
}
