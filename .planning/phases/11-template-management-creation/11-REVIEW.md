---
phase: 11-template-management-creation
reviewed: 2026-05-09T12:00:00Z
depth: standard
files_reviewed: 7
files_reviewed_list:
  - WorkloadApp/Components/ToastBanner.swift
  - WorkloadApp/Views/TemplateEditorSheet.swift
  - WorkloadApp/Views/WorkoutLog/ActiveWorkoutSheet.swift
  - WorkloadApp/Views/WorkoutLog/FinishWorkoutSheet.swift
  - WorkloadApp/Views/WorkoutLog/TemplateCarouselSection.swift
  - WorkloadApp/Views/WorkoutLog/TemplatePreviewSheet.swift
  - WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift
findings:
  critical: 1
  warning: 5
  info: 3
  total: 9
status: issues_found
---

# Phase 11: Code Review Report

**Reviewed:** 2026-05-09
**Depth:** standard
**Files Reviewed:** 7
**Status:** issues_found

## Summary

Reviewed template management UI files (editor, carousel, preview, toast) and the updated workout log view. The code is well-organized and follows project conventions (pure draft structs, SwiftData patterns, design system tokens). One critical bug exists in the template editor save path where old exercise groups may not be deleted correctly due to SwiftData cascade timing. Several warnings around silent error suppression and a race condition between sheet dismissal and save completion.

## Critical Issues

### CR-01: Deleting old groups before reassignment may orphan or crash on cascade timing

**File:** `WorkloadApp/Views/TemplateEditorSheet.swift:215`
**Issue:** When editing an existing template, the code deletes all old `ExerciseGroup` objects via `modelContext.delete(group)` in a loop, then immediately sets `template.groups = []`, then builds new groups and appends them. SwiftData's cascade delete (groups -> exercises -> sets) is deferred until the context saves. Between the delete calls and the save at line 261, the template's `groups` relationship is cleared and repopulated. If `ExerciseGroup` has a cascade `deleteRule` to `TemplateExercise` and `TemplateSet`, the deferred deletes may interfere with the newly inserted objects if any share identity (e.g., same persistent model ID on re-edit). More immediately, `template.groups` is an array fetched from the relationship -- iterating it while the relationship is being mutated by `modelContext.delete` can produce undefined iteration behavior in SwiftData.
**Fix:** Capture the groups to delete in a separate array, clear the relationship first, then delete:
```swift
let oldGroups = Array(template.groups)
template.groups = []
for group in oldGroups { modelContext.delete(group) }
```
Or, if the model uses cascade delete rules, simply clearing `template.groups = []` may suffice and SwiftData will handle orphan cleanup.

## Warnings

### WR-01: Save failure silently dismissed without user feedback

**File:** `WorkloadApp/Views/TemplateEditorSheet.swift:261`
**Issue:** `try? modelContext.save()` suppresses save errors. If the save fails (e.g., constraint violation, disk full), the user sees no error and the sheet dismisses, giving the false impression that the template was saved.
**Fix:** Handle the error and surface it to the user, or at minimum prevent dismissal:
```swift
do {
    try modelContext.save()
} catch {
    print("Template save error: \(error)")
    // Show error state, do not dismiss
    return
}
```

### WR-02: UnicodeScalar overflow when more than 26 groups are created

**File:** `WorkloadApp/Views/TemplateEditorSheet.swift:125`
**Issue:** `Character(UnicodeScalar(65 + min(groups.count, 25))!)` caps at 25 (producing 'Z'), but `min(groups.count, 25)` means every group beyond the 26th is also named "Group Z". While not a crash, it creates duplicate group names which could confuse users and potentially cause issues if group names are used as identifiers downstream.
**Fix:** Use a numeric suffix after exhausting letters:
```swift
let nextName = groups.count < 26
    ? "Group \(Character(UnicodeScalar(65 + groups.count)!))"
    : "Group \(groups.count + 1)"
```

### WR-03: FinishWorkoutSheet dismiss-then-callback race condition

