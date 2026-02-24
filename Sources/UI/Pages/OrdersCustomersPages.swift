import SwiftUI

struct OrdersPage: View {
    @ObservedObject var router: BAAppRouter
    @ObservedObject var ordersStore: OrdersStore

    @State private var query = ""
    @State private var selectedDate: Date? = nil
    @State private var showCreate = false

    private var filtered: [OrderItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return ordersStore.orders }
        return ordersStore.orders.filter {
            [$0.customerLabel, $0.status].joined(separator: " ").lowercased().contains(q)
        }
    }

    var body: some View {
        AppShell {
            VStack(alignment: .leading, spacing: 12) {
                PageHeader(title: "Bestellungen", subtitle: "Alle Bestellungen", onBack: { router.setTop(.dashboard) })

                HStack(spacing: 10) {
                    TextField("Suche Bestellungen (Nr., Kunde, Firma, Email, Telefon)", text: $query)
                        .dsInput()

                    DSCalendarFilter(selectedDate: $selectedDate)

                    Button {
                        showCreate = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .dsPrimaryButton()
                    .help("Neue Bestellung")
                }

                if filtered.isEmpty {
                    DSCard {
                        VStack(spacing: 10) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(Theme.textSecondary)
                            Text("Noch keine Bestellungen")
                                .font(.headline)
                                .foregroundStyle(Theme.textPrimary)
                            Text("Erstelle deine erste Bestellung über \"+\" oder den Button \"Neue Bestellung\" im Dashboard.")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 220)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(filtered) { order in
                                Button {
                                    router.push(.orderDetail(order.id))
                                } label: {
                                    DSCard {
                                        HStack {
                                            Text(order.customerLabel)
                                            Spacer()
                                            Text("\(order.lines.count) Pos.")
                                            Text(String(format: "€ %.2f", order.grossTotal)).monospacedDigit()
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

                Spacer()
            }
            .padding(18)
        }
        .sheet(isPresented: $showCreate) {
            NewOrderModal()
        }
    }
}

struct OrderDetailPage: View {
    @ObservedObject var router: BAAppRouter
    @ObservedObject var ordersStore: OrdersStore
    let orderID: UUID

    private var order: OrderItem? { ordersStore.orders.first(where: { $0.id == orderID }) }

    var body: some View {
        AppShell {
            VStack(alignment: .leading, spacing: 12) {
                PageHeader(title: "Bestellung", subtitle: order?.customerLabel, onBack: { router.pop() })
                if let order {
                    DSCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Packing list")
                                .font(.headline)
                            ForEach(order.lines) { line in
                                HStack { Text(line.sku); Text(line.desc); Spacer(); Text("\(line.qty, specifier: "%.0f") x \(line.unitPrice, specifier: "%.2f")").monospacedDigit() }
                                    .font(.system(size: 12))
                            }
                        }
                    }
                }
                Spacer()
            }
            .padding(18)
        }
    }
}

struct CustomersPage: View {
    @ObservedObject var router: BAAppRouter
    @ObservedObject var customersStore: CustomersStore

    @State private var query = ""
    @State private var showCreate = false

    private var filtered: [CustomerItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return customersStore.customers }
        return customersStore.customers.filter {
            [$0.number, $0.name, $0.phone, $0.email, $0.address, $0.city].joined(separator: " ").lowercased().contains(q)
        }
    }

    var body: some View {
        AppShell {
            VStack(alignment: .leading, spacing: 12) {
                PageHeader(title: "Kunden", subtitle: "Alle Kunden", onBack: { router.setTop(.dashboard) })
                HStack {
                    TextField("Suche Kunden", text: $query).dsInput()
                    Button("Kunde hinzufügen") { showCreate = true }.dsPrimaryButton()
                }
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filtered) { customer in
                            Button {
                                router.push(.customerDetail(customer.id))
                            } label: {
                                DSCard {
                                    HStack {
                                        Text(customer.number).frame(width: 90, alignment: .leading)
                                        Text(customer.name).frame(width: 170, alignment: .leading)
                                        Text(customer.address).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                                        Text(customer.phone).frame(width: 120, alignment: .leading)
                                        Text(customer.email).lineLimit(1).frame(width: 180, alignment: .leading)
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
        }
        .sheet(isPresented: $showCreate) {
            CustomerFormModal(customersStore: customersStore)
        }
    }
}

struct CustomerDetailPage: View {
    @ObservedObject var router: BAAppRouter
    @ObservedObject var customersStore: CustomersStore
    let customerID: UUID

    private var customer: CustomerItem? { customersStore.customers.first(where: { $0.id == customerID }) }

    var body: some View {
        AppShell {
            VStack(alignment: .leading, spacing: 12) {
                PageHeader(title: "Kunde", subtitle: customer?.name, onBack: { router.pop() })
                if let customer {
                    DSCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Nr: \(customer.number)")
                            Text("Adresse: \(customer.address), \(customer.city)")
                            Text("Kontakt: \(customer.phone) · \(customer.email)")
                        }
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textPrimary)
                    }
                }
                Spacer()
            }
            .padding(18)
        }
    }
}

struct CustomerFormModal: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var customersStore: CustomersStore

    @State private var number = ""
    @State private var name = ""
    @State private var city = ""
    @State private var address = ""
    @State private var phone = ""
    @State private var email = ""

    var body: some View {
        AppShell {
            VStack(alignment: .leading, spacing: 10) {
                HStack { Text("Kunde erstellen").font(.headline); Spacer(); Button("✕") { dismiss() }.dsSecondaryButton() }
                DSCard {
                    VStack(spacing: 10) {
                        TextField("Kunden-Nr.", text: $number).dsInput()
                        TextField("Name", text: $name).dsInput()
                        HStack { TextField("Stadt", text: $city).dsInput(); TextField("Adresse", text: $address).dsInput() }
                        HStack { TextField("Telefon", text: $phone).dsInput(); TextField("Email", text: $email).dsInput() }
                        HStack { Spacer(); Button("Abbrechen") { dismiss() }.dsSecondaryButton(); Button("Speichern") { save() }.dsPrimaryButton() }
                    }
                }
            }
            .padding(18)
            .frame(width: 620)
        }
    }

    private func save() {
        guard !name.isEmpty else { return }
        let customer = CustomerItem(id: UUID(), number: number.isEmpty ? "K-\(Int.random(in: 1000...9999))" : number, name: name, city: city, address: address, phone: phone, email: email)
        customersStore.upsert(customer)
        dismiss()
    }
}
