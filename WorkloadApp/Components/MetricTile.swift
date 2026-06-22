import SwiftUI

/// Reusable metric display tile used across Workload and Session detail views.
struct MetricTile: View {
    let title: String
    let value: String
    var subtitle: String?
    var color: Color = ColorTokens.text1

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.baselinePair) {
            Text(title)
                .font(.Tokens.micro)
                .tracking(1.2)
                .foregroundStyle(ColorTokens.text3)
            Text(value)
                .font(.Tokens.sectionHead)
                .monospacedDigit()
                .foregroundStyle(color)
            if let subtitle {
                Text(subtitle)
                    .font(.Tokens.micro)
                    .foregroundStyle(ColorTokens.text2)
            }
        }
        .cardStyle(horizontalPadding: Spacing.sm, verticalPadding: Spacing.sm)
    }
}

/// Square outline badge communicating zone state through text label + colored border.
/// Color is supplementary — the text label is always the primary information.
///
/// zh-Hans typography: per 23-UI-SPEC, Chinese has no case and looser tracking is wrong.
/// Apply textCase(.uppercase) and tracking(1.2) only when the env locale is English.
/// Horizontal padding widens for zh-Hans glyphs (16 vs 10).
struct ZoneBadge: View {
    @Environment(\.locale) private var locale
    let label: String
    let color: Color

    var body: some View {
        Text(label)
            .font(.Tokens.micro)
            .tracking(locale.language.languageCode?.identifier == "en" ? 1.2 : 0)
            .textCase(locale.language.languageCode?.identifier == "en" ? .uppercase : nil)
            .padding(.horizontal, locale.language.languageCode?.identifier == "zh" ? 16 : 10)
            .padding(.vertical, 5)
            .foregroundStyle(color)
            .overlay(
                Rectangle().stroke(color, lineWidth: 0.5)
            )
    }
}
