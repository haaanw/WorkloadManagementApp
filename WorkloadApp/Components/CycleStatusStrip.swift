import SwiftUI

/// Unobtrusive opt-in cycle day/phase indicator for the Dashboard (Phase 19 D-07).
///
/// Reads one local-only `MenstrualCycleSnapshot` and renders it as a calm instrument
/// metric (micro-caps "CYCLE" label + "Day N" + optional phase name) — never an alert,
/// no accent color, no icon emphasis. The phase NAME is shown only when the interpretation
/// gate passes (D-03/D-04: confidence >= 0.7, non-unknown phase, no exclusion); otherwise
/// the cycle day shows alone as a neutral fact.
struct CycleStatusStrip: View {
    let snapshot: MenstrualCycleSnapshot

    /// D-03 / D-04 interpretation gate — mirrors the Phase 18 engine gate so the displayed
    /// phase interpretation is consistent with the same-phase baseline that was actually applied.
    private var showsPhase: Bool {
        snapshot.confidence >= 0.7
            && (snapshot.estimatedPhase ?? .unknown) != .unknown
            && !(snapshot.isOnHormonalContraceptive || snapshot.isPregnant || snapshot.isLactating)
    }

    private var dayText: String? {
        guard let day = snapshot.cycleDay else { return nil }
        return String(format: String(localized: "cycle.indicator.day"), day)
    }

    private var phaseName: String? {
        guard showsPhase, let phase = snapshot.estimatedPhase else { return nil }
        return phase.displayName
    }

    private var accessibilityText: String {
        [String(localized: "cycle.indicator.label"), dayText, phaseName]
            .compactMap { $0 }
            .joined(separator: ", ")
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("cycle.indicator.label")
                .font(.Tokens.micro)
                .tracking(1.2)
                .foregroundStyle(ColorTokens.text3)

            Spacer()

            if let dayText {
                Text(dayText)
                    .font(.Tokens.labelMedium)
                    .monospacedDigit()
                    .foregroundStyle(ColorTokens.text1)
            }

            if let phaseName {
                Text(phaseName)
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(ColorTokens.surface)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(ColorTokens.divider)
                .frame(height: 0.5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(accessibilityText))
    }
}
