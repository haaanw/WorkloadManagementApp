import Foundation

/// Deterministic shadow-mode predictor (Phase 20, D-04).
///
/// For each tracked outcome (D-02), `ShadowPredictor` produces TWO competing
/// next-day predictions from the athlete's recent history:
///
/// 1. **Baseline prediction** — a persistence/trend extrapolation that uses NO cycle
///    phase information (last value + least-squares slope via
///    `RecoveryScoreEngine.computeSlope`).
/// 2. **Cycle-aware prediction** — the baseline plus a *fixed, literature-derived*
///    phase offset for the predicted day's cycle phase.
///
/// This is intentionally **not** a trained/ML model. We are only measuring whether a
/// fixed population-derived phase offset's direction and magnitude track reality for an
/// individual athlete over time (see `ShadowAnalyticsService` MAE aggregation). Per the
/// research base (Sims: "train by readiness, use cycle as context"; Altini: "individual
/// response > population priors"), the offset is a hypothesis to be validated in shadow,
/// never an applied adjustment.
///
/// Pure struct, static methods, Foundation only — no SwiftData, no HealthKit, deterministic.
struct ShadowPredictor {

    /// The four tracked next-day outcomes (D-02).
    enum Outcome: CaseIterable {
        case recovery    // next-day recovery score (0-100)
        case wellness    // next-day wellness score (0-100)
        case completion  // next-day workout completion (0 or 1) — reframed as ADHERENCE (D-06)
        case pain        // next-day reported soreness (WellnessCheckIn.soreness, 1-5 scale)
    }

    // MARK: - Outcome label provenance (Phase 24, D-06)
    //
    // The PRIMARY validation targets are RAW self-report labels (wellness, soreness/pain,
    // adherence/completion) — none engine-derived. The continuous `recovery` label is a
    // `RecoveryScoreEngine` output, so it is **circular** for a recovery model predicting its
    // own future transformed inputs; it is RETAINED only as a flagged SECONDARY/diagnostic arm
    // (`engineDerived = true`) for relative baseline-vs-baseline MAE continuity, and is NON-gating.
    // A truly raw continuous-recovery target (raw HRV/RHR/sleep z-targets) is Phase-26 work.

    /// Outcomes whose label is engine-derived (circular) and therefore secondary / non-gating.
    /// Phase 24: only `recovery`. Wellness / pain / completion(adherence) are raw self-report.
    static let engineDerivedOutcomes: Set<Outcome> = [.recovery]

    // MARK: - Literature-derived phase offsets
    //
    // Magnitudes are deliberately conservative starting values sourced from
    // `.planning/research/female-athlete-optimization-research.md`:
    //
    // - HRV (RMSSD) reaches its minimum in the late-luteal phase; resting HR rises
    //   ~2-5 bpm in the luteal phase (research §"Sex Differences in Recovery Metrics",
    //   HRV/RHR subsections). Both depress the composite recovery score in the luteal
    //   bucket → negative recovery offset.
    // - A late-luteal sleep-quality penalty and elevated symptom burden depress the
    //   subjective wellness score (research §"Sleep") → negative wellness offset.
    // - Elevated late-luteal symptom burden raises reported soreness/pain → positive
    //   pain offset (pain is on the 1-5 soreness scale, so the offset is in scale points).
    // - The same symptom burden marginally lowers next-day completion likelihood →
    //   small negative completion offset (probability units).
    //
    // The follicular bucket is treated as the neutral reference (offset 0): population
    // recovery metrics are near baseline in the follicular-dominant half. `.unknown`
    // phase contributes nothing (offset 0) so the cycle-aware prediction collapses to
    // the baseline (no phase signal → no adjustment).

    /// Recovery-score suppression in the luteal bucket (points, 0-100 scale).
    private static let lutealRecoveryOffset: Double = -4.0
    /// Wellness-score suppression in the luteal bucket (points, 0-100 scale).
    private static let lutealWellnessOffset: Double = -3.0
    /// Completion-probability reduction in the luteal bucket (0-1 scale).
    private static let lutealCompletionOffset: Double = -0.05
    /// Soreness/pain elevation in the luteal bucket (1-5 soreness scale points).
    private static let lutealPainOffset: Double = 0.3

    /// Neutral fallback prediction when the series carries no usable signal.
    private static let neutralScore: Double = 50.0

    // MARK: - Predictions

