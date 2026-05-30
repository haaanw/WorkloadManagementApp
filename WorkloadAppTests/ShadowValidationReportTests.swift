import XCTest
import Foundation
@testable import workload_management

/// **Phase 29 Wave 2 (29-02) result checkpoint — deterministic seeded shadow-validation report.**
///
/// This is a "test" only as a **deterministic execution harness**: it builds synthetic
/// PRS-vs-baseline prediction/outcome traces with KNOWN ground truth, resolves them through the REAL
/// harness path (`CyclePredictionLog` rows carrying `ShadowArmPrediction` children + the outcome
/// `*Actual` fields → `ShadowAnalyticsService.metricsReport` / `pairedMAEDifferenceCI`), runs the
/// Wave-1 `ActivationGateEvaluator`, and then:
///
///  1. XCTAsserts each scenario's gate verdict against its KNOWN ground truth (the regression guard),
///  2. EMITS a markdown artifact at
///     `.planning/phases/29-shadow-validation-activation-gates/artifacts/29-shadow-validation-report.md`
///     (FileManager + String.write, temp-dir fallback if unwritable),
///  3. machine-asserts the master activation flag (and PRSActivation / CycleModifierActivation) stays
///     FALSE at emit time, and
///  4. proves byte-reproducibility (hash-equality) + no "injury prediction" copy.
///
/// ## Scope fence
/// FLIPS NO FLAG, adds NO app-target file, adds NO persisted model/column, adds NO statistic. It only
/// DRIVES + REPORTS the Wave-1 evaluator over synthetic data. `recommendsActivation` is rendered into
/// the report and NEVER assigned to any flag. Product name "Tuwa"; no "injury prediction" copy.
///
/// ## Determinism
/// Dates from a fixed anchor `Date(timeIntervalSince1970: 0) + i·86400`. The only RNG is
/// `ShadowMetrics.SplitMix64(seed:)` (verbatim); the CI bootstrap uses a FIXED `seed:`. Same seeds ⇒
/// byte-identical markdown.
@MainActor
final class ShadowValidationReportTests: XCTestCase {

    typealias Outcome = ShadowPredictor.Outcome

    // MARK: - Determinism scaffolding

    private static let anchor = Date(timeIntervalSince1970: 0)
    private static func day(_ i: Int) -> Date { anchor.addingTimeInterval(Double(i) * 86_400.0) }
    /// Fixed CI bootstrap seed so `pairedMAEDifferenceCI` is reproducible.
    private static let ciSeed: UInt64 = 0x5A11_DA7E

    /// Standard-normal sample via Box–Muller over the seeded SplitMix64 (the only RNG).
    private static func gaussian(_ rng: inout ShadowMetrics.SplitMix64) -> Double {
        var u1 = Double.random(in: 0...1, using: &rng)
        let u2 = Double.random(in: 0...1, using: &rng)
        if u1 < 1e-12 { u1 = 1e-12 }
        let r = (-2.0 * Foundation.log(u1)).squareRoot()
        return r * Foundation.cos(2.0 * Double.pi * u2)
    }

    // MARK: - Scenario model

    private enum ScenarioKind { case clearlyWins, clearlyLoses, thinData, ambiguous }

    private struct Scenario {
        let name: String
        let kind: ScenarioKind
        let seed: UInt64
        let n: Int
        let notes: String
        /// Ground-truth expectation for the overall recommendation.
        let expectRecommends: Bool
        /// Ground-truth expectation for G-MAE passing (when not thin).
        let expectMAEPasses: Bool
    }

