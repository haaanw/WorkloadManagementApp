import XCTest
import SwiftData
@testable import workload_management

/// The recovery orchestrator's first direct test file.
///
/// `RecoveryPipeline` had none despite carrying the wake-day sleep gate, the orphan backfill,
/// the daily-input reduction and two shadow folds — it was the largest coverage hole in the
/// algorithm stack. HealthKit is not injectable, so in the test environment the reads return
/// nothing; that is exactly the **no-data contract** worth pinning, because it is also what a
/// new install and a permission-revoked install hit. The value-level rules that HealthKit
/// would otherwise feed are covered by `ReadinessInputReducerTests` and `RecoveryShadowTests`,
/// and the persistence rules directly here.
@MainActor
final class RecoveryPipelineTests: XCTestCase {

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
            BaselineState.self,
            SleepShadowNight.self,
            RecoveryShadowDay.self,
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

    // MARK: - The no-data contract

    func test_run_withNoHealthKitData_producesNeutralScoreAndDoesNotThrow() async throws {
        let context = try makeContext()
        let athlete = makeAthlete(in: context)

        let result = try await RecoveryPipeline.run(
            athlete: athlete,
            healthKitService: HealthKitService(),
            modelContext: context
        )

        // With no signals the engine reports its documented neutral rather than inventing one.
        XCTAssertEqual(result.score, 50)
        XCTAssertEqual(result.zone, .yellow)
    }

    func test_run_persistsExactlyOneSnapshotForToday() async throws {
        let context = try makeContext()
        let athlete = makeAthlete(in: context)

        _ = try await RecoveryPipeline.run(
            athlete: athlete, healthKitService: HealthKitService(), modelContext: context
        )
        let snapshots = try context.fetch(FetchDescriptor<RecoverySnapshot>())
        XCTAssertEqual(snapshots.count, 1)
        XCTAssertEqual(
            calendar.startOfDay(for: snapshots[0].date),
            calendar.startOfDay(for: Date()),
            "the snapshot is keyed on today"
        )
    }

    func test_run_twiceInOneDay_upsertsRatherThanAccumulating() async throws {
        // A dashboard reload, a wellness check-in and a foreground all re-run the pipeline.
        let context = try makeContext()
        let athlete = makeAthlete(in: context)
        let service = HealthKitService()

        _ = try await RecoveryPipeline.run(athlete: athlete, healthKitService: service, modelContext: context)
        _ = try await RecoveryPipeline.run(athlete: athlete, healthKitService: service, modelContext: context)

        XCTAssertEqual(try context.fetch(FetchDescriptor<RecoverySnapshot>()).count, 1)
    }

    func test_run_isStableAcrossRepeatRuns_noSelfDrift() async throws {
        // The v1.7.1 fix: today used to enter its own baseline AND its own trend series, so a
        // second run moved the score with no new physiology.
        let context = try makeContext()
        let athlete = makeAthlete(in: context)
        let service = HealthKitService()

        let first = try await RecoveryPipeline.run(
            athlete: athlete, healthKitService: service, modelContext: context
        )
        let second = try await RecoveryPipeline.run(
            athlete: athlete, healthKitService: service, modelContext: context
        )
        XCTAssertEqual(first.score, second.score, accuracy: 0.0001)
    }

    // MARK: - Shadow discipline

    func test_run_shadowFoldNeverBlocksTheLiveResult() async throws {
        // The shadow must never break the pipeline: with no HealthKit data there is nothing to
        // fold, and the live result must still arrive.
        let context = try makeContext()
        let athlete = makeAthlete(in: context)

        let result = try await RecoveryPipeline.run(
            athlete: athlete, healthKitService: HealthKitService(), modelContext: context
        )
        XCTAssertEqual(result.score, 50)
        // No reduction ran, so no shadow row should exist — the arm stays silent rather than
        // recording an empty comparison.
        XCTAssertTrue(try context.fetch(FetchDescriptor<RecoveryShadowDay>()).isEmpty)
    }

    // MARK: - Baseline checkpoint persistence

    func test_run_doesNotCreateABaselineRowWhenThereIsNothingToFold() async throws {
        // With no HealthKit data the shadow returns before touching state — an empty carrier
        // row would be noise, and its version stamp would falsely claim a checkpoint exists.
        let context = try makeContext()
        let athlete = makeAthlete(in: context)

        _ = try await RecoveryPipeline.run(
            athlete: athlete, healthKitService: HealthKitService(), modelContext: context
        )
        let states = try context.fetch(FetchDescriptor<BaselineState>())
        XCTAssertTrue(states.filter { $0.baselineCheckpointVersion != 0 }.isEmpty)
    }

    func test_baselineState_startsUnversioned_soAnExistingInstallRebuildsOnce() throws {
        // The migration contract: a row written before checkpointing existed reads version 0,
        // mismatches the current version, and is rebuilt from raw history rather than trusted.
        let state = BaselineState()
        XCTAssertEqual(state.baselineCheckpointVersion, 0)
        XCTAssertNotEqual(state.baselineCheckpointVersion, BaselineCheckpoint.schemaVersion)
    }

    // MARK: - Sleep orphan backfill (v1.7.1)

