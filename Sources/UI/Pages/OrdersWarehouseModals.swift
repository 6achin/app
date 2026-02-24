import SwiftUI

struct NewOrderModal: View {
    @Environment(\.dismiss) private var dismiss

    @State private var customer = ""
    @State private var note = ""

    var body: some View {
        AppShell {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Neue Bestellung")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Button("✕") { dismiss() }
                        .dsSecondaryButton()
                }

                DSCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Platzhalter")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)

                        TextField("Kunde / Firma", text: $customer)
                            .dsInput()
                        TextField("Notiz", text: $note)
                            .dsInput()

                        Text("Die Bestell-Logik (Positionen, Kunde-Auswahl, Speichern) kommt im nächsten Schritt.")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack {
                            Spacer()
                            Button("Abbrechen") { dismiss() }
                                .dsSecondaryButton()
                            Button("Speichern") { dismiss() }
                                .dsPrimaryButton()
                        }
                    }
                }
            }
            .padding(18)
            .frame(width: 640)
        }
    }
}

struct AddDeliveryModal: View {
    @Environment(\.dismiss) private var dismiss

    @State private var supplier = ""
    @State private var reference = ""
    @State private var note = ""

    var body: some View {
        AppShell {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Lieferung hinzufügen")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Button("✕") { dismiss() }
                        .dsSecondaryButton()
                }

                DSCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Platzhalter")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)

                        TextField("Lieferant", text: $supplier)
                            .dsInput()
                        TextField("Referenz / Lieferschein-Nr.", text: $reference)
                            .dsInput()
                        TextField("Notiz", text: $note)
                            .dsInput()

                        Text("Die Lager-Logik (Artikel hinzufügen, Mengen, Bestand) kommt im nächsten Schritt.")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack {
                            Spacer()
                            Button("Abbrechen") { dismiss() }
                                .dsSecondaryButton()
                            Button("Speichern") { dismiss() }
                                .dsPrimaryButton()
                        }
                    }
                }
            }
            .padding(18)
            .frame(width: 640)
        }
    }
}
