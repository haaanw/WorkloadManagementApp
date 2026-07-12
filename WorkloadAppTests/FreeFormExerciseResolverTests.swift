import XCTest
import SwiftData
@testable import workload_management

@MainActor
final class FreeFormExerciseResolverTests: XCTestCase {

    private func fullSchema() -> Schema {
        Schema([
            Athlete.self, WorkoutSession.self, ExerciseEntry.self, SetRecord.self,
            WorkloadSnapshot.self, RecoverySnapshot.self, MenstrualCycleSnapshot.self,
            CyclePredictionLog.self, ShadowArmPrediction.self, SorenessLog.self,
            BaselineState.self, WellnessCheckIn.self, PersonalRecord.self,
            CoachAthleteRelationship.self, WorkoutTemplate.self, ExerciseGroup.self,
            TemplateExercise.self, TemplateSet.self, PrescribedWorkout.self,
            CustomExercise.self, BehaviorTag.self, TrainingProfile.self,
            VerdictEvent.self
        ])
    }

    func test_localMatchHit_returnsCatalogMetadataWithNonNilMuscleGroup() {
        let resolved = WorkoutLLMImportService.resolveLocalExercise(
            name: "bench press",
            sportType: .lifting,
            customExercises: []
        )

        XCTAssertEqual(resolved?.exerciseCategory, .compound)
        XCTAssertEqual(resolved?.muscleGroup, .chest)
        XCTAssertEqual(resolved?.source, .localCatalog)
    }

    func test_localMatchUsesPersistedCustomExerciseOnNextLookup() {
        let custom = CustomExercise(
            name: "Spanish Squat Iso",
            exerciseCategory: .isolation,
            muscleGroup: .quads,
            sportType: .lifting
        )

        let resolved = WorkoutLLMImportService.resolveLocalExercise(
            name: "spanish squat",
            sportType: .lifting,
            customExercises: [custom]
        )

        XCTAssertEqual(resolved?.exerciseCategory, .isolation)
        XCTAssertEqual(resolved?.muscleGroup, .quads)
        XCTAssertEqual(resolved?.source, .localCustom)
    }

    func test_missPathMapsLLMResponseToResolvedExercise() throws {
        let resolved = try WorkoutLLMImportService.resolveLLMExercise(
            .init(
                exerciseName: "Copenhagen Plank",
                exerciseCategoryRaw: "bodyweight",
                muscleGroupRaw: "adductors"
            ),
            requestedName: "Copenhagen plank",
            sportType: .lifting
        )

        XCTAssertEqual(resolved.name, "Copenhagen plank")
        XCTAssertEqual(resolved.exerciseCategory, .bodyweight)
        XCTAssertEqual(resolved.muscleGroup, .adductors)
        XCTAssertEqual(resolved.source, .llm)
    }

    func test_noNilMuscleGroupGuarantee_rejectsLLMWithoutMuscleGroup() {
        XCTAssertThrowsError(
            try WorkoutLLMImportService.resolveLLMExercise(
                .init(
                    exerciseName: "Unknown Skill Drill",
                    exerciseCategoryRaw: "drill",
                    muscleGroupRaw: nil
                ),
                requestedName: "Unknown skill drill",
                sportType: .teamSport
            )
        ) { error in
            XCTAssertEqual(error as? WorkoutLLMImportService.ExerciseResolveError, .missingMuscleGroup)
        }
    }

    func test_manualFallbackProducesValidMuscleGroup() throws {
        let resolved = try WorkoutLLMImportService.manualResolution(
            name: "Low pogo hops",
            exerciseCategory: .plyometric,
            muscleGroup: .calves,
            sportType: .teamSport
        )

        XCTAssertEqual(resolved.exerciseCategory, .plyometric)
        XCTAssertEqual(resolved.muscleGroup, .calves)
        XCTAssertEqual(resolved.source, .manual)
    }

    func test_manualFallbackRejectsMissingMuscleGroup() {
        XCTAssertThrowsError(
            try WorkoutLLMImportService.manualResolution(
                name: "Low pogo hops",
                exerciseCategory: .plyometric,
                muscleGroup: nil,
                sportType: .teamSport
            )
        ) { error in
            XCTAssertEqual(error as? WorkoutLLMImportService.ExerciseResolveError, .missingMuscleGroup)
        }
    }

    func test_persistedCustomExerciseFromResolverNeverHasNilMuscleGroup() throws {
        let container = try ModelContainer(
            for: fullSchema(),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)

        let resolved = try WorkoutLLMImportService.manualResolution(
            name: "Reverse nordic",
            exerciseCategory: .bodyweight,
            muscleGroup: .quads,
            sportType: .lifting
        )
        let exercise = WorkoutLLMImportService.makeCustomExercise(
            from: resolved,
            athlete: nil
        )
        context.insert(exercise)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<CustomExercise>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.muscleGroup, .quads)
        XCTAssertNotNil(fetched.first?.muscleGroup)
    }
}
