---
phase: 10-cold-start-questionnaire
reviewed: 2026-05-08T12:42:38Z
depth: standard
files_reviewed: 8
files_reviewed_list:
  - WorkloadApp/Repositories/TemplateRepository.swift
  - WorkloadApp/Repositories/TrainingProfileRepository.swift
  - WorkloadApp/Services/WorkoutPipeline.swift
  - WorkloadApp/ViewModels/DashboardViewModel.swift
  - WorkloadApp/Views/Dashboard/DashboardView.swift
  - WorkloadApp/Views/Dashboard/TrainingProfileCard.swift
  - WorkloadApp/Views/Profile/ProfileView.swift
  - WorkloadApp/Views/Profile/TrainingProfileSheet.swift
findings:
  critical: 1
  warning: 4
  info: 3
  total: 8
status: issues_found
---

# Phase 10: Code Review Report

**Reviewed:** 2026-05-08T12:42:38Z
**Depth:** standard
**Files Reviewed:** 8
**Status:** issues_found

## Summary

The cold-start questionnaire feature introduces `TrainingProfileSheet` (form), `TrainingProfileCard` (CTA), `TrainingProfileRepository` (persistence), `ColdStartEngine` (seeding), and integration points in `WorkoutPipeline` (switchover/bias capture), `DashboardView`, and `ProfileView` (re-edit). The `ColdStartEngine` is clean and well-structured as a pure static engine. The `TrainingProfileRepository` and model are solid.

Key concerns: (1) the switchover session count in `WorkoutPipeline` does not filter by athlete, which is a correctness bug in coach-athlete scenarios; (2) the re-edit path omits Supabase sync; (3) `TrainingProfileCard` is defined but never integrated into `DashboardView`; (4) the `hasChanges` guard on the re-edit form blocks swipe-to-dismiss even when the user makes no edits.

## Critical Issues

### CR-01: Switchover session count is unscoped -- counts ALL athletes' sessions

**File:** `WorkloadApp/Services/WorkoutPipeline.swift:89-93`
**Issue:** The cold-start switchover threshold check fetches ALL `WorkoutSession` records in the database without filtering by athlete. The comment says "Count ALL sessions for this athlete (not just recent -- lifetime total)" but the `FetchDescriptor` has no predicate. In a coach-athlete multi-user scenario where a coach has synced athlete sessions locally, sessions from other athletes inflate the count and could trigger premature switchover.
**Fix:**
```swift
// Count ALL sessions for this athlete (not just recent -- lifetime total)
let athleteIdForCount = athlete.id
let sessionPredicate = #Predicate<WorkoutSession> { $0.athlete?.id == athleteIdForCount }
let allSessionsDescriptor = FetchDescriptor<WorkoutSession>(
    predicate: sessionPredicate,
    sortBy: [SortDescriptor(\.sessionDate)]
)
let totalSessionCount = (try? modelContext.fetch(allSessionsDescriptor).count) ?? 0
```
Note: If SwiftData's type-checker cannot handle the optional chain `$0.athlete?.id`, an alternative is to fetch all sessions and filter in memory: `.filter { $0.athlete?.id == athlete.id }`.

## Warnings

### WR-01: Re-edit path does not sync updated TrainingProfile to Supabase

**File:** `WorkloadApp/Views/Profile/TrainingProfileSheet.swift:439-441`
**Issue:** When saving an existing profile (re-edit from ProfileView), the code calls `repo.updateProfile(existing)` and dismisses, but does NOT call `syncService.pushTrainingProfile()`. The new-profile path (line 462) correctly pushes to Supabase. This means profile edits are persisted locally but never synced to the backend, causing data divergence.
**Fix:**
```swift
do {
    try repo.updateProfile(existing)
    Task { await container.syncService.pushTrainingProfile(context: modelContext, athleteId: athlete.id) }
    dismiss()
} catch {
    saveError = "Couldn't save your training profile. Please try again."
}
```

### WR-02: `hasChanges` is always true on re-edit, preventing swipe-to-dismiss

**File:** `WorkloadApp/Views/Profile/TrainingProfileSheet.swift:45-48`
**Issue:** `hasChanges` checks `sessionsPerWeek != nil || avgDurationMinutes != nil || ...`. When `existingProfile` is provided, `onAppear` (lines 169-187) pre-populates all required fields to non-nil values, so `hasChanges` is immediately `true`. Combined with `.interactiveDismissDisabled(hasChanges)` (line 154), this prevents the user from swiping to dismiss even if they opened the sheet and changed nothing.
**Fix:** Track a snapshot of the original values and compare against current state:
```swift
@State private var originalSessionsPerWeek: Int? = nil
@State private var originalAvgDuration: Int? = nil
@State private var originalSRPE: Int? = nil
@State private var originalWeeksAtLevel: Int? = nil

private var hasChanges: Bool {
    if existingProfile != nil {
        return sessionsPerWeek != originalSessionsPerWeek ||
               avgDurationMinutes != originalAvgDuration ||
               typicalSRPE != originalSRPE ||
               weeksAtLevel != originalWeeksAtLevel ||
               trainingAgeYears != existingProfile?.trainingAgeYears
               // ... compare other fields
    }
    return sessionsPerWeek != nil || avgDurationMinutes != nil ||
           typicalSRPE != nil || weeksAtLevel != nil ||
           trainingAgeYears != nil || scheduleType != nil ||
           !selectedMovementTypes.isEmpty || !selectedBodyRegions.isEmpty ||
           !injuryNotes.isEmpty
}
```
And in `onAppear`, also set the `original*` fields. Alternatively, a simpler approach: set a `@State private var hasUserEdited = false` flag and flip it in each picker's `set:` callback.

