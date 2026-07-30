import SwiftUI

/// Inline warning badge for stale HealthKit data (>24h threshold).
/// Displays below a metric value when the underlying data source is outdated.
///
/// v6 "Field Notes": a data timestamp is textbook marginalia, so the badge renders in the
/// **annotation voice** — the caution glyph is the Unicode `△` from the sanctioned glyph set
/// rather than an SF Symbol (Unicode is the icon system; no icon font, no emoji). The state is
/// carried by the text, never by colour alone. Callers place this inside a card plane (it lives
/// in `MetricCell`'s accessory slot, which is a `dataPlate`), satisfying DESIGN.md rule 7.
struct StalenessWarningBadge: View {
    let daysAgo: Int

    var body: some View {
        HStack(spacing: Spacing.xs) {
            AnnotationLabel("\u{25B3}", size: .small, color: ColorTokens.zoneCaution)
            AnnotationLabel(
                String(format: String(localized: "staleness.badge", defaultValue: "Updated %dd ago"), daysAgo),
                size: .small,
                color: ColorTokens.text2
            )
        }
        .annotationReveal()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "a11y.stalenessWarning", defaultValue: "Warning: health data last updated \(daysAgo) days ago"))
    }
}
