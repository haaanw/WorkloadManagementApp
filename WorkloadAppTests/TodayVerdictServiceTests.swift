import XCTest
import SwiftData
@testable import workload_management

/// Phase 43 Plan 03 (Task 2) — tests for `TodayVerdictService`: read today's planned session, run the
/// two pure engines, and WRITE the verdict SUGGESTION into the Phase-42 `TemplateSet` verdict slots
/// (adjustedTargetWeightKg / adjustedTargetRPE / verdictReason) — never `verdictAppliedAt` /
/// `athleteOverrode`, never the source authored template.
///
/// Follows the `@MainActor`-repo XCTest lifetime pattern (own ModelContainer/ModelContext/Service as
/// stored props, set in setUp, cleared in tearDown) to avoid the iOS 26.1-sim `@MainActor` deinit
/// crash.
@MainActor
final class TodayVerdictServiceTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var service: TodayVerdictService!

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
        service = TodayVerdictService(modelContext: context)
    }

    override func tearDown() {
        service = nil
        context = nil
        container = nil
        super.tearDown()
    }

    // MARK: - Fixtures

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    /// A prescribed workout with one strength exercise (`.legs`) carrying a top set at `weightKg`
    /// (+RPE) plus a back-off set; optionally a SECOND exercise whose top set has nil RPE.
    private func makePrescription(
        athleteId: UUID = UUID(),
        topWeightKg: Double = 100,
        topRPE: Double? = 8,
        scheduledDate: Date = .now,
        secondExerciseNilRPE: Bool = false,
        secondMuscleGroupNil: Bool = false
    ) -> PrescribedWorkout {
        let workout = PrescribedWorkout(
            coachId: athleteId, athleteId: athleteId, templateId: UUID(),
            scheduledDate: scheduledDate, templateName: "Leg Day"
        )
        let group = ExerciseGroup(groupName: "Group A", orderIndex: 0)

        let squat = TemplateExercise(exerciseName: "Back Squat", muscleGroup: .legs, orderIndex: 0)
        squat.sets = [
            TemplateSet(setIndex: 0, targetReps: 5, targetWeightKg: topWeightKg, targetRPE: topRPE, isWarmup: false),
            TemplateSet(setIndex: 1, targetReps: 5, targetWeightKg: topWeightKg - 10, targetRPE: topRPE, isWarmup: false)
        ]
        var exercises = [squat]

        if secondExerciseNilRPE {
            let press = TemplateExercise(
                exerciseName: "Overhead Press",
                muscleGroup: secondMuscleGroupNil ? nil : .shoulders,
                orderIndex: 1
            )
            press.sets = [
                TemplateSet(setIndex: 0, targetReps: 5, targetWeightKg: 50, targetRPE: nil, isWarmup: false)
            ]
            exercises.append(press)
        }

        group.exercises = exercises
        workout.groups = [group]
        context.insert(workout)
        try? context.save()
        return workout
    }

    private func topSet(of workout: PrescribedWorkout, exerciseIndex: Int = 0) -> TemplateSet {
        let exercise = workout.allExercises[exerciseIndex]
        return exercise.sortedSets.max { ($0.targetWeightKg ?? 0) < ($1.targetWeightKg ?? 0) }!
    }

    /// A DecisionInput warranting a MODIFY trim (clearly down).
    private func modifyDecisionInput() -> ReasoningEngine.DecisionInput {
        let readiness = ReadinessFusionEngine.compute(.init(hrvZ: -1.6, rhrZ: -0.6, sleepZ: -0.8, confidence: 0.7))
        let strain = StrainRiskEngine.StrainRiskResult(
            score: 0.6, zone: StrainRiskEngine.zone(for: 0.6),
            factors: [.init(label: "Per-muscle strength-load elevation", contribution: 0.2)],
            confidence: 0.6
        )
        // volumeModifier 0.6 → clear LOAD trim; intensityCap 7 → caps an RPE-8 plan down to 7.
        let rec = AutoregulationEngine.TrainingRecommendation(
            intensityCap: 7, volumeModifier: 0.6, sessionType: .conditioning,
            warnings: [], headline: "Stay Controlled", detail: "..."
        )
        return ReasoningEngine.DecisionInput(readiness: readiness, strainRisk: strain, recommendation: rec)
    }

    private func fatigueResult(index: Double = 40) -> FatigueIndexEngine.FatigueResult {
        FatigueIndexEngine.FatigueResult(
            index: index, zone: FatigueIndexEngine.FatigueZone.classify(index: index),
            loadElevation: 0.4, sessionDensity: 0.3, recoveryTrend: 0.4,
            restDebt: 0.2, wellnessTrend: 0.3, softTissueRisk: 0.1
        )
    }

    private func populatedSnapshots(asOf: Date) -> [RecoverySnapshot] {
        (1...20).map { i in
            let jitter = Double((i % 5)) - 2.0
            return RecoverySnapshot(
                date: calendar.date(byAdding: .day, value: -i, to: asOf)!,
                hrvSDNN: 60 + jitter, restingHR: 55 + jitter * 0.5,
                sleepDurationMinutes: 420 + jitter * 10, recoveryScore: 55
            )
        }
    }

    // MARK: - Slot-write happy path (VERDICT-01/02/03)

    func test_evaluateAndWrite_writesAdjustedWeight_plateRounded_belowPlanned_withinBound() {
        let workout = makePrescription(topWeightKg: 100, topRPE: 8)
        _ = service.evaluateAndWrite(
            prescribedWorkout: workout,
            decisionInput: modifyDecisionInput(),
            crossModalResult: nil,
            plateStepKg: 2.5
        )
        let top = topSet(of: workout)
        let adjusted = try? XCTUnwrap(top.adjustedTargetWeightKg)
        XCTAssertNotNil(adjusted)
        guard let adj = adjusted else { return }
        XCTAssertLessThan(adj, 100)
        XCTAssertGreaterThanOrEqual(adj, 100 * 0.90 - 1e-9)
        // plate multiple of 2.5
        XCTAssertEqual(adj, (adj / 2.5).rounded() * 2.5, accuracy: 1e-9)
    }

    func test_evaluateAndWrite_writesSingleLineReason() {
        let workout = makePrescription()
        _ = service.evaluateAndWrite(
            prescribedWorkout: workout, decisionInput: modifyDecisionInput(),
            crossModalResult: nil, plateStepKg: 2.5
        )
        let reason = topSet(of: workout).verdictReason
        XCTAssertNotNil(reason)
        XCTAssertFalse(reason?.contains("\n") ?? true)
    }

    func test_evaluateAndWrite_neverSetsVerdictAppliedAt_orAthleteOverrode() {
        let workout = makePrescription()
        _ = service.evaluateAndWrite(
            prescribedWorkout: workout, decisionInput: modifyDecisionInput(),
            crossModalResult: nil, plateStepKg: 2.5
        )
        let top = topSet(of: workout)
        XCTAssertNil(top.verdictAppliedAt)
        XCTAssertFalse(top.athleteOverrode)
    }

    // MARK: - nil-RPE handling (WARNING-3)

    func test_nilPlannedRPE_leavesAdjustedRPENil_butNonNilRPEGetsDownwardCap() {
        let workout = makePrescription(topWeightKg: 100, topRPE: 8, secondExerciseNilRPE: true)
        _ = service.evaluateAndWrite(
            prescribedWorkout: workout, decisionInput: modifyDecisionInput(),
            crossModalResult: nil, plateStepKg: 2.5
        )
        // Exercise 0 has RPE 8, recommendation cap 7 → downward cap to 7.
        let first = topSet(of: workout, exerciseIndex: 0)
        XCTAssertEqual(first.adjustedTargetRPE ?? -1, 7, accuracy: 1e-9)
        // Exercise 1 had nil planned RPE → adjustedTargetRPE stays nil (no bare cap emitted).
        let second = topSet(of: workout, exerciseIndex: 1)
        XCTAssertNil(second.adjustedTargetRPE)
    }

    // MARK: - Plan never overwritten

    func test_sourcePlanNumbers_unchanged_onlyAdjustedSlotsWritten() {
        let workout = makePrescription(topWeightKg: 120, topRPE: 9)
        _ = service.evaluateAndWrite(
            prescribedWorkout: workout, decisionInput: modifyDecisionInput(),
            crossModalResult: nil, plateStepKg: 2.5
        )
        let top = topSet(of: workout)
        // The frozen plan numbers are untouched (only adjusted* slots changed).
        XCTAssertEqual(top.targetWeightKg ?? -1, 120, accuracy: 1e-9)
        XCTAssertEqual(top.targetRPE ?? -1, 9, accuracy: 1e-9)
    }

    // MARK: - Per-lift region selection

    func test_nilMuscleGroup_treatedAsFullBody_noCrash() {
        // Second exercise has a nil muscleGroup → region falls back to .fullBody, still produces a verdict.
        let workout = makePrescription(secondExerciseNilRPE: true, secondMuscleGroupNil: true)
        let results = service.evaluateAndWrite(
            prescribedWorkout: workout, decisionInput: modifyDecisionInput(),
            crossModalResult: nil, plateStepKg: 2.5
        )
        XCTAssertGreaterThanOrEqual(results.count, 2)
    }

    // MARK: - Cold-start defer (locked)

    func test_coldStartDefer_suggestionEqualsPlan_nilRPE_deferCopy() {
        let workout = makePrescription(topWeightKg: 100, topRPE: 8)
        _ = service.evaluateAndWrite(
            prescribedWorkout: workout,
            decisionInput: nil,           // cold-start
            crossModalResult: nil, plateStepKg: 2.5
        )
        let top = topSet(of: workout)
        // No trim on a guess: suggestion equals the plan.
        XCTAssertEqual(top.adjustedTargetWeightKg ?? -1, 100, accuracy: 1e-9)
        XCTAssertNil(top.adjustedTargetRPE)   // a defer caps nothing
        XCTAssertNotNil(top.verdictReason)
        XCTAssertTrue((top.verdictReason ?? "").lowercased().contains("plan"))
    }

    // MARK: - Gate-off cross-modal = zero

    func test_gateOff_crossModal_identicalWrite_withOrWithoutResult() {
        let legLoaded = CrossModalFatigueEngine.CrossModalResult(
            perRegionCarry: [.legs: 500], perRegionElevation: [.legs: 0.9],
            systemicFactor: 0.9, dominantReason: "legs still loaded from recent cross-modal work"
        )
        let w1 = makePrescription(topWeightKg: 100, topRPE: 8)
        _ = service.evaluateAndWrite(prescribedWorkout: w1, decisionInput: modifyDecisionInput(),
                                     crossModalResult: legLoaded, plateStepKg: 2.5)
        let withResult = topSet(of: w1).adjustedTargetWeightKg

        let w2 = makePrescription(topWeightKg: 100, topRPE: 8)
        _ = service.evaluateAndWrite(prescribedWorkout: w2, decisionInput: modifyDecisionInput(),
                                     crossModalResult: nil, plateStepKg: 2.5)
        let withNil = topSet(of: w2).adjustedTargetWeightKg

        XCTAssertEqual(withResult ?? -1, withNil ?? -2, accuracy: 0.0)
    }

    // MARK: - makeDecisionInput assembly helper (the live reason seam)

    func test_makeDecisionInput_assemblesRealDecisionInput_fromBuiltReadiness() {
        let asOf = DateComponents(calendar: calendar, year: 2026, month: 3, day: 15).date!
        let built = PRSReadinessInputBuilder.buildDetailed(
            recentSnapshots: populatedSnapshots(asOf: asOf),
            latestHRV: 58, latestRHR: 56, latestSleepMinutes: 410,
            allSessions: [], fatigueResult: fatigueResult(), daysSinceRest: 1,
            wellnessScore: nil, acwr: 1.0, acwrZone: .optimal, asOf: asOf, calendar: calendar
        )
        let b = try? XCTUnwrap(built)
        guard let built = b else { return XCTFail("buildDetailed nil on populated athlete") }
        let rec = AutoregulationEngine.recommendReadiness(input: built.input)
        let di = service.makeDecisionInput(built: built, recommendation: rec)
        // The assembled DecisionInput carries the REAL fused results (not defaulted).
        XCTAssertEqual(di.readiness.zone, built.readiness.zone)
        XCTAssertEqual(di.strainRisk.zone, built.strain.zone)
        XCTAssertEqual(di.recommendation.intensityCap, rec.intensityCap, accuracy: 1e-9)
    }

    // MARK: - PRODUCTION wrapper reason path (sources the live VERDICT-03 seam)

    func test_productionWrapper_writesReasonFromRealDecisionInput_onPopulatedAthlete() {
        let athleteId = UUID()
        let asOf = Date()   // real today so fetchTodaysPlannedSession finds it
        let workout = makePrescription(athleteId: athleteId, topWeightKg: 100, topRPE: 8, scheduledDate: asOf)
        _ = workout  // inserted

        let results = service.evaluateTodaysPlannedSession(
            athleteId: athleteId,
            recentSnapshots: populatedSnapshots(asOf: asOf),
            latestHRV: 58, latestRHR: 56, latestSleepMinutes: 410,
            allSessions: [], fatigueResult: fatigueResult(), daysSinceRest: 1,
            acwr: 1.0, acwrZone: .optimal, asOf: asOf, calendar: .current
        )
        XCTAssertNotNil(results)
        let top = topSet(of: workout)
        XCTAssertNotNil(top.verdictReason)
        // The live reason is sourced from the real DecisionInput → NOT the cold-start defer copy.
        let lower = (top.verdictReason ?? "").lowercased()
        XCTAssertFalse(lower.contains("still learning your baseline"))
    }

    func test_productionWrapper_coldStart_defersEndToEnd() {
        let athleteId = UUID()
        let asOf = Date()
        let workout = makePrescription(athleteId: athleteId, topWeightKg: 100, topRPE: 8, scheduledDate: asOf)

        let results = service.evaluateTodaysPlannedSession(
            athleteId: athleteId,
            recentSnapshots: [],            // empty history → buildDetailed nil → defer
            latestHRV: 58, latestRHR: 56, latestSleepMinutes: 410,
            allSessions: [], fatigueResult: fatigueResult(), daysSinceRest: 1,
            acwr: 1.0, acwrZone: .optimal, asOf: asOf, calendar: .current
        )
        XCTAssertNotNil(results)
        let top = topSet(of: workout)
        // Cold-start defers end-to-end: plan-equal suggestion + defer copy.
        XCTAssertEqual(top.adjustedTargetWeightKg ?? -1, 100, accuracy: 1e-9)
        XCTAssertNil(top.adjustedTargetRPE)
        XCTAssertTrue((top.verdictReason ?? "").lowercased().contains("plan"))
    }

    // MARK: - Honesty fence

    func test_service_neverSaysInjuryPrediction_sourceGrep() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        for rel in ["WorkloadApp/Services/TodayVerdictService.swift",
                    "WorkloadApp/Services/PRSReadinessInputBuilder.swift"] {
            let source = try String(contentsOf: root.appendingPathComponent(rel), encoding: .utf8).lowercased()
            XCTAssertFalse(source.contains("injury prediction"), "\(rel) contains 'injury prediction'")
            XCTAssertFalse(source.contains("injury risk"), "\(rel) contains 'injury risk'")
        }
    }

    // MARK: - Structured volume cut (executable, not just reason text)

    /// volumeModifier 0.90 ∈ [0.85, 0.95) ⇒ VOLUME-CUT-PREFERRED (keep the top-set load, cut a
    /// back-off set). intensityCap 8 == the plan's RPE 8 ⇒ no RPE change.
    private func volumeCutDecisionInput() -> ReasoningEngine.DecisionInput {
        let readiness = ReadinessFusionEngine.compute(.init(hrvZ: -0.8, rhrZ: -0.3, sleepZ: -0.4, confidence: 0.7))
        let strain = StrainRiskEngine.StrainRiskResult(
            score: 0.4, zone: StrainRiskEngine.zone(for: 0.4),
            factors: [.init(label: "Per-muscle strength-load elevation", contribution: 0.1)],
            confidence: 0.6
        )
        let rec = AutoregulationEngine.TrainingRecommendation(
            intensityCap: 8, volumeModifier: 0.90, sessionType: .conditioning,
            warnings: [], headline: "Trim Volume", detail: "..."
        )
        return ReasoningEngine.DecisionInput(readiness: readiness, strainRisk: strain, recommendation: rec)
    }

    func test_evaluateAndWrite_volumeCut_writesStructuredCut_noWeightTrim() {
        let workout = makePrescription()
        _ = service.evaluateAndWrite(prescribedWorkout: workout, decisionInput: volumeCutDecisionInput(), crossModalResult: nil)
        let top = topSet(of: workout)
        XCTAssertEqual(top.adjustedBackoffSetCut, 2, "volumeModifier 0.90 ⇒ 2 back-off sets")
        XCTAssertEqual(top.adjustedTargetWeightKg ?? 0, 100, accuracy: 1e-9, "volume-cut-preferred keeps the top load")
    }

    func test_evaluateAndWrite_nonVolumeReeval_clearsStaleCut() {
        let workout = makePrescription()
        _ = service.evaluateAndWrite(prescribedWorkout: workout, decisionInput: volumeCutDecisionInput(), crossModalResult: nil)
        XCTAssertNotNil(topSet(of: workout).adjustedBackoffSetCut)
        // A clearly-down (load-trim) re-eval has no volume cut → the stale cut must be cleared.
        _ = service.evaluateAndWrite(prescribedWorkout: workout, decisionInput: modifyDecisionInput(), crossModalResult: nil)
        XCTAssertNil(topSet(of: workout).adjustedBackoffSetCut)
    }

    func test_evaluateAndWrite_coldStartDefer_clearsCut() {
        let workout = makePrescription()
        _ = service.evaluateAndWrite(prescribedWorkout: workout, decisionInput: volumeCutDecisionInput(), crossModalResult: nil)
        _ = service.evaluateAndWrite(prescribedWorkout: workout, decisionInput: nil, crossModalResult: nil)
        XCTAssertNil(topSet(of: workout).adjustedBackoffSetCut, "cold-start defer cuts no volume")
    }
}
