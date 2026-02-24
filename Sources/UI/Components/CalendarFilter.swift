import SwiftUI

/// Lightweight calendar filter with easy month navigation.
///
/// Phase 1: single-date selection (optionally used as a month anchor).
struct DSCalendarFilter: View {
    @Binding var selectedDate: Date?

    @State private var showPopover = false
    @State private var tempDate = Date()

    private static let labelFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateStyle = .medium
        return f
    }()

    private var label: String {
        if let selectedDate {
            return Self.labelFormatter.string(from: selectedDate)
        }
        return "Alle Daten"
    }

    var body: some View {
        Button {
            tempDate = selectedDate ?? Date()
            showPopover = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                Text(label)
                    .lineLimit(1)
            }
        }
        .dsSecondaryButton()
        .popover(isPresented: $showPopover) {
            AppShell {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Datum")
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Button("✕") { showPopover = false }
                            .dsSecondaryButton()
                    }

                    DSCard {
                        VStack(alignment: .leading, spacing: 10) {
                            // Graphical style supports month switching via built-in navigation.
                            DatePicker(
                                "",
                                selection: $tempDate,
                                displayedComponents: [.date]
                            )
                            .datePickerStyle(.graphical)
                            .labelsHidden()

                            HStack {
                                Button("Alle Daten") {
                                    selectedDate = nil
                                    showPopover = false
                                }
                                .dsSecondaryButton()

                                Spacer()

                                Button("Übernehmen") {
                                    selectedDate = tempDate
                                    showPopover = false
                                }
                                .dsPrimaryButton()
                            }
                        }
                    }
                }
                .padding(18)
                .frame(width: 420)
            }
        }
    }
}
