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
}
