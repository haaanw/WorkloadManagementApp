import XCTest
import SwiftData
@testable import workload_management

/// Pull-to-refresh on Today (v1.7.3 · UAT round 3 · U18).
///
/// The defect: Today prints a PERSISTED snapshot while the HRV and RHR detail screens re-query
/// HealthKit on every push. HAN's watch was off overnight; the app foregrounded before it
/// synced, wrote `hrvSDNN = nil`, and nothing re-ran while the app stayed resident — so the
/// detail page showed this morning's reading and Today did not.
///
/// What is pinned here is the ORDER, because the four steps are not independent: the watch
/// import can add sessions the load reads, the pipeline rewrites today's row, and only then is
/// there anything worth pushing. And the mid-morning re-run itself must be safe by the
/// 2026-08-05 rules — a late HRV replaces the nil, and today never enters its own baseline.
@MainActor
final class RecoveryRefreshTests: XCTestCase {

    // MARK: - Store

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Athlete.self,
            WorkoutSession.self,
            ExerciseEntry.self,
            SetRecord.self,
            RecoverySnapshot.self,
            WorkloadSnapshot.self,
            WellnessCheckIn.self,
            TrainingProfile.self,
            PersonalRecord.self,
            SorenessLog.self,
            BaselineState.self,
            SleepShadowNight.self,
            RecoveryShadowDay.self,
            MorningReadinessProbe.self,
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

