import SwiftUI

/// Inline warning badge for stale HealthKit data (>24h threshold).
/// Displays below a metric value when the underlying data source is outdated.
struct StalenessWarningBadge: View {
    let daysAgo: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.Tokens.micro)
                .foregroundStyle(ColorTokens.zoneCaution)
            Text("Updated \(daysAgo)d ago")
                .font(.Tokens.micro)
                .foregroundStyle(ColorTokens.text2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Warning: health data last updated \(daysAgo) days ago")
    }
}
