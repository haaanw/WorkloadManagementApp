import XCTest
@testable import workload_management

final class RecoveryScoreEngineTests: XCTestCase {

    // MARK: - No data

    func test_noData_returnsNeutralScore() {
        let input = RecoveryScoreEngine.RecoveryInput(
            hrvSDNN: nil,
            restingHR: nil,
            sleepDurationMinutes: nil,
            wellnessScore: nil,
            hrvBaseline: nil,
            restingHRBaseline: nil
        )
        let result = RecoveryScoreEngine.compute(input: input)
        XCTAssertEqual(result.score, 50)
        XCTAssertEqual(result.zone, .yellow)
        XCTAssertNil(result.hrvContribution)
        XCTAssertNil(result.rhrContribution)
        XCTAssertNil(result.sleepContribution)
        XCTAssertNil(result.wellnessContribution)
    }

    // MARK: - Score clamping

    func test_score_isClamped_0to100() {
        let input = RecoveryScoreEngine.RecoveryInput(
            hrvSDNN: 35,
            restingHR: 90,
            sleepDurationMinutes: 180,
            wellnessScore: 5,
            hrvBaseline: 50,
            restingHRBaseline: 55
        )
        let result = RecoveryScoreEngine.compute(input: input)
        XCTAssertGreaterThanOrEqual(result.score, 0)
        XCTAssertLessThanOrEqual(result.score, 100)
    }

    func test_perfectInputs_highScore() {
        let input = RecoveryScoreEngine.RecoveryInput(
            hrvSDNN: 70,
            restingHR: 45,
            sleepDurationMinutes: 540,
            wellnessScore: 95,
            hrvBaseline: 50,
            restingHRBaseline: 58
        )
        let result = RecoveryScoreEngine.compute(input: input)
        XCTAssertGreaterThan(result.score, 80)
        XCTAssertEqual(result.zone, .green)
    }

    // MARK: - Weight redistribution

    func test_missingHRV_weightRedistributed() {
        let input = RecoveryScoreEngine.RecoveryInput(
            hrvSDNN: nil,
            restingHR: nil,
            sleepDurationMinutes: 420,
            wellnessScore: 80,
            hrvBaseline: nil,
            restingHRBaseline: nil
        )
        let result = RecoveryScoreEngine.compute(input: input)
        XCTAssertNil(result.hrvContribution)
        XCTAssertNil(result.rhrContribution)
        XCTAssertNotNil(result.sleepContribution)
        XCTAssertNotNil(result.wellnessContribution)
        XCTAssertGreaterThan(result.score, 50)
    }

    func test_wellnessOnly_scoreEqualsWellness() {
        let input = RecoveryScoreEngine.RecoveryInput(
            hrvSDNN: nil,
            restingHR: nil,
            sleepDurationMinutes: nil,
            wellnessScore: 70,
            hrvBaseline: nil,
            restingHRBaseline: nil
        )
        let result = RecoveryScoreEngine.compute(input: input)
        XCTAssertEqual(result.score, 70, accuracy: 1.0)
    }

    // MARK: - Sleep scoring

    func test_sevenHourSleep_scoreAround70() {
        let input = RecoveryScoreEngine.RecoveryInput(
            hrvSDNN: nil,
            restingHR: nil,
            sleepDurationMinutes: 420,
            wellnessScore: nil,
            hrvBaseline: nil,
            restingHRBaseline: nil
        )
        let result = RecoveryScoreEngine.compute(input: input)
        XCTAssertEqual(result.score, 70, accuracy: 5.0)
    }

    func test_shortSleep_lowScore() {
        let input = RecoveryScoreEngine.RecoveryInput(
            hrvSDNN: nil,
            restingHR: nil,
            sleepDurationMinutes: 270, // 4.5h
            wellnessScore: nil,
            hrvBaseline: nil,
            restingHRBaseline: nil
        )
        let result = RecoveryScoreEngine.compute(input: input)
        XCTAssertLessThan(result.score, 20)
        XCTAssertEqual(result.zone, .red)
    }

    // MARK: - Zone classification

