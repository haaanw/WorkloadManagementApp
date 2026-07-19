import SwiftUI

/// Phase 45 Plan 04 (METRIC-03) — the single Sean-Ellis disappointment prompt.
///
/// Asks one neutral question — "How would you feel if you could no longer use Tuwa?" — with three
/// EQUAL-weight choices (Very disappointed / Somewhat disappointed / Not disappointed). The answer is
/// emitted via `onAnswer`; the host records it locally (`SeanEllisStore`) and, on "very", routes into
/// the existing RevenueCat paywall (the revealed WTP / card-on-file hop).
///
/// DESIGN.md (hard, v3 "Ink & Grain"): corners from `CornerTokens` only (the three choices are
/// rectangular control-corner keys), no shadows, `Font.Tokens.*`, 8pt grid, light-only via `ColorTokens`.
/// The reserved hero accent is FORBIDDEN here. Calm, neutral copy — no guilt, no upsell language
/// in the question itself. The three choices use ONE shared builder so they are provably equal
/// weight (mirror TodayVerdictCard.decisionButton).
struct SeanEllisPromptSheet: View {

    /// Emits the chosen disappointment level.
    var onAnswer: (SeanEllisStore.Disappointment) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.md) {

                // Header label (micro-caps).
                Text(String(localized: "seanEllis.title", defaultValue: "ONE QUESTION"))
                    .font(.Tokens.micro)
                    .tracking(1.2)
                    .foregroundStyle(ColorTokens.text3)

                // The one neutral question.
                Text(String(localized: "seanEllis.question",
                            defaultValue: "How would you feel if you could no longer use Tuwa?"))
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text1)
                    .fixedSize(horizontal: false, vertical: true)

                // Three equal-weight, stacked choices.
                VStack(spacing: Spacing.xs) {
                    choiceButton(
                        String(localized: "seanEllis.very", defaultValue: "Very disappointed"),
                        answer: .very
                    )
                    choiceButton(
                        String(localized: "seanEllis.somewhat", defaultValue: "Somewhat disappointed"),
                        answer: .somewhat
                    )
                    choiceButton(
                        String(localized: "seanEllis.not", defaultValue: "Not disappointed"),
                        answer: .not
                    )
                }

                Spacer()
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ColorTokens.background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.skip") { dismiss() }
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                }
            }
        }
    }

    /// The ONE choice-button builder — Very / Somewhat / Not are provably identical in treatment;
    /// they differ ONLY in label/answer (no color coding, no danger token, no accent).
    private func choiceButton(_ title: String, answer: SeanEllisStore.Disappointment) -> some View {
        Button {
            Haptics.select()
            onAnswer(answer)
        } label: {
            Text(verbatim: title)
                .font(.Tokens.bodyMedium)
                .foregroundStyle(ColorTokens.text1)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, Spacing.sm)
                .background(ColorTokens.surface, in: RoundedRectangle(cornerRadius: CornerTokens.control))
                .overlay(RoundedRectangle(cornerRadius: CornerTokens.control).stroke(ColorTokens.divider, lineWidth: 0.5))
        }
        .buttonStyle(.pressable)
    }
}
