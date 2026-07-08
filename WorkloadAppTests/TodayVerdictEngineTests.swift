import XCTest
@testable import workload_management

/// Phase 43 Plan 01 (VERDICT-01 / VERDICT-02) — unit tests for the pure `TodayVerdictEngine`.
///
/// Proves the verdict CORE: collapse the existing `AutoregulationEngine.TrainingRecommendation`
/// into a go / modify / hold trichotomy (VERDICT-01), and compute a concrete, evidence-bounded,
/// plate-rounded adjusted top-set number / back-off volume cut (VERDICT-02). The engine is a pure
/// DERIVED function — a Foundation-only value-test, no ModelContainer needed.
///
/// Cross-modal is wired through `CrossModalShadowGate`; gate-off still contributes EXACTLY ZERO,
/// while gate-on can only tighten inside the locked bounds.
final class TodayVerdictEngineTests: XCTestCase {

    // MARK: - Fixtures

    /// Construct a `TrainingRecommendation` via its memberwise init.
    private func recommendation(
        cap: Double,
        vol: Double,
        type: AutoregulationEngine.TrainingRecommendation.RecommendedSessionType = .strength
    ) -> AutoregulationEngine.TrainingRecommendation {
        AutoregulationEngine.TrainingRecommendation(
            intensityCap: cap,
            volumeModifier: vol,
            sessionType: type,
            warnings: [],
            headline: "H",
            detail: "D"
        )
    }

    private func plannedTopSet(
        kg: Double = 100.0,
        region: MuscleRegion = .legs,
        reps: Int? = 5,
        rpe: Double? = 8.0
    ) -> TodayVerdictEngine.PlannedTopSet {
        TodayVerdictEngine.PlannedTopSet(
            exerciseName: "Back Squat",
            region: region,
            plannedTopSetKg: kg,
            plannedReps: reps,
            plannedRPE: rpe
        )
    }

    private let plateStep = 2.5

    // MARK: - VERDICT-01 mapping

    func test_fullRecommendation_isGo_atPlannedWeight() {
        let rec = recommendation(cap: 9.0, vol: 1.0, type: .strength)
        let result = TodayVerdictEngine.evaluate(
            recommendation: rec,
            plannedTopSet: plannedTopSet(kg: 100, rpe: 8),
            crossModalResult: nil,
            plateStepKg: plateStep
        )
        XCTAssertEqual(result.verdict, .go)
        XCTAssertEqual(result.adjustedTopSetKg, 100, accuracy: 1e-9)
        XCTAssertEqual(result.loadFactor, 1.0, accuracy: 1e-9)
        XCTAssertNil(result.volumeCutSets)
    }

    func test_mildVolumeCut_isModify_keepsTopSet_cutsBackoff() {
        // volumeModifier in [0.85, 0.95), intensity near planned → volume-cut-preferred.
        let rec = recommendation(cap: 8.0, vol: 0.85, type: .hypertrophy)
        let result = TodayVerdictEngine.evaluate(
            recommendation: rec,
            plannedTopSet: plannedTopSet(kg: 100, rpe: 8),
            crossModalResult: nil,
            plateStepKg: plateStep
        )
        XCTAssertEqual(result.verdict, .modify)
        XCTAssertEqual(result.loadFactor, 1.0, accuracy: 1e-9)        // top-set load unchanged
        XCTAssertEqual(result.adjustedTopSetKg, 100, accuracy: 1e-9)  // weight unchanged
        XCTAssertNotNil(result.volumeCutSets)
        XCTAssertGreaterThanOrEqual(result.volumeCutSets ?? 0, 1)
    }

    func test_clearLoadTrim_isModify_movesWeightBelowPlanned() {
        // volumeModifier well below 0.85 → real LOAD trim.
        let rec = recommendation(cap: 6.0, vol: 0.6, type: .conditioning)
        let result = TodayVerdictEngine.evaluate(
            recommendation: rec,
            plannedTopSet: plannedTopSet(kg: 100, rpe: 8),
            crossModalResult: nil,
            plateStepKg: plateStep
        )
        XCTAssertEqual(result.verdict, .modify)
        XCTAssertLessThan(result.adjustedTopSetKg, 100)
    }

