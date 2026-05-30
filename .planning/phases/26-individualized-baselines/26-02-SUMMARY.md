---
phase: 26-individualized-baselines
plan: 02
subsystem: recovery-baseline-engine
tags: [algorithm, ewma, welford, mad, huber, prequential, altini-cv, confidence, pure-engine]
requires: ["26-01"]
provides:
  - "BaselineEngine (pure stateless struct): lambda/median/robustScale/score/cvUpdate/confidence/step"
  - "BaselineEngine.SignalState value mirror, BaselineEngine.CVWarning enum, BaselineConstants, SignalConfig"
affects:
  - "Phase 26-03 (DayBucketer / caller — owns the lastBucketedDate idempotency cutoff, W-1 contract)"
  - "Phase 26-04 (convergence report — reads SignalState, deterministic byte-reproducible)"
  - "Phase 28 (consumes CVWarning + z + confidence as context)"
tech-stack:
  added: []
  patterns:
    - "Pure-struct static-method engine (CLAUDE.md convention; mirrors WorkloadCalculator/RecoveryScoreEngine)"
    - "Prequential no-leak via STRUCTURALLY separate score() / step() methods"
    - "Detect-honestly (raw innovation) / update-robustly (Huber-clipped innovation) split"
    - "Dateless engine — day-advance/idempotency owned by the caller (W-1)"
key-files:
  created:
    - "WorkloadApp/Services/BaselineEngine.swift"
    - "WorkloadAppTests/BaselineEngineTests.swift"
  modified:
    - "workload management/workload management.xcodeproj/project.pbxproj (4 app-target entries for BaselineEngine.swift)"
decisions:
  - "Sign convention API = per-signal `SignalConfig.higherIsBetter` (true for HRV/sleep, false for RHR) rather than a bare Bool param — bundles half-life + σ floor + sign in one value so callers pass `.hrv`/`.rhr`/`.sleep`."
  - "W-1 cutoff owner = CALLER/DayBucketer. Engine is dateless and does NOT self-guard; `step` stamps `lastBucketedDate` when given a `bucketedDate` but performs no day arithmetic. Contract documented in the type doc-comment and proven by test_idempotencyCutoff."
  - "All §8.3 constants used verbatim — NO defaults adjusted (hrvHalfLife=7, rhrHalfLife=10, sleepHalfLife=7, madScaleK=1.4826, W=21, W_min=5, huberK=1.5, floors 3.0/1.5/15.0, cv 7/28/1.25/1.5/1.10/14/7, conf 14/60/2.0/1.0/7)."
  - "robustScale falls back to Welford SD only while buffer < W_min (cold-start fill), else MAD×1.4826; both floored."
metrics:
  duration: "~10 min"
  completed: "2026-05-30"
  tasks: 2
  files: 3
  commits: 2
  tests: "10/10 pass (BaselineEngineTests)"
---

# Phase 26 Plan 02: BaselineEngine (robust per-signal baseline math core) Summary

A pure, **stateless**, deterministic `BaselineEngine` implementing the full robust per-signal online estimator — EWMA mean (half-life→λ), Welford M2 + rolling MAD×1.4826 dispersion, Huber-clipped bounded update (k=1.5), prequential no-leak z-score (σ floor + cold-start nil), Altini dispersion-ratio CV early-warning on innovations (3-level hysteresis), and composite 0–1 confidence with no population prior — operating on a `SignalState` value mirror with every tunable a named constant and zero time/RNG. Proven against hand-computed oracles to 1e-9 via real xcodebuild, parallel to and gated OFF from the live recovery path.

## What was built

**Task 1 — `BaselineEngine.swift`** (commit `619fd80`): pure `struct BaselineEngine` of static methods only.
- `enum CVWarning: String { normal, elevated, high }` (round-trips to `BaselineState.cvLevelRaw`).
- `struct SignalState` value mirror: `mu? / welfordMean / m2 / count / madBuffer:[Double] / lastBucketedDate? / cvRatio? / cvLevel / confidence`.
- `enum BaselineConstants` — the single home for every §8.3 tunable; `struct SignalConfig` (`.hrv`/`.rhr`/`.sleep`) bundling half-life + σ floor + `higherIsBetter`.
- Methods: `lambda(halfLifeDays:)=1−2^(−1/H)` (0 for .infinity); `median`; `robustScale` (MAD×1.4826 floored, Welford cold-start fill); `score(state:observation:config:)→(z?,innovation)` on the **raw** innovation, σ from state through t-1, nil for count<2 or buffer<W_min; `cvUpdate` (short/long robust-dispersion ratio, hysteresis, min-valid suppression) on **raw** innovations; `confidence(state:daysSinceLastBucket:)` = c_count·c_recency·c_disp; `step(state:observation:config:bucketedDate:)→SignalState` Huber-clipping the raw innovation, EWMA-folding the **clipped** ŷ, advancing Welford on ŷ, pushing the **raw** r into the W-length ring buffer, updating CV — **pure** (input never mutated).
- 4 app-target pbxproj entries added in the Services group.

