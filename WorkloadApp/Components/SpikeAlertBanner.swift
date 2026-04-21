import SwiftUI

/// Post-workout banner shown when a session's load significantly exceeds the recent average.
/// Design system: flat surface card with colored left border, no shadows, no rounded corners.
struct SpikeAlertBanner: View {
    let alert: WorkloadCalculator.SpikeAlert
    let onDismiss: () -> Void

    private var borderColor: Color {
        switch alert.severity {
        case .high: ColorTokens.zoneDanger
        case .moderate: ColorTokens.zoneCaution
        }
    }

    private var severityLabel: String {
        switch alert.severity {
        case .high: "HIGH LOAD SPIKE"
        case .moderate: "SESSION LOAD SPIKE"
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Colored left border strip
            Rectangle()
                .fill(borderColor)
                .frame(width: 2)

            VStack(alignment: .leading, spacing: 8) {
                Text(severityLabel)
                    .font(.custom("DMSans-Medium", size: 11))
                    .tracking(0.88)
                    .foregroundStyle(borderColor)

                Text("This session's load was \(String(format: "%.1f", alert.ratio))x your 28-day average. Consider extra recovery.")
                    .font(.custom("DMSans-Regular", size: 13))
                    .foregroundStyle(ColorTokens.text1)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 16) {
                    Label {
                        Text(String(format: "%.0f", alert.sessionTSS))
                            .font(.custom("DMSans-Medium", size: 13))
                            .monospacedDigit()
                    } icon: {
                        Text("SESSION")
                            .font(.custom("DMSans-Regular", size: 11))
                            .tracking(0.88)
                    }
                    .foregroundStyle(ColorTokens.text1)

                    Label {
                        Text(String(format: "%.0f", alert.averageTSS))
                            .font(.custom("DMSans-Medium", size: 13))
                            .monospacedDigit()
                    } icon: {
                        Text("AVG")
                            .font(.custom("DMSans-Regular", size: 11))
                            .tracking(0.88)
                    }
                    .foregroundStyle(ColorTokens.text2)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)

            Spacer()
        }
        .background(ColorTokens.surface)
        .overlay(
            Rectangle()
                .stroke(ColorTokens.divider, lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture { onDismiss() }
    }
}
