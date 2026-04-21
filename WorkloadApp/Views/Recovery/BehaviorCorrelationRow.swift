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
                Text("Recovery \(impactPercentage >= 0 ? "+" : "")\(String(format: "%.0f", impactPercentage))% on tagged days")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
                Text("\(sampleCountWith) days with, \(sampleCountWithout) days without")
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
                Text("\(neededDays) more tagged days needed")
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
