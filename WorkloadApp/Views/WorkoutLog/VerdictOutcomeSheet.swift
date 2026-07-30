import SwiftUI

/// Phase 45 Plan 02 (Task 2) — the no-guilt **post-session outcome capture**.
///
/// After a planned-session day with a verdict has passed, this calm sheet asks one neutral question —
/// "Was the call right?" — with three EQUAL-weight choices (Right / Wrong / Not sure). It shows the
/// event's planned→adjusted number + reason as quiet read-only context. The selection ("right" /
/// "wrong" / "unsure") is emitted via `onSelect`; the host writes it onto the awaiting `VerdictEvent`.
///
/// DESIGN.md (hard): corners via `CornerTokens` (v3 Corner Law), no shadows, `Font.Tokens.*`, 8pt grid, light-only
/// via `ColorTokens`. The reserved hero accent is FORBIDDEN here. NO guilt / coercion copy. The three
/// choices use ONE shared button builder, so they are provably equal weight (mirror TodayVerdictCard).
struct VerdictOutcomeSheet: View {

    let event: VerdictEvent
    let weightUnit: WeightUnit
    /// Emits "right" / "wrong" / "unsure".
    var onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.md) {

                // Header stamp — marginalia, so the annotation voice (v6).
                AnnotationLabel(String(localized: "verdictOutcome.title", defaultValue: "LOOKING BACK"))
                    .annotationReveal()

                // Quiet context: the planned→adjusted number + the reason (read-only).
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    numberLine
                    if !event.reasonLine.isEmpty {
                        Text(verbatim: event.reasonLine)
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                // The one calm question.
                Text(String(localized: "verdictOutcome.question", defaultValue: "Was the call right?"))
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text1)

                // Three equal-weight choices.
                HStack(spacing: Spacing.xs) {
                    choiceButton(
                        String(localized: "verdictOutcome.right", defaultValue: "Right"),
                        outcome: "right"
                    )
                    choiceButton(
                        String(localized: "verdictOutcome.wrong", defaultValue: "Wrong"),
                        outcome: "wrong"
                    )
                    choiceButton(
                        String(localized: "verdictOutcome.unsure", defaultValue: "Not sure"),
                        outcome: "unsure"
                    )
                }

                // Quiet honest context line.
                Text(String(localized: "verdictOutcome.context",
                            defaultValue: "A quick read helps tune the calls — no right answer."))
                    .font(.Tokens.smallLabel)
                    .foregroundStyle(ColorTokens.text3)

                Spacer()
            }
            .onAppear { Haptics.prepare() }
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

    @ViewBuilder
    private var numberLine: some View {
        if let adjusted = event.adjustedTopSetKg, event.differed {
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

    /// The ONE choice-button builder — Right / Wrong / Not sure are provably identical in treatment;
    /// they differ ONLY in label/outcome (no color coding, no danger token, no accent).
    private func choiceButton(_ title: String, outcome: String) -> some View {
        Button {
            Haptics.select()
            onSelect(outcome)
        } label: {
            Text(verbatim: title)
                .font(.Tokens.bodyMedium)
                .foregroundStyle(ColorTokens.text1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xs)
                .background(ColorTokens.surface, in: Capsule())
                .overlay(Capsule().stroke(ColorTokens.divider, lineWidth: 0.5))
        }
        .buttonStyle(.pressable)
    }
}
