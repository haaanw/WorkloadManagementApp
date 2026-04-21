import SwiftUI

/// Reusable metric display tile used across Workload and Session detail views.
struct MetricTile: View {
    let title: String
    let value: String
    var subtitle: String?
    var color: Color = ColorTokens.text1

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(ColorTokens.surface)
        .overlay(
            Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5)
        )
    }
}

/// Square outline badge communicating zone state through text label + colored border.
/// Color is supplementary — the text label is always the primary information.
struct ZoneBadge: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label)
            .font(.Tokens.micro)
            .tracking(1.2)
            .textCase(.uppercase)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(color)
            .overlay(
                Rectangle().stroke(color, lineWidth: 0.5)
            )
    }
}
