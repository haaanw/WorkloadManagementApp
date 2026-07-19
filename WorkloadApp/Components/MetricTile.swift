import SwiftUI

/// Reusable metric display tile used across Workload and Session detail views.
/// v4 "Instrument": the value is a data numeral, so it renders in the dial voice
/// (`dialSmall` — IBM Plex Mono, tabular by construction).
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
                .font(.Tokens.dialSmall)
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

/// Hairline-bordered text-first chip communicating zone state (v4 "Instrument": near-square
/// `CornerTokens.control` corners — the pill silhouette is retired for zone chips). Zone
/// color appears as TEXT + border only, never as a fill; the text label is always the
/// primary information (color supplementary — never color alone).
///
/// zh-Hans typography: per 23-UI-SPEC, Chinese has no case and looser tracking is wrong.
/// Apply textCase(.uppercase) and tracking(1.2) only when the env locale is English.
/// Horizontal padding widens for zh-Hans glyphs (16 vs 8). Paddings sit on the 8pt grid
/// (+ the sanctioned 4pt sub-step).
struct ZoneBadge: View {
    @Environment(\.locale) private var locale
    let label: String
    let color: Color

    var body: some View {
        Text(label)
            .font(.Tokens.micro)
            .tracking(locale.language.languageCode?.identifier == "en" ? 1.2 : 0)
            .textCase(locale.language.languageCode?.identifier == "en" ? .uppercase : nil)
            .padding(.horizontal, locale.language.languageCode?.identifier == "zh" ? 16 : 8)
            .padding(.vertical, 4)
            .foregroundStyle(color)
            .overlay(
                RoundedRectangle(cornerRadius: CornerTokens.control).stroke(color, lineWidth: 0.5)
            )
    }
}
