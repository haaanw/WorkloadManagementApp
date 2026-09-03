import SwiftUI

/// OnboardingV2 screen 1 — the cold open. One statement of the user's problem, one CTA
/// (owned by the coordinator's pill), a "log in" affordance for returning users (C5),
/// and one piece of app-surface imagery (§5.1: the app's own surfaces are the sanctioned
/// visual language). Measured on advance rate only.
struct ColdOpenScreen: View {
    let onShowLogin: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            Text("onboardingV2.coldOpen.title")
                .font(.Tokens.pageTitle)
                .foregroundStyle(ColorTokens.text1)
                .fixedSize(horizontal: false, vertical: true)

            Text("onboardingV2.coldOpen.subtitle")
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Spacing.sm)

            specimen
                .padding(.top, Spacing.lg)

            Spacer()

            Button {
                onShowLogin()
            } label: {
                Text("onboardingV2.coldOpen.logIn")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("onboardingV2.logIn")
        }
        .padding(.horizontal, Spacing.sm)
    }

    /// App-surface imagery: a raised light card carrying a specimen readiness reading —
    /// hero ≥32pt so the metric hue is legal on any plane (v6 contrast rule).
    private var specimen: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            AnnotationLabel(key: "onboardingV2.coldOpen.specimen.anno", size: .small)
                .annotationReveal(index: 0)

            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Text(verbatim: "74")
                    .font(.Tokens.displayAction)
                    .monospacedDigit()
                    .foregroundStyle(ColorTokens.metricReadiness)
                AnnotationLabel(key: "onboardingV2.coldOpen.specimen.state", size: .small, color: ColorTokens.text2)
                    .annotationReveal(index: 1)
            }

            AnnotationLabel(key: "onboardingV2.coldOpen.specimen.detail", size: .small)
                .annotationReveal(index: 2)
        }
        .padding(Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorTokens.surfaceEl, in: RoundedRectangle(cornerRadius: CornerTokens.card))
        .overlay(
            RoundedRectangle(cornerRadius: CornerTokens.card)
                .stroke(ColorTokens.divider, lineWidth: 0.5)
        )
        .accessibilityHidden(true)
    }
}
