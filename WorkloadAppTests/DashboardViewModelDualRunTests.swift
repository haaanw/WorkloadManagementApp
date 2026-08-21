import XCTest
import SwiftData
@testable import workload_management

/// Phase 28 Wave 4 (28-05) — DashboardViewModel dual-run wiring tests.
///
/// Pins the FLAG-OFF byte-identical guarantee at the ViewModel level (after `load()`,
/// `dualRunMessage == nil`) AND proves the FLAG-ON real build emits a non-nil `DualRunMessage`
/// carrying the legacy + updated headlines from REAL recomputed readiness/strain.
///
/// The flag-on path is tested against the SYNCHRONOUS `buildDualRunMessage(...)` method under
/// `PRSActivation.withEnabled(true)`. `withEnabled` is sync and restores the override via `defer`
/// the instant its closure returns; `PRSDualRunSurface.dualRunMessage` re-reads
/// `PRSActivation.isEnabled` internally, so wrapping an `await vm.load()` in the sync closure could
/// NOT keep the flag active across the await. Factoring the gated build into a sync method is the
/// correct, testable shape (plan-check must-fix).
///
/// Does NOT touch the three fence tests (AutoregulationFlagFenceTests, DualRunFlagFenceTests,
/// BaselineTierFenceTests).
@MainActor
final class DashboardViewModelDualRunTests: XCTestCase {

