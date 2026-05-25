---
phase: 18-cycle-aware-recovery-baselines
plan: 02
subsystem: recovery-scoring
tags: [recovery, cycle, baselines, pipeline, privacy, read-time-join]
requires:
  - RecoveryScoreEngine.PhaseBucket / bucket(for:) / samePhaseBaseline(readings:) (Plan 18-01)
  - RecoveryInput.samePhaseHRVBaseline / samePhaseRestingHRBaseline (Plan 18-01)
  - CycleTrackingService.run(athlete:context:) + CycleContext (Phase 17)
  - MenstrualCycleSnapshot local-only @Model (Phase 17)
provides:
  - CycleSnapshotRepository.fetchCycleSnapshots(days:athlete:) (date-windowed phase-per-date reads)
  - RecoveryPipeline.run cycleTrackingService optional param + gated same-phase derivation
  - AppContainer.cycleTrackingService ownership
  - DashboardViewModel.load / RecoveryViewModel.onWellnessCheckInSaved cycle wiring
affects:
  - Live recovery scoring (Dashboard + Recovery tabs) now cycle-aware when data qualifies
tech-stack:
  added: []
  patterns:
    - Optional injected service param preserves identical-behavior scope lock (mirrors syncService)
    - Read-time date join (no schema change) of RecoverySnapshot x MenstrualCycleSnapshot
    - Per-component baseline fallback handled by engine `??` (Plan 01 contract)
key-files:
  created:
    - WorkloadApp/Repositories/CycleSnapshotRepository.swift
  modified:
    - WorkloadApp/Repositories/RecoveryRepository.swift
    - WorkloadApp/Services/RecoveryPipeline.swift
    - WorkloadApp/App/AppContainer.swift
    - WorkloadApp/ViewModels/DashboardViewModel.swift
    - WorkloadApp/ViewModels/RecoveryViewModel.swift
    - WorkloadApp/Views/Dashboard/DashboardView.swift
    - WorkloadApp/Views/Recovery/RecoveryView.swift
    - "workload management/workload management.xcodeproj/project.pbxproj"
decisions:
  - D-04 gate implemented verbatim (confidence >= 0.7 AND !hasExclusion AND phase != .unknown)
  - D-05 OC/pregnant/lactating fall through to 7-day via hasExclusion in the gate
  - D-06/D-07 delegated to engine `??` selection (per-component fallback + hard switch)
  - Discretion (planner-resolved) read-time join over a min((cycleLength ?? 28)*3 + 10, 365) day window
metrics:
  duration: ~12 min
  completed: 2026-05-25
  tasks: 3
  files_changed: 9
requirements: [CYCLE-04, CYCLE-05]
---

# Phase 18 Plan 02: Cycle-Aware Recovery Baselines (Pipeline Integration) Summary

Wired the same-phase baseline algorithm from Plan 18-01 into the live recovery flow. `RecoveryPipeline.run()` now accepts an optional `CycleTrackingService`, queries it for `CycleContext`, joins historical `RecoverySnapshot` HRV/RHR with the `CyclePhase` active on each date (read-time join via `MenstrualCycleSnapshot`), buckets those readings, and — only when the D-04 confidence gate passes and a bucket meets the 4-reading minimum — feeds same-phase baselines into the engine. When no service is injected, `run()` is byte-identical to the pre-change 7-day pipeline.

## What Was Built

**Task 1 — CycleSnapshotRepository + multi-cycle history window (commit d0909f4):**
- New `CycleSnapshotRepository` (`@MainActor final class`, `init(modelContext:)`) mirroring `RecoveryRepository` exactly. `fetchCycleSnapshots(days:athlete:)` performs a date-windowed, athlete-scoped `FetchDescriptor` with `#Predicate` and `sortBy: [SortDescriptor(\.date)]` so its output joins by date against recovery history.
- `RecoveryRepository.fetchRecoveryHistory` left functionally unchanged (it already accepts arbitrary `days`); added a `///` note that callers may request multi-cycle windows.
- Registered `CycleSnapshotRepository.swift` in the app target's `project.pbxproj` (PBXBuildFile + PBXFileReference + Repositories group child + Sources phase), mirroring `RecoveryRepository.swift` with fresh non-colliding IDs (`DD18020000…0001` / `DD18020100…0001`).
- No `import Supabase`, encoder, or sync code in either repository — `MenstrualCycleSnapshot` stays local-only.

