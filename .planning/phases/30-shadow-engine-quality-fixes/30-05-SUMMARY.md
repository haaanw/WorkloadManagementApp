---
phase: 30-shadow-engine-quality-fixes
plan: 05
subsystem: shadow-load-distribution / strain-risk engines
tags: [shadow-only, monotony, foster, load-distribution, strain-risk, windowing, integration-test]
requires: ["30-02", "30-03"]
provides:
  - "single real-unit combined daily series (strength→sRPE-equivalent) feeding Foster monotony/strain"
  - "gate + monotony share ONE series → .computed implies monotony non-nil"
  - "half-open LoadDistributionEngine windows (exact N-calendar-day spans)"
  - "StrainRiskEngine .computed-with-nil-monotony reduced-weight fallback defence"
  - "real distribution()→fuse() integration test guarding W1 regression"
affects:
  - WorkloadApp/Services/LoadDistributionEngine.swift
  - WorkloadApp/Services/StrainRiskEngine.swift
tech-stack:
  added: []
  patterns: ["single real-unit combined series + classic Foster monotony", "half-open windowing (exclusive upper)"]
key-files:
  created: []
  modified:
    - WorkloadApp/Services/LoadDistributionEngine.swift
    - WorkloadApp/Services/StrainRiskEngine.swift
    - WorkloadAppTests/LoadDistributionEngineTests.swift
    - WorkloadAppTests/StrainRiskEngineTests.swift
decisions:
  - "strengthSRPEEquivalentPerStrainUnit = 5.0 (a heavy hard set ≈ 5 sRPE units ≈ 0.7 min × RPE 7)"
  - "W2 wired by gating on the SAME single combined series (.computed ⇒ monotony non-nil structurally)"
  - "StrainRiskEngine defends residual .computed-with-nil-monotony → reduced-weight fallback, never 0-at-full-weight"
metrics:
  duration: "~25 min"
  completed: 2026-05-31
---

# Phase 30 Plan 05: Monotony-Saturation + Gate-Divergence + Window Correction Summary

Shadow-only Wave-5 fix: replaced the Wave-2 z-standardise+offset monotony hack with ONE real-unit combined daily series (strength converted to an sRPE-equivalent load) so Foster monotony lands in the natural ~1-3 range and `clamp01(monotony/3.0)` is meaningful instead of pinned at 1.0; the gate and the metric now share one series; the three LoadDistributionEngine windows are half-open; and a real `distribution()→fuse()` integration test now guards the W1 regression. LIVE behaviour byte-identical — three fence families green, files untouched.

## What changed

### W1 — monotony saturation (the main defect)
- Removed `Constants.standardizedOffset (3.0)` and the per-stream `standardize(_:)` z-score machinery entirely.
- Added `Constants.strengthSRPEEquivalentPerStrainUnit = 5.0` — converts a strength strain-unit (heavy hard set ≈ 1.0) to an sRPE-equivalent internal load so endurance srpeLoad (minutes×RPE) and strength load live on ONE real-unit scale.
- New `combinedDailyLoadSeries(...)` builds the single per-logged-day value `enduranceSrpe + strengthStrainSum × 5.0`; `monotonyInputSeries(...)` now returns this combined series (`.map(\.load)`).
- Re-derived oracle: 8-day varied endurance log srpeLoads `[180,300,120,360,150,270,210,330]` → mean 240, sampleSD ≈ 87.83 → **monotony ≈ 2.733 → clamp01(/3) ≈ 0.911 (< 1.0)**. Under the superseded hack this was ≈4-6 → clamp01 == 1.0 for every gate-passing log.
- Movement confirmed: near-uniform daily distribution yields strictly higher monotony than a varied one; folding strength onto a subset of days shifts monotony by > 1e-6.

### W2 — gate/series divergence
- `distribution(...)` now builds the combined series ONCE, gates on THAT series, and feeds THAT series to `monotony`/`strain`. Because `completenessGate`'s `count ≥ 7 AND SD > 0` checks are exactly the conditions `monotony()` needs to be non-nil, **`.computed` ⇒ monotony non-nil structurally**.
- Defensive hardening in `StrainRiskEngine.fuse`: a residual `.computed`-with-nil-monotony now degrades to the SAME reduced-weight fallback (`Weights.monotonyStrainFallback` on `fallbackLoadSignal`, "limited data" label) used by `.fellBack` — **never 0-at-full-weight**. The `.computed`-with-monotony path is byte-identical to before.

### W3 — windowing off-by-one
- Three LoadDistributionEngine window filters changed from inclusive `diff <= windowDays` to half-open `diff < windowDays` (and `< spikeLookbackDays` in `fallbackLoadSignal`), matching `StrengthLoadEngine.windowedRange`. A "window of N days" now spans exactly N calendar days; a session exactly `windowDays` old is excluded.

### Test-gap closure
- Added the real end-to-end integration test (`StrainRiskEngineTests.test_integration_realDistributionToFuse_monotonyNotSaturated` + `..._uniformVsVaried_monotonyFactorOrders`) that runs the REAL `LoadDistributionEngine.distribution()` into `StrainRiskEngine.fuse()` and asserts the monotony factor is NOT saturated at 1.0 and orders uniform > varied — the path that hid W1 (prior StrainRisk tests hand-fed monotony 1.5/2.0/3.0).
- Re-derived `LoadDistributionEngineTests` monotony/window oracle to the new correct values; raw `dailyLoadSeries` 280.0 oracle preserved.

## Verification
- `LoadDistributionEngineTests`: 23/23 green (xcodebuild ** TEST SUCCEEDED **).
- `StrainRiskEngineTests`: all green incl. 3 new (W2 defence + 2 integration).
- Full `WorkloadAppTests` suite: ** TEST SUCCEEDED **.
- Hard-invariant gate: fence diff empty; PRSActivation + PRSMasterActivation `isEnabled` default FALSE; SyncService references engines == 0; `standardizedOffset` grep == 0; no new injury-prediction copy (only the pre-existing "NEVER injury prediction" disclaimer); no Faros/Tonus/Tutrice; no .xcstrings churn.

## Deviations from Plan
None — plan executed as written. Task 3 was verification-only (no source change → no commit).

## Commits
- `510188f` fix(30-05): W1+W2+W3 — single real-unit combined series replaces z-offset hack; half-open windows
- `02ad347` fix(30-05): W2 defence + real distribution()->fuse() integration test (test-gap closure)

Verified-green HEAD: **02ad347**.

## Self-Check: PASSED
- WorkloadApp/Services/LoadDistributionEngine.swift — FOUND
- WorkloadApp/Services/StrainRiskEngine.swift — FOUND
- WorkloadAppTests/LoadDistributionEngineTests.swift — FOUND
- WorkloadAppTests/StrainRiskEngineTests.swift — FOUND
- Commit 510188f — FOUND
- Commit 02ad347 — FOUND
