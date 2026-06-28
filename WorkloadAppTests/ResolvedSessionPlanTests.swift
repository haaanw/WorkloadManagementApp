import XCTest
import SwiftData
@testable import workload_management

/// Verdict → workout loop — the pure `ResolvedSessionPlan.resolve(from:)` resolver.
///
/// Proves the resolution rules in code:
///  - pending / kept-plan sets resolve to AUTHORED weight + RPE;
///  - accepted sets resolve to ADJUSTED weight + RPE (falling back to authored when no adjustment);
///  - adjusted RPE is ignored until the set is accepted;
///  - reps / RIR / duration / distance / warm-up are carried straight from the authored set;
///  - multiple groups/exercises retain deterministic (group-order → exercise-order → set-order) order;
///  - resolving NEVER mutates the prescription or the source template.
///
/// Pure mutation/read on detached `@Model` objects — no `ModelContainer`, no `@MainActor` repository
/// in scope, so the iOS-26.1-sim `@MainActor` deinit SIGABRT cannot occur here.
final class ResolvedSessionPlanTests: XCTestCase {

    // MARK: - Helpers (detached @Model graph)

    /// One authored top set: 140 kg @ RPE 8, with an adjusted suggestion of 130 kg @ RPE 7 and
    /// non-weight targets (reps/RIR/duration/distance/warm-up) set so mapping can be asserted.
    private func makeTopSet() -> TemplateSet {
        let set = TemplateSet(setIndex: 0, targetReps: 5, targetWeightKg: 140, targetRPE: 8, isWarmup: false)
        set.targetRIR = 2
        set.targetDurationSeconds = 90
        set.targetDistanceMeters = 25
        set.adjustedTargetWeightKg = 130
        set.adjustedTargetRPE = 7
        return set
    }

    /// A frozen prescription wrapping the given sets in one exercise / one group.
    private func makePrescription(sets: [TemplateSet]) -> PrescribedWorkout {
        let group = ExerciseGroup(groupName: "Group A", orderIndex: 0)
        let exercise = TemplateExercise(exerciseName: "Back Squat", muscleGroup: .legs, orderIndex: 0)
        exercise.sets = sets
        group.exercises = [exercise]
        let prescription = PrescribedWorkout(
            coachId: UUID(), athleteId: UUID(), templateId: UUID(),
            scheduledDate: .now, templateName: "Leg Day",
            sportType: .lifting, sessionType: .strength
        )
        prescription.groups = [group]
        return prescription
    }

    private func firstSet(_ plan: ResolvedSessionPlan) throws -> ResolvedSessionPlan.ResolvedSet {
        try XCTUnwrap(plan.exercises.first?.sets.first)
    }

    // MARK: - Pending → authored

    func test_pending_resolvesAuthoredWeightAndRPE() throws {
        let set = makeTopSet()                       // verdictAppliedAt == nil
        let resolved = try firstSet(ResolvedSessionPlan.resolve(from: makePrescription(sets: [set])))
        XCTAssertEqual(resolved.weightKg, 140)       // authored, not the 130 suggestion
        XCTAssertEqual(resolved.rpe, 8)              // authored, not the RPE-7 cap
    }

    // MARK: - Accepted → adjusted

    func test_accepted_resolvesAdjustedWeightAndRPE() throws {
        let set = makeTopSet()
        set.verdictReason = "Readiness is lower than baseline."
        VerdictDecisionApplier.applyAccept(to: set, appliedAt: .now)
        let resolved = try firstSet(ResolvedSessionPlan.resolve(from: makePrescription(sets: [set])))
        XCTAssertEqual(resolved.weightKg, 130)
        XCTAssertEqual(resolved.rpe, 7)
        XCTAssertEqual(resolved.plannedWeightKg, 140)
        XCTAssertEqual(resolved.plannedRPE, 8)
        XCTAssertTrue(resolved.isSuggestedAdjustment)
        XCTAssertEqual(resolved.verdictReason, "Readiness is lower than baseline.")
    }

    // MARK: - Keep after accept → back to authored