**Task 2 — `BaselineEngineTests.swift`** (commit `228130f`): 10 tests, all green, numeric oracles to 1e-9.
`test_lambdaMatchesFormula`, `test_ewmaFoldOracle`, `test_welfordVsTwoPass` (W-2), `test_madOracle`, `test_huberClampsOutlier`, `test_noLeakOrdering`, `test_sigmaFloorAndColdNil`, `test_confidenceRamp`, `test_cvFiresOnInstability`, `test_idempotencyCutoff`.

## PLAN-CHECK resolutions

- **W-1 (idempotency cutoff owner — PINNED):** the `lastBucketedDate` monotonic cutoff has ONE concrete owner — the **caller/DayBucketer (Plan 26-03)**. The engine is dateless and does NOT self-guard. The contract is documented in the `BaselineEngine` type doc-comment ("`step` MUST be called exactly once per advanced bucketed day … only when `startOfDay(t) > state.lastBucketedDate`") and on `step`. `test_idempotencyCutoff` proves it two ways: (1) `step` stamps `lastBucketedDate` (the caller's cutoff source); (2) an emulated caller guard `t > last` makes re-presenting a day a no-op (count/μ unchanged) while a strictly-later day folds.
- **W-2 (Welford oracle centering — FIXED):** `test_welfordVsTwoPass` centers the variance on the separate `welfordMean` accumulator (NOT the EWMA μ). It uses a mean≫variance array (~1e6 ± a few) with no clipping so `welfordMean == simple mean`, asserts `m2/(n−1) == two-pass variance` to 1e-9, and documents that centering on μ would spuriously fail.
- **W-3 (proof, not build-only):** both tasks proven by `xcodebuild test` (not build-only). Task 1's build is green; Task 2's 10 behavior tests all pass on the iPhone 17 Pro Max sim.

## Build & verification

- **Task 1:** `xcodebuild build` → **BUILD SUCCEEDED**.
- **Task 2:** `xcodebuild test -only-testing:WorkloadAppTests/BaselineEngineTests` → **TEST SUCCEEDED**, 10/10 pass.
- **Grep gate (engine, in code):** no `Date(` / `.now` / `Calendar.current` / `SystemRandomNumberGenerator` (only doc-comment prose mentions them). No `RecoveryScoreEngine` / `RecoveryPipeline` / `SyncService` symbol in code.
- **Grep gate (tests, in code):** no `.now` / system RNG (fixed `Date(timeIntervalSince1970:)` anchor + explicit arrays).
- **Tier fence:** `RecoveryScoreEngine.swift` / `RecoveryPipeline.swift` byte-unchanged (`git diff` empty); live 7-day-mean baseline untouched; engine is standalone/parallel/gated-OFF.
- **pbxproj:** `BaselineEngine.swift` added as 4 app-target entries (PBXBuildFile + PBXFileReference + Services group + app PBXSourcesBuildPhase); test file auto-included via the synchronized WorkloadAppTests group.
- **xcstrings hygiene:** no `Localizable.xcstrings` / `InfoPlist.xcstrings` churn was produced by either build; nothing to discard, nothing staged.

## Deviations from Plan

None for Rules 1–4. Two in-test oracle adjustments during Task 2 (test-only, no engine change):
- `test_lambdaMatchesFormula` loose sanity constant tightened to the correct rounded λ (the 1e-9 formula assert is the real oracle).
- `test_cvFiresOnInstability` uses a tiny `floor=0.001` for the dispersion-RATIO checks so the MAD ratio drives the level (the per-signal σ floor of 3.0 would otherwise dominate the denominator and swamp small-magnitude oracle residuals). Engine behavior unchanged; this is correct test construction.

## Self-Check: PASSED
- `WorkloadApp/Services/BaselineEngine.swift` — FOUND
- `WorkloadAppTests/BaselineEngineTests.swift` — FOUND
- Commit `619fd80` (feat 26-02 engine) — FOUND
- Commit `228130f` (test 26-02) — FOUND
