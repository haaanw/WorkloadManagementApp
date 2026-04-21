import XCTest
@testable import workload_management

final class ReasoningEngineTests: XCTestCase {

    private func makeResult(hrv: Double? = nil, sleep: Double? = nil) -> RecoveryScoreEngine.RecoveryResult {
        RecoveryScoreEngine.RecoveryResult(
            score: 70,
            zone: .green,
            hrvContribution: hrv,
            rhrContribution: nil,
            sleepContribution: sleep,
            wellnessContribution: nil
        )
    }

    // MARK: - HRV Factor

    func test_hrv_belowBaseline_negativeHighImpact() {
        let input = ReasoningEngine.Input(
            recoveryResult: makeResult(hrv: 80),
            workloadSnapshot: nil,
            rawHRV: 43,
            rawRHR: nil,
            hrvBaseline: 50,
            rhrBaseline: nil,
            sleepMinutes: nil,
            daysSinceRest: 0
        )
        let factors = ReasoningEngine.summarize(input: input)
        let hrv = factors.first(where: { $0.label == "Heart Rate Variability" })

        XCTAssertNotNil(hrv)
        XCTAssertEqual(hrv?.direction, .negative)
        XCTAssertTrue(hrv?.deltaText.contains("below baseline") == true)
        XCTAssertGreaterThan(hrv?.impact ?? 0, 0)
    }

    func test_hrv_aboveBaseline_positiveDirection() {
        let input = ReasoningEngine.Input(
            recoveryResult: makeResult(hrv: 90),
            workloadSnapshot: nil,
            rawHRV: 60,
            rawRHR: nil,
            hrvBaseline: 50,
            rhrBaseline: nil,
            sleepMinutes: nil,
            daysSinceRest: 0
        )
        let factors = ReasoningEngine.summarize(input: input)
        let hrv = factors.first(where: { $0.label == "Heart Rate Variability" })

        XCTAssertEqual(hrv?.direction, .positive)
        XCTAssertTrue(hrv?.deltaText.contains("above baseline") == true)
    }

    func test_hrv_withinThreshold_neutralDirection() {
        let input = ReasoningEngine.Input(
            recoveryResult: makeResult(),
            workloadSnapshot: nil,
            rawHRV: 51,
            rawRHR: nil,
            hrvBaseline: 50,
            rhrBaseline: nil,
            sleepMinutes: nil,
            daysSinceRest: 0
        )
        let factors = ReasoningEngine.summarize(input: input)
        let hrv = factors.first(where: { $0.label == "Heart Rate Variability" })

        XCTAssertEqual(hrv?.direction, .neutral)
    }

    func test_hrv_noBaseline_noFactor() {
        let input = ReasoningEngine.Input(
            recoveryResult: makeResult(),
            workloadSnapshot: nil,
            rawHRV: 50,
            rawRHR: nil,
            hrvBaseline: nil,
            rhrBaseline: nil,
            sleepMinutes: nil,
            daysSinceRest: 0
        )
        let factors = ReasoningEngine.summarize(input: input)
        XCTAssertNil(factors.first(where: { $0.label == "Heart Rate Variability" }))
    }

    // MARK: - RHR Factor

    func test_rhr_aboveBaseline_negativeDirection() {
        let input = ReasoningEngine.Input(
            recoveryResult: makeResult(),
            workloadSnapshot: nil,
            rawHRV: nil,
            rawRHR: 65,
            hrvBaseline: nil,
            rhrBaseline: 55,
            sleepMinutes: nil,
            daysSinceRest: 0
        )
        let factors = ReasoningEngine.summarize(input: input)
        let rhr = factors.first(where: { $0.label == "Resting Heart Rate" })

        XCTAssertEqual(rhr?.direction, .negative)
    }

    func test_rhr_belowBaseline_positiveDirection() {
        let input = ReasoningEngine.Input(
            recoveryResult: makeResult(),
            workloadSnapshot: nil,
            rawHRV: nil,
            rawRHR: 48,
            hrvBaseline: nil,
            rhrBaseline: 55,
            sleepMinutes: nil,
            daysSinceRest: 0
        )
        let factors = ReasoningEngine.summarize(input: input)
        let rhr = factors.first(where: { $0.label == "Resting Heart Rate" })

        XCTAssertEqual(rhr?.direction, .positive)
    }