### WR-03: TrainingProfileCard is defined but never integrated into DashboardView

**File:** `WorkloadApp/Views/Dashboard/TrainingProfileCard.swift:6` / `WorkloadApp/Views/Dashboard/DashboardView.swift`
**Issue:** `TrainingProfileCard` is a fully-implemented CTA component meant to prompt athletes without a `TrainingProfile` to complete the questionnaire. However, it is not referenced anywhere in `DashboardView` (or any other view). The cold-start questionnaire has no discovery path from the Dashboard -- users can only find it via `ProfileView > Set up training profile`. This may be intentional if the feature is being rolled out incrementally, but the card appears complete and ready for integration.
**Fix:** Add the card to `DashboardView` between `WelcomeActionCard` and `EmptyStateCard`:
```swift
// After WelcomeActionCard and before EmptyStateCard
@Query private var trainingProfiles: [TrainingProfile]
@State private var showTrainingProfileSheet = false

// In body, after showWelcomeCard block:
if trainingProfiles.isEmpty, athlete != nil {
    TrainingProfileCard {
        showTrainingProfileSheet = true
    }
}

// Add sheet modifier:
.sheet(isPresented: $showTrainingProfileSheet) {
    TrainingProfileSheet(existingProfile: nil)
        .environment(container)
}
```

### WR-04: Seeded ATL/CTL values not used as Dashboard fallback during cold-start window

**File:** `WorkloadApp/ViewModels/DashboardViewModel.swift:139-149`
**Issue:** The DashboardViewModel fetches the latest `WorkloadSnapshot` to display ATL/CTL/ACWR on the Dashboard. However, for a brand-new athlete who just completed the questionnaire but has zero workout sessions, no `WorkloadSnapshot` exists. The seeded ATL/CTL from `TrainingProfile` are stored but never consumed as a display fallback. This means the Dashboard Training Load section shows all dashes/zeros during the cold-start window, defeating the purpose of the questionnaire ("get estimated workload data right away" per TrainingProfileCard's copy).
**Fix:** After the workload snapshot fetch (line 142), add a fallback to seeded values:
```swift
if let snapshot = try? workloadRepo.fetchLatestSnapshot() {
    acwr = snapshot.acwr
    // ... existing code
} else {
    // Cold-start fallback: use seeded values from TrainingProfile
    let profileRepo = TrainingProfileRepository(modelContext: modelContext)
    if let profile = try? profileRepo.fetchProfile(athleteId: athlete.id),
       profile.coldStartCompletedAt == nil {
        atl = profile.seededATL
        ctl = profile.seededCTL
        acwr = profile.seededCTL > 0 ? profile.seededATL / profile.seededCTL : 0
        tsb = profile.seededCTL - profile.seededATL
        acwrZone = ACWRZone.classify(acwr)
    }
}
```
Note: This is the core value proposition of the cold-start feature. The seeded values should be displayed as estimated values (possibly with a visual indicator) until real data takes over.

## Info

### IN-01: `.font(.system(...))` used for SF Symbol icons (design system deviation)

**File:** `WorkloadApp/Views/Profile/TrainingProfileSheet.swift:252,297,330,360`
**Issue:** The design system specifies DM Sans via `Font.custom()` for all text. These lines use `.font(.system(size: 10))` and `.font(.system(size: 14))` for chevron and checkmark SF Symbols. This is consistent with the existing codebase pattern (14 occurrences across 7 files) where system fonts are used exclusively for SF Symbol icon sizing, not for body text. Not a functional issue, but worth noting for design system purity.
**Fix:** If strict compliance is desired, create a `Font.Tokens.iconSmall` and `Font.Tokens.iconMedium` token. Otherwise, this is an acceptable pragmatic exception since SF Symbols render best with system fonts.

### IN-02: Re-edit does not update `seededAt` timestamp

**File:** `WorkloadApp/Views/Profile/TrainingProfileSheet.swift:437-438`
**Issue:** When re-editing a profile, `seededATL` and `seededCTL` are recalculated and updated, but `seededAt` retains the original creation timestamp. The bias capture logic in `WorkoutPipeline` (line 113-118) uses `profile.seededAt` to calculate days elapsed. If the user re-edits their profile significantly after initial creation, the bias measurement timing could be off (e.g., bias capture triggered immediately because 56 days already passed relative to the original `seededAt`). This may be intentional if re-edit is not expected to restart the cold-start lifecycle.
**Fix:** If re-edit should restart the bias timeline, add `existing.seededAt = .now` in the re-edit path. If not, document the design decision with a comment.

### IN-03: `injuryNotes` shared across all selected body regions

**File:** `WorkloadApp/Views/Profile/TrainingProfileSheet.swift:381,412-416`
**Issue:** The injury history UI allows selecting multiple body regions and entering a single notes field. When encoding to `InjuryEntry` array (line 412-416), the same `injuryNotes` string is attached only to the first entry (via `injuries.first?.notes` on decode, line 181). The remaining entries get `nil` notes. This is a minor data modeling asymmetry -- all regions share one notes field in the UI but `InjuryEntry` has per-region notes. Not a functional bug since it round-trips correctly through the first entry, but the per-entry `notes` field on `InjuryEntry` is misleading.
**Fix:** Either attach the same notes to all entries on encode, or use a top-level notes field outside the per-region array. The current approach works but could confuse future maintainers.

---

_Reviewed: 2026-05-08T12:42:38Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
