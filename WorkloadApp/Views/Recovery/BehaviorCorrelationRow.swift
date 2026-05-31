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
            VStack(alignment: .leading, spacing: 8) {
                Text(tagName)
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text1)
                Text(String(format: String(localized: "behavior.impact.suffix", defaultValue: "Recovery %@ on tagged days"), "\(impactPercentage >= 0 ? "+" : "")\(String(format: "%.0f", impactPercentage))%"))
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
                Text(String(format: String(localized: "behavior.sample.count", defaultValue: "%d days with, %d days without"), sampleCountWith, sampleCountWithout))
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
            }
            Spacer()
            Text("\(impactPercentage >= 0 ? "+" : "")\(String(format: "%.0f", impactPercentage))%")
                .font(.Tokens.sectionHead)
                .monospacedDigit()
                .foregroundStyle(ColorTokens.text1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(ColorTokens.surface)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(impactPercentage >= 0 ? ColorTokens.zoneOptimal : ColorTokens.zoneDanger)
                .frame(width: 3)
        }
        .overlay(
            Rectangle()
                .stroke(ColorTokens.divider, lineWidth: 0.5)
        )
    }

    private var insufficientView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(tagName)
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text1)
                Text(String(format: String(localized: "behavior.insufficient.days", defaultValue: "%d more tagged days needed"), neededDays))
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(ColorTokens.surface)
        .overlay(
            Rectangle()
                .stroke(ColorTokens.divider, lineWidth: 0.5)
        )
    }
}
