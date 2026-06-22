import XCTest
import SwiftData
@testable import workload_management

/// Phase 45 Plan 01 (Task 1) — `VerdictEvent` composite-only @Model contract.
///
/// Proves the measurement substrate's privacy posture at build time:
///  - the model round-trips every COMPOSITE field through an in-memory container (mirrors
///    `ShadowDataContractTests.test_armStore_roundTripsAndCascadeDeletes`),
///  - a source-grep guard asserts NO raw-biometric field name ever appears on the model
///    (composite-only — no raw recovery inputs may be stored),
///  - a sync-omission guard asserts the type is local-only by omission (its name never appears
///    in `SyncService.swift`, mirroring `SorenessLog`),
///  - a schema guard asserts the model is registered additively in the app container.
///
/// `@MainActor` + STORED container/context props set in `setUp` / cleared in `tearDown` is the
/// documented iOS 26.1-sim deinit-SIGABRT avoidance from 42-02 / 43-03.
@MainActor
final class VerdictEventModelTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let schema = Schema([
            Athlete.self, WorkoutSession.self, ExerciseEntry.self, SetRecord.self,
            WorkloadSnapshot.self, RecoverySnapshot.self, MenstrualCycleSnapshot.self,
            CyclePredictionLog.self, ShadowArmPrediction.self, SorenessLog.self,
            BaselineState.self, WellnessCheckIn.self, PersonalRecord.self,
            CoachAthleteRelationship.self, WorkoutTemplate.self, ExerciseGroup.self,
            TemplateExercise.self, TemplateSet.self, PrescribedWorkout.self,
            CustomExercise.self, BehaviorTag.self, TrainingProfile.self,
            VerdictEvent.self
        ])
        container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        context = nil
        container = nil
        try super.tearDownWithError()
    }

    // MARK: - Round-trip

    func test_verdictEvent_roundTripsThroughContainer() throws {
        let cal = Calendar.current
        let decidedAt = Date()
        let planDay = cal.startOfDay(for: decidedAt)

        let event = VerdictEvent(
            decidedAt: decidedAt,
            planDate: planDay,
            verdictKindRaw: "modify",
            plannedTopSetKg: 100,
            adjustedTopSetKg: 95,
            deltaKg: -5,
            differed: true,
            actionRaw: "accepted",
            regionRaw: MuscleRegion.legs.rawValue,
            reasonLine: "Suggested a small back-off today.",
            confidenceNote: "moderate confidence"
        )
        context.insert(event)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<VerdictEvent>())
        XCTAssertEqual(fetched.count, 1)
        let row = try XCTUnwrap(fetched.first)
        XCTAssertEqual(row.decidedAt, decidedAt)
        XCTAssertEqual(row.planDate, planDay, "planDate is normalized to start-of-day")
        XCTAssertEqual(row.verdictKindRaw, "modify")
        XCTAssertEqual(row.plannedTopSetKg, 100)
        XCTAssertEqual(row.adjustedTopSetKg, 95)
        XCTAssertEqual(row.deltaKg, -5)
        XCTAssertTrue(row.differed)
        XCTAssertEqual(row.actionRaw, "accepted")
        XCTAssertEqual(row.regionRaw, "legs")
        XCTAssertEqual(row.reasonLine, "Suggested a small back-off today.")
        XCTAssertEqual(row.confidenceNote, "moderate confidence")
        XCTAssertNil(row.outcomeRaw, "outcome is nil until reported")
        XCTAssertNil(row.outcomeRecordedAt)
    }

    func test_verdictEvent_normalizesPlanDateToStartOfDay() throws {
        let cal = Calendar.current
        let intraday = cal.date(byAdding: .hour, value: 14, to: cal.startOfDay(for: .now))!
        let event = VerdictEvent(
            decidedAt: intraday,
            planDate: intraday,
            verdictKindRaw: "go",
            plannedTopSetKg: 80,
            actionRaw: "keptPlan",
            regionRaw: MuscleRegion.back.rawValue,
            reasonLine: "As planned."
        )
        XCTAssertEqual(event.planDate, cal.startOfDay(for: intraday))
    }

    // MARK: - Composite-only source-grep guard (no raw biometric field names)

    private func source(of relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // WorkloadAppTests/
            .deletingLastPathComponent()   // repo root
        let url = root.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    func test_verdictEvent_compositeOnly_noRawBiometricFieldNames() throws {
        let lowered = try source(of: "WorkloadApp/Models/VerdictEvent.swift").lowercased()
        let bannedRawBiometricTokens = [
            "hrv", "rhr", "restinghr", "hrvsdnn", "sleepduration",
            "heartrate", "bodytemp", "wristtemperature", "vo2", "healthkit", "hkquantity"
        ]
        for token in bannedRawBiometricTokens {
            XCTAssertFalse(
                lowered.contains(token),
                "VerdictEvent.swift must be composite-only — found raw-biometric token '\(token)'"
            )
        }
    }

    // MARK: - Sync-omission guard (local-only by omission)

    func test_verdictEvent_isLocalOnly_absentFromSyncService() throws {
        let sync = try source(of: "WorkloadApp/Services/SyncService.swift")
        XCTAssertFalse(
            sync.contains("VerdictEvent"),
            "VerdictEvent must be local-only — its name must never appear in SyncService.swift"
        )
    }

    // MARK: - Schema-registration guard

    func test_verdictEvent_isRegisteredInAppSchema() throws {
        let app = try source(of: "WorkloadApp/App/WorkloadApp.swift")
        XCTAssertTrue(
            app.contains("VerdictEvent.self"),
            "VerdictEvent.self must be registered in the app SwiftData schema"
        )
    }
}
