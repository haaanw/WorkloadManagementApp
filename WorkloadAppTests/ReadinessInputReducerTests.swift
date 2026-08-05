import XCTest
@testable import workload_management

/// The v1.7.1 algorithm update's input layer: what the recovery score is actually allowed to
/// see. Covers the HRV/RHR reduction split and the rule that today never enters its own
/// baseline or its own trend.
final class ReadinessInputReducerTests: XCTestCase {

    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    /// 2026-08-05 14:00 UTC — deliberately AFTER the 11:00 morning boundary, so a test that
    /// accidentally admits afternoon samples fails loudly.
    private var now: Date {
        DateComponents(
            calendar: calendar, timeZone: calendar.timeZone,
            year: 2026, month: 8, day: 5, hour: 14
        ).date!
    }

    private func date(dayOffset: Int, hour: Int) -> Date {
        let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: now))!
        return calendar.date(byAdding: .hour, value: hour, to: day)!
    }

    // MARK: - HRV: momentary, morning window only

    func test_hrv_takesMorningMedian_andIgnoresAfternoonSamples() {
        let samples: [(date: Date, value: Double)] = [
            (date(dayOffset: 0, hour: 5), 60),
            (date(dayOffset: 0, hour: 7), 50),
            (date(dayOffset: 0, hour: 13), 20)   // afternoon: not a recovery reading
        ]
        let reduced = ReadinessInputReducer.hrv(
            samples: samples, windowDays: 30, now: now, calendar: calendar
        )
        XCTAssertEqual(reduced.today, 55, "median of the two morning samples")
    }

    func test_hrv_afternoonOnlyDay_hasNoValue_ratherThanScoringAMiddaySample() {
        // The whole point of the change: the score must not treat a midday reading as
        // today's recovery HRV.
        let samples = [(date: date(dayOffset: 0, hour: 13), value: 42.0)]
        let reduced = ReadinessInputReducer.hrv(
            samples: samples, windowDays: 30, now: now, calendar: calendar
        )
        XCTAssertNil(reduced.today)
        XCTAssertTrue(reduced.priorDays.isEmpty)
    }

    // MARK: - RHR: a daily aggregate, no hour filter

    func test_rhr_acceptsAnAfternoonTimestamp_becauseAppleComputesItDaily() {
        // Apple derives RHR over rest periods and refines it through the day; its timestamp
        // does not mark a morning reading, so an hour filter would drop it at random.
        let samples = [(date: date(dayOffset: 0, hour: 16), value: 52.0)]
        let reduced = ReadinessInputReducer.rhr(
            samples: samples, windowDays: 30, now: now, calendar: calendar
        )
        XCTAssertEqual(reduced.today, 52)
    }

    func test_rhr_collapsesMultipleSamplesOnOneDayToTheirMedian() {
        let samples: [(date: Date, value: Double)] = [
            (date(dayOffset: 0, hour: 2), 50),
            (date(dayOffset: 0, hour: 9), 54),
            (date(dayOffset: 0, hour: 20), 52)
        ]
        let reduced = ReadinessInputReducer.rhr(
            samples: samples, windowDays: 30, now: now, calendar: calendar
        )
        XCTAssertEqual(reduced.today, 52)
    }

    // MARK: - Today is never part of its own baseline

    func test_priorDays_excludesToday() {
        let samples: [(date: Date, value: Double)] = [
            (date(dayOffset: -2, hour: 6), 40),
            (date(dayOffset: -1, hour: 6), 50),
            (date(dayOffset: 0, hour: 6), 90)
        ]
        let reduced = ReadinessInputReducer.hrv(
            samples: samples, windowDays: 30, now: now, calendar: calendar
        )
        XCTAssertEqual(reduced.today, 90)
        XCTAssertEqual(reduced.priorDays, [40, 50], "today must not pull the baseline it is compared against")
        XCTAssertEqual(reduced.observedDayCount, 3)
    }

    func test_priorDays_areOldestFirst() {
        let samples: [(date: Date, value: Double)] = [
            (date(dayOffset: -1, hour: 6), 50),
            (date(dayOffset: -3, hour: 6), 30),
            (date(dayOffset: -2, hour: 6), 40)
        ]
        let reduced = ReadinessInputReducer.hrv(
            samples: samples, windowDays: 30, now: now, calendar: calendar
        )
        XCTAssertEqual(reduced.priorDays, [30, 40, 50])
    }

    func test_noSamples_yieldsEmptyReduction() {
        let reduced = ReadinessInputReducer.hrv(
            samples: [], windowDays: 30, now: now, calendar: calendar
        )
        XCTAssertNil(reduced.today)
        XCTAssertTrue(reduced.priorDays.isEmpty)
        XCTAssertEqual(reduced.observedDayCount, 0)
    }

    // MARK: - Trend series

    func test_priorDayScores_dropsTodaysScore() {
        // The trend modifier is an autoregression on the engine's own output, so letting it
        // read the score it is about to replace made a same-day re-run move the number with
        // no new physiology.
        let dated: [(date: Date, score: Double)] = [
            (date(dayOffset: -2, hour: 8), 60),
            (date(dayOffset: -1, hour: 8), 65),
            (date(dayOffset: 0, hour: 8), 99)
        ]
        let scores = ReadinessInputReducer.priorDayScores(dated, now: now, calendar: calendar)
        XCTAssertEqual(scores, [60, 65])
    }

    func test_priorDayScores_sortsAscendingByDate() {
        let dated: [(date: Date, score: Double)] = [
            (date(dayOffset: -1, hour: 8), 65),
            (date(dayOffset: -3, hour: 8), 55),
            (date(dayOffset: -2, hour: 8), 60)
        ]
        let scores = ReadinessInputReducer.priorDayScores(dated, now: now, calendar: calendar)
        XCTAssertEqual(scores, [55, 60, 65])
    }

    // MARK: - Coverage reporting

    func test_recoveryResult_reportsPartialCoverageWhenASignalIsMissing() {
        let input = RecoveryScoreEngine.RecoveryInput(
            hrvSDNN: nil,               // no morning reading today
            restingHR: 52,
            sleepDurationMinutes: 430,
            wellnessScore: 70,
            hrvBaseline: 50,
            restingHRBaseline: 54,
            recentScores: []
        )
        let result = RecoveryScoreEngine.compute(input: input)
        XCTAssertNil(result.hrvContribution)
        XCTAssertEqual(result.contributingSignalCount, 3)
        XCTAssertTrue(result.hasPartialCoverage)
        XCTAssertNotNil(ReasoningEngine.coverageNote(for: result))
    }

    func test_recoveryResult_reportsNoNoteWhenAllSignalsPresent() {
        let input = RecoveryScoreEngine.RecoveryInput(
            hrvSDNN: 55,
            restingHR: 52,
            sleepDurationMinutes: 430,
            wellnessScore: 70,
            hrvBaseline: 50,
            restingHRBaseline: 54,
            recentScores: []
        )
        let result = RecoveryScoreEngine.compute(input: input)
        XCTAssertEqual(result.contributingSignalCount, 4)
        XCTAssertFalse(result.hasPartialCoverage)
        XCTAssertNil(ReasoningEngine.coverageNote(for: result))
    }
}
