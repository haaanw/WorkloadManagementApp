import SwiftUI

/// Circular progress indicator for gating intelligence features behind minimum data thresholds.
struct DataSufficiencyRing: View {
    let progress: Double   // 0.0 to 1.0
    let label: String      // "3 of 8 weeks"
    let message: String    // "Keep logging -- periodization insights unlock after 8 weeks"

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(ColorTokens.divider, lineWidth: 2)
                    .frame(width: 48, height: 48)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(ColorTokens.text2, lineWidth: 2)
                    .frame(width: 48, height: 48)
                    .rotationEffect(.degrees(-90))
            }
            Text(label)
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text1)
            Text(message)
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text2)
                .multilineTextAlignment(.center)
        }
        .padding(16)
    }
}
