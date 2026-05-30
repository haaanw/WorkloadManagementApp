import Foundation

/// **Pure, deterministic, REPORT-ONLY activation-gate evaluator (Phase 29).**
///
/// Consumes the EXISTING Phase-24 `ShadowAnalyticsService` PRS-vs-baseline metric outputs
/// (`OutcomeMetrics` + `pairedMAEDifferenceCI` tuples) and reports whether the four ROADMAP
/// activation gates pass. It adds NO new statistics — all the math already lives in `ShadowMetrics`
/// / `ShadowAnalyticsService`. This is the honest go-live gate any FUTURE live activation must clear.
///
/// ## Hard scope fence (GA-7)
/// This engine is **REPORT-ONLY**. It returns a `GateReport` whose `recommendsActivation` is a
/// recommendation rendered into the shadow-validation report — it **MUST NOT** read or write any
/// `*Activation.isEnabled`. No source line here assigns `isEnabled` (enforced by a no-mutation grep
/// test). It imports neither `PRSMasterActivation` nor `PRSActivation` for mutation. NO persisted
/// SwiftData state (GA-5). NO new statistics in `ShadowMetrics`.
///
/// ## The four ROADMAP gates
/// - **G-MAE**: PRS beats baseline on ≥ `minMAEBeatCount` (3) of the 4 continuous outcomes
///   (`.recovery`, `.wellness`, `.completion`, `.pain`). `.niggleSeverity` is excluded (no arm
///   predicts it in v1). A "PRS win" on an outcome ⇔ its paired-MAE-difference CI **upper bound < 0**
///   (PRS error strictly lower; GA-9 sign convention below).
/// - **G-SPEARMAN**: the designated primary self-report outcome (`.wellness`) has Spearman ρ ≥
///   `minSpearman` (0.50), AND no sufficiently-sampled primary outcome (`.wellness`/`.completion`/
///   `.pain`) falls below 0.50. Boundary: exactly 0.50 passes (`>=`).
/// - **G-CALIBRATION**: the primary outcome calibration slope ∈ `[calibrationLow, calibrationHigh]`
///   ([0.8, 1.2]), AND no sufficiently-sampled primary outcome is outside the band. Boundary: exactly
///   0.8 and 1.2 pass (inclusive).
/// - **G-DATA-MATURITY**: a hard precondition — if the resolved-row count `n` for the gating
///   outcomes < `minResolvedRows` (60), OR any required gate metric is `nil` (thin/degenerate data),
///   `recommendsActivation = false` with reason "insufficient data" — REGARDLESS of any other gate
///   (GA-4). Thin/degenerate data must never fabricate a pass.
///
/// `overall recommendsActivation == (G-MAE && G-SPEARMAN && G-CALIBRATION && G-DATA-MATURITY all
/// pass)`. The honesty caveat (GA-2): `.recovery` is engine-derived (circular), so the report also
/// surfaces a raw-self-report-only MAE-win sub-count (over `.wellness`/`.completion`/`.pain`).
///
/// ## Sign convention (GA-9)
/// The MAE CI is computed with `armA="prs"`, `armB="baseline"`, i.e.
/// `d = |err_prs| - |err_baseline|`. PRS WINS when the CI **upper bound < 0** (PRS error strictly
/// lower than baseline). A CI upper bound of exactly `0` is **NOT** a win (`< 0`, strict).
///
/// Pure struct, static methods, Foundation only — deterministic.
struct ActivationGateEvaluator {

    // MARK: - Fixed named thresholds (GA-8 — match the ROADMAP verbatim)

    /// G-MAE: PRS must beat baseline on at least this many of the 4 continuous outcomes.
    static let minMAEBeatCount: Int = 3
    /// The 4 continuous outcomes G-MAE counts over. `.niggleSeverity` is excluded (no arm in v1).
    static let continuousOutcomeCount: Int = 4
    /// G-SPEARMAN: minimum Spearman ρ on the primary self-report outcomes (inclusive).
    static let minSpearman: Double = 0.50
    /// G-CALIBRATION: inclusive calibration-slope band lower bound.
    static let calibrationLow: Double = 0.8
    /// G-CALIBRATION: inclusive calibration-slope band upper bound.
    static let calibrationHigh: Double = 1.2
    /// G-DATA-MATURITY: minimum resolved-row count before any gate verdict can recommend activation.
    static let minResolvedRows: Int = 60

