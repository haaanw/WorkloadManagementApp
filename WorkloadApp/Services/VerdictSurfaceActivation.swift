import Foundation

/// **ACT-01 surface-scoped activation gate** for the verdict-feeding dashboard surface (the
/// dormant PRS readiness/strain compute: `BaselineEngine` → `ReadinessFusionEngine` +
/// `StrengthLoadEngine`/`LoadDistributionEngine` → `StrainRiskEngine` →
/// `AutoregulationEngine.recommendReadiness`, surfaced via the dual-run "method updated" card).
///
/// **DEFAULTS FALSE.** Mirrors `PRSActivation` / `PRSMasterActivation` in shape and default exactly.
///
/// ## What this flag does (and what it deliberately does NOT)
/// 1. It un-gates the live PRS readiness/strain compute on the **verdict-feeding dashboard surface
///    only**, WITHOUT touching `PRSActivation` or `PRSMasterActivation` (whose defaults stay `false`
///    so the legacy-byte-identical golden-snapshot fences — `AutoregulationFlagFenceTests`,
///    `BaselineTierFenceTests` — and the dual-run flag-off fences stay green).
/// 2. UNLIKE a test-only override, the PRODUCTION dashboard path itself calls `withEnabled(true)`
///    around the dual-run build (`DashboardViewModel.activateVerdictSurface()`, invoked by
///    `DashboardView.loadData()` after `load()` returns). So this surface is LIVE in the real app —
///    the engines run in production, no longer tests-only. There is no user-facing kill switch left
///    in the production path for this surface; the production code opts in unconditionally.
/// 3. The default stays FALSE precisely so that any BARE call — the flag-off fence tests, and any
///    other surface that calls `PRSDualRunSurface.dualRunMessage` / `.adjust` without an explicit
///    opt-in — keeps the BYTE-IDENTICAL legacy behaviour (false-OR-false ⇒ nil / no-op).
/// 4. The legacy recovery score (flat 7-day mean) and legacy recommendation (recovery × ACWR) remain
///    the LIVE values everywhere else (research §202 — verdict-surface-only activation).
/// 5. The app-wide `PRSActivation` and `PRSMasterActivation` remain `false` and unmodified.
///
/// ## Honest-confidence deferral preserved
/// Activating this surface does NOT fabricate a verdict on thin data: the gated build still routes
/// through `PRSReadinessInputBuilder.build(...)`, which returns `nil` on cold-start / low-confidence,
/// leaving `dualRunMessage` nil (the legacy guidance stands).
enum VerdictSurfaceActivation {

    /// Surface gate for the ACT-01 verdict-feeding dashboard compute. Default `false`.
    ///
    /// The PRODUCTION dashboard path activates the surface by calling `withEnabled(true)` around the
    /// dual-run build (see `DashboardViewModel.activateVerdictSurface()`); tests may likewise override
    /// it to exercise the surface-on path. A BARE read (no override on the stack) is `false`.
    static var isEnabled: Bool { _override ?? false }

    /// Override storage. `nil` ⇒ use the shipped default (`false`).
    private static var _override: Bool?

    /// Run `body` with `isEnabled` forced to `value`, restoring the prior state afterward.
    /// Used by the PRODUCTION dashboard opt-in (`activateVerdictSurface()`) to make the verdict
    /// surface live, and by tests to exercise the surface-on path. Mirrors `PRSActivation.withEnabled`
    /// verbatim: synchronous, restores via `defer` the instant the closure returns — so the gated
    /// build must run inside a SYNC scope (it cannot straddle an `await`).
    static func withEnabled<T>(_ value: Bool, _ body: () throws -> T) rethrows -> T {
        let prior = _override
        _override = value
        defer { _override = prior }
        return try body()
    }
}
