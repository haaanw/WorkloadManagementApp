import SwiftUI

/// Post-workout banner shown when a session's load significantly exceeds the recent average.
/// Design system: shared attention-banner plane (CornerTokens.card, zone-colored leading rule).
struct SpikeAlertBanner: View {
    let alert: WorkloadCalculator.SpikeAlert
    let onDismiss: () -> Void

    // Locale-correct string lookup for the `AnnotationLabel`s below: the app pins its language
    // via `.environment(\.locale, …)`, which `String(localized:)` does not observe.
    @Environment(\.locale) private var locale

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
        VStack(alignment: .leading, spacing: 8) {
            // v6: the severity key is a machine-flavoured state key → annotation voice. The
            // message below is a sentence, so it stays working voice. Zone-coloured annotation
            // below 24pt is legal here because `attentionBannerStyle` fills a card plane.
            AnnotationLabel(severityLabel, color: borderColor)
                .annotationReveal(index: 0)

            Text(String(format: String(localized: "spike.alert.message", defaultValue: "This session's load was %@x your 28-day average. Consider extra recovery."), String(format: "%.1f", alert.ratio)))
                .font(.Tokens.smallLabel)
                .foregroundStyle(ColorTokens.text1)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 16) {
                Label {
                    Text(String(format: "%.0f", alert.sessionTSS))
                        .font(.Tokens.smallLabelMedium)
                        .monospacedDigit()
                        .foregroundStyle(ColorTokens.text1)
                } icon: {
                    AnnotationLabel(LocalePinnedStrings.localized("spike.alert.label.session", locale: locale))
                        .annotationReveal(index: 1)
                }

                Label {
                    Text(String(format: "%.0f", alert.averageTSS))
                        .font(.Tokens.smallLabelMedium)
                        .monospacedDigit()
                        .foregroundStyle(ColorTokens.text2)
                } icon: {
                    AnnotationLabel(LocalePinnedStrings.localized("spike.alert.label.average", locale: locale))
                        .annotationReveal(index: 2)
                }
            }
        }
        .attentionBannerStyle(ruleColor: borderColor)
        .contentShape(RoundedRectangle(cornerRadius: CornerTokens.card))
        .onTapGesture { Haptics.tap(); onDismiss() }
        // A load spike / caution was surfaced → the sanctioned warning cue.
        .onAppear { Haptics.warning() }
    }
}