    func test_restSession_isHold_carriesPlannedNumber() {
        let rec = recommendation(cap: 5.0, vol: 0.0, type: .rest)
        let result = TodayVerdictEngine.evaluate(
            recommendation: rec,
            plannedTopSet: plannedTopSet(kg: 100, rpe: 8),
            crossModalResult: nil,
            plateStepKg: plateStep
        )
        XCTAssertEqual(result.verdict, .hold)
        // HOLD is "the number" — planned top set held, never nil / "don't train".
        XCTAssertEqual(result.adjustedTopSetKg, 100, accuracy: 1e-9)
        XCTAssertEqual(result.loadFactor, 1.0, accuracy: 1e-9)
        XCTAssertNil(result.volumeCutSets)
    }

    func test_activeRecoverySession_isHold_carriesPlannedNumber() {
        let rec = recommendation(cap: 5.0, vol: 0.5, type: .activeRecovery)
        let result = TodayVerdictEngine.evaluate(
            recommendation: rec,
            plannedTopSet: plannedTopSet(kg: 120, rpe: 9),
            crossModalResult: nil,
            plateStepKg: plateStep
        )
        XCTAssertEqual(result.verdict, .hold)
        XCTAssertEqual(result.adjustedTopSetKg, 120, accuracy: 1e-9)
    }

    // MARK: - VERDICT-02 bounds + plate rounding

    func test_deepCut_isFlooredAt_minus10Percent_ceiling() {
        // A recommendation implying a very deep cut still floors the LOAD trim at −10%.
        let rec = recommendation(cap: 5.0, vol: 0.0, type: .conditioning)
        let result = TodayVerdictEngine.evaluate(
            recommendation: rec,
            plannedTopSet: plannedTopSet(kg: 100, rpe: 8),
            crossModalResult: nil,
            plateStepKg: plateStep
        )
        XCTAssertGreaterThanOrEqual(result.adjustedTopSetKg, 100 * 0.90 - 1e-9)
    }

    func test_defaultTrim_isMinus5Percent_atModifyBoundary() {
        // "modify but mild": volumeModifier just below 0.85 triggers the default −5% trim.
        let rec = recommendation(cap: 8.0, vol: 0.849, type: .strength)
        let result = TodayVerdictEngine.evaluate(
            recommendation: rec,
            plannedTopSet: plannedTopSet(kg: 200, rpe: 8),
            crossModalResult: nil,
            plateStepKg: plateStep
        )
        // 200 * 0.95 = 190, already a plate multiple. Default trim ≈ −5%.
        XCTAssertEqual(result.adjustedTopSetKg, 190, accuracy: plateStep)
        XCTAssertGreaterThanOrEqual(result.adjustedTopSetKg, 200 * 0.90 - 1e-9)
    }

    func test_adjustedWeight_isPlateMultiple_andNeverRoundsUpPastPlanned() {
        let rec = recommendation(cap: 6.0, vol: 0.5, type: .conditioning)
        let result = TodayVerdictEngine.evaluate(
            recommendation: rec,
            plannedTopSet: plannedTopSet(kg: 102.5, rpe: 8),
            crossModalResult: nil,
            plateStepKg: plateStep
        )
        // multiple of 2.5
        let remainder = (result.adjustedTopSetKg / plateStep).rounded() * plateStep
        XCTAssertEqual(result.adjustedTopSetKg, remainder, accuracy: 1e-9)
        // never rounded UP past the plan when trimming
        XCTAssertLessThanOrEqual(result.adjustedTopSetKg, 102.5 + 1e-9)
    }

