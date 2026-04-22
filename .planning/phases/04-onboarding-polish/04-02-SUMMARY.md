---
phase: 04-onboarding-polish
plan: 02
subsystem: onboarding
tags: [onboarding, swiftui, approuter, healthkit]
dependency_graph:
  requires: [04-01]
  provides: [onboarding-flow, onboarding-gate]
  affects: [AppRouter, OnboardingView]
tech_stack:
  added: []
  patterns: [paged-tabview, forward-only-navigation, state-derived-gate]
key_files:
  created:
    - WorkloadApp/Views/Onboarding/OnboardingView.swift
  modified:
    - WorkloadApp/App/AppRouter.swift
    - workload management/workload management.xcodeproj/project.pbxproj
decisions:
  - Used @State needsOnboarding flag derived from Athlete model fields rather than @Query in AppRouter (per RESEARCH.md recommendation)
  - Forward-only navigation via DragGesture() consumer on TabView (no back button)
  - HealthKit step offers both Connect Health and Skip for now (per D-03)
metrics:
  duration: 22m
  completed: 2026-04-22
  tasks_completed: 2
  tasks_total: 2
  files_created: 1
  files_modified: 2
---

# Phase 04 Plan 02: Onboarding Flow Summary

3-step paged OnboardingView (frequency chips, experience cards, HealthKit permission) with AppRouter gate that routes new users through onboarding before Dashboard.

## Task Completion

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Create OnboardingView with 3-step paged flow | c223a0a | OnboardingView.swift, project.pbxproj |
| 2 | Wire onboarding gate in AppRouter | 8297382 | AppRouter.swift |

## What Was Built

### OnboardingView.swift (new, 268 lines)
- **Step 1 (Training Frequency):** 2x2 LazyVGrid with TrainingFrequency.allCases chip grid. Selected state uses ColorTokens.surface background with 1.0pt text3 border; unselected uses background with 0.5pt divider border.
- **Step 2 (Experience Level):** VStack of 3 vertical cards showing displayName and subtitle for each ExperienceLevel. Same selection pattern as frequency chips.
- **Step 3 (HealthKit Permission):** Lists HRV, RHR, and Sleep with SF Symbol icons. "Connect Health" primary button calls healthKitService.requestAuthorization(). "Skip for now" text button bypasses HealthKit.
- **Navigation:** Forward-only via Continue button (disabled until selection made). DragGesture() on TabView disables swiping. Custom dot indicators (3 circles, 8pt).
- **Completion:** Saves trainingFrequency and experienceLevel to Athlete model, calls modelContext.save(), pushes via SyncService, then calls onComplete closure.

### AppRouter.swift (modified)
- Added `@State private var needsOnboarding = false`
- Body renders `OnboardingView(onComplete: { needsOnboarding = false })` between auth and MainTabView
- After `container.setAuthenticated(true)` in .task, checks `a.trainingFrequency == nil || a.experienceLevel == nil` to set needsOnboarding
- SCREENSHOT_MODE explicitly sets `needsOnboarding = false` to skip onboarding

## Design Compliance

- All fonts use Font.Tokens (pageTitle, body, label)
- All colors from ColorTokens (text1, text2, text3, surface, background, divider)
- No RoundedRectangle usage -- Rectangle() only
- No .shadow() modifiers
- No ColorTokens.accent usage
- All spacing multiples of 8pt (8, 16, 24, 32, 48, 64)
- 0pt border radius everywhere

## Deviations from Plan

None -- plan executed exactly as written.

## Known Stubs

None -- all data flows are wired (Athlete model fields saved and synced).

## Self-Check: PASSED

- All created files exist on disk
- Both task commits verified in git log
- OnboardingView contains onComplete parameter
- AppRouter contains needsOnboarding gate and OnboardingView reference
- SCREENSHOT_MODE bypass confirmed
