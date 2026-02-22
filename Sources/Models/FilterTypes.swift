import Foundation

enum DebtFilterStatus: String, CaseIterable {
    case all, open, paid
}

enum DebtSort: String, CaseIterable {
    case dueDate, amountDesc, amountAsc
}

enum InvoiceFilterType: String, CaseIterable {
    case all, outgoing, incoming
}

enum InvoiceFilterStatus: String, CaseIterable {
    case all, open, paid
}

enum InvoiceSort: String, CaseIterable {
    case dateDesc, dateAsc, amountDesc
}
