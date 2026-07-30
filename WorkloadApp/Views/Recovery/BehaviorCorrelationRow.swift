import SwiftUI

/// Shows recovery impact percentage for a single behavior tag.
struct BehaviorCorrelationRow: View {
    let tagName: String
    let impactPercentage: Double
    let sampleCountWith: Int
    let sampleCountWithout: Int
    let isSufficient: Bool
    let neededDays: Int          // 0 if sufficient

    var body: some View {
        if isSufficient {
            sufficientView
        } else {
            insufficientView
        }
    }

    private var sufficientView: some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(tagName)
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text1)
                Text(String(format: String(localized: "behavior.impact.suffix", defaultValue: "Recovery %@ on tagged days"), "\(impactPercentage >= 0 ? "+" : "")\(String(format: "%.0f", impactPercentage))%"))
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
                // Sample provenance for the claim above — marginalia, annotation voice
                // (DESIGN.md v6). The impact sentence itself stays working voice.
                AnnotationLabel(
                    String(format: String(localized: "behavior.sample.count", defaultValue: "%d days with, %d days without"), sampleCountWith, sampleCountWithout),
                    size: .small
                )
                    .annotationReveal()
            }
            Spacer()
            Text("\(impactPercentage >= 0 ? "+" : "")\(String(format: "%.0f", impactPercentage))%")
                .font(.Tokens.sectionHead)
                .monospacedDigit()
                .foregroundStyle(ColorTokens.text1)
        }
        // Shared attention-banner plane (v3): card plate + zone-colored leading rule; the
        // impact text above stays the primary channel (never color alone).
        .attentionBannerStyle(ruleColor: impactPercentage >= 0 ? ColorTokens.zoneOptimal : ColorTokens.zoneDanger)
    }

    private var insufficientView: some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(tagName)
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text1)
                Text(String(format: String(localized: "behavior.insufficient.days", defaultValue: "%d more tagged days needed"), neededDays))
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
            }
            Spacer()
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.sm)
        .background(ColorTokens.surfaceEl, in: RoundedRectangle(cornerRadius: CornerTokens.card))
        .overlay(
            RoundedRectangle(cornerRadius: CornerTokens.card)
                .stroke(ColorTokens.divider, lineWidth: 0.5)
        )
    }
}
