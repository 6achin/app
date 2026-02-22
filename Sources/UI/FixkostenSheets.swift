import SwiftUI

struct FixkostenSheet: View {
    @ObservedObject var viewModel: DashboardViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showAddForm = false
    @State private var editingEntry: FixkostenEntry?

    var body: some View {
        ModalSheetContainer(title: "Fixkosten", onClose: { dismiss() }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Doppelklick auf eine Zeile, um sie zu bearbeiten.")
                        .font(.footnote)
                        .foregroundStyle(AppPalette.textSecondary)

                    Spacer()

                    Button {
                        showAddForm = true
                    } label: {
                        Label("Hinzufügen", systemImage: "plus")
                    }
                    .appPrimaryButtonStyle()
                }

                fixkostenHeader

                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.fixkostenEntries) { entry in
                            fixkostenRow(entry)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(minWidth: 860, minHeight: 620)
        .sheet(isPresented: $showAddForm) {
            AddFixkostenForm(viewModel: viewModel)
                .presentationDetents([.medium])
                .interactiveDismissDisabled(false)
        }
        .sheet(item: $editingEntry) { entry in
            EditFixkostenForm(viewModel: viewModel, entry: entry)
                .presentationDetents([.medium])
                .interactiveDismissDisabled(false)
        }
    }

    private var fixkostenHeader: some View {
        HStack(spacing: 10) {
            Text("Position")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppPalette.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Netto")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppPalette.textSecondary)
                .frame(width: 130, alignment: .trailing)

            Text("Brutto")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppPalette.textSecondary)
                .frame(width: 130, alignment: .trailing)

            Text("Intervall")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppPalette.textSecondary)
                .frame(width: 140, alignment: .leading)
        }
        .padding(.horizontal, 10)
    }

    private func fixkostenRow(_ entry: FixkostenEntry) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.name)
                    .font(.headline)
                    .foregroundStyle(AppPalette.textPrimary)
                if !entry.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(entry.description)
                        .font(.footnote)
                        .foregroundStyle(AppPalette.textSecondary)
                        .lineLimit(2)
                }
                Text("MwSt \(entry.vatLabel) · \(entry.automaticDebit ? "Automatisch" : "Manuell")")
                    .font(.caption)
                    .foregroundStyle(AppPalette.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(viewModel.formatCurrency(entry.netAmount))
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .frame(width: 130, alignment: .trailing)

            Text(viewModel.formatCurrency(entry.grossAmount))
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .frame(width: 130, alignment: .trailing)

            Text(entry.cycle.rawValue)
                .font(.callout)
                .foregroundStyle(AppPalette.textSecondary)
                .frame(width: 140, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppPalette.inputSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppPalette.border.opacity(0.6), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            editingEntry = entry
        }
    }
}

struct AddFixkostenForm: View {
    @ObservedObject var viewModel: DashboardViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var cycle: BillingCycle = .monatlich
    @State private var automaticDebit = true
    @State private var netInput = ""
    @State private var vatRate: Double = 0.19
    @State private var description = ""

