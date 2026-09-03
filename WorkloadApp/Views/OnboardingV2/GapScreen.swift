import SwiftUI

/// OnboardingV2 screen 3 — the gap. The anti-positioning rendered once, visually: a 2×2
/// field (accepts your plan × adjusts training) with Tuwa alone in the upper right. One
/// chart, one line of copy — deliberately NOT a comparison table (spec §3: a table
/// invites reading). Competitor names are quadrant labels in the quiet voice.
struct GapScreen: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("onboardingV2.gap.title")
                .font(.Tokens.pageTitle)
                .foregroundStyle(ColorTokens.text1)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.sm)
                .padding(.top, Spacing.md)

            quadrantChart
                .padding(.horizontal, Spacing.sm)
                .padding(.top, Spacing.lg)

            Text("onboardingV2.gap.line")
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text1)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.sm)
                .padding(.top, Spacing.lg)

            Spacer()
        }
    }

    // MARK: - The 2×2 field

    private var quadrantChart: some View {
        VStack(spacing: 0) {
            // Y-axis label rides the top edge — marginalia in the margin.
            HStack {
                AnnotationLabel(key: "onboardingV2.gap.axis.adjusts", size: .small)
                    .annotationReveal(index: 0)
                Spacer()
            }
            .padding(.bottom, Spacing.baselinePair)

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    quadrant(labelKey: "onboardingV2.gap.cell.scores", emphasized: false)
                    hairlineV
                    quadrant(labelKey: "onboardingV2.gap.cell.tuwa", emphasized: true)
                }
                hairlineH
                HStack(spacing: 0) {
                    quadrant(labelKey: "onboardingV2.gap.cell.aiCoach", emphasized: false)
                    hairlineV
                    quadrant(labelKey: "onboardingV2.gap.cell.holds", emphasized: false)
                }
            }
            .background(ColorTokens.surfaceEl, in: RoundedRectangle(cornerRadius: CornerTokens.card))
            .overlay(
                RoundedRectangle(cornerRadius: CornerTokens.card)
                    .stroke(ColorTokens.divider, lineWidth: 0.5)
            )

            // X-axis label along the bottom-right edge.
            HStack {
                Spacer()
                AnnotationLabel(key: "onboardingV2.gap.axis.accepts", size: .small)
                    .annotationReveal(index: 1)
            }
            .padding(.top, Spacing.baselinePair)
        }
    }

    private func quadrant(labelKey: LocalizedStringKey, emphasized: Bool) -> some View {
        Text(labelKey)
            .font(emphasized ? .Tokens.bodyMedium : .Tokens.smallLabel)
            .foregroundStyle(emphasized ? ColorTokens.text1 : ColorTokens.text3)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: 96)
            .padding(Spacing.xs)
    }

    private var hairlineV: some View {
        Rectangle()
            .fill(ColorTokens.divider)
            .frame(width: 0.5)
    }

    private var hairlineH: some View {
        Rectangle()
            .fill(ColorTokens.divider)
            .frame(height: 0.5)
    }
}
