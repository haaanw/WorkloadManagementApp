import XCTest
@testable import workload_management

/// v1.7.2 codebase audit — the pure halves of the chart/date findings (L1, L2, L3).
///
/// The chart changes themselves are SwiftUI view code and are verified by eye; the two pieces
/// with a right answer are pinned here.
final class ChartAxisAndStalenessTests: XCTestCase {

    // MARK: - L1 / L2: axis ticks

    /// Swift Charts' automatic date axis picks a stride from the plot width rather than the
    /// data's span, so a dense 28-day series drew "AUG 4" three times running.
    func testDayStrideKeepsLabelsUnderTheCeiling() {
        for span in 1...400 {
            let stride = ChartAxisTicks.dayStride(spanningDays: span)
            XCTAssertGreaterThanOrEqual(stride, 1)
            let labels = Int((Double(span) / Double(stride)).rounded(.up))
            XCTAssertLessThanOrEqual(
                labels, 5,
                "A \(span)-day span at stride \(stride) draws \(labels) labels"
            )
        }
    }

    func testDayStrideIsDailyForShortSpans() {
        XCTAssertEqual(ChartAxisTicks.dayStride(spanningDays: 1), 1)
        XCTAssertEqual(ChartAxisTicks.dayStride(spanningDays: 5), 1)
        XCTAssertEqual(ChartAxisTicks.dayStride(spanningDays: 7), 2)
        XCTAssertEqual(ChartAxisTicks.dayStride(spanningDays: 28), 6)
        XCTAssertEqual(ChartAxisTicks.dayStride(spanningDays: 90), 18)
    }

    /// Zero and negative spans come from an empty series. The stride must stay usable rather
    /// than reach `.stride(by: .day, count: 0)`, which is not a valid axis.
    func testDayStrideSurvivesAnEmptySeries() {
        XCTAssertEqual(ChartAxisTicks.dayStride(spanningDays: 0), 1)
        XCTAssertEqual(ChartAxisTicks.dayStride(spanningDays: -3), 1)
    }

    func testYAxisAsksForFewStops() {
        XCTAssertGreaterThanOrEqual(ChartAxisTicks.yAxisStops, 2)
        XCTAssertLessThanOrEqual(
            ChartAxisTicks.yAxisStops, 5,
            "A dense y-axis is what makes the %.0f formatter emit two identical labels (audit L2)"
        )
    }

    // MARK: - L3: staleness counts calendar days

    /// A reading taken at 22:00 yesterday and read at 09:00 today is 11 hours old. Counting
    /// elapsed 24-hour blocks reported 0 — a badge reading "0D" for data the athlete would
    /// call yesterday's.
    func testDaysAgoCountsCalendarDaysNotTwentyFourHourBlocks() throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let lateYesterday = try XCTUnwrap(
            calendar.date(byAdding: .hour, value: -2, to: today)
        )

        let staleness = HealthKitStaleness(
            lastHRVDate: lateYesterday, lastSleepDate: nil, lastRHRDate: nil
        )

        // Only reported once the reading is stale at all, which the 24h rule still decides.
        if staleness.isHRVStale {
            XCTAssertEqual(staleness.daysAgo(lateYesterday), 1)
        }
    }

    func testDaysAgoOnAThreeDayOldReading() throws {
        let calendar = Calendar.current
        let threeDaysAgo = try XCTUnwrap(
            calendar.date(byAdding: .day, value: -3, to: calendar.startOfDay(for: .now))
        )
        let staleness = HealthKitStaleness(
            lastHRVDate: threeDaysAgo, lastSleepDate: nil, lastRHRDate: nil
        )
        XCTAssertTrue(staleness.isHRVStale)
        XCTAssertEqual(staleness.daysAgo(threeDaysAgo), 3)
    }

    /// Fresh data has no staleness to report; nil means "no badge", not "zero days".
    func testFreshReadingReportsNoDaysAgo() {
        let staleness = HealthKitStaleness(
            lastHRVDate: .now, lastSleepDate: nil, lastRHRDate: nil
        )
        XCTAssertFalse(staleness.isHRVStale)
        XCTAssertNil(staleness.daysAgo(.now))
    }

    func testMissingReadingIsStale() {
        let staleness = HealthKitStaleness(
            lastHRVDate: nil, lastSleepDate: nil, lastRHRDate: nil
        )
        XCTAssertTrue(staleness.isHRVStale)
        XCTAssertTrue(staleness.hasAnyStaleness)
        XCTAssertNil(staleness.daysAgo(nil))
    }

    // MARK: - M7: a "latest" reading is bounded

    /// Body temperature and VO2 max had no date bound, so a reading from a device the athlete
    /// stopped wearing months ago was presented as current.
    func testFreshnessWindowsAreBoundedAndOrdered() {
        XCTAssertGreaterThan(HealthKitService.bodyTempFreshnessDays, 0)
        XCTAssertLessThanOrEqual(
            HealthKitService.bodyTempFreshnessDays, 14,
            "Sleeping wrist temperature is written nightly — a long window lets a dead device answer"
        )
        XCTAssertGreaterThan(
            HealthKitService.vo2MaxFreshnessDays, HealthKitService.bodyTempFreshnessDays,
            "Cardiorespiratory fitness moves over months; temperature does not"
        )
        XCTAssertLessThanOrEqual(HealthKitService.vo2MaxFreshnessDays, 180)
    }
}
