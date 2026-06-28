import XCTest
import SwiftData
@testable import workload_management

/// Phase 45 Plan 02 (Task 1) — SC4 ordering guard: every verdict decision logs exactly one composite
/// VerdictEvent, and the production surface wires the logger so the verdict can't be reached unlogged.
///
/// STORED container/context/repos/VM in setUp + non-throwing `tearDown` is the documented iOS 26.1-sim
/// @MainActor deinit-SIGABRT avoidance (releasing a @MainActor class inside `tearDownWithError()`'s
/// error-observation wrapper trips `swift_task_deinitOnExecutorMainActorBackDeploy` → SIGABRT).
@MainActor
final class VerdictEventLoggingTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var planRepo: PlannedSessionRepository!
    private var eventRepo: VerdictEventRepository!
    private var vm: TodayVerdictViewModel!
    private var athlete: Athlete!

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
        planRepo = PlannedSessionRepository(modelContext: context)
        eventRepo = VerdictEventRepository(modelContext: context)
        vm = TodayVerdictViewModel(modelContext: context)

        athlete = Athlete(displayName: "Test")
        context.insert(athlete)
        try context.save()

        // Seed a today planned manual lift, then refresh the VM (cold-start ⇒ honest defer).
        _ = planRepo.planManualLift(
            athleteId: athlete.id, liftName: "Back Squat",
            targetWeightKg: 100, targetReps: 5, targetRPE: 8, setCount: 3, scheduledDate: .now
        )
        vm.refresh(athlete: athlete)

        // Wire the logger seam EXACTLY as WorkoutLogView does.
        let repo = eventRepo!
        let loggedAthlete = athlete!
        let model = vm!
        vm.onDecisionRecorded = { [weak model] decision in
            guard let model else { return }
            let delta = (decision.adjustedTopSetKg ?? decision.plannedTopSetKg) - decision.plannedTopSetKg
            repo.log(
                decidedAt: decision.decidedAt,
                planDate: .now,
                verdictKindRaw: model.lastHeadlineVerdictRaw ?? "go",
                plannedTopSetKg: decision.plannedTopSetKg,
                adjustedTopSetKg: decision.adjustedTopSetKg,
                deltaKg: delta,
                differed: decision.hadAdjustment,
                actionRaw: Self.actionRaw(decision.action),
                regionRaw: model.lastHeadlineRegionRaw ?? MuscleRegion.fullBody.rawValue,
                reasonLine: decision.reasonLine,
                confidenceNote: model.display?.confidenceNote,
                suggestedBackoffSetCut: decision.suggestedBackoffSetCut,
                suggestedRPECap: decision.suggestedRPECap,
                athlete: loggedAthlete
            )
        }
    }

    override func tearDown() {
        vm = nil
        eventRepo = nil
        planRepo = nil
        athlete = nil
        context = nil
        container = nil
        super.tearDown()
    }

    private static func actionRaw(_ action: VerdictAction) -> String {
        switch action {
        case .accepted: return "accepted"
        case .keptPlan: return "keptPlan"
        case .feel(.feelingStrong): return "feelStrong"
        case .feel(.feelingRough): return "feelRough"
        }
    }

    // MARK: - One event per decision, correct mapping

    func test_eachDecision_logsExactlyOneEvent_withCorrectMapping() throws {
        XCTAssertEqual(eventRepo.fetchAll(athlete: athlete).count, 0, "nothing logged before any decision")

        // ACCEPT
        vm.accept()
        var all = eventRepo.fetchAll(athlete: athlete)
        XCTAssertEqual(all.count, 1, "accept logs exactly one event")
        XCTAssertEqual(all.first?.actionRaw, "accepted")
        XCTAssertEqual(all.first?.regionRaw, MuscleRegion.fullBody.rawValue, "manual lift has no muscleGroup ⇒ fullBody")
        XCTAssertEqual(all.first?.verdictKindRaw, "defer", "cold-start ⇒ defer label")
        XCTAssertFalse(all.first?.differed ?? true, "cold-start defer ⇒ no adjustment ⇒ not differed")

        // KEEP-PLAN
        vm.keepPlan()
        all = eventRepo.fetchAll(athlete: athlete)
        XCTAssertEqual(all.count, 2, "keepPlan logs exactly one more event")
        XCTAssertEqual(all.first?.actionRaw, "keptPlan")

        // FEEL-OVERRIDE (rough)
        vm.feelOverride(.feelingRough)
        all = eventRepo.fetchAll(athlete: athlete)
        XCTAssertEqual(all.count, 3, "feel-override logs exactly one more event")
        XCTAssertEqual(all.first?.actionRaw, "feelRough")
    }

    // MARK: - Differing-adjustment mapping (delta + differed)

    func test_differingDecision_mapsDeltaAndDifferedFlag() throws {
        // Drive the wired closure directly with a differing decision (suggestion below plan).
        let decision = VerdictDecision(
            action: .accepted,
            plannedTopSetKg: 100,
            adjustedTopSetKg: 95,
            hadAdjustment: true,
            reasonLine: "Backed off a touch.",
            decidedAt: .now,
            suggestedBackoffSetCut: nil,
            suggestedRPECap: nil
        )
        vm.onDecisionRecorded?(decision)
        let all = eventRepo.fetchAll(athlete: athlete)
        XCTAssertEqual(all.count, 1)
        XCTAssertTrue(all.first?.differed ?? false, "hadAdjustment ⇒ differed")
        XCTAssertEqual(all.first?.deltaKg ?? 0, -5, accuracy: 0.0001, "delta = adjusted − planned")
        XCTAssertEqual(all.first?.adjustedTopSetKg, 95)
    }

    func test_volumeOnlyDecision_differedTrue_zeroDelta_structuredContext() {
        let decision = VerdictDecision(
            action: .accepted, plannedTopSetKg: 100, adjustedTopSetKg: 100,
            hadAdjustment: true, reasonLine: "Trim a back-off set.", decidedAt: .now,
            suggestedBackoffSetCut: 1, suggestedRPECap: nil
        )
        vm.onDecisionRecorded?(decision)
        let e = eventRepo.fetchAll(athlete: athlete).first
        XCTAssertTrue(e?.differed ?? false, "volume-only still differs")
        XCTAssertEqual(e?.deltaKg ?? -1, 0, accuracy: 1e-9)
        XCTAssertEqual(e?.suggestedBackoffSetCut, 1)
    }

    func test_rpeOnlyDecision_differedTrue_structuredContext() {
        let decision = VerdictDecision(
            action: .accepted, plannedTopSetKg: 100, adjustedTopSetKg: 100,
            hadAdjustment: true, reasonLine: "Cap the effort.", decidedAt: .now,
            suggestedBackoffSetCut: nil, suggestedRPECap: 7
        )
        vm.onDecisionRecorded?(decision)
        let e = eventRepo.fetchAll(athlete: athlete).first
        XCTAssertTrue(e?.differed ?? false, "RPE-only still differs")
        XCTAssertEqual(e?.suggestedRPECap, 7)
    }

    // MARK: - SC4 structural guard: the production surface wires the logger

    func test_workoutLogView_wiresOnDecisionRecorded_sourceGrep() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // WorkloadAppTests/
            .deletingLastPathComponent()   // repo root
        let url = root.appendingPathComponent("WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(
            source.contains("onDecisionRecorded"),
            "WorkoutLogView must wire onDecisionRecorded — the SC4 ordering guard (seam never left nil)"
        )
    }
}
