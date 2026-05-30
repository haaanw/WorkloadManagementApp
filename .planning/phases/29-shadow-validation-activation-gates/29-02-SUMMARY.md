---
phase: 29-shadow-validation-activation-gates
plan: 02
subsystem: algorithm-moat / shadow-validation
tags: [shadow-validation, report-generator, deterministic, no-activation, human-checkpoint]
requires:
  - ActivationGateEvaluator + GateReport (Wave 1)
  - ShadowAnalyticsService.metricsReport / pairedMAEDifferenceCI (Phase 24)
  - CyclePredictionLog + ShadowArmPrediction row shape
  - ShadowMetrics.SplitMix64 (deterministic RNG)
provides:
  - ShadowValidationReportTests (seeded generator + verdict asserts + hash-equality + flag-stays-false)
  - 29-shadow-validation-report.md artifact (human-review deliverable)
affects:
  - none live — flips no flag; test-target + artifact only
tech-stack:
  added: []
  patterns: [seeded-deterministic-report-generator, fixed-date-anchor, splitmix64-rng, known-ground-truth-scenarios, glass-box-gate-panels]
key-files:
  created:
    - WorkloadAppTests/ShadowValidationReportTests.swift
    - .planning/phases/29-shadow-validation-activation-gates/artifacts/29-shadow-validation-report.md
  modified: []
decisions:
  - "Synthetic predictions = actual + ZERO-MEAN gaussian noise; the winning arm has smaller noise SD. This keeps calibration slope ≈ 1 and Spearman ρ high while still producing a clear paired-MAE win (CI upper < 0) — an alternating signed-offset earlier broke ρ / calibration."
  - "Per-outcome noise scales (completion 0.15, pain 0.4, recovery/wellness 5.0) keep additive errors on each outcome's own scale."
  - "Four scenarios with known ground truth: clearly-wins (recommends), clearly-loses (G-MAE fails 0/4), thin-data (n=10 → insufficient data), ambiguous (CIs straddle 0 → no win). Each verdict XCTAsserted."
  - "Determinism via fixed Date(timeIntervalSince1970:0)+i*86400 anchor + per-scenario SplitMix64 seed + fixed CI bootstrap seed 0x5A11DA7E; hash-equality proves byte reproducibility."
  - "Artifact path resolved from #filePath repo-root traversal with SHADOW_VALIDATION_REPORT_DIR env override + temp-dir fallback (never hard-fails in sandboxed CI)."
metrics:
  duration: ~30m
  completed: 2026-05-31
---

# Phase 29 Plan 02: Shadow-validation report generator Summary

A deterministic, seeded shadow-validation report generator (test target) that drives the Wave-1
`ActivationGateEvaluator` over synthetic PRS-vs-baseline traces resolved through the REAL Phase-24
harness, plus the generated `29-shadow-validation-report.md` artifact — with the master activation
flag machine-asserted FALSE and never flipped.

## What was built

- **`ShadowValidationReportTests`** — a deterministic execution harness:
  - Builds synthetic `CyclePredictionLog` resolved rows carrying `ShadowArmPrediction` children for
    the `"prs"` and `"baseline"` arms across the 4 continuous outcomes plus the `*Actual` fields,
    exactly as the harness aggregation reads them.
  - Runs `ShadowAnalyticsService.metricsReport(armId:"prs")` + `pairedMAEDifferenceCI(armA:"prs",
    armB:"baseline", seed:fixed)` per outcome, feeds them to `ActivationGateEvaluator`, captures the
    `GateReport`.
  - Four scenarios with known ground truth — PRS-CLEARLY-WINS (→ recommends), PRS-CLEARLY-LOSES
    (G-MAE 0/4 fail), THIN-DATA (n=10 → "insufficient data"), AMBIGUOUS (straddling CIs → no win).
  - XCTAsserts each scenario's `recommendsActivation` + per-gate verdicts vs ground truth.
  - Emits the markdown artifact with a top NO-ACTIVATION banner, a cross-scenario summary table,
    per-scenario glass-box panels (per-outcome CI + win/no-win, MAE-beat X/4 + raw-self X/3, ρ per
    primary vs 0.50, slope vs [0.8,1.2], n vs 60, overall verdict), and a closing flag-FALSE reminder.
  - Hash-equality (byte-reproducible), flag-stays-FALSE at emit (and after a synthetic PASS),
    no-prediction-copy / Tuwa-naming guards.
- **`29-shadow-validation-report.md`** — the human-review deliverable. Summary verdicts:
  CLEARLY-WINS → recommends YES; CLEARLY-LOSES / THIN-DATA / AMBIGUOUS → no.

## Verification

- `ShadowValidationReportTests` all green (verdict asserts, hash-equality, flag-stays-false,
  no-prediction-copy).
- `WorkloadAppTests` suite fully green via real `xcodebuild` (`** TEST SUCCEEDED **`).
- Tier + Autoregulation + DualRun flag fences green (within the full-suite run).
- No new packages. No app-target file. No new persisted model/column/statistic. No .xcstrings churn.
- Artifact written to the repo path; NO-ACTIVATION banner present; master flag FALSE.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Non-exhaustive switch over `ShadowPredictor.Outcome`**
- **Found during:** Task 1 first compile.
- **Issue:** Two `switch outcome` blocks omitted `.niggleSeverity` (the generator only iterates the
  4 continuous outcomes) → "Switch must be exhaustive" build failure.
- **Fix:** Added explicit `.niggleSeverity` cases (no-op / 0.0) — the outcome is never iterated here.
- **Files modified:** WorkloadAppTests/ShadowValidationReportTests.swift
- **Commit:** cb23fab

**2. [Rule 1 - Bug] Synthetic data initially failed G-SPEARMAN / G-CALIBRATION on the win scenario**
- **Found during:** Task 1 verdict asserts.
- **Issue:** The first synthetic design set `prediction = actual ± constantError` with an alternating
  per-row sign. That large alternating offset is uncorrelated with the actual signal, deflating the
  calibration slope well below 0.8 and scrambling rank order (ρ low) for the win scenario — so
  PRS-CLEARLY-WINS produced `recommends=false` against its ground truth.
- **Fix:** Redesigned predictions as `actual + ZERO-MEAN gaussian noise` with the winning arm given a
  much smaller noise SD (and per-outcome noise scales). PRS still wins the paired-MAE comparison
  (CI upper < 0) while pred tracks actual (slope ≈ 1, ρ high), matching the intended ground truth.
- **Files modified:** WorkloadAppTests/ShadowValidationReportTests.swift
- **Commit:** cb23fab

## Self-Check: PASSED
- FOUND: WorkloadAppTests/ShadowValidationReportTests.swift
- FOUND: .planning/phases/29-shadow-validation-activation-gates/artifacts/29-shadow-validation-report.md
- FOUND commit: cb23fab