    func test_subIncrementDelta_collapsesToGo_noFalseChange() {
        // A trim smaller than one plate step must collapse to GO with the planned weight.
        // 50kg * 0.95 = 47.5 — that IS a plate step away. Use a tiny planned weight so the raw
        // delta is < 2.5kg: 20kg * 0.95 = 19.0 → delta 1.0 < plate step → GO.
        let rec = recommendation(cap: 8.0, vol: 0.84, type: .strength)
        let result = TodayVerdictEngine.evaluate(
            recommendation: rec,
            plannedTopSet: plannedTopSet(kg: 20, rpe: 8),
            crossModalResult: nil,
            plateStepKg: plateStep
        )
        XCTAssertEqual(result.verdict, .go)
        XCTAssertEqual(result.adjustedTopSetKg, 20, accuracy: 1e-9)
    }

    func test_trimSnap_floorsToPlateStep_neverAboveTheCappedValue() {
        // REGRESSION (floor-snap on trim): planned 102.5, mild clearly-down trim ≈ −5% ⇒ capped
        // value ≈ 97.37. Nearest-snap used to round back UP to 97.5 — ABOVE the cap. Trims must
        // floor to the plate step: 95.0 (the heaviest loadable weight not exceeding the cap).
        let rec = recommendation(cap: 8.0, vol: 0.849, type: .strength)
        let result = TodayVerdictEngine.evaluate(
            recommendation: rec,
            plannedTopSet: plannedTopSet(kg: 102.5, rpe: 8),
            crossModalResult: nil,
            plateStepKg: plateStep
        )
        XCTAssertEqual(result.verdict, .modify)
        XCTAssertEqual(result.adjustedTopSetKg, 95.0, accuracy: 1e-9)
        // The invariant itself: the plate-snapped number never exceeds the capped raw value.
        XCTAssertLessThanOrEqual(result.adjustedTopSetKg, 102.5 * result.loadFactor + 1e-9)
    }

    func test_deepTrimSnap_neverAboveTheMinus10PercentCeilingValue() {
        // REGRESSION (floor-snap at the −10% hard ceiling): planned 102.5, deepest cut ⇒
        // effectiveFactor clamps to 0.90 ⇒ ceiling value 92.25. Nearest-snap used to give 92.5 —
        // above the ceiling. Floor-snap gives 90.0.
        let rec = recommendation(cap: 5.0, vol: 0.0, type: .conditioning)
        let result = TodayVerdictEngine.evaluate(
            recommendation: rec,
            plannedTopSet: plannedTopSet(kg: 102.5, rpe: 8),
            crossModalResult: nil,
            plateStepKg: plateStep
        )
        XCTAssertEqual(result.verdict, .modify)
        XCTAssertEqual(result.loadFactor, 0.90, accuracy: 1e-9)
        XCTAssertEqual(result.adjustedTopSetKg, 90.0, accuracy: 1e-9)
        XCTAssertLessThanOrEqual(result.adjustedTopSetKg, 102.5 * 0.90 + 1e-9)
    }

    func test_trimSnap_exactPlateMultiple_staysPut_noFloatCliff() {
        // Floor-snap must not drop a whole plate step when the capped value lands EXACTLY on a
        // multiple — the epsilon guard in `floorToIncrement`. The proximity cap produces the exact
        // −5% factor: 100 × 0.95 = 95.0 must stay 95.0, never cliff down to 92.5.
        let rec = recommendation(cap: 9.0, vol: 1.0, type: .strength)
        let result = TodayVerdictEngine.evaluate(
            recommendation: rec,
            plannedTopSet: plannedTopSet(kg: 100, rpe: 8),
            crossModalResult: nil,
            plateStepKg: plateStep,
            matchDaysAway: 1,
            plannedWorkingSetCount: 3
        )
        XCTAssertEqual(result.adjustedTopSetKg, 95.0, accuracy: 1e-9)
    }

    func test_volumeCutPreferred_overLoadCut_whenMildlyDown() {
        // volumeModifier in [0.85, 0.95), intensity near planned → keep top set, cut a back-off set.
        let rec = recommendation(cap: 8.0, vol: 0.90, type: .hypertrophy)
        let result = TodayVerdictEngine.evaluate(
            recommendation: rec,
            plannedTopSet: plannedTopSet(kg: 140, rpe: 8),
            crossModalResult: nil,
            plateStepKg: plateStep
        )
        XCTAssertNotNil(result.volumeCutSets)
        XCTAssertEqual(result.adjustedTopSetKg, 140, accuracy: 1e-9)  // top-set load unchanged
    }

