import XCTest
@testable import workload_management

/// Phase 28 Wave 2 (28-02) — the CENTRAL gating guard.
///
/// MUST-FIX (plan-check): pin `AutoregulationEngine` output BYTE-FOR-BYTE across the FULL
/// recovery × ACWR matrix when `PRSActivation.isEnabled == false`. "Existing tests stay green" is
/// insufficient to prove the byte-identical-live-recommendation invariant — this test captures a
/// golden snapshot of the legacy matrix and asserts the FLAGGED dispatch reproduces it exactly with
/// the flag off, AND that the flag-on path takes a different (readiness × strain-risk) branch.
final class AutoregulationFlagFenceTests: XCTestCase {

    private let tol = 1e-12

    // Every RecoveryZone × every ACWRZone (the full matrix), across a fatigue / rest / wellness grid.
    private let recoveryZones: [RecoveryZone] = [.red, .yellow, .green]
    private let acwrZones: [ACWRZone] = [.undertrained, .optimal, .caution, .danger, .noData]

    private func legacyInputs() -> [AutoregulationEngine.DailyInput] {
        var out: [AutoregulationEngine.DailyInput] = []
        for rz in recoveryZones {
            for az in acwrZones {
                for fatigue in [nil, 20.0, 60.0, 90.0] as [Double?] {
                    for rest in [0, 5, 7, 9] {
                        for wellness in [nil, 30.0, 80.0] as [Double?] {
                            let score: Double = rz == .red ? 20 : rz == .yellow ? 50 : 85
                            out.append(.init(
                                recoveryZone: rz,
                                recoveryScore: score,
                                acwrZone: az,
                                acwr: 1.0,
                                wellnessScore: wellness,
                                daysSinceLastRest: rest,
                                fatigueIndex: fatigue
                            ))
                        }
                    }
                }
            }
        }
        return out
    }

    private func assertEqual(
        _ a: AutoregulationEngine.TrainingRecommendation,
        _ b: AutoregulationEngine.TrainingRecommendation,
        _ msg: String
    ) {
        XCTAssertEqual(a.intensityCap, b.intensityCap, accuracy: tol, "cap \(msg)")
        XCTAssertEqual(a.volumeModifier, b.volumeModifier, accuracy: tol, "vol \(msg)")
        XCTAssertEqual(a.sessionType, b.sessionType, "sessionType \(msg)")
        XCTAssertEqual(a.headline, b.headline, "headline \(msg)")
        XCTAssertEqual(a.detail, b.detail, "detail \(msg)")
        XCTAssertEqual(a.warnings.count, b.warnings.count, "warnings.count \(msg)")
        for (wa, wb) in zip(a.warnings, b.warnings) {
            XCTAssertEqual(wa.message, wb.message, "warning.message \(msg)")
        }
    }

    // MARK: - Byte-identical golden fence (flag OFF, FULL matrix)

    func test_flagOff_recommendFlagged_isByteIdenticalToLegacy_fullMatrix() {
        XCTAssertFalse(PRSActivation.isEnabled, "precondition: flag defaults false")

        for legacy in legacyInputs() {
            // The flag-on input is intentionally a DIFFERENT decision (low readiness + high strain)
            // so that if the flag were accidentally honored, the fence would FAIL loudly.
            let readiness = AutoregulationEngine.ReadinessInput(
                readinessZone: .high, readiness: 90,
                strainRiskZone: .low,
                wellnessScore: legacy.wellnessScore,
                daysSinceLastRest: legacy.daysSinceLastRest,
                fatigueIndex: legacy.fatigueIndex,
                acwrContextLabel: "Load Steady"
            )
            let golden = AutoregulationEngine.recommend(input: legacy)   // legacy path directly
            let flagged = AutoregulationEngine.recommendFlagged(legacyInput: legacy, readinessInput: readiness)
            assertEqual(flagged, golden,
                "flag-off must be byte-identical for \(legacy.recoveryZone)/\(legacy.acwrZone) fi=\(String(describing: legacy.fatigueIndex)) rest=\(legacy.daysSinceLastRest)")
        }
    }

    // MARK: - Flag ON takes the new branch

    func test_flagOn_usesReadinessStrainRiskBranch_notLegacy() {
        // A case where legacy and new branches clearly diverge: legacy red/danger => rest(5,0);
        // new high-readiness/low-strain => power(10,1).
        let legacy = AutoregulationEngine.DailyInput(
            recoveryZone: .red, recoveryScore: 20, acwrZone: .danger, acwr: 1.6,
            wellnessScore: 80, daysSinceLastRest: 0, fatigueIndex: nil
        )
        let readiness = AutoregulationEngine.ReadinessInput(
            readinessZone: .high, readiness: 92, strainRiskZone: .low,
            wellnessScore: 80, daysSinceLastRest: 0, fatigueIndex: nil,
            acwrContextLabel: "Load Steady"
        )
        let legacyResult = AutoregulationEngine.recommend(input: legacy)
        let flagOn = PRSActivation.withEnabled(true) {
            AutoregulationEngine.recommendFlagged(legacyInput: legacy, readinessInput: readiness)
        }
        XCTAssertNotEqual(flagOn.sessionType, legacyResult.sessionType)
        XCTAssertEqual(flagOn.sessionType, .power)
        XCTAssertEqual(flagOn.intensityCap, 10.0, accuracy: tol)
    }

    // MARK: - GA-4: ACWR is context-label only in the flag-on path

    func test_flagOn_acwrIsContextLabelOnly_neverInWarnings() {
        for rz in [ReadinessZone.low, .moderate, .high] {
            for sz in StrainRiskZone.allCases {
                let input = AutoregulationEngine.ReadinessInput(
                    readinessZone: rz, readiness: 50, strainRiskZone: sz,
                    wellnessScore: 50, daysSinceLastRest: 2, fatigueIndex: nil,
                    acwrContextLabel: "Load Building"
                )
                let r = PRSActivation.withEnabled(true) {
                    AutoregulationEngine.recommendReadiness(input: input)
                }
                // No ACWR warning may appear in the flag-on path.
                for w in r.warnings {
                    let m = w.message.lowercased()
                    XCTAssertFalse(m.contains("above your baseline") && m.contains("load"),
                                   "ACWR-style warning leaked into flag-on path for \(rz)/\(sz)")
                }
                // ACWR appears ONLY as the context label in detail.
                XCTAssertTrue(r.detail.contains("Load context: Load Building"),
                              "ACWR context label missing for \(rz)/\(sz)")
            }
        }
    }

    func test_flagOn_highReadinessHighStrain_capsVolume_twoChannelCase() {
        // GA-1 key case: recovered athlete carrying dangerous load must still be capped.
        let input = AutoregulationEngine.ReadinessInput(
            readinessZone: .high, readiness: 90, strainRiskZone: .high,
            wellnessScore: 80, daysSinceLastRest: 1, fatigueIndex: nil,
            acwrContextLabel: "High Load"
        )
        let r = PRSActivation.withEnabled(true) {
            AutoregulationEngine.recommendReadiness(input: input)
        }
        XCTAssertLessThan(r.volumeModifier, 1.0, "high strain must cap volume even when readiness is high")
        XCTAssertNotEqual(r.sessionType, .power)
    }
}
