import XCTest
import SwiftData
@testable import workload_management

/// v1.7.3 reorientation slice 3 — the Trends merge (APP-REORIENTATION §4.2 Option A).
///
/// Two claims are pinned here:
/// 1. `TrendsViewModel` really is the union of what the retired Recovery and Load tabs
///    fetched for their glance surfaces (windows, insight inputs, range mapping).
/// 2. The "one fetch path for one screen" retirement holds at the SOURCE level: the
///    Dashboard no longer runs its own detail-view fetches, and every
///    `TrendDestination` push lands on the self-fetching `TrendDetailScreens`.
@MainActor
final class TrendsMergeTests: XCTestCase {

    // MARK: - Harness

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Athlete.self,
            WorkoutSession.self,
            ExerciseEntry.self,
            SetRecord.self,
            WorkloadSnapshot.self,
            RecoverySnapshot.self,
            WellnessCheckIn.self,
            PersonalRecord.self,
            BehaviorTag.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        return ModelContext(container)
    }

    private func makeAthlete(in context: ModelContext) -> Athlete {
        let athlete = Athlete(displayName: "Test", sportType: .lifting)
        context.insert(athlete)
        try? context.save()
        return athlete
    }

    private var calendar: Calendar { Calendar.current }

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: .now))!
    }

    // MARK: - TimeRange survived the move

    func test_timeRange_daysMapping_unchanged() {
        XCTAssertEqual(TimeRange.fourWeeks.days, 28)
        XCTAssertEqual(TimeRange.twelveWeeks.days, 84)
        XCTAssertEqual(TimeRange.sixMonths.days, 180)
        XCTAssertEqual(TimeRange.allCases.count, 3)
    }

    // MARK: - The merged load

    func test_load_populatesRecoveryAndCorrelationWindows() async throws {
        let context = try makeContext()
        let athlete = makeAthlete(in: context)

        // 40 days of recovery + workload history — more than every 28-day window, so
        // the window bounds are actually exercised.
        for offset in 0..<40 {
            let recovery = RecoverySnapshot(date: day(offset), recoveryScore: 60)
            recovery.athlete = athlete
            context.insert(recovery)
            let load = WorkloadSnapshot(snapshotDate: day(offset), acuteLoad: 100, chronicLoad: 90, acwr: 1.1)
            load.athlete = athlete
            context.insert(load)
        }
        try context.save()

        let viewModel = TrendsViewModel()
        await viewModel.load(
            athlete: athlete,
            healthKitService: StubHealthDataProvider.silent(),
            modelContext: context
        )

        // 28-day windows, the retired tabs' contract (fetchRecoveryHistory counts
        // calendar days including today, so the bound is the window size ±1 edge day).
        XCTAssertFalse(viewModel.recoveryHistory.isEmpty)
        XCTAssertLessThanOrEqual(viewModel.recoveryHistory.count, 29)
        XCTAssertFalse(viewModel.correlationLoadSnapshots.isEmpty)
        XCTAssertLessThanOrEqual(viewModel.correlationLoadSnapshots.count, 29)
        XCTAssertEqual(viewModel.correlationRecoverySnapshots.count, viewModel.recoveryHistory.count)
        XCTAssertFalse(viewModel.isLoading)
    }

    func test_load_hrvGlance_fromHealthKit_isDailyMorningSeries() async throws {
        let context = try makeContext()
        let athlete = makeAthlete(in: context)

        // Three samples on one morning must reduce to ONE daily value (the v1.7.1
        // morning-window reduction the glance charts contract on).
        let morning = calendar.date(byAdding: .hour, value: 7, to: day(1))!
        let samples = [
            (date: morning, value: 60.0),
            (date: morning.addingTimeInterval(600), value: 70.0),
            (date: morning.addingTimeInterval(1200), value: 80.0),
        ]
        let stub = StubHealthDataProvider.reporting(hrv: samples)

        let viewModel = TrendsViewModel()
        await viewModel.load(athlete: athlete, healthKitService: stub, modelContext: context)

        XCTAssertEqual(viewModel.hrvGlance.count, 1, "three same-morning samples must bucket to one daily value")
        XCTAssertEqual(viewModel.hrvGlance.first?.value ?? 0, 70.0, accuracy: 0.001, "daily value is the morning median")
    }

    func test_load_withoutHealthKit_leavesGlanceEmpty_notCrashing() async throws {
        let context = try makeContext()
        let athlete = makeAthlete(in: context)

        let viewModel = TrendsViewModel()
        await viewModel.load(
            athlete: athlete,
            healthKitService: StubHealthDataProvider.silent(),
            modelContext: context
        )

        XCTAssertTrue(viewModel.hrvGlance.isEmpty, "no HealthKit and no SCREENSHOT_MODE — the glance stays honestly empty")
        XCTAssertFalse(viewModel.isLoading)
    }

    // MARK: - One fetch path for one screen (source fences)

    private func repoRoot(file: StaticString = #filePath) -> URL {
        URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent()   // WorkloadAppTests/
            .deletingLastPathComponent()   // <repo root>
    }

    private func readSource(_ relativePath: String) -> String {
        let url = repoRoot().appendingPathComponent(relativePath)
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("TRENDS-FENCE could not resolve source at \(url.path) — fence cannot be verified")
            return ""
        }
        return contents
    }

    /// The Dashboard VM used to run its own 90-day HRV fetch solely for the detail push.
    /// If `fetchHRVHistory` reappears there, the duplicate query path is back.
    func test_fence_dashboardViewModel_runsNoDetailViewFetch() {
        let source = readSource("WorkloadApp/ViewModels/DashboardViewModel.swift")
        XCTAssertFalse(source.contains("fetchHRVHistory"),
                       "DashboardViewModel must not fetch the HRV detail series — HRVDetailScreen owns that fetch")
        XCTAssertFalse(source.contains("recentSnapshots90"),
                       "the 90-day detail-view snapshot array was retired with the Trends merge")
    }

    /// Every `TrendDestination` push must land on the self-fetching screens, never on the
    /// pure rendering views with a caller-supplied array.
    func test_fence_allTrendDestinationsLandOnDetailScreens() {
        for path in [
            "WorkloadApp/Views/Dashboard/DashboardView.swift",
            "WorkloadApp/Views/Recovery/RecoveryView.swift",
            "WorkloadApp/Views/Trends/TrendsView.swift",
        ] {
            let source = readSource(path)
            guard source.contains("navigationDestination(for: TrendDestination.self)") else { continue }
            XCTAssertTrue(source.contains("HRVDetailScreen()"),
                          "\(path): TrendDestination.hrv must land on HRVDetailScreen")
            XCTAssertTrue(source.contains("SleepDetailScreen()"),
                          "\(path): TrendDestination.sleep must land on SleepDetailScreen")
            XCTAssertFalse(source.contains("HRVDetailView(data:"),
                           "\(path): no caller may feed HRVDetailView its own array any more")
            XCTAssertFalse(source.contains("SleepDetailView(snapshots:"),
                           "\(path): no caller may feed SleepDetailView its own window any more")
        }
    }

    /// The Pro chart stays Pro (closure-plan law): the merged Trends screen must gate the
    /// Recovery-vs-Load section and the range control on `isPro`, and keep the free-tier
    /// history filter + teaser.
    func test_fence_trendsView_carriesFreeTierGating() {
        let source = readSource("WorkloadApp/Views/Trends/TrendsView.swift")
        XCTAssertTrue(source.contains("SubscriptionService.filterSnapshotsForFree"),
                      "free-tier history filter must carry over from the retired Load tab")
        XCTAssertTrue(source.contains("SubscriptionService.lockedWeeks"),
                      "locked-weeks teaser input must carry over")
        XCTAssertTrue(source.contains("HistoryTeaserBanner"),
                      "history teaser banner must carry over")
        // The Recovery-vs-Load chart renders only inside an isPro branch.
        guard let chartRange = source.range(of: "RecoveryLoadChart(") else {
            return XCTFail("RecoveryLoadChart missing from TrendsView")
        }
        let before = source[..<chartRange.lowerBound]
        guard let gateRange = before.range(of: "if container.subscriptionService.isPro", options: .backwards) else {
            return XCTFail("RecoveryLoadChart must sit inside an isPro branch — the Pro chart stays Pro")
        }
        // The gate must be close above the chart (same section, not a distant earlier one).
        XCTAssertLessThan(source.distance(from: gateRange.lowerBound, to: chartRange.lowerBound), 600,
                          "the isPro gate guarding RecoveryLoadChart must be the section's own gate")
    }
}
