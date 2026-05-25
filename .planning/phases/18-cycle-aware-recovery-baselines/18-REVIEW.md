---
phase: 18-cycle-aware-recovery-baselines
reviewed: 2026-05-25T13:47:51Z
depth: standard
files_reviewed: 11
files_reviewed_list:
  - WorkloadApp/Services/RecoveryScoreEngine.swift
  - WorkloadApp/Services/RecoveryPipeline.swift
  - WorkloadApp/Repositories/CycleSnapshotRepository.swift
  - WorkloadApp/Repositories/RecoveryRepository.swift
  - WorkloadApp/App/AppContainer.swift
  - WorkloadApp/ViewModels/DashboardViewModel.swift
  - WorkloadApp/ViewModels/RecoveryViewModel.swift
  - WorkloadApp/Views/Dashboard/DashboardView.swift
  - WorkloadApp/Views/Recovery/RecoveryView.swift
  - WorkloadApp/Views/Profile/ProfileView.swift
  - WorkloadAppTests/RecoveryScoreEngineTests.swift
findings:
  critical: 1
  warning: 4
  info: 3
  total: 8
status: issues_found
---

# Phase 18: Code Review Report

**Reviewed:** 2026-05-25T13:47:51Z
**Depth:** standard
**Files Reviewed:** 11
**Status:** issues_found

## Summary

Phase 18 implements confidence-gated same-phase HRV/RHR recovery baselines. The core engine work is well-executed: `RecoveryScoreEngine` stays a pure Foundation-only struct, the same-phase fields default to nil so the no-cycle path is byte-identical to the prior 7-day path (well-covered by `test_samePhaseNil_identicalToOriginalBehavior`), and the confidence gate (`confidence >= 0.7 && !hasExclusion && phase != .unknown`) is correctly implemented in `RecoveryPipeline`. The same-phase baselines are kept transient on `RecoveryInput` and are never written to `RecoverySnapshot`, so the composite `RecoverySnapshotRow` sync path remains clean.

However, the central privacy invariant of this feature is violated end-to-end: the reproductive-health flags that drive the cycle-aware gate (`isOnHormonalContraceptive`, `isPregnant`, `isLactating`) are pushed to and pulled from a Supabase `athletes` table. Although the columns were added in Phase 17, Phase 18 is the feature that consumes them (`CycleContext.hasExclusion`), making this a cycle-derived data leak squarely on the feature surface under review. This is a BLOCKER.

Additional findings: a stale/abandoned app name ("Faros") in new user-facing cycle-prompt copy, a latent same-phase-baseline-of-zero fallthrough, a couple of robustness gaps, and minor DESIGN.md/quality notes.

## Critical Issues

### CR-01: Reproductive-health flags (cycle exclusion inputs) are synced to Supabase

**File:** `WorkloadApp/Services/SyncService.swift:232-234` (push), `269-271` (pull), `827-829` (`AthleteRow`); schema `migrations/add_cycle_fields_to_athletes.sql:3-5`
**Issue:** The Phase 18 confidence gate depends on `CycleContext.hasExclusion`, which is derived from `athlete.isOnHormonalContraceptive`, `athlete.isPregnant`, and `athlete.isLactating` (see `CycleTrackingService.run` lines 27, 62, 99-101 and `CycleContext.hasExclusion` in `MenstrualCycleSnapshot.swift:67-69`). These three fields are reproductive-health / cycle-derived data. `SyncService.pushAthlete` serializes them into `AthleteRow` and uploads to the Supabase `athletes` table, and `pullAthlete` reads them back. The migration adds dedicated columns `is_on_hormonal_contraceptive`, `is_pregnant`, `is_lactating`.

This directly violates the Phase 18 invariant ("raw cycle/menstrual data ... must NEVER be persisted to or synced via Supabase — only composite scores") and the project-wide HealthKit/privacy constraint in CLAUDE.md ("Raw HealthKit data must never be uploaded to Supabase — only composite scores"). Pregnancy/lactation/contraceptive status is among the most sensitive health categories and is now stored server-side, also exposing it to any coach with row visibility depending on RLS.

