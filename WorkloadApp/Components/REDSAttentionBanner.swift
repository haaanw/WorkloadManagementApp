import SwiftUI

/// Non-diagnostic "cycle pattern change" attention banner for the Recovery tab (Phase 19 D-12/D-13).
///
/// Adapted from FatigueAttentionBanner. The copy is clinician-referral only and NEVER names
/// RED-S / amenorrhea / a diagnosis (D-12). The state is communicated by the text label first;
/// the caution-colored leading rule is supplementary (DESIGN rule 5 — never color alone). It is
/// dismissible (caller persists dismissal). Caution color (not danger) — this is a "consider
/// checking", not an emergency. Shared attention-banner plane (CornerTokens.card), no shadow.
struct REDSAttentionBanner: View {
    let onDismiss: () -> Void

    // Locale-correct lookup for the annotation below (the app pins language through the
    // SwiftUI environment, which `String(localized:)` does not observe).
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                // v6: state key → annotation voice. `zoneCaution` clears 4.5:1 on every stone
                // plane (5.05:1 on the base), so it is legal on this banner's `surface` fill.
                AnnotationLabel(LocalePinnedStrings.localized("cycle.reds.title", locale: locale), color: ColorTokens.zoneCaution)
                    .annotationReveal(index: 0)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.Tokens.smallLabel)
                        .foregroundStyle(ColorTokens.text2)
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(Text("cycle.reds.dismiss.a11y"))
            }

            Text("cycle.reds.body")
                .font(.Tokens.smallLabel)
                .foregroundStyle(ColorTokens.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .attentionBannerStyle(ruleColor: ColorTokens.zoneCaution, fill: ColorTokens.surface)
    }
}