    func test_keepAfterAccept_resolvesAuthored() throws {
        let set = makeTopSet()
        VerdictDecisionApplier.applyAccept(to: set, appliedAt: .now)
        VerdictDecisionApplier.applyKeepPlan(to: set)
        let resolved = try firstSet(ResolvedSessionPlan.resolve(from: makePrescription(sets: [set])))
        XCTAssertEqual(resolved.weightKg, 140)
        XCTAssertEqual(resolved.rpe, 8)
    }

    // MARK: - Accepted but no adjustment → authored fallback

    func test_acceptedMissingAdjusted_fallsBackToAuthored() throws {
        let set = TemplateSet(setIndex: 0, targetReps: 5, targetWeightKg: 100, targetRPE: 8, isWarmup: false)
        // No adjustedTargetWeightKg / adjustedTargetRPE.
        VerdictDecisionApplier.applyAccept(to: set, appliedAt: .now)
        let resolved = try firstSet(ResolvedSessionPlan.resolve(from: makePrescription(sets: [set])))
        XCTAssertEqual(resolved.weightKg, 100)
        XCTAssertEqual(resolved.rpe, 8)
    }

    // MARK: - Adjusted RPE ignored until accepted

    func test_adjustedRPE_ignoredUntilAccepted() throws {
        let set = TemplateSet(setIndex: 0, targetReps: 5, targetWeightKg: 140, targetRPE: 8, isWarmup: false)
        set.adjustedTargetRPE = 6
        // Pending: authored RPE.
        var resolved = try firstSet(ResolvedSessionPlan.resolve(from: makePrescription(sets: [set])))
        XCTAssertEqual(resolved.rpe, 8)
        // Accepted: the adjusted RPE cap appears.
        VerdictDecisionApplier.applyAccept(to: set, appliedAt: .now)
        resolved = try firstSet(ResolvedSessionPlan.resolve(from: makePrescription(sets: [set])))
        XCTAssertEqual(resolved.rpe, 6)
    }

    // MARK: - Non-weight fields survive mapping

    func test_nonWeightFields_surviveMapping() throws {
        let working = makeTopSet()
        let warmup = TemplateSet(setIndex: 1, targetReps: 8, targetWeightKg: 60, targetRPE: 5, isWarmup: true)
        let resolved = ResolvedSessionPlan.resolve(from: makePrescription(sets: [working, warmup]))
        let sets = try XCTUnwrap(resolved.exercises.first?.sets)
        XCTAssertEqual(sets.count, 2)

        XCTAssertEqual(sets[0].reps, 5)
        XCTAssertEqual(sets[0].rir, 2)
        XCTAssertEqual(sets[0].durationSeconds, 90)
        XCTAssertEqual(sets[0].distanceMeters, 25)
        XCTAssertFalse(sets[0].isWarmup)
        // Warm-up status preserved on the warm-up set.
        XCTAssertTrue(sets[1].isWarmup)
        XCTAssertEqual(sets[1].reps, 8)
    }

    // MARK: - Deterministic order across groups/exercises

    func test_multipleGroupsExercises_retainDeterministicOrder() throws {
        // Group A (order 0): Squat(0), Lunge(1); Group B (order 1): Press(0). Insert OUT of order.
        let squat = TemplateExercise(exerciseName: "Squat", orderIndex: 0)
        squat.sets = [TemplateSet(setIndex: 0, targetReps: 5, targetWeightKg: 100, targetRPE: 8, isWarmup: false)]
        let lunge = TemplateExercise(exerciseName: "Lunge", orderIndex: 1)
        lunge.sets = [TemplateSet(setIndex: 0, targetReps: 8, targetWeightKg: 40, targetRPE: 7, isWarmup: false)]
        let groupA = ExerciseGroup(groupName: "A", orderIndex: 0)
        groupA.exercises = [lunge, squat]                       // reversed on purpose

        let press = TemplateExercise(exerciseName: "Press", orderIndex: 0)
        press.sets = [TemplateSet(setIndex: 0, targetReps: 5, targetWeightKg: 60, targetRPE: 8, isWarmup: false)]
        let groupB = ExerciseGroup(groupName: "B", orderIndex: 1)
        groupB.exercises = [press]

        let prescription = PrescribedWorkout(
            coachId: UUID(), athleteId: UUID(), templateId: UUID(),
            scheduledDate: .now, templateName: "Full Body"
        )
        prescription.groups = [groupB, groupA]                  // reversed on purpose

        let resolved = ResolvedSessionPlan.resolve(from: prescription)
        XCTAssertEqual(resolved.exercises.map { $0.exerciseName }, ["Squat", "Lunge", "Press"])
        XCTAssertEqual(resolved.exercises.map { $0.groupName }, ["A", "A", "B"])
    }