    /// The four continuous outcomes counted by G-MAE (`.niggleSeverity` excluded).
    static let continuousOutcomes: [ShadowPredictor.Outcome] = [.recovery, .wellness, .completion, .pain]
    /// The primary RAW self-report outcomes (non-engine-derived) used for ρ / calibration gating.
    static let primarySelfReportOutcomes: [ShadowPredictor.Outcome] = [.wellness, .completion, .pain]
    /// The single designated primary outcome whose ρ / slope must individually clear its gate.
    static let designatedPrimaryOutcome: ShadowPredictor.Outcome = .wellness

    // MARK: - Inputs (the testable PURE core, form (b))

    /// A single outcome's paired-MAE-difference CI (PRS vs baseline) plus its sample size.
    /// `ci == nil` ⇔ `ShadowAnalyticsService.pairedMAEDifferenceCI` returned nil (thin/degenerate).
    struct OutcomeMAEInput {
        let outcome: ShadowPredictor.Outcome
        let ci: (lower: Double, upper: Double, point: Double)?
        let n: Int

        init(outcome: ShadowPredictor.Outcome,
             ci: (lower: Double, upper: Double, point: Double)?,
             n: Int) {
            self.outcome = outcome
            self.ci = ci
            self.n = n
        }
    }

    // MARK: - Per-gate evidence + verdict

    /// One outcome's G-MAE breakdown (glass-box evidence).
    struct MAEWinEvidence {
        let outcome: ShadowPredictor.Outcome
        let ci: (lower: Double, upper: Double, point: Double)?
        let n: Int
        let engineDerived: Bool
        /// PRS win ⇔ CI upper bound < 0 (strict). nil CI ⇒ not a win.
        let isWin: Bool
    }

    struct GMAEResult {
        let passed: Bool
        let winCount: Int
        /// Raw-self-report-only win sub-count (GA-2 honesty caveat — excludes `.recovery`).
        let rawSelfReportWinCount: Int
        let evidence: [MAEWinEvidence]
        let threshold: Int
        let reason: String
    }

    /// One primary outcome's ρ breakdown.
    struct SpearmanEvidence {
        let outcome: ShadowPredictor.Outcome
        let rho: Double?
        let n: Int
        let meetsThreshold: Bool   // rho != nil && rho >= minSpearman (when n>=minResolvedRows)
    }

    struct GSpearmanResult {
        let passed: Bool
        let designatedRho: Double?
        let evidence: [SpearmanEvidence]
        let threshold: Double
        let reason: String
    }

    /// One primary outcome's calibration-slope breakdown.
    struct CalibrationEvidence {
        let outcome: ShadowPredictor.Outcome
        let slope: Double?
        let n: Int
        let inBand: Bool
    }

    struct GCalibrationResult {
        let passed: Bool
        let designatedSlope: Double?
        let evidence: [CalibrationEvidence]
        let low: Double
        let high: Double
        let reason: String
    }

    struct GDataMaturityResult {
        let passed: Bool
        /// The minimum resolved-row count across the gating outcomes considered.
        let minObservedN: Int
        let threshold: Int
        /// True if any required gate metric was nil (thin/degenerate).
        let hadNilMetric: Bool
        let reason: String
    }

    // MARK: - Overall report

    /// The full glass-box gate report. `recommendsActivation` is REPORT-ONLY (GA-7).
    struct GateReport {
        let mae: GMAEResult
        let spearman: GSpearmanResult
        let calibration: GCalibrationResult
        let dataMaturity: GDataMaturityResult
        /// Overall recommendation = all four gates passed. REPORT-ONLY — never assigned to a flag.
        let recommendsActivation: Bool
        /// Human-readable summary reason (the dominant gate failure, or the pass message).
        let reason: String
    }

    // MARK: - Pure evaluation core (form (b) — oracle-testable with hand-built inputs)

