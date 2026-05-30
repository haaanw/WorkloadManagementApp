import Foundation

/// Master activation flag for **PRS-v1** (Personal Readiness — the predicting shadow arm of the
/// v1.6 algorithm moat: `ReadinessFusionEngine` fusion + the `AutoregulationEngine`
/// readiness×strain-risk swap + the dual-run "method updated" surface).
///
/// **DEFAULTS FALSE.** Mirrors the Phase-20 `CycleModifierActivation` posture exactly.
///
/// ## What this flag gates (and what it does NOT)
/// This flag gates ONLY the **live user-facing swap**:
///   - the `AutoregulationEngine` decision-axis swap (recovery×ACWR → readiness×strain-risk),
///   - the decision-level `ReasoningEngine` explanation surfaced to the user,
///   - the dual-run "method updated" UI + the real-workout adjustment.
///
/// The **shadow predicting arm** (PRS Readiness logged in `ShadowPredictor` /
/// `CyclePredictionLog`) runs **UNCONDITIONALLY** — it logs predictions for prequential
/// validation regardless of this flag, exactly like the Phase-20/24 shadow-log discipline.
/// Collecting that shadow data while the flag is off is the entire point of the Phase-29
/// activation gate.
///
/// ## Invariant (Phase 28)
/// With `isEnabled == false`, the live recovery score AND the live user-facing recommendation
/// are **BYTE-IDENTICAL** to pre-Phase-28 behavior (machine-enforced by
/// `AutoregulationFlagFenceTests` golden snapshot + `BaselineTierFenceTests`).
///
/// **Do NOT flip the live default to `true`** until the Phase-29 shadow-validation +
/// activation gates pass. The predicting arm is SHADOW ONLY this milestone.
enum PRSActivation {

    /// Master gate for the PRS-v1 live user-facing swap. Default `false` (GA-6, research §219).
    ///
    /// Tests may override this via `withEnabled(_:)` to exercise the flag-on path without ever
    /// shipping an enabled default.
    static var isEnabled: Bool { _override ?? false }

    /// Test-only override storage. `nil` ⇒ use the shipped default (`false`). Never set in app code.
    private static var _override: Bool?

    /// Run `body` with `isEnabled` forced to `value`, restoring the prior state afterward.
    /// TEST-ONLY helper so the flag-on branch can be exercised deterministically; production code
    /// must never call this. Mirrors the deterministic-override discipline used elsewhere.
    static func withEnabled<T>(_ value: Bool, _ body: () throws -> T) rethrows -> T {
        let prior = _override
        _override = value
        defer { _override = prior }
        return try body()
    }
}
