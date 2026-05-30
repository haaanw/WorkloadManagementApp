import XCTest
import SwiftData
@testable import workload_management

/// Phase 26 Plan 01 — persistence round-trip + Optional-fidelity + sync-omission for the
/// local-only `BaselineState` @Model (one row per athlete, flattened HRV/RHR/sleep sub-states).
///
/// Tests build an in-memory `ModelContainer` whose schema INCLUDES `BaselineState.self`. They avoid
/// optional-relationship `#Predicate` fetches (fetch-all + filter in Swift) to dodge the known
/// iOS 26.1 in-memory SwiftData trap on optional to-one relationship predicates.
@MainActor
final class BaselineStateModelTests: XCTestCase {

    // MARK: - In-memory container (schema MUST include BaselineState.self)

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

    // MARK: - Test 1: field fidelity round-trip (incl [Double] MAD buffer, A7)

    func test_baselineState_persistsAndFetchesBack_allFieldsEqual() throws {
        let context = try makeContext()
        let id = UUID()
        let date = Calendar.current.startOfDay(for: .now)
        let state = BaselineState(id: id)

        // HRV sub-state
        state.hrvMu = 52.0
        state.hrvWelfordMean = 51.4
        state.hrvM2 = 120.0
        state.hrvCount = 14
        state.hrvMadBuffer = [-1.0, 2.0, -0.5]
        state.hrvLastBucketedDate = date
        state.hrvCvRatio = 1.2
        state.hrvCvLevelRaw = "elevated"
        state.hrvConfidence = 0.6

        // RHR mirror
        state.rhrMu = 48.0
        state.rhrWelfordMean = 47.5
        state.rhrM2 = 30.0
        state.rhrCount = 9
        state.rhrMadBuffer = [0.5, -0.25]
        state.rhrLastBucketedDate = date
        state.rhrCvRatio = 0.9
        state.rhrCvLevelRaw = "high"
        state.rhrConfidence = 0.4

        // Sleep mirror
        state.sleepMu = 420.0
        state.sleepWelfordMean = 415.0
        state.sleepM2 = 5000.0
        state.sleepCount = 21
        state.sleepMadBuffer = [10.0, -5.0, 3.0, -2.0]
        state.sleepLastBucketedDate = date
        state.sleepCvRatio = 1.05
        state.sleepCvLevelRaw = "normal"
        state.sleepConfidence = 0.8

        context.insert(state)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<BaselineState>())
        XCTAssertEqual(fetched.count, 1)
        let row = try XCTUnwrap(fetched.first)
        XCTAssertEqual(row.id, id)

        // HRV
        XCTAssertEqual(row.hrvMu, 52.0)
        XCTAssertEqual(row.hrvWelfordMean, 51.4)
        XCTAssertEqual(row.hrvM2, 120.0)
        XCTAssertEqual(row.hrvCount, 14)
        XCTAssertEqual(row.hrvMadBuffer, [-1.0, 2.0, -0.5]) // A7: [Double] survives
        XCTAssertEqual(row.hrvLastBucketedDate, date)
        XCTAssertEqual(row.hrvCvRatio, 1.2)
        XCTAssertEqual(row.hrvCvLevelRaw, "elevated")
        XCTAssertEqual(row.hrvConfidence, 0.6)

        // RHR
        XCTAssertEqual(row.rhrMu, 48.0)
        XCTAssertEqual(row.rhrWelfordMean, 47.5)
        XCTAssertEqual(row.rhrM2, 30.0)
        XCTAssertEqual(row.rhrCount, 9)
        XCTAssertEqual(row.rhrMadBuffer, [0.5, -0.25])
        XCTAssertEqual(row.rhrLastBucketedDate, date)
        XCTAssertEqual(row.rhrCvRatio, 0.9)
        XCTAssertEqual(row.rhrCvLevelRaw, "high")
        XCTAssertEqual(row.rhrConfidence, 0.4)

        // Sleep
        XCTAssertEqual(row.sleepMu, 420.0)
        XCTAssertEqual(row.sleepWelfordMean, 415.0)
        XCTAssertEqual(row.sleepM2, 5000.0)
        XCTAssertEqual(row.sleepCount, 21)
        XCTAssertEqual(row.sleepMadBuffer, [10.0, -5.0, 3.0, -2.0])
        XCTAssertEqual(row.sleepLastBucketedDate, date)
        XCTAssertEqual(row.sleepCvRatio, 1.05)
        XCTAssertEqual(row.sleepCvLevelRaw, "normal")
        XCTAssertEqual(row.sleepConfidence, 0.8)
    }

    // MARK: - Test 2: Optional fidelity ("no fold yet" ≠ "μ==0")

    func test_baselineState_freshInit_optionalsAreNil_accumulatorsZero() throws {
        let context = try makeContext()
        let state = BaselineState()
        context.insert(state)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<BaselineState>())
        let row = try XCTUnwrap(fetched.first)

        for mu in [row.hrvMu, row.rhrMu, row.sleepMu] {
            XCTAssertNil(mu)
        }
        for d in [row.hrvLastBucketedDate, row.rhrLastBucketedDate, row.sleepLastBucketedDate] {
            XCTAssertNil(d)
        }
        for cv in [row.hrvCvRatio, row.rhrCvRatio, row.sleepCvRatio] {
            XCTAssertNil(cv)
        }
        XCTAssertEqual(row.hrvCount, 0)
        XCTAssertEqual(row.rhrCount, 0)
        XCTAssertEqual(row.sleepCount, 0)
        XCTAssertEqual(row.hrvMadBuffer, [])
        XCTAssertEqual(row.rhrMadBuffer, [])
        XCTAssertEqual(row.sleepMadBuffer, [])
    }

    // MARK: - Test 3: local-only / no sync (privacy-by-omission)

    func test_baselineState_isAbsentFromSyncService() throws {
        // Resolve the repo root from this test file's location.
        let thisFile = URL(fileURLWithPath: #filePath)
        // .../WorkloadAppTests/BaselineStateModelTests.swift → repo root is two levels up.
        let repoRoot = thisFile
            .deletingLastPathComponent()   // WorkloadAppTests
            .deletingLastPathComponent()   // repo root
        let syncURL = repoRoot
            .appendingPathComponent("WorkloadApp")
            .appendingPathComponent("Services")
            .appendingPathComponent("SyncService.swift")

        let contents = try String(contentsOf: syncURL, encoding: .utf8)
        XCTAssertFalse(
            contents.contains("BaselineState"),
            "BaselineState must NEVER appear in SyncService.swift (local-only by omission)."
        )
    }

    // MARK: - Test 4: cvLevelRaw cold-state default

    func test_baselineState_defaultCvLevel_isNormal() throws {
        let context = try makeContext()
        let state = BaselineState()
        context.insert(state)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<BaselineState>())
        let row = try XCTUnwrap(fetched.first)
        XCTAssertEqual(row.hrvCvLevelRaw, "normal")
        XCTAssertEqual(row.rhrCvLevelRaw, "normal")
        XCTAssertEqual(row.sleepCvLevelRaw, "normal")
    }
}