    private static func scenarios() -> [Scenario] {
        [
            Scenario(name: "PRS-CLEARLY-WINS", kind: .clearlyWins, seed: 0xC1EA_010A, n: 80,
                     notes: "PRS predictions much closer to actuals on all 4 outcomes; ρ≥0.50, slope∈[0.8,1.2], n≥60",
                     expectRecommends: true, expectMAEPasses: true),
            Scenario(name: "PRS-CLEARLY-LOSES", kind: .clearlyLoses, seed: 0x105E_5EED, n: 80,
                     notes: "PRS worse than baseline on ≥2 outcomes → G-MAE fails",
                     expectRecommends: false, expectMAEPasses: false),
            Scenario(name: "THIN-DATA", kind: .thinData, seed: 0x7417_DA7A, n: 10,
                     notes: "n=10 < 60 with otherwise-perfect PRS → G-DATA-MATURITY forces no activation",
                     expectRecommends: false, expectMAEPasses: true),
            Scenario(name: "AMBIGUOUS", kind: .ambiguous, seed: 0xA11B_1605, n: 80,
                     notes: "PRS ≈ baseline → paired-MAE CIs straddle 0 (no win) → G-MAE fails",
                     expectRecommends: false, expectMAEPasses: false)
        ]
    }

    // MARK: - Synthetic resolved-row construction (the REAL harness row shape)

    /// The four continuous outcomes the gates operate over.
    private static let outcomes: [Outcome] = ActivationGateEvaluator.continuousOutcomes

    /// A plausible per-outcome "actual" value generator + scale, so calibration slope ~1 and ρ high
    /// when PRS tracks the actuals.
    private static func actualBase(_ outcome: Outcome, _ i: Int, _ rng: inout ShadowMetrics.SplitMix64) -> Double {
        // A smoothly varying signal in the outcome's own units + light seeded noise.
        let phase = Double(i)
        switch outcome {
        case .recovery:   return 60.0 + 15.0 * Foundation.sin(phase / 9.0) + 2.0 * gaussian(&rng)
        case .wellness:   return 65.0 + 12.0 * Foundation.sin(phase / 7.0) + 2.0 * gaussian(&rng)
        case .completion: return (Foundation.sin(phase / 5.0) > 0 ? 1.0 : 0.0)
        case .pain:       return 2.5 + 1.0 * Foundation.sin(phase / 6.0) + 0.3 * gaussian(&rng)
        case .niggleSeverity: return 0.0  // not a gating outcome; never requested here
        }
    }

    /// Build resolved `CyclePredictionLog` rows for a scenario, writing arm predictions for "prs"
    /// and "baseline" across the 4 continuous outcomes plus the outcome `*Actual` fields — exactly
    /// as the harness aggregation reads them (via `row.armPredictions` + the actual columns).
    private func buildResolvedRows(_ s: Scenario) -> [CyclePredictionLog] {
        var rng = ShadowMetrics.SplitMix64(seed: s.seed)
        var rows: [CyclePredictionLog] = []

        for i in 0..<s.n {
            let row = CyclePredictionLog(predictionDate: Self.day(i), predictionHorizonDays: 1)
            row.resolvedAt = Self.day(i + 1)

            for outcome in Self.outcomes {
                let actual = Self.actualBase(outcome, i, &rng)
                // Per-outcome noise scale so the additive errors stay on the outcome's own scale
                // (completion/pain are tiny; recovery/wellness are 0-100). This keeps the calibration
                // slope ≈ 1 (prediction ≈ actual + small zero-mean noise) and ρ high.
                let scale: Double = (outcome == .completion) ? 0.15
                                  : (outcome == .pain) ? 0.4
                                  : 5.0

                // Predictions = actual + ZERO-MEAN gaussian noise. The arm that WINS has the smaller
                // noise SD, so its |error| is smaller per row → paired-MAE-difference CI below 0,
                // while pred still tracks actual (slope≈1, ρ high).
                let baselineNoise = scale * 1.6 * Self.gaussian(&rng)
                let prsNoise: Double
                switch s.kind {
                case .clearlyWins, .thinData:
                    // PRS noise much smaller than baseline → PRS wins every outcome. Thin-data reuses
                    // the same signal so only G-DATA-MATURITY fails (n<60).
                    prsNoise = scale * 0.3 * Self.gaussian(&rng)
                case .clearlyLoses:
                    // PRS noise much larger than baseline → PRS loses every outcome (0 wins).
                    prsNoise = scale * 3.0 * Self.gaussian(&rng)
                case .ambiguous:
                    // PRS noise ≈ baseline → paired-MAE difference straddles 0 (no clear win).
                    prsNoise = scale * 1.6 * Self.gaussian(&rng)
                }

                let baselinePred = actual + baselineNoise
                let prsPred = actual + prsNoise

                row.armPredictions.append(ShadowArmPrediction(armId: "baseline", outcome: outcome, predicted: baselinePred))
                row.armPredictions.append(ShadowArmPrediction(armId: "prs", outcome: outcome, predicted: prsPred))

                switch outcome {
                case .recovery:   row.recoveryActual = actual
                case .wellness:   row.wellnessActual = actual
                case .completion: row.completionActual = actual
                case .pain:       row.painActual = actual
                case .niggleSeverity: break  // not a gating outcome; never iterated here
                }
            }
            rows.append(row)
        }
        return rows
    }

