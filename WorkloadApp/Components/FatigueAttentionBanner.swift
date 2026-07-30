import SwiftUI

/// Dashboard banner shown when accumulated fatigue is elevated.
/// Not a medical or injury prediction — a load-attention signal.
/// Design system: shared attention-banner plane (CornerTokens.card, zone-colored leading rule).
struct FatigueAttentionBanner: View {
    let fatigueIndex: Double
    let zone: FatigueIndexEngine.FatigueZone
    /// Fire the caution haptic only on first surfacing — not on every dashboard re-render.
    @State private var didSignal = false

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
        case .low: String(localized: "fatigue.zone.low", defaultValue: "FATIGUE LOW")
        case .elevated: String(localized: "fatigue.zone.elevated", defaultValue: "FATIGUE ELEVATED")
        case .high: String(localized: "fatigue.zone.high", defaultValue: "FATIGUE HIGH")
        case .saturation: String(localized: "fatigue.zone.saturation", defaultValue: "FATIGUE VERY HIGH")
        }
    }

    private var message: String {
        switch zone {
        case .low:
            String(localized: "fatigue.message.low", defaultValue: "Training stress is within normal range.")
        case .elevated:
            String(localized: "fatigue.message.elevated", defaultValue: "Accumulated training stress is building. Consider lighter sessions or extra recovery.")
        case .high:
            String(localized: "fatigue.message.high", defaultValue: "Body stress is elevated. A deload day or active recovery session is recommended.")
        case .saturation:
            String(localized: "fatigue.message.saturation", defaultValue: "Training stress is very high. Prioritize rest to avoid diminishing returns.")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                // v6: the zone key is a machine-flavoured state key → annotation voice; the
                // index below it is a reading, so it stays working voice. The banner plane is a
                // card, so zone-coloured text below 24pt is legal (DESIGN.md rule 7).
                AnnotationLabel(zoneLabel, color: borderColor)
                    .annotationReveal(index: 0)

                Spacer()

                Text("\(Int(fatigueIndex))")
                    .font(.Tokens.labelMedium)
                    .monospacedDigit()
                    .foregroundStyle(borderColor)
            }

            Text(message)
                .font(.Tokens.smallLabel)
                .foregroundStyle(ColorTokens.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .attentionBannerStyle(ruleColor: borderColor)
        .onAppear {
            // Caution surfaced → one warning haptic (guarded so reloads don't re-fire).
            guard !didSignal else { return }
            didSignal = true
            Haptics.warning()
        }
    }
}