    /// A sample inside the HRV morning window on a given day offset.
    private func morningSample(daysAgo: Int, value: Double) -> (date: Date, value: Double) {
        let calendar = Calendar.current
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: .now))!
        let at7 = calendar.date(byAdding: .hour, value: 7, to: day)!
        return (date: at7, value: value)
    }

    /// Seven prior mornings at a flat 50 ms, so the baseline is exactly 50 and any drift into
    /// it from today's reading would show up immediately.
    private var sevenFlatPriorMornings: [(date: Date, value: Double)] {
        (1...7).map { morningSample(daysAgo: $0, value: 50) }
    }

    private func todaysSnapshot(
        _ context: ModelContext,
        athlete: Athlete
    ) throws -> RecoverySnapshot? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return try context.fetch(FetchDescriptor<RecoverySnapshot>())
            .filter { $0.athlete?.id == athlete.id && calendar.startOfDay(for: $0.date) == today }
            .max { $0.updatedAt < $1.updatedAt }
    }

    // MARK: - The ordering contract

    func test_refreshAll_runsTheWatchImportBeforeTheBodyIsRead() async throws {
        let context = try makeContext()
        let athlete = makeAthlete(in: context)
        let health = StubHealthDataProvider.reporting(hrv: sevenFlatPriorMornings)

        var order: [String] = []
        var fetchCountWhenImportRan: Int?

        let viewModel = DashboardViewModel()
        await viewModel.refreshAll(
            athlete: athlete,
            healthKitService: health,
            modelContext: context,
            syncService: nil,
            importWatchWorkouts: {
                order.append("import")
                // The pipeline reads the body; if it had already started, this would be > 0.
                fetchCountWhenImportRan = health.fetchCount
            }
        )
        order.append("after")

        XCTAssertEqual(order, ["import", "after"], "the import must run, and run first")
        XCTAssertEqual(
            fetchCountWhenImportRan, 0,
            "the pipeline must not have read HealthKit before the watch import finished"
        )
        XCTAssertTrue(viewModel.hasLoadedOnce, "refreshAll must AWAIT the load, never fire and forget")
    }

    func test_refreshAll_awaitsThePipelineBeforeItPushes() throws {
        // A source fence rather than a behavioural one: `pushAll` needs a live Supabase client,
        // and the property under test is ordering in the source, not a network result. Racing
        // the push against the pipeline would push the row the pipeline is replacing.
        let source = try readSource("WorkloadApp/ViewModels/DashboardViewModel.swift")
        guard let body = source.range(of: "func refreshAll(") else {
            return XCTFail("refreshAll is gone — U18's whole contract went with it")
        }
        let tail = String(source[body.lowerBound...])
        guard let loadCall = tail.range(of: "await load("),
              let pushCall = tail.range(of: "await syncService.pushAll("),
              let pullCall = tail.range(of: "await syncService.pullAll(")
        else {
            return XCTFail("refreshAll no longer awaits load / pushAll / pullAll by name")
        }
        XCTAssertTrue(
            loadCall.lowerBound < pushCall.lowerBound,
            "the pipeline must be AWAITED before pushAll — never raced with it"
        )
        XCTAssertTrue(
            pushCall.lowerBound < pullCall.lowerBound,
            "push before pull: a pull first would overwrite what was never sent"
        )
        XCTAssertFalse(
            tail.prefix(through: pushCall.lowerBound).contains("Task {"),
            "no detached Task may carry the sync — the refresh spinner must cover the whole run"
        )
    }

    // MARK: - The late morning HRV

    func test_refreshAll_aLateMorningHRV_replacesTheNilOnTodaysRow() async throws {
        let context = try makeContext()
        let athlete = makeAthlete(in: context)

        // Morning run: the watch has not synced, so prior days are known and today is not.
        let beforeSync = StubHealthDataProvider.reporting(hrv: sevenFlatPriorMornings)
        let viewModel = DashboardViewModel()
        await viewModel.load(athlete: athlete, healthKitService: beforeSync, modelContext: context)

        let morningRow = try XCTUnwrap(try todaysSnapshot(context, athlete: athlete))
        XCTAssertNil(morningRow.hrvSDNN, "precondition: today's row starts with no HRV")

        // The watch goes on and syncs. The athlete pulls Today down.
        let afterSync = StubHealthDataProvider.reporting(
            hrv: sevenFlatPriorMornings + [morningSample(daysAgo: 0, value: 90)]
        )
        await viewModel.refreshAll(
            athlete: athlete,
            healthKitService: afterSync,
            modelContext: context,
            syncService: nil,
            importWatchWorkouts: {}
        )

        let refreshedRow = try XCTUnwrap(try todaysSnapshot(context, athlete: athlete))
        XCTAssertEqual(
            refreshedRow.hrvSDNN, 90,
            "the authoritative HRV write replaces the nil once the morning reading arrives"
        )
        XCTAssertEqual(viewModel.latestHRV, 90, "and Today reads it back")
    }

    func test_refreshAll_baselineStillExcludesToday() async throws {
        let context = try makeContext()
        let athlete = makeAthlete(in: context)

        let health = StubHealthDataProvider.reporting(
            hrv: sevenFlatPriorMornings + [morningSample(daysAgo: 0, value: 90)]
        )
        let viewModel = DashboardViewModel()
        await viewModel.refreshAll(
            athlete: athlete,
            healthKitService: health,
            modelContext: context,
            syncService: nil,
            importWatchWorkouts: {}
        )

        let row = try XCTUnwrap(try todaysSnapshot(context, athlete: athlete))
        // Seven prior days at 50; today at 90. A baseline that had folded today in would land
        // at 55, and the deviation the score is built on would shrink with no new physiology.
        XCTAssertEqual(
            try XCTUnwrap(row.hrvBaseline), 50, accuracy: 0.0001,
            "a mid-morning re-run must build the baseline from days STRICTLY before today"
        )
    }

    // MARK: - The observer

    func test_recoverySignalObserver_isRegisteredFromTheContainer_overTheThreeReadSignals() throws {
        let service = try readSource("WorkloadApp/Services/HealthKitService.swift")
        XCTAssertTrue(
            service.contains("func observeRecoverySignals("),
            "U18 needs an observer over the signals Today prints"
        )
        for identifier in ["heartRateVariabilitySDNN", "restingHeartRate", "sleepAnalysis"] {
            XCTAssertTrue(
                service.contains("HKQuantityType(.\(identifier))")
                    || service.contains("HKCategoryType(.\(identifier))"),
                "\(identifier) must be observed — it is one of the three cells on Today"
            )
        }

        let container = try readSource("WorkloadApp/App/AppContainer.swift")
        XCTAssertTrue(
            container.contains("registerRecoverySignalObserver()"),
            "registration belongs to the container, which outlives every scene"
        )
        XCTAssertTrue(
            container.contains(".recoverySignalsChanged"),
            "the observer must post the notice Today listens for"
        )
        XCTAssertFalse(
            container.contains("enableBackgroundDelivery"),
            "foreground-only by ruling: no background delivery, no new entitlement, for these types"
        )

        let dashboard = try readSource("WorkloadApp/Views/Dashboard/DashboardView.swift")
        XCTAssertTrue(
            dashboard.contains("publisher(for: .recoverySignalsChanged)"),
            "Today must observe the notice the same way it observes NSCalendarDayChanged"
        )
        XCTAssertTrue(
            dashboard.contains(".refreshable"),
            "U18's affordance is the system pull-to-refresh on Today's ScrollView"
        )
    }

    // MARK: - Helper

    private func readSource(_ relativePath: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
