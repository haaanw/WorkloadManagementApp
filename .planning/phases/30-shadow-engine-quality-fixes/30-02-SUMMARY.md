---
phase: 30-shadow-engine-quality-fixes
plan: 02
subsystem: load-distribution-engine
tags: [shadow, foster-monotony, z-standardisation, scale-mismatch]
requires: [30-01]
provides: [monotonyInputSeries, per-stream-standardised-monotony]
affects: [StrainRiskEngine (Wave 3 — consumes LoadDistributionResult.monotony)]
key-files:
  modified:
    - WorkloadApp/Services/LoadDistributionEngine.swift
    - WorkloadAppTests/LoadDistributionEngineTests.swift
decisions: [GA-30-B]
metrics:
  completed: 2026-05-31
commit: 466df41
---

# Phase 30 Plan 02: LoadDistributionEngine Finding 2 z-standardisation Summary

Per-stream z-standardised the endurance-sRPE and strength-strain sub-series before feeding Foster monotony/strain, so strength is no longer drowned out by the larger endurance scale whenever sessionRPE is logged.

## What changed (Finding 2 / GA-30-B)
- Added `private static func standardize(_:) -> [Double]` — `z = (v − mean)/sampleSD`; returns zeros (no NaN) for <2 values or zero variance.
- Added `monotonyInputSeries(sessions:asOf:calendar:windowDays:)` — builds per-day endurance and strength sub-series over the SAME logged days/windowing as `dailyLoadSeries`, standardises EACH, then sums element-wise.
- `distribution` now feeds `monotonyInputSeries(...)` (not the raw `series.map(\.load)`) to `monotony`/`strain` when the gate passes. The completeness gate still runs on the RAW series; `loggedDays` and `dailyLoadSeries` are unchanged.

## Standardisation scheme + the positive-offset refinement
The literal "sum of two zero-mean z-streams" collapses to a mean-0 series, on which Foster monotony (`mean/SD`) is degenerate (≈ 0 regardless of the streams), defeating the finding's purpose. To honour GA-30-B's intent (each stream contributes comparably) while keeping Foster meaningful, each z-score is shifted by a fixed positive offset (`Constants.standardizedOffset = 3.0`, since z-scores are almost always within ±3) before summing. This preserves the per-stream SHAPE that standardisation equalises and gives Foster a well-defined positive-mean series. Documented inline.

This is a justified refinement (deviation Rule 1/3) of the plan's standardisation detail, not a weakening — without it the output would be a degenerate constant.

## Drift for Wave 3
None. `StrainRiskEngineTests` pass literal `monotony:` values into `loadDist(...)` builders (not values derived from `distribution`), so Wave 2's change does not move any StrainRisk worked example. Full suite green confirms.

## Verification
- `LoadDistributionEngineTests` — all green (incl. strength-measurably-moves-monotony 6.0→3.73, zero-strength-variance finite/no-NaN, constant-input no-NaN, raw-oracle day1.load==280 unchanged).
- FULL `WorkloadAppTests` — `** TEST SUCCEEDED **`.
- `git diff --stat` on the three fence files — EMPTY.
- No `.xcstrings` churn. No flag default changed.

## Deviations from Plan
**1. [Rule 1 - Correctness] Positive offset on standardised streams**
- Found during: Task 1 (test (a) "strength measurably changes monotony" was unsatisfiable).
- Issue: summing two zero-mean z-standardised streams yields a mean-0 series; Foster monotony=mean/SD is then ≈0 regardless of the streams (degenerate constant), so strength could not measurably move it.
- Fix: shift each z-score by `standardizedOffset = 3.0` before summing → positive-mean series; both streams now move monotony/strain. Documented in code + this summary.
- Files modified: WorkloadApp/Services/LoadDistributionEngine.swift
- Commit: 466df41

## Self-Check: PASSED
- Commit 466df41 present on main.
- LoadDistributionEngine.swift contains `standardize` / `monotonyInputSeries`.
- LoadDistributionEngineTests.swift contains the standardisation contribution tests.
