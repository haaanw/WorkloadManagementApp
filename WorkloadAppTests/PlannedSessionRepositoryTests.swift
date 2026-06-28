import XCTest
import SwiftData
@testable import workload_management

/// Phase 42 Plan 02 (PLAN-10 / PLAN-11) — tests for `PlannedSessionRepository`'s three designation
/// paths: plan-from-template (frozen copy, source untouched), plan-manual one-off, and fetch-today,
/// plus the proof that planned working sets carry the Plan-01 verdict slots at default.
///
/// In-memory `ModelContainer` whose schema includes the prescription graph; fetch-all + Swift filter
/// (no optional-relationship `#Predicate`) per the iOS 26.1 in-memory SwiftData trap note.
///
/// IMPORTANT (toolchain note): the `@MainActor` repository and its `ModelContext` are held as stored
/// properties and released in `tearDown`, NOT as method locals. On the iOS 26.1 simulator toolchain a
/// `@MainActor` class deallocated mid-synchronous-test-method trips a libswift_Concurrency
/// back-deploy deinit bug (`swift_task_deinitOnExecutorMainActorBackDeploy` → SIGABRT). Owning the
/// instances at the (also `@MainActor`) XCTestCase level and clearing them in tearDown avoids it.
@MainActor
final class PlannedSessionRepositoryTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var repo: PlannedSessionRepository!

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
        repo = PlannedSessionRepository(modelContext: context)
    }

    override func tearDown() {
        repo = nil
        context = nil
        container = nil
        super.tearDown()
    }

    /// Build + insert a saved template with one exercise of `setCount` sets at the given targets.
    private func makeTemplate(
        athleteId: UUID,
        name: String = "Heavy Squat Day",
        weightKg: Double = 140.0,
        reps: Int = 3,
        rpe: Double = 9.0,
        setCount: Int = 4
    ) throws -> WorkoutTemplate {
        let template = WorkoutTemplate(coachId: athleteId, templateName: name)
        template.isAthleteOwned = true
        template.athleteId = athleteId
        let group = ExerciseGroup(groupName: "Group A", orderIndex: 0)
        let exercise = TemplateExercise(exerciseName: "Back Squat", orderIndex: 0)
        exercise.sets = (0..<setCount).map { index in
            TemplateSet(setIndex: index, targetReps: reps, targetWeightKg: weightKg, targetRPE: rpe, isWarmup: false)
        }
        group.exercises = [exercise]
        template.groups = [group]
        context.insert(template)
        try context.save()
        return template
    }

    private func firstWorkingSet(of prescription: PrescribedWorkout) throws -> TemplateSet {
        let set = prescription.sortedGroups.first?.sortedExercises.first?.sortedSets.first
        return try XCTUnwrap(set)
    }

    // MARK: - Test 1: plan-from-template freezes a copy; source template is untouched

    func test_planFromTemplate_freezesCopy_sourceTemplateUntouched() throws {
        let athleteId = UUID()
        let template = try makeTemplate(athleteId: athleteId, setCount: 4)

        let sourceSetCount = template.sortedGroups.first?.sortedExercises.first?.sortedSets.count
        let prescription = repo.planFromTemplate(template, athleteId: athleteId)

        // Prescription mirrors the template targets and links templateId.
        XCTAssertEqual(prescription.templateId, template.id)
        XCTAssertEqual(prescription.templateName, template.templateName)
        let pSet = try firstWorkingSet(of: prescription)
        XCTAssertEqual(pSet.targetWeightKg, 140.0)
        XCTAssertEqual(pSet.targetReps, 3)
        XCTAssertEqual(pSet.targetRPE, 9.0)

        // Mutate the prescription's frozen copy — the source template must NOT change.
        pSet.targetWeightKg = 999.0
        try context.save()

        let sourceSet = try XCTUnwrap(template.sortedGroups.first?.sortedExercises.first?.sortedSets.first)
        XCTAssertEqual(sourceSet.targetWeightKg, 140.0, "Source template set must remain 140 (frozen copy isolation).")
        XCTAssertEqual(template.sortedGroups.first?.sortedExercises.first?.sortedSets.count, sourceSetCount)
    }

    // MARK: - Test 2: plan-manual builds a one-off graph (templateId nil)

    func test_planManualLift_buildsOneOffGraph() throws {
        let athleteId = UUID()

        let prescription = repo.planManualLift(
            athleteId: athleteId,
            liftName: "Back Squat",
            targetWeightKg: 100.0,
            targetReps: 5,
            targetRPE: 8.0,
            setCount: 3
        )

        XCTAssertNil(prescription.templateId)
        XCTAssertEqual(prescription.templateName, "Back Squat")
        let exercises = prescription.allExercises
        XCTAssertEqual(exercises.count, 1)
        XCTAssertEqual(exercises.first?.exerciseName, "Back Squat")
        let sets = try XCTUnwrap(exercises.first).sortedSets
        XCTAssertEqual(sets.count, 3)
        for set in sets {
            XCTAssertFalse(set.isWarmup)
            XCTAssertEqual(set.targetWeightKg, 100.0)
            XCTAssertEqual(set.targetReps, 5)
            XCTAssertEqual(set.targetRPE, 8.0)
        }
    }

    // MARK: - Test 3: fetch-today returns today's plan, not yesterday's

    func test_fetchTodaysPlannedSession_returnsTodaysPlan() throws {
        let athleteId = UUID()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now).addingTimeInterval(8 * 3600) // mid-morning today
        let yesterday = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: today))

        _ = repo.planManualLift(athleteId: athleteId, liftName: "Yesterday Lift",
                                targetWeightKg: 50, targetReps: 5, scheduledDate: yesterday)
        _ = repo.planManualLift(athleteId: athleteId, liftName: "Today Lift",
                                targetWeightKg: 60, targetReps: 5, scheduledDate: today)

        let fetched = repo.fetchTodaysPlannedSession(athleteId: athleteId)
        XCTAssertEqual(fetched?.templateName, "Today Lift")
    }

    // MARK: - Test 4: planned working sets carry the verdict slots at default (ready for Phase 43)

    func test_plannedSets_carryVerdictSlotsAtDefault() throws {
        let athleteId = UUID()

        // Manual path
        let manual = repo.planManualLift(athleteId: athleteId, liftName: "Deadlift",
                                         targetWeightKg: 180, targetReps: 3, targetRPE: 8.5)
        let manualSet = try firstWorkingSet(of: manual)
        XCTAssertNil(manualSet.adjustedTargetWeightKg)
        XCTAssertNil(manualSet.adjustedTargetRPE)
        XCTAssertNil(manualSet.verdictReason)
        XCTAssertNil(manualSet.verdictAppliedAt)
        XCTAssertFalse(manualSet.athleteOverrode)

        // Template path
        let template = try makeTemplate(athleteId: athleteId)
        let fromTemplate = repo.planFromTemplate(template, athleteId: athleteId)
        let templateSet = try firstWorkingSet(of: fromTemplate)
        XCTAssertNil(templateSet.adjustedTargetWeightKg)
        XCTAssertNil(templateSet.adjustedTargetRPE)
        XCTAssertNil(templateSet.verdictReason)
        XCTAssertNil(templateSet.verdictAppliedAt)
        XCTAssertFalse(templateSet.athleteOverrode)
    }

    // MARK: - Test 5: markCompleted links the saved session and is queryable (verdict → workout loop)

    func test_markCompleted_setsStatusAndLinksSession() throws {
        let athleteId = UUID()
        let prescription = repo.planManualLift(athleteId: athleteId, liftName: "Back Squat",
                                               targetWeightKg: 100, targetReps: 5)
        XCTAssertEqual(prescription.status, .assigned)
        XCTAssertNil(prescription.completedSessionId)

        let sessionId = UUID()
        repo.markCompleted(prescriptionId: prescription.id, completedSessionId: sessionId)

        XCTAssertEqual(prescription.status, .completed)
        XCTAssertEqual(prescription.completedSessionId, sessionId)

        // Queryable linkage: re-fetch by id and confirm the session link survives a round-trip.
        let all = (try? context.fetch(FetchDescriptor<PrescribedWorkout>())) ?? []
        let reloaded = try XCTUnwrap(all.first { $0.id == prescription.id })
        XCTAssertEqual(reloaded.completedSessionId, sessionId)
    }

    func test_fetchTodaysPlannedSession_excludesCompleted() throws {
        let athleteId = UUID()
        let prescription = repo.planManualLift(athleteId: athleteId, liftName: "Back Squat",
                                               targetWeightKg: 100, targetReps: 5)
        XCTAssertNotNil(repo.fetchTodaysPlannedSession(athleteId: athleteId))

        repo.markCompleted(prescriptionId: prescription.id, completedSessionId: UUID())
        XCTAssertNil(repo.fetchTodaysPlannedSession(athleteId: athleteId),
                     "A completed prescription must not be re-served as today's plan (no re-decide / double-complete).")
    }

    func test_markCompleted_returnsTrueOnSuccess_falseOnUnknown() throws {
        let athleteId = UUID()
        let prescription = repo.planManualLift(athleteId: athleteId, liftName: "Squat",
                                               targetWeightKg: 100, targetReps: 5)
        XCTAssertTrue(repo.markCompleted(prescriptionId: prescription.id, completedSessionId: UUID()),
                      "Found + persisted ⇒ success (not silently swallowed).")
        XCTAssertFalse(repo.markCompleted(prescriptionId: UUID(), completedSessionId: UUID()),
                       "Unknown id ⇒ explicit failure.")
    }

    func test_markCompleted_unknownPrescription_isNoOp() throws {
        let athleteId = UUID()
        let prescription = repo.planManualLift(athleteId: athleteId, liftName: "Bench",
                                               targetWeightKg: 80, targetReps: 5)
        repo.markCompleted(prescriptionId: UUID(), completedSessionId: UUID())  // wrong id
        XCTAssertEqual(prescription.status, .assigned)
        XCTAssertNil(prescription.completedSessionId)
    }
}
