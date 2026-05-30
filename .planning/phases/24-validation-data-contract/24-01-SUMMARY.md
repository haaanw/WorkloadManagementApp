# Phase 24 Plan 01 — Summary

**Status:** Complete. Build GREEN, all Plan-01 tests pass, full unit suite green (262 passed / 0 failed / 2 skipped-pre-existing).

## What shipped

Fixed the same-day shadow date-contract leak (codex CRITICAL #3) and introduced the generic experimental-arm storage that the rest of v1.6 plugs into. No scoring model added.

### Date contract (D-01..D-05)
- `CyclePredictionLog` now carries explicit `predictionDate` (day made), `targetDate` (day about), and `predictionHorizonDays` (default 1). `targetDate = startOfDay(predictionDate) + horizon`.
- Stage-2 `resolveOutcomes` joins ALL actuals (recovery/wellness/soreness/adherence) on `row.targetDate` only — closing the leak. A D+1 prediction is scored against D+1's outcomes, never D's.
- `fetchUnresolved(targetBefore:)` gates resolvability on `targetDate < startOfDay(asOf)`.
- `upsertPrediction(predictionDate:)` keys one row per athlete per prediction day.
- `fetchResolved` windowed and time-ordered on `targetDate`.

### Generic arm store (D-11/D-12/D-13)
- New local-only `ShadowArmPrediction` child `@Model` (`armId`, `outcomeRaw`, `predicted`, parent `log`), cascade from `CyclePredictionLog`.
- `ExperimentalArm` value type + `ShadowPredictor.registeredArms()` returning exactly two arms (`baseline`, `cycleAware`) delegating to the existing static methods byte-identically.
- `recordPrediction` writes one child row per (registered arm × outcome); `aggregate` reads the arm store and reproduces the Phase-20 MAE.
- Byte-identical regression guard tests pass (`test_baselineArm_equalsBaselinePrediction_byteIdentical`, `test_cycleAwareArm_equalsCycleAwarePrediction_byteIdentical`, `test_armEquivalence_baselineAndCycleAwareMAE_matchLegacyColumns`).

### Labels (D-06)
- `recovery` flagged `engineDerived` (secondary, non-gating) via `ShadowPredictor.engineDerivedOutcomes = [.recovery]`. `wellness`/`soreness(pain)`/`adherence(completion)` are raw primary targets. `completion` reframed as adherence in naming/comments.

### Feature cutoff (D-02)
- `RecoveryPipeline` shadow block clamps each series to days ≤ `startOfDay(.now)` and asserts (DEBUG) no record is dated after the cutoff.

## Decisions taken (risk forks)

**Date-field migration:** Took the **additive / parallel** path. Added `predictionDate`/`targetDate`/`predictionHorizonDays` as new fields (optional/defaulted via the initializer) and KEPT the legacy `date` field as a stored alias of `predictionDate`. This is a pure additive SwiftData lightweight migration on the local-only store — zero risk to existing Phase-20 shadow rows. No rename, no destructive change.

**Legacy per-arm columns (assumption #3 risk fork):** Took the documented **FALLBACK / parallel** path. The legacy `*Baseline`/`*CycleAware`/`*Actual` columns are RETAINED and still written in parallel; the new `ShadowArmPrediction` store is the source of truth that `aggregate` reads. Rationale: unifying by deleting the legacy columns is a destructive migration of existing local shadow data; the parallel path proves the arm store reproduces the Phase-20 MAE byte-identically through a dedicated equivalence test without ever risking existing rows. A later phase can drop the legacy columns once the arm store has fully superseded them.

**Arm storage:** Child-row model (D-12a) as recommended — avoids column sprawl across Phases 26–28.

## Privacy / locks held
- `CyclePredictionLog` + `ShadowArmPrediction`: no `Codable`, no encoder, no sync field (grep-clean; only doc-comments mention the words). Never referenced by SyncService.
- nil-cycle-service path byte-identical — all changes are inside the `if cycleTrackingService != nil` block or its comment.
- Master activation flag untouched / OFF. No user-facing change.

## Files
- `WorkloadApp/Models/CyclePredictionLog.swift` (date contract + arm relationship + helper)
- `WorkloadApp/Models/ShadowArmPrediction.swift` (new local-only child model)
- `WorkloadApp/App/WorkloadApp.swift` (schema registration)
- `WorkloadApp/Services/ShadowPredictor.swift` (ExperimentalArm + registry + engineDerivedOutcomes)
- `WorkloadApp/Services/ShadowAnalyticsService.swift` (per-arm write, targetDate resolve, arm-store aggregate)
- `WorkloadApp/Repositories/CyclePredictionLogRepository.swift` (predictionDate upsert / targetDate gates)
- `WorkloadApp/Services/RecoveryPipeline.swift` (feature cutoff + corrected comment)
- `WorkloadAppTests/ShadowDataContractTests.swift` (new), `ShadowPredictorTests.swift`, `ShadowAnalyticsServiceTests.swift`
- `workload management/workload management.xcodeproj/project.pbxproj` (new model in app target)

Commit: `9e9e95f feat(24-01): split prediction date-contract + generic experimental-arm store`
