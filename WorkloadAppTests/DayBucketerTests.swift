import XCTest
@testable import workload_management

/// Tests for the pure `DayBucketer` (Phase 26, Plan 03).
///
/// All dates are built from a fixed epoch anchor + hour/day offsets against a fixed UTC
/// gregorian calendar, so the morning-window hour math and day grouping are deterministic
/// across machines — NO `Date.now`.
final class DayBucketerTests: XCTestCase {

    // Fixed UTC gregorian calendar so `component(.hour)` / `startOfDay` are machine-stable.
    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    // Anchor: a clean UTC midnight (2021-01-01 00:00:00 UTC).
    private let anchor = Date(timeIntervalSince1970: 1_609_459_200)

    /// `anchor` + `day` days + `hour` hours.
    private func at(day: Int, hour: Int) -> Date {
        anchor.addingTimeInterval(TimeInterval(day) * 86_400 + TimeInterval(hour) * 3_600)
    }

    private func startOfDay(_ day: Int) -> Date {
        cal.startOfDay(for: at(day: day, hour: 0))
    }

    // MARK: - 1. Median of the morning window

    func testMedianWindow() {
        // Three in-window HRV samples on day 0 → median 50. A 14:00 sample of 90 is excluded.
        let samples: [(date: Date, value: Double)] = [
            (at(day: 0, hour: 6), 48),
            (at(day: 0, hour: 7), 52),
            (at(day: 0, hour: 8), 50),
            (at(day: 0, hour: 14), 90)   // afternoon — excluded
        ]
        let buckets = DayBucketer.bucketMorningWindow(
            samples: samples,
            rangeStart: startOfDay(0),
            rangeEnd: startOfDay(0),
            calendar: cal
        )
        XCTAssertEqual(buckets.count, 1)
        XCTAssertEqual(buckets[0].value, 50)
    }

    // MARK: - 2. Afternoon-only day is a GAP

    func testAfternoonOnlyIsGap() {
        let samples: [(date: Date, value: Double)] = [
            (at(day: 0, hour: 12), 70),
            (at(day: 0, hour: 18), 72)
        ]
        let buckets = DayBucketer.bucketMorningWindow(
            samples: samples,
            rangeStart: startOfDay(0),
            rangeEnd: startOfDay(0),
            calendar: cal
        )
        XCTAssertEqual(buckets.count, 1)
        XCTAssertNil(buckets[0].value, "A day whose only samples are after the morning window must be a GAP")
    }

    // MARK: - 3. No carry-forward over an empty day

    func testGapNoCarryForward() {
        // Day 0 valued, day 1 has NO samples, day 2 valued. Day 1 must be a GAP, not day-0's value.
        let samples: [(date: Date, value: Double)] = [
            (at(day: 0, hour: 7), 50),
            (at(day: 2, hour: 7), 60)
        ]
        let buckets = DayBucketer.bucketMorningWindow(
            samples: samples,
            rangeStart: startOfDay(0),
            rangeEnd: startOfDay(2),
            calendar: cal
        )
        XCTAssertEqual(buckets.count, 3)
        XCTAssertEqual(buckets[0].value, 50)
        XCTAssertNil(buckets[1].value, "Empty middle day must be a GAP — prior value not carried forward")
        XCTAssertEqual(buckets[2].value, 60)
    }

    // MARK: - 4. Stale-sample dedup (no fake-stable repeats)

    func testStaleDedup() {
        // A single sample on day 0; range spans days 0..3. Only day 0 is valued; days 1-3 are GAPs.
        let samples: [(date: Date, value: Double)] = [
            (at(day: 0, hour: 7), 55)
        ]
        let buckets = DayBucketer.bucketMorningWindow(
            samples: samples,
            rangeStart: startOfDay(0),
            rangeEnd: startOfDay(3),
            calendar: cal
        )
        XCTAssertEqual(buckets.count, 4)
        XCTAssertEqual(buckets[0].value, 55)
        XCTAssertNil(buckets[1].value)
        XCTAssertNil(buckets[2].value)
        XCTAssertNil(buckets[3].value, "A stale latest sample must NOT fake-fill later days")
    }

    // MARK: - 5. Sleep bucket (last-night aggregate)

    func testSleepBucket() {
        let samples: [(date: Date, value: Double)] = [
            (at(day: 0, hour: 7), 420)   // 7h sleep keyed to the night's end date
        ]
        let buckets = DayBucketer.bucketSleep(
            samples: samples,
            rangeStart: startOfDay(0),
            rangeEnd: startOfDay(0),
            calendar: cal
        )
        XCTAssertEqual(buckets.count, 1)
        XCTAssertEqual(buckets[0].date, startOfDay(0))
        XCTAssertEqual(buckets[0].value, 420)
    }

    // MARK: - 6. Ascending and dense over the requested span

