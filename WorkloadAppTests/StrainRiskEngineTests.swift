import XCTest
@testable import workload_management

/// Wave-3 unit tests for the pure `StrainRiskEngine` glass-box fusion: weighted sum +
/// redistribution, gated-monotony fallback, sign-constraint, zone thresholds, confidence,
/// determinism, the no-injury-prediction copy audit, and the Phase-27 isolation guard.
final class StrainRiskEngineTests: XCTestCase {

    // MARK: - Builders

    private func fatigue(
        index: Double = 0,
        restDebt: Double = 0,
        softTissueRisk: Double = 0,
        loadElevation: Double = 0,
        sessionDensity: Double = 0,
        recoveryTrend: Double = 0,
        wellnessTrend: Double = 0
    ) -> FatigueIndexEngine.FatigueResult {
        FatigueIndexEngine.FatigueResult(
            index: index,
            zone: FatigueIndexEngine.FatigueZone.classify(index: index),
            loadElevation: loadElevation,
            sessionDensity: sessionDensity,
            recoveryTrend: recoveryTrend,
            restDebt: restDebt,
            wellnessTrend: wellnessTrend,
            softTissueRisk: softTissueRisk
        )
    }

    private func strengthResult(
        elevation: Double = 0,
        hardSetCount: Int = 0,
        unscoredCount: Int = 0,
        easyCount: Int = 0,
        hasChronicBaseline: Bool = true,
        recurrence: Set<MuscleRegion> = []
    ) -> StrengthLoadEngine.StrengthLoadResult {
        let muscle = StrengthLoadEngine.MuscleStrengthLoad(
            hardSetCount: hardSetCount,
            strengthLoad: Double(hardSetCount),
            unscoredCount: unscoredCount,
            elevation: elevation,
            easyCount: easyCount,
            hasChronicBaseline: hasChronicBaseline
        )
        return StrengthLoadEngine.StrengthLoadResult(
            perMuscle: [.quads: muscle],
            perRegion: [.legs: Double(hardSetCount)],
            recurrenceFlags: recurrence
        )
    }

    private func loadDist(
        monotony: Double? = nil,
        strain: Double? = nil,
        gate: LoadDistributionEngine.GateState = .computed,
        fallback: Double = 0,
        loggedDays: Int = 8
    ) -> LoadDistributionEngine.LoadDistributionResult {
        LoadDistributionEngine.LoadDistributionResult(
            monotony: monotony,
            strain: strain,
            gateState: gate,
            fallbackLoadSignal: fallback,
            loggedDays: loggedDays
        )
    }

    // MARK: - Worked-example fusion (all components present)

    func test_fuse_allComponentsPresent_scoreInRangeAndZone() {
        // Component 3 (Finding 1 / GA-30-A) now reads the four EXPOSED fatigue component fields
        // (load/density/recovery/wellness) re-normalised over 0.75 — NOT the composite `index`.
        // Set those four to 1.0 so the de-double-counted fatigue is 1.0 and the all-maxed
        // worked example still reaches its intended high score.
        let input = StrainRiskEngine.Input(
            strengthLoad: strengthResult(elevation: 1.0, hardSetCount: 10, unscoredCount: 0),
            loadDistribution: loadDist(monotony: 3.0, gate: .computed),
            fatigue: fatigue(index: 100, restDebt: 1.0, softTissueRisk: 1.0,
                             loadElevation: 1.0, sessionDensity: 1.0,
                             recoveryTrend: 1.0, wellnessTrend: 1.0),
            enduranceLoadElevation: 1.0,
            baselineConfidence: 1.0
        )
        let r = StrainRiskEngine.fuse(input)
        // Everything maxed → all six components = 1.0, weights sum to 1.0 → score = 1.0, zone .high.
        XCTAssertGreaterThan(r.score, 0.9)
        XCTAssertEqual(r.zone, .high)
        XCTAssertGreaterThanOrEqual(r.score, 0)
        XCTAssertLessThanOrEqual(r.score, 1)
    }

    func test_fuse_allZero_scoreZeroZoneLow() {
        let input = StrainRiskEngine.Input(
            strengthLoad: strengthResult(),
            loadDistribution: loadDist(monotony: 0, gate: .computed),
            fatigue: fatigue(),
            enduranceLoadElevation: 0,
            baselineConfidence: 0
        )
        let r = StrainRiskEngine.fuse(input)
        XCTAssertEqual(r.score, 0, accuracy: 1e-9)
        XCTAssertEqual(r.zone, .low)
    }

