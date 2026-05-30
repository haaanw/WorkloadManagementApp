---
phase: 29-shadow-validation-activation-gates
plan: 01
subsystem: algorithm-moat / shadow-validation
tags: [activation-gates, shadow-validation, flags, report-only, no-activation]
requires:
  - ShadowAnalyticsService.metricsReport / pairedMAEDifferenceCI (Phase 24)
  - ShadowPredictor outcomes + PRS arm (Phase 28)
  - PRSActivation / CycleModifierActivation flag posture
provides:
  - PRSMasterActivation (milestone go-live flag, default FALSE)
  - ActivationGateEvaluator + GateReport (pure, report-only gate evaluation)
affects:
  - none live — every flag FALSE; recovery score + recommendation byte-unchanged
tech-stack:
  added: []
  patterns: [pure-struct-static-methods, defaults-false-flag, test-only-withEnabled-override, source-grep-isolation-guard]
key-files:
  created:
    - WorkloadApp/Services/PRSMasterActivation.swift
    - WorkloadApp/Services/ActivationGateEvaluator.swift
    - WorkloadAppTests/ActivationGateEvaluatorTests.swift
  modified:
    - workload management/workload management.xcodeproj/project.pbxproj
decisions:
  - "PRSMasterActivation is a SEPARATE milestone-level go-live gate, distinct from PRSActivation (engineering swap). Both stay FALSE."
  - "ActivationGateEvaluator exposes a pure form (b) (hand-built metric inputs, oracle-testable) + a thin @MainActor form (a) wiring ShadowAnalyticsService over resolved rows. No new statistics."
  - "G-MAE win = paired-MAE-difference CI upper bound STRICTLY < 0 (armA=prs, armB=baseline). CI upper==0 is NOT a win."
  - "G-DATA-MATURITY is a hard precondition (GA-4): n<60 OR any nil gate metric → recommendsActivation=false reason 'insufficient data', overriding all other gates."
  - "No-mutation grep guard checks for assignment substrings 'isEnabled =' / '.isEnabled =' (tolerating '==' comparisons); doc-comment references to flag names are permitted."
metrics:
  duration: ~30m
  completed: 2026-05-31
---

# Phase 29 Plan 01: Activation-gate evaluation core Summary

PRSMasterActivation (milestone go-live flag, defaults FALSE and not flipped) plus a pure,
deterministic, REPORT-ONLY `ActivationGateEvaluator` that consumes the existing Phase-24
`ShadowAnalyticsService` PRS-vs-baseline metrics and reports whether the four ROADMAP activation
gates pass — without ever mutating a flag.

## What was built

- **`PRSMasterActivation`** — enum namespace mirroring `PRSActivation` exactly: `static var isEnabled`
  defaulting to `false`, a test-only `withEnabled(_:_:)` override. Documented as the milestone-level
  go-live gate (separate from the Phase-28 engineering swap gate `PRSActivation`), NOT flipped this
  phase, with an explicit GA-7 note that no code may assign it from `recommendsActivation`.
- **`ActivationGateEvaluator` + `GateReport`** — pure struct, static methods, Foundation only.
  - Fixed named constants (GA-8): `minMAEBeatCount = 3`, `minSpearman = 0.50`,
    `calibrationLow = 0.8`, `calibrationHigh = 1.2`, `minResolvedRows = 60`.
  - **G-MAE** counts PRS wins over the 4 continuous outcomes (`.recovery`, `.wellness`,
    `.completion`, `.pain`); a win ⇔ paired-MAE-difference CI upper bound `< 0` (armA="prs",
    armB="baseline"). Passes at `>= 3`. Exposes a raw-self-report-only win sub-count (GA-2 honesty,
    excludes engine-derived `.recovery`).
  - **G-SPEARMAN** — designated primary `.wellness` ρ `>= 0.50` AND no sampled primary
    (`.wellness`/`.completion`/`.pain`, n>=60) below 0.50.
  - **G-CALIBRATION** — designated primary slope ∈ `[0.8, 1.2]` AND no sampled primary outside.
  - **G-DATA-MATURITY** — hard precondition (GA-4): min resolved-row count `< 60` OR any nil gate
    metric ⇒ `recommendsActivation = false`, reason "insufficient data", overriding all gates.
  - `recommendsActivation = (all four gates pass)` — REPORT-ONLY.
  - Pure form (b) `evaluate(prsMetrics:maeInputs:)` is the oracle-testable core; thin `@MainActor`
    form (a) `evaluate(resolvedRows:ciSeed:)` wires `ShadowAnalyticsService` (no new statistics).
- **`ActivationGateEvaluatorTests`** — oracle (all-pass / exactly-3-of-4), per-gate isolated
  failures, boundaries (ρ exactly 0.50, slope exactly 0.8 and 1.2, CI upper exactly 0 = not a win),
  thin-data (n=10) + nil-CI + nil-metric preconditions, form-(a) empty-rows no-crash, the
  activation-flag fence (PRSMasterActivation + PRSActivation + CycleModifierActivation all FALSE),
  and the no-mutation isolation grep.

## Verification

- `WorkloadAppTests` suite fully green via real `xcodebuild` (`** TEST SUCCEEDED **`).
- `ActivationGateEvaluatorTests`, `BaselineTierFenceTests`, `AutoregulationFlagFenceTests`,
  `DualRunFlagFenceTests` all green.
- No new packages. No new persisted SwiftData model/column. No .xcstrings churn committed.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] No-mutation grep guard was initially over-strict**
- **Found during:** Task 2 first test run.
- **Issue:** The first draft asserted the evaluator source contains no `PRSMasterActivation`
  substring at all. The evaluator's own doc comment legitimately NAMES the flags to explain the
  no-mutation contract, so the assertion failed on documentation, not on a real mutation.
- **Fix:** Narrowed the guard to the true GA-7 invariant — scan for assignment substrings
  `isEnabled =` / `.isEnabled =` while tolerating `==` comparisons. Doc-comment references to flag
  names are permitted (and desirable). The source contains zero `isEnabled =` substrings, so the
  guard passes while still catching any future assignment.
- **Files modified:** WorkloadAppTests/ActivationGateEvaluatorTests.swift
- **Commit:** 7f5b03e

## Self-Check: PASSED
- FOUND: WorkloadApp/Services/PRSMasterActivation.swift
- FOUND: WorkloadApp/Services/ActivationGateEvaluator.swift
- FOUND: WorkloadAppTests/ActivationGateEvaluatorTests.swift
- FOUND commit: 7f5b03e