    // MARK: - Evaluate a scenario through the REAL harness path

    private struct ScenarioResult {
        let scenario: Scenario
        let report: ActivationGateEvaluator.GateReport
        let maeInputs: [ActivationGateEvaluator.OutcomeMAEInput]
        let prsMetrics: [Outcome: ShadowAnalyticsService.OutcomeMetrics]
    }

    private func runScenario(_ s: Scenario) -> ScenarioResult {
        let rows = buildResolvedRows(s)
        // REAL harness: metricsReport + pairedMAEDifferenceCI per continuous outcome.
        let prsMetrics = ShadowAnalyticsService.metricsReport(resolvedRows: rows, armId: "prs")
        var maeInputs: [ActivationGateEvaluator.OutcomeMAEInput] = []
        for outcome in Self.outcomes {
            let ci = ShadowAnalyticsService.pairedMAEDifferenceCI(
                resolvedRows: rows, outcome: outcome, armA: "prs", armB: "baseline", seed: Self.ciSeed
            )
            let n = prsMetrics[outcome]?.n ?? 0
            maeInputs.append(ActivationGateEvaluator.OutcomeMAEInput(outcome: outcome, ci: ci, n: n))
        }
        let report = ActivationGateEvaluator.evaluate(prsMetrics: prsMetrics, maeInputs: maeInputs)
        return ScenarioResult(scenario: s, report: report, maeInputs: maeInputs, prsMetrics: prsMetrics)
    }

    // MARK: - Markdown emit

    private func fmt(_ x: Double?, _ places: Int = 3) -> String {
        guard let x = x else { return "—" }
        return String(format: "%.\(places)f", x)
    }
    private func pass(_ ok: Bool) -> String { ok ? "PASS" : "**FAIL**" }
    private func outcomeLabel(_ o: Outcome) -> String {
        switch o {
        case .recovery: return "recovery"
        case .wellness: return "wellness"
        case .completion: return "completion"
        case .pain: return "pain"
        case .niggleSeverity: return "niggleSeverity"
        }
    }

