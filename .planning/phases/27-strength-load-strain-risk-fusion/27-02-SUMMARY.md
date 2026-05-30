---
phase: 27-strength-load-strain-risk-fusion
plan: 02
subsystem: algorithm-substrate
tags: [load-distribution, foster-monotony, strain, completeness-gate, shadow-gated]
requires: [27-01]
provides: [LoadDistributionEngine]
affects: [27-03]
tech-stack:
  added: []
  patterns: [pure-static-engine, dateless-by-injection, completeness-gate, heuristic-fallback]
key-files:
  created:
    - WorkloadApp/Services/LoadDistributionEngine.swift
    - WorkloadAppTests/LoadDistributionEngineTests.swift
    - .planning/phases/27-strength-load-strain-risk-fusion/artifacts/27-02-notes.md
  modified:
    - workload management/workload management.xcodeproj/project.pbxproj
decisions:
  - "monotonyMinLoggedDays = 7 + non-zero variance gates Foster monotony/strain; else heuristic fallback"
  - "Fallback signal = density (sessions/14d) + 0.25 spike bump, clamped 0..1"
metrics:
  duration: single-session
  completed: 2026-05-30
---

# Phase 27 Plan 02: LoadDistributionEngine Summary

Pure deterministic `LoadDistributionEngine` that builds a unified daily-load series (endurance
sRPE + strength hard-set load) and computes completeness-gated Foster monotony & strain, with
an honest heuristic fallback (density + spike) when logged days are too sparse to trust — both
gate paths unit-tested, live recovery score unchanged.

## What was built

- **`LoadDistributionEngine.swift`** — pure `struct`, static methods, Foundation-only,
  `asOf` + `Calendar` injected. API:
  - `dailyLoadSeries(...)` → `[DailyLoad]` — per-day `Σ srpeLoad + Σ strength hard-set load`,
    logged days only (rest days absent, not zero-filled). Reuses
    `WorkloadCalculator.srpeLoad` + `StrengthLoadEngine.classify` / strain weights.
  - `monotony(_:)` = mean / sampleSD (nil when <2 points or SD == 0).
  - `strain(_:)` = sum × monotony (nil when monotony nil).
  - `completenessGate(_:)` — `loggedDays ≥ 7` AND variance > 0.
  - `distribution(...)` → `LoadDistributionResult` { monotony?, strain?, gateState
    (.computed/.fellBack), fallbackLoadSignal (0…1), loggedDays }.
  - `fallbackLoadSignal(...)` — density (sessions/14d, FatigueIndex shape) + 0.25 spike bump
    (via `WorkloadCalculator.detectSessionSpike`), clamped 0…1.
- **`LoadDistributionEngineTests.swift`** — monotony/strain numerics + known values, zero-
  variance / sparse guards, daily-series bucketing + window exclusion + nil-RPE handling,
  gate-pass (.computed) / sparse (.fellBack) / zero-variance fallback, boundary at 7 logged
  days, fallback range, determinism. Fixed UTC anchor 2026-03-15.

## Decisions made

- **Completeness gate = `monotonyMinLoggedDays` (7) + non-zero variance.** Below that, Foster
  monotony is fragile, so the engine falls back to a 0…1 density+spike heuristic and marks
  `gateState == .fellBack` so Wave 3 can weight the channel honestly.

## Deviations from Plan

None — plan executed as written. (App-target pbxproj registration of the new engine file is
the same explicit-membership step established in Wave 1; the app target is not a synchronized
group.)

## Verification

- `WorkloadAppTests/LoadDistributionEngineTests` → **TEST SUCCEEDED**, 0 failures.
- FULL `WorkloadAppTests` suite → **TEST SUCCEEDED**, 0 errors, 0 failures.
- `BaselineTierFenceTests` → all 3 PASSED (live recovery baseline byte-unchanged).
- Only reads `WorkloadCalculator` / `FatigueIndexEngine` / `StrengthLoadEngine`; no live
  engine modified; no master/activation flag touched; no `.xcstrings` churn.

## Self-Check: PASSED
- FOUND: WorkloadApp/Services/LoadDistributionEngine.swift
- FOUND: WorkloadAppTests/LoadDistributionEngineTests.swift
- FOUND: .planning/phases/27-strength-load-strain-risk-fusion/artifacts/27-02-notes.md
- Commit hash recorded at commit time.