    func test_backfillSleep_fillsAnExistingRowThatHasNoSleep() async throws {
        let context = try makeContext()
        let athlete = makeAthlete(in: context)
        let repo = RecoveryRepository(modelContext: context)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date()))!

        let row = RecoverySnapshot(date: yesterday, recoveryScore: 60)
        row.athlete = athlete
        context.insert(row)
        try context.save()

        let filled = try repo.backfillSleep(minutes: 430, wakeDay: yesterday, athlete: athlete)
        XCTAssertTrue(filled)
        XCTAssertEqual(row.sleepDurationMinutes, 430)
    }

    func test_backfillSleep_neverOverwritesAMeasuredValue() async throws {
        let context = try makeContext()
        let athlete = makeAthlete(in: context)
        let repo = RecoveryRepository(modelContext: context)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date()))!

        let row = RecoverySnapshot(date: yesterday, sleepDurationMinutes: 400, recoveryScore: 60)
        row.athlete = athlete
        context.insert(row)
        try context.save()

        let filled = try repo.backfillSleep(minutes: 999, wakeDay: yesterday, athlete: athlete)
        XCTAssertFalse(filled)
        XCTAssertEqual(row.sleepDurationMinutes, 400)
    }

    func test_backfillSleep_neverFabricatesARow() async throws {
        // A row invented for a day the pipeline never ran would carry a made-up recovery score.
        let context = try makeContext()
        let athlete = makeAthlete(in: context)
        let repo = RecoveryRepository(modelContext: context)
        let longAgo = calendar.date(byAdding: .day, value: -5, to: calendar.startOfDay(for: Date()))!

        let filled = try repo.backfillSleep(minutes: 430, wakeDay: longAgo, athlete: athlete)
        XCTAssertFalse(filled)
        XCTAssertTrue(try context.fetch(FetchDescriptor<RecoverySnapshot>()).isEmpty)
    }

    // MARK: - Authoritative HRV write (v1.7.1 coalesce fix)

    func test_upsert_authoritativeHRV_clearsAStaleMiddayValue() async throws {
        // The ship-blocker both reviewers named: an earlier run's midday HRV must not sit on
        // the row displaying a number the score deliberately did not use.
        let context = try makeContext()
        let athlete = makeAthlete(in: context)
        let repo = RecoveryRepository(modelContext: context)

        try repo.upsertRecoverySnapshot(
            hrvSDNN: 45, restingHR: nil, sleepDurationMinutes: nil,
            bodyTemp: nil, vo2Max: nil, recoveryScore: 60, athlete: athlete
        )
        try repo.upsertRecoverySnapshot(
            hrvSDNN: nil, restingHR: nil, sleepDurationMinutes: nil,
            bodyTemp: nil, vo2Max: nil, recoveryScore: 60, athlete: athlete,
            authoritativeHRV: true
        )

        let row = try XCTUnwrap(try context.fetch(FetchDescriptor<RecoverySnapshot>()).first)
        XCTAssertNil(row.hrvSDNN, "the row must not display an HRV the score ignored")
    }

    func test_upsert_nonAuthoritativeNil_preservesAMeasuredValue() async throws {
        // Every other caller keeps the protective coalesce: for them nil means "not read".
        let context = try makeContext()
        let athlete = makeAthlete(in: context)
        let repo = RecoveryRepository(modelContext: context)

        try repo.upsertRecoverySnapshot(
            hrvSDNN: 45, restingHR: nil, sleepDurationMinutes: nil,
            bodyTemp: nil, vo2Max: nil, recoveryScore: 60, athlete: athlete
        )
        try repo.upsertRecoverySnapshot(
            hrvSDNN: nil, restingHR: nil, sleepDurationMinutes: nil,
            bodyTemp: nil, vo2Max: nil, recoveryScore: 60, athlete: athlete
        )

        let row = try XCTUnwrap(try context.fetch(FetchDescriptor<RecoverySnapshot>()).first)
        XCTAssertEqual(row.hrvSDNN, 45)
    }

    func test_upsert_authoritativeWrite_stillPreservesRHRAndSleep() async throws {
        // RHR keeps its coalesce (Apple refines the daily value), and sleep keeps its own —
        // the wake-day gate nils sleep deliberately and must not wipe a valid earlier write.
        let context = try makeContext()
        let athlete = makeAthlete(in: context)
        let repo = RecoveryRepository(modelContext: context)

        try repo.upsertRecoverySnapshot(
            hrvSDNN: nil, restingHR: 52, sleepDurationMinutes: 420,
            bodyTemp: nil, vo2Max: nil, recoveryScore: 60, athlete: athlete
        )
        try repo.upsertRecoverySnapshot(
            hrvSDNN: nil, restingHR: nil, sleepDurationMinutes: nil,
            bodyTemp: nil, vo2Max: nil, recoveryScore: 60, athlete: athlete,
            authoritativeHRV: true
        )

        let row = try XCTUnwrap(try context.fetch(FetchDescriptor<RecoverySnapshot>()).first)
        XCTAssertEqual(row.restingHR, 52)
        XCTAssertEqual(row.sleepDurationMinutes, 420)
    }
}