`MenstrualCycleSnapshot`, `CyclePhase`, `CycleContext`, and the same-phase baselines themselves are correctly local-only — the leak is specifically these three Athlete booleans.

**Fix:** Remove the three fields from the Supabase sync path and keep them local-only, consistent with `MenstrualCycleSnapshot`.

```swift
// AthleteRow: drop these three fields entirely
// (delete lines 827-829: isOnHormonalContraceptive / isPregnant / isLactating)

// pushAthlete: stop sending them
let row = AthleteRow(
    id: athlete.id,
    userId: userId,
    // ... existing non-cycle fields ...
    // REMOVE: isOnHormonalContraceptive / isPregnant / isLactating
    createdAt: athlete.createdAt,
    updatedAt: athlete.updatedAt
)

// pullAthlete: stop reading them (delete lines 269-271)
```

Also drop the columns server-side (new migration `ALTER TABLE athletes DROP COLUMN ...`) so existing rows do not retain the data. These flags are user-entered toggles in `ProfileView`; persist them locally via SwiftData only (they already live on the local `Athlete` model).

## Warnings

### WR-01: Stale/abandoned app name "Faros" in user-facing cycle-prompt copy

**File:** `WorkloadApp/Views/Dashboard/DashboardView.swift:82`
**Issue:** The new Phase 18 cycle soft-prompt reads: "...cycle-aware recovery insights. **Faros** reads existing data from apps like Clue, Flo, or Apple Cycle Tracking...". The app's official name is **Tuwa** (bundle `com.tonus.app`). "Faros" is an abandoned name. Every other user-facing string in the reviewed files correctly says "Tuwa" (e.g. `ProfileView.swift:215, 880`). Shipping "Faros" in production copy is a user-visible defect and a brand inconsistency.
**Fix:**
```swift
Text("Track your menstrual cycle in Apple Health to get cycle-aware recovery insights. Tuwa reads existing data from apps like Clue, Flo, or Apple Cycle Tracking \u{2014} no manual re-entry needed.")
```

### WR-02: Same-phase baseline of 0 drops the component instead of falling back to 7-day

**File:** `WorkloadApp/Services/RecoveryScoreEngine.swift:105-107, 116-118`
**Issue:** The per-component selection is `let baseline = input.samePhaseHRVBaseline ?? input.hrvBaseline, baseline > 0`. The `??` resolves first, so if `samePhaseHRVBaseline` is non-nil but `<= 0`, `baseline > 0` fails and the **entire** HRV component is dropped even when a valid 7-day `hrvBaseline > 0` exists. This breaks the intended D-06 per-bucket fallback (which should fall back to the 7-day baseline, not silently delete the component and redistribute its weight). In practice `samePhaseBaseline` averages positive HRV/RHR readings so 0 is not currently reachable, hence WARNING rather than BLOCKER — but it is a latent correctness gap with no test guarding it.
**Fix:** Select the baseline with an explicit positivity check per source so a non-positive same-phase value falls back rather than nullifying the component:
```swift
let hrvBaselineSelected: Double? = {
    if let sp = input.samePhaseHRVBaseline, sp > 0 { return sp }
    if let seven = input.hrvBaseline, seven > 0 { return seven }
    return nil
}()
if let hrv = input.hrvSDNN, let baseline = hrvBaselineSelected {
    // ... same as today ...
}
```

### WR-03: Cycle pipeline re-runs HealthKit fetch + snapshot upsert on every dashboard foreground

