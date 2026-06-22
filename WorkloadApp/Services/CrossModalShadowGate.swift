import Foundation

/// **The explicit cross-modal VERDICT-INFLUENCE gate (Phase 41, ACT-02). DEFAULTS FALSE.**
///
/// The cross-modal fatigue-carry channel (`CrossModalFatigueEngine`, logged as the `"crossModal"`
/// shadow arm in `ShadowPredictor.registeredArms()`) runs DARK through the existing
/// `ShadowMetrics` / `ShadowAnalyticsService` harness. This enum is the hard fence that keeps that
/// channel from ever driving a user-facing number or verdict until it has earned it.
///
/// ## What `crossModalDrivesVerdict` gates
/// While `crossModalDrivesVerdict == false` (the shipped default, and the ONLY value this phase),
/// the cross-modal channel is FORBIDDEN from influencing any verdict number. It logs predictions
/// for prequential validation and nothing else. Collecting that shadow data while the flag is off
/// is the entire point of the shadow-gate (CONTEXT.md, locked: "Shadow-gate before influence";
/// ROADMAP SC4).
///
/// ## How it flips (and how it does NOT)
/// Flipping `crossModalDrivesVerdict` to `true` is a FUTURE human-authorized decision, taken ONLY
/// after a human reviews the cross-modal shadow-validation signal (paired-MAE CI vs baseline,
/// region-soreness next-day agreement) and judges it has cleared a validation pass. It is NEVER set
/// in app code, NEVER assigned from any evaluator's `recommendsActivation`, and NEVER flipped by a
/// code merge. The magnitude of the cross-modal model is an honest heuristic (LOW confidence per
/// research §1.5), so day-one there is no shadow data and the gate stays OFF by construction.
///
/// ## Report-only discipline (mirrors `ActivationGateEvaluator`, GA-7)
/// `validationSummary(resolvedRows:)` is REPORT-ONLY: it extracts the EXISTING
/// `ShadowAnalyticsService.metricsReport(armId: "crossModal")` + `pairedMAEDifferenceCI(armA:
/// "crossModal", armB: "baseline")` outputs and reports whether the cross-modal arm shows signal.
/// It adds NO new statistics and MUST NEVER assign `crossModalDrivesVerdict` (enforced by a
/// no-mutation grep test). The only line that assigns the flag is the test-only `_override` inside
/// `withEnabled(_:)`.
enum CrossModalShadowGate {

    /// Verdict-influence gate for the cross-modal channel. **Default `false`** — the channel logs
    /// DARK and cannot drive any user-facing number or verdict until an explicit human
    /// shadow-validation PASS flips this. Never set in app code; never assigned from any
    /// evaluator's `recommendsActivation`.
    static var crossModalDrivesVerdict: Bool { _override ?? false }

    /// Test-only override storage. `nil` ⇒ use the shipped default (`false`). Never set in app code.
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
