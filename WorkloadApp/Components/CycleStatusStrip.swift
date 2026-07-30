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

    // `AnnotationLabel` takes a plain `String`, and `String(localized:)` resolves against the
    // PROCESS locale — which would silently break in-app language switching (the app pins its
    // language via `.environment(\.locale, …)`, not the process locale). `LocalePinnedStrings`
    // is the established locale-correct route; see `AppShellContracts`.
    @Environment(\.locale) private var locale

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
            // v6: a cycle-position strip is the canonical annotation stamp (DESIGN.md names
            // "cycle position" — `D-028` — as annotation), so the key and the day counter are
            // marginalia. The phase name stays in the working voice: it is a word the app says.
            AnnotationLabel(LocalePinnedStrings.localized("cycle.indicator.label", locale: locale))
                .annotationReveal(index: 0)

            Spacer()

            if let dayText {
                AnnotationLabel(dayText, color: ColorTokens.text1)
                    .annotationReveal(index: 1)
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