    func test_highScore_greenZone() {
        let input = RecoveryScoreEngine.RecoveryInput(
            hrvSDNN: nil, restingHR: nil, sleepDurationMinutes: nil,
            wellnessScore: 85, hrvBaseline: nil, restingHRBaseline: nil
        )
        XCTAssertEqual(RecoveryScoreEngine.compute(input: input).zone, .green)
    }

    func test_midScore_yellowZone() {
        let input = RecoveryScoreEngine.RecoveryInput(
            hrvSDNN: nil, restingHR: nil, sleepDurationMinutes: nil,
            wellnessScore: 50, hrvBaseline: nil, restingHRBaseline: nil
        )
        XCTAssertEqual(RecoveryScoreEngine.compute(input: input).zone, .yellow)
    }

    func test_lowScore_redZone() {
        let input = RecoveryScoreEngine.RecoveryInput(
            hrvSDNN: nil, restingHR: nil, sleepDurationMinutes: nil,
            wellnessScore: 15, hrvBaseline: nil, restingHRBaseline: nil
        )
        XCTAssertEqual(RecoveryScoreEngine.compute(input: input).zone, .red)
    }

    // MARK: - Baseline computation

    func test_baseline_isAverageOf7Values() {
        let values = [40.0, 45.0, 50.0, 55.0, 60.0, 65.0, 70.0]
        let baseline = RecoveryScoreEngine.computeBaseline(values: values)
        XCTAssertEqual(baseline, (40 + 45 + 50 + 55 + 60 + 65 + 70) / 7)
    }

    func test_baseline_emptyArray_isNil() {
        XCTAssertNil(RecoveryScoreEngine.computeBaseline(values: []))
    }

    func test_baseline_usesLast7() {
        let values = [10.0, 10.0, 10.0, 10.0, 60.0, 60.0, 60.0, 60.0, 60.0, 60.0, 60.0]
        let baseline = RecoveryScoreEngine.computeBaseline(values: values)
        XCTAssertEqual(baseline, 60)
    }

    // MARK: - Same-Phase Bucket Mapping (D-01)

    func test_bucket_follicularPhasesMapToFollicular() {
        XCTAssertEqual(RecoveryScoreEngine.bucket(for: .earlyFollicular), .follicular)
        XCTAssertEqual(RecoveryScoreEngine.bucket(for: .lateFollicular), .follicular)
        XCTAssertEqual(RecoveryScoreEngine.bucket(for: .ovulatory), .follicular)
    }

    func test_bucket_lutealPhasesMapToLuteal() {
        XCTAssertEqual(RecoveryScoreEngine.bucket(for: .earlyLuteal), .luteal)
        XCTAssertEqual(RecoveryScoreEngine.bucket(for: .lateLuteal), .luteal)
    }

    func test_bucket_unknownMapsToNil() {
        XCTAssertNil(RecoveryScoreEngine.bucket(for: .unknown))
    }

    // MARK: - Same-Phase Baseline (D-02, D-03)

    func test_samePhaseBaseline_fourReadings_returnsEqualWeightMean() {
        let baseline = RecoveryScoreEngine.samePhaseBaseline(readings: [34, 36, 35, 35])
        XCTAssertNotNil(baseline)
        XCTAssertEqual(baseline!, 35.0, accuracy: 0.0001)
    }

    func test_samePhaseBaseline_threeReadings_returnsNil() {
        XCTAssertNil(RecoveryScoreEngine.samePhaseBaseline(readings: [34, 36, 35]))
    }

    func test_samePhaseBaseline_emptyArray_returnsNil() {
        XCTAssertNil(RecoveryScoreEngine.samePhaseBaseline(readings: []))
    }

    func test_samePhaseBaseline_fourReadingBoundary_isInclusive() {
        // count == 4 qualifies; count == 3 does not
        XCTAssertNotNil(RecoveryScoreEngine.samePhaseBaseline(readings: [40, 40, 40, 40]))
        XCTAssertNil(RecoveryScoreEngine.samePhaseBaseline(readings: [40, 40, 40]))
    }

