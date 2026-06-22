import SwiftUI

/// Colored arrow + percentage for week-over-week deltas (D-04).
/// Positive: green arrow.up + "+X%". Negative: red arrow.down + "-X%". Near-zero: em dash in text2.
struct DeltaIndicator: View {
    let delta: Double  // percentage value (e.g., 12.0 = +12%)

    var body: some View {
        if abs(delta) < 1.0 {
            // Negligible change
            Text("\u{2014}")
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text2)
        } else {
            HStack(spacing: 2) {
                Image(systemName: delta > 0 ? "arrow.up" : "arrow.down")
                    .font(.Tokens.smallLabel)
                Text(String(format: "%+.0f%%", delta))
                    .font(.Tokens.label)
            }
            .foregroundStyle(delta > 0 ? ColorTokens.zoneOptimal : ColorTokens.zoneDanger)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(delta > 0 ? "Increased \(Int(abs(delta))) percent week over week" : "Decreased \(Int(abs(delta))) percent week over week")
        }
    }
}
