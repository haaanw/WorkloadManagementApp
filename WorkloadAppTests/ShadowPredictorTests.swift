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
}
