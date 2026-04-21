import SwiftUI

/// Natural language fatigue pattern insight card.
struct InsightCard: View {
    let text: String           // "Recovery typically drops 8 points 2 days after high-volume sessions"
    let sampleSize: Int        // Number of occurrences

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text)
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text1)
            Text("Based on \(sampleSize) occurrences")
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(ColorTokens.surface)
        .overlay(
            Rectangle()
                .stroke(ColorTokens.divider, lineWidth: 0.5)
        )
    }
}