    // MARK: - Sleep Factor

    func test_sleep_short_negativeMaxImpact() {
        let input = ReasoningEngine.Input(
            recoveryResult: makeResult(sleep: 40),
            workloadSnapshot: nil,
            rawHRV: nil,
            rawRHR: nil,
            hrvBaseline: nil,
            rhrBaseline: nil,
            sleepMinutes: 330, // 5.5h = 90 min below 7h target
            daysSinceRest: 0
        )
        let factors = ReasoningEngine.summarize(input: input)
        let sleep = factors.first(where: { $0.label == "Sleep Duration" })

        XCTAssertEqual(sleep?.direction, .negative)
        XCTAssertEqual(sleep?.impact, 1.0)
        XCTAssertTrue(sleep?.deltaText.contains("below average") == true)
    }

    func test_sleep_onTarget_neutralDirection() {
        let input = ReasoningEngine.Input(
            recoveryResult: makeResult(sleep: 70),
            workloadSnapshot: nil,
            rawHRV: nil,
            rawRHR: nil,
            hrvBaseline: nil,
            rhrBaseline: nil,
            sleepMinutes: 420,
            daysSinceRest: 0
        )
        let factors = ReasoningEngine.summarize(input: input)
        let sleep = factors.first(where: { $0.label == "Sleep Duration" })

        XCTAssertEqual(sleep?.direction, .neutral)
    }

    // MARK: - Training Streak Factor

    func test_streak_fourDays_factorProduced() {
        let input = ReasoningEngine.Input(
            recoveryResult: makeResult(),
            workloadSnapshot: nil,
            rawHRV: nil,
            rawRHR: nil,
            hrvBaseline: nil,
            rhrBaseline: nil,
            sleepMinutes: nil,
            daysSinceRest: 4
        )
        let factors = ReasoningEngine.summarize(input: input)
        let streak = factors.first(where: { $0.label == "Training Streak" })

        XCTAssertNotNil(streak)
        XCTAssertEqual(streak?.direction, .negative)
        XCTAssertTrue(streak?.deltaText.contains("4 consecutive") == true)
    }

    func test_streak_threeDays_noFactor() {
        let input = ReasoningEngine.Input(
            recoveryResult: makeResult(),
            workloadSnapshot: nil,
            rawHRV: nil,
            rawRHR: nil,
            hrvBaseline: nil,
            rhrBaseline: nil,
            sleepMinutes: nil,
            daysSinceRest: 3
        )
        let factors = ReasoningEngine.summarize(input: input)
        XCTAssertNil(factors.first(where: { $0.label == "Training Streak" }))
    }

    // MARK: - Ranking and count

    func test_factors_rankedByImpactDescending() {
        let input = ReasoningEngine.Input(
            recoveryResult: makeResult(hrv: 80, sleep: 40),
            workloadSnapshot: nil,
            rawHRV: 25, // 50% below baseline — very high impact
            rawRHR: nil,
            hrvBaseline: 50,
            rhrBaseline: nil,
            sleepMinutes: 410, // 10 min below — low impact
            daysSinceRest: 0
        )
        let factors = ReasoningEngine.summarize(input: input)

        guard factors.count >= 2 else {
            XCTFail("Expected at least 2 factors")
            return
        }
        XCTAssertGreaterThanOrEqual(factors[0].impact, factors[1].impact)
    }

    func test_factors_atMostThreeReturned() {
        let input = ReasoningEngine.Input(
            recoveryResult: makeResult(hrv: 80, sleep: 40),
            workloadSnapshot: nil,
            rawHRV: 25,
            rawRHR: 75,
            hrvBaseline: 50,
            rhrBaseline: 55,
            sleepMinutes: 330,
            daysSinceRest: 5
        )
        let factors = ReasoningEngine.summarize(input: input)
        XCTAssertLessThanOrEqual(factors.count, 3)
    }

    func test_nilInputs_emptyFactors() {
        let input = ReasoningEngine.Input(
            recoveryResult: makeResult(),
            workloadSnapshot: nil,
            rawHRV: nil,
            rawRHR: nil,
            hrvBaseline: nil,
            rhrBaseline: nil,
            sleepMinutes: nil,
            daysSinceRest: 0
        )
        let factors = ReasoningEngine.summarize(input: input)
        XCTAssertTrue(factors.isEmpty)
    }
}
