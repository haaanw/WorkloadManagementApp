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
        case .high: String(localized: "spike.alert.severity.high", defaultValue: "HIGH LOAD SPIKE")
        case .moderate: String(localized: "spike.alert.severity.moderate", defaultValue: "SESSION LOAD SPIKE")
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
                    .font(.Tokens.micro)
                    .tracking(0.88)
                    .foregroundStyle(borderColor)

                Text(String(format: String(localized: "spike.alert.message", defaultValue: "This session's load was %@x your 28-day average. Consider extra recovery."), String(format: "%.1f", alert.ratio)))
                    .font(.Tokens.smallLabel)
                    .foregroundStyle(ColorTokens.text1)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 16) {
                    Label {
                        Text(String(format: "%.0f", alert.sessionTSS))
                            .font(.Tokens.smallLabelMedium)
                            .monospacedDigit()
                    } icon: {
                        Text("spike.alert.label.session")
                            .font(.Tokens.micro)
                            .tracking(0.88)
                    }
                    .foregroundStyle(ColorTokens.text1)

                    Label {
                        Text(String(format: "%.0f", alert.averageTSS))
                            .font(.Tokens.smallLabelMedium)
                            .monospacedDigit()
                    } icon: {
                        Text("spike.alert.label.average")
                            .font(.Tokens.micro)
                            .tracking(0.88)
                    }
                    .foregroundStyle(ColorTokens.text2)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)

            Spacer()
        }
        .background(ColorTokens.surfaceEl)
        .overlay(
            Rectangle()
                .stroke(ColorTokens.divider, lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture { Haptics.tap(); onDismiss() }
        // A load spike / caution was surfaced → the sanctioned warning cue.
        .onAppear { Haptics.warning() }
    }
}
