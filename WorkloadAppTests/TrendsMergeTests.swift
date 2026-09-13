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
            // The fatigue series reads the niggle log for its soft-tissue component.
            SorenessLog.self,
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

    // MARK: - The range rail

    /// v1.7.3 (UAT round 1 · U9): the windows changed with the page's question. 4W/12W/6M
    /// belonged to "how has my load moved"; the fatigue narrative is answered over a fortnight,
    /// because the model's own windows are 14 days (density, wellness) and 7 (recovery trend).
    func test_timeRange_isTheFatigueWindowSet() {
        XCTAssertEqual(TimeRange.oneWeek.days, 7)
        XCTAssertEqual(TimeRange.twoWeeks.days, 14)
        XCTAssertEqual(TimeRange.oneMonth.days, 30)
        XCTAssertEqual(TimeRange.allCases.count, 3)
    }

    /// The default is the fortnight, and it is load-bearing: the range rail stays Pro, so this
    /// is the ONLY window a free athlete ever reads. It has to be the one the engine is built on.
    ///
    /// The view model is held for the PROCESS rather than constructed inline: a transient
    /// `@MainActor`-isolated object deallocating in a synchronous test aborts the host through
    /// `swift_task_deinitOnExecutorMainActorBackDeploy` — a zero-second failure with no message
    /// (the C-wdg-002 family, documented in `AnalyticsSinkTests`). Held, it never deinits here.
    private static let defaultRangeProbe = TrendsViewModel()

    func test_defaultRange_isTheFortnight_whichFreeAthletesAreStuckWith() {
        XCTAssertEqual(Self.defaultRangeProbe.selectedRange, .twoWeeks)
        XCTAssertEqual(TimeRange.twoWeeks.days, FatigueHistoryEngine.minimumHistoryDays)
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

    // MARK: - The fatigue narrative (U9)

    /// With enough history the page has a series, a reading, and a story to tell about it.
    func test_load_buildsTheFatigueSeries_overTheSelectedWindow() async throws {
        let context = try makeContext()
        let athlete = makeAthlete(in: context)

        // 40 days of daily training + recovery: more than any window, so the slice is real.
        for offset in 0..<40 {
            let session = WorkoutSession(sessionDate: day(offset), sportType: .lifting)
            session.sessionRPE = 8
            session.durationSeconds = 3600
            // `trainingStress` is written by `recalculateDerivedFields()` at save time; these
            // rows are hand-built, so the load the engine reads is set explicitly.
            session.trainingStress = 80
            session.athlete = athlete
            context.insert(session)
            let recovery = RecoverySnapshot(date: day(offset), recoveryScore: 60)
            recovery.athlete = athlete
            context.insert(recovery)
        }
        try context.save()

        let viewModel = TrendsViewModel()
        await viewModel.load(
            athlete: athlete,
            healthKitService: StubHealthDataProvider.silent(),
            modelContext: context
        )

        XCTAssertEqual(viewModel.selectedRange, .twoWeeks)
        XCTAssertEqual(viewModel.fatiguePoints.count, TimeRange.twoWeeks.days,
                       "the series covers the whole selected window when history allows")
        XCTAssertTrue(viewModel.hasEnoughHistory)
        XCTAssertEqual(viewModel.sessionsInRange, TimeRange.twoWeeks.days,
                       "a session a day for 40 days means a session a day inside the window")
        XCTAssertEqual(viewModel.dailyLoadBars.count, TimeRange.twoWeeks.days,
                       "rest days are present-and-zero, so the bar count is the window length")
        XCTAssertNotNil(viewModel.baselineSessionsInRange)
    }

    /// The honest empty state. A young account must NOT get a chart of its own warm-up.
    func test_load_withThinHistory_reportsNotEnough_ratherThanGuessing() async throws {
        let context = try makeContext()
        let athlete = makeAthlete(in: context)

        for offset in 0..<4 {
            let session = WorkoutSession(sessionDate: day(offset), sportType: .lifting)
            session.sessionRPE = 7
            session.durationSeconds = 3600
            session.trainingStress = 60
            session.athlete = athlete
            context.insert(session)
        }
        try context.save()

        let viewModel = TrendsViewModel()
        await viewModel.load(
            athlete: athlete,
            healthKitService: StubHealthDataProvider.silent(),
            modelContext: context
        )

        XCTAssertFalse(viewModel.hasEnoughHistory)
        XCTAssertLessThan(viewModel.observedHistoryDays, FatigueHistoryEngine.minimumHistoryDays)
    }

    /// No sessions at all: no series, no crash, and nothing invented.
    func test_load_withNoSessions_leavesTheNarrativeEmpty() async throws {
        let context = try makeContext()
        let athlete = makeAthlete(in: context)

        let viewModel = TrendsViewModel()
        await viewModel.load(
            athlete: athlete,
            healthKitService: StubHealthDataProvider.silent(),
            modelContext: context
        )

        XCTAssertTrue(viewModel.fatiguePoints.isEmpty)
        XCTAssertFalse(viewModel.hasEnoughHistory)
        XCTAssertEqual(viewModel.observedHistoryDays, 0)
        XCTAssertEqual(viewModel.sessionsInRange, 0)
        XCTAssertNil(viewModel.baselineSessionsInRange)
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

    /// The tab merge itself: four tabs, Trends among them, selection owned by the R9
    /// router seam so cross-feature entries can hand off between tabs.
    ///
    /// The router's default is asserted at the SOURCE level, not by constructing one:
    /// deallocating a `@MainActor` class in a sync test context SIGABRTs through
    /// `swift_task_deinitOnExecutorMainActorBackDeploy` (the C-wdg-002 trap — same crash,
    /// zero-second failure, no assertion message).
    func test_tabStructure_isOptionA() {
        XCTAssertEqual(AppTab.allCases, [.home, .log, .trends, .profile])
        let router = readSource("WorkloadApp/App/AppRouter.swift")
        XCTAssertTrue(router.contains("var selection: AppTab = .home"),
                      "the shell opens on Home — TabRouter's default moved")
    }

    /// Every `TrendDestination` push must land on the self-fetching screens, never on the
    /// pure rendering views with a caller-supplied array. (RecoveryView left this list
    /// when the tab retired in commit 2 of the slice.)
    func test_fence_allTrendDestinationsLandOnDetailScreens() {
        for path in [
            "WorkloadApp/Views/Dashboard/DashboardView.swift",
            "WorkloadApp/Views/Trends/TrendsView.swift",
        ] {
            let source = readSource(path)
            guard source.contains("navigationDestination(for: TrendDestination.self)") else { continue }
            XCTAssertTrue(source.contains("HRVDetailScreen()"),
                          "\(path): TrendDestination.hrv must land on HRVDetailScreen")
            XCTAssertTrue(source.contains("RHRDetailScreen()"),
                          "\(path): TrendDestination.rhr must land on RHRDetailScreen")
            XCTAssertTrue(source.contains("SleepDetailScreen()"),
                          "\(path): TrendDestination.sleep must land on SleepDetailScreen")
            XCTAssertFalse(source.contains("HRVDetailView(data:"),
                           "\(path): no caller may feed HRVDetailView its own array any more")
            XCTAssertFalse(source.contains("SleepDetailView(snapshots:"),
                           "\(path): no caller may feed SleepDetailView its own window any more")
        }
    }

    /// U9's receiving half: each of Today's three body-signal cells is a DOOR. This is what
    /// makes it safe for Trends to stop plotting the same three lines — the physiology now
    /// lives behind the number that names it. Source-level, because a cell that renders but
    /// does not navigate is exactly the defect this closed and a green suite could not see it.
    func test_fence_todayMetricCells_eachPushTheirOwnDetailScreen() {
        let source = readSource("WorkloadApp/Views/Dashboard/DashboardView.swift")
        for destination in ["destination: .hrv", "destination: .rhr", "destination: .sleep"] {
            XCTAssertTrue(source.contains(destination),
                          "MetricsStrip must wire a cell for \(destination) — the strip is three doors, not a readout")
        }
        XCTAssertTrue(source.contains("indicatesNavigation: true"),
                      "a cell that navigates must carry the caret; an unmarked door reads as a readout")
    }

    /// The physiology glances LEFT Trends. If either returns, the page is re-plotting readings
    /// Today already prints one tap from their own detail screens — the U9 finding verbatim.
    func test_fence_trendsView_noLongerRePlotsTodaysReadings() {
        let source = readSource("WorkloadApp/Views/Trends/TrendsView.swift")
        XCTAssertFalse(source.contains("HRVTrendChart("),
                       "the HRV glance belongs behind Today's HRV cell, not on Trends")
        XCTAssertFalse(source.contains("SleepTrendChart("),
                       "the sleep glance belongs behind Today's sleep cell, not on Trends")
        XCTAssertTrue(source.contains("TrendsFatigueSection("),
                      "the fatigue narrative is the page's spine")
    }

    /// v6.3 area ownership follows the METRIC. The re-scoped page's hero is the fatigue index —
    /// a load reading — so the page is a load surface, and the recovery-vs-load section declares
    /// recovery on itself. (It was the other way round while the page was fronted by HRV.)
    func test_fence_trendsView_standsInTheLoadArea() {
        let source = readSource("WorkloadApp/Views/Trends/TrendsView.swift")
        XCTAssertTrue(source.contains(".metricArea(.load)"),
                      "the re-scoped Trends page is a LOAD surface — its hero is the fatigue index")
        XCTAssertTrue(source.contains(".metricArea(.recovery)"),
                      "the recovery-vs-load section must declare its own hue")
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
