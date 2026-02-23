import SwiftUI

struct KPIButtonCard: View {
    let card: MetricCard
    let action: () -> Void

    private var isPrimaryCard: Bool {
        card.type == .umsatz
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Text(card.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(isPrimaryCard ? Color.white.opacity(0.90) : AppPalette.textSecondary)

                Text(card.value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(isPrimaryCard ? Color.white : AppPalette.textPrimary)
                    .minimumScaleFactor(0.85)

                Text(card.note)
                    .font(.callout)
                    .foregroundStyle(isPrimaryCard ? AppPalette.positive : AppPalette.cardNote)
            }
            .frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isPrimaryCard ? AppPalette.darkCardSurface : AppPalette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isPrimaryCard ? AppPalette.darkCardBorder : AppPalette.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(isPrimaryCard ? 0.10 : 0.05), radius: 7, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}
