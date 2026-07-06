import SwiftUI

/// v2.1 Track 1 item 6 — the calm, inline **next-day "felt right?" capture** for the n=1 dogfood
/// protocol (criterion 3: judged next-day, logged same-day, never retro-rated).
///
/// Renders ONLY when `FeltRightPromptEngine.eligibleEvent` returns yesterday's representative
/// differing-verdict decision — the host owns that gate. Shows yesterday's verdict context as one
/// quiet line (planned→adjusted number + reason), then one neutral question with three EQUAL-weight
/// choices: Felt right / Felt wrong / Unsure. Unsure is the neutral dismissal — every answer
/// (including Unsure) records once and removes the card; there is no separate close affordance and
/// no back-fill path.
///
/// DESIGN.md (hard): 0pt corners (Rectangle only), no shadows, `Font.Tokens.*`, 8pt grid,
/// light-only via `ColorTokens`. The accent is FORBIDDEN here (not a live/actionable-number
/// surface). No red / alarm styling — the three choices use ONE shared button builder, so they are
/// provably equal weight (mirrors `VerdictOutcomeSheet`).
struct FeltRightPromptRow: View {

    let event: VerdictEvent
    let weightUnit: WeightUnit
    /// Emits "right" / "wrong" / "unsure" — exactly once; the host records and clears the row.
    var onSelect: (String) -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {

            // Micro-caps header — this is about YESTERDAY, never today.
            Text(String(localized: "feltRight.header", defaultValue: "YESTERDAY'S CALL"))
                .font(.Tokens.micro)
                .tracking(1.2)
                .foregroundStyle(ColorTokens.text3)

            // Quiet one-line context: the differing number + the composed reason (read-only).
            numberLine
            if !event.reasonLine.isEmpty {
                Text(verbatim: event.reasonLine)
                    .font(.Tokens.smallLabel)
                    .foregroundStyle(ColorTokens.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // The one calm question.
            Text(String(localized: "feltRight.question", defaultValue: "Did it feel right?"))
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text1)
                .padding(.top, Spacing.xs)

            // Three equal-weight choices — Unsure is the neutral out.
            HStack(spacing: Spacing.xs) {
                choiceButton(
                    String(localized: "feltRight.right", defaultValue: "Felt right"),
                    answer: "right"
                )
                choiceButton(
                    String(localized: "feltRight.wrong", defaultValue: "Felt wrong"),
                    answer: "wrong"
                )
                choiceButton(
                    String(localized: "feltRight.unsure", defaultValue: "Unsure"),
                    answer: "unsure"
                )
            }
        }
        .cardStyle()
    }

    @ViewBuilder
    private var numberLine: some View {
        if let adjusted = event.adjustedTopSetKg {
            HStack(spacing: Spacing.xs) {
                Text(WeightFormatter.display(event.plannedTopSetKg, unit: weightUnit, locale: locale))
                    .foregroundStyle(ColorTokens.text2)
                Text(verbatim: "→")
                    .foregroundStyle(ColorTokens.text2)
                Text(WeightFormatter.display(adjusted, unit: weightUnit, locale: locale))
                    .foregroundStyle(ColorTokens.text1)
            }
            .font(.Tokens.body)
            .monospacedDigit()
        } else {
            Text(WeightFormatter.display(event.plannedTopSetKg, unit: weightUnit, locale: locale))
                .font(.Tokens.body)
                .monospacedDigit()
                .foregroundStyle(ColorTokens.text1)
        }
    }

    /// The ONE choice-button builder — the three answers are provably identical in treatment; they
    /// differ ONLY in label/value (no color coding, no danger token, no accent).
    private func choiceButton(_ title: String, answer: String) -> some View {
        Button {
            Haptics.select()
            onSelect(answer)
        } label: {
            Text(verbatim: title)
                .font(.Tokens.smallLabelMedium)
                .foregroundStyle(ColorTokens.text1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xs)
                .background(ColorTokens.surface)
                .overlay(Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5))
        }
        .buttonStyle(.pressable)
    }
}
