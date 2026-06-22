import SwiftUI

/// Inline warning badge for stale HealthKit data (>24h threshold).
/// Displays below a metric value when the underlying data source is outdated.
struct StalenessWarningBadge: View {
    let daysAgo: Int

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.Tokens.micro)
                .foregroundStyle(ColorTokens.zoneCaution)
            Text(String(format: String(localized: "staleness.badge", defaultValue: "Updated %dd ago"), daysAgo))
                .font(.Tokens.micro)
                .foregroundStyle(ColorTokens.text2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "a11y.stalenessWarning", defaultValue: "Warning: health data last updated \(daysAgo) days ago"))
    }
}
