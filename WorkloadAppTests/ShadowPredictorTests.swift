import XCTest
@testable import workload_management

/// Phase 20 Plan 01 — ShadowPredictor pure-engine unit tests.
/// Proves: unknown-phase / .none-context equivalence (cycle-aware == baseline),
/// luteal offset direction, the baseline extrapolation formula, and the error metric.
final class ShadowPredictorTests: XCTestCase {

    // MARK: - Baseline extrapolation

    func test_baseline_emptySeries_returnsNeutral() {
        XCTAssertEqual(ShadowPredictor.baselinePrediction(series: []), 50.0, accuracy: 0.0001)
    }

    func test_baseline_singleValue_returnsThatValue() {
        XCTAssertEqual(ShadowPredictor.baselinePrediction(series: [72]), 72.0, accuracy: 0.0001)
    }

    func test_baseline_increasingSeries_extrapolatesUp() {
        // Perfectly linear +5/step series; slope == 5, last == 70 → 75.
        let series = [55.0, 60, 65, 70]
        let slope = RecoveryScoreEngine.computeSlope(values: series)!
        let expected = series.last! + slope
        XCTAssertEqual(ShadowPredictor.baselinePrediction(series: series), expected, accuracy: 0.0001)
        XCTAssertEqual(ShadowPredictor.baselinePrediction(series: series), 75.0, accuracy: 0.0001)
    }

    func test_baseline_flatSeries_extrapolatesFlat() {
        let series = [60.0, 60, 60, 60]
        XCTAssertEqual(ShadowPredictor.baselinePrediction(series: series), 60.0, accuracy: 0.0001)
    }

    // MARK: - Unknown phase / none context is a no-op

    func test_unknownPhase_cycleAwareEqualsBaseline_allOutcomes() {
        let series = [50.0, 55, 60]
        let base = ShadowPredictor.baselinePrediction(series: series)
        for outcome in [ShadowPredictor.Outcome.recovery, .wellness, .completion, .pain] {
            let cycleAware = ShadowPredictor.cycleAwarePrediction(series: series, phase: .unknown, outcome: outcome)
            XCTAssertEqual(cycleAware, base, accuracy: 0.0001, "unknown phase must contribute zero offset")
            XCTAssertEqual(ShadowPredictor.phaseOffset(for: .unknown, outcome: outcome), 0, accuracy: 0.0001)
        }
    }

    func test_noneContext_cycleAwareEqualsBaseline() {
        let series = [50.0, 55, 60]
        let base = ShadowPredictor.baselinePrediction(series: series)
        let cycleAware = ShadowPredictor.cycleAwarePrediction(series: series, context: .none, outcome: .recovery)
        XCTAssertEqual(cycleAware, base, accuracy: 0.0001)
    }

    // MARK: - Follicular bucket is neutral reference

    func test_follicularPhases_zeroOffset() {
        for phase in [CyclePhase.earlyFollicular, .lateFollicular, .ovulatory] {
            XCTAssertEqual(ShadowPredictor.phaseOffset(for: phase, outcome: .recovery), 0, accuracy: 0.0001)
        }
    }

    // MARK: - Luteal offset direction (research-derived)

    func test_lutealRecoveryOffset_isNegative() {
        // Luteal HRV suppression / RHR rise depress recovery → negative offset.
        XCTAssertLessThan(ShadowPredictor.phaseOffset(for: .lateLuteal, outcome: .recovery), 0)
        XCTAssertLessThan(ShadowPredictor.phaseOffset(for: .earlyLuteal, outcome: .recovery), 0)
    }

    func test_lutealWellnessOffset_isNegative() {
        XCTAssertLessThan(ShadowPredictor.phaseOffset(for: .lateLuteal, outcome: .wellness), 0)
    }

    func test_lutealCompletionOffset_isNegative() {
        XCTAssertLessThan(ShadowPredictor.phaseOffset(for: .lateLuteal, outcome: .completion), 0)
    }

    func test_lutealPainOffset_isPositive() {
        // Elevated luteal symptom burden raises reported soreness → positive offset.
        XCTAssertGreaterThan(ShadowPredictor.phaseOffset(for: .lateLuteal, outcome: .pain), 0)
    }

