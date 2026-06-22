import XCTest
import SwiftData
@testable import workload_management

/// Phase 42 Plan 01 (PLAN-11) — persistence round-trip + default-value fidelity + sync-omission
/// for the additive-nullable verdict-target slots on `TemplateSet`
/// (adjustedTargetWeightKg / adjustedTargetRPE / verdictReason / verdictAppliedAt / athleteOverrode).
///
/// Tests build an in-memory `ModelContainer` whose schema INCLUDES `TemplateSet.self` (+ the graph it
/// hangs off). They avoid optional-relationship `#Predicate` fetches (fetch-all + filter in Swift) to
/// dodge the known iOS 26.1 in-memory SwiftData trap on optional to-one relationship predicates.
@MainActor
final class TemplateSetVerdictSlotTests: XCTestCase {

    // MARK: - In-memory container (schema MUST include TemplateSet.self + its graph)

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Athlete.self, WorkoutSession.self, ExerciseEntry.self, SetRecord.self,
            WorkloadSnapshot.self, RecoverySnapshot.self, MenstrualCycleSnapshot.self,
            CyclePredictionLog.self, ShadowArmPrediction.self, SorenessLog.self,
            BaselineState.self,
            WellnessCheckIn.self, PersonalRecord.self, CoachAthleteRelationship.self,
            WorkoutTemplate.self, ExerciseGroup.self, TemplateExercise.self, TemplateSet.self,
            PrescribedWorkout.self, CustomExercise.self, BehaviorTag.self, TrainingProfile.self
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    /// Build a minimal attached graph: ExerciseGroup → TemplateExercise → one TemplateSet.
    /// Returns the inserted set's id for refetching.
    private func insertSetGraph(into context: ModelContext, configure: (TemplateSet) -> Void) throws -> UUID {
        let group = ExerciseGroup(groupName: "Group A", orderIndex: 0)
        let exercise = TemplateExercise(exerciseName: "Back Squat", orderIndex: 0)
        let set = TemplateSet(setIndex: 0)
        configure(set)
        exercise.sets = [set]
        group.exercises = [exercise]
        context.insert(group)
        try context.save()
        return set.id
    }

    private func fetchSet(_ id: UUID, in context: ModelContext) throws -> TemplateSet {
        let all = try context.fetch(FetchDescriptor<TemplateSet>())
        let match = all.first { $0.id == id }
        return try XCTUnwrap(match)
    }

    // MARK: - Test 1: fresh defaults are nil/false

    func test_newTemplateSet_verdictSlotsDefaultToNilAndFalse() throws {
        let set = TemplateSet(setIndex: 0)
        XCTAssertNil(set.adjustedTargetWeightKg)
        XCTAssertNil(set.adjustedTargetRPE)
        XCTAssertNil(set.verdictReason)
        XCTAssertNil(set.verdictAppliedAt)
        XCTAssertFalse(set.athleteOverrode)
    }

    // MARK: - Test 2: full round-trip, all five slots equal after refetch

    func test_verdictSlots_persistAndFetchBack_allFieldsEqual() throws {
        let context = try makeContext()
        let appliedAt = Calendar.current.startOfDay(for: .now)
        let id = try insertSetGraph(into: context) { set in
            set.adjustedTargetWeightKg = 92.5
            set.adjustedTargetRPE = 7.5
            set.verdictReason = "HRV down 18% — capped intensity"
            set.verdictAppliedAt = appliedAt
            set.athleteOverrode = true
        }

        let row = try fetchSet(id, in: context)
        XCTAssertEqual(row.adjustedTargetWeightKg, 92.5)
        XCTAssertEqual(row.adjustedTargetRPE, 7.5)
        XCTAssertEqual(row.verdictReason, "HRV down 18% — capped intensity")
        XCTAssertEqual(row.verdictAppliedAt, appliedAt)
        XCTAssertTrue(row.athleteOverrode)
    }

    // MARK: - Test 3: an existing-shaped row (no verdict slots set) decodes without migration

    func test_existingRowShape_decodesWithoutMigration() throws {
        let context = try makeContext()
        // Simulate a pre-existing row: only the legacy target fields are set, verdict slots untouched.
        let id = try insertSetGraph(into: context) { set in
            set.targetReps = 5
            set.targetWeightKg = 100.0
            set.targetRPE = 8.0
        }

        let row = try fetchSet(id, in: context)
        // Legacy fields survive…
        XCTAssertEqual(row.targetReps, 5)
        XCTAssertEqual(row.targetWeightKg, 100.0)
        XCTAssertEqual(row.targetRPE, 8.0)
        // …and the additive slots applied their defaults (no crash, no migration).
        XCTAssertNil(row.adjustedTargetWeightKg)
        XCTAssertNil(row.adjustedTargetRPE)
        XCTAssertNil(row.verdictReason)
        XCTAssertNil(row.verdictAppliedAt)
        XCTAssertFalse(row.athleteOverrode)
    }

    // MARK: - Test 4: verdict slots are NOT carried by the synced group payload (SetDTO omission)

    func test_setDTO_excludesVerdictSlots() throws {
        // Build a detached group graph whose single set has every verdict slot populated.
        let group = ExerciseGroup(groupName: "Group A", orderIndex: 0)
        let exercise = TemplateExercise(exerciseName: "Bench Press", orderIndex: 0)
        let set = TemplateSet(
            setIndex: 0,
            targetReps: 5,
            targetWeightKg: 80.0,
            targetRPE: 8.0
        )
        set.adjustedTargetWeightKg = 72.0
        set.adjustedTargetRPE = 6.5
        set.verdictReason = "should not survive sync"
        set.verdictAppliedAt = .now
        set.athleteOverrode = true
        exercise.sets = [set]
        group.exercises = [exercise]

        // Round-trip through the sync encoder/decoder (the exact path used for template sync).
        let json = try XCTUnwrap(SyncService.encodeGroups([group]))
        // The reason string must not even appear in the serialized payload.
        XCTAssertFalse(json.contains("should not survive sync"),
                       "Verdict slots must NOT be serialized into groupsJson (SetDTO is not extended).")

        let decoded = SyncService.decodeGroups(from: json)
        let decodedSet = try XCTUnwrap(decoded.first?.sortedExercises.first?.sortedSets.first)

        // Legacy target fields DO survive the sync round-trip…
        XCTAssertEqual(decodedSet.targetReps, 5)
        XCTAssertEqual(decodedSet.targetWeightKg, 80.0)
        XCTAssertEqual(decodedSet.targetRPE, 8.0)
        // …but the verdict slots come back at their defaults (never carried across sync).
        XCTAssertNil(decodedSet.adjustedTargetWeightKg)
        XCTAssertNil(decodedSet.adjustedTargetRPE)
        XCTAssertNil(decodedSet.verdictReason)
        XCTAssertNil(decodedSet.verdictAppliedAt)
        XCTAssertFalse(decodedSet.athleteOverrode)
    }
}
