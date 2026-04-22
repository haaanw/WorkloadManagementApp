---
phase: 04-onboarding-polish
fixed_at: 2026-04-22T00:00:00Z
review_path: .planning/phases/04-onboarding-polish/04-REVIEW.md
iteration: 1
findings_in_scope: 5
fixed: 4
skipped: 1
status: partial
---

# Phase 04: Code Review Fix Report

**Fixed at:** 2026-04-22T00:00:00Z
**Source review:** .planning/phases/04-onboarding-polish/04-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 5
- Fixed: 4
- Skipped: 1

## Fixed Issues

### WR-01: `completeOnboarding()` silently no-ops if user bypasses step guards

**Files modified:** `WorkloadApp/Views/Onboarding/OnboardingView.swift`
**Commit:** 6082146
**Applied fix:** Added `assertionFailure` with descriptive message in the guard's else branch so that the silent return is caught during development. The existing `return` already prevented `onComplete()` from firing (contrary to the review's description), but the assertion makes the unexpected state visible in DEBUG builds.

### WR-02: `.gesture(DragGesture())` swipe suppression is unreliable

**Files modified:** `WorkloadApp/Views/Onboarding/OnboardingView.swift`
**Commit:** 9fd651e
**Applied fix:** Replaced `TabView` with paging style and `DragGesture()` hack with a `ZStack` using opacity-based step visibility. Added `.animation(.easeOut(duration: 0.25), value: currentStep)` for smooth transitions. Forward navigation is now exclusively controlled by the Continue button with no swipe interception issues.

### WR-04: ACWR zone boundary at 1.3 is ambiguous

**Files modified:** `WorkloadApp/Models/Enums.swift`
**Commit:** b8cecb4
**Applied fix:** Changed overlapping closed ranges (`0.8...1.3` and `1.3...1.5`) to half-open ranges (`0.8..<1.3` and `1.3..<1.5`) so that ACWR of exactly 1.3 correctly classifies as `.caution` rather than `.optimal`. This is a logic fix that requires human verification of domain intent.

### WR-05: `pullCoachPrescriptions` partially syncs records

**Files modified:** `WorkloadApp/Services/SyncService.swift`
**Commit:** 3353929
**Applied fix:** Added all missing field assignments to `pullCoachPrescriptions` to match the complete field set in `pullPrescribedWorkouts`: `coachId`, `athleteId`, `templateId`, `scheduledDate`, `notes`, `templateName`, `sportType`, `sessionType`, `createdAt`, plus the groups JSON decode and replace logic.

## Skipped Issues

### WR-03: DEBUG mock data seeder runs on every cold launch, not only first-time

**File:** `WorkloadApp/App/AppRouter.swift:101-106`
**Reason:** Code context differs from review. The actual code at lines 109-113 already gates `MockDataSeeder.seed` behind `ProcessInfo.processInfo.arguments.contains("SCREENSHOT_MODE")`, meaning it only runs when the `SCREENSHOT_MODE` launch argument is explicitly passed -- not on every cold launch. The review's premise is incorrect; no fix needed.
**Original issue:** The DEBUG block calls `MockDataSeeder.seed` unconditionally on every cold launch for authenticated athletes.

---

_Fixed: 2026-04-22T00:00:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