    private var netAmount: Double {
        Double(netInput.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var vatAmount: Double {
        netAmount * vatRate
    }

    private var grossAmount: Double {
        netAmount + vatAmount
    }

    var body: some View {
        FixkostenFormContent(
            title: "Neue Fixkosten",
            name: $name,
            cycle: $cycle,
            automaticDebit: $automaticDebit,
            netInput: $netInput,
            vatRate: $vatRate,
            description: $description,
            vatAmountText: viewModel.formatCurrency(vatAmount),
            grossAmountText: viewModel.formatCurrency(grossAmount),
            onClose: { dismiss() },
            onCancel: { dismiss() },
            onSave: {
                let entry = FixkostenEntry(
                    name: name.isEmpty ? "Neue Position" : name,
                    cycle: cycle,
                    automaticDebit: automaticDebit,
                    netAmount: netAmount,
                    vatRate: vatRate,
                    description: description
                )
                viewModel.addFixkostenEntry(entry)
                dismiss()
            },
            isSaveDisabled: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || netAmount <= 0
        )
    }
}

struct EditFixkostenForm: View {
    @ObservedObject var viewModel: DashboardViewModel
    @Environment(\.dismiss) private var dismiss

    let entry: FixkostenEntry

    @State private var name = ""
    @State private var cycle: BillingCycle = .monatlich
    @State private var automaticDebit = true
    @State private var netInput = ""
    @State private var vatRate: Double = 0.19
    @State private var description = ""

    private var netAmount: Double {
        Double(netInput.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var vatAmount: Double {
        netAmount * vatRate
    }

    private var grossAmount: Double {
        netAmount + vatAmount
    }

    var body: some View {
        FixkostenFormContent(
            title: "Fixkosten bearbeiten",
            name: $name,
            cycle: $cycle,
            automaticDebit: $automaticDebit,
            netInput: $netInput,
            vatRate: $vatRate,
            description: $description,
            vatAmountText: viewModel.formatCurrency(vatAmount),
            grossAmountText: viewModel.formatCurrency(grossAmount),
            onClose: { dismiss() },
            onCancel: { dismiss() },
            onSave: {
                let updated = FixkostenEntry(
                    id: entry.id,
                    name: name,
                    cycle: cycle,
                    automaticDebit: automaticDebit,
                    netAmount: netAmount,
                    vatRate: vatRate,
                    description: description
                )
                viewModel.updateFixkostenEntry(updated)
                dismiss()
            },
            isSaveDisabled: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || netAmount <= 0
        )
        .onAppear {
            name = entry.name
            cycle = entry.cycle
            automaticDebit = entry.automaticDebit
            netInput = String(format: "%.2f", entry.netAmount).replacingOccurrences(of: ".", with: ",")
            vatRate = entry.vatRate
            description = entry.description
        }
    }
}

struct FixkostenFormContent: View {
    let title: String

    @Binding var name: String
    @Binding var cycle: BillingCycle
    @Binding var automaticDebit: Bool
    @Binding var netInput: String
    @Binding var vatRate: Double
    @Binding var description: String

    let vatAmountText: String
    let grossAmountText: String
    let onClose: () -> Void
    let onCancel: () -> Void
    let onSave: () -> Void
    let isSaveDisabled: Bool

    private var netAmount: Double {
        Double(netInput.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var isNameInvalid: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isNetInvalid: Bool {
        netAmount <= 0
    }

    private var formColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 12, alignment: .top),
            GridItem(.flexible(), spacing: 12, alignment: .top)
        ]
    }

    var body: some View {
        ModalSheetContainer(title: title, onClose: onClose) {
            VStack(alignment: .leading, spacing: 12) {
                GroupBox("Basis") {
                    LazyVGrid(columns: formColumns, spacing: 12) {
                        TextField("Name", text: $name)
                            .modalEditorStyle()
                            .appValidationHighlight(isNameInvalid)

                        Picker("Intervall", selection: $cycle) {
                            ForEach(BillingCycle.allCases) { interval in
                                Text(interval.rawValue).tag(interval)
                            }
                        }
                        .appSegmentedStyle()

                        TextField("Summe Netto", text: $netInput)
                            .modalEditorStyle()
                            .appValidationHighlight(isNetInvalid)

                        Picker("MwSt", selection: $vatRate) {
                            Text("19% ").tag(0.19)
                            Text("7%").tag(0.07)
                            Text("0%").tag(0.0)
                        }
                        .appSegmentedStyle()
                    }

                    Toggle("Automatische Abbuchung", isOn: $automaticDebit)
                        .padding(.top, 6)
                }
                .appFormGroupStyle()

                GroupBox("Summen") {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("MwSt")
                                .font(.caption)
                                .foregroundStyle(AppPalette.textSecondary)
                            Text(vatAmountText)
                                .font(.headline.weight(.semibold))
                                .monospacedDigit()
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .padding(10)
                        .background(AppPalette.inputSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Brutto")
                                .font(.caption)
                                .foregroundStyle(AppPalette.textSecondary)
                            Text(grossAmountText)
                                .font(.headline.weight(.semibold))
                                .monospacedDigit()
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .padding(10)
                        .background(AppPalette.inputSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                .appFormGroupStyle()

                GroupBox("Beschreibung") {
                    TextField("Beschreibung", text: $description, axis: .vertical)
                        .modalEditorStyle()
                        .lineLimit(2...4)
                }
                .appFormGroupStyle()

                HStack {
                    Spacer()
                    Button("Abbrechen", role: .cancel, action: onCancel)
                        .appSecondaryButtonStyle()
                    Button("Speichern", action: onSave)
                        .appPrimaryButtonStyle()
                        .disabled(isSaveDisabled)
                }
            }
        }
        .frame(width: 640)
    }
}
