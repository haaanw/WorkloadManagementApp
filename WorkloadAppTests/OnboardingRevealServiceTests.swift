import XCTest
@testable import workload_management

/// The C1/C2 contracts: the reveal computes in memory from raw samples via the same
/// reducer + engine the live pipeline uses, and the branch predicate is a DAY COUNT read
/// against `BaselineEngine.BaselineConstants` — never the confidence composite, never the
/// dark v2 estimator.
@MainActor
final class OnboardingRevealServiceTests: XCTestCase {

    private let calendar = Calendar.current
    private var now: Date {
        // A fixed mid-morning "now" so today's 07:00 sample is already in the past.
        calendar.date(bySettingHour: 10, minute: 0, second: 0, of: Date(timeIntervalSince1970: 1_756_800_000))!
    }

    /// One 07:00 sample per day for `count` days ending `daysAgoEnd` days before now.
    private func morningSamples(
        value: Double,
        days: Int,
        endingDaysAgo: Int = 0
    ) -> [(date: Date, value: Double)] {
        (0..<days).compactMap { offset in
            let day = calendar.date(byAdding: .day, value: -(offset + endingDaysAgo), to: now)!
            let stamp = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: day)!
            return (date: stamp, value: value)
        }
    }

    // MARK: - Degraded

    func test_noSamples_isDegraded() {
        let reveal = OnboardingRevealService.reveal(
            hrvSamples: [], rhrSamples: [], now: now, calendar: calendar
        )
        XCTAssertNil(reveal.score)
        XCTAssertEqual(reveal.observedPriorHRVDays, 0)
        XCTAssertFalse(reveal.isRealBranch)
        XCTAssertEqual(reveal.confidenceBucket, .floor)
    }

    func test_rhrOnly_hasScoreButNeverRealBranch() {
        // The C2 predicate is an HRV day count — an RHR-only body can score, but the
        // baseline is not honest yet, so the branch stays degraded.
        let reveal = OnboardingRevealService.reveal(
            hrvSamples: [],
            rhrSamples: morningSamples(value: 52, days: 30),
            now: now,
            calendar: calendar
        )
        XCTAssertNotNil(reveal.score)
        XCTAssertEqual(reveal.observedPriorHRVDays, 0)
        XCTAssertFalse(reveal.isRealBranch)
    }

    func test_belowFloor_statesTheDate() {
        let observed = 10
        let reveal = OnboardingRevealService.reveal(
            hrvSamples: morningSamples(value: 65, days: observed + 1), // +1 = today
            rhrSamples: [],
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(reveal.observedPriorHRVDays, observed)
        XCTAssertFalse(reveal.isRealBranch)
        XCTAssertEqual(reveal.confidenceBucket, .floor)

        let missing = BaselineEngine.BaselineConstants.confFloorDays - observed
        let expected = calendar.date(
            byAdding: .day, value: missing, to: calendar.startOfDay(for: now)
        )!
        XCTAssertEqual(reveal.firstRealNumberDate(now: now, calendar: calendar), expected)
    }

    // MARK: - Real branch

    func test_atFloor_isRealAndPartial() {
        let reveal = OnboardingRevealService.reveal(
            hrvSamples: morningSamples(value: 65, days: BaselineEngine.BaselineConstants.confFloorDays + 1),
            rhrSamples: morningSamples(value: 52, days: 20),
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(reveal.observedPriorHRVDays, BaselineEngine.BaselineConstants.confFloorDays)
        XCTAssertNotNil(reveal.score)
        XCTAssertNotNil(reveal.zone)
        XCTAssertTrue(reveal.isRealBranch)
        XCTAssertEqual(reveal.confidenceBucket, .partial)
        XCTAssertNotNil(reveal.hrvBaseline)
        XCTAssertNotNil(reveal.hrvToday)
    }

    func test_atFullDays_isFullBucket() {
        let reveal = OnboardingRevealService.reveal(
            hrvSamples: morningSamples(value: 65, days: BaselineEngine.BaselineConstants.confFullDays + 1),
            rhrSamples: [],
            now: now,
            calendar: calendar
        )
        XCTAssertTrue(reveal.isRealBranch)
        XCTAssertEqual(reveal.confidenceBucket, .full)
    }

    func test_steadyHRVOnBaseline_scoresGreenZone() {
        // A body sitting exactly on its own baseline should read recovered — the same
        // math as the live pipeline, so the reveal and the first snapshot agree.
        let reveal = OnboardingRevealService.reveal(
            hrvSamples: morningSamples(value: 65, days: 30),
            rhrSamples: morningSamples(value: 52, days: 30),
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(reveal.zone, .green)
    }

    // MARK: - Persistence fence (C1)

    func test_serviceSourceTouchesNoModelContext() throws {
        // The reveal persists NOTHING pre-auth. Source fence: the service must never
        // reference SwiftData's write surface or the repositories.
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("WorkloadApp/Services/OnboardingRevealService.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        for forbidden in ["ModelContext", "modelContext", "Repository", "upsert", "insert("] {
            XCTAssertFalse(
                source.contains(forbidden),
                "OnboardingRevealService references \(forbidden) — the reveal must not persist"
            )
        }
    }
}