    private func buildReport(_ results: [ScenarioResult]) -> String {
        var md = ""
        md += "# Phase 29 — Tuwa Shadow-Validation & Activation-Gate Report (PRS-v1)\n\n"
        md += "> ## NO ACTIVATION THIS PHASE — master flag remains FALSE\n"
        md += "> This report demonstrates the activation-gate machinery on SYNTHETIC data with known\n"
        md += "> ground truth. A synthetic PASS is **NOT** an authorization to go live. The PRS-v1 arm\n"
        md += "> stays SHADOW; `PRSMasterActivation.isEnabled` is FALSE and is not flipped here.\n\n"
        md += "Generated by `ShadowValidationReportTests` driving the Wave-1 `ActivationGateEvaluator`\n"
        md += "over synthetic PRS-vs-baseline traces resolved through the REAL Phase-24 harness\n"
        md += "(`ShadowAnalyticsService.metricsReport` + `pairedMAEDifferenceCI`). Determinism: fixed\n"
        md += "date anchor + seeded `SplitMix64`; same seeds ⇒ byte-identical report (hash-equality test).\n\n"
        md += "Gate thresholds (fixed named constants): G-MAE ≥ \(ActivationGateEvaluator.minMAEBeatCount)/"
        md += "\(ActivationGateEvaluator.continuousOutcomeCount) PRS wins (CI upper < 0); "
        md += "G-SPEARMAN ρ ≥ \(fmt(ActivationGateEvaluator.minSpearman, 2)); "
        md += "G-CALIBRATION slope ∈ [\(fmt(ActivationGateEvaluator.calibrationLow, 1)), "
        md += "\(fmt(ActivationGateEvaluator.calibrationHigh, 1))]; "
        md += "G-DATA-MATURITY n ≥ \(ActivationGateEvaluator.minResolvedRows).\n\n"
        md += "Honesty caveat (GA-2): `recovery` is engine-derived (circular); the report also reports a\n"
        md += "raw-self-report-only MAE-win sub-count over wellness/completion/pain. PRS-v1 is a\n"
        md += "load-tolerance / overreaching-context arm — this report contains no outcome 'prediction'\n"
        md += "marketing claims.\n\n"

        // Cross-scenario summary.
        md += "## Summary\n\n"
        md += "| Scenario | n | G-MAE (wins) | raw-self X/3 | G-SPEARMAN | G-CALIBRATION | G-DATA-MATURITY | recommends |\n"
        md += "|---|---:|---|---:|---|---|---|---|\n"
        for r in results {
            let rep = r.report
            md += "| \(r.scenario.name) | \(rep.dataMaturity.minObservedN) | "
            md += "\(pass(rep.mae.passed)) (\(rep.mae.winCount)/\(ActivationGateEvaluator.continuousOutcomeCount)) | "
            md += "\(rep.mae.rawSelfReportWinCount)/3 | "
            md += "\(pass(rep.spearman.passed)) | \(pass(rep.calibration.passed)) | "
            md += "\(pass(rep.dataMaturity.passed)) | \(rep.recommendsActivation ? "**YES**" : "no") |\n"
        }
        md += "\n"

        // Per-scenario panels.
        for r in results {
            let rep = r.report
            md += "## Scenario: \(r.scenario.name)\n\n"
            md += "_\(r.scenario.notes)_\n\n"

            md += "### G-MAE — PRS-vs-baseline paired MAE difference per outcome\n\n"
            md += "| outcome | engine-derived | n | CI lower | CI point | CI upper | PRS win (upper<0) |\n"
            md += "|---|:--:|---:|---:|---:|---:|:--:|\n"
            for e in rep.mae.evidence {
                let lo = e.ci.map { fmt($0.lower) } ?? "—"
                let pt = e.ci.map { fmt($0.point) } ?? "—"
                let up = e.ci.map { fmt($0.upper) } ?? "—"
                md += "| \(outcomeLabel(e.outcome)) | \(e.engineDerived ? "yes" : "no") | \(e.n) | "
                md += "\(lo) | \(pt) | \(up) | \(e.isWin ? "✓" : "✗") |\n"
            }
            md += "\nMAE-beat count **\(rep.mae.winCount)/\(ActivationGateEvaluator.continuousOutcomeCount)** "
            md += "(raw-self-report only **\(rep.mae.rawSelfReportWinCount)/3**); threshold ≥ "
            md += "\(rep.mae.threshold) → \(pass(rep.mae.passed)).\n\n"

            md += "### G-SPEARMAN — primary self-report ρ vs \(fmt(ActivationGateEvaluator.minSpearman, 2))\n\n"
            md += "| outcome | n | ρ | meets ≥\(fmt(ActivationGateEvaluator.minSpearman, 2)) |\n"
            md += "|---|---:|---:|:--:|\n"
            for e in rep.spearman.evidence {
                md += "| \(outcomeLabel(e.outcome)) | \(e.n) | \(fmt(e.rho)) | \(e.meetsThreshold ? "✓" : "✗") |\n"
            }
            md += "\nDesignated primary ρ `\(fmt(rep.spearman.designatedRho))` → \(pass(rep.spearman.passed)).\n\n"

            md += "### G-CALIBRATION — primary slope vs [\(fmt(ActivationGateEvaluator.calibrationLow, 1)), \(fmt(ActivationGateEvaluator.calibrationHigh, 1))]\n\n"
            md += "| outcome | n | slope | in band |\n"
            md += "|---|---:|---:|:--:|\n"
            for e in rep.calibration.evidence {
                md += "| \(outcomeLabel(e.outcome)) | \(e.n) | \(fmt(e.slope)) | \(e.inBand ? "✓" : "✗") |\n"
            }
            md += "\nDesignated primary slope `\(fmt(rep.calibration.designatedSlope))` → \(pass(rep.calibration.passed)).\n\n"

            md += "### G-DATA-MATURITY — n vs \(ActivationGateEvaluator.minResolvedRows)\n\n"
            md += "min observed resolved-row count **\(rep.dataMaturity.minObservedN)** "
            md += "(threshold ≥ \(rep.dataMaturity.threshold)); nil metric seen: "
            md += "\(rep.dataMaturity.hadNilMetric ? "yes" : "no") → \(pass(rep.dataMaturity.passed)).\n\n"

            md += "**Overall:** recommendsActivation = `\(rep.recommendsActivation)` — \(rep.reason).\n\n"
            md += "---\n\n"
        }

        md += "## Closing\n\n"
        md += "Every gate panel decomposes to its metric value(s), the fixed threshold, and a per-outcome\n"
        md += "breakdown (glass-box). The verdicts above are ALSO XCTAsserted against each scenario's\n"
        md += "known ground truth in `ShadowValidationReportTests`, so a regression fails the build.\n\n"
        md += "**Reminder: the master activation flag `PRSMasterActivation.isEnabled` is FALSE.** Phase 29\n"
        md += "builds and reports these gates only; flipping the flag to go live is a future,\n"
        md += "human-authorized decision taken after reviewing this report on REAL collected shadow data.\n"
        return md
    }