    /// Baseline next-day prediction: last value + one-step linear-trend extrapolation.
    ///
    /// Uses `RecoveryScoreEngine.computeSlope` for the trend (mirroring how
    /// `FatigueIndexEngine` consumes the same helper). Degrades gracefully:
    /// - >= 2 points → last value + slope (one step ahead)
    /// - exactly 1 point → that value (pure persistence)
    /// - empty → `neutralScore` for score-like outcomes (caller passes a series in the
    ///   outcome's own units; the neutral fallback only ever applies to an empty series).
    static func baselinePrediction(series: [Double]) -> Double {
        guard let last = series.last else { return neutralScore }
        guard let slope = RecoveryScoreEngine.computeSlope(values: series) else {
            return last
        }
        return last + slope
    }

    /// Cycle-aware next-day prediction = baseline + fixed phase offset for `phase`.
    /// When `phase == .unknown` the offset is 0, so this equals `baselinePrediction(series:)`.
    static func cycleAwarePrediction(series: [Double], phase: CyclePhase, outcome: Outcome) -> Double {
        baselinePrediction(series: series) + phaseOffset(for: phase, outcome: outcome)
    }

    /// Cycle-aware prediction from a `CycleContext`. `.none` (phase `.unknown`) → baseline.
    static func cycleAwarePrediction(series: [Double], context: CycleContext, outcome: Outcome) -> Double {
        cycleAwarePrediction(series: series, phase: context.phase, outcome: outcome)
    }

    // MARK: - Phase offset

    /// Fixed literature-derived offset added to the baseline for the cycle-aware prediction.
    ///
    /// Follicular bucket and `.unknown` return 0 (neutral reference / no signal). Only the
    /// luteal bucket carries a non-zero offset, in the documented physiological direction.
    static func phaseOffset(for phase: CyclePhase, outcome: Outcome) -> Double {
        guard let bucket = RecoveryScoreEngine.bucket(for: phase) else {
            return 0  // .unknown → no phase signal
        }
        switch bucket {
        case .follicular:
            return 0  // neutral reference half
        case .luteal:
            switch outcome {
            case .recovery:   return lutealRecoveryOffset
            case .wellness:   return lutealWellnessOffset
            case .completion: return lutealCompletionOffset
            case .pain:       return lutealPainOffset
            }
        }
    }

    // MARK: - Error metric

    /// Absolute prediction error for a single resolved outcome.
    static func absoluteError(predicted: Double, actual: Double) -> Double {
        abs(predicted - actual)
    }
}

// MARK: - Experimental arm interface (Phase 24, D-11/D-13)

/// A generic registered shadow predictor ("arm"). Phases 26–28 register a new arm by adding it
/// to `ShadowPredictor.registeredArms()` — no change to the log model, the pipeline call, or the
/// analytics. Phase 24 ships exactly two arms (`baseline`, `cycleAware`) and adds NO new model.
///
/// Pure value type, Foundation-only, deterministic: `predict` is a function of `(outcome, series,
/// context)` with no state or I/O. `engineDerivedOutcomes` flags which of this arm's outcome
/// predictions target an engine-derived (circular) label (D-06).
struct ExperimentalArm {
    /// Stable identifier, e.g. `"baseline"`, `"cycleAware"`.
    let id: String
    /// Outcomes this arm treats as engine-derived (secondary / non-gating). See D-06.
    let engineDerivedOutcomes: Set<ShadowPredictor.Outcome>
    /// Deterministic prediction for an outcome given the outcome's history series and cycle
    /// context. Returns nil if the arm cannot produce a value for this outcome.
    let predict: (ShadowPredictor.Outcome, [Double], CycleContext) -> Double?
}

extension ShadowPredictor {

    /// The experimental arms registered this phase, in stable order. EXACTLY two:
    /// - `"baseline"` — persistence/trend extrapolation, ignores cycle context.
    /// - `"cycleAware"` — baseline + fixed literature-derived phase offset (collapses to baseline
    ///   when the phase is `.unknown`).
    /// Both delegate to the existing static methods so their numbers are byte-identical to the
    /// pre-Phase-24 hard-coded columns (D-13 regression guard). No model/PRS arm is added here.
    static func registeredArms() -> [ExperimentalArm] {
        let baseline = ExperimentalArm(
            id: "baseline",
            engineDerivedOutcomes: engineDerivedOutcomes,
            predict: { _, series, _ in
                ShadowPredictor.baselinePrediction(series: series)
            }
        )
        let cycleAware = ExperimentalArm(
            id: "cycleAware",
            engineDerivedOutcomes: engineDerivedOutcomes,
            predict: { outcome, series, context in
                ShadowPredictor.cycleAwarePrediction(series: series, context: context, outcome: outcome)
            }
        )
        return [baseline, cycleAware]
    }
}
