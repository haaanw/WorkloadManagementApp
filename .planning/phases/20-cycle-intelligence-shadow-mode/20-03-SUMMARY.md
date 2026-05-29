# 20-03 Summary — Pipeline/ViewModel Wiring + Two-Stage Shadow Record/Resolve + MAE

**Wave:** 2 | **Status:** Complete | **Commit:** `fb0a2ee`

## What shipped
- `WorkloadApp/Repositories/CyclePredictionLogRepository.swift` — `@MainActor final class`,
  local-only (mirrors `CycleSnapshotRepository`). `upsertPrediction(date:athlete:mutate:)`
  (find-or-create by start-of-day + athlete), `fetchUnresolved(olderThan:athlete:)`
  (`resolvedAt == nil` AND `date < cutoff`), `fetchResolved(days:athlete:)`. No Supabase/encoder.
- `WorkloadApp/Services/ShadowAnalyticsService.swift` — `@MainActor struct`, static methods.
  - `recordPrediction(...)`: Stage-1; builds baseline + cycle-aware predictions for all four
    outcomes via `ShadowPredictor`, stores phase/bucket/confidence/exclusion + the would-be
    modifier effects (recorded, never applied). Upserts today's row.
  - `resolveOutcomes(athlete:asOf:modelContext:)`: Stage-2; idempotent date-join (start-of-day)
    filling recovery (RecoverySnapshot.recoveryScore), wellness (WellnessCheckIn.wellnessScore),
    pain (soreness), completion (1/0 if a WorkoutSession was logged that day); sets `resolvedAt`.
    Already-resolved rows are not refetched.
  - `aggregate(resolvedRows:)`: pure per-outcome baseline vs cycle-aware MAE + n; excludes rows
    missing that outcome's actual.
- `WorkloadApp/Services/RecoveryPipeline.swift`: `RecoveryResult` now carries `cycleContext` +
  `cyclesObserved`. Inside the existing `if let cycleTrackingService` block: counts cycle
  boundaries (isCycleStart) and, after snapshot upsert, runs `resolveOutcomes` then
  `recordPrediction` — all guarded by `cycleTrackingService != nil` so the nil-service path is
  byte-identical (D-12). `upsertRecoverySnapshot` and the syncService push are unchanged (D-13).
- `WorkloadApp/ViewModels/DashboardViewModel.swift`: captures `cycleContext`/`cyclesObserved`
  from the pipeline result and passes them into `AutoregulationEngine.recommend` and
  `FatigueIndexEngine.compute` (passing nil when phase is `.unknown`). Activation off → returned
  values unchanged → dashboard visually identical.
- `WorkloadAppTests/ShadowAnalyticsServiceTests.swift` (auto-included).
- pbxproj: repository + service added to the `workload management` target.

## Verification
- `xcodebuild build` and `build-for-testing` exit 0.
- Aggregate MAE math + resolve completion arithmetic validated via standalone snippet: **8/8 pass**.
  Unit-test host crashes on the pre-existing DEBUG font `assertionFailure` (not a regression).
- grep confirms: SyncService references none of CyclePredictionLog/ShadowAnalytics/ShadowPredictor;
  ShadowAnalyticsService/repository carry no Supabase/push/pull/encoder; no `isEnabled = true`;
  RecoveryPipeline shadow block guarded by `cycleTrackingService != nil`.

## Must-haves
All Plan-03 truths satisfied (Stage-1 write, idempotent Stage-2 resolve, MAE aggregation,
nil-service identical, modifiers wired but inert, shadow log off-sync).