    // MARK: - Identity mapping

    func test_resolve_carriesPrescriptionAndTemplateIdentity() {
        let prescription = makePrescription(sets: [makeTopSet()])
        let resolved = ResolvedSessionPlan.resolve(from: prescription)
        XCTAssertEqual(resolved.prescriptionID, prescription.id)
        XCTAssertEqual(resolved.sourceTemplateID, prescription.templateId)
        XCTAssertEqual(resolved.sessionName, "Leg Day")
        XCTAssertEqual(resolved.sportType, .lifting)
        XCTAssertEqual(resolved.sessionType, .strength)
    }

    // MARK: - Accepted volume cut

    /// warm-up(0,60) · back-off(1,110) · back-off(2,120) · TOP(3,140 → adjusted 130). The top owns
    /// any structured cut; the cut filters lowest-priority back-offs (highest setIndex) first.
    private func volumeSets() -> [TemplateSet] {
        let warmup = TemplateSet(setIndex: 0, targetReps: 8, targetWeightKg: 60, targetRPE: 5, isWarmup: true)
        let backA = TemplateSet(setIndex: 1, targetReps: 5, targetWeightKg: 110, targetRPE: 8, isWarmup: false)
        let backB = TemplateSet(setIndex: 2, targetReps: 5, targetWeightKg: 120, targetRPE: 8, isWarmup: false)
        let top = TemplateSet(setIndex: 3, targetReps: 5, targetWeightKg: 140, targetRPE: 8, isWarmup: false)
        top.adjustedTargetWeightKg = 130
        return [warmup, backA, backB, top]
    }

    private func topOf(_ sets: [TemplateSet]) -> TemplateSet {
        sets.max { ($0.targetWeightKg ?? 0) < ($1.targetWeightKg ?? 0) }!
    }

    func test_acceptedVolumeCut_removesExactCount_keepsTopAndWarmup() throws {
        let sets = volumeSets()
        topOf(sets).adjustedBackoffSetCut = 1
        VerdictDecisionApplier.applyAccept(to: topOf(sets), appliedAt: .now)
        let resolved = try XCTUnwrap(ResolvedSessionPlan.resolve(from: makePrescription(sets: sets)).exercises.first)
        XCTAssertEqual(resolved.sets.count, 3)                       // 4 − 1
        XCTAssertEqual(resolved.sets.map { $0.setIndex }, [0, 1, 3]) // back-off idx 2 dropped (highest)
        XCTAssertTrue(resolved.sets.contains { $0.isWarmup })        // warm-up never removed
        XCTAssertEqual(resolved.sets.last?.weightKg, 130)           // top accepted → adjusted
    }

    func test_keepPlan_retainsAllSets_authoredTopWeight() throws {
        let sets = volumeSets()
        topOf(sets).adjustedBackoffSetCut = 1
        VerdictDecisionApplier.applyKeepPlan(to: topOf(sets))        // declined → no cut
        let resolved = try XCTUnwrap(ResolvedSessionPlan.resolve(from: makePrescription(sets: sets)).exercises.first)
        XCTAssertEqual(resolved.sets.count, 4)
        XCTAssertEqual(resolved.sets.last?.weightKg, 140)
    }

    func test_pendingVolumeCut_notApplied() throws {
        let sets = volumeSets()
        topOf(sets).adjustedBackoffSetCut = 1                       // suggested, NOT accepted
        let resolved = try XCTUnwrap(ResolvedSessionPlan.resolve(from: makePrescription(sets: sets)).exercises.first)
        XCTAssertEqual(resolved.sets.count, 4)
    }

