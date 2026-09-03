import SwiftUI

/// OnboardingV2 screen 9 — the reveal. The real branch shows the athlete's own readiness
/// (hero in `metric-readiness`, count-up per amendment 4 via `Motion` + `.numericText()`),
/// the HRV baseline, and the confidence bucket as marginalia. The degraded branch never
/// pretends: it states what Tuwa needs and the DATE the first real number arrives
/// (spec §4). No review prompt exists on either branch (amendment 1).
struct RevealScreen: View {
    let reveal: OnboardingRevealService.Reveal
    /// Personalizes the sub-line from quiz Q2, in memory only (C7).
    let splitChoiceID: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayedScore = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if reveal.isRealBranch {
                realBranch
            } else {
                degradedBranch
            }
            Spacer()
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.top, Spacing.md)
    }

    // MARK: - Real branch

    private var realBranch: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("onboardingV2.reveal.title")
                .font(.Tokens.pageTitle)
                .foregroundStyle(ColorTokens.text1)

            // The hero reading wears its metric's hue (Reading Color Rule v6) and counts
            // up on entry — the one orchestrated moment the flow owns.
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Text(verbatim: "\(displayedScore)")
                    .font(.Tokens.heroScore)
                    .monospacedDigit()
                    .foregroundStyle(ColorTokens.metricReadiness)
                    .contentTransition(.numericText(value: Double(displayedScore)))
                AnnotationLabel(key: "onboardingV2.reveal.unit", size: .small, color: ColorTokens.text3)
            }
            .padding(.top, Spacing.md)
            .onAppear {
                guard let score = reveal.score else { return }
                displayedScore = 0
                withAnimation(Motion.resolved(Motion.entrance, reduceMotion: reduceMotion)) {
                    displayedScore = Int(score.rounded())
                }
            }

            Text(zoneLine)
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text1)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Spacing.sm)

            annotationBlock
                .padding(.top, Spacing.lg)
        }
    }

    /// One sentence of what the number means today, personalized by the Q2 split.
    private var zoneLine: String {
        let base: String
        switch reveal.zone {
        case .green:
            base = String(localized: "onboardingV2.reveal.zone.green", defaultValue: "Recovered and ready to load. Your HRV sits right on your own baseline.")
        case .yellow:
            base = String(localized: "onboardingV2.reveal.zone.yellow", defaultValue: "Carrying some fatigue — today rewards controlled work, not max effort.")
        case .red:
            base = String(localized: "onboardingV2.reveal.zone.red", defaultValue: "Run down against your own baseline — today is the day to go easy.")
        case nil:
            base = String(localized: "onboardingV2.reveal.zone.none", defaultValue: "Your baseline is live and today's number is real.")
        }
        if splitChoiceID == "basketballLifting" {
            return base + " " + String(localized: "onboardingV2.reveal.split.basketball", defaultValue: "Court time and bar time will draw from this one number.")
        }
        return base
    }

    /// The marginalia block: machine-keyed readings in the annotation voice, revealed
    /// staggered after the surface settles (the sanctioned choreography primitive).
    private var annotationBlock: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if let baseline = reveal.hrvBaseline {
                AnnotationLabel(
                    "HRV_BASELINE: \(Int(baseline.rounded())) MS",
                    size: .standard,
                    color: ColorTokens.text3
                )
                .annotationReveal(index: 0)
            }
            if let today = reveal.hrvToday {
                AnnotationLabel(
                    "TODAY: \(Int(today.rounded())) MS",
                    size: .standard,
                    color: ColorTokens.text3
                )
                .annotationReveal(index: 1)
            }
            AnnotationLabel(
                "CONFIDENCE: \(confidenceLabel) · \(reveal.observedPriorHRVDays)D OBSERVED",
                size: .standard,
                color: ColorTokens.text3
            )
            .annotationReveal(index: 2)
        }
    }

    private var confidenceLabel: String {
        switch reveal.confidenceBucket {
        case .floor: "FLOOR"
        case .partial: "PARTIAL"
        case .full: "FULL"
        }
    }

    // MARK: - Degraded branch

    private var degradedBranch: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("onboardingV2.reveal.degraded.title")
                .font(.Tokens.pageTitle)
                .foregroundStyle(ColorTokens.text1)
                .fixedSize(horizontal: false, vertical: true)

            Text("onboardingV2.reveal.degraded.body")
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Spacing.sm)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                AnnotationLabel(
                    "NEEDS: \(BaselineEngine.BaselineConstants.confFloorDays) MORNINGS OF HRV + REST HR",
                    size: .standard, color: ColorTokens.text3
                )
                .annotationReveal(index: 0)
                AnnotationLabel(
                    "HAVE: \(reveal.observedPriorHRVDays)",
                    size: .standard, color: ColorTokens.text3
                )
                .annotationReveal(index: 1)
                AnnotationLabel(
                    "FIRST REAL NUMBER: \(firstDateLabel)",
                    size: .standard, color: ColorTokens.text2
                )
                .annotationReveal(index: 2)
            }
            .padding(.top, Spacing.lg)

            Text("onboardingV2.reveal.degraded.meanwhile")
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text1)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Spacing.lg)
        }
    }

    /// The named day the first real number arrives — uppercase Latin via the annotation
    /// voice's own transform; date formatted short so zh-Hans reads naturally too.
    private var firstDateLabel: String {
        reveal.firstRealNumberDate(now: .now)
            .formatted(date: .abbreviated, time: .omitted)
    }
}
