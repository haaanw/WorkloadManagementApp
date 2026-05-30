import XCTest
import Foundation
@testable import workload_management

/// **Phase 29 Wave 1 — `ActivationGateEvaluator` oracle / boundary / thin-data battery, the
/// activation-flag fence, and the no-mutation isolation grep.**
///
/// The evaluator is pure / deterministic / REPORT-ONLY: it consumes the EXISTING Phase-24
/// `ShadowAnalyticsService.OutcomeMetrics` + paired-MAE-difference CI tuples and reports whether the
/// four ROADMAP activation gates pass. These tests pin its behavior against hand-computed oracles,
/// the named-constant boundaries, the thin-data hard precondition, the all-flags-FALSE fence, and a
/// source-level guard that the evaluator never assigns any `*Activation.isEnabled` (GA-7).
@MainActor
final class ActivationGateEvaluatorTests: XCTestCase {

    typealias Outcome = ShadowPredictor.Outcome
    typealias Metrics = ShadowAnalyticsService.OutcomeMetrics
    typealias MAEInput = ActivationGateEvaluator.OutcomeMAEInput

    private let big = ActivationGateEvaluator.minResolvedRows  // 60

    // MARK: - Builders

    /// A "PRS wins" CI: upper bound strictly < 0.
    private func winCI(_ n: Int = 60) -> MAEInput {
        MAEInput(outcome: .recovery, ci: (lower: -2.0, upper: -0.5, point: -1.0), n: n)
    }

    private func mae(_ outcome: Outcome, win: Bool, n: Int = 60) -> MAEInput {
        let ci: (lower: Double, upper: Double, point: Double) = win
            ? (lower: -2.0, upper: -0.5, point: -1.0)   // upper < 0 → win
            : (lower: -0.5, upper: 0.5, point: 0.0)     // straddles 0 → no win
        return MAEInput(outcome: outcome, ci: ci, n: n)
    }

    private func metric(rho: Double?, slope: Double?, n: Int, engineDerived: Bool = false) -> Metrics {
        Metrics(n: n, mae: 1.0, calibrationSlope: slope, spearmanRho: rho, engineDerived: engineDerived)
    }

    /// A fully-passing metrics map (ρ and slope clear the gates on all primaries) at n>=60.
    private func passingMetrics(n: Int = 60) -> [Outcome: Metrics] {
        [
            .recovery:   metric(rho: 0.60, slope: 1.0, n: n, engineDerived: true),
            .wellness:   metric(rho: 0.60, slope: 1.0, n: n),
            .completion: metric(rho: 0.60, slope: 1.0, n: n),
            .pain:       metric(rho: 0.60, slope: 1.0, n: n)
        ]
    }

    /// MAE inputs where PRS wins on all 4 continuous outcomes.
    private func allWinMAE(n: Int = 60) -> [MAEInput] {
        [mae(.recovery, win: true, n: n), mae(.wellness, win: true, n: n),
         mae(.completion, win: true, n: n), mae(.pain, win: true, n: n)]
    }

    // MARK: - Oracle: clear PASS

    func test_oracle_allGatesPass_recommendsActivation() {
        let report = ActivationGateEvaluator.evaluate(
            prsMetrics: passingMetrics(), maeInputs: allWinMAE()
        )
        XCTAssertTrue(report.mae.passed, "G-MAE should pass (4/4 wins)")
        XCTAssertTrue(report.spearman.passed, "G-SPEARMAN should pass")
        XCTAssertTrue(report.calibration.passed, "G-CALIBRATION should pass")
        XCTAssertTrue(report.dataMaturity.passed, "G-DATA-MATURITY should pass")
        XCTAssertTrue(report.recommendsActivation, "all four gates pass → recommends")
        XCTAssertEqual(report.mae.winCount, 4)
        XCTAssertEqual(report.mae.rawSelfReportWinCount, 3, "raw-self-report sub-count excludes .recovery")
        XCTAssertEqual(report.reason, "all four activation gates passed")
    }

    func test_oracle_exactly3of4Wins_passesGMAE() {
        // .recovery loses, the 3 raw self-report outcomes win → 3/4, still ≥ minMAEBeatCount.
        let inputs = [mae(.recovery, win: false), mae(.wellness, win: true),
                      mae(.completion, win: true), mae(.pain, win: true)]
        let report = ActivationGateEvaluator.evaluate(prsMetrics: passingMetrics(), maeInputs: inputs)
        XCTAssertEqual(report.mae.winCount, 3)
        XCTAssertEqual(report.mae.rawSelfReportWinCount, 3)
        XCTAssertTrue(report.mae.passed, "3/4 meets the ≥3 threshold")
        XCTAssertTrue(report.recommendsActivation)
    }

