import SwiftUI

struct VATOverviewPage: View {
    @ObservedObject var router: BAAppRouter
    @ObservedObject var viewModel: DashboardViewModel

    var body: some View {
        AppShell {
            VStack(alignment: .leading, spacing: 12) {
                PageHeader(title: "Umsatzsteuer", subtitle: "Monatliche Übersicht", onBack: { router.setTop(.dashboard) })
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.groupedInvoicesByMonth()) { group in
                            let output = group.entries.filter { $0.type == .ausgangsrechnung }.reduce(0) { $0 + $1.vatAmount }
                            let input = group.entries.filter { $0.type == .eingangsrechnung }.reduce(0) { $0 + $1.vatAmount }
                            DSCard {
                                HStack {
                                    Text(group.title)
                                    Spacer()
                                    Text(viewModel.formatCurrency(output - input)).monospacedDigit()
                                }
                            }
                        }
                    }
                }
            }
            .padding(18)
        }
    }
}

struct RevenueByMonthPage: View {
    @ObservedObject var router: BAAppRouter
    @ObservedObject var viewModel: DashboardViewModel

    var body: some View {
        AppShell {
            VStack(alignment: .leading, spacing: 12) {
                PageHeader(title: "Umsatz", subtitle: "Nach Monaten", onBack: { router.setTop(.dashboard) })
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.monthlyStats()) { item in
                            DSCard {
                                HStack {
                                    Text(item.title)
                                    Spacer()
                                    Text(viewModel.formatCurrency(item.umsatz)).monospacedDigit()
                                }
                            }
                        }
                    }
                }
            }
            .padding(18)
        }
    }
}

struct IncomePage: View {
    @ObservedObject var router: BAAppRouter
    @ObservedObject var viewModel: DashboardViewModel

    var body: some View {
        AppShell {
            VStack(alignment: .leading, spacing: 12) {
                PageHeader(title: "Einnahmen", subtitle: "Bezahlt", onBack: { router.setTop(.dashboard) })
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.paidOutgoingInvoices) { invoice in
                            DSCard {
                                HStack {
                                    Text(invoice.title)
                                    Spacer()
                                    Text(viewModel.formatCurrency(invoice.netAmount))
                                        .monospacedDigit()
                                }
                            }
                        }
                    }
                }
            }
            .padding(18)
        }
    }
}