    func test_samePhaseBaseline_equalWeight_noRecencyDecay() {
        // Equal-weight mean: later readings are not weighted more heavily.
        // [30, 30, 30, 50] -> plain mean 35, NOT a recency-weighted value > 35.
        let baseline = RecoveryScoreEngine.samePhaseBaseline(readings: [30, 30, 30, 50])
        XCTAssertEqual(baseline!, 35.0, accuracy: 0.0001)
    }

    // MARK: - Same-Phase Baseline Selection in compute() (D-06, D-07, scope locks)

    /// Identical-behavior regression: when the new same-phase fields are nil,
    /// compute() must produce byte-identical results to an input built with the
    /// original (pre-change) initializer arguments.
    func test_samePhaseNil_identicalToOriginalBehavior() {
        // Several representative inputs exercising HRV, RHR, sleep, wellness, trend.
        let cases: [(Double?, Double?, Double?, Double?, Double?, Double?, [Double])] = [
            (52, 50, 450, 80, 50, 55, [60, 62, 65]),
            (40, 60, 300, 30, 50, 55, [70, 60, 50]),
            (nil, 58, 480, nil, nil, 60, []),
            (55, nil, nil, 75, 50, nil, [50, 50, 50])
        ]
        for c in cases {
            let withSamePhaseNil = RecoveryScoreEngine.RecoveryInput(
                hrvSDNN: c.0, restingHR: c.1, sleepDurationMinutes: c.2,
                wellnessScore: c.3, hrvBaseline: c.4, restingHRBaseline: c.5,
                recentScores: c.6,
                samePhaseHRVBaseline: nil, samePhaseRestingHRBaseline: nil
            )
            // Original-initializer equivalent (no same-phase args).
            let original = RecoveryScoreEngine.RecoveryInput(
                hrvSDNN: c.0, restingHR: c.1, sleepDurationMinutes: c.2,
                wellnessScore: c.3, hrvBaseline: c.4, restingHRBaseline: c.5,
                recentScores: c.6
            )
            let a = RecoveryScoreEngine.compute(input: withSamePhaseNil)
            let b = RecoveryScoreEngine.compute(input: original)
            XCTAssertEqual(a.score, b.score, accuracy: 0.0000001)
            XCTAssertEqual(a.baseScore, b.baseScore, accuracy: 0.0000001)
            XCTAssertEqual(a.zone, b.zone)
            XCTAssertEqual(a.hrvContribution, b.hrvContribution)
            XCTAssertEqual(a.rhrContribution, b.rhrContribution)
            XCTAssertEqual(a.sleepContribution, b.sleepContribution)
            XCTAssertEqual(a.wellnessContribution, b.wellnessContribution)
            XCTAssertEqual(a.trendModifier, b.trendModifier, accuracy: 0.0000001)
        }
    }

    /// Worked example 5: consistent late-luteal HRV (35ms) read against a luteal
    /// same-phase baseline (~35) scores NORMAL, whereas the same 35ms against the
    /// male-normative 7-day baseline (42) reads materially lower.
    func test_workedExample5_samePhaseHRV_scoresNormalNotDecline() {
        let samePhase = RecoveryScoreEngine.RecoveryInput(
            hrvSDNN: 35, hrvBaseline: 42,
            samePhaseHRVBaseline: 35
        )
        let sevenDayOnly = RecoveryScoreEngine.RecoveryInput(
            hrvSDNN: 35, hrvBaseline: 42
        )
        let withSamePhase = RecoveryScoreEngine.compute(input: samePhase)
        let without = RecoveryScoreEngine.compute(input: sevenDayOnly)

        XCTAssertNotNil(withSamePhase.hrvContribution)
        // Ratio 35/35 = 1.0 -> normal band. ratioToScore(1.0, higherIsBetter:true)
        // = 20 + (1.0 - 0.7) * 160 = 68.
        XCTAssertEqual(withSamePhase.hrvContribution!, 68, accuracy: 0.5)
        // Same-phase reading is materially higher (more normal) than 7-day baseline.
        XCTAssertGreaterThan(withSamePhase.hrvContribution!, without.hrvContribution!)
        XCTAssertGreaterThan(withSamePhase.score, without.score)
    }