    // MARK: - Per-gate isolated FAILURE

    func test_GMAE_only2Wins_fails() {
        let inputs = [mae(.recovery, win: true), mae(.wellness, win: true),
                      mae(.completion, win: false), mae(.pain, win: false)]
        let report = ActivationGateEvaluator.evaluate(prsMetrics: passingMetrics(), maeInputs: inputs)
        XCTAssertEqual(report.mae.winCount, 2)
        XCTAssertFalse(report.mae.passed, "2/4 < 3 → G-MAE fails")
        XCTAssertFalse(report.recommendsActivation)
        XCTAssertTrue(report.reason.contains("G-MAE"))
    }

    func test_GSpearman_designatedBelowThreshold_fails() {
        var m = passingMetrics()
        m[.wellness] = metric(rho: 0.49, slope: 1.0, n: big)  // designated ρ just below 0.50
        let report = ActivationGateEvaluator.evaluate(prsMetrics: m, maeInputs: allWinMAE())
        XCTAssertFalse(report.spearman.passed, "designated ρ 0.49 < 0.50 → fails")
        XCTAssertFalse(report.recommendsActivation)
        XCTAssertTrue(report.reason.contains("G-SPEARMAN"))
    }

    func test_GSpearman_otherSampledPrimaryBelow_fails() {
        var m = passingMetrics()
        m[.pain] = metric(rho: 0.40, slope: 1.0, n: big)  // sampled primary below → blocks
        let report = ActivationGateEvaluator.evaluate(prsMetrics: m, maeInputs: allWinMAE())
        XCTAssertFalse(report.spearman.passed, "a sampled primary below 0.50 blocks the gate")
        XCTAssertFalse(report.recommendsActivation)
    }

    func test_GCalibration_designatedOutsideBand_fails() {
        var m = passingMetrics()
        m[.wellness] = metric(rho: 0.60, slope: 1.25, n: big)  // slope > 1.2
        let report = ActivationGateEvaluator.evaluate(prsMetrics: m, maeInputs: allWinMAE())
        XCTAssertFalse(report.calibration.passed, "slope 1.25 outside [0.8,1.2] → fails")
        XCTAssertFalse(report.recommendsActivation)
        XCTAssertTrue(report.reason.contains("G-CALIBRATION"))
    }

    // MARK: - Boundaries

    func test_boundary_spearmanExactly050_passes() {
        var m = passingMetrics()
        m[.wellness] = metric(rho: 0.50, slope: 1.0, n: big)
        m[.completion] = metric(rho: 0.50, slope: 1.0, n: big)
        m[.pain] = metric(rho: 0.50, slope: 1.0, n: big)
        let report = ActivationGateEvaluator.evaluate(prsMetrics: m, maeInputs: allWinMAE())
        XCTAssertTrue(report.spearman.passed, "exactly 0.50 passes (>=)")
    }

    func test_boundary_calibrationExactlyLowAndHigh_passes() {
        var lowM = passingMetrics()
        lowM[.wellness] = metric(rho: 0.60, slope: 0.8, n: big)
        lowM[.completion] = metric(rho: 0.60, slope: 0.8, n: big)
        lowM[.pain] = metric(rho: 0.60, slope: 1.2, n: big)
        let report = ActivationGateEvaluator.evaluate(prsMetrics: lowM, maeInputs: allWinMAE())
        XCTAssertTrue(report.calibration.passed, "exactly 0.8 and 1.2 pass (inclusive)")
    }

    func test_boundary_ciUpperExactlyZero_isNOTaWin() {
        // CI upper bound exactly 0 → NOT a win (strict < 0). All four at upper==0 → 0 wins.
        let zero: (lower: Double, upper: Double, point: Double) = (lower: -1.0, upper: 0.0, point: -0.5)
        let inputs = ActivationGateEvaluator.continuousOutcomes.map {
            MAEInput(outcome: $0, ci: zero, n: big)
        }
        let report = ActivationGateEvaluator.evaluate(prsMetrics: passingMetrics(), maeInputs: inputs)
        XCTAssertEqual(report.mae.winCount, 0, "upper==0 is not strictly < 0 → no win")
        XCTAssertFalse(report.mae.passed)
        XCTAssertFalse(report.recommendsActivation)
    }

