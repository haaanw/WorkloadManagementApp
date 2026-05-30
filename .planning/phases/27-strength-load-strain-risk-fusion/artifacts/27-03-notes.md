# 27-03 notes — StrainRiskEngine (Wave 3)

## Isolation grep (Task 3) — PASS

```
grep -E "StrainRisk" WorkloadApp/Services/AutoregulationEngine.swift WorkloadApp/Services/RecoveryScoreEngine.swift
→ (no matches)  ⇒  ISOLATION_OK
```

`StrainRiskEngine` / `StrainRiskResult` / `StrainRiskZone` appear NOWHERE in the live
recommendation or recovery path. The engine `fuse(...)` consumes only the passed-in
substrate `Input` (no live recovery/recommendation input) and is pure, so it cannot reach
the live path. Display/shadow context only this phase (D-27-06).

## No master / activation flag

No master/activation flag was added or flipped. Strain-Risk is standalone substrate; it
does not gate or alter any live default.

## Fixed sign-constrained weights (named constants — NOT fitted, NOT logistic)

| Component | Weight | Sign | Evidence anchor |
|-----------|--------|------|-----------------|
| strengthLoadElevation | 0.30 | + | competitive §3.1 — structural moat, highest weight |
| enduranceLoadElevation | 0.15 | + | BaselineEngine z vs personal baseline |
| fatigueIndex | 0.20 | + | FatigueIndexEngine (FEA lineage) |
| monotonyStrain (computed) | 0.15 | + | Foster monotony, full weight when gate computed |
| monotonyStrain (fallback) | 0.07 | + | reduced weight on fallback signal when gate fell back |
| softTissue | 0.12 | + | FatigueResult.softTissueRisk (single source) + recurrence bonus |
| restDebt | 0.08 | + | FatigueIndexEngine only (D-27-05) |

All weights POSITIVE → each component pushes the score up only (sign constraint; unit-tested:
raising any single risk input never lowers the score). Missing components redistribute their
weight PROPORTIONALLY over present components (redistribution, not mean-imputation — mirrors
`FatigueIndexEngine.compute`).

## Zone thresholds (on the 0…1 score)

| Zone | Range |
|------|-------|
| low | < 0.25 |
| moderate | 0.25 … < 0.50 |
| elevated | 0.50 … < 0.70 |
| high | ≥ 0.70 |

## Single soft-tissue source (no double counting)

Soft-tissue uses `FatigueResult.softTissueRisk` ONLY (which already incorporates the
`NiggleInjuryDeriver`-derived count/recency via the fatigue path), plus a same-region
recurrence bonus (`0.15` per region from `StrengthLoadEngine.recurrenceFlags`, clamped). It
does NOT additionally apply a separate `1-exp(-0.5n)` term — that would double-count (D-27-08).

## Confidence

`confidence = clamp01(baselineConfidence(nil→0) × gateFactor × (0.5 + 0.5·coverage))` where
`gateFactor` = 1.0 (computed) / 0.5 (fellBack) and `coverage` = hardSets / (hardSets +
unscored). Confidence is 0 when baseline confidence is nil; rises with more/better data.

## No injury-prediction copy (D-27-01) — PASS

String-audit test asserts no `StrainRiskZone.displayName` or `StrainRiskFactor.label`
contains "injury prediction" / "predicts injury" / "injury risk" / "will get injured".
Framing is strictly "load-tolerance / overreaching caution".

## Reuse / purity

- Consumes precomputed `FatigueIndexEngine.FatigueResult`, `StrengthLoadEngine`/
  `LoadDistributionEngine` results, and BaselineEngine-derived endurance elevation +
  confidence as plain inputs — no upstream math duplicated (D-27-08), no SwiftData fetch.
- `StrainRiskZone` added to `Enums.swift` (shared type) → FULL `WorkloadAppTests` suite run
  to catch switch-exhaustiveness ripple — none found.
- `StrainRiskEngine.swift` registered in the app target pbxproj (ids EE2703*).

## Test result

- Targeted: `WorkloadAppTests/StrainRiskEngineTests` → **TEST SUCCEEDED**, 0 failures
  (fusion, redistribution, fallback factor, sign-constraint ×3, zone thresholds, confidence,
  determinism, recurrence, no-prediction copy audit, isolation).
- FULL `WorkloadAppTests` suite → **TEST SUCCEEDED**, 0 errors, 0 failures.
- `BaselineTierFenceTests` → all 3 PASSED (live recovery baseline byte-unchanged).
- Isolation grep == 0; no live engine modified; no master/activation flag; no `.xcstrings` churn.
