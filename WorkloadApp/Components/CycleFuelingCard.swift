import SwiftUI

/// Cycle-aware fueling & recovery suggestions card for the Recovery tab (Phase 19 D-08/D-09).
///
/// Evidence-tagged to Dr. Stacy Sims (research §9.4/§6.2/§9.9). The card offers SUGGESTIONS
/// only — never a training prescription (no volume/intensity directives, SC5). Two always-on
/// lines (avoid fasted hard work; protein within ~45 min) plus two luteal-only lines
/// (heat/hydration; extra protein + complex carbs). Flat surface, `CornerTokens.card` corners
/// (v3 Corner Law), no accent, no shadow — matches the InsightCard recipe.
struct CycleFuelingCard: View {
    let phase: CyclePhase

    private var isLuteal: Bool {
        phase == .earlyLuteal || phase == .lateLuteal
    }

    private var lines: [LocalizedStringKey] {
        var keys: [LocalizedStringKey] = ["cycle.fueling.fasted", "cycle.fueling.protein"]
        if isLuteal {
            keys.append("cycle.fueling.lutealHeat")
            keys.append("cycle.fueling.lutealNutrition")
        }
        return keys
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("cycle.fueling.title")
                .font(.Tokens.micro)
                .tracking(1.2)
                .foregroundStyle(ColorTokens.text3)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, key in
                    HStack(alignment: .top, spacing: 8) {
                        Rectangle()
                            .fill(ColorTokens.text3)
                            .frame(width: 2, height: 2)
                            .padding(.top, 8)
                        Text(key)
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.sm)
        .background(ColorTokens.surface, in: RoundedRectangle(cornerRadius: CornerTokens.card))
        .overlay(
            RoundedRectangle(cornerRadius: CornerTokens.card)
                .stroke(ColorTokens.divider, lineWidth: 0.5)
        )
    }
}