    /// Worked example 6: a genuine luteal HRV drop (28ms) against the athlete's own
    /// luteal same-phase average (36) still depresses the HRV contribution, i.e.
    /// fatigue is still detected relative to a same-phase-normal reading.
    func test_workedExample6_genuineLutealDrop_stillDetectsFatigue() {
        let fatigued = RecoveryScoreEngine.RecoveryInput(
            hrvSDNN: 28, hrvBaseline: 36,
            samePhaseHRVBaseline: 36
        )
        let normal = RecoveryScoreEngine.RecoveryInput(
            hrvSDNN: 36, hrvBaseline: 36,
            samePhaseHRVBaseline: 36
        )
        let fatiguedResult = RecoveryScoreEngine.compute(input: fatigued)
        let normalResult = RecoveryScoreEngine.compute(input: normal)

        XCTAssertNotNil(fatiguedResult.hrvContribution)
        // 28/36 < 1 -> depressed HRV contribution vs the same-phase-normal case.
        XCTAssertLessThan(fatiguedResult.hrvContribution!, normalResult.hrvContribution!)
        XCTAssertLessThan(fatiguedResult.score, normalResult.score)
    }

    /// D-06 per-bucket fallback: same-phase for HRV, 7-day for RHR, independently.
    func test_perBucketFallback_hrvSamePhase_rhrSevenDay() {
        // HRV uses same-phase (40), RHR has no same-phase so uses 7-day (55).
        let mixed = RecoveryScoreEngine.RecoveryInput(
            hrvSDNN: 40, restingHR: 55,
            hrvBaseline: 50, restingHRBaseline: 55,
            samePhaseHRVBaseline: 40,
            samePhaseRestingHRBaseline: nil
        )
        // Reference: HRV against 7-day (50) and RHR against 7-day (55).
        let allSevenDay = RecoveryScoreEngine.RecoveryInput(
            hrvSDNN: 40, restingHR: 55,
            hrvBaseline: 50, restingHRBaseline: 55
        )
        let mixedResult = RecoveryScoreEngine.compute(input: mixed)
        let refResult = RecoveryScoreEngine.compute(input: allSevenDay)

        // HRV differs (40/40 = 1.0 same-phase vs 40/50 = 0.8 seven-day).
        XCTAssertNotNil(mixedResult.hrvContribution)
        XCTAssertGreaterThan(mixedResult.hrvContribution!, refResult.hrvContribution!)
        // RHR is identical in both (both use 7-day 55 -> ratio 1.0).
        XCTAssertEqual(mixedResult.rhrContribution!, refResult.rhrContribution!, accuracy: 0.0000001)
    }

    /// RHR same-phase selection: lower RHR vs same-phase baseline behaves like the
    /// 7-day path but against the same-phase denominator.
    func test_rhrSamePhase_usesSamePhaseDenominator() {
        // RHR 50 against same-phase 50 -> ratio 1.0 (normal), vs 50 against 7-day 60
        // -> lower RHR than baseline = better recovery (higher score).
        let samePhase = RecoveryScoreEngine.RecoveryInput(
            restingHR: 50, restingHRBaseline: 60,
            samePhaseRestingHRBaseline: 50
        )
        let sevenDay = RecoveryScoreEngine.RecoveryInput(
            restingHR: 50, restingHRBaseline: 60
        )
        let withSamePhase = RecoveryScoreEngine.compute(input: samePhase)
        let without = RecoveryScoreEngine.compute(input: sevenDay)
        XCTAssertNotNil(withSamePhase.rhrContribution)
        // 50/50 = 1.0 -> normal band. ratioToScore(1.0, higherIsBetter:false) uses
        // adjustedRatio = 2.0 - 1.0 = 1.0 -> 20 + (1.0 - 0.7) * 160 = 68.
        XCTAssertEqual(withSamePhase.rhrContribution!, 68, accuracy: 0.5)
        XCTAssertNotEqual(withSamePhase.rhrContribution!, without.rhrContribution!)
    }
}