    // MARK: - Artifact path resolution

    private func repoRoot(file: StaticString = #filePath) -> URL {
        URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent()   // WorkloadAppTests/
            .deletingLastPathComponent()   // <repo root>
    }

    private func resolveArtifactURL() -> URL {
        let relDir = ".planning/phases/29-shadow-validation-activation-gates/artifacts"
        let fileName = "29-shadow-validation-report.md"
        if let override = ProcessInfo.processInfo.environment["SHADOW_VALIDATION_REPORT_DIR"], !override.isEmpty {
            return URL(fileURLWithPath: override).appendingPathComponent(fileName)
        }
        return repoRoot().appendingPathComponent(relDir).appendingPathComponent(fileName)
    }

    private func writeReport(_ md: String) -> URL {
        let fm = FileManager.default
        let target = resolveArtifactURL()
        do {
            try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try md.write(to: target, atomically: true, encoding: .utf8)
            print("📄 Shadow-validation report written to: \(target.path)")
            return target
        } catch {
            let fallback = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("29-shadow-validation-report.md")
            try? md.write(to: fallback, atomically: true, encoding: .utf8)
            print("⚠️ Repo path unwritable (\(error)); report written to temp: \(fallback.path)")
            return fallback
        }
    }

    // MARK: - TEST: generate report + assert verdicts against ground truth + flag-stays-false

