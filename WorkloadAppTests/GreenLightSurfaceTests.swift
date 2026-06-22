import XCTest
import SwiftData
@testable import workload_management

/// Phase 45 Plan 03 (Task 1) — pins the `VerdictMeasurementView` → `GreenLightEngine` contract.
///
/// The view binds exactly what `GreenLightEngine.compute(events:asOf:calendar:)` returns over the
/// repository's `fetchAll`. This test seeds events through a STORED in-memory container + repository,
/// then asserts the engine returns the metrics the view will render — for a known differing/acted/right
/// fixture (a real green-light rate) AND for an empty store (honest nil, never a fabricated 0%). It
/// does not render SwiftUI; it pins the data → engine seam the view depends on.
///
/// IMPORTANT (toolchain note): the `@MainActor` repository + `ModelContext` are stored properties and
/// released in a plain non-throwing `tearDown` — NOT `tearDownWithError()` — to dodge the iOS 26.1
/// `swift_task_deinitOnExecutorMainActorBackDeploy` SIGABRT (see VerdictEventRepositoryTests).
@MainActor
final class GreenLightSurfaceTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var repo: VerdictEventRepository!
    private var calendar: Calendar!

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
        repo = VerdictEventRepository(modelContext: context)
        calendar = Calendar(identifier: .gregorian)
    }

    override func tearDown() {
        repo = nil
        context = nil
        container = nil
        calendar = nil
        super.tearDown()
    }

    private func day(_ offsetDays: Int) -> Date {
        calendar.date(byAdding: .day, value: offsetDays, to: calendar.startOfDay(for: .now))!
    }

    /// Seed a differing/acted/right fixture and assert the view's engine call returns the green-light
    /// rate the row will bind.
    func test_seededDifferingActedRight_bindsGreenLightRate() throws {
        let athlete = Athlete(displayName: "Test")
        context.insert(athlete)

        // Day -3: differed, accepted, reported right  → counts in numerator + denominator.
        let e1 = repo.log(
            decidedAt: day(-3), planDate: day(-3), verdictKindRaw: "modify",
            plannedTopSetKg: 100, adjustedTopSetKg: 95, deltaKg: -5, differed: true,
            actionRaw: "accepted", regionRaw: MuscleRegion.legs.rawValue,
            reasonLine: "Backed off.", confidenceNote: nil, athlete: athlete
        )
        repo.recordOutcome("right", for: e1, at: day(-2))

        // Day -2: differed, accepted, reported wrong  → denominator only.
        let e2 = repo.log(
            decidedAt: day(-2), planDate: day(-2), verdictKindRaw: "modify",
            plannedTopSetKg: 100, adjustedTopSetKg: 90, deltaKg: -10, differed: true,
            actionRaw: "accepted", regionRaw: MuscleRegion.back.rawValue,
            reasonLine: "Backed off more.", confidenceNote: nil, athlete: athlete
        )
        repo.recordOutcome("wrong", for: e2, at: day(-1))

        // The view's exact call: engine over fetchAll, clock read at the boundary.
        let events = repo.fetchAll(athlete: athlete)
        let metrics = GreenLightEngine.compute(events: events, asOf: .now, calendar: calendar)

        XCTAssertEqual(metrics.differingDays, 2)
        XCTAssertEqual(try XCTUnwrap(metrics.greenLightRate), 0.5, accuracy: 0.0001)   // 1 of 2 days green
        XCTAssertEqual(metrics.totalEvents, 2)
        XCTAssertEqual(try XCTUnwrap(metrics.activationRate), 1.0, accuracy: 0.0001)   // both acted (≠ keptPlan)
    }

    /// Empty store → honest nil green-light rate (the view shows "still learning", never "0%").
    func test_emptyStore_bindsNilGreenLightRate() throws {
        let athlete = Athlete(displayName: "Test")
        context.insert(athlete)

        let events = repo.fetchAll(athlete: athlete)
        let metrics = GreenLightEngine.compute(events: events, asOf: .now, calendar: calendar)

        XCTAssertNil(metrics.greenLightRate)
        XCTAssertNil(metrics.activationRate)
        XCTAssertEqual(metrics.differingDays, 0)
        XCTAssertEqual(metrics.totalEvents, 0)
    }
}
