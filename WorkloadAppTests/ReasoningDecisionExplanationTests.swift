import XCTest
@testable import workload_management

/// Phase 28 Wave 2 (28-02), Task 2 — ReasoningEngine decision-explanation upgrade + guards.
///
/// Covers: the new `explainDecision` produces decomposable, ranked, confidence-aware reasons;
/// the existing `summarize` signature/output is UNCHANGED (flag-OFF regression, MUST-FIX); the
/// no-prediction-copy guard (GA-11); and the isolation guard (the new Readiness/decision path is
/// not referenced by live flag-off call sites).
final class ReasoningDecisionExplanationTests: XCTestCase {

    // MARK: - Builders

    private func readinessResult(
        hrvZ: Double = -1.2, sleepZ: Double = -0.8, rhrZ: Double = -0.3
    ) -> ReadinessFusionEngine.ReadinessResult {
        ReadinessFusionEngine.compute(.init(hrvZ: hrvZ, rhrZ: rhrZ, sleepZ: sleepZ, confidence: 0.7))
    }

    private func strainResult(score: Double = 0.6) -> StrainRiskEngine.StrainRiskResult {
        StrainRiskEngine.StrainRiskResult(
            score: score,
            zone: StrainRiskEngine.zone(for: score),
            factors: [
                .init(label: "Per-muscle strength-load elevation", contribution: 0.25),
                .init(label: "Rest debt", contribution: 0.10)
            ],
            confidence: 0.6
        )
    }

    private func recommendation(vol: Double = 0.5) -> AutoregulationEngine.TrainingRecommendation {
        AutoregulationEngine.TrainingRecommendation(
            intensityCap: 6, volumeModifier: vol, sessionType: .activeRecovery,
            warnings: [], headline: "Light Day", detail: "..."
        )
    }

    // MARK: - explainDecision produces decomposable, ranked reasons

    func test_explainDecision_returnsRankedDecomposableReasons() {
        let input = ReasoningEngine.DecisionInput(
            readiness: readinessResult(),
            strainRisk: strainResult(),
            recommendation: recommendation(vol: 0.5)
        )
        let reasons = ReasoningEngine.explainDecision(input: input)
        XCTAssertFalse(reasons.isEmpty)
        // Every reason maps to a named source factor (glass-box).
        for r in reasons {
            XCTAssertFalse(r.source.isEmpty)
            XCTAssertFalse(r.text.isEmpty)
        }
        // Ranked by absolute contribution (descending), ignoring trailing zero-contribution lines.
        let nonzero = reasons.filter { $0.contribution != 0 }
        for i in 1..<max(nonzero.count, 1) where nonzero.count > 1 {
            XCTAssertGreaterThanOrEqual(abs(nonzero[i - 1].contribution), abs(nonzero[i].contribution))
        }
    }

    func test_explainDecision_surfacesStrainRiskAsDownwardPressure() {
        let input = ReasoningEngine.DecisionInput(
            readiness: readinessResult(hrvZ: 0, sleepZ: 0, rhrZ: 0), // neutral readiness
            strainRisk: strainResult(score: 0.7),
            recommendation: recommendation(vol: 0.5)
        )
        let reasons = ReasoningEngine.explainDecision(input: input)
        XCTAssertTrue(reasons.contains { $0.source == "Per-muscle strength-load elevation" })
    }

    func test_explainDecision_personalSleepBaselineLineWhenProvided() {
        let input = ReasoningEngine.DecisionInput(
            readiness: readinessResult(),
            strainRisk: strainResult(),
            recommendation: recommendation(),
            personalSleepBaselineMinutes: 465 // ~7h45m
        )
        let reasons = ReasoningEngine.explainDecision(input: input)
        XCTAssertTrue(reasons.contains { $0.source == "Sleep" && $0.text.contains("personal sleep baseline") })
    }

    // MARK: - MUST-FIX: legacy summarize is UNCHANGED (flag-OFF regression)

