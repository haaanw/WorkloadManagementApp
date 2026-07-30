import SwiftUI

/// Natural language fatigue pattern insight card.
///
/// The insight itself is something the app SAYS, so it stays in the working voice. Its sample
/// size is the provenance footnote on that claim — marginalia, so it renders in the annotation
/// voice (DESIGN.md v6).
struct InsightCard: View {
    let text: String           // "Recovery typically drops 8 points 2 days after high-volume sessions"
    let sampleSize: Int        // Number of occurrences

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(text)
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text1)
            AnnotationLabel(
                String(format: String(localized: "insight.sample.suffix", defaultValue: "Based on %d occurrences"), sampleSize),
                size: .small
            )
                .annotationReveal()
        }
        .cardStyle()
    }
}
