import SwiftUI

/// Compact progress row for gating intelligence features behind minimum data thresholds.
/// v3 (Ink & Grain, Stage 3): demoted from a centered 48pt ring stack to a single quiet
/// row — a 24pt inline ring beside the label — so it reads as supporting metadata and
/// never competes with a hero surface.
struct DataSufficiencyRing: View {
    let progress: Double   // 0.0 to 1.0
    let label: String      // "3 of 8 weeks"
    let message: String    // "Keep logging — periodization insights unlock after 8 weeks"

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.xs) {
            ZStack {
                Circle()
                    .stroke(ColorTokens.divider, lineWidth: 2)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(ColorTokens.accent, lineWidth: 2)
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 24, height: 24)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.baselinePair) {
                Text(label)
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text1)
                if !message.isEmpty {
                    Text(message)
                        .font(.Tokens.smallLabel)
                        .foregroundStyle(ColorTokens.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
    }
}