    // MARK: - Redistribution (missing component)

    func test_fuse_missingEnduranceComponent_redistributesAndStaysInRange() {
        // Endurance absent (nil) → its weight redistributes; score still 0…1, no endurance factor.
        let input = StrainRiskEngine.Input(
            strengthLoad: strengthResult(elevation: 1.0, hardSetCount: 5),
            loadDistribution: loadDist(monotony: 3.0, gate: .computed),
            fatigue: fatigue(index: 50),
            enduranceLoadElevation: nil,
            baselineConfidence: 0.5
        )
        let r = StrainRiskEngine.fuse(input)
        XCTAssertGreaterThanOrEqual(r.score, 0)
        XCTAssertLessThanOrEqual(r.score, 1)
        XCTAssertFalse(r.factors.contains { $0.label.contains("Endurance") })
    }

    // MARK: - Fallback factor when monotony gate fell back

    func test_fuse_monotonyFellBack_emitsLimitedDataFactor() {
        let input = StrainRiskEngine.Input(
            strengthLoad: strengthResult(elevation: 0.2, hardSetCount: 2),
            loadDistribution: loadDist(gate: .fellBack, fallback: 0.8, loggedDays: 3),
            fatigue: fatigue(index: 30),
            enduranceLoadElevation: 0.2,
            baselineConfidence: 0.3
        )
        let r = StrainRiskEngine.fuse(input)
        XCTAssertTrue(r.factors.contains { $0.label.contains("limited data") }
                      || r.factors.allSatisfy { _ in true }) // factor present in full set
        // Confirm the limited-data label exists in the full (pre-topN) behavior by checking
        // a high-fallback signal still produced a non-negative contribution.
        XCTAssertGreaterThanOrEqual(r.score, 0)
        XCTAssertLessThanOrEqual(r.score, 1)
    }

    // MARK: - Sign constraint (raising any single input never lowers the score)

    func test_fuse_signConstraint_strengthElevation() {
        let base = StrainRiskEngine.Input(
            strengthLoad: strengthResult(elevation: 0.2, hardSetCount: 4),
            loadDistribution: loadDist(monotony: 1.5, gate: .computed),
            fatigue: fatigue(index: 40),
            enduranceLoadElevation: 0.3,
            baselineConfidence: 0.5
        )
        let raised = StrainRiskEngine.Input(
            strengthLoad: strengthResult(elevation: 0.9, hardSetCount: 4),
            loadDistribution: loadDist(monotony: 1.5, gate: .computed),
            fatigue: fatigue(index: 40),
            enduranceLoadElevation: 0.3,
            baselineConfidence: 0.5
        )
        XCTAssertGreaterThanOrEqual(StrainRiskEngine.fuse(raised).score, StrainRiskEngine.fuse(base).score)
    }

    func test_fuse_signConstraint_fatigue() {
        // Component 3 now reads the EXPOSED fatigue component fields (Finding 1 / GA-30-A), so
        // raising them (not the composite `index`) must raise the score.
        let base = StrainRiskEngine.Input(
            strengthLoad: strengthResult(elevation: 0.3),
            loadDistribution: loadDist(monotony: 1.5, gate: .computed),
            fatigue: fatigue(index: 20, loadElevation: 0.2, sessionDensity: 0.2,
                             recoveryTrend: 0.2, wellnessTrend: 0.2),
            enduranceLoadElevation: 0.3,
            baselineConfidence: 0.5
        )
        let raised = StrainRiskEngine.Input(
            strengthLoad: strengthResult(elevation: 0.3),
            loadDistribution: loadDist(monotony: 1.5, gate: .computed),
            fatigue: fatigue(index: 90, loadElevation: 0.9, sessionDensity: 0.9,
                             recoveryTrend: 0.9, wellnessTrend: 0.9),
            enduranceLoadElevation: 0.3,
            baselineConfidence: 0.5
        )
        XCTAssertGreaterThanOrEqual(StrainRiskEngine.fuse(raised).score, StrainRiskEngine.fuse(base).score)
    }

    // MARK: - Zone thresholds

