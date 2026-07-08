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
        case niggleSeverity   // max SorenessLog severity (0-10) in the outcome window, 0 if none (P25 D-04)
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
            case .niggleSeverity: return 0  // no cycle offset in v1 (P25 D-04); no arm predicts it
            }
        }
    }

    // MARK: - PRS-v1 prediction (Phase 28, Wave 3 — shadow only)

    /// PRS-v1 next-day prediction for an outcome.
    ///
    /// The PRS arm is the **predicting** arm of the algorithm moat. Within the existing harness
    /// contract `(outcome, series)` it forms a baseline persistence/trend extrapolation and then
    /// applies a small, sign-correct **readiness-trend** adjustment derived from the recent series
    /// itself (a proxy for the `ReadinessFusionEngine` direction): when the athlete's own recent
    /// trajectory is improving, nudge the prediction up; when declining, nudge it down. This keeps
    /// the arm deterministic and leak-free (it uses only the supplied historical series, never the
    /// target day), while being a genuinely DIFFERENT predictor from `baseline` so the Phase-29
    /// shadow comparison is meaningful.
    ///
    /// Validated against RAW self-report labels (wellness / pain / adherence) in the harness; the
    /// `recovery` outcome stays flagged engine-derived / secondary (codex §315).
    static func prsPrediction(series: [Double], outcome: Outcome) -> Double {
        let base = baselinePrediction(series: series)
        guard series.count >= 3,
              let slope = RecoveryScoreEngine.computeSlope(values: series) else {
            return base
        }
        // Readiness-trend nudge: a fraction of the recent slope, in the outcome's own units.
        // Pain is inverted (a rising pain trend is "worse"), but the slope is already in pain units
        // so we keep the same additive form — the arm simply trusts the recent trajectory more than
        // pure persistence. Magnitude is deliberately conservative (0.5× the one-step slope).
        let nudge = 0.5 * slope
        switch outcome {
        case .niggleSeverity: return base // no arm predicts niggleSeverity in v1 (P25 D-04)
        default: return base + nudge
        }
    }

    // MARK: - Cross-modal prediction (Phase 41, ACT-02 — shadow only, DARK)

    /// Cross-modal next-day prediction for an outcome (the shadow arm representing the
    /// `CrossModalFatigueEngine` channel).
    ///
    /// The FULL engine (`CrossModalFatigueEngine`) is region-resolved and consumes raw
    /// `[WorkoutSession]` to express *directional* carry — yesterday's run loads today's legs but
    /// spares the bench. The shadow-harness arm contract, however, only hands an arm the per-outcome
    /// history `series` (no raw sessions, no region). So within that contract this arm represents the
    /// cross-modal HYPOTHESIS deterministically and leak-free: when the athlete's own recent trajectory
    /// shows ELEVATED above-normal load (proxied by a recency-weighted rise in the historical series),
    /// the next-day value is nudged in the cross-modal-fatigue direction (down for capacity-like
    /// outcomes, UP for pain — fatigue carry makes soreness worse), through a CONCAVE, saturating,
    /// bounded modifier so two stacked stressors never double-penalize (mirrors the engine's
    /// anti-linear-stacking `maxPenalty · (1 − e^(−k·E))` core and the conservative `0.5×` posture of
    /// the `prs` arm). It uses ONLY the supplied historical series — never the target day (no leak) —
    /// and is a genuinely DIFFERENT predictor from `baseline` and `prs` (it dampens toward the recent
    /// MEAN under elevation rather than extrapolating the trend), so the Phase-43-gating shadow
    /// comparison is meaningful.
    ///
    /// This is the shadow-harness predictor for the same cross-modal channel. Verdict influence is
    /// separately controlled by `CrossModalShadowGate.crossModalDrivesVerdict`.
    static func crossModalPrediction(series: [Double], outcome: ShadowPredictor.Outcome) -> Double {
        let base = baselinePrediction(series: series)
        guard outcome != .niggleSeverity else { return base } // no arm predicts niggleSeverity in v1 (P25 D-04)
        guard series.count >= 3,
              let slope = RecoveryScoreEngine.computeSlope(values: series) else {
            return base
        }
        // Recency-weighted "above-normal elevation" proxy E ≥ 0: a recent RISE in load proxies
        // accumulated cross-modal carry. We read it from the series' own trend magnitude relative to
        // its spread, deadbanded so steady-state athletes (flat series) get E ≈ 0 ⇒ no nudge (only
        // ABOVE-personal-normal carry counts — the engine's personal-baseline moat). Leak-free: uses
        // only the historical `series`.
        let mean = series.reduce(0, +) / Double(series.count)
        let spread = series.map { abs($0 - mean) }.reduce(0, +) / Double(series.count)
        let denom = max(spread, 1.0) // avoid divide-by-zero / over-amplifying tiny-spread series
        let rawElevation = max(0.0, slope) / denom
        let E = max(0.0, rawElevation - crossModalElevationDeadband)
        // Concave, saturating, bounded carry penalty (anti-linear-stacking): maxNudge · (1 − e^(−k·E)).
        let carry = crossModalMaxNudge * (1.0 - exp(-crossModalK * E))
        // Direction: fatigue carry DEPRESSES capacity-like outcomes and RAISES reported pain.
        switch outcome {
        case .pain:           return base + carry  // more carry ⇒ more next-day soreness
        case .niggleSeverity: return base          // unreachable (guarded above); defensive
        default:              return base - carry  // recovery / wellness / completion: depressed
        }
    }

    /// Saturating-rate of the cross-modal arm's concave carry modifier (mirrors the engine's `k`).
    private static let crossModalK: Double = 2.0
    /// Bounded magnitude of the cross-modal arm's next-day nudge in the outcome's own units
    /// (conservative — matches the engine's deliberately small `maxPenalty` posture).
    private static let crossModalMaxNudge: Double = 2.0
    /// Above-personal-normal deadband: only a series whose recency-weighted elevation clears this gets
    /// any nudge (steady-state athletes ⇒ E ≈ 0 ⇒ no penalty — the personal-baseline moat).
    private static let crossModalElevationDeadband: Double = 0.10

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

    /// The experimental arms registered, in stable order. EXACTLY four:
    /// - `"baseline"` — persistence/trend extrapolation, ignores cycle context.
    /// - `"cycleAware"` — baseline + fixed literature-derived phase offset (collapses to baseline
    ///   when the phase is `.unknown`).
    /// - `"prs"` — PRS-v1 readiness-trend predicting arm (Phase 28, shadow-only).
    /// - `"crossModal"` — the cross-modal fatigue-carry arm (Phase 41, ACT-02): represents the
    ///   `CrossModalFatigueEngine` channel inside the harness contract. Runs UNCONDITIONALLY (shadow
    ///   only); verdict influence is separately gated by `CrossModalShadowGate.crossModalDrivesVerdict`.
    /// `baseline`/`cycleAware`/`prs` delegate to their existing static methods so their numbers stay
    /// byte-identical to the pre-Phase-24 hard-coded columns (D-13 regression guard); appending the
    /// fourth arm does NOT perturb the first three.
    static func registeredArms() -> [ExperimentalArm] {
        let baseline = ExperimentalArm(
            id: "baseline",
            engineDerivedOutcomes: engineDerivedOutcomes,
            predict: { outcome, series, _ in
                // P25 D-04: no arm predicts .niggleSeverity in v1. Returning the 50.0 neutral
                // score on a 0–10 scale would pollute metrics; nil is correct (harness tolerates it).
                guard outcome != .niggleSeverity else { return nil }
                return ShadowPredictor.baselinePrediction(series: series)
            }
        )
        let cycleAware = ExperimentalArm(
            id: "cycleAware",
            engineDerivedOutcomes: engineDerivedOutcomes,
            predict: { outcome, series, context in
                // P25 D-04: no arm predicts .niggleSeverity in v1 (see baseline arm above).
                guard outcome != .niggleSeverity else { return nil }
                return ShadowPredictor.cycleAwarePrediction(series: series, context: context, outcome: outcome)
            }
        )
        // Phase 28, Wave 3: the PRS-v1 predicting arm. Runs UNCONDITIONALLY (shadow-only) —
        // independent of PRSActivation.isEnabled (which gates only the live user-facing swap).
        let prs = ExperimentalArm(
            id: "prs",
            engineDerivedOutcomes: engineDerivedOutcomes,
            predict: { outcome, series, _ in
                // P25 D-04: no arm predicts .niggleSeverity in v1.
                guard outcome != .niggleSeverity else { return nil }
                return ShadowPredictor.prsPrediction(series: series, outcome: outcome)
            }
        )
        // Phase 41, ACT-02: the cross-modal fatigue-carry arm. The full region-resolved
        // CrossModalFatigueEngine is the channel this arm represents; within the harness contract it
        // logs a deterministic, leak-free, cross-modal-flavoured prediction. Runs UNCONDITIONALLY
        // (shadow-only) — independent of EVERY activation flag (PRSActivation / PRSMasterActivation /
        // VerdictSurfaceActivation) AND of CrossModalShadowGate. Its VERDICT influence is separately
        // gated by CrossModalShadowGate.crossModalDrivesVerdict — never by this registration.
        let crossModal = ExperimentalArm(
            id: "crossModal",
            engineDerivedOutcomes: engineDerivedOutcomes,
            predict: { outcome, series, _ in
                // P25 D-04: no arm predicts .niggleSeverity in v1.
                guard outcome != .niggleSeverity else { return nil }
                return ShadowPredictor.crossModalPrediction(series: series, outcome: outcome)
            }
        )
        return [baseline, cycleAware, prs, crossModal]
    }
}
