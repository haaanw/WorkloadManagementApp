# 27-02 notes — LoadDistributionEngine (Wave 2)

## monotonyMinLoggedDays = 7

The completeness gate requires **≥ 7 distinct logged days** in the 14-day series AND non-zero
variance. Below that, a 7-point Foster monotony is statistically fragile on sparse consumer
logs (codex MAJOR), so monotony/strain return `nil`, `gateState == .fellBack`, and the
heuristic `fallbackLoadSignal` is surfaced instead.

## Monotony worked example

Daily series `[1, 2, 3]`: mean = 2, sample SD = 1 → **monotony = 2.0**, sum = 6 →
**strain = sum × monotony = 12.0**. Zero-variance (`[100,100,100]`) and `< 2` points both
return `nil` (no divide-by-zero / inf).

## Unified daily-load series

Per logged calendar day (`calendar.startOfDay(sessionDate)`):
`Σ WorkloadCalculator.srpeLoad(durationSeconds:sessionRPE:)` over sessions WITH a `sessionRPE`
+ `Σ` strength hard-set load (per-bucket strain weight summed over each session's hard sets,
reusing `StrengthLoadEngine.classify` + `StrengthLoadEngine.Constants.strainWeight` and
`StrengthLoadEngine.e1RMReferences`). Rest days (no session in window) are ABSENT, not
zero-filled, so `loggedDays` reflects genuine training frequency. NO raw tonnage.

## Fallback heuristic composition

`fallbackLoadSignal = clamp(density + spikeBump, 0…1)` where
- `density = clamp(recentSessions / 14, 0…1)` over the last 14 days — same shape as
  `FatigueIndexEngine`'s `sessions/14d` density formula (REUSED philosophy, not reinvented).
- `spikeBump = 0.25` added when `WorkloadCalculator.detectSessionSpike` fires on the most
  recent session's TSS vs the prior session TSS values; else 0.

## Reuse / purity

- REUSES `WorkloadCalculator.srpeLoad` / `sessionTSS` / `detectSessionSpike` and
  `StrengthLoadEngine` classification — nothing reinvented.
- Pure deterministic struct, Foundation-only; `asOf` + `Calendar` injected (no `Date.now` /
  `Calendar.current`).
- `WorkloadCalculator` and `FatigueIndexEngine` are only READ, not modified.

## Test result

- Targeted: `WorkloadAppTests/LoadDistributionEngineTests` → **TEST SUCCEEDED**, 0 failures.
- FULL `WorkloadAppTests` suite → **TEST SUCCEEDED**, 0 errors, 0 failures.
- `BaselineTierFenceTests` → all 3 PASSED (live recovery baseline byte-unchanged).
- No `.xcstrings` build-churn. No live engine modified.
- `LoadDistributionEngine.swift` registered in the app target pbxproj (ids EE2702*) — the
  app target is not a synchronized group (same as Wave 1).
