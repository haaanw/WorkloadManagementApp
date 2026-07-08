import XCTest
@testable import workload_management

/// Phase 43 Plan 02 (VERDICT-03) — unit tests for the pure `VerdictReasonBuilder`.
///
/// Proves the one-line plain-language reason is assembled from the EXISTING
/// `ReasoningEngine.explainDecision` ranked reasons, with the two locked guardrails:
///   1. the cross-modal cause is named ONLY when `CrossModalShadowGate.crossModalDrivesVerdict`
///      is true AND cross-modal is the dominant driver for the planned region;
///   2. confidence is reported as a SEPARATE field (never folded into the reason line), and a
///      cold-start / low-confidence path DEFERS to the plan instead of fabricating a trim rationale.
final class VerdictReasonBuilderTests: XCTestCase {

    // MARK: - Fixtures

    private func readinessResult(
        hrvZ: Double = -1.4, sleepZ: Double = -0.9, rhrZ: Double = -0.4, confidence: Double = 0.7
    ) -> ReadinessFusionEngine.ReadinessResult {
        ReadinessFusionEngine.compute(.init(hrvZ: hrvZ, rhrZ: rhrZ, sleepZ: sleepZ, confidence: confidence))
    }

    private func strainResult(score: Double = 0.4) -> StrainRiskEngine.StrainRiskResult {
        StrainRiskEngine.StrainRiskResult(
            score: score,
            zone: StrainRiskEngine.zone(for: score),
            factors: [
                .init(label: "Per-muscle strength-load elevation", contribution: 0.18),
                .init(label: "Rest debt", contribution: 0.05)
            ],
            confidence: 0.6
        )
    }

    private func recommendation(vol: Double = 0.6, cap: Double = 7) -> AutoregulationEngine.TrainingRecommendation {
        AutoregulationEngine.TrainingRecommendation(
            intensityCap: cap, volumeModifier: vol, sessionType: .conditioning,
            warnings: [], headline: "Stay Controlled", detail: "..."
        )
    }

    private func decisionInput(
        readiness: ReadinessFusionEngine.ReadinessResult? = nil,
        strain: StrainRiskEngine.StrainRiskResult? = nil,
        rec: AutoregulationEngine.TrainingRecommendation? = nil
    ) -> ReasoningEngine.DecisionInput {
        ReasoningEngine.DecisionInput(
            readiness: readiness ?? readinessResult(),
            strainRisk: strain ?? strainResult(),
            recommendation: rec ?? recommendation()
        )
    }

    /// A cross-modal result whose dominant elevated region is `region`.
    private func crossModal(
        dominantRegion: MuscleRegion,
        elevation: Double
    ) -> CrossModalFatigueEngine.CrossModalResult {
        CrossModalFatigueEngine.CrossModalResult(
            perRegionCarry: [dominantRegion: 500],
            perRegionElevation: [dominantRegion: elevation],
            systemicFactor: 0.9,
            dominantReason: "\(dominantRegion.displayName.lowercased()) still loaded from recent cross-modal work"
        )
    }

    // MARK: - VERDICT-03 reason assembly

    func test_reasonLine_containsTopRankedSignal_singleLine() {
        // Top-ranked explainDecision reason here is the HRV depression (largest |contribution|).
        let result = VerdictReasonBuilder.build(
            decisionInput: decisionInput(readiness: readinessResult(hrvZ: -1.8, sleepZ: -0.2, rhrZ: -0.1)),
            crossModalResult: nil,
            plannedRegion: .legs,
            deferToPlan: false
        )
        XCTAssertFalse(result.reasonLine.isEmpty)
        XCTAssertFalse(result.reasonLine.contains("\n"))   // single line
        XCTAssertFalse(result.deferredToPlan)
        // The HRV signal label leads the explanation.
        XCTAssertTrue(result.reasonLine.contains("Heart Rate Variability"))
    }

    func test_confidence_isSeparateField_notInReasonLine() {
        let readiness = readinessResult(confidence: 0.73)
        let result = VerdictReasonBuilder.build(
            decisionInput: decisionInput(readiness: readiness),
            crossModalResult: nil,
            plannedRegion: .legs,
            deferToPlan: false
        )
        XCTAssertEqual(result.confidence, readiness.confidence, accuracy: 1e-9)
        // The numeric confidence is NOT interpolated into the reason string.
        XCTAssertFalse(result.reasonLine.contains("0.73"))
        XCTAssertFalse(result.reasonLine.contains("73"))
    }

    // MARK: - Cross-modal naming, gated

    func test_gateOff_crossModalCause_neverNamed() {
        let cross = crossModal(dominantRegion: .legs, elevation: 0.9)
        // Gate off: even with a leg-loaded dominant cross-modal result, the cause is never named.
        let result = CrossModalShadowGate.withEnabled(false) {
            VerdictReasonBuilder.build(
                decisionInput: decisionInput(),
                crossModalResult: cross,
                plannedRegion: .legs,
                deferToPlan: false
            )
        }
        XCTAssertFalse(result.reasonLine.lowercased().contains("loaded from"))
    }

