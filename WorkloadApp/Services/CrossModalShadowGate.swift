import Foundation

/// **The explicit cross-modal VERDICT-INFLUENCE gate (Phase 41, ACT-02). DEFAULTS TRUE.**
///
/// The cross-modal fatigue-carry channel (`CrossModalFatigueEngine`, logged as the `"crossModal"`
/// shadow arm in `ShadowPredictor.registeredArms()`) runs DARK through the existing
/// `ShadowMetrics` / `ShadowAnalyticsService` harness. This enum keeps verdict influence revertible
/// while the founder dogfoods the n=1 validation window.
///
/// ## What `crossModalDrivesVerdict` gates
/// While `crossModalDrivesVerdict == true` (the shipped default as of 2026-07-08), the
/// cross-modal channel may tighten the verdict through `TodayVerdictEngine`'s bounded path. If the
/// dogfood window shows cross-modal misfires, flip this back to `false`; then the channel returns to
/// shadow-only logging and contributes zero to the user-facing number.
///
/// ## How it flips (and how it does NOT)
/// `crossModalDrivesVerdict` was activated 2026-07-08 for pre-registered n=1 dogfood validation.
/// Keep this as a plain default so it remains revertible. It is NEVER assigned from any evaluator's
/// `recommendsActivation`; validation summaries remain report-only. The magnitude of the
/// cross-modal model is an honest heuristic (LOW confidence per research §1.5), so the dogfood
/// criterion decides whether this default survives.
///
/// ## Report-only discipline (mirrors `ActivationGateEvaluator`, GA-7)
/// `validationSummary(resolvedRows:)` is REPORT-ONLY: it extracts the EXISTING
/// `ShadowAnalyticsService.metricsReport(armId: "crossModal")` + `pairedMAEDifferenceCI(armA:
/// "crossModal", armB: "baseline")` outputs and reports whether the cross-modal arm shows signal.
/// It adds NO new statistics and MUST NEVER assign `crossModalDrivesVerdict` (enforced by a
/// no-mutation grep test). The only line that assigns the flag is the test-only `_override` inside
/// `withEnabled(_:)`.
enum CrossModalShadowGate {

    /// Verdict-influence gate for the cross-modal channel. **Default `true`** — activated
    /// 2026-07-08 for n=1 dogfood validation; revert to `false` if dogfood shows cross-modal
    /// misfires. Never assigned from any evaluator's `recommendsActivation`.
    static var crossModalDrivesVerdict: Bool { _override ?? true }

    /// Test-only override storage. `nil` ⇒ use the shipped default (`true`). Never set in app code.
    private static var _override: Bool?

    /// Run `body` with `crossModalDrivesVerdict` forced to `value`, restoring the prior state after.
    /// TEST-ONLY helper so the gate-on path can be exercised deterministically; production code must
    /// never call this. Mirrors the `PRSActivation` / `VerdictSurfaceActivation` override discipline.
    static func withEnabled<T>(_ value: Bool, _ body: () throws -> T) rethrows -> T {
        let prior = _override
        _override = value
        defer { _override = prior }
        return try body()
    }

    // MARK: - Report-only validation summary (REPORT-ONLY — never mutates the gate)

    /// The cross-modal arm's id in the shadow harness.
    static let armId: String = "crossModal"
    /// The baseline arm the cross-modal arm is compared against for the paired-MAE CI.
    static let comparisonArmId: String = "baseline"

    /// A read-only snapshot of the cross-modal arm's shadow signal. NO new statistics — it only
    /// surfaces the EXISTING `ShadowAnalyticsService` outputs and a derived `showsSignal` flag.
    struct ValidationSummary {
        /// Per-outcome metrics (MAE, calibration slope, Spearman ρ, n) for the `"crossModal"` arm.
        let crossModalMetrics: [ShadowPredictor.Outcome: ShadowAnalyticsService.OutcomeMetrics]
        /// Per-outcome paired-MAE-difference CI (cross-modal vs baseline): `d = |err_crossModal| -
        /// |err_baseline|`. The cross-modal arm WINS an outcome ⇔ the CI upper bound < 0 (strict).
        let pairedMAEvsBaseline: [ShadowPredictor.Outcome: (lower: Double, upper: Double, point: Double)?]
        /// Number of outcomes on which the cross-modal arm strictly beats baseline (CI upper < 0).
        let winCount: Int
        /// REPORT-ONLY signal flag: the cross-modal arm shows signal iff it beats baseline on at
        /// least one continuous outcome with a present CI and present Spearman ρ. This is a REPORT —
        /// it does NOT flip `crossModalDrivesVerdict`; only a human shadow-validation pass does.
        let showsSignal: Bool
        /// Mirror of the gate state at report time (so a reader sees the channel is still fenced).
        let crossModalDrivesVerdict: Bool
    }

    /// Continuous outcomes the cross-modal arm predicts (excludes `.niggleSeverity`, which no arm
    /// predicts in v1). Same set the `ActivationGateEvaluator` gates over.
    static let consideredOutcomes: [ShadowPredictor.Outcome] = [.recovery, .wellness, .completion, .pain]

    /// REPORT-ONLY: extract the EXISTING shadow metrics for the cross-modal arm and report whether it
    /// shows signal against baseline. Adds NO statistics; NEVER assigns `crossModalDrivesVerdict`.
    /// `@MainActor` because `ShadowAnalyticsService` is (mirrors `ActivationGateEvaluator.evaluate`).
    @MainActor
    static func validationSummary(
        resolvedRows: [CyclePredictionLog],
        ciSeed: UInt64 = 0x5EED
    ) -> ValidationSummary {
        let metrics = ShadowAnalyticsService.metricsReport(resolvedRows: resolvedRows, armId: armId)
        var cis: [ShadowPredictor.Outcome: (lower: Double, upper: Double, point: Double)?] = [:]
        var winCount = 0
        var anyWinWithRho = false
        for outcome in consideredOutcomes {
            let ci = ShadowAnalyticsService.pairedMAEDifferenceCI(
                resolvedRows: resolvedRows,
                outcome: outcome,
                armA: armId,
                armB: comparisonArmId,
                seed: ciSeed
            )
            cis[outcome] = ci
            // Cross-modal WINS an outcome ⇔ CI upper bound < 0 (strict; matches GA-9 sign convention).
            let isWin = (ci.map { $0.upper < 0 }) ?? false
            if isWin { winCount += 1 }
            if isWin, metrics[outcome]?.spearmanRho != nil { anyWinWithRho = true }
        }
        return ValidationSummary(
            crossModalMetrics: metrics,
            pairedMAEvsBaseline: cis,
            winCount: winCount,
            showsSignal: anyWinWithRho,
            crossModalDrivesVerdict: crossModalDrivesVerdict   // READ only — never assigned here.
        )
    }
}