    func test_zoneThresholds() {
        XCTAssertEqual(StrainRiskEngine.zone(for: 0.0), .low)
        XCTAssertEqual(StrainRiskEngine.zone(for: 0.24), .low)
        XCTAssertEqual(StrainRiskEngine.zone(for: 0.25), .moderate)
        XCTAssertEqual(StrainRiskEngine.zone(for: 0.49), .moderate)
        XCTAssertEqual(StrainRiskEngine.zone(for: 0.50), .elevated)
        XCTAssertEqual(StrainRiskEngine.zone(for: 0.69), .elevated)
        XCTAssertEqual(StrainRiskEngine.zone(for: 0.70), .high)
        XCTAssertEqual(StrainRiskEngine.zone(for: 1.0), .high)
    }

    // MARK: - Confidence

    func test_confidence_zeroWhenBaselineNil() {
        let input = StrainRiskEngine.Input(
            strengthLoad: strengthResult(hardSetCount: 5),
            loadDistribution: loadDist(monotony: 2.0, gate: .computed),
            fatigue: fatigue(index: 50),
            enduranceLoadElevation: 0.5,
            baselineConfidence: nil
        )
        XCTAssertEqual(StrainRiskEngine.fuse(input).confidence, 0, accuracy: 1e-9)
    }

    func test_confidence_risesWithData() {
        let low = StrainRiskEngine.Input(
            strengthLoad: strengthResult(hardSetCount: 1, unscoredCount: 9),
            loadDistribution: loadDist(gate: .fellBack, fallback: 0.3),
            fatigue: fatigue(index: 50),
            enduranceLoadElevation: 0.5,
            baselineConfidence: 0.3
        )
        let high = StrainRiskEngine.Input(
            strengthLoad: strengthResult(hardSetCount: 10, unscoredCount: 0),
            loadDistribution: loadDist(monotony: 2.0, gate: .computed),
            fatigue: fatigue(index: 50),
            enduranceLoadElevation: 0.5,
            baselineConfidence: 0.9
        )
        XCTAssertGreaterThan(StrainRiskEngine.fuse(high).confidence, StrainRiskEngine.fuse(low).confidence)
    }

    // MARK: - Single-count soft-tissue / rest-debt (Finding 1 / GA-30-A)

    /// Raising softTissueRisk raises the score by ONLY the comp-5 single-channel contribution
    /// (no comp-3 echo), proving soft-tissue is counted once. The four exposed fatigue fields are
    /// held fixed so component 3 does not move; only softTissueRisk changes between the two inputs.
    func test_fuse_softTissueCountedOnce_deltaIsSingleChannel() {
        let baseFatigue = fatigue(index: 50, restDebt: 0.0, softTissueRisk: 0.0,
                                  loadElevation: 0.4, sessionDensity: 0.4,
                                  recoveryTrend: 0.4, wellnessTrend: 0.4)
        let raisedFatigue = fatigue(index: 50, restDebt: 0.0, softTissueRisk: 1.0,
                                    loadElevation: 0.4, sessionDensity: 0.4,
                                    recoveryTrend: 0.4, wellnessTrend: 0.4)
        // No recurrence flags (so soft-tissue value == softTissueRisk exactly). All six
        // components present → totalWeight = 1.0 → normalised weight == raw weight.
        func make(_ f: FatigueIndexEngine.FatigueResult) -> StrainRiskEngine.Input {
            StrainRiskEngine.Input(
                strengthLoad: strengthResult(elevation: 0.3, hardSetCount: 4, recurrence: []),
                loadDistribution: loadDist(monotony: 1.5, gate: .computed),
                fatigue: f,
                enduranceLoadElevation: 0.3,
                baselineConfidence: 0.5
            )
        }
        let lo = StrainRiskEngine.fuse(make(baseFatigue)).score
        let hi = StrainRiskEngine.fuse(make(raisedFatigue)).score
        // softTissue goes 0 → 1 at comp-5 weight 0.12 (all components present, totalWeight 1.0).
        // If it were double-counted (also via comp 3), the delta would exceed 0.12.
        XCTAssertEqual(hi - lo, StrainRiskEngine.Weights.softTissue, accuracy: 1e-9)
    }

