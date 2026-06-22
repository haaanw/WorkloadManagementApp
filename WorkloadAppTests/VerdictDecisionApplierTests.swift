import XCTest
import SwiftData
@testable import workload_management

/// Phase 44 Plan 01 (Task 1) — slot-invariant tests for the pure `VerdictDecisionApplier`.
///
/// Proves the autonomy guarantees in code:
///  - accept marks `verdictAppliedAt` and NEVER writes the authored `targetWeightKg`;
///  - keep-plan records `athleteOverrode` and leaves the planned number intact;
///  - the effective number resolves at read time (authored wins until accepted);
///  - accept → keep-plan is a clean non-destructive reverse;
///  - the SOURCE authored `WorkoutTemplate` is provably untouched when mutating the frozen copy.
///
/// Pure mutation on detached `@Model` objects — no `ModelContainer` and no `@MainActor` repository
/// in scope, so the iOS-26.1-sim `@MainActor` deinit SIGABRT cannot occur here.
final class VerdictDecisionApplierTests: XCTestCase {

    // MARK: - Helpers (detached @Model graph — no container needed for pure mutation)

    private func makeSet(targetKg: Double = 100, adjustedKg: Double? = 92.5) -> TemplateSet {
        let set = TemplateSet(setIndex: 0, targetReps: 5, targetWeightKg: targetKg, targetRPE: 8, isWarmup: false)
        set.adjustedTargetWeightKg = adjustedKg
        return set
    }

    // MARK: - applyAccept

    func test_applyAccept_setsAppliedAt_clearsOverride_leavesNumbersUnchanged() {
        let set = makeSet(targetKg: 100, adjustedKg: 92.5)
        let when = Date(timeIntervalSince1970: 1_000_000)
        VerdictDecisionApplier.applyAccept(to: set, appliedAt: when)
        XCTAssertEqual(set.verdictAppliedAt, when)
        XCTAssertFalse(set.athleteOverrode)
        XCTAssertEqual(set.targetWeightKg, 100)            // authored number untouched
        XCTAssertEqual(set.adjustedTargetWeightKg, 92.5)   // suggestion untouched
    }

    // MARK: - applyKeepPlan

    func test_applyKeepPlan_setsOverride_clearsAppliedAt_leavesPlanned() {
        let set = makeSet(targetKg: 120, adjustedKg: 110)
        VerdictDecisionApplier.applyKeepPlan(to: set)
        XCTAssertTrue(set.athleteOverrode)
        XCTAssertNil(set.verdictAppliedAt)
        XCTAssertEqual(set.targetWeightKg, 120)
    }

    // MARK: - effectiveTargetKg

    func test_effectiveTargetKg_authoredWinsUntilAccepted() {
        let set = makeSet(targetKg: 100, adjustedKg: 92.5)
        // pending → authored number
        XCTAssertEqual(VerdictDecisionApplier.effectiveTargetKg(set), 100)
        // accepted → adjusted number
        VerdictDecisionApplier.applyAccept(to: set, appliedAt: .now)
        XCTAssertEqual(VerdictDecisionApplier.effectiveTargetKg(set), 92.5)
    }

    func test_effectiveTargetKg_acceptedButNoAdjustment_fallsBackToAuthored() {
        let set = makeSet(targetKg: 100, adjustedKg: nil)
        VerdictDecisionApplier.applyAccept(to: set, appliedAt: .now)
        XCTAssertEqual(VerdictDecisionApplier.effectiveTargetKg(set), 100)
    }

    // MARK: - accept → keep-plan is the clean non-destructive reverse

    func test_acceptThenKeepPlan_flipsStateCleanly() {
        let set = makeSet(targetKg: 100, adjustedKg: 92.5)
        VerdictDecisionApplier.applyAccept(to: set, appliedAt: .now)
        XCTAssertNotNil(set.verdictAppliedAt)
        XCTAssertFalse(set.athleteOverrode)

        VerdictDecisionApplier.applyKeepPlan(to: set)
        XCTAssertNil(set.verdictAppliedAt)        // accept marker cleared
        XCTAssertTrue(set.athleteOverrode)        // decline recorded
        XCTAssertEqual(set.targetWeightKg, 100)   // authored never touched
        // effective number falls back to the authored plan after keep
        XCTAssertEqual(VerdictDecisionApplier.effectiveTargetKg(set), 100)
    }

    // MARK: - VerdictDecision event shape

    func test_verdictDecision_feelStrong_carriesFeelAction() {
        let decision = VerdictDecision(
            action: .feel(.feelingStrong),
            plannedTopSetKg: 100, adjustedTopSetKg: 92.5, hadAdjustment: true,
            reasonLine: "r", decidedAt: .now
        )
        XCTAssertEqual(decision.action, .feel(.feelingStrong))
    }

    func test_verdictDecision_accepted_hadAdjustmentReflectsPlannedVsAdjusted() {
        let planned = 100.0
        let adjustedKg = 92.5
        let adjusted = VerdictDecision(
            action: .accepted, plannedTopSetKg: planned, adjustedTopSetKg: adjustedKg,
            hadAdjustment: adjustedKg < planned, reasonLine: "r", decidedAt: .now
        )
        XCTAssertEqual(adjusted.action, .accepted)
        XCTAssertTrue(adjusted.hadAdjustment)

        let asPlanned = VerdictDecision(
            action: .accepted, plannedTopSetKg: planned, adjustedTopSetKg: planned,
            hadAdjustment: planned < planned, reasonLine: "r", decidedAt: .now
        )
        XCTAssertFalse(asPlanned.hadAdjustment)
    }

    // MARK: - SOURCE authored template provably untouched

    func test_sourceTemplate_untouched_whenApplyingToFrozenCopy() throws {
        // Build a source authored WorkoutTemplate with one top set.
        let template = WorkoutTemplate(coachId: UUID(), templateName: "Leg Day")
        let group = ExerciseGroup(groupName: "Group A", orderIndex: 0)
        let exercise = TemplateExercise(exerciseName: "Back Squat", muscleGroup: .legs, orderIndex: 0)
        let sourceSet = TemplateSet(setIndex: 0, targetReps: 5, targetWeightKg: 140, targetRPE: 8, isWarmup: false)
        exercise.sets = [sourceSet]
        group.exercises = [exercise]
        template.groups = [group]

        // Freeze it into a prescription (deep copy — the same path PlannedSessionRepository uses).
        let prescription = PrescribedWorkout(
            coachId: UUID(), athleteId: UUID(), templateId: template.id,
            scheduledDate: .now, templateName: template.templateName
        )
        prescription.groups = template.deepCopyGroups()
        let frozenSet = try XCTUnwrap(prescription.allExercises.first?.sortedSets.first)
        frozenSet.adjustedTargetWeightKg = 130

        // Mutate the COPY.
        VerdictDecisionApplier.applyAccept(to: frozenSet, appliedAt: .now)
        VerdictDecisionApplier.applyKeepPlan(to: frozenSet)

        // The SOURCE authored set is provably unchanged.
        XCTAssertEqual(sourceSet.targetWeightKg, 140)
        XCTAssertNil(sourceSet.verdictAppliedAt)
        XCTAssertFalse(sourceSet.athleteOverrode)
        XCTAssertNil(sourceSet.adjustedTargetWeightKg)
    }
}
