import SwiftUI

/// Dashboard banner shown when accumulated fatigue is elevated.
/// Not a medical or injury prediction — a load-attention signal.
/// Design system: flat surface card with colored left border, no shadows, no rounded corners.
struct FatigueAttentionBanner: View {
    let fatigueIndex: Double
    let zone: FatigueIndexEngine.FatigueZone

    private var borderColor: Color {
        switch zone {
        case .low: ColorTokens.zoneOptimal
        case .elevated: ColorTokens.zoneCaution
        case .high: ColorTokens.zoneDanger
        case .saturation: ColorTokens.zoneDanger
        }
    }

    private var zoneLabel: String {
        switch zone {
        case .low: "FATIGUE LOW"
        case .elevated: "FATIGUE ELEVATED"
        case .high: "FATIGUE HIGH"
        case .saturation: "FATIGUE VERY HIGH"
        }
    }

    private var message: String {
        switch zone {
        case .low:
            "Training stress is within normal range."
        case .elevated:
            "Accumulated training stress is building. Consider lighter sessions or extra recovery."
        case .high:
            "Body stress is elevated. A deload day or active recovery session is recommended."
        case .saturation:
            "Training stress is very high. Prioritize rest to avoid diminishing returns."
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(borderColor)
                .frame(width: 2)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(zoneLabel)
                        .font(.custom("DMSans-Medium", size: 11))
                        .tracking(0.88)
                        .foregroundStyle(borderColor)

                    Spacer()

                    Text("\(Int(fatigueIndex))")
                        .font(.custom("DMSans-Medium", size: 15))
                        .monospacedDigit()
                        .foregroundStyle(borderColor)
                }

                Text(message)
                    .font(.custom("DMSans-Regular", size: 13))
                    .foregroundStyle(ColorTokens.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(ColorTokens.surface)
        .overlay(
            Rectangle()
                .stroke(ColorTokens.divider, lineWidth: 0.5)
        )
    }
}