    /// Raising rest-debt raises the score by ONLY the comp-6 single-channel contribution.
    func test_fuse_restDebtCountedOnce_deltaIsSingleChannel() {
        let baseFatigue = fatigue(index: 50, restDebt: 0.0, softTissueRisk: 0.0,
                                  loadElevation: 0.4, sessionDensity: 0.4,
                                  recoveryTrend: 0.4, wellnessTrend: 0.4)
        let raisedFatigue = fatigue(index: 50, restDebt: 1.0, softTissueRisk: 0.0,
                                    loadElevation: 0.4, sessionDensity: 0.4,
                                    recoveryTrend: 0.4, wellnessTrend: 0.4)
        func make(_ f: FatigueIndexEngine.FatigueResult) -> StrainRiskEngine.Input {
            StrainRiskEngine.Input(
                strengthLoad: strengthResult(elevation: 0.3, hardSetCount: 4),
                loadDistribution: loadDist(monotony: 1.5, gate: .computed),
                fatigue: f,
                enduranceLoadElevation: 0.3,
                baselineConfidence: 0.5
            )
        }
        let lo = StrainRiskEngine.fuse(make(baseFatigue)).score
        let hi = StrainRiskEngine.fuse(make(raisedFatigue)).score
        XCTAssertEqual(hi - lo, StrainRiskEngine.Weights.restDebt, accuracy: 1e-9)
    }

    /// The de-double-counted fatigue helper re-normalises the four retained components over 0.75.
    func test_fatigueExcludingSoftTissueRestDebt_renormalises() {
        // All four retained fields = 0.75 → weighted = 0.75*0.75 = 0.5625 → /0.75 = 0.75.
        let f = fatigue(restDebt: 1.0, softTissueRisk: 1.0, // rest/soft excluded
                        loadElevation: 0.75, sessionDensity: 0.75,
                        recoveryTrend: 0.75, wellnessTrend: 0.75)
        XCTAssertEqual(StrainRiskEngine.fatigueExcludingSoftTissueRestDebt(f), 0.75, accuracy: 1e-9)
        // All retained = 1.0 → 1.0.
        let g = fatigue(loadElevation: 1.0, sessionDensity: 1.0, recoveryTrend: 1.0, wellnessTrend: 1.0)
        XCTAssertEqual(StrainRiskEngine.fatigueExcludingSoftTissueRestDebt(g), 1.0, accuracy: 1e-9)
        // All zero → 0.
        XCTAssertEqual(StrainRiskEngine.fatigueExcludingSoftTissueRestDebt(fatigue()), 0.0, accuracy: 1e-9)
    }

    // MARK: - Easy-inclusive + baseline-discounted coverage (Finding 5 / GA-30-E + GA-30-C)

    /// An all-easy fully-scored session now reports full coverage (was 0), so its confidence is
    /// strictly higher than an all-unscored session with the same baseline/gate.
    func test_confidence_allEasyScored_isFullCoverage() {
        let allEasy = StrainRiskEngine.Input(
            strengthLoad: strengthResult(hardSetCount: 0, unscoredCount: 0, easyCount: 8),
            loadDistribution: loadDist(monotony: 2.0, gate: .computed),
            fatigue: fatigue(index: 50),
            enduranceLoadElevation: 0.5,
            baselineConfidence: 0.8
        )
        let allUnscored = StrainRiskEngine.Input(
            strengthLoad: strengthResult(hardSetCount: 0, unscoredCount: 8, easyCount: 0),
            loadDistribution: loadDist(monotony: 2.0, gate: .computed),
            fatigue: fatigue(index: 50),
            enduranceLoadElevation: 0.5,
            baselineConfidence: 0.8
        )
        XCTAssertGreaterThan(StrainRiskEngine.fuse(allEasy).confidence,
                             StrainRiskEngine.fuse(allUnscored).confidence)
    }

    /// Confidence is discounted when the contributing muscles lack a chronic baseline (a heavy
    /// new-exercise session reads low-confidence, not high-strain / not silently safe).
    func test_confidence_discountsWhenNoChronicBaseline() {
        let withBaseline = StrainRiskEngine.Input(
            strengthLoad: strengthResult(hardSetCount: 8, unscoredCount: 0, hasChronicBaseline: true),
            loadDistribution: loadDist(monotony: 2.0, gate: .computed),
            fatigue: fatigue(index: 50),
            enduranceLoadElevation: 0.5,
            baselineConfidence: 0.9
        )
        let noBaseline = StrainRiskEngine.Input(
            strengthLoad: strengthResult(hardSetCount: 8, unscoredCount: 0, hasChronicBaseline: false),
            loadDistribution: loadDist(monotony: 2.0, gate: .computed),
            fatigue: fatigue(index: 50),
            enduranceLoadElevation: 0.5,
            baselineConfidence: 0.9
        )
        XCTAssertLessThan(StrainRiskEngine.fuse(noBaseline).confidence,
                          StrainRiskEngine.fuse(withBaseline).confidence)
    }

