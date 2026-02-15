import Foundation

struct MetricCard: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let trend: String
}

struct TransactionItem: Identifiable {
    let id = UUID()
    let date: String
    let category: String
    let amount: String
    let status: String
}

final class DashboardViewModel: ObservableObject {
    @Published var cards: [MetricCard] = [
        MetricCard(title: "Выручка за месяц", value: "₽ 1 240 000", trend: "+12%"),
        MetricCard(title: "Расходы", value: "₽ 640 000", trend: "-3%"),
        MetricCard(title: "Чистая прибыль", value: "₽ 600 000", trend: "+18%"),
        MetricCard(title: "Счета к оплате", value: "₽ 220 000", trend: "5 счетов")
    ]

    @Published var transactions: [TransactionItem] = [
        TransactionItem(date: "12.02.2026", category: "Закупки", amount: "₽ 54 000", status: "Оплачено"),
        TransactionItem(date: "11.02.2026", category: "Маркетинг", amount: "₽ 32 500", status: "В процессе"),
        TransactionItem(date: "09.02.2026", category: "Логистика", amount: "₽ 17 200", status: "Оплачено"),
        TransactionItem(date: "07.02.2026", category: "Зарплаты", amount: "₽ 410 000", status: "Оплачено")
    ]
}