    func testAscendingDense() {
        let samples: [(date: Date, value: Double)] = [
            (at(day: 1, hour: 7), 50)
        ]
        let buckets = DayBucketer.bucketMorningWindow(
            samples: samples,
            rangeStart: startOfDay(0),
            rangeEnd: startOfDay(4),
            calendar: cal
        )
        // One entry per calendar day, strictly ascending.
        XCTAssertEqual(buckets.count, 5)
        for i in 1..<buckets.count {
            XCTAssertLessThan(buckets[i - 1].date, buckets[i].date, "Buckets must be strictly ascending")
            let expectedDay = startOfDay(i)
            XCTAssertEqual(buckets[i].date, expectedDay, "Dense: one entry per calendar day")
        }
        // Day 1 valued, the rest GAP.
        XCTAssertNil(buckets[0].value)
        XCTAssertEqual(buckets[1].value, 50)
        XCTAssertNil(buckets[2].value)
    }

    // MARK: - 7. RHR synthetic bucket (helper shape verified via the bucketer)

    func testRhrHistoryShape() {
        // RHR uses the same `(date, value)` shape as HRV; verify the bucketer over a synthetic
        // RHR array (live HealthKit fetch needs a device). RHR is lower-is-better but the
        // bucketer is sign-agnostic: median of the morning window.
        let rhrSamples: [(date: Date, value: Double)] = [
            (at(day: 0, hour: 6), 52),
            (at(day: 0, hour: 7), 50),
            (at(day: 0, hour: 8), 54)
        ]
        let buckets = DayBucketer.bucketMorningWindow(
            samples: rhrSamples,
            rangeStart: startOfDay(0),
            rangeEnd: startOfDay(0),
            calendar: cal
        )
        XCTAssertEqual(buckets.count, 1)
        XCTAssertEqual(buckets[0].value, 52, "RHR median of [52,50,54] is 52")
    }

    // MARK: - Empty range / inverted range edges

    func testInvertedRangeEmpty() {
        let buckets = DayBucketer.bucketMorningWindow(
            samples: [],
            rangeStart: startOfDay(3),
            rangeEnd: startOfDay(0),
            calendar: cal
        )
        XCTAssertTrue(buckets.isEmpty, "rangeEnd < rangeStart yields no days")
    }

    // MARK: - W-1: day-advance / idempotency guard

    func testFoldIsIdempotentOnRepeat() {
        // Folding the same buckets twice must yield the SAME state (re-presenting folded days is a no-op).
        let buckets: [DayBucketer.BucketedDay] = [
            .init(date: startOfDay(0), value: 50),
            .init(date: startOfDay(1), value: 52),
            .init(date: startOfDay(2), value: nil),   // GAP — skipped
            .init(date: startOfDay(3), value: 55)
        ]
        let s0 = BaselineEngine.SignalState()
        let once = DayBucketer.foldBuckets(state: s0, buckets: buckets, config: .hrv, calendar: cal)
        let twice = DayBucketer.foldBuckets(state: once, buckets: buckets, config: .hrv, calendar: cal)

        XCTAssertEqual(once.lastBucketedDate, startOfDay(3))
        XCTAssertEqual(twice.lastBucketedDate, once.lastBucketedDate)
        XCTAssertEqual(twice.mu, once.mu, "Re-folding the same days must be a no-op")
        XCTAssertEqual(twice.count, once.count, "Fold count must not advance on a repeat")
    }

    func testFoldSkipsOlderDay() {
        // After advancing to day 3, presenting day 2 again must be ignored (monotonic cutoff).
        let first: [DayBucketer.BucketedDay] = [
            .init(date: startOfDay(0), value: 50),
            .init(date: startOfDay(3), value: 60)
        ]
        let s0 = BaselineEngine.SignalState()
        let advanced = DayBucketer.foldBuckets(state: s0, buckets: first, config: .hrv, calendar: cal)
        XCTAssertEqual(advanced.lastBucketedDate, startOfDay(3))

        // Re-present an OLDER day (day 2) — must be a no-op.
        let older: [DayBucketer.BucketedDay] = [
            .init(date: startOfDay(2), value: 999)
        ]
        let afterOlder = DayBucketer.foldBuckets(state: advanced, buckets: older, config: .hrv, calendar: cal)
        XCTAssertEqual(afterOlder.mu, advanced.mu, "An older day must not fold")
        XCTAssertEqual(afterOlder.lastBucketedDate, startOfDay(3))
    }

    func testFoldGapsDoNotAdvanceCutoff() {
        // A GAP day must not move lastBucketedDate.
        let buckets: [DayBucketer.BucketedDay] = [
            .init(date: startOfDay(0), value: 50),
            .init(date: startOfDay(1), value: nil),   // GAP
            .init(date: startOfDay(2), value: nil)    // GAP
        ]
        let s0 = BaselineEngine.SignalState()
        let folded = DayBucketer.foldBuckets(state: s0, buckets: buckets, config: .hrv, calendar: cal)
        XCTAssertEqual(folded.lastBucketedDate, startOfDay(0), "GAP days must not advance the cutoff")
    }
}
