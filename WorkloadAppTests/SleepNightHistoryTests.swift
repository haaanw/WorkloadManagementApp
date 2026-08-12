import XCTest
@testable import workload_management

/// `SleepSessionMath.nightSummaries` — the pure per-wake-day reduction behind
/// `fetchSleepNights` (v1.7.1 round 2, HAN UAT: charts rendered pre-fix inflated
/// snapshot rows and gaps while HealthKit held every night).
///
/// The reducer must apply the SAME rules as the live single-night fetch: dominant
/// source per window, 90-min gap clustering, 180-min night floor with
/// largest-candidate stand-in, wake-day keying, unioned stage intervals.
final class SleepNightHistoryTests: XCTestCase {

    /// Fixed calendar so the tests do not depend on the machine's timezone.
    private var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return cal
    }()

    /// `now` = 2026-08-12 12:00 local.
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 8, day: 12, hour: 12))!
    }

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0, month: Int = 8) -> Date {
        calendar.date(from: DateComponents(
            year: 2026, month: month, day: day, hour: hour, minute: minute
        ))!
    }

    private func sample(
        _ source: String = "watch",
        _ stage: SleepSessionMath.Stage,
        from: Date,
        to: Date
    ) -> SleepSessionMath.StagedSample {
        SleepSessionMath.StagedSample(
            source: source,
            stage: stage,
            interval: DateInterval(start: from, end: to)
        )
    }

    // MARK: - Wake-day keying and per-night totals

    func testTwoNightsReduceToTwoWakeDays() {
        let samples = [
            // Night ending morning of Aug 11: 23:00 (10th) → 06:00 (11th)
            sample("watch", .core, from: date(10, 23), to: date(11, 6)),
            // Night ending morning of Aug 12: 00:30 → 07:30
            sample("watch", .core, from: date(12, 0, 30), to: date(12, 7, 30))
        ]
        let nights = SleepSessionMath.nightSummaries(
            samples: samples, days: 7, now: now, calendar: calendar
        )

        XCTAssertEqual(nights.count, 2)
        XCTAssertEqual(nights[0].wakeDay, calendar.startOfDay(for: date(11, 0)))
        XCTAssertEqual(nights[0].tstMinutes, 420, accuracy: 0.01)
        XCTAssertEqual(nights[1].wakeDay, calendar.startOfDay(for: date(12, 0)))
        XCTAssertEqual(nights[1].tstMinutes, 420, accuracy: 0.01)
    }

    func testNightSpanningMidnightKeysToWakeDay() {
        let samples = [
            sample("watch", .core, from: date(9, 22), to: date(10, 5, 19))
        ]
        let nights = SleepSessionMath.nightSummaries(
            samples: samples, days: 7, now: now, calendar: calendar
        )

        XCTAssertEqual(nights.count, 1)
        XCTAssertEqual(nights[0].wakeDay, calendar.startOfDay(for: date(10, 0)),
                       "A night is keyed to the day the session ENDS (wake-day keying)")
    }

    // MARK: - Nap vs night (the H-35/v1.7.1 inversion class)

    func testAfternoonNapDoesNotDisplaceTheNight() {
        let samples = [
            // The real night: 23:30 (10th) → 07:00 (11th)
            sample("watch", .core, from: date(10, 23, 30), to: date(11, 7)),
            // A 40-min afternoon nap the same wake day — more recent than the night.
            sample("watch", .core, from: date(11, 14), to: date(11, 14, 40))
        ]
        let nights = SleepSessionMath.nightSummaries(
            samples: samples, days: 7, now: now, calendar: calendar
        )

        XCTAssertEqual(nights.count, 1)
        XCTAssertEqual(nights[0].tstMinutes, 450, accuracy: 0.01,
                       "The ≥180-min floor must pick the night, not the more recent nap")
    }

    func testNapOnlyDayFallsBackToLargestCandidate() {
        let samples = [
            sample("watch", .core, from: date(11, 14), to: date(11, 14, 40))
        ]
        let nights = SleepSessionMath.nightSummaries(
            samples: samples, days: 7, now: now, calendar: calendar
        )

        XCTAssertEqual(nights.count, 1)
        XCTAssertEqual(nights[0].tstMinutes, 40, accuracy: 0.01,
                       "With no qualifying cluster the largest candidate stands in — same rule as the live number that morning")
    }

    // MARK: - Dominant source and double-count protection

    func testDominantSourceWinsPerWindow() {
        let samples = [
            // Watch writes the night in 3 samples (dominant by count).
            sample("watch", .core, from: date(11, 0), to: date(11, 2)),
            sample("watch", .deep, from: date(11, 2), to: date(11, 4)),
            sample("watch", .core, from: date(11, 4), to: date(11, 6)),
            // iPhone writes ONE overlapping blanket sample of the same night.
            sample("iphone", .unspecified, from: date(11, 0), to: date(11, 6))
        ]
        let nights = SleepSessionMath.nightSummaries(
            samples: samples, days: 7, now: now, calendar: calendar
        )

        XCTAssertEqual(nights.count, 1)
        XCTAssertEqual(nights[0].dominantSourceID, "watch")
        XCTAssertEqual(nights[0].tstMinutes, 360, accuracy: 0.01,
                       "Mixing sources would double-count the night (the 12h45m class)")
    }

    func testOverlappingSameSourceSamplesCountOnce() {
        let samples = [
            sample("watch", .core, from: date(11, 0), to: date(11, 4)),
            // Re-binned duplicate write overlapping the first.
            sample("watch", .core, from: date(11, 3), to: date(11, 6))
        ]
        let nights = SleepSessionMath.nightSummaries(
            samples: samples, days: 7, now: now, calendar: calendar
        )

        XCTAssertEqual(nights.count, 1)
        XCTAssertEqual(nights[0].tstMinutes, 360, accuracy: 0.01,
                       "Unioned intervals: each minute counts once (F6)")
    }

    // MARK: - Stages, awake episodes, in-bed

    func testStagedNightReportsStageMinutesAndAwakeEpisodes() {
        let samples = [
            sample("watch", .deep, from: date(11, 0), to: date(11, 1, 30)),
            sample("watch", .core, from: date(11, 1, 30), to: date(11, 4)),
            sample("watch", .awake, from: date(11, 4), to: date(11, 4, 10)),
            sample("watch", .rem, from: date(11, 4, 10), to: date(11, 5, 40)),
            sample("watch", .awake, from: date(11, 5, 40), to: date(11, 5, 45)),
            sample("watch", .core, from: date(11, 5, 45), to: date(11, 7))
        ]
        let nights = SleepSessionMath.nightSummaries(
            samples: samples, days: 7, now: now, calendar: calendar
        )

        XCTAssertEqual(nights.count, 1)
        let night = nights[0]
        XCTAssertEqual(night.deepMinutes ?? 0, 90, accuracy: 0.01)
        XCTAssertEqual(night.remMinutes ?? 0, 90, accuracy: 0.01)
        XCTAssertEqual(night.coreMinutes ?? 0, 225, accuracy: 0.01)
        XCTAssertEqual(night.awakeMinutes ?? 0, 15, accuracy: 0.01)
        XCTAssertEqual(night.awakeEpisodes, 2)
        // No explicit inBed samples → span of asleep+awake session samples (7 h).
        XCTAssertEqual(night.inBedMinutes ?? 0, 420, accuracy: 0.01)
    }

    func testUnstagedSourceReportsNilStages() {
        let samples = [
            sample("whoop", .unspecified, from: date(11, 0), to: date(11, 7))
        ]
        let nights = SleepSessionMath.nightSummaries(
            samples: samples, days: 7, now: now, calendar: calendar
        )

        XCTAssertEqual(nights.count, 1)
        let night = nights[0]
        XCTAssertEqual(night.tstMinutes, 420, accuracy: 0.01)
        XCTAssertNil(night.deepMinutes, "A stage-less source reports nil, never a fabricated 0")
        XCTAssertNil(night.remMinutes)
        XCTAssertNil(night.coreMinutes)
        XCTAssertNil(night.awakeEpisodes)
    }

    // MARK: - Absence is honest

    func testDayWithNoSamplesIsAbsent() {
        let samples = [
            sample("watch", .core, from: date(10, 23), to: date(11, 6))
        ]
        let nights = SleepSessionMath.nightSummaries(
            samples: samples, days: 28, now: now, calendar: calendar
        )

        XCTAssertEqual(nights.count, 1, "Days without data are absent, never fabricated")
    }

    func testEmptyInputYieldsEmptyOutput() {
        XCTAssertTrue(SleepSessionMath.nightSummaries(
            samples: [], days: 28, now: now, calendar: calendar
        ).isEmpty)
    }
}