    /// Evaluate the four gates from per-outcome metric inputs. Pure / deterministic / report-only.
    ///
    /// - Parameters:
    ///   - prsMetrics: PRS-arm per-outcome `OutcomeMetrics` (from `metricsReport(armId:"prs")`),
    ///     providing Spearman ρ, calibration slope, and `n` for the ρ / calibration / maturity gates.
    ///   - maeInputs: per-outcome PRS-vs-baseline paired-MAE-difference CIs (from
    ///     `pairedMAEDifferenceCI(armA:"prs",armB:"baseline")`) for the four continuous outcomes.
    static func evaluate(
        prsMetrics: [ShadowPredictor.Outcome: ShadowAnalyticsService.OutcomeMetrics],
        maeInputs: [OutcomeMAEInput]
    ) -> GateReport {
        let mae = evaluateMAE(maeInputs: maeInputs)
        let spearman = evaluateSpearman(prsMetrics: prsMetrics)
        let calibration = evaluateCalibration(prsMetrics: prsMetrics)
        let dataMaturity = evaluateDataMaturity(prsMetrics: prsMetrics, maeInputs: maeInputs)

        // GA-4: data-maturity is a HARD precondition — it overrides everything. If it fails, no
        // activation regardless of the other gates.
        let allPass = dataMaturity.passed && mae.passed && spearman.passed && calibration.passed
        let recommends = allPass

        let reason: String
        if !dataMaturity.passed {
            reason = "insufficient data"
        } else if recommends {
            reason = "all four activation gates passed"
        } else {
            var failed: [String] = []
            if !mae.passed { failed.append("G-MAE") }
            if !spearman.passed { failed.append("G-SPEARMAN") }
            if !calibration.passed { failed.append("G-CALIBRATION") }
            reason = "gate(s) failed: \(failed.joined(separator: ", "))"
        }

        return GateReport(
            mae: mae,
            spearman: spearman,
            calibration: calibration,
            dataMaturity: dataMaturity,
            recommendsActivation: recommends,
            reason: reason
        )
    }

    // MARK: - G-MAE

    static func evaluateMAE(maeInputs: [OutcomeMAEInput]) -> GMAEResult {
        // Order evidence by the canonical continuous-outcome order for a stable report.
        var evidence: [MAEWinEvidence] = []
        let byOutcome = Dictionary(uniqueKeysWithValues: maeInputs.map { ($0.outcome, $0) })
        for outcome in continuousOutcomes {
            let input = byOutcome[outcome]
            let ci = input?.ci ?? nil
            let n = input?.n ?? 0
            let engineDerived = ShadowPredictor.engineDerivedOutcomes.contains(outcome)
            // PRS win ⇔ CI upper bound < 0 (strict, GA-9). nil CI ⇒ not a win.
            let isWin = (ci.map { $0.upper < 0 }) ?? false
            evidence.append(MAEWinEvidence(
                outcome: outcome, ci: ci, n: n, engineDerived: engineDerived, isWin: isWin
            ))
        }
        let winCount = evidence.filter { $0.isWin }.count
        let rawWinCount = evidence.filter { $0.isWin && !$0.engineDerived }.count
        let passed = winCount >= minMAEBeatCount
        let reason = passed
            ? "PRS beat baseline on \(winCount)/\(continuousOutcomeCount) continuous outcomes (≥ \(minMAEBeatCount))"
            : "PRS beat baseline on only \(winCount)/\(continuousOutcomeCount) (need ≥ \(minMAEBeatCount))"
        return GMAEResult(
            passed: passed,
            winCount: winCount,
            rawSelfReportWinCount: rawWinCount,
            evidence: evidence,
            threshold: minMAEBeatCount,
            reason: reason
        )
    }

    // MARK: - G-SPEARMAN

    static func evaluateSpearman(
        prsMetrics: [ShadowPredictor.Outcome: ShadowAnalyticsService.OutcomeMetrics]
    ) -> GSpearmanResult {
        var evidence: [SpearmanEvidence] = []
        var anySufficientBelow = false
        for outcome in primarySelfReportOutcomes {
            let m = prsMetrics[outcome]
            let rho = m?.spearmanRho
            let n = m?.n ?? 0
            let sufficient = n >= minResolvedRows
            let meets = (rho.map { $0 >= minSpearman }) ?? false
            if sufficient && !meets { anySufficientBelow = true }
            evidence.append(SpearmanEvidence(outcome: outcome, rho: rho, n: n, meetsThreshold: meets))
        }
        let designated = prsMetrics[designatedPrimaryOutcome]?.spearmanRho
        let designatedMeets = (designated.map { $0 >= minSpearman }) ?? false
        let passed = designatedMeets && !anySufficientBelow
        let reason = passed
            ? "primary ρ (\(designatedPrimaryOutcome)) ≥ \(minSpearman) and no sampled primary below"
            : "primary ρ gate not met (designated ρ \(designated.map { String(format: "%.3f", $0) } ?? "nil") vs ≥ \(minSpearman))"
        return GSpearmanResult(
            passed: passed,
            designatedRho: designated,
            evidence: evidence,
            threshold: minSpearman,
            reason: reason
        )
    }

    // MARK: - G-CALIBRATION