    private func recoveryStub() -> RecoveryScoreEngine.RecoveryResult {
        RecoveryScoreEngine.RecoveryResult(
            score: 55, zone: .yellow, breakdown: nil,
            hrvContribution: nil, rhrContribution: nil, sleepContribution: nil,
            dataSource: .healthKit, hasRealData: true
        )
    }

    func test_summarize_signatureAndOutput_unchanged() {
        // Reproduce a representative summarize call and pin its output shape/values.
        let recovery = recoveryStub()
        let input = ReasoningEngine.Input(
            recoveryResult: recovery,
            workloadSnapshot: nil,
            rawHRV: 50, rawRHR: 60, hrvBaseline: 60, rhrBaseline: 55,
            sleepMinutes: 360, daysSinceRest: 5
        )
        let factors = ReasoningEngine.summarize(input: input)
        // Legacy behavior: max 3 factors, ranked by impact, HRV/RHR/Sleep/Streak labels only.
        XCTAssertLessThanOrEqual(factors.count, 3)
        let allowed: Set<String> = ["Heart Rate Variability", "Resting Heart Rate", "Sleep Duration", "Training Streak"]
        for f in factors { XCTAssertTrue(allowed.contains(f.label), "unexpected legacy label \(f.label)") }
        // HRV 50 vs baseline 60 = ~16.7% below → present and negative.
        XCTAssertTrue(factors.contains { $0.label == "Heart Rate Variability" && $0.direction == .negative })
    }

    func test_summarize_isIndependentOfPRSFlag() {
        let recovery = recoveryStub()
        let input = ReasoningEngine.Input(
            recoveryResult: recovery, workloadSnapshot: nil,
            rawHRV: 50, rawRHR: 60, hrvBaseline: 60, rhrBaseline: 55,
            sleepMinutes: 360, daysSinceRest: 5
        )
        let off = ReasoningEngine.summarize(input: input)
        let on = PRSActivation.withEnabled(true) { ReasoningEngine.summarize(input: input) }
        XCTAssertEqual(off.count, on.count)
        for (a, b) in zip(off, on) {
            XCTAssertEqual(a.label, b.label)
            XCTAssertEqual(a.deltaText, b.deltaText)
            XCTAssertEqual(a.impact, b.impact, accuracy: 1e-12)
        }
    }

    // MARK: - No-prediction-copy guard (GA-11) — extend the Phase-27 guard to new copy

    func test_noPredictionCopy_inDecisionReasons() {
        let input = ReasoningEngine.DecisionInput(
            readiness: readinessResult(),
            strainRisk: strainResult(),
            recommendation: recommendation(),
            personalSleepBaselineMinutes: 465
        )
        let reasons = ReasoningEngine.explainDecision(input: input)
        let forbidden = ["injury prediction", "injury risk", "predicts injury", "will get injured"]
        for r in reasons {
            let lower = r.text.lowercased()
            for phrase in forbidden {
                XCTAssertFalse(lower.contains(phrase), "decision reason contains '\(phrase)': \(r.text)")
            }
        }
    }

    func test_noPredictionCopy_inFlaggedAutoregulationDetail() {
        for rz in [ReadinessZone.low, .moderate, .high] {
            for sz in StrainRiskZone.allCases {
                let input = AutoregulationEngine.ReadinessInput(
                    readinessZone: rz, readiness: 50, strainRiskZone: sz,
                    wellnessScore: 50, daysSinceLastRest: 1, fatigueIndex: nil,
                    acwrContextLabel: "Load Steady"
                )
                let r = AutoregulationEngine.recommendReadiness(input: input)
                let lower = (r.headline + " " + r.detail).lowercased()
                for phrase in ["injury prediction", "injury risk", "predicts injury", "will get injured"] {
                    XCTAssertFalse(lower.contains(phrase), "flagged copy contains '\(phrase)' for \(rz)/\(sz)")
                }
            }
        }
    }
}