    func test_gateOn_crossModalDominant_causeNamed() {
        // Make cross-modal the DOMINANT driver: readiness near-neutral, strain low, big leg elevation.
        let cross = crossModal(dominantRegion: .legs, elevation: 0.95)
        let result = CrossModalShadowGate.withEnabled(true) {
            VerdictReasonBuilder.build(
                decisionInput: decisionInput(
                    readiness: readinessResult(hrvZ: 0.0, sleepZ: 0.0, rhrZ: 0.0),
                    strain: strainResult(score: 0.05)
                ),
                crossModalResult: cross,
                plannedRegion: .legs,
                deferToPlan: false
            )
        }
        let lower = result.reasonLine.lowercased()
        XCTAssertTrue(lower.contains("legs"))
        XCTAssertTrue(lower.contains("easing"))
        XCTAssertTrue(lower.contains("lower-body"))
    }

    func test_gateOn_crossModalDominant_upperBodyLineIsRegionAware() {
        let cross = crossModal(dominantRegion: .chest, elevation: 0.95)
        let result = CrossModalShadowGate.withEnabled(true) {
            VerdictReasonBuilder.build(
                decisionInput: decisionInput(
                    readiness: readinessResult(hrvZ: 0.0, sleepZ: 0.0, rhrZ: 0.0),
                    strain: strainResult(score: 0.05)
                ),
                crossModalResult: cross,
                plannedRegion: .chest,
                deferToPlan: false
            )
        }
        let lower = result.reasonLine.lowercased()
        XCTAssertTrue(lower.contains("upper body"))
        XCTAssertTrue(lower.contains("easing"))
    }

    func test_gateOn_crossModalNotDominant_readinessLeads() {
        // Readiness is the bigger driver (deep HRV depression); cross-modal elevation tiny.
        let cross = crossModal(dominantRegion: .legs, elevation: 0.02)
        let result = CrossModalShadowGate.withEnabled(true) {
            VerdictReasonBuilder.build(
                decisionInput: decisionInput(readiness: readinessResult(hrvZ: -2.5, sleepZ: -1.5, rhrZ: -1.0)),
                crossModalResult: cross,
                plannedRegion: .legs,
                deferToPlan: false
            )
        }
        // The cross-modal cause is NOT forced into the line; readiness reason leads.
        XCTAssertTrue(result.reasonLine.contains("Heart Rate Variability"))
        XCTAssertFalse(result.reasonLine.lowercased().contains("loaded from"))
    }

    func test_matchProximityMicrodoseLine_takesPrecedenceOverCrossModal() {
        let cross = crossModal(dominantRegion: .legs, elevation: 0.95)
        let calendar = Calendar(identifier: .gregorian)
        let matchDate = DateComponents(calendar: calendar, year: 2026, month: 7, day: 10).date!
        let result = CrossModalShadowGate.withEnabled(true) {
            VerdictReasonBuilder.build(
                decisionInput: decisionInput(
                    readiness: readinessResult(hrvZ: 0.0, sleepZ: 0.0, rhrZ: 0.0),
                    strain: strainResult(score: 0.05)
                ),
                crossModalResult: cross,
                plannedRegion: .legs,
                deferToPlan: false,
                matchContext: .init(daysAway: 1, matchDate: matchDate),
                calendar: calendar
            )
        }
        let lower = result.reasonLine.lowercased()
        XCTAssertTrue(lower.contains("microdose"))
        XCTAssertFalse(lower.contains("easing"))
        XCTAssertFalse(lower.contains("lower-body"))
    }

    // MARK: - Cold-start defer (locked honest-confidence rule)

    func test_coldStart_defersToPlan_withDeferCopy() {
        let result = VerdictReasonBuilder.build(
            decisionInput: nil,           // the PRSReadinessInputBuilder.build returned-nil case
            crossModalResult: nil,
            plannedRegion: .legs,
            deferToPlan: true
        )
        XCTAssertTrue(result.deferredToPlan)
        // Defer copy: going with the plan, still learning the baseline — not a fabricated trim rationale.
        let lower = result.reasonLine.lowercased()
        XCTAssertTrue(lower.contains("plan"))
        XCTAssertTrue(lower.contains("baseline") || lower.contains("learning"))
        // Confidence reported as low/unknown (no decisionInput).
        XCTAssertEqual(result.confidence, 0, accuracy: 1e-9)
    }

    func test_deferToPlanFlag_forcesDefer_evenWithDecisionInput() {
        let result = VerdictReasonBuilder.build(
            decisionInput: decisionInput(),
            crossModalResult: nil,
            plannedRegion: .legs,
            deferToPlan: true
        )
        XCTAssertTrue(result.deferredToPlan)
        XCTAssertTrue(result.reasonLine.lowercased().contains("plan"))
    }

    // MARK: - Honesty fence

    func test_reasonBuilder_neverSaysInjuryPrediction_sourceGrep() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()       // WorkloadAppTests/
            .deletingLastPathComponent()       // repo root
            .appendingPathComponent("WorkloadApp/Services/VerdictReasonBuilder.swift")
        let source = try String(contentsOf: url, encoding: .utf8).lowercased()
        XCTAssertFalse(source.contains("injury prediction"))
        XCTAssertFalse(source.contains("injury risk"))
    }
}
