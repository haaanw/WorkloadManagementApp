import XCTest
@testable import workload_management

/// v1.7.3 · UAT round 1 · U9 — the daily resting-heart-rate series behind Today's RHR cell.
///
/// Two claims: the reduction is ALL-DAY (no morning filter — the difference from HRV that the
/// 2026-08-05 panel insisted on), and the baseline statistics are the same ones HRV reports,
/// because they now come from one implementation.
final class RHRDailyStatsTests: XCTestCase {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private let now = Date(timeIntervalSince1970: 1_757_500_000)

    private func at(day offset: Int, hour: Int) -> Date {
        let start = calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: now))!
        return calendar.date(byAdding: .hour, value: hour, to: start)!
    }

    private func daily(_ samples: [(date: Date, value: Double)], days: Int = 14) -> [RHRDailyStats.DailyValue] {
        RHRDailyStats.dailyValues(samples: samples, days: days, now: now, calendar: calendar)
    }

    // MARK: - The reduction

    /// The whole reason this type exists rather than reusing `HRVDailyStats`: Apple writes RHR
    /// as a daily aggregate it refines through the day, so an hour filter would keep or drop a
    /// day's value essentially at random. An afternoon sample is a real reading here.
    func test_afternoonSampleCounts_unlikeHRV() {
        let values = daily([(date: at(day: 1, hour: 16), value: 52)])

        XCTAssertEqual(values.count, 1, "an afternoon RHR sample is the day's reading, not a discard")
        XCTAssertEqual(values.first?.value, 52)
    }

    func test_severalSamplesOnOneDay_collapseToTheirMedian() {
        let values = daily([
            (date: at(day: 1, hour: 3), value: 48),
            (date: at(day: 1, hour: 9), value: 52),
            (date: at(day: 1, hour: 20), value: 62)
        ])

        XCTAssertEqual(values.count, 1)
        XCTAssertEqual(values.first?.value ?? 0, 52, accuracy: 0.001)
    }

    func test_daysWithNoSample_areGapsNotCarriedForward() {
        let values = daily([
            (date: at(day: 5, hour: 7), value: 50),
            (date: at(day: 1, hour: 7), value: 56)
        ])

        XCTAssertEqual(values.count, 2, "the three empty days between are gaps, never imputed")
        XCTAssertEqual(values.map(\.value), [50, 56])
    }

    func test_zeroDayWindow_isEmpty() {
        XCTAssertTrue(daily([(date: at(day: 0, hour: 7), value: 50)], days: 0).isEmpty)
    }

    // MARK: - Baseline statistics

    /// The rule that makes the deviation mean anything: the baseline never contains the day it
    /// is being compared against. At n = 1 the old shape reported a permanent, false 0%.
    func test_baseline_excludesTheDayItIsComparedAgainst() {
        let samples = (0..<8).map { (date: at(day: $0, hour: 7), value: $0 == 0 ? 70.0 : 50.0) }
        let values = daily(samples)

        let baseline = try! XCTUnwrap(RHRDailyStats.baseline(values, calendar: calendar))
        XCTAssertEqual(baseline, 50, accuracy: 0.001, "today's 70 must not pull its own baseline")

        let deviation = try! XCTUnwrap(RHRDailyStats.deviationPercent(values, calendar: calendar))
        XCTAssertEqual(deviation, 40, accuracy: 0.001, "70 against a 50 baseline is +40%")
    }

    func test_baseline_isNilBelowTheMinimumPriorDays() {
        let values = daily([
            (date: at(day: 1, hour: 7), value: 50),
            (date: at(day: 0, hour: 7), value: 52)
        ])

        XCTAssertNil(RHRDailyStats.baseline(values, calendar: calendar))
        XCTAssertNil(RHRDailyStats.standardDeviation(values, calendar: calendar))
        XCTAssertNil(RHRDailyStats.deviationPercent(values, calendar: calendar))
    }

    /// One implementation of "my normal" across the two signals. If these ever diverge, a screen
    /// and the score one tap away are telling the athlete different things about the same week.
    func test_statistics_areTheSameOnesHRVReports() {
        let dayValues = (0..<8).map {
            DailySignalStats.DailyValue(date: at(day: $0, hour: 7), value: Double(50 + $0))
        }.reversed().map { $0 }

        XCTAssertEqual(
            RHRDailyStats.baseline(dayValues, calendar: calendar),
            HRVDailyStats.baseline(dayValues, calendar: calendar)
        )
        XCTAssertEqual(
            RHRDailyStats.standardDeviation(dayValues, calendar: calendar),
            HRVDailyStats.standardDeviation(dayValues, calendar: calendar)
        )
        XCTAssertEqual(
            RHRDailyStats.deviationPercent(dayValues, calendar: calendar),
            HRVDailyStats.deviationPercent(dayValues, calendar: calendar)
        )
    }

    // MARK: - Availability

    /// There is no `noMorningSamples` case, and its absence is the point: with no window filter,
    /// a sample that exists always lands on a day.
    func test_availability_reportsWhyThereIsNoNumber() {
        XCTAssertEqual(RHRDailyStats.availability(daily: [], calendar: calendar), .noSamples)

        let two = daily([
            (date: at(day: 1, hour: 7), value: 50),
            (date: at(day: 0, hour: 7), value: 52)
        ])
        XCTAssertEqual(RHRDailyStats.availability(daily: two, calendar: calendar), .building(days: 2))

        let eight = daily((0..<8).map { (date: at(day: $0, hour: 7), value: 50.0) })
        XCTAssertEqual(RHRDailyStats.availability(daily: eight, calendar: calendar), .ready)
    }
}