    // MARK: - In-memory store

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
            MenstrualCycleSnapshot.self,
            CyclePredictionLog.self,
            ShadowArmPrediction.self,
            BaselineState.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        return ModelContext(container)
    }

    // MARK: - Seeding helpers

    private func makeSet(
        weightKg: Double? = nil,
        reps: Int? = nil,
        rpe: Double? = nil,
        isWarmup: Bool = false
    ) -> SetRecord {
        SetRecord(reps: reps, weightKg: weightKg, rpe: rpe, rir: nil, isWarmup: isWarmup)
    }

    private func makeStrengthSession(date: Date, weightKg: Double) -> WorkoutSession {
        let session = WorkoutSession(sessionDate: date)
        let entry = ExerciseEntry(exerciseName: "Back Squat", muscleGroup: .quads)
        entry.sets = [
            makeSet(weightKg: weightKg, reps: 5, rpe: 8),
            makeSet(weightKg: weightKg, reps: 5, rpe: 8),
            makeSet(weightKg: weightKg, reps: 5, rpe: 9),
        ]
        session.exerciseEntries = [entry]
        return session
    }

    /// A REAL FatigueResult via the real engine (so the strain channel is honest, not synthesized).
    private func makeRealFatigueResult() -> FatigueIndexEngine.FatigueResult {
        let input = FatigueIndexEngine.FatigueInput(
            recentSessionTSS: [60, 70, 80, 75, 65],
            baselineSessionTSS: 60,
            sessionsIn14Days: 6,
            baselineSessionsIn14Days: 4,
            trainingStreakDays: 4,
            daysSinceRestPeriod: nil,
            recentRecoveryScores: [60, 58, 55, 52, 50, 48, 45],
            recentWellnessScores: [60, 58, 55, 52, 50, 48, 45],
            softTissueInjuryCount: 0,
            daysSinceLastInjury: nil
        )
        return FatigueIndexEngine.compute(input: input)
    }

    // MARK: - FLAG OFF: byte-identical guarantee at the VM level

    func test_flagOff_dualRunMessage_nilAfterLoad() async throws {
        XCTAssertFalse(PRSActivation.isEnabled, "precondition: PRS flag defaults false")

        let ctx = try makeContext()
        let athlete = Athlete(displayName: "Test")
        ctx.insert(athlete)

        // Seed a little real history so load() runs its normal path; flag-off must STILL leave
        // dualRunMessage nil regardless of data.
        let cal = Calendar.current
        for i in 0..<10 {
            let day = cal.date(byAdding: .day, value: -i, to: .now)!
            let snap = RecoverySnapshot(
                date: day,
                hrvSDNN: 55 + Double(i),
                restingHR: 50 + Double(i % 3),
                sleepDurationMinutes: 420 + Double(i * 5),
                recoveryScore: 60
            )
            snap.athlete = athlete
            ctx.insert(snap)
            let session = makeStrengthSession(date: day, weightKg: 100)
            session.athlete = athlete
            ctx.insert(session)
        }

        let vm = DashboardViewModel()
        await vm.load(athlete: athlete, healthKitService: StubHealthDataProvider.silent(), modelContext: ctx)

        XCTAssertNil(vm.dualRunMessage, "flag-off: dualRunMessage MUST be nil after load()")
    }

    // MARK: - FLAG ON: real build emits legacy + updated headlines (sync method under override)

    // NOTE: declared `async` purely to give the @MainActor @Observable VM an enclosing concurrency
    // context for clean deinit (avoids a known Swift-Concurrency TaskLocal double-free on synchronous
    // @MainActor test teardown). The flag-gated build itself remains SYNCHRONOUS: `withEnabled` is sync
    // and wraps the sync `buildDualRunMessage(...)` call with no `await` straddling the override scope.
    func test_flagOn_buildDualRunMessage_nonNil_withLegacyAndUpdatedHeadlines() async throws {
        // Arrange a VM with the REAL published inputs the synchronous builder reads, plus a real
        // legacy recommendation and a real FatigueResult.
        let vm = DashboardViewModel()

        let cal = Calendar.current
        var snapshots: [RecoverySnapshot] = []
        for i in 0..<14 {
            let day = cal.date(byAdding: .day, value: -(13 - i), to: .now)!
            let snap = RecoverySnapshot(
                date: day,
                hrvSDNN: 55 + Double(i),
                restingHR: 52 - Double(i % 4),
                sleepDurationMinutes: 410 + Double(i * 4),
                recoveryScore: 60
            )
            snapshots.append(snap)
        }
        vm.recentSnapshots = snapshots
        vm.latestHRV = 70
        vm.latestRHR = 48
        vm.latestSleepMinutes = 470
        vm.acwr = 1.1
        vm.acwrZone = .optimal

        // Real legacy recommendation (recovery × ACWR).
        let legacy = AutoregulationEngine.recommend(
            input: AutoregulationEngine.DailyInput(
                recoveryZone: .green,
                recoveryScore: 80,
                acwrZone: .optimal,
                acwr: 1.1,
                wellnessScore: nil,
                daysSinceLastRest: 2,
                fatigueIndex: 40
            )
        )
        vm.recommendation = legacy

        let sessions = (0..<8).map { i -> WorkoutSession in
            makeStrengthSession(
                date: cal.date(byAdding: .day, value: -i, to: .now)!,
                weightKg: 100 + Double(i)
            )
        }
        let fatigue = makeRealFatigueResult()

        // Act — flag ON, synchronous build (override stays active for the full sync call).
        PRSActivation.withEnabled(true) {
            vm.buildDualRunMessage(allSessions: sessions, fatigueResult: fatigue, daysSinceRest: 2)
        }

        // Assert — non-nil with legacy + updated headlines from the real recompute.
        let message = try XCTUnwrap(vm.dualRunMessage, "flag-on: dualRunMessage MUST be non-nil")
        XCTAssertEqual(message.previousHeadline, legacy.headline,
                       "previous headline must be the legacy recommendation headline")
        XCTAssertFalse(message.updatedHeadline.isEmpty,
                       "updated headline (readiness × strain-risk) must be non-empty")
        XCTAssertFalse(message.title.isEmpty)
        XCTAssertFalse(message.explanation.isEmpty)
    }

    // MARK: - FLAG ON but no real fatigue → no fabrication (dualRunMessage stays nil)

    func test_flagOn_noFatigueResult_dualRunMessage_staysNil() async {
        let vm = DashboardViewModel()
        vm.recommendation = AutoregulationEngine.recommend(
            input: AutoregulationEngine.DailyInput(
                recoveryZone: .green, recoveryScore: 80, acwrZone: .optimal, acwr: 1.1,
                wellnessScore: nil, daysSinceLastRest: 2, fatigueIndex: nil
            )
        )

        PRSActivation.withEnabled(true) {
            // Cold-start: no real FatigueResult → builder returns nil → no fabrication.
            vm.buildDualRunMessage(allSessions: [], fatigueResult: nil, daysSinceRest: 2)
        }

        XCTAssertNil(vm.dualRunMessage,
                     "no real FatigueResult: builder must return nil rather than fabricate")
    }
}