    // MARK: - Cross-modal gate

    func test_gateOff_crossModalContributesZero_identicalToNil() {
        let rec = recommendation(cap: 6.0, vol: 0.6, type: .conditioning)
        // A leg-loaded cross-modal result that WOULD trim legs if the gate were on.
        let legLoaded = CrossModalFatigueEngine.CrossModalResult(
            perRegionCarry: [.legs: 500],
            perRegionElevation: [.legs: 0.8],
            systemicFactor: 0.9,
            dominantReason: "legs still loaded from recent cross-modal work"
        )
        let withResult = CrossModalShadowGate.withEnabled(false) {
            TodayVerdictEngine.evaluate(
                recommendation: rec,
                plannedTopSet: plannedTopSet(kg: 100, region: .legs, rpe: 8),
                crossModalResult: legLoaded,
                plateStepKg: plateStep
            )
        }
        let withNil = CrossModalShadowGate.withEnabled(false) {
            TodayVerdictEngine.evaluate(
                recommendation: rec,
                plannedTopSet: plannedTopSet(kg: 100, region: .legs, rpe: 8),
                crossModalResult: nil,
                plateStepKg: plateStep
            )
        }
        // Gate OFF ⇒ cross-modal contributes exactly 0 ⇒ byte-identical adjusted weight.
        XCTAssertEqual(withResult.adjustedTopSetKg, withNil.adjustedTopSetKg, accuracy: 0.0)
        XCTAssertEqual(withResult.loadFactor, withNil.loadFactor, accuracy: 0.0)
    }

    func test_gateOn_crossModalLegPenalty_tightensSquat_sparesUpperBody() {
        let rec = recommendation(cap: 9.0, vol: 1.0, type: .strength)
        let legLoaded = CrossModalFatigueEngine.CrossModalResult(
            perRegionCarry: [.legs: 500],
            perRegionElevation: [.legs: 0.8],
            systemicFactor: 1.0,
            dominantReason: "legs still loaded from recent cross-modal work"
        )
        let squat = TodayVerdictEngine.evaluate(
            recommendation: rec,
            plannedTopSet: plannedTopSet(kg: 200, region: .legs, rpe: 8),
            crossModalResult: legLoaded,
            plateStepKg: plateStep
        )
        let bench = TodayVerdictEngine.evaluate(
            recommendation: rec,
            plannedTopSet: plannedTopSet(kg: 200, region: .chest, rpe: 8),
            crossModalResult: legLoaded,
            plateStepKg: plateStep
        )

        XCTAssertEqual(squat.verdict, .modify)
        XCTAssertLessThan(squat.adjustedTopSetKg, 200)
        XCTAssertEqual(bench.verdict, .go)
        XCTAssertEqual(bench.adjustedTopSetKg, 200, accuracy: 1e-9)
    }

    func test_gateOn_crossModal_trimsAtMost_notMore() {
        let rec = recommendation(cap: 6.0, vol: 0.6, type: .conditioning)
        let legLoaded = CrossModalFatigueEngine.CrossModalResult(
            perRegionCarry: [.legs: 500],
            perRegionElevation: [.legs: 0.8],
            systemicFactor: 0.9,
            dominantReason: "legs still loaded from recent cross-modal work"
        )
        let gateOff = CrossModalShadowGate.withEnabled(false) {
            TodayVerdictEngine.evaluate(
                recommendation: rec,
                plannedTopSet: plannedTopSet(kg: 100, region: .legs, rpe: 8),
                crossModalResult: legLoaded,
                plateStepKg: plateStep
            )
        }
        let gateOn = CrossModalShadowGate.withEnabled(true) {
            TodayVerdictEngine.evaluate(
                recommendation: rec,
                plannedTopSet: plannedTopSet(kg: 100, region: .legs, rpe: 8),
                crossModalResult: legLoaded,
                plateStepKg: plateStep
            )
        }
        // Gate-on trims AT MOST as much as
        // gate-off (heuristic magnitude — tolerant <= comparison, never tighter than the floor).
        XCTAssertLessThanOrEqual(gateOn.adjustedTopSetKg, gateOff.adjustedTopSetKg + 1e-9)
        XCTAssertGreaterThanOrEqual(gateOn.adjustedTopSetKg, 100 * 0.90 - 1e-9)
    }

