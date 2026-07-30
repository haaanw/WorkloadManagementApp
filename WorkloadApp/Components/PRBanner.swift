import SwiftUI

/// Inline, dismissible post-workout banner shown when a session set new personal records.
/// Mirrors SpikeAlertBanner: shared attention-banner plane (CornerTokens.card, zone-optimal
/// leading rule = PR), no shadow, tap-to-dismiss.
struct PRBanner: View {
    let prs: [PersonalRecord]
    let onDismiss: () -> Void

    @Environment(\.locale) private var locale
    private var isLatinLocale: Bool { locale.language.languageCode?.identifier != "zh" }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(prs.count > 1
                ? String(localized: "workout.pr.title.plural", defaultValue: "New PRs!")
                : String(localized: "workout.pr.title.single", defaultValue: "New PR!"))
                // Working voice, deliberately: this is a sentence the app says to the athlete,
                // and the annotation voice never speaks. CJK guard added — added tracking harms
                // Chinese (the transform was previously unconditional).
                .font(.Tokens.micro)
                .tracking(isLatinLocale ? 0.88 : 0)
                .foregroundStyle(ColorTokens.zoneOptimal)

            ForEach(prs, id: \.id) { pr in
                HStack(spacing: 16) {
                    Text(pr.exerciseName)
                        .font(.Tokens.smallLabel)
                        .foregroundStyle(ColorTokens.text1)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 8)

                    // v6: a `KEY: VALUE` readout is the archetypal annotation. The banner title
                    // above stays working voice — it is a sentence the app says to the athlete.
                    AnnotationLabel(
                        "\(pr.recordType.displayName): \(String(format: "%.1f", pr.value))",
                        color: ColorTokens.text2
                    )
                    .annotationReveal(index: 0)
                }
            }
        }
        .attentionBannerStyle(ruleColor: ColorTokens.zoneOptimal)
        .contentShape(RoundedRectangle(cornerRadius: CornerTokens.card))
        .onTapGesture { Haptics.tap(); onDismiss() }
        // A PR was detected and surfaced → the one sanctioned success cue.
        .onAppear { Haptics.success() }
    }
}
