import SwiftUI

/// OnboardingV2 — the daily-use tutorial slot (amendment 7), built LAST with MOCKED
/// frames by design: it demonstrates the plan-led daily loop (check-in → proposal →
/// voice capture) whose real surfaces Lane A (feature 6) is still building. REFRESH
/// PASS FLAGGED: when Lane A's surfaces finalize, these three specimen cards are
/// replaced with renders of the real screens — the structure, keys, and step logic
/// stay. The specimens are schematic app-surface imagery (§5.1), never screenshots of
/// UI that does not exist.
struct TutorialScreen: View {
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var stepIndex = 0

    private let stepKeys: [LocalizedStringKey] = [
        "onboardingV2.tutorial.step.checkin",
        "onboardingV2.tutorial.step.proposal",
        "onboardingV2.tutorial.step.capture"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("onboardingV2.tutorial.title")
                .font(.Tokens.pageTitle)
                .foregroundStyle(ColorTokens.text1)

            Text("onboardingV2.tutorial.subtitle")
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Spacing.xs)

            specimen
                .padding(.top, Spacing.lg)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                ForEach(Array(stepKeys.enumerated()), id: \.offset) { index, key in
                    Button {
                        withAnimation(Motion.resolved(Motion.state, reduceMotion: reduceMotion)) {
                            stepIndex = index
                        }
                    } label: {
                        HStack(spacing: Spacing.xs) {
                            Circle()
                                .fill(index == stepIndex ? ColorTokens.accent : ColorTokens.divider)
                                .frame(width: 8, height: 8)
                            Text(key)
                                .font(index == stepIndex ? .Tokens.bodyMedium : .Tokens.label)
                                .foregroundStyle(index == stepIndex ? ColorTokens.text1 : ColorTokens.text2)
                        }
                        .padding(.vertical, Spacing.baselinePair)
                    }
                    .buttonStyle(.pressable)
                }
            }
            .padding(.top, Spacing.md)

            Spacer()

            PrimaryActionButton(title: "onboardingV2.tutorial.done") {
                onDone()
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.xs)
    }

    /// MOCKED specimen frames — one raised card per step, schematic only.
    private var specimen: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            switch stepIndex {
            case 0:
                AnnotationLabel("MORNING · 06:52", size: .small)
                Text(verbatim: "How ready do you feel to train hard today?")
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text1)
                HStack(spacing: Spacing.baselinePair) {
                    ForEach(1...10, id: \.self) { n in
                        Text(verbatim: "\(n)")
                            .font(.Tokens.smallLabel)
                            .monospacedDigit()
                            .foregroundStyle(n == 7 ? ColorTokens.text1 : ColorTokens.text3)
                            .frame(maxWidth: .infinity, minHeight: 28)
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerTokens.control)
                                    .stroke(n == 7 ? ColorTokens.text1 : ColorTokens.divider, lineWidth: n == 7 ? 1 : 0.5)
                            )
                    }
                }
            case 1:
                AnnotationLabel("TODAY'S PLAN · BACK SQUAT", size: .small)
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                    Text(verbatim: "132.5")
                        .font(.Tokens.displayAction)
                        .monospacedDigit()
                        .foregroundStyle(ColorTokens.text1)
                    AnnotationLabel("KG · ↓ FROM 140", size: .small, color: ColorTokens.text2)
                }
                Text(verbatim: "Readiness is down this morning — easing the top set.")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
            default:
                AnnotationLabel("IN SESSION · SET 1", size: .small)
                HStack(spacing: Spacing.xs) {
                    Circle()
                        .fill(ColorTokens.accent)
                        .frame(width: 8, height: 8)
                    Text(verbatim: "\u{201C}one thirty for five\u{201D}")
                        .font(.Tokens.body)
                        .foregroundStyle(ColorTokens.text1)
                }
                AnnotationLabel("LOGGED · 130 KG × 5", size: .small, color: ColorTokens.text2)
            }
        }
        .padding(Spacing.sm)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .background(ColorTokens.surfaceEl, in: RoundedRectangle(cornerRadius: CornerTokens.card))
        .overlay(
            RoundedRectangle(cornerRadius: CornerTokens.card)
                .stroke(ColorTokens.divider, lineWidth: 0.5)
        )
        .accessibilityHidden(true)
    }
}
