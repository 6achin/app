import SwiftUI

struct DashboardView: View {
    @ObservedObject var viewModel: DashboardViewModel
    let onLogout: () -> Void

    var body: some View {
        NavigationSplitView {
            List {
                Label("Дашборд", systemImage: "speedometer")
                Label("Доходы", systemImage: "chart.bar")
                Label("Расходы", systemImage: "creditcard")
                Label("Отчеты", systemImage: "doc.text")
            }
            .navigationTitle("Меню")
        } detail: {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Система учета")
                            .font(.largeTitle.bold())
                        Text("Минималистичный обзор вашего бизнеса")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Выйти", action: onLogout)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(viewModel.cards) { card in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(card.title)
                                .foregroundStyle(.secondary)
                            Text(card.value)
                                .font(.title3.bold())
                            Text(card.trend)
                                .font(.callout)
                                .foregroundStyle(card.trend.contains("+") ? .green : .blue)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Последние операции")
                        .font(.headline)

                    Table(viewModel.transactions) {
                        TableColumn("Дата", value: \.date)
                        TableColumn("Категория", value: \.category)
                        TableColumn("Сумма", value: \.amount)
                        TableColumn("Статус", value: \.status)
                    }
                    .frame(minHeight: 250)
                }

                Spacer()
            }
            .padding(24)
        }
    }
}