**File:** `WorkloadApp/Views/Dashboard/DashboardView.swift:227-231` + `WorkloadApp/Services/RecoveryPipeline.swift:74-113` + `WorkloadApp/Services/CycleTrackingService.swift:25-103`
**Issue:** `DashboardView.onChange(of: scenePhase)` calls `loadData()` on every `.active` transition, which calls `RecoveryPipeline.run(..., cycleTrackingService:)`. When the service is present, `run()` performs a 365-day menstrual-flow HealthKit query, a 30-day wrist-temp query, cycle-start detection, and a `MenstrualCycleSnapshot` upsert (`try? context.save()`) on every foreground — and again after each wellness check-in via `RecoveryViewModel.onWellnessCheckInSaved`. There is no once-per-day guard like the existing `shouldForegroundSync` time gate. This is repeated unconditional HealthKit I/O and writes; failures inside the service are swallowed with bare `print`/`try?`, so a persistently failing save would never surface. (Pure performance cost is out of scope, but the unbounded repeated writes + fully-suppressed errors are a robustness concern.)
**Fix:** Gate the cycle pipeline run to at most once per day (e.g. skip when today's `MenstrualCycleSnapshot` already exists and is fresh), and surface persistent `context.save()` failures in `CycleTrackingService.upsertSnapshot` instead of `try?`-swallowing them.

### WR-04: Read-time phase join silently yields no same-phase baseline when cycle/recovery dates are misaligned

**File:** `WorkloadApp/Services/RecoveryPipeline.swift:87-105`
**Issue:** The join keys `RecoverySnapshot` and `MenstrualCycleSnapshot` on `calendar.startOfDay(for: snap.date)`. Both models are written at `startOfDay` today, but `Calendar.current` is captured separately for each side and any historical row written under a different timezone/DST offset, or a `RecoverySnapshot.date` that is not exactly `startOfDay`, will fail the dictionary `==` lookup. When the join misses, `sameBucketHRV/RHR` stay below the 4-reading minimum and the feature silently falls back to 7-day with no diagnostic — making the gate appear to "work" while never actually engaging. There is no test exercising the pipeline-level join (tests only cover the pure engine). 
**Fix:** Add an integration-level test for the read-time join (seed aligned `RecoverySnapshot` + `MenstrualCycleSnapshot` rows and assert a same-phase baseline is produced), and normalize both date keys through a single shared `Calendar`/timezone helper to guarantee alignment.

## Info

### IN-01: `cycleSnapshots` @Query is not athlete-scoped on Dashboard

**File:** `WorkloadApp/Views/Dashboard/DashboardView.swift:24, 38-40`
**Issue:** `@Query private var cycleSnapshots: [MenstrualCycleSnapshot]` and `showCyclePrompt` (`cycleSnapshots.isEmpty`) are not filtered by the current athlete, unlike `RecoveryView` which uses `scopedRecoverySnapshots`. In a multi-athlete local store this could suppress the prompt for an athlete who has no snapshots but whose store contains another athlete's. Low impact (single-athlete is the norm locally and `allCheckIns` is likewise unscoped), but inconsistent with the scoping convention.
**Fix:** Filter by `athlete?.id` as `RecoveryView.scopedRecoverySnapshots` does.

### IN-02: SF Symbol sizing via `.font(.system(size:))` in new cycle-prompt UI

**File:** `WorkloadApp/Views/Dashboard/DashboardView.swift:77` (xmark), `339` (chevron)
**Issue:** DESIGN.md mandates `Font.Tokens.*` and forbids `.system()`. These two instances are on `Image(systemName:)` (icons), which is the conventional way to size SF Symbols and matches existing pre-Phase-18 usage (e.g. `ProfileView.swift:281, 302`). Flagging for DESIGN.md QA awareness; if the design system defines an icon-sizing token, prefer it. No `RoundedRectangle` or `.shadow()` were found — corner/shadow constraints are respected.
**Fix:** If an icon-size token exists, use it; otherwise confirm with the design owner that `.system(size:)` on `Image` is acceptable.

### IN-03: Dead/unused `removeRelationship` helper

**File:** `WorkloadApp/Views/Profile/ProfileView.swift:689-695`
**Issue:** `private func removeRelationship(_:)` has no call sites in `ProfileView` (the "MY COACHES"/"MY ATHLETES" rows render `LinkedPartyRow` with no remove action). Dead code. Pre-existing, not introduced by Phase 18, but surfaced while reviewing the file.
**Fix:** Remove the unused method or wire it to a remove affordance if intended.

---

_Reviewed: 2026-05-25T13:47:51Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