**File:** `WorkloadApp/Views/WorkoutLog/FinishWorkoutSheet.swift:67-68`
**Issue:** The Finish button calls `dismiss()` then `onFinish()`. The `dismiss()` triggers sheet dismissal which may cause the parent view's state to change (e.g., `showFinishConfirmation = false`). The `onFinish()` callback in `ActiveWorkoutSheet` calls `saveAsTemplateFromSession()` and `saveSession()`, which access `@State` properties on the parent. If SwiftUI processes the dismiss before the callback completes, state reads may be stale or the view hierarchy may have changed.
**Fix:** Call the callback first, then dismiss:
```swift
Button("Finish") {
    onFinish()
    dismiss()
}
```

### WR-04: Silent error suppression in CRUD helpers

**File:** `WorkloadApp/Views/WorkoutLog/TemplateCarouselSection.swift:351-373`
**Issue:** All CRUD helpers (`duplicateTemplate`, `toggleFavorite`, `archiveTemplate`, `deleteTemplate`) use `try?` to suppress errors, and the sync `Task` fires regardless of whether the local operation succeeded. If `archive` fails, the sync push will push stale data. If `delete` fails, the sync push sends templates that were not actually deleted.
**Fix:** Guard on success before triggering sync:
```swift
private func archiveTemplate(_ template: WorkoutTemplate) {
    do {
        try TemplateRepository(modelContext: modelContext).archive(template)
        guard let athleteId = athletes.first?.id else { return }
        Task { await container.syncService.pushWorkoutTemplates(context: modelContext, coachId: athleteId) }
    } catch {
        print("Archive error: \(error)")
    }
}
```

### WR-05: TemplateCarouselSection creates new TemplateRepository on every computed property access

**File:** `WorkloadApp/Views/WorkoutLog/TemplateCarouselSection.swift:24`
**Issue:** The `templates` computed property instantiates a new `TemplateRepository` every time SwiftUI evaluates the body. This happens on every view redraw. While the repository is lightweight, the `modelContext.fetch()` call inside is not free -- it runs a full SwiftData query on each render cycle. Combined with `scrollTransition` animations that trigger frequent redraws, this can cause unnecessary query load.
**Fix:** This is borderline performance (out of v1 scope), but the real risk is correctness: if `templates` returns different results on consecutive body evaluations within the same render pass, SwiftUI's `ForEach` diffing may produce incorrect UI. Consider caching via `@State` with an `.onAppear`/`.onChange` refresh pattern, or use `@Query` with a predicate.

## Info

### IN-01: TargetSetRow has a misaligned closing brace

**File:** `WorkloadApp/Views/TemplateEditorSheet.swift:400`
**Issue:** The closing `}` for the `HStack` appears at the wrong indentation level -- it closes before `.font(.Tokens.label)` modifier, but the modifier is applied outside the `HStack`. This compiles because Swift allows trailing modifiers, but the visual indentation is misleading and suggests a copy-paste formatting error.
**Fix:** Align the closing brace with the `HStack` opening:
```swift
        HStack {
            // ...
        }
        .font(.Tokens.label)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
```

### IN-02: Unused `isError` parameter in ToastBanner

**File:** `WorkloadApp/Components/ToastBanner.swift:7`
**Issue:** The `isError` parameter controls the auto-dismiss delay (3s vs 2s) but does not change the visual appearance of the banner. The banner looks identical for errors and success messages -- no color differentiation, no icon. This may confuse users who expect visual feedback that something went wrong.
**Fix:** Consider adding a leading icon or border color based on `isError`:
```swift
.overlay(
    Rectangle()
        .stroke(isError ? ColorTokens.zoneDanger : ColorTokens.divider, lineWidth: 0.5)
)
```

### IN-03: `computeDaysSinceRest` fetches all sessions without a limit

**File:** `WorkloadApp/Views/WorkoutLog/ActiveWorkoutSheet.swift:270-287`
**Issue:** `FetchDescriptor` has no `fetchLimit`, so it loads every `WorkoutSession` into memory just to count consecutive days. For athletes with hundreds of sessions, this is wasteful. The loop also has a subtle logic issue: if two sessions happen on the same day, both increment `consecutive`, overcounting rest days.
**Fix:** Add a `fetchLimit` (e.g., 30) and deduplicate by calendar day before counting:
```swift
var descriptor = FetchDescriptor<WorkoutSession>(
    sortBy: [SortDescriptor(\WorkoutSession.sessionDate, order: .reverse)]
)
descriptor.fetchLimit = 30
```

---

_Reviewed: 2026-05-09_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
