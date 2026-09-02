import XCTest
import SwiftData
import SwiftUI
@testable import workload_management

/// Reorientation slice 1 (APP-REORIENTATION R2) — Home's plan-aware primary CTA.
///
/// Proves the glance contract:
///  - no planned session today ⇒ `.none` (the blank recommendation path, unchanged);
///  - today-plan with NO decision markers ⇒ `.pendingDecision` (slice 1 leaves the pill
///    on the blank path; the decision itself stays single-surfaced on the Log tab's card);
///  - accepted decision ⇒ `.startAdjusted` carrying the ADJUSTED resolved numbers;
///  - kept-plan decision ⇒ `.startPlan` carrying the AUTHORED numbers;
///  - completed / skipped / other-athlete / other-day prescriptions never produce a CTA;
///  - the derivation is a PURE read — it never writes verdict slots (SC4 stays on the card).
///
/// Follows the `@MainActor`-repo XCTest lifetime pattern (container/context as stored props)
/// to avoid the iOS 26.1-sim `@MainActor` deinit crash; the derivation itself constructs no
/// repository (C-wdg-002 trap) so calling it synchronously here is the point of the test.
@MainActor
final class DashboardTodayPlanCTATests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let schema = Schema([
            Athlete.self, WorkoutSession.self, ExerciseEntry.self, SetRecord.self,
            WorkloadSnapshot.self, RecoverySnapshot.self, MenstrualCycleSnapshot.self,
            CyclePredictionLog.self, ShadowArmPrediction.self, SorenessLog.self,
            BaselineState.self,
            WellnessCheckIn.self, PersonalRecord.self, CoachAthleteRelationship.self,
            WorkoutTemplate.self, ExerciseGroup.self, TemplateExercise.self, TemplateSet.self,
            PrescribedWorkout.self, CustomExercise.self, BehaviorTag.self, TrainingProfile.self,
            VerdictEvent.self
        ])
        container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
    }

    override func tearDown() {
        context = nil
        container = nil
        super.tearDown()
    }

    // MARK: - Fixtures

    /// A prescription for `athleteId` with one exercise whose top set is 140 kg authored /
    /// 130 kg suggested, inserted into the context.
    @discardableResult
    private func insertPrescription(
        athleteId: UUID,
        scheduledDate: Date = .now,
        status: PrescriptionStatus = .assigned
    ) -> (prescription: PrescribedWorkout, topSet: TemplateSet) {
        let topSet = TemplateSet(setIndex: 0, targetReps: 5, targetWeightKg: 140, targetRPE: 8, isWarmup: false)
        topSet.adjustedTargetWeightKg = 130
        topSet.adjustedTargetRPE = 7
        let backoff = TemplateSet(setIndex: 1, targetReps: 5, targetWeightKg: 120, targetRPE: 7, isWarmup: false)
        let exercise = TemplateExercise(exerciseName: "Back Squat", muscleGroup: .legs, orderIndex: 0)
        exercise.sets = [topSet, backoff]
        let group = ExerciseGroup(groupName: "Group A", orderIndex: 0)
        group.exercises = [exercise]
        let prescription = PrescribedWorkout(
            coachId: athleteId, athleteId: athleteId, templateId: UUID(),
            scheduledDate: scheduledDate, templateName: "Leg Day",
            sportType: .lifting, sessionType: .strength
        )
        prescription.status = status
        prescription.groups = [group]
        context.insert(prescription)
        return (prescription, topSet)
    }

    private func derive(_ athleteId: UUID) -> DashboardViewModel.TodayPlanCTA {
        DashboardViewModel.deriveTodayPlanCTA(athleteId: athleteId, modelContext: context)
    }

    // MARK: - No plan / out-of-scope plans

    func test_noPlan_isNone() {
        XCTAssertEqual(derive(UUID()), .none)
    }

    func test_otherAthletesPlan_isNone() {
        insertPrescription(athleteId: UUID())
        XCTAssertEqual(derive(UUID()), .none)
    }

    func test_yesterdaysPlan_isNone() {
        let athleteId = UUID()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        insertPrescription(athleteId: athleteId, scheduledDate: yesterday)
        XCTAssertEqual(derive(athleteId), .none)
    }

    func test_completedPlan_isNone() {
        let athleteId = UUID()
        insertPrescription(athleteId: athleteId, status: .completed)
        XCTAssertEqual(derive(athleteId), .none)
    }

    // MARK: - Pending: plan exists, card not decided

    func test_undecidedPlan_isPendingDecision() {
        let athleteId = UUID()
        insertPrescription(athleteId: athleteId)
        XCTAssertEqual(derive(athleteId), .pendingDecision)
    }

    // MARK: - Decided: the pill carries the SAME resolved numbers as the card

    func test_acceptedPlan_isStartAdjusted_withAdjustedWeight() throws {
        let athleteId = UUID()
        let (_, topSet) = insertPrescription(athleteId: athleteId)
        VerdictDecisionApplier.applyAccept(to: topSet, appliedAt: .now)

        guard case .startAdjusted(let plan) = derive(athleteId) else {
            return XCTFail("expected .startAdjusted, got \(derive(athleteId))")
        }
        let resolvedTop = try XCTUnwrap(plan.exercises.first?.sets.first)
        XCTAssertEqual(resolvedTop.weightKg, 130)      // adjusted, not authored
        XCTAssertEqual(resolvedTop.plannedWeightKg, 140)
    }

    func test_keptPlan_isStartPlan_withAuthoredWeight() throws {
        let athleteId = UUID()
        let (_, topSet) = insertPrescription(athleteId: athleteId)
        VerdictDecisionApplier.applyKeepPlan(to: topSet)

        guard case .startPlan(let plan) = derive(athleteId) else {
            return XCTFail("expected .startPlan, got \(derive(athleteId))")
        }
        let resolvedTop = try XCTUnwrap(plan.exercises.first?.sets.first)
        XCTAssertEqual(resolvedTop.weightKg, 140)      // authored — keep-plan resolves as written
    }

    // MARK: - Purity: deriving never writes decision slots (SC4 stays on the card)

    func test_derivation_neverWritesVerdictSlots() {
        let athleteId = UUID()
        let (_, topSet) = insertPrescription(athleteId: athleteId)
        _ = derive(athleteId)
        XCTAssertNil(topSet.verdictAppliedAt)
        XCTAssertFalse(topSet.athleteOverrode)   // non-optional marker, defaults false
        XCTAssertEqual(derive(athleteId), .pendingDecision)   // still undecided after N reads
    }

    // MARK: - CTA label: plan states outrank the recommendation label

    func test_labelKey_planStatesOutrankRecommendation() {
        let resolved = ResolvedSessionPlan.resolve(
            from: insertPrescription(athleteId: UUID()).prescription
        )
        XCTAssertEqual(
            PrimaryActionCTA.labelKey(planCTA: .startAdjusted(resolved), sessionType: .rest),
            "verdictCard.start.adjusted"
        )
        XCTAssertEqual(
            PrimaryActionCTA.labelKey(planCTA: .startPlan(resolved), sessionType: .strength),
            "verdictCard.start.plan"
        )
        // Pending / none fall through to the recommendation-driven labels, unchanged.
        XCTAssertEqual(
            PrimaryActionCTA.labelKey(planCTA: .pendingDecision, sessionType: .strength),
            "dashboard.cta.startSession"
        )
        XCTAssertEqual(
            PrimaryActionCTA.labelKey(planCTA: .none, sessionType: nil),
            "dashboard.cta.logWorkout"
        )
    }
}
