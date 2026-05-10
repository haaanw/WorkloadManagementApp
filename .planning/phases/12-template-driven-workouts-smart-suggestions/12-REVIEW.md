---
phase: 12-template-driven-workouts-smart-suggestions
reviewed: 2026-05-10T12:00:00Z
depth: standard
files_reviewed: 7
files_reviewed_list:
  - WorkloadApp/Models/WorkoutSession.swift
  - WorkloadApp/Services/TemplateSuggestionEngine.swift
  - WorkloadApp/Views/Dashboard/DashboardView.swift
  - WorkloadApp/Views/WorkoutLog/ActiveWorkoutSheet.swift
  - WorkloadApp/Views/WorkoutLog/TemplateCarouselSection.swift
  - WorkloadApp/Views/WorkoutLog/TemplatePickerSheet.swift
  - WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift
findings:
  critical: 0
  warning: 4
  info: 3
  total: 7
status: issues_found
---

# Phase 12: Code Review Report

**Reviewed:** 2026-05-10T12:00:00Z
**Depth:** standard
**Files Reviewed:** 7
**Status:** issues_found

## Summary

Phase 12 adds template-driven workout starts, a smart template suggestion engine (TemplateSuggestionEngine), a Quick Start section on the Dashboard, a TemplatePickerSheet for the + button flow, fill buttons for template-loaded sessions, and sourceTemplateId linkage on WorkoutSession. The engine code is clean and well-structured as a pure static struct. The main concerns are: duplicated suggestion computation logic across three views, a force-unwrap that can crash, and computed properties performing SwiftData fetches on every view re-render.

## Warnings

### WR-01: Force-unwrap on Calendar date computation (crash risk)

**File:** `WorkloadApp/Views/WorkoutLog/TemplateCarouselSection.swift:384`
**Issue:** `Calendar.current.date(byAdding:value:to:)` returns `Optional<Date>`, but is force-unwrapped with `!`. While this is extremely unlikely to return nil for `.weekOfYear`, the same force-unwrap pattern appears at `DashboardView.swift:704`. A defensive guard is more consistent with the project's error handling conventions.
**Fix:**
```swift
guard let fourWeeksAgo = Calendar.current.date(byAdding: .weekOfYear, value: -4, to: .now) else { return }
```

### WR-02: Computed property `templates` performs SwiftData fetch on every body evaluation

**File:** `WorkloadApp/Views/WorkoutLog/TemplateCarouselSection.swift:24-28`
**Issue:** The `templates` computed property creates a new `TemplateRepository` and calls `fetchAthleteTemplates` every time the view body is evaluated. SwiftUI can re-evaluate body frequently (on any state change, scroll, animation frame). This creates a new repository instance and runs a fetch on each evaluation, which is unnecessary work. The same pattern exists in `TemplatePickerSheet.swift:16-20` and `DashboardView.swift:602-614` (`quickStartTemplates`).
**Fix:** Use `@Query` with a predicate for reactive SwiftData reads (project convention), or cache the result in `@State` and refresh only on `.onAppear` / `.task`. Example:
```swift
@State private var templates: [WorkoutTemplate] = []

func loadTemplates() {
    guard let athleteId = athletes.first?.id else { return }
    templates = (try? TemplateRepository(modelContext: modelContext)
        .fetchAthleteTemplates(athleteId: athleteId)) ?? []
}
```

### WR-03: Duplicated suggestion computation logic across three views

**File:** `WorkloadApp/Views/WorkoutLog/TemplateCarouselSection.swift:377-408`, `WorkloadApp/Views/Dashboard/DashboardView.swift:697-723`
**Issue:** The `computeSuggestion()` method is copy-pasted across `TemplateCarouselSection` and `QuickStartSection` with identical logic: fetch templates, fetch sessions from 4 weeks ago, fetch latest recovery snapshot, call `TemplateSuggestionEngine.suggest()`. If the suggestion API or fetching logic changes, both copies must be updated in sync -- a maintenance risk. This should be extracted into a shared helper or computed at a higher level and passed down.
**Fix:** Extract the suggestion computation into a shared static method or a lightweight service:
```swift
extension TemplateSuggestionEngine {
    static func computeFromContext(
        athleteId: UUID,
        modelContext: ModelContext
    ) -> SuggestionResult? {
        // consolidated fetch + suggest logic
    }
}
```

### WR-04: Template sheet dismisses then triggers state change (potential race condition)

**File:** `WorkloadApp/Views/WorkoutLog/TemplatePickerSheet.swift:36-38`
**Issue:** The "Start blank workout" button calls `dismiss()` first, then `onStartBlank()` which sets `showActiveWorkout = true` in the parent. Since `dismiss()` is asynchronous (sheet dismissal is animated), the parent's state change may fire before the sheet is fully dismissed, which can cause SwiftUI to present the new sheet while the old one is still animating away, leading to dropped presentations. The same pattern appears on line 113 (`onSelectTemplate`).
**Fix:** Use the sheet's `onDismiss` callback or reverse the order -- set state first and let the sheet dismiss handle itself:
```swift
Button {
    onStartBlank()
    dismiss()
} label: { ... }
```
Or better, use `.onChange(of: showTemplatePicker)` in the parent (which already exists at line 212 of WorkoutLogView) to trigger the next action.

## Info

### IN-01: `quickStartTemplates` computed property has side-effect dependency on `@State`

**File:** `WorkloadApp/Views/Dashboard/DashboardView.swift:602-624`
**Issue:** The `quickStartTemplates` computed property reads from `suggestionResult` (a `@State` property) and also performs repository fetches. Mixing reactive state reads with imperative fetches in a computed property makes the data flow harder to reason about. Consider making `quickStartTemplates` itself a `@State` that is computed in `onAppear` or `computeSuggestion()`.

### IN-02: Unused `swipeOffset` / `swipedTemplateId` state not reset on template deletion

**File:** `WorkloadApp/Views/WorkoutLog/TemplateCarouselSection.swift:444-452`
**Issue:** When a template is deleted via `deleteTemplate()`, the `swipedTemplateId` and `swipeOffset` state are not reset. If the user had swiped the card and then confirmed deletion via the confirmation dialog, these stale values persist. Not a crash risk but can cause visual artifacts if IDs are reused.
**Fix:** Add cleanup in `deleteTemplate`:
```swift
swipeOffset = 0
swipedTemplateId = nil
```

### IN-03: Font usage with `.system(size:)` in carousel icons

**File:** `WorkloadApp/Views/WorkoutLog/TemplateCarouselSection.swift:170,174,225,340`
**Issue:** SF Symbol icons use `.font(.system(size: 17))` and `.font(.system(size: 15))`, which the project's DESIGN.md forbids: "Do not use `.system()` ... these override the design system." While this only applies to icon sizing (not text), it deviates from the stated convention. Consider using a fixed-size `Font.custom("DMSans-Regular", size: 17)` or accepting that SF Symbols need system font sizing (in which case, document the exception).

---

_Reviewed: 2026-05-10T12:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
