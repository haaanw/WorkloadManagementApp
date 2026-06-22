import XCTest
import SwiftData
@testable import workload_management

/// Phase 44 Plan 01 (Task 2) — `TodayVerdictViewModel`: refresh assembles inputs + writes the slots
/// via the service seam and builds the headline display; accept/keepPlan/feelOverride mutate ONLY the
/// two Phase-44 slots, emit a `VerdictDecision`, and never overwrite the authored `targetWeightKg`;
/// cold-start defers honestly.
///
/// Stored-XCTestCase-prop pattern (own ModelContainer/ModelContext/viewModel, set in `setUp`, cleared
/// in `tearDown`) to avoid the iOS-26.1-sim `@MainActor` deinit SIGABRT.
@MainActor
final class TodayVerdictViewModelTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var athlete: Athlete!
    private var viewModel: TodayVerdictViewModel!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let schema = Schema([
            Athlete.self, WorkoutSession.self, ExerciseEntry.self, SetRecord.self,
            WorkloadSnapshot.self, RecoverySnapshot.self, MenstrualCycleSnapshot.self,
            CyclePredictionLog.self, ShadowArmPrediction.self, SorenessLog.self,
            BaselineState.self,
            WellnessCheckIn.self, PersonalRecord.self, CoachAthleteRelationship.self,
            WorkoutTemplate.self, ExerciseGroup.self, TemplateExercise.self, TemplateSet.self,
            PrescribedWorkout.self, CustomExercise.self, BehaviorTag.self, TrainingProfile.self
        ])
        container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
        athlete = Athlete(displayName: "Test Athlete")
        context.insert(athlete)
        try context.save()
        viewModel = TodayVerdictViewModel(modelContext: context)
    }

    override func tearDown() {
        viewModel = nil
        athlete = nil
        context = nil
        container = nil
        super.tearDown()
    }

    // MARK: - Fixtures

    /// A today-plan with two exercises: Back Squat (top working set 140, warmup 60, back-off 120)
    /// and Bench Press (working 80). The SESSION headline = Back Squat @ 140.
    @discardableResult
    private func seedTodayPlan() -> PrescribedWorkout {
        let workout = PrescribedWorkout(
            coachId: athlete.id, athleteId: athlete.id, templateId: UUID(),
            scheduledDate: .now, templateName: "Leg Day"
        )
        let group = ExerciseGroup(groupName: "Group A", orderIndex: 0)

        let squat = TemplateExercise(exerciseName: "Back Squat", muscleGroup: .legs, orderIndex: 0)
        squat.sets = [
            TemplateSet(setIndex: 0, targetReps: 5, targetWeightKg: 60, targetRPE: 6, isWarmup: true),
            TemplateSet(setIndex: 1, targetReps: 5, targetWeightKg: 120, targetRPE: 7, isWarmup: false),
            TemplateSet(setIndex: 2, targetReps: 5, targetWeightKg: 140, targetRPE: 8, isWarmup: false)
        ]
        let bench = TemplateExercise(exerciseName: "Bench Press", muscleGroup: .chest, orderIndex: 1)
        bench.sets = [
            TemplateSet(setIndex: 0, targetReps: 5, targetWeightKg: 80, targetRPE: 8, isWarmup: false)
        ]
        group.exercises = [squat, bench]
        workout.groups = [group]
        context.insert(workout)
        try? context.save()
        return workout
    }

    /// Seed enough REAL history that `PRSReadinessInputBuilder.buildDetailed` returns non-nil:
    /// 20 recovery snapshots with HRV/RHR/sleep + one workout session (so fatigue is non-nil).
    private func seedPopulatedHistory() {
        let calendar = Calendar.current
        for i in 1...20 {
            let jitter = Double(i % 5) - 2.0
            let snap = RecoverySnapshot(
                date: calendar.date(byAdding: .day, value: -i, to: .now)!,
                hrvSDNN: 60 + jitter,
                restingHR: 55 + jitter * 0.5,
                sleepDurationMinutes: 420 + jitter * 10,
                recoveryScore: 55
            )
            snap.athlete = athlete
            context.insert(snap)
        }
        let session = WorkoutSession(sessionDate: calendar.date(byAdding: .day, value: -2, to: .now)!,
                                     durationSeconds: 3600, sessionRPE: 7)
        session.trainingStress = 50
        session.athlete = athlete
        context.insert(session)
        try? context.save()
    }

    /// The per-exercise top working sets (matches the VM's selection rule).
    private func topSets(of workout: PrescribedWorkout) -> [TemplateSet] {
        workout.allExercises.compactMap { exercise in
            exercise.sortedSets
                .filter { !$0.isWarmup && ($0.targetWeightKg ?? 0) > 0 }
                .max { ($0.targetWeightKg ?? 0) < ($1.targetWeightKg ?? 0) }
        }
    }

    // MARK: - No planned session

    func test_refresh_noPlannedSession_displayNil() {
        viewModel.refresh(athlete: athlete)
        XCTAssertNil(viewModel.display)
    }

    // MARK: - Populated → display built, headline correct

    func test_refresh_populated_buildsHeadlineDisplay() {
        seedPopulatedHistory()
        seedTodayPlan()
        viewModel.refresh(athlete: athlete)

        let display = try? XCTUnwrap(viewModel.display)
        XCTAssertNotNil(display)
        XCTAssertEqual(viewModel.display?.headlineExerciseName, "Back Squat")
        XCTAssertEqual(viewModel.display?.plannedTopSetKg ?? -1, 140, accuracy: 1e-9)
        // Real readiness build → not a cold-start defer.
        XCTAssertNotEqual(viewModel.display?.kind, .deferred)
        XCTAssertNil(viewModel.display?.confidenceNote)
    }

    // MARK: - Cold-start defers honestly (SC4)

    func test_refresh_coldStart_defersWithLearningNote_noFabricatedTrim() {
        seedTodayPlan()                       // a plan, but NO recovery/session history
        viewModel.refresh(athlete: athlete)

        XCTAssertEqual(viewModel.display?.kind, .deferred)
        XCTAssertEqual(viewModel.display?.confidenceNote, "Still learning your baseline")
        XCTAssertEqual(viewModel.display?.hasAdjustment, false)
        // Defer never fabricates a trim: planned == adjusted.
        XCTAssertEqual(viewModel.display?.plannedTopSetKg ?? -1,
                       viewModel.display?.adjustedTopSetKg ?? -2, accuracy: 1e-9)
    }

    // MARK: - accept()

    func test_accept_marksAppliedAt_neverOverwritesPlanned_emitsDecisionOnce() {
        seedPopulatedHistory()
        let plan = seedTodayPlan()
        viewModel.refresh(athlete: athlete)

        var fireCount = 0
        viewModel.onDecisionRecorded = { _ in fireCount += 1 }

        viewModel.accept()

        for top in topSets(of: plan) {
            XCTAssertNotNil(top.verdictAppliedAt)
            XCTAssertFalse(top.athleteOverrode)
        }
        // Authored numbers untouched.
        XCTAssertEqual(topSets(of: plan).map { $0.targetWeightKg ?? -1 }.sorted(), [80, 140])
        XCTAssertEqual(viewModel.display?.appliedState, .accepted)
        XCTAssertEqual(viewModel.lastDecision?.action, .accepted)
        XCTAssertEqual(fireCount, 1)
    }

    // MARK: - keepPlan()

    func test_keepPlan_marksOverride_clearsApplied_plannedUnchanged() {
        seedPopulatedHistory()
        let plan = seedTodayPlan()
        viewModel.refresh(athlete: athlete)

        viewModel.keepPlan()

        for top in topSets(of: plan) {
            XCTAssertTrue(top.athleteOverrode)
            XCTAssertNil(top.verdictAppliedAt)
        }
        XCTAssertEqual(topSets(of: plan).map { $0.targetWeightKg ?? -1 }.sorted(), [80, 140])
        XCTAssertEqual(viewModel.display?.appliedState, .keptPlan)
        XCTAssertEqual(viewModel.lastDecision?.action, .keptPlan)
    }

    // MARK: - feelOverride

    func test_feelOverride_strong_keepsPlan_emitsFeelStrong() {
        seedPopulatedHistory()
        let plan = seedTodayPlan()
        viewModel.refresh(athlete: athlete)

        viewModel.feelOverride(.feelingStrong)

        for top in topSets(of: plan) {
            XCTAssertTrue(top.athleteOverrode)
            XCTAssertNil(top.verdictAppliedAt)
        }
        XCTAssertEqual(viewModel.lastDecision?.action, .feel(.feelingStrong))
    }

    func test_feelOverride_rough_withAdjustment_acceptsEmitsFeelRough() {
        seedPopulatedHistory()
        let plan = seedTodayPlan()
        viewModel.refresh(athlete: athlete)

        // Force a real adjustment on every top set (simulate the engine having trimmed).
        for top in topSets(of: plan) {
            top.adjustedTargetWeightKg = (top.targetWeightKg ?? 0) - 10
        }

        viewModel.feelOverride(.feelingRough)

        for top in topSets(of: plan) {
            XCTAssertNotNil(top.verdictAppliedAt)   // accepted the conservative trim
            XCTAssertFalse(top.athleteOverrode)
        }
        XCTAssertEqual(viewModel.lastDecision?.action, .feel(.feelingRough))
    }
}
