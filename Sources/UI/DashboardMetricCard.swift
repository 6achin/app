import SwiftUI

struct KPIButtonCard: View {
    let card: MetricCard
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Text(card.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(card.type == .umsatz ? Color.white.opacity(0.88) : Color(red: 0.21, green: 0.22, blue: 0.26))
                Text(card.value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(card.type == .umsatz ? Color.white : Color(red: 0.11, green: 0.12, blue: 0.16))
                    .minimumScaleFactor(0.85)
                Text(card.note)
                    .font(.callout)
                    .foregroundStyle(card.type == .umsatz ? Color(red: 0.70, green: 0.93, blue: 0.76) : Color(red: 0.36, green: 0.37, blue: 0.41))
            }
            .frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(card.type == .umsatz ? Color(red: 0.17, green: 0.18, blue: 0.20) : Color(red: 0.94, green: 0.94, blue: 0.95))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(card.type == .umsatz ? Color(red: 0.24, green: 0.25, blue: 0.28) : Color(red: 0.78, green: 0.78, blue: 0.80), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(card.type == .umsatz ? 0.10 : 0.05), radius: 7, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}