    func test_generateShadowValidationReport_andAssertVerdicts() {
        // FLAG-STAYS-FALSE precondition at emit time (machine-asserted, GA-10).
        XCTAssertFalse(PRSMasterActivation.isEnabled, "master flag must remain FALSE at report emit")
        XCTAssertFalse(PRSActivation.isEnabled, "PRSActivation must remain FALSE at report emit")
        XCTAssertFalse(CycleModifierActivation.isEnabled, "CycleModifierActivation must remain FALSE")

        let results = Self.scenarios().map { runScenario($0) }
        let md = buildReport(results)
        let written = writeReport(md)

        XCTAssertTrue(FileManager.default.fileExists(atPath: written.path),
                      "report artifact must exist at \(written.path)")
        XCTAssertTrue(md.contains("NO ACTIVATION THIS PHASE"), "banner must be present")

        // Per-scenario verdict asserts against known ground truth.
        for r in results {
            let rep = r.report
            XCTAssertEqual(rep.recommendsActivation, r.scenario.expectRecommends,
                           "\(r.scenario.name): recommendsActivation mismatch (got \(rep.recommendsActivation))")
            switch r.scenario.kind {
            case .clearlyWins:
                XCTAssertTrue(rep.mae.passed, "\(r.scenario.name): G-MAE should pass")
                XCTAssertEqual(rep.mae.winCount, 4, "\(r.scenario.name): all 4 outcomes should win")
                XCTAssertTrue(rep.spearman.passed, "\(r.scenario.name): G-SPEARMAN should pass")
                XCTAssertTrue(rep.calibration.passed, "\(r.scenario.name): G-CALIBRATION should pass")
                XCTAssertTrue(rep.dataMaturity.passed, "\(r.scenario.name): maturity should pass")
            case .clearlyLoses:
                XCTAssertFalse(rep.mae.passed, "\(r.scenario.name): G-MAE should FAIL")
                XCTAssertEqual(rep.mae.winCount, 0, "\(r.scenario.name): PRS should win 0 outcomes")
                XCTAssertFalse(rep.recommendsActivation)
            case .thinData:
                XCTAssertFalse(rep.dataMaturity.passed, "\(r.scenario.name): maturity should FAIL (n<60)")
                XCTAssertEqual(rep.reason, "insufficient data")
                XCTAssertFalse(rep.recommendsActivation)
            case .ambiguous:
                XCTAssertFalse(rep.mae.passed, "\(r.scenario.name): straddling CIs → G-MAE should FAIL")
                XCTAssertFalse(rep.recommendsActivation)
            }
        }
    }

    // MARK: - TEST: hash-equality (byte-reproducibility)

    func test_reportIsByteReproducible() {
        let md1 = buildReport(Self.scenarios().map { runScenario($0) })
        let md2 = buildReport(Self.scenarios().map { runScenario($0) })
        XCTAssertEqual(md1, md2, "two same-seed runs must produce byte-identical markdown")
        XCTAssertEqual(md1.hashValue, md2.hashValue, "hash-equality must hold for the report String")
    }

    // MARK: - TEST: no-prediction-copy guard on the report strings

    func test_reportCopy_neverSaysInjuryPrediction() {
        let md = buildReport(Self.scenarios().map { runScenario($0) }).lowercased()
        XCTAssertFalse(md.contains("injury prediction"), "report must not contain 'injury prediction'")
        for dead in ["faros", "tutrice"] {
            XCTAssertFalse(md.contains(dead), "report uses dead product name '\(dead)'")
        }
        XCTAssertTrue(md.contains("tuwa"), "report should use the product name Tuwa")
    }

    // MARK: - TEST: flag stays FALSE even after evaluating a synthetic PASS

    func test_flagStaysFalse_afterSyntheticPass() {
        let results = Self.scenarios().map { runScenario($0) }
        // At least one scenario recommends (the synthetic PASS) — but no flag may flip.
        XCTAssertTrue(results.contains { $0.report.recommendsActivation },
                      "the PRS-CLEARLY-WINS scenario should produce a synthetic recommends=true")
        XCTAssertFalse(PRSMasterActivation.isEnabled, "a synthetic PASS must NOT flip the master flag")
        XCTAssertFalse(PRSActivation.isEnabled)
        XCTAssertFalse(CycleModifierActivation.isEnabled)
    }
}
