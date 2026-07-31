import XCTest
@testable import workload_management

final class ReasoningEngineTests: XCTestCase {

    private func makeResult(hrv: Double? = nil, sleep: Double? = nil) -> RecoveryScoreEngine.RecoveryResult {
        RecoveryScoreEngine.RecoveryResult(
            score: 70,
            baseScore: 70,
            zone: .green,
            hrvContribution: hrv,
            rhrContribution: nil,
            sleepContribution: sleep,
            wellnessContribution: nil,
            trendSlope3Day: nil,
            trendSlope7Day: nil,
            trendModifier: 0
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
            sleepMinutes: 360, // 6h = 90 min below the 7.5h target
            daysSinceRest: 0
        )
        let factors = ReasoningEngine.summarize(input: input)
        let sleep = factors.first(where: { $0.label == "Sleep Duration" })

        XCTAssertEqual(sleep?.direction, .negative)
        XCTAssertEqual(sleep?.impact, 1.0)
        // The MAGNITUDE, not just the sign: the old assertion only checked `.negative`, which
        // stayed true while the factor was still measuring against a stale 7 h reference.
        XCTAssertEqual(sleep?.deltaText, "90 min below target")
    }

    /// Pins the reference this factor measures against to the app-wide sleep target, because the
    /// Dashboard row this Factor draws navigates INTO `SleepDetailView` — which reports the same
    /// night against `RecoveryScoreEngine.sleepTargetHours`. A 435-min night used to read
    /// "15 min above average" here and sit below target one tap later.
    func test_sleep_referenceIsTheAppWideTarget() {
        func sleepFactor(minutes: Double) -> ReasoningEngine.Factor? {
            let input = ReasoningEngine.Input(
                recoveryResult: makeResult(sleep: 70),
                workloadSnapshot: nil,
                rawHRV: nil,
                rawRHR: nil,
                hrvBaseline: nil,
                rhrBaseline: nil,
                sleepMinutes: minutes,
                daysSinceRest: 0
            )
            return ReasoningEngine.summarize(input: input)
                .first(where: { $0.label == "Sleep Duration" })
        }

        // Exactly on target: zero delta, and the copy names the target rather than an "average".
        let onTarget = sleepFactor(minutes: RecoveryScoreEngine.sleepTargetHours * 60)
        XCTAssertEqual(onTarget?.direction, .neutral)
        XCTAssertEqual(onTarget?.deltaText, "0 min above target")

        // The night that exposed the half-migration: 7h15m is BELOW the 7.5 h target.
        let sevenFifteen = sleepFactor(minutes: 435)
        XCTAssertEqual(sevenFifteen?.deltaText, "15 min below target")

        // The old 7 h reference is now 30 min short — enough to tip the direction negative.
        let sevenHours = sleepFactor(minutes: 420)
        XCTAssertEqual(sevenHours?.deltaText, "30 min below target")
        XCTAssertEqual(sevenHours?.direction, .negative)
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

final class FatigueIndexEngineTests: XCTestCase {

    func test_baselineSessionsPer14Days_usesFullObservedSpan() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let sessions = makeSessions(daysAgo: [80, 70, 60, 50, 40, 30, 20, 10], from: now)

        let baseline = FatigueIndexEngine.baselineSessionsPer14Days(sessions: sessions, asOf: now)

        XCTAssertEqual(baseline ?? 0, 8.0 / 81.0 * 14.0, accuracy: 0.0001)
    }

    func test_baselineSessionsPer14Days_usesMinimumFourteenDayWindow() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let sessions = makeSessions(daysAgo: [2, 1, 0], from: now)

        let baseline = FatigueIndexEngine.baselineSessionsPer14Days(sessions: sessions, asOf: now)

        XCTAssertEqual(baseline ?? 0, 3.0, accuracy: 0.0001)
    }

    func test_baselineSessionsPer14Days_emptyHistory() {
        XCTAssertNil(FatigueIndexEngine.baselineSessionsPer14Days(sessions: []))
    }

    private func makeSessions(daysAgo: [Int], from now: Date) -> [WorkoutSession] {
        daysAgo.map { daysAgo in
            let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: now)!
            return WorkoutSession(sessionDate: date)
        }
    }
}
