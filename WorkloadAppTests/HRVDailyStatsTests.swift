import XCTest
@testable import workload_management

/// Covers the v1.7.1 HRV reduction: raw multi-sample days → one morning value per day, and
/// the baseline/deviation rules that make those numbers honest at low n.
final class HRVDailyStatsTests: XCTestCase {

    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    /// 2026-08-05 12:00 UTC — the reference "now" for every case here.
    private var now: Date {
        DateComponents(
            calendar: calendar, timeZone: calendar.timeZone,
            year: 2026, month: 8, day: 5, hour: 12
        ).date!
    }

    private func date(dayOffset: Int, hour: Int) -> Date {
        let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: now))!
        return calendar.date(byAdding: .hour, value: hour, to: day)!
    }

    // MARK: - Bucketing

    func test_dailyValues_collapsesManySamplesPerDayIntoOneMedian() {
        // The defect this fixes: a Watch writes several SDNN samples a day, so the old
        // `suffix(7)` over raw samples covered about a day and a half, not seven days.
        let samples: [(date: Date, value: Double)] = [
            (date(dayOffset: -1, hour: 3), 40),
            (date(dayOffset: -1, hour: 5), 50),
            (date(dayOffset: -1, hour: 7), 60),
            (date(dayOffset: 0, hour: 6), 55)
        ]
        let daily = HRVDailyStats.dailyValues(samples: samples, days: 7, now: now, calendar: calendar)
        XCTAssertEqual(daily.count, 2)
        XCTAssertEqual(daily[0].value, 50)   // median of 40/50/60, not their sum or last
        XCTAssertEqual(daily[1].value, 55)
    }

    func test_dailyValues_excludesAfternoonSamples() {
        // Midday HRV reflects posture, food, caffeine and stress rather than recovery
        // state, so it must not enter the readiness series.
        let samples: [(date: Date, value: Double)] = [
            (date(dayOffset: 0, hour: 6), 55),
            (date(dayOffset: 0, hour: 15), 20)
        ]
        let daily = HRVDailyStats.dailyValues(samples: samples, days: 7, now: now, calendar: calendar)
        XCTAssertEqual(daily.count, 1)
        XCTAssertEqual(daily[0].value, 55)
    }

    func test_dailyValues_afternoonOnlyDayIsAGap_notCarriedForward() {
        let samples: [(date: Date, value: Double)] = [
            (date(dayOffset: -2, hour: 6), 55),
            (date(dayOffset: -1, hour: 16), 30)
        ]
        let daily = HRVDailyStats.dailyValues(samples: samples, days: 7, now: now, calendar: calendar)
        XCTAssertEqual(daily.count, 1, "the afternoon-only day is a gap, and yesterday is not filled from the day before")
        XCTAssertEqual(daily[0].value, 55)
    }

    // MARK: - Baseline gating

    func test_baseline_isNilBelowMinimumDays() {
        let samples = (0..<2).map { i in (date: date(dayOffset: -i, hour: 6), value: 50.0) }
        let daily = HRVDailyStats.dailyValues(samples: samples, days: 7, now: now, calendar: calendar)
        XCTAssertNil(HRVDailyStats.baseline(daily, now: now, calendar: calendar))
        XCTAssertNil(HRVDailyStats.deviationPercent(daily, now: now, calendar: calendar))
    }

    func test_baseline_excludesTheLatestDay_soDeviationIsNotStructurallyZero() {
        // With the latest day inside its own baseline, a single day of history produced a
        // permanent "0% — on baseline". Prior days only.
        let samples: [(date: Date, value: Double)] = [
            (date(dayOffset: -3, hour: 6), 50),
            (date(dayOffset: -2, hour: 6), 50),
            (date(dayOffset: -1, hour: 6), 50),
            (date(dayOffset: 0, hour: 6), 60)
        ]
        let daily = HRVDailyStats.dailyValues(samples: samples, days: 7, now: now, calendar: calendar)
        let baseline = HRVDailyStats.baseline(daily, now: now, calendar: calendar)
        XCTAssertEqual(baseline, 50, "today's 60 must not pull its own baseline")
        let deviation = HRVDailyStats.deviationPercent(daily, now: now, calendar: calendar)
        XCTAssertEqual(deviation ?? 0, 20, accuracy: 0.001)
    }

    func test_singleDay_reportsNoDeviationRatherThanZeroPercent() {
        let samples = [(date: date(dayOffset: 0, hour: 6), value: 55.0)]
        let daily = HRVDailyStats.dailyValues(samples: samples, days: 7, now: now, calendar: calendar)
        XCTAssertEqual(HRVDailyStats.latest(daily)?.value, 55)
        XCTAssertNil(HRVDailyStats.deviationPercent(daily, now: now, calendar: calendar))
    }

    // MARK: - Availability

    func test_availability_distinguishesNoSamplesFromNoMorningSamples() {
        let afternoonOnly = [(date: date(dayOffset: 0, hour: 15), value: 40.0)]
        let daily = HRVDailyStats.dailyValues(samples: afternoonOnly, days: 7, now: now, calendar: calendar)
        XCTAssertEqual(
            HRVDailyStats.availability(rawSampleCount: afternoonOnly.count, daily: daily, now: now, calendar: calendar),
            .noMorningSamples,
            "an empty chart must be able to say WHY it is empty"
        )
        XCTAssertEqual(
            HRVDailyStats.availability(rawSampleCount: 0, daily: [], now: now, calendar: calendar),
            .noSamples
        )
    }

    func test_availability_buildingUntilMinimumBaselineDays() {
        let samples = (0..<2).map { i in (date: date(dayOffset: -i, hour: 6), value: 50.0) }
        let daily = HRVDailyStats.dailyValues(samples: samples, days: 7, now: now, calendar: calendar)
        XCTAssertEqual(
            HRVDailyStats.availability(rawSampleCount: samples.count, daily: daily, now: now, calendar: calendar),
            .building(days: 2)
        )
    }

    func test_availability_readyWithEnoughPriorMornings() {
        let samples = (0..<5).map { i in (date: date(dayOffset: -i, hour: 6), value: 50.0) }
        let daily = HRVDailyStats.dailyValues(samples: samples, days: 7, now: now, calendar: calendar)
        XCTAssertEqual(
            HRVDailyStats.availability(rawSampleCount: samples.count, daily: daily, now: now, calendar: calendar),
            .ready
        )
    }
}