    func test_lutealRecovery_cycleAwareBelowBaseline() {
        let series = [60.0, 62, 64]
        let base = ShadowPredictor.baselinePrediction(series: series)
        let cycleAware = ShadowPredictor.cycleAwarePrediction(series: series, phase: .lateLuteal, outcome: .recovery)
        XCTAssertLessThan(cycleAware, base)
    }

    // MARK: - Error metric

    func test_absoluteError() {
        XCTAssertEqual(ShadowPredictor.absoluteError(predicted: 70, actual: 65), 5, accuracy: 0.0001)
        XCTAssertEqual(ShadowPredictor.absoluteError(predicted: 60, actual: 72), 12, accuracy: 0.0001)
        XCTAssertEqual(ShadowPredictor.absoluteError(predicted: 50, actual: 50), 0, accuracy: 0.0001)
    }

    // MARK: - Phase 24: ExperimentalArm registry (D-11/D-13)

    private func cycleContext(phase: CyclePhase) -> CycleContext {
        CycleContext(
            phase: phase, confidence: 1, cycleDay: nil, cycleLength: nil,
            isOnHormonalContraceptive: false, isPregnant: false, isLactating: false
        )
    }

    func test_registeredArms_baselineCycleAwareAndPRS() {
        // Phase 28 (Wave 3): the PRS-v1 predicting arm joins as a THIRD arm (shadow-only, stable order).
        let ids = ShadowPredictor.registeredArms().map(\.id)
        XCTAssertEqual(ids, ["baseline", "cycleAware", "prs"], "baseline + cycleAware + prs, stable order")
    }

    func test_baselineArm_equalsBaselinePrediction_byteIdentical() {
        let arms = ShadowPredictor.registeredArms()
        let baseline = arms.first { $0.id == "baseline" }!
        let series = [55.0, 60, 65, 70]
        // P25 D-04/D-05: no arm predicts .niggleSeverity in v1 (returns nil by design); exclude it.
        for outcome in ShadowPredictor.Outcome.allCases where outcome != .niggleSeverity {
            // Baseline ignores context; equals baselinePrediction for any phase.
            for phase in [CyclePhase.unknown, .lateLuteal, .earlyFollicular] {
                let armValue = baseline.predict(outcome, series, cycleContext(phase: phase))
                XCTAssertEqual(armValue ?? .nan, ShadowPredictor.baselinePrediction(series: series), accuracy: 0.0)
            }
        }
    }

    func test_cycleAwareArm_equalsCycleAwarePrediction_byteIdentical() {
        let arms = ShadowPredictor.registeredArms()
        let cycleAware = arms.first { $0.id == "cycleAware" }!
        let series = [60.0, 62, 64]
        // P25 D-04/D-05: no arm predicts .niggleSeverity in v1 (returns nil by design); exclude it.
        for outcome in ShadowPredictor.Outcome.allCases where outcome != .niggleSeverity {
            for phase in [CyclePhase.unknown, .lateLuteal, .earlyLuteal, .lateFollicular, .ovulatory] {
                let ctx = cycleContext(phase: phase)
                let armValue = cycleAware.predict(outcome, series, ctx)
                let expected = ShadowPredictor.cycleAwarePrediction(series: series, context: ctx, outcome: outcome)
                XCTAssertEqual(armValue ?? .nan, expected, accuracy: 0.0)
            }
        }
    }

    func test_cycleAwareArm_collapsesToBaseline_forUnknownPhase() {
        let cycleAware = ShadowPredictor.registeredArms().first { $0.id == "cycleAware" }!
        let series = [50.0, 55, 60]
        let base = ShadowPredictor.baselinePrediction(series: series)
        // P25 D-04/D-05: no arm predicts .niggleSeverity in v1 (returns nil by design); exclude it.
        for outcome in ShadowPredictor.Outcome.allCases where outcome != .niggleSeverity {
            let armValue = cycleAware.predict(outcome, series, cycleContext(phase: .unknown))
            XCTAssertEqual(armValue ?? .nan, base, accuracy: 0.0)
        }
    }
}
