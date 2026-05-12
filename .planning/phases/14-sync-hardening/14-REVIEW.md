---
phase: 14-sync-hardening
reviewed: 2026-05-10T18:42:00Z
depth: standard
files_reviewed: 7
files_reviewed_list:
  - WorkloadApp/Services/SyncEntity.swift
  - WorkloadApp/Services/SyncTimestampStore.swift
  - WorkloadApp/Services/SyncService.swift
  - WorkloadApp/Views/Profile/SyncStatusView.swift
  - WorkloadApp/App/AppRouter.swift
  - WorkloadApp/App/AppContainer.swift
  - WorkloadApp/Utilities/FontTokens.swift
findings:
  critical: 1
  warning: 3
  info: 2
  total: 6
status: issues_found
---

# Phase 14: Code Review Report

**Reviewed:** 2026-05-10T18:42:00Z
**Depth:** standard
**Files Reviewed:** 7
**Status:** issues_found

## Summary

Reviewed the sync hardening file set: SyncEntity, SyncTimestampStore, SyncService, SyncStatusView, AppRouter, AppContainer, and FontTokens. The sync infrastructure is well-structured with per-entity error isolation and a clean timestamp store. However, there is one critical bug where `shouldSync` always returns `true` due to entities that never record success, causing unnecessary sync cycles on every foreground resume. Three warnings cover fragile error classification, missing timestamp tracking for coach-initiated pushes, and a misplaced sync badge overlay. FontTokens and SyncEntity are clean.

## Critical Issues

### CR-01: `shouldSync` always returns `true` -- coachRelationships never records success

**File:** `WorkloadApp/Services/SyncTimestampStore.swift:61`
**Issue:** `shouldSync` iterates all `SyncEntity.allCases` and returns `true` if any entity has never been synced (`lastSuccess` returns `nil`). The `.coachRelationships` entity is included in `allCases` but `SyncService.pushAll()` and `SyncService.pullAll()` never call `recordSuccess(for: .coachRelationships)`. The `pullLinkedAthletes` method (the only place coach relationships are pulled) logs failures but does not update the timestamp store. This means `shouldSync` is always `true`, triggering a full sync cycle on every foreground resume (`scenePhase == .active`), defeating the 15-minute staleness window.
**Fix:** Either record success for `.coachRelationships` in the appropriate sync paths, or exclude it from the `shouldSync` check when the user is not in coach mode. The simplest correct fix is to record success in `pullAll` and `pullLinkedAthletes`:

```swift
// In pullAll(), after the existing entity pulls, add:
if await pullCoachRelationships(context: context, athlete: athlete) {
    store.recordSuccess(for: .coachRelationships)
}

// In pullLinkedAthletes(), after the successful fetch loop:
SyncTimestampStore.shared.recordSuccess(for: .coachRelationships)
```

Alternatively, change `shouldSync` to accept a set of applicable entities based on current mode, so athlete-mode users are not penalized by coach-only entities.

## Warnings

### WR-01: Error classification relies on fragile string interpolation

**File:** `WorkloadApp/Services/SyncService.swift:147-149`
**Issue:** `classifyError` converts an `Error` to string via `"\(error)"` and checks for substrings like `"401"`, `"403"`, `"500"`. The string representation of Supabase SDK errors is not contractually guaranteed to contain raw HTTP status codes. If the SDK changes its error formatting, authentication expiry and server errors will silently fall through to the generic "Sync error" label, hiding actionable information from the user.
**Fix:** Check for Supabase-specific error types that carry HTTP status codes directly. For example:

```swift
private func classifyError(_ error: Error) -> String {
    if error is URLError {
        return "Network unavailable"
    }
    if error is DecodingError {
        return "Data format error"
    }
    // Check Supabase PostgrestError which carries a status code
    if let pgError = error as? PostgrestError {
        if pgError.code == "PGRST301" || pgError.message.contains("JWT") {
            return "Authentication expired"
        }
        return "Server error"
    }
    return "Sync error"
}
```

### WR-02: Coach-initiated push methods do not record to SyncTimestampStore

**File:** `WorkloadApp/Services/SyncService.swift:698-735`
**Issue:** The `pushCoachWorkloadSnapshot`, `pushCoachRecoverySnapshot`, `pushCoachPersonalRecord`, and `pushCoachWorkoutSession` methods log failures via `logFailure` but never call `SyncTimestampStore.shared.recordFailure()` or `recordSuccess()`. This means coach-push failures are invisible in the SyncStatusView UI, and the user has no feedback that a coach-initiated operation failed.
**Fix:** Use the `run()` helper (which records to the timestamp store) instead of raw do/catch, or explicitly call `recordFailure`/`recordSuccess` in each method:

```swift
func pushCoachWorkloadSnapshot(_ snapshot: WorkloadSnapshot, for athleteId: UUID) async {
    let row = WorkloadSnapshotRow(from: snapshot, athleteId: athleteId)
    await run(.workloadSnapshots, .push) {
        _ = try await client.from("workload_snapshots").upsert(row).execute()
    }
}
```

### WR-03: Sync failure badge overlay is placed on view content, not tab bar icon

**File:** `WorkloadApp/App/AppRouter.swift:178-187`
**Issue:** The sync failure indicator (8pt yellow circle) is applied as `.overlay(alignment: .topTrailing)` on the `ProfileView()` itself, not on the tab item. This positions the dot at the top-trailing corner of the full-screen profile view content, where it will be obscured by navigation bars or scroll content. It does not appear as a badge on the tab bar icon, which is the expected UX for a persistent status indicator.
**Fix:** Use SwiftUI's `.badge()` modifier on the tab item, or move the indicator into the `ProfileView` navigation bar. For a tab badge approach:

```swift
ProfileView()
    .tabItem { Label("Profile", systemImage: "person.fill") }
    .badge(syncStore.hasAnyFailure ? "!" : nil)
```

Or render the dot inside ProfileView's toolbar for more design control.

## Info

### IN-01: pushAll and pullAll silently discard when no Athlete found

**File:** `WorkloadApp/Services/SyncService.swift:27-28`
**Issue:** Both `pushAll` and `pullAll` silently `return` when no local Athlete is found (`try? context.fetch(...)` yields nil). No error is logged and no failure is recorded in the timestamp store. While this is a valid early-exit for edge cases (e.g., post-sign-out race), it makes debugging sync-not-running issues harder.
**Fix:** Add a log statement before the early return:

```swift
guard let athlete = try? context.fetch(FetchDescriptor<Athlete>()).first else {
    print("SyncService: pushAll skipped — no local Athlete found")
    return
}
```

### IN-02: Substantial code duplication between pullPrescribedWorkouts and pullCoachPrescriptions

**File:** `WorkloadApp/Services/SyncService.swift:1188-1305`
**Issue:** `pullPrescribedWorkouts` (lines 1188-1248) and `pullCoachPrescriptions` (lines 1251-1305) contain nearly identical upsert logic for `PrescribedWorkout` records, differing only in the Supabase query filter (`athlete_id` vs `coach_id`) and whether failures are recorded in the timestamp store. This duplication increases maintenance burden and risk of divergence.
**Fix:** Extract the shared upsert loop into a private helper:

```swift
private func upsertPrescribedWorkouts(
    _ rows: [PrescribedWorkoutRow],
    context: ModelContext
) throws { ... }
```

---

_Reviewed: 2026-05-10T18:42:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
