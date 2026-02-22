import SwiftUI

struct InvoicesPage: View {
    @ObservedObject var router: BAAppRouter
    @ObservedObject var viewModel: DashboardViewModel
    @State private var search = ""

    private var filtered: [InvoiceEntry] {
        let text = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !text.isEmpty else { return viewModel.invoices }
        return viewModel.invoices.filter {
            $0.title.lowercased().contains(text) || ($0.invoiceNumber ?? "").lowercased().contains(text)
        }
    }

    var body: some View {
        AppShell {
            VStack(alignment: .leading, spacing: 12) {
                PageHeader(title: "Rechnungen", subtitle: "Liste", onBack: { router.setTop(.dashboard) })

                HStack {
                    TextField("Suche", text: $search).dsInput()
                    Button("Neue Rechnung") { router.push(.addInvoice) }.dsPrimaryButton()
                }

                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filtered) { invoice in
                            Button {
                                router.push(.invoiceDetail(invoice.id))
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(invoice.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Theme.textPrimary)
                                        Text(invoice.invoiceNumber ?? "-")
                                            .font(.system(size: 12, weight: .regular))
                                            .foregroundStyle(Theme.textSecondary)
                                    }
                                    Spacer()
                                    Text(viewModel.formatCurrency(invoice.grossAmount))
                                        .font(.subheadline.weight(.semibold))
                                        .monospacedDigit()
                                        .foregroundStyle(Theme.textPrimary)
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

struct InvoiceDetailPage: View {
    @ObservedObject var router: BAAppRouter
    @ObservedObject var viewModel: DashboardViewModel
    let invoiceID: UUID

    private var invoice: InvoiceEntry? {
        viewModel.invoices.first(where: { $0.id == invoiceID })
    }

    var body: some View {
        AppShell {
            VStack(alignment: .leading, spacing: 12) {
                PageHeader(title: "Rechnungsdetail", subtitle: invoice?.title, onBack: { router.pop() })
                if let invoice {
                    DSCard {
                        VStack(alignment: .leading, spacing: 8) {
                            row("Nummer", invoice.invoiceNumber ?? "-")
                            row("Typ", invoice.type.rawValue)
                            row("Quelle", invoice.source.rawValue)
                            row("Netto", viewModel.formatCurrency(invoice.netAmount))
                            row("Brutto", viewModel.formatCurrency(invoice.grossAmount))
                        }
                    }
                }
                Spacer()
            }
            .padding(18)
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value).foregroundStyle(Theme.textPrimary)
        }
    }
}

struct AddInvoicePage: View {
    @ObservedObject var router: BAAppRouter
    @ObservedObject var viewModel: DashboardViewModel

    @State private var title = ""
    @State private var number = ""
    @State private var net = ""

    var body: some View {
        AppShell {
            VStack(alignment: .leading, spacing: 12) {
                PageHeader(title: "Neue Rechnung", subtitle: "Anlegen", onBack: { router.pop() })
                DSCard {
                    VStack(spacing: 10) {
                        TextField("Bezeichnung", text: $title).dsInput()
                        TextField("Rechnungs-Nr.", text: $number).dsInput()
                        TextField("Netto", text: $net).dsInput()

                        HStack {
                            Spacer()
                            Button("Abbrechen") { router.pop() }.dsSecondaryButton()
                            Button("Speichern") {
                                let amount = Double(net.replacingOccurrences(of: ",", with: ".")) ?? 0
                                let invoice = InvoiceEntry(
                                    title: title.isEmpty ? "Neue Rechnung" : title,
                                    source: .manual,
                                    type: .ausgangsrechnung,
                                    netAmount: amount,
                                    vatRate: 0.19,
                                    isPaid: false,
                                    issuedAt: Date(),
                                    invoiceNumber: number.isEmpty ? nil : number
                                )
                                viewModel.addInvoice(invoice)
                                router.pop()
                            }
                            .dsPrimaryButton()
                            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (Double(net.replacingOccurrences(of: ",", with: ".")) ?? 0) <= 0)
                        }
                    }
                }
                Spacer()
            }
            .padding(18)
        }
    }
}