    static func evaluateCalibration(
        prsMetrics: [ShadowPredictor.Outcome: ShadowAnalyticsService.OutcomeMetrics]
    ) -> GCalibrationResult {
        var evidence: [CalibrationEvidence] = []
        var anySufficientOutside = false
        for outcome in primarySelfReportOutcomes {
            let m = prsMetrics[outcome]
            let slope = m?.calibrationSlope
            let n = m?.n ?? 0
            let sufficient = n >= minResolvedRows
            let inBand = (slope.map { $0 >= calibrationLow && $0 <= calibrationHigh }) ?? false
            if sufficient && !inBand { anySufficientOutside = true }
            evidence.append(CalibrationEvidence(outcome: outcome, slope: slope, n: n, inBand: inBand))
        }
        let designated = prsMetrics[designatedPrimaryOutcome]?.calibrationSlope
        let designatedInBand = (designated.map { $0 >= calibrationLow && $0 <= calibrationHigh }) ?? false
        let passed = designatedInBand && !anySufficientOutside
        let reason = passed
            ? "primary slope (\(designatedPrimaryOutcome)) ∈ [\(calibrationLow), \(calibrationHigh)] and no sampled primary outside"
            : "primary calibration-slope gate not met (designated slope \(designated.map { String(format: "%.3f", $0) } ?? "nil") vs [\(calibrationLow), \(calibrationHigh)])"
        return GCalibrationResult(
            passed: passed,
            designatedSlope: designated,
            evidence: evidence,
            low: calibrationLow,
            high: calibrationHigh,
            reason: reason
        )
    }

    // MARK: - G-DATA-MATURITY (hard precondition, GA-4)

    static func evaluateDataMaturity(
        prsMetrics: [ShadowPredictor.Outcome: ShadowAnalyticsService.OutcomeMetrics],
        maeInputs: [OutcomeMAEInput]
    ) -> GDataMaturityResult {
        // The gating outcomes whose sample count must mature: the 4 continuous outcomes' MAE inputs
        // plus the primary self-report metric rows used by ρ / calibration.
        let byOutcome = Dictionary(uniqueKeysWithValues: maeInputs.map { ($0.outcome, $0) })
        var observedNs: [Int] = []
        var hadNil = false

        for outcome in continuousOutcomes {
            let n = byOutcome[outcome]?.n ?? 0
            observedNs.append(n)
            // A nil CI on a continuous outcome ⇒ thin/degenerate data for that pair.
            if byOutcome[outcome]?.ci == nil { hadNil = true }
        }
        for outcome in primarySelfReportOutcomes {
            let m = prsMetrics[outcome]
            observedNs.append(m?.n ?? 0)
            // Required ρ / calibration metrics nil on a sampled primary ⇒ degenerate.
            if m?.spearmanRho == nil || m?.calibrationSlope == nil { hadNil = true }
        }

        let minObserved = observedNs.min() ?? 0
        let matureCount = minObserved >= minResolvedRows
        let passed = matureCount && !hadNil
        let reason: String
        if !matureCount {
            reason = "insufficient data — min resolved-row count \(minObserved) < \(minResolvedRows)"
        } else if hadNil {
            reason = "insufficient data — a required gate metric was nil (thin/degenerate)"
        } else {
            reason = "data maturity met — all gating outcomes have ≥ \(minResolvedRows) resolved rows"
        }
        return GDataMaturityResult(
            passed: passed,
            minObservedN: minObserved,
            threshold: minResolvedRows,
            hadNilMetric: hadNil,
            reason: reason
        )
    }

    // MARK: - Form (a) convenience: wire the EXISTING ShadowAnalyticsService outputs

    /// Convenience entry point that drives the EXISTING `ShadowAnalyticsService` over resolved rows
    /// for the PRS arm vs baseline and evaluates the gates. Adds NO statistics — it only extracts the
    /// already-computed `metricsReport` + `pairedMAEDifferenceCI` outputs and forwards them to the
    /// pure `evaluate(prsMetrics:maeInputs:)` core. `@MainActor` because `ShadowAnalyticsService` is.
    @MainActor
    static func evaluate(
        resolvedRows: [CyclePredictionLog],
        ciSeed: UInt64 = 0x5EED
    ) -> GateReport {
        let prsMetrics = ShadowAnalyticsService.metricsReport(resolvedRows: resolvedRows, armId: "prs")
        var maeInputs: [OutcomeMAEInput] = []
        for outcome in continuousOutcomes {
            let ci = ShadowAnalyticsService.pairedMAEDifferenceCI(
                resolvedRows: resolvedRows,
                outcome: outcome,
                armA: "prs",
                armB: "baseline",
                seed: ciSeed
            )
            let n = prsMetrics[outcome]?.n ?? 0
            maeInputs.append(OutcomeMAEInput(outcome: outcome, ci: ci, n: n))
        }
        return evaluate(prsMetrics: prsMetrics, maeInputs: maeInputs)
    }
}
