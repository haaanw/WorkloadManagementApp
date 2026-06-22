import SwiftUI

/// Natural language fatigue pattern insight card.
struct InsightCard: View {
    let text: String           // "Recovery typically drops 8 points 2 days after high-volume sessions"
    let sampleSize: Int        // Number of occurrences

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(text)
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text1)
            Text(String(format: String(localized: "insight.sample.suffix", defaultValue: "Based on %d occurrences"), sampleSize))
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text2)
        }
        .cardStyle()
    }
}
