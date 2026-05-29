# 20-01 Summary — Shadow-Mode Foundation

**Wave:** 1 | **Status:** Complete | **Commit:** `1b37089`

## What shipped
- `WorkloadApp/Models/CyclePredictionLog.swift` — local-only `@Model` (D-01/D-13).
  Stores cycle state (`estimatedPhase`, `phaseBucketRaw`, `confidence`, `hadExclusion`),
  per-outcome `{Baseline, CycleAware, Actual}` Doubles for the four D-02 outcomes
  (recovery/wellness/completion/pain), the three would-be modifier fields for Plan 02/03
  (`wouldBeVolumeFactor`, `wouldBeDampenedFatigueIndex`, `wouldBiasProgressionToMaintain`),
  and `resolvedAt` for Stage-2 idempotency. No `Codable`, no `import Supabase`, no encoder.
- `WorkloadApp/Services/ShadowPredictor.swift` — pure struct, Foundation only.
  `baselinePrediction(series:)` = last value + `RecoveryScoreEngine.computeSlope` one-step
  extrapolation (neutral 50 on empty, persistence on single). `cycleAwarePrediction` =
  baseline + `phaseOffset`. Literature-derived offsets: luteal recovery -4, wellness -3,
  completion -0.05, pain +0.3; follicular and `.unknown` = 0. `absoluteError(predicted:actual:)`.
- Schema registration in `WorkloadApp.swift` (font assertion block untouched) and
  `PreviewData.swift`. pbxproj: both app files added to the `workload management` target
  (4 entries each: build file, file ref, group child, Sources phase).
- `WorkloadAppTests/ShadowPredictorTests.swift` — auto-included via fileSystemSynchronizedGroups.

## Verification
- `xcodebuild build` exits 0.
- ShadowPredictor logic validated via standalone Swift snippet: **24/24 pass** (baseline
  formula, unknown/none == baseline for all outcomes, follicular zero, luteal offset
  directions, error metric). The XCUnit host crashes on launch on the pre-existing DEBUG
  font `assertionFailure` in WorkloadApp.swift (confirmed Phases 19/21/22, NOT a regression).
- `grep` confirms no Supabase/Codable/encoder/sync reference in CyclePredictionLog or ShadowPredictor.

## Must-haves
All Plan-01 truths satisfied: local-only @Model with two-stage fields, schema-registered,
deterministic baseline + cycle-aware predictions, unknown/nil = no-op, pure struct, error metric.