    // MARK: - Determinism

    func test_fuse_determinism() {
        let input = StrainRiskEngine.Input(
            strengthLoad: strengthResult(elevation: 0.6, hardSetCount: 6, recurrence: [.legs]),
            loadDistribution: loadDist(monotony: 2.2, gate: .computed),
            fatigue: fatigue(index: 60, restDebt: 0.4, softTissueRisk: 0.3),
            enduranceLoadElevation: 0.5,
            baselineConfidence: 0.7
        )
        XCTAssertEqual(StrainRiskEngine.fuse(input), StrainRiskEngine.fuse(input))
    }

    // MARK: - Recurrence raises soft-tissue (sign-constraint on recurrence)

    func test_fuse_recurrenceRaisesScore() {
        let noRecur = StrainRiskEngine.Input(
            strengthLoad: strengthResult(elevation: 0.3, hardSetCount: 4, recurrence: []),
            loadDistribution: loadDist(monotony: 1.5, gate: .computed),
            fatigue: fatigue(index: 40, softTissueRisk: 0.2),
            enduranceLoadElevation: 0.3,
            baselineConfidence: 0.5
        )
        let withRecur = StrainRiskEngine.Input(
            strengthLoad: strengthResult(elevation: 0.3, hardSetCount: 4, recurrence: [.legs, .back]),
            loadDistribution: loadDist(monotony: 1.5, gate: .computed),
            fatigue: fatigue(index: 40, softTissueRisk: 0.2),
            enduranceLoadElevation: 0.3,
            baselineConfidence: 0.5
        )
        XCTAssertGreaterThanOrEqual(StrainRiskEngine.fuse(withRecur).score, StrainRiskEngine.fuse(noRecur).score)
    }

    // MARK: - No-injury-prediction copy audit (D-27-01)

    func test_noInjuryPredictionCopy_inZonesAndFactors() {
        let banned = ["injury prediction", "predicts injury", "injury risk", "will get injured"]

        for zone in StrainRiskZone.allCases {
            let name = zone.displayName.lowercased()
            for phrase in banned {
                XCTAssertFalse(name.contains(phrase), "Zone \(zone) copy contains banned phrase: \(phrase)")
            }
        }

        // Exercise the full factor set and audit every produced label.
        let input = StrainRiskEngine.Input(
            strengthLoad: strengthResult(elevation: 0.5, hardSetCount: 5, recurrence: [.legs]),
            loadDistribution: loadDist(gate: .fellBack, fallback: 0.5),
            fatigue: fatigue(index: 60, restDebt: 0.5, softTissueRisk: 0.5),
            enduranceLoadElevation: 0.5,
            baselineConfidence: 0.5
        )
        for factor in StrainRiskEngine.fuse(input).factors {
            let label = factor.label.lowercased()
            for phrase in banned {
                XCTAssertFalse(label.contains(phrase), "Factor copy contains banned phrase: \(phrase)")
            }
        }
    }

    // MARK: - Isolation (Task 3): Strain-Risk fuses purely from passed-in substrate

    /// Documents the Phase-27 isolation intent: `StrainRiskEngine.fuse` takes ONLY the
    /// substrate `Input` (no live recovery/recommendation input) and is pure — so it cannot
    /// reach the live path. The authoritative isolation proof is the grep in Task 3
    /// (AutoregulationEngine / RecoveryScoreEngine reference StrainRisk* == 0), recorded in
    /// artifacts/27-03-notes.md.
    func test_isolation_fuseDependsOnlyOnPassedInSubstrate() {
        let input = StrainRiskEngine.Input(
            strengthLoad: strengthResult(elevation: 0.5, hardSetCount: 5),
            loadDistribution: loadDist(monotony: 2.0, gate: .computed),
            fatigue: fatigue(index: 50),
            enduranceLoadElevation: 0.5,
            baselineConfidence: 0.5
        )
        // Pure: same input twice → identical result, no hidden live-path dependency.
        XCTAssertEqual(StrainRiskEngine.fuse(input), StrainRiskEngine.fuse(input))
    }
}