    // MARK: - Thin-data / nil precondition (GA-4)

    func test_thinData_n10_forcesNoActivation_evenWithPerfectMetrics() {
        // Perfect-looking metrics + all MAE wins, but n=10 < 60 → insufficient data.
        let report = ActivationGateEvaluator.evaluate(
            prsMetrics: passingMetrics(n: 10), maeInputs: allWinMAE(n: 10)
        )
        XCTAssertFalse(report.dataMaturity.passed, "n=10 < 60 → maturity fails")
        XCTAssertFalse(report.recommendsActivation, "insufficient data overrides everything")
        XCTAssertEqual(report.reason, "insufficient data")
    }

    func test_nilCI_forcesNoActivation_insufficientData() {
        // A nil CI on a continuous outcome → degenerate → data maturity fails even at large n.
        var inputs = allWinMAE()
        inputs[1] = MAEInput(outcome: .wellness, ci: nil, n: big)  // nil CI
        let report = ActivationGateEvaluator.evaluate(prsMetrics: passingMetrics(), maeInputs: inputs)
        XCTAssertTrue(report.dataMaturity.hadNilMetric, "nil CI flagged")
        XCTAssertFalse(report.dataMaturity.passed)
        XCTAssertFalse(report.recommendsActivation)
        XCTAssertEqual(report.reason, "insufficient data")
    }

    func test_nilMetric_forcesNoActivation() {
        var m = passingMetrics()
        m[.wellness] = metric(rho: nil, slope: 1.0, n: big)  // nil ρ on a sampled primary
        let report = ActivationGateEvaluator.evaluate(prsMetrics: m, maeInputs: allWinMAE())
        XCTAssertTrue(report.dataMaturity.hadNilMetric)
        XCTAssertFalse(report.recommendsActivation)
    }

    // MARK: - Form (a) convenience wires the real harness

    func test_formA_overResolvedRows_returnsAReport_noCrash() {
        // Empty rows → thin data → no activation, never a crash / fabricated pass.
        let report = ActivationGateEvaluator.evaluate(resolvedRows: [])
        XCTAssertFalse(report.recommendsActivation)
        XCTAssertEqual(report.reason, "insufficient data")
    }

    // MARK: - Activation-flag fence (all three flags FALSE)

    func test_activationFlagFence_allFlagsFalse() {
        XCTAssertFalse(PRSMasterActivation.isEnabled, "PRSMasterActivation must default FALSE")
        XCTAssertFalse(PRSActivation.isEnabled, "PRSActivation must default FALSE")
        XCTAssertFalse(CycleModifierActivation.isEnabled, "CycleModifierActivation must default FALSE")
    }

    // MARK: - No-mutation isolation grep (GA-7)

    /// Resolve the evaluator source via #filePath parent traversal (mirrors the convergence-report
    /// repo-root resolution) and assert it contains no `isEnabled =` / `.isEnabled =` assignment.
    func test_evaluatorSource_neverAssignsAnyActivationFlag() throws {
        let repoRoot = URL(fileURLWithPath: "\(#filePath)")
            .deletingLastPathComponent()   // WorkloadAppTests/
            .deletingLastPathComponent()   // <repo root>
        let source = repoRoot
            .appendingPathComponent("WorkloadApp/Services/ActivationGateEvaluator.swift")
        let text = try String(contentsOf: source, encoding: .utf8)

        // The GA-7 invariant: the evaluator must never ASSIGN any *.isEnabled (it is report-only).
        // We check for the assignment substrings only — documentation that NAMES the flags (to
        // explain the no-mutation contract) is legitimate and intended, so we do NOT forbid mere
        // references. Tolerate "isEnabled ==" comparisons by requiring a non-`=` char after the `=`.
        for pattern in ["isEnabled =", ".isEnabled ="] {
            var searchRange = text.startIndex..<text.endIndex
            while let r = text.range(of: pattern, range: searchRange) {
                // Character immediately after the matched "=" — an assignment iff it is NOT another
                // "=" (which would make it "==", a comparison).
                let afterEq = r.upperBound
                let isComparison = afterEq < text.endIndex && text[afterEq] == "="
                XCTAssertTrue(isComparison,
                              "ActivationGateEvaluator must never assign \(pattern) (report-only, GA-7)")
                searchRange = r.upperBound..<text.endIndex
            }
        }
    }
}