    func test_volumeCut_clampsToAvailableCandidates() throws {
        let sets = volumeSets()
        topOf(sets).adjustedBackoffSetCut = 5                       // > the 2 back-off candidates
        VerdictDecisionApplier.applyAccept(to: topOf(sets), appliedAt: .now)
        let resolved = try XCTUnwrap(ResolvedSessionPlan.resolve(from: makePrescription(sets: sets)).exercises.first)
        XCTAssertEqual(resolved.sets.map { $0.setIndex }, [0, 3])   // only warm-up + top remain
    }

    func test_volumeCut_deterministicDescendingSetIndex() throws {
        let sets = volumeSets()
        topOf(sets).adjustedBackoffSetCut = 1
        VerdictDecisionApplier.applyAccept(to: topOf(sets), appliedAt: .now)
        let resolved = try XCTUnwrap(ResolvedSessionPlan.resolve(from: makePrescription(sets: sets)).exercises.first)
        XCTAssertTrue(resolved.sets.contains { $0.setIndex == 1 })  // backA (lower idx) kept
        XCTAssertFalse(resolved.sets.contains { $0.setIndex == 2 }) // backB (higher idx) cut
    }

    func test_resolve_carriesSourceIDs() throws {
        let prescription = makePrescription(sets: [makeTopSet()])
        let resolved = ResolvedSessionPlan.resolve(from: prescription)
        let ex = try XCTUnwrap(resolved.exercises.first)
        XCTAssertEqual(ex.sourceExerciseID, prescription.allExercises.first?.id)
        XCTAssertEqual(ex.sets.first?.sourceSetID, prescription.allExercises.first?.sortedSets.first?.id)
    }

    func test_mixedPerExercise_onlyCutsAcceptedExercise() throws {
        // Exercise A: top accepted + cut 1 (one back-off dropped). Exercise B: top kept (all retained).
        let aWarm = TemplateSet(setIndex: 0, targetReps: 8, targetWeightKg: 50, targetRPE: 5, isWarmup: true)
        let aBack = TemplateSet(setIndex: 1, targetReps: 5, targetWeightKg: 90, targetRPE: 8, isWarmup: false)
        let aTop = TemplateSet(setIndex: 2, targetReps: 5, targetWeightKg: 120, targetRPE: 8, isWarmup: false)
        aTop.adjustedBackoffSetCut = 1
        VerdictDecisionApplier.applyAccept(to: aTop, appliedAt: .now)
        let exA = TemplateExercise(exerciseName: "Squat", orderIndex: 0); exA.sets = [aWarm, aBack, aTop]

        let bBack = TemplateSet(setIndex: 0, targetReps: 5, targetWeightKg: 40, targetRPE: 8, isWarmup: false)
        let bTop = TemplateSet(setIndex: 1, targetReps: 5, targetWeightKg: 60, targetRPE: 8, isWarmup: false)
        bTop.adjustedBackoffSetCut = 1
        VerdictDecisionApplier.applyKeepPlan(to: bTop)
        let exB = TemplateExercise(exerciseName: "Press", orderIndex: 1); exB.sets = [bBack, bTop]

        let group = ExerciseGroup(groupName: "A", orderIndex: 0); group.exercises = [exA, exB]
        let prescription = PrescribedWorkout(coachId: UUID(), athleteId: UUID(), templateId: UUID(),
                                             scheduledDate: .now, templateName: "Mixed")
        prescription.groups = [group]

        let resolved = ResolvedSessionPlan.resolve(from: prescription)
        XCTAssertEqual(resolved.exercises[0].sets.count, 2)  // A: warm-up + top (one back-off cut)
        XCTAssertEqual(resolved.exercises[1].sets.count, 2)  // B: kept — both sets retained
    }

    // MARK: - Resolver does not mutate

    func test_resolve_doesNotMutatePrescriptionOrSet() {
        let set = makeTopSet()
        _ = ResolvedSessionPlan.resolve(from: makePrescription(sets: [set]))
        // Read-only: the authored + suggestion fields and the decision markers are untouched.
        XCTAssertEqual(set.targetWeightKg, 140)
        XCTAssertEqual(set.targetRPE, 8)
        XCTAssertEqual(set.adjustedTargetWeightKg, 130)
        XCTAssertEqual(set.adjustedTargetRPE, 7)
        XCTAssertNil(set.verdictAppliedAt)
        XCTAssertFalse(set.athleteOverrode)
    }
}
