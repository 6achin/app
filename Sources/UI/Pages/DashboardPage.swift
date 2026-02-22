import SwiftUI

struct DashboardPage: View {
    @ObservedObject var router: BAAppRouter
    @ObservedObject var viewModel: DashboardViewModel
    @Environment(\.uiDensityMode) private var density

    private let appVersion = AppVersionReader.readVersion()

    private var kpiCards: [MetricCard] {
        viewModel.cards.filter {
            [.umsatz, .umsatzsteuer, .rechnungenOffen, .einnahmen, .fixkosten].contains($0.type)
        }
    }

    var body: some View {
        AppShell {
            VStack(alignment: .leading, spacing: density.spacing) {
                header

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: density.spacing)], spacing: density.spacing) {
                    ForEach(kpiCards) { card in
                        let trend = trendInfo(for: card.type)
                        Button {
                            open(card.type)
                        } label: {
                            DSCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(card.title)
                                        .font(.footnote)
                                        .foregroundStyle(Theme.textSecondary)

                                    Spacer(minLength: 0)

                                    Text(mainValue(for: card.type, fallback: card.value))
                                        .font(.title3.weight(.semibold))
                                        .foregroundStyle(Theme.textPrimary)
                                        .monospacedDigit()

                                    bottomLine(for: card.type, trend: trend)
                                }
                                .frame(maxWidth: .infinity, minHeight: density == .compact ? 96 : 112, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()

                Text("App-Version: v\(appVersion)")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(density == .compact ? 14 : 20)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var header: some View {
        HStack {
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
    }

    @ViewBuilder
    private func bottomLine(for type: MetricType, trend: MoMTrend) -> some View {
        switch type {
        case .umsatzsteuer:
            HStack {
                Text("Ausgang: \(viewModel.formatCurrency(vatOutputCurrent)) · Eingang: \(viewModel.formatCurrency(vatInputCurrent))")
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(trend.label)
                    .foregroundStyle(trend.color)
            }
            .font(.system(size: 11))
            .foregroundStyle(Theme.textSecondary)

        case .rechnungenOffen:
            HStack {
                Text("Bezahlt: \(paidCurrentMonthCount)")
                Spacer(minLength: 8)
                Text("Überfällig: \(overdueCurrentMonthCount)")
                    .foregroundStyle(overdueCurrentMonthCount > 0 ? Theme.danger : Theme.textSecondary)
            }
            .font(.system(size: 11))
            .foregroundStyle(Theme.textSecondary)

        default:
            Text(trend.label)
                .font(.system(size: 11))
                .foregroundStyle(trend.color)
        }
    }

    private func mainValue(for type: MetricType, fallback: String) -> String {
        switch type {
        case .umsatz:
            return viewModel.formatCurrency(revenueCurrent)
        case .umsatzsteuer:
            return viewModel.formatCurrency(vatPayableCurrent)
        case .rechnungenOffen:
            return "\(openCurrentMonthCount)"
        case .einnahmen:
            return viewModel.formatCurrency(incomeCurrent)
        case .fixkosten:
            return viewModel.formatCurrency(fixkostenCurrent)
        }
    }

    private func trendInfo(for type: MetricType) -> MoMTrend {
        let t: Double
        switch type {
        case .umsatz:
            t = mom(current: revenueCurrent, previous: revenuePrevious)
        case .umsatzsteuer:
            t = mom(current: vatPayableCurrent, previous: vatPayablePrevious)
        case .rechnungenOffen:
            t = mom(current: Double(openCurrentMonthCount), previous: Double(openPreviousMonthCount))
        case .einnahmen:
            t = mom(current: incomeCurrent, previous: incomePrevious)
        case .fixkosten:
            t = mom(current: fixkostenCurrent, previous: fixkostenPrevious, lowerIsBetter: true)
        }
        return MoMTrend(value: t)
    }

    private func open(_ type: MetricType) {
        switch type {
        case .umsatz: router.setTop(.umsatz)
        case .umsatzsteuer: router.setTop(.umsatzsteuer)
        case .rechnungenOffen: router.openInvoicesFromOpenKPI()
        case .einnahmen: router.setTop(.einnahmen)
        case .fixkosten: router.setTop(.fixkosten)
        }
    }

    private var currentMonth: Date { viewModel.startOfMonth(for: Date()) }
    private var previousMonth: Date {
        Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
    }

    private var currentInvoices: [InvoiceEntry] {
        viewModel.invoices.filter { viewModel.startOfMonth(for: $0.issuedAt) == currentMonth }
    }
    private var previousInvoices: [InvoiceEntry] {
        viewModel.invoices.filter { viewModel.startOfMonth(for: $0.issuedAt) == previousMonth }
    }

    private var revenueCurrent: Double { currentInvoices.filter { $0.type == .ausgangsrechnung }.reduce(0) { $0 + $1.netAmount } }
    private var revenuePrevious: Double { previousInvoices.filter { $0.type == .ausgangsrechnung }.reduce(0) { $0 + $1.netAmount } }

    private var vatOutputCurrent: Double { currentInvoices.filter { $0.type == .ausgangsrechnung }.reduce(0) { $0 + $1.vatAmount } }
    private var vatInputCurrent: Double { currentInvoices.filter { $0.type == .eingangsrechnung }.reduce(0) { $0 + $1.vatAmount } }
    private var vatPayableCurrent: Double { vatOutputCurrent - vatInputCurrent }

    private var vatOutputPrevious: Double { previousInvoices.filter { $0.type == .ausgangsrechnung }.reduce(0) { $0 + $1.vatAmount } }
    private var vatInputPrevious: Double { previousInvoices.filter { $0.type == .eingangsrechnung }.reduce(0) { $0 + $1.vatAmount } }
    private var vatPayablePrevious: Double { vatOutputPrevious - vatInputPrevious }

    private var paidCurrentMonthCount: Int { currentInvoices.filter { $0.isPaid }.count }
    private var overdueCurrentMonthCount: Int { currentInvoices.filter { viewModel.dueState(for: $0) == "overdue" }.count }
    private var openCurrentMonthCount: Int { currentInvoices.filter { !$0.isPaid }.count }
    private var openPreviousMonthCount: Int { previousInvoices.filter { !$0.isPaid }.count }

    private var fixkostenCurrent: Double { viewModel.fixkostenEntries.reduce(0) { $0 + $1.grossAmount } }
    private var fixkostenPrevious: Double { fixkostenCurrent }

    private var incomeCurrent: Double { revenueCurrent - max(vatPayableCurrent, 0) - viewModel.kreditUndDarlehenMonatlich - fixkostenCurrent }
    private var incomePrevious: Double { revenuePrevious - max(vatPayablePrevious, 0) - viewModel.kreditUndDarlehenMonatlich - fixkostenPrevious }

    private func mom(current: Double, previous: Double, lowerIsBetter: Bool = false) -> Double {
        guard abs(previous) > 0.0001 else { return .infinity }
        let raw = ((current - previous) / abs(previous)) * 100
        return lowerIsBetter ? -raw : raw
    }
}

private struct MoMTrend {
    let value: Double

    var isNeutral: Bool { value.isFinite ? abs(value) <= 1 : false }

    var color: Color {
        if !value.isFinite { return Theme.textSecondary }
        if isNeutral { return Theme.textSecondary }
        return value > 0 ? Theme.success : Theme.danger
    }

    var label: String {
        guard value.isFinite else { return "vs last month: —" }
        if isNeutral { return "vs last month: 0%" }
        return String(format: "vs last month: %@%.1f%%", value > 0 ? "+" : "", value)
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