    func test_gateOn_crossModal_cannotPushBelowMinus10PercentCeiling() {
        let rec = recommendation(cap: 5.0, vol: 0.0, type: .conditioning)
        let severeCarry = CrossModalFatigueEngine.CrossModalResult(
            perRegionCarry: [.legs: 2_000],
            perRegionElevation: [.legs: 1.0],
            systemicFactor: 0.85,
            dominantReason: "legs still loaded from recent cross-modal work"
        )
        let result = TodayVerdictEngine.evaluate(
            recommendation: rec,
            plannedTopSet: plannedTopSet(kg: 200, region: .legs, rpe: 8),
            crossModalResult: severeCarry,
            plateStepKg: plateStep
        )

        XCTAssertEqual(result.loadFactor, 0.90, accuracy: 1e-9)
        XCTAssertGreaterThanOrEqual(result.adjustedTopSetKg, 200 * 0.90 - 1e-9)
    }

    func test_gateOn_crossModal_cannotLoosenEvenWithMalformedFactor() {
        let rec = recommendation(cap: 6.0, vol: 0.6, type: .conditioning)
        let malformedLoosening = CrossModalFatigueEngine.CrossModalResult(
            perRegionCarry: [.legs: 1],
            perRegionElevation: [:],
            systemicFactor: 1.2,
            dominantReason: nil
        )
        let baseline = TodayVerdictEngine.evaluate(
            recommendation: rec,
            plannedTopSet: plannedTopSet(kg: 200, region: .legs, rpe: 8),
            crossModalResult: nil,
            plateStepKg: plateStep
        )
        let withCrossModal = TodayVerdictEngine.evaluate(
            recommendation: rec,
            plannedTopSet: plannedTopSet(kg: 200, region: .legs, rpe: 8),
            crossModalResult: malformedLoosening,
            plateStepKg: plateStep
        )

        XCTAssertLessThanOrEqual(withCrossModal.loadFactor, baseline.loadFactor + 1e-9)
        XCTAssertLessThanOrEqual(withCrossModal.adjustedTopSetKg, baseline.adjustedTopSetKg + 1e-9)
    }

    func test_gateOn_crossModal_cannotForceHold() {
        let rec = recommendation(cap: 9.0, vol: 1.0, type: .strength)
        let severeCarry = CrossModalFatigueEngine.CrossModalResult(
            perRegionCarry: [.legs: 2_000],
            perRegionElevation: [.legs: 1.0],
            systemicFactor: 0.85,
            dominantReason: "legs still loaded from recent cross-modal work"
        )
        let result = TodayVerdictEngine.evaluate(
            recommendation: rec,
            plannedTopSet: plannedTopSet(kg: 200, region: .legs, rpe: 8),
            crossModalResult: severeCarry,
            plateStepKg: plateStep
        )

        XCTAssertNotEqual(result.verdict, .hold)
    }

    // MARK: - Honesty fence (no injury-prediction copy in the source)

    func test_verdictEngine_neverSaysInjuryPrediction_sourceGrep() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()       // WorkloadAppTests/
            .deletingLastPathComponent()       // repo root
            .appendingPathComponent("WorkloadApp/Services/TodayVerdictEngine.swift")
        let source = try String(contentsOf: url, encoding: .utf8).lowercased()
        XCTAssertFalse(source.contains("injury prediction"))
        XCTAssertFalse(source.contains("injury risk"))
    }
}
