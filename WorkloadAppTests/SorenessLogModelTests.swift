import XCTest
import SwiftData
@testable import workload_management

/// Phase 25 Plan 01 — persistence round-trip + field-fidelity for the local-only `SorenessLog`
/// @Model, plus the `NiggleType` rawValue-stability serialization contract.
///
/// Tests build an in-memory `ModelContainer` whose schema INCLUDES `SorenessLog.self`. They avoid
/// optional-relationship `#Predicate` fetches (fetch-all + filter in Swift) to dodge the known
/// iOS 26.1 in-memory SwiftData trap on optional to-one relationship predicates.
@MainActor
final class SorenessLogModelTests: XCTestCase {

    // MARK: - In-memory container (schema MUST include SorenessLog.self)

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Athlete.self, WorkoutSession.self, ExerciseEntry.self, SetRecord.self,
            WorkloadSnapshot.self, RecoverySnapshot.self, MenstrualCycleSnapshot.self,
            CyclePredictionLog.self, ShadowArmPrediction.self, SorenessLog.self,
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

    // MARK: - Test 1: field fidelity round-trip

    func test_sorenessLog_persistsAndFetchesBack_allFieldsEqual() throws {
        let context = try makeContext()
        let id = UUID()
        let log = SorenessLog(
            id: id,
            regionRaw: "legs",
            typeRaw: "tweak",
            severity: 8,
            limitedTraining: true,
            note: "left hamstring"
        )
        context.insert(log)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<SorenessLog>())
        XCTAssertEqual(fetched.count, 1)
        let row = try XCTUnwrap(fetched.first)
        XCTAssertEqual(row.id, id)
        XCTAssertEqual(row.regionRaw, "legs")
        XCTAssertEqual(row.typeRaw, "tweak")
        XCTAssertEqual(row.severity, 8)
        XCTAssertEqual(row.limitedTraining, true)
        XCTAssertEqual(row.note, "left hamstring")
    }

    // MARK: - Test 2: NiggleType rawValue stability (serialization contract)

    func test_niggleType_casesAndRawValues_areStable() {
        XCTAssertEqual(NiggleType.allCases.count, 3)
        XCTAssertEqual(Set(NiggleType.allCases), [.soreness, .pain, .tweak])
        XCTAssertEqual(NiggleType.soreness.rawValue, "soreness")
        XCTAssertEqual(NiggleType.pain.rawValue, "pain")
        XCTAssertEqual(NiggleType.tweak.rawValue, "tweak")
        // id mirrors rawValue
        XCTAssertEqual(NiggleType.tweak.id, "tweak")
    }

    // MARK: - Test 3: optional note nil + limitedTraining default

    func test_sorenessLog_nilNote_andLimitedTrainingDefault() throws {
        let context = try makeContext()
        // note omitted (nil), limitedTraining omitted (should default to false)
        let log = SorenessLog(regionRaw: "back", typeRaw: "soreness", severity: 3)
        context.insert(log)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<SorenessLog>())
        let row = try XCTUnwrap(fetched.first)
        XCTAssertNil(row.note)
        XCTAssertEqual(row.limitedTraining, false)
    }

    // MARK: - Test 4: MuscleGroup rawValue round-trips and reconstructs

    func test_sorenessLog_muscleGroupRawValue_reconstructs() throws {
        let context = try makeContext()
        let stored = MuscleGroup.legs.rawValue
        let log = SorenessLog(regionRaw: stored, typeRaw: NiggleType.pain.rawValue, severity: 5)
        context.insert(log)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<SorenessLog>())
        let row = try XCTUnwrap(fetched.first)
        XCTAssertEqual(row.regionRaw, "legs")
        XCTAssertEqual(MuscleGroup(rawValue: row.regionRaw), .legs)
        XCTAssertEqual(NiggleType(rawValue: row.typeRaw), .pain)
    }
}
