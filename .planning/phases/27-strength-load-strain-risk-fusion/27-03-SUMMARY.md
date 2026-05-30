---
phase: 27-strength-load-strain-risk-fusion
plan: 03
subsystem: algorithm-substrate
tags: [strain-risk, glass-box-fusion, sign-constrained, shadow-gated, no-injury-prediction]
requires: [27-01, 27-02, 25-soreness-tweak-self-log, 26-individualized-baselines]
provides: [StrainRiskEngine, StrainRiskZone]
affects: [28-readiness-fusion]
tech-stack:
  added: []
  patterns: [pure-static-engine, fixed-glass-box-weighted-sum, redistribution-not-imputation, sign-constraint]
key-files:
  created:
    - WorkloadApp/Services/StrainRiskEngine.swift
    - WorkloadAppTests/StrainRiskEngineTests.swift
    - .planning/phases/27-strength-load-strain-risk-fusion/artifacts/27-03-notes.md
  modified:
    - WorkloadApp/Models/Enums.swift
    - workload management/workload management.xcodeproj/project.pbxproj
decisions:
  - "Soft-tissue single source = FatigueResult.softTissueRisk (+ recurrence bonus); no separate 1-exp term (avoids double counting, D-27-08)"
  - "Fixed sign-constrained named weights; redistribution over present components; NOT logistic / NOT fitted"
  - "Strain-Risk isolated from live path (grep == 0); no master/activation flag"
metrics:
  duration: single-session
  completed: 2026-05-30
---

# Phase 27 Plan 03: StrainRiskEngine Summary

Pure deterministic `StrainRiskEngine` — a FIXED sign-constrained glass-box fusion of the
Phase-27 substrate (strength-load elevation, gated Foster monotony/strain, endurance-load
elevation, FatigueIndex, soft-tissue memory + same-region recurrence, rest-debt) into an
honest 0–1 Strain-Risk score + `StrainRiskZone` + ranked factors + confidence. Load-tolerance
/ overreaching-caution context only — never injury prediction — provably isolated from the
live recommendation/recovery path, live recovery score byte-unchanged.

## What was built

- **`StrainRiskZone`** (in `Enums.swift`) — `String, Codable, CaseIterable, Identifiable`,
  cases `.low/.moderate/.elevated/.high`, displayName + systemImage. Copy is strictly
  load-tolerance/overreaching framing — no injury-prediction language.
- **`StrainRiskEngine.swift`** — pure `struct`, static methods, Foundation-only.
  - `Input` bundle: `StrengthLoadResult` + `LoadDistributionResult` + precomputed
    `FatigueResult` + optional BaselineEngine-derived endurance elevation + baseline
    confidence (no SwiftData fetch, no stateful call).
  - `fuse(_:)` → `StrainRiskResult` { score 0…1, zone, ranked factors (top 4), confidence
    0…1 }. Fixed named weights, each component clamped 0…1, weight redistributed over present
    components when absent (no mean-impute), sign-constrained (every component pushes up).
    Gated monotony substitutes the fallback signal at reduced weight with an honest
    "limited data" factor.
  - `zone(for:)` named thresholds; `confidence(_:)` = baseline conf × gate factor × coverage.
- **`StrainRiskEngineTests.swift`** — fusion worked example, all-zero, redistribution,
  fallback factor, sign-constraint (×3), zone boundaries, confidence (0 when baseline nil /
  rises with data), recurrence raises score, determinism, no-injury-prediction copy audit,
  isolation/purity.

## Decisions made

- **Single soft-tissue source** = `FatigueResult.softTissueRisk` (already incorporates
  `NiggleInjuryDeriver` via the fatigue path) + a same-region recurrence bonus from
  `StrengthLoadEngine.recurrenceFlags`. No separate `1-exp(-0.5n)` term → no double counting
  (D-27-08).
- **Fixed sign-constrained glass-box**, not logistic / not fitted (codex §301). All weights
  are compile-time named constants.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Isolation test simplified to avoid fragile live-engine init**
- **Found during:** Task 3. `RecoveryScoreEngine.RecoveryInput` has ~50 fields with no
  convenient memberwise shortcut; instantiating it in the guard test was brittle.
- **Fix:** The authoritative isolation proof is the Task-3 grep (recorded in
  `artifacts/27-03-notes.md`, result `ISOLATION_OK`). The guard test instead documents intent
  by asserting `fuse` depends only on the passed-in substrate (purity/determinism), which is
  the meaningful, non-brittle invariant.
- **Files modified:** `WorkloadAppTests/StrainRiskEngineTests.swift`

(App-target pbxproj registration is the same explicit-membership step as Waves 1–2.)

## Verification

- `WorkloadAppTests/StrainRiskEngineTests` → **TEST SUCCEEDED**, 0 failures.
- FULL `WorkloadAppTests` suite (run because `Enums.swift` shared type changed) →
  **TEST SUCCEEDED**, 0 errors, 0 failures — no switch-exhaustiveness ripple.
- `BaselineTierFenceTests` → all 3 PASSED (live recovery baseline byte-unchanged).
- Isolation grep: `AutoregulationEngine.swift` + `RecoveryScoreEngine.swift` reference
  StrainRisk* → 0 matches.
- No-injury-prediction copy audit green; fixed named weights (no fit/logistic); no
  master/activation flag; no `.xcstrings` churn.

## Self-Check: PASSED
- FOUND: WorkloadApp/Services/StrainRiskEngine.swift
- FOUND: WorkloadAppTests/StrainRiskEngineTests.swift
- FOUND: .planning/phases/27-strength-load-strain-risk-fusion/artifacts/27-03-notes.md
- Commit hash recorded at commit time.
