import XCTest
import SwiftData
@testable import workload_management

/// v1.7.3 feature 6, batch 4 — the eased entry trims the frozen copy only: one back-off
/// per exercise, never the top set, never a warmup, and never the source template.
@MainActor
final class EasedEntryTrimTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var repo: PlannedSessionRepository!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let schema = Schema([
            Athlete.self, WorkoutTemplate.self, ExerciseGroup.self, TemplateExercise.self,
            TemplateSet.self, PrescribedWorkout.self
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

    func test_trim_dropsLastBackoffKeepsTopSetAndWarmup_sourceUntouched() throws {
        let athleteId = UUID()
        let template = WorkoutTemplate(coachId: athleteId, templateName: "Lower")
        let group = ExerciseGroup(groupName: "Main", orderIndex: 0)
        let exercise = TemplateExercise(exerciseName: "Back squat", orderIndex: 0)
        exercise.sets = [
            TemplateSet(setIndex: 0, targetReps: 5, targetWeightKg: 60, isWarmup: true),
            TemplateSet(setIndex: 1, targetReps: 5, targetWeightKg: 140),
            TemplateSet(setIndex: 2, targetReps: 5, targetWeightKg: 120),
            TemplateSet(setIndex: 3, targetReps: 5, targetWeightKg: 120)
        ]
        group.exercises = [exercise]
        template.groups = [group]
        context.insert(template)
        try context.save()

        let prescription = repo.planFromTemplate(template, athleteId: athleteId)
        try repo.trimOneBackoffPerExercise(prescription, reason: "Eased entry — week 1")

        let copySets = prescription.allExercises[0].sortedSets
        XCTAssertEqual(copySets.count, 3, "one back-off trimmed from the copy")
        XCTAssertTrue(copySets.contains { $0.isWarmup }, "warmups survive")
        XCTAssertTrue(copySets.contains { $0.targetWeightKg == 140 }, "the top set survives")
        XCTAssertEqual(copySets.filter { $0.targetWeightKg == 120 }.count, 1)
        XCTAssertEqual(
            copySets.first { $0.targetWeightKg == 140 }?.verdictReason,
            "Eased entry — week 1"
        )

        // The athlete's program template is untouched.
        XCTAssertEqual(template.groups[0].exercises[0].sets.count, 4)
    }

    func test_trim_singleWorkingSetIsNeverTouched() throws {
        let athleteId = UUID()
        let template = WorkoutTemplate(coachId: athleteId, templateName: "Singles")
        let group = ExerciseGroup(groupName: "Main", orderIndex: 0)
        let exercise = TemplateExercise(exerciseName: "Deadlift", orderIndex: 0)
        exercise.sets = [TemplateSet(setIndex: 0, targetReps: 3, targetWeightKg: 180)]
        group.exercises = [exercise]
        template.groups = [group]
        context.insert(template)
        try context.save()

        let prescription = repo.planFromTemplate(template, athleteId: athleteId)
        try repo.trimOneBackoffPerExercise(prescription, reason: "Eased entry — week 1")
        XCTAssertEqual(prescription.allExercises[0].sortedSets.count, 1,
                       "a single working set has nothing to trim but the top set — untouched")
    }
}
