import Foundation

/// Master shadow-validation flag for ALL cycle modifiers (Phase 20, D-06).
///
/// **Defaults to `false` and stays false this phase.** With it false, every cycle
/// modifier computes its would-be effect (so `ShadowAnalyticsService` can log "what we'd
/// have done") but returns the UNMODIFIED value to the app — no user-facing behavior
/// change. Flipping it to `true` is an explicit **future-phase** decision, made only after
/// the shadow-mode MAE data shows that cycle-aware prediction beats the baseline. Do NOT
/// flip it as part of this phase.
enum CycleModifierActivation {
    static let isEnabled: Bool = false
}

/// The single, reusable evidence gate that decides modifier eligibility (Phase 20, D-05).
///
/// This is the ONLY place modifier eligibility is decided. Every modifier
/// (AutoregulationEngine soft volume, FatigueIndexEngine luteal dampening,
/// ProgressionEngine late-luteal maintain bias) routes its decision through
/// `shouldApply(context:cyclesObserved:)`, which is the double-gate:
///
///     eligibility(...).isEligible  AND  CycleModifierActivation.isEnabled
///
/// `isEligible` is true ONLY when ALL of D-05 hold:
///   (a) confidence >= 0.7          (same threshold as the Phase 18 D-04 gate)
///   (b) !hasExclusion              (no hormonal contraception / pregnancy / lactation)
///   (c) phase != .unknown          (detected regularity is already folded into confidence
///                                   upstream — Phase 17/18 — so we do NOT recount cycles)
///   (d) cyclesObserved >= 3        (3+ usable cycles, unique to modifiers)
///   (e) a non-empty user-visible explanation string is producible (so a modifier can
///       never fire without text consistent with Phase 19's readiness-first tone)
///
/// Pure struct, Foundation only.
struct CycleModifierGate {

    /// Minimum confidence — mirrors the Phase 18 D-04 same-phase-baseline gate exactly.
    static let minConfidence: Double = 0.7
    /// Minimum usable cycles (unique to modifiers, D-05 (d)).
    static let minCyclesObserved: Int = 3

    struct Eligibility {
        let isEligible: Bool
        /// Non-empty, readiness-first explanation when eligible; nil otherwise.
        let explanation: String?
    }

    /// Evaluate the 5-part D-05 gate. Returns eligibility + an explanation string.
    static func eligibility(context: CycleContext, cyclesObserved: Int) -> Eligibility {
        let passes =
            context.confidence >= minConfidence &&
            !context.hasExclusion &&
            context.phase != .unknown &&
            cyclesObserved >= minCyclesObserved

        guard passes else {
            return Eligibility(isEligible: false, explanation: nil)
        }

        let explanation = explanationText(for: context.phase)
        // D-05 (e): eligibility requires a producible non-empty explanation.
        guard let explanation, !explanation.isEmpty else {
            return Eligibility(isEligible: false, explanation: nil)
        }
        return Eligibility(isEligible: true, explanation: explanation)
    }

    /// The single double-gate every modifier calls before APPLYING any change (D-06).
    /// False whenever activation is off — so it is false everywhere this phase.
    static func shouldApply(context: CycleContext, cyclesObserved: Int) -> Bool {
        eligibility(context: context, cyclesObserved: cyclesObserved).isEligible
            && CycleModifierActivation.isEnabled
    }

    // MARK: - Explanation (readiness-first, Phase 19 tone)

    /// Cycle-as-context explanation. Never "deload because luteal" — cycle is context,
    /// readiness/symptoms are the driver (D-05 (e), Phase 19 consistency).
    private static func explanationText(for phase: CyclePhase) -> String? {
        switch phase {
        case .earlyFollicular, .lateFollicular, .ovulatory:
            return "You're in your follicular phase. Your recent readiness is the guide today — cycle phase is just context."
        case .earlyLuteal, .lateLuteal:
            return "You're in your luteal phase, when recovery can run a little lower. If your readiness also points down, a slightly lighter session may help."
        case .unknown:
            return nil
        }
    }
}
