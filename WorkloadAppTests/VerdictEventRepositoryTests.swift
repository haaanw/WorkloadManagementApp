import XCTest
import SwiftData
@testable import workload_management

/// Phase 45 Plan 01 (Task 2) — `VerdictEventRepository` round-trip + query contract.
///
/// Proves log / recordOutcome / fetchAll / fetchRecent / mostRecentAwaitingOutcome behave per the
/// repository convention (newest-first, athlete-filtered, past-day un-resolved gating).
///
/// IMPORTANT (toolchain note, mirrors PlannedSessionRepositoryTests): the `@MainActor` repository and
/// its `ModelContext` are held as stored properties and released in a plain, non-throwing `tearDown`,
/// NOT `tearDownWithError()`. On the iOS 26.1 simulator toolchain, releasing a `@MainActor` class
/// inside the failable-teardown error-observation wrapper trips a libswift_Concurrency back-deploy
/// deinit bug (`swift_task_deinitOnExecutorMainActorBackDeploy` → libmalloc double-free → SIGABRT).
/// A non-throwing `tearDown()` releases inline on the main actor and avoids it.
@MainActor
final class VerdictEventRepositoryTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var repo: VerdictEventRepository!

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
    }

    override func tearDown() {
        repo = nil
        context = nil
        container = nil
        super.tearDown()
    }

    private func daysAgo(_ n: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -n, to: .now)!
    }

    // MARK: - log

    func test_log_createsRow() throws {
        let athlete = Athlete(displayName: "Test")
        context.insert(athlete)
        let event = repo.log(
            decidedAt: .now, planDate: .now, verdictKindRaw: "modify",
            plannedTopSetKg: 100, adjustedTopSetKg: 95, deltaKg: -5, differed: true,
            actionRaw: "accepted", regionRaw: MuscleRegion.legs.rawValue,
            reasonLine: "Backed off a touch.", confidenceNote: nil, athlete: athlete
        )
        XCTAssertEqual(event.actionRaw, "accepted")
        let all = repo.fetchAll(athlete: athlete)
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.verdictKindRaw, "modify")
    }

    // MARK: - recordOutcome

    func test_recordOutcome_setsOutcomeAndTimestamp() throws {
        let event = repo.log(
            decidedAt: .now, planDate: .now, verdictKindRaw: "go",
            plannedTopSetKg: 80, adjustedTopSetKg: nil, deltaKg: 0, differed: false,
            actionRaw: "keptPlan", regionRaw: MuscleRegion.back.rawValue,
            reasonLine: "As planned.", confidenceNote: nil, athlete: nil
        )
        XCTAssertNil(event.outcomeRaw)
        let stamp = Date()
        repo.recordOutcome("right", for: event, at: stamp)
        XCTAssertEqual(event.outcomeRaw, "right")
        XCTAssertEqual(event.outcomeRecordedAt, stamp)
    }

    // MARK: - fetchAll newest-first + athlete filter

    func test_fetchAll_newestFirst_andAthleteFiltered() throws {
        let a1 = Athlete(displayName: "A1")
        let a2 = Athlete(displayName: "A2")
        context.insert(a1); context.insert(a2)
        repo.log(decidedAt: daysAgo(2), planDate: daysAgo(2), verdictKindRaw: "go",
                 plannedTopSetKg: 50, adjustedTopSetKg: nil, deltaKg: 0, differed: false,
                 actionRaw: "keptPlan", regionRaw: "back", reasonLine: "x", confidenceNote: nil, athlete: a1)
        repo.log(decidedAt: daysAgo(1), planDate: daysAgo(1), verdictKindRaw: "modify",
                 plannedTopSetKg: 60, adjustedTopSetKg: 55, deltaKg: -5, differed: true,
                 actionRaw: "accepted", regionRaw: "legs", reasonLine: "y", confidenceNote: nil, athlete: a1)
        repo.log(decidedAt: .now, planDate: .now, verdictKindRaw: "hold",
                 plannedTopSetKg: 70, adjustedTopSetKg: 60, deltaKg: -10, differed: true,
                 actionRaw: "feelRough", regionRaw: "chest", reasonLine: "z", confidenceNote: nil, athlete: a2)

        let a1Events = repo.fetchAll(athlete: a1)
        XCTAssertEqual(a1Events.count, 2, "a2's event is filtered out")
        XCTAssertEqual(a1Events.first?.verdictKindRaw, "modify", "newest-first")
        XCTAssertEqual(a1Events.last?.verdictKindRaw, "go")
        XCTAssertEqual(repo.fetchAll(athlete: a2).count, 1)
        XCTAssertEqual(repo.fetchAll(athlete: nil).count, 3, "nil athlete returns all")
    }

    // MARK: - fetchRecent window

    func test_fetchRecent_respectsWindow() throws {
        repo.log(decidedAt: daysAgo(10), planDate: daysAgo(10), verdictKindRaw: "go",
                 plannedTopSetKg: 50, adjustedTopSetKg: nil, deltaKg: 0, differed: false,
                 actionRaw: "keptPlan", regionRaw: "back", reasonLine: "old", confidenceNote: nil, athlete: nil)
        repo.log(decidedAt: daysAgo(1), planDate: daysAgo(1), verdictKindRaw: "modify",
                 plannedTopSetKg: 60, adjustedTopSetKg: 55, deltaKg: -5, differed: true,
                 actionRaw: "accepted", regionRaw: "legs", reasonLine: "recent", confidenceNote: nil, athlete: nil)

        let recent = repo.fetchRecent(days: 7, athlete: nil)
        XCTAssertEqual(recent.count, 1)
        XCTAssertEqual(recent.first?.reasonLine, "recent")
    }

    // MARK: - mostRecentAwaitingOutcome

    func test_mostRecentAwaitingOutcome_returnsOnlyPastDayUnresolved() throws {
        let athlete = Athlete(displayName: "A")
        context.insert(athlete)
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: .now)

        // Today's event — planDate == todayStart, NOT before todayStart ⇒ excluded.
        repo.log(decidedAt: .now, planDate: .now, verdictKindRaw: "go",
                 plannedTopSetKg: 50, adjustedTopSetKg: nil, deltaKg: 0, differed: false,
                 actionRaw: "keptPlan", regionRaw: "back", reasonLine: "today", confidenceNote: nil, athlete: athlete)
        // Yesterday, already resolved ⇒ excluded.
        let resolved = repo.log(decidedAt: daysAgo(1), planDate: daysAgo(1), verdictKindRaw: "modify",
                 plannedTopSetKg: 60, adjustedTopSetKg: 55, deltaKg: -5, differed: true,
                 actionRaw: "accepted", regionRaw: "legs", reasonLine: "resolved", confidenceNote: nil, athlete: athlete)
        repo.recordOutcome("right", for: resolved, at: .now)
        // Two days ago, un-resolved ⇒ the expected hit.
        repo.log(decidedAt: daysAgo(2), planDate: daysAgo(2), verdictKindRaw: "hold",
                 plannedTopSetKg: 70, adjustedTopSetKg: 60, deltaKg: -10, differed: true,
                 actionRaw: "feelRough", regionRaw: "chest", reasonLine: "awaiting", confidenceNote: nil, athlete: athlete)

        let hit = repo.mostRecentAwaitingOutcome(athlete: athlete, before: todayStart)
        XCTAssertEqual(hit?.reasonLine, "awaiting")
    }
}