**Task 2 — Gated same-phase derivation in RecoveryPipeline.run (commit b5fffd3):**
- Added `cycleTrackingService: CycleTrackingService? = nil` after `syncService` (additive — existing callers compile unchanged).
- New step 3b runs only inside `if let cycleTrackingService`: calls `await cycleTrackingService.run(athlete:context:)`, evaluates the D-04 gate `ctx.confidence >= 0.7 && !ctx.hasExclusion && ctx.phase != .unknown`. On gate pass, fetches a ~3-cycle window (`min((ctx.cycleLength ?? 28) * 3 + 10, 365)` days) of recovery history and cycle snapshots, builds a `[startOfDay: PhaseBucket]` map, and collects same-bucket HRV/RHR readings via `compactMap`-style guards (only non-nil readings count toward the 4-minimum). Results from `RecoveryScoreEngine.samePhaseBaseline(readings:)` (nil if < 4) are assigned to the new `RecoveryInput` same-phase fields.
- The 7-day `hrvBaseline`/`restingHRBaseline` are still computed (step 2) and passed in every branch — they are the fallback denominators. D-06 (per-bucket fallback) and D-07 (hard switch) are satisfied by the engine's `samePhase ?? sevenDay` selection from Plan 01.
- `upsertRecoverySnapshot` and the `syncService.pushRecoveryAndWellness` call are untouched — no cycle-derived value is persisted or synced.

**Task 3 — AppContainer ownership + ViewModel/View wiring (commit a761cd4):**
- `AppContainer` declares `let cycleTrackingService: CycleTrackingService` and initializes `CycleTrackingService()` next to `healthKitService`.
- `DashboardViewModel.load` and `RecoveryViewModel.onWellnessCheckInSaved` accept an optional `cycleTrackingService` and forward it to `RecoveryPipeline.run`.
- `DashboardView.loadData` and `RecoveryView.onCheckInSaved` pass `container.cycleTrackingService`.
- All new parameters default to nil, preserving the non-breaking guarantee. `SCREENSHOT_MODE` short-circuit in `DashboardViewModel` is unchanged.

## Verification

- `xcodebuild build` on iPhone 17 Pro Max simulator → **BUILD SUCCEEDED** after each task.
- `xcodebuild test -only-testing:WorkloadAppTests` → **TEST SUCCEEDED** (full suite incl. Plan 01 engine tests).
- Threat invariants confirmed by grep: `SyncService.swift` references none of `samePhase|estimatedPhase|CycleContext|MenstrualCycleSnapshot`; the `upsertRecoverySnapshot` call references no cycle-derived field.
- `CycleSnapshotRepository.swift` present in `project.pbxproj` (4 entries).
- nil-service path: the entire same-phase branch is guarded by `if let cycleTrackingService`, so omitting it yields the original 7-day behavior.

## Deviations from Plan

None — plan executed exactly as written. The developer's unrelated uncommitted WIP (AuthService.swift, SubscriptionService.swift, TrainingProfileSheet.swift, workload-management-Info.plist, untracked files, deleted .planning/ files) was not touched, staged, or reverted. Each commit staged only its specific plan-scoped files by explicit path.

## Threat Surface

No new security surface beyond the plan's threat model.
- T-18-04 (Info Disclosure, upsert/sync): mitigated — upsert and push unchanged; verified by grep no cycle field enters either.
- T-18-05 (Info Disclosure, repository reads): mitigated — `CycleSnapshotRepository` only fetches `MenstrualCycleSnapshot` into memory for the in-memory join; no encoder, no `import Supabase`, no upload path. Model remains local-only.
- T-18-06 (Tampering, file registration): mitigated — new file registered in pbxproj; build gate confirms inclusion. No package installs.
- T-18-07 (Info Disclosure, engine input): accept — engine receives only aggregate `Double` means (Plan 01 contract).

No threat flags: no new network endpoints, auth paths, or schema changes introduced.

## Known Stubs

None. Same-phase baselines now derive from real cycle history; the nil-service / gate-fail / <4-reading paths intentionally fall back to the 7-day baseline (graceful degradation per D-04/D-05/D-06), which is the designed behavior, not a stub.

## Self-Check: PASSED

- Files present: CycleSnapshotRepository.swift, RecoveryPipeline.swift, AppContainer.swift (all FOUND).
- pbxproj registration: 4 CycleSnapshotRepository entries present.
- Commits d0909f4, b5fffd3, a761cd4 all present in branch history.
- Build SUCCEEDED; WorkloadAppTests TEST SUCCEEDED.
