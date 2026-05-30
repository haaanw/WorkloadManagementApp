import Foundation

/// **Milestone-level master activation flag for PRS-v1** (the v1.6 Algorithm-Moat go-live gate).
///
/// **DEFAULTS FALSE — and Phase 29 NEVER flips it.** Mirrors the Phase-20 `CycleModifierActivation`
/// and Phase-28 `PRSActivation` defaults-false posture exactly (GA-1, research §219 / §4.4).
///
/// ## What this flag IS (and how it differs from `PRSActivation`)
/// This is the SEPARATE, milestone-level **"gates passed → go live"** gate. It is distinct from the
/// Phase-28 `PRSActivation`, which is the **engineering swap gate** for the live user-facing
/// `AutoregulationEngine` decision-axis swap + dual-run surface. The two flags layer:
///   - `PRSActivation` answers "is the live swap wired on?" (engineering).
///   - `PRSMasterActivation` answers "have the Phase-29 activation gates passed so we are AUTHORIZED
///     to flip the live swap on?" (milestone go-live authorization).
/// Neither is flipped this phase. Both stay FALSE.
///
/// ## Phase-29 invariant
/// Phase 29 BUILDS and REPORTS the activation gates (`ActivationGateEvaluator` →
/// `29-shadow-validation-report.md`) but DOES NOT flip this flag. Flipping it to `true` is a
/// **FUTURE, human-authorized decision** taken only after a human reviews the shadow-validation
/// report and the four ROADMAP gates pass on real data (research Open Q6).
///
/// ## Hard separation from the evaluator (GA-7)
/// **NO code may assign this flag from `ActivationGateEvaluator.recommendsActivation`.** That boolean
/// is REPORT-ONLY. The evaluator computes a recommendation and renders it into a report; it must
/// never mutate any `*Activation.isEnabled`. A no-mutation isolation grep test machine-enforces that
/// the evaluator source contains no `isEnabled =` assignment.
enum PRSMasterActivation {

    /// Master go-live gate for PRS-v1. Default `false` (GA-1). Stays false this phase.
    ///
    /// Tests may override this via `withEnabled(_:_:)` to exercise the flag-on path without ever
    /// shipping an enabled default. Production code must never call the override.
    static var isEnabled: Bool { _override ?? false }

    /// Test-only override storage. `nil` ⇒ use the shipped default (`false`). Never set in app code.
    private static var _override: Bool?

    /// Run `body` with `isEnabled` forced to `value`, restoring the prior state afterward.
    /// TEST-ONLY helper so the flag-on branch can be exercised deterministically; production code
    /// must never call this. Mirrors `PRSActivation.withEnabled` verbatim.
    static func withEnabled<T>(_ value: Bool, _ body: () throws -> T) rethrows -> T {
        let prior = _override
        _override = value
        defer { _override = prior }
        return try body()
    }
}
