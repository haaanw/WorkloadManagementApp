import XCTest
@testable import workload_management

/// The checkpoint-plus-replayed-tail baseline: it must behave EXACTLY like recomputing from
/// scratch, while doing a fraction of the work — and it must survive the things that break a
/// naive saved fold (missed days, late arrivals, re-runs).
final class BaselineCheckpointTests: XCTestCase {

    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private var now: Date {
        DateComponents(
            calendar: calendar, timeZone: calendar.timeZone,
            year: 2026, month: 8, day: 7, hour: 9
        ).date!
    }

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now))!
    }

    /// A deterministic, mildly varying series so the MAD buffer and Welford terms are exercised.
    private func series(_ offsets: [Int]) -> [BaselineCheckpoint.DayValue] {
        offsets.map { offset in
            BaselineCheckpoint.DayValue(
                day: day(offset),
                value: 50 + Double((abs(offset) % 7)) - 3
            )
        }
    }

    private func fullReplay(_ days: [BaselineCheckpoint.DayValue]) -> BaselineEngine.SignalState {
        var state = BaselineEngine.SignalState()
        for entry in days.sorted(by: { $0.day < $1.day }) {
            state = BaselineEngine.step(
                state: state,
                observation: entry.value,
                config: .hrv,
                bucketedDate: calendar.startOfDay(for: entry.day)
            )
        }
        return state
    }

    // MARK: - The property that makes the whole design safe

    func test_checkpointPlusTail_equalsFullReplay() {
        // The equivalence that lets us trust a saved summary at all: sealing days into a
        // checkpoint and replaying the rest must land exactly where walking every day lands.
        let days = series(Array(-60...0))
        let outcome = BaselineCheckpoint.advance(
            stored: BaselineCheckpoint.Stored(),
            days: days,
            config: .hrv,
            now: now,
            calendar: calendar
        )
        let expected = fullReplay(days)
        XCTAssertEqual(outcome.workingState.mu ?? .nan, expected.mu ?? .nan, accuracy: 1e-9)
        XCTAssertEqual(outcome.workingState.count, expected.count)
        XCTAssertEqual(outcome.workingState.madBuffer.count, expected.madBuffer.count)
    }

    func test_resumingFromAStoredCheckpoint_equalsFullReplay() {
        // Run once to build a checkpoint, then resume from it the next day.
        let firstDays = series(Array(-60...(-1)))
        let first = BaselineCheckpoint.advance(
            stored: BaselineCheckpoint.Stored(), days: firstDays,
            config: .hrv, now: day(-1), calendar: calendar
        )
        let allDays = series(Array(-60...0))
        let second = BaselineCheckpoint.advance(
            stored: first.checkpoint, days: allDays,
            config: .hrv, now: now, calendar: calendar
        )
        let expected = fullReplay(allDays)
        XCTAssertFalse(second.didRebuild, "a valid checkpoint must be reused, not discarded")
        XCTAssertEqual(second.workingState.mu ?? .nan, expected.mu ?? .nan, accuracy: 1e-9)
        XCTAssertEqual(second.workingState.count, expected.count)
    }

    // MARK: - The failure modes a naive saved fold cannot survive

    func test_missingTwoDays_thenOpening_foldsBothInOrder() {
        // HAN's case: the app is not opened for two days. Those days sit in the replay tail
        // and are folded in date order — there is no catch-up path because nothing was
        // skipped in the first place.
        let throughDayMinus3 = series(Array(-60...(-3)))
        let checkpoint = BaselineCheckpoint.advance(
            stored: BaselineCheckpoint.Stored(), days: throughDayMinus3,
            config: .hrv, now: day(-3), calendar: calendar
        ).checkpoint

        let allDays = series(Array(-60...0))
        let resumed = BaselineCheckpoint.advance(
            stored: checkpoint, days: allDays, config: .hrv, now: now, calendar: calendar
        )
        let expected = fullReplay(allDays)
        XCTAssertEqual(resumed.workingState.count, expected.count, "every missed day is folded")
        XCTAssertEqual(resumed.workingState.mu ?? .nan, expected.mu ?? .nan, accuracy: 1e-9)
    }

    func test_lateArrivalInsideTheHorizon_isAbsorbed() {
        // A day that syncs late but lands inside the replay window needs no special handling:
        // the tail is rebuilt from raw values every run.
        let withoutLateDay = series([-60, -50, -40, -30, -20, -10, -5, -3, -1, 0])
        let checkpoint = BaselineCheckpoint.advance(
            stored: BaselineCheckpoint.Stored(), days: withoutLateDay,
            config: .hrv, now: now, calendar: calendar
        ).checkpoint

        var withLateDay = withoutLateDay
        withLateDay.append(BaselineCheckpoint.DayValue(day: day(-2), value: 61))
        let resumed = BaselineCheckpoint.advance(
            stored: checkpoint, days: withLateDay, config: .hrv, now: now, calendar: calendar
        )
        XCTAssertEqual(
            resumed.workingState.count,
            fullReplay(withLateDay).count,
            "a late day inside the horizon must be picked up"
        )
    }

    func test_dayAppearingInsideTheSealedWindow_forcesARebuild() {
        // The one case a saved summary cannot absorb quietly — so it is detected and the
        // checkpoint is thrown away rather than trusted.
        let days = series(Array(-60...0).filter { $0 != -40 })
        let checkpoint = BaselineCheckpoint.advance(
            stored: BaselineCheckpoint.Stored(), days: days,
            config: .hrv, now: now, calendar: calendar
        ).checkpoint
        XCTAssertGreaterThan(checkpoint.sealedDayCount, 0)

        var backfilled = days
        backfilled.append(BaselineCheckpoint.DayValue(day: day(-40), value: 52))
        let resumed = BaselineCheckpoint.advance(
            stored: checkpoint, days: backfilled, config: .hrv, now: now, calendar: calendar
        )
        XCTAssertTrue(resumed.didRebuild, "a stale summary must be rebuilt, not trusted")
        XCTAssertEqual(
            resumed.workingState.mu ?? .nan,
            fullReplay(backfilled).mu ?? .nan,
            accuracy: 1e-9
        )
    }

    func test_schemaVersionBump_forcesARebuild() {
        let days = series(Array(-60...0))
        var checkpoint = BaselineCheckpoint.advance(
            stored: BaselineCheckpoint.Stored(), days: days,
            config: .hrv, now: now, calendar: calendar
        ).checkpoint
        checkpoint.schemaVersion = BaselineCheckpoint.schemaVersion - 1

        let resumed = BaselineCheckpoint.advance(
            stored: checkpoint, days: days, config: .hrv, now: now, calendar: calendar
        )
        XCTAssertTrue(resumed.didRebuild)
    }

    // MARK: - Re-running must never double-count

    func test_repeatedRunsOnTheSameDay_areIdempotent() {
        let days = series(Array(-60...0))
        let first = BaselineCheckpoint.advance(
            stored: BaselineCheckpoint.Stored(), days: days,
            config: .hrv, now: now, calendar: calendar
        )
        let second = BaselineCheckpoint.advance(
            stored: first.checkpoint, days: days, config: .hrv, now: now, calendar: calendar
        )
        XCTAssertEqual(first.workingState.count, second.workingState.count)
        XCTAssertEqual(first.workingState.mu ?? .nan, second.workingState.mu ?? .nan, accuracy: 1e-12)
        XCTAssertEqual(first.checkpoint.sealedDayCount, second.checkpoint.sealedDayCount)
    }

    // MARK: - Sealing behaviour

    func test_recentDaysAreNeverSealed() {
        // Everything inside the horizon must stay replayable, or late data could not land.
        let days = series(Array(-60...0))
        let outcome = BaselineCheckpoint.advance(
            stored: BaselineCheckpoint.Stored(), days: days,
            config: .hrv, now: now, calendar: calendar
        )
        let sealedThrough = try? XCTUnwrap(outcome.checkpoint.sealedThroughDay)
        let boundary = calendar.date(byAdding: .day, value: -BaselineCheckpoint.sealHorizonDays,
                                     to: calendar.startOfDay(for: now))!
        XCTAssertLessThanOrEqual(sealedThrough ?? boundary, boundary)
    }

    func test_shortHistory_sealsNothingAndStillScores() {
        // A brand-new athlete: everything is inside the horizon, so nothing seals yet and the
        // whole series is replayed.
        let days = series([-3, -2, -1, 0])
        let outcome = BaselineCheckpoint.advance(
            stored: BaselineCheckpoint.Stored(), days: days,
            config: .hrv, now: now, calendar: calendar
        )
        XCTAssertNil(outcome.checkpoint.sealedThroughDay)
        XCTAssertEqual(outcome.workingState.count, 4)
    }

    func test_confidenceGrowsBeyondTheReplayWindow() {
        // The concrete reason to persist at all: BaselineEngine's confidence ramps toward 60
        // days, so a fetch-window-bounded fold could never express a settled baseline.
        let longHistory = series(Array(-120...0))
        let outcome = BaselineCheckpoint.advance(
            stored: BaselineCheckpoint.Stored(), days: longHistory,
            config: .hrv, now: now, calendar: calendar
        )
        let shortHistory = series(Array(-20...0))
        let shortOutcome = BaselineCheckpoint.advance(
            stored: BaselineCheckpoint.Stored(), days: shortHistory,
            config: .hrv, now: now, calendar: calendar
        )
        XCTAssertGreaterThan(
            BaselineEngine.confidence(state: outcome.workingState, daysSinceLastBucket: 0),
            BaselineEngine.confidence(state: shortOutcome.workingState, daysSinceLastBucket: 0)
        )
    }
}
