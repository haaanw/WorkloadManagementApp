---
phase: 30-shadow-engine-quality-fixes
plan: 03
subsystem: strain-risk-engine
tags: [shadow, strain-risk, double-count, coverage-confidence, baseline-discount]
requires: [30-01, 30-02]
provides: [single-count-fusion, easy-inclusive-coverage, baseline-discounted-confidence]
affects: []
key-files:
  modified:
    - WorkloadApp/Services/StrainRiskEngine.swift
    - WorkloadAppTests/StrainRiskEngineTests.swift
decisions: [GA-30-A, GA-30-E, GA-30-C-consumption]
metrics:
  completed: 2026-05-31
commit: bd5739d
---

# Phase 30 Plan 03: StrainRiskEngine Findings 1+5 Summary

Each underlying signal now contributes to the shadow Strain-Risk score exactly once (soft-tissue and rest-debt no longer double-counted), and coverage confidence counts easy scored sets while discounting muscles with no chronic baseline.

## Finding 1 (GA-30-A) — single-count soft-tissue + rest-debt
- New `static func fatigueExcludingSoftTissueRestDebt(_:) -> Double`: re-composes a FatigueIndex-style 0…1 value from ONLY the four exposed `FatigueResult` component fields that are not soft-tissue / rest-debt (`loadElevation*0.20 + sessionDensity*0.20 + recoveryTrend*0.20 + wellnessTrend*0.15`), re-normalised over their retained weight sum `0.75`.
- Component 3 ("Accumulated fatigue") now uses this helper instead of `fatigue.index/100`.
- Components 5 (soft-tissue + recurrence bonus, w 0.12) and 6 (rest debt, w 0.08) unchanged → each signal counted once.
- FatigueIndex internal weights re-declared locally (`FatigueInternalWeights`) with a citation comment because they are `private` in `FatigueIndexEngine` — no cross-engine API change.

### New component-3 formula
`fatigueExcl = clamp01((loadElevation*0.20 + sessionDensity*0.20 + recoveryTrend*0.20 + wellnessTrend*0.15) / 0.75)`

## Finding 5 (GA-30-E) consumption — easy-inclusive + baseline-discounted confidence
### New confidence formula
`raw = baselineConf × gateFactor × (0.5 + 0.5·coverage) × (0.5 + 0.5·baselineCoverage)`, clamped 0…1, where
- `coverage = (hard + easy) / (hard + easy + unscored)` (was `hard/(hard+unscored)`) — an all-easy fully-scored session now reports coverage 1.0 (was 0).
- `baselineCoverage = (muscles with hasChronicBaseline) / muscleCount` — a heavy new-exercise session (no chronic baseline) reads low-confidence.

## New worked-example expected score
All-maxed (all six components = 1.0; weights sum to 1.0) → **score = 1.0** (zone `.high`). The all-maxed test builder now sets the four exposed fatigue fields (load/density/recovery/wellness) to 1.0 because component 3 reads them, not the composite `index`.

## Wave-2 drift absorbed
None to absorb — StrainRiskEngineTests pass literal `monotony:` values into `loadDist(...)`, so Wave 2 did not move any worked example.

## Verification
- `StrainRiskEngineTests` — all green (incl. soft-tissue delta == 0.12, rest-debt delta == 0.08 single-count proofs; fatigueExcluding re-normalisation; all-easy full coverage; no-chronic-baseline discount; sign-constraint via exposed fields; no-injury-prediction copy audit).
- FULL `WorkloadAppTests` — `** TEST SUCCEEDED **`.
- Isolation invariant: **0** `StrainRiskEngine.fuse(`/`.confidence(` calls in `AutoregulationEngine` / `RecoveryScoreEngine`. (NOTE: the plan's bare-`StrainRisk` grep returns NONZERO — 2 hits — only via legitimate `StrainRiskZone` field-type refs at AutoregulationEngine L183/L193; the corrected gate asserts no fuse/confidence CALL, which holds.)
- `git diff --stat` on the three fence files — EMPTY.
- No `.xcstrings` churn. No flag default changed. No new injury-prediction copy (the only "injury prediction" match is the pre-existing "It is NEVER injury prediction" disclaimer in the doc comment).

## Deviations from Plan
**1. [Plan-check must-fix applied] Corrected isolation gate**
- The plan's Task-3 verify grepped the bare token `StrainRisk` and expected 0, which FALSE-FAILS because of legitimate `StrainRiskZone` field-type references in AutoregulationEngine (L183/L193). Asserted the real invariant instead: zero `StrainRiskEngine.fuse(`/`.confidence(` calls in the live engines (result 0). No fix weakened to satisfy a bogus gate.

## Self-Check: PASSED
- Commit bd5739d present on main.
- StrainRiskEngine.swift contains `hasChronicBaseline` (confidence) and `fatigueExcludingSoftTissueRestDebt`.
- StrainRiskEngineTests.swift contains `easyCount` usage + single-count delta tests.
