---
phase: 10-cold-start-questionnaire
plan: 02
subsystem: dashboard-cold-start
tags: [cold-start, dashboard, estimated-values, fatigue-suppression]
dependency_graph:
  requires: [TrainingProfileRepository (10-01), TrainingProfileCard (10-01), TrainingProfileSheet (10-01), TrainingProfile model (09-01), ColdStartEngine (09-01)]
  provides: [DashboardViewModel cold-start data path, LoadStatCell EST annotation, FatigueIndex cold-start suppression]
  affects: [DashboardView layout, TrainingLoadSection display, FatigueAttentionBanner visibility]
tech_stack:
  added: []
  patterns: [cold-start fallback branch in ViewModel, isEstimated default parameter on view component]
key_files:
  created: []
  modified:
    - WorkloadApp/ViewModels/DashboardViewModel.swift
    - WorkloadApp/Views/Dashboard/DashboardView.swift
decisions:
  - "Used fatigueIndex property instead of scoped fatigueResult variable in recommendation input to maintain correct scope after cold-start conditional wrapping"
  - "TrainingProfileCard placed between WelcomeActionCard and EmptyStateCard in dashboard VStack ordering"
  - "EST annotation uses tracking(0.88) per UI-SPEC component #4, distinct from micro-caps tracking(1.2)"
metrics:
  duration: 3m 40s
  completed: "2026-05-02T14:27:15Z"
  tasks_completed: 2
  tasks_total: 3
  files_created: 0
  files_modified: 2
  checkpoint_reached: true
  checkpoint_task: 3
  checkpoint_type: human-verify
---

# Phase 10 Plan 02: Cold-Start Dashboard Wiring Summary

DashboardViewModel cold-start fallback using TrainingProfile seeded ATL/CTL when no WorkloadSnapshot exists, with isColdStartActive flag driving EST annotations on LoadStatCell, FatigueIndex suppression ("Building baseline..."), and TrainingProfileCard placement on dashboard

## Task Execution

### Task 1: Add cold-start data path to DashboardViewModel
**Commit:** 3d9694d

Added `isColdStartActive: Bool` property to DashboardViewModel alongside existing workload properties. In the `load()` method, after the existing WorkloadSnapshot fetch block, added an else branch that checks for a TrainingProfile with seeded values and `coldStartCompletedAt == nil`. When found, sets `atl`, `ctl`, `acwr`, `tsb`, and `acwrZone` from seeded values and sets `isColdStartActive = true`. When a real WorkloadSnapshot exists, explicitly sets `isColdStartActive = false`.

Wrapped the FatigueIndex computation in a conditional: during cold-start, `fatigueIndex` and `fatigueZone` are set to nil (COLD-07 suppression). The existing FatigueIndexEngine.compute call runs only when not in cold-start.

Fixed a scoping issue where `fatigueResult.index` was referenced in the recommendation input but `fatigueResult` moved inside the else block -- replaced with the `fatigueIndex` property which is set in both branches.

### Task 2: Update DashboardView with EST annotations, card placement, FatigueIndex suppression, and chart gating
**Commit:** 5ca2f86

Added `@Query private var trainingProfiles: [TrainingProfile]` and `@State private var showTrainingProfile = false` to DashboardView. Added `showTrainingProfileCard` computed property that returns true when `trainingProfiles.isEmpty`.

Placed `TrainingProfileCard` in the body VStack between WelcomeActionCard and EmptyStateCard, with `onComplete` triggering the TrainingProfileSheet via `.sheet(isPresented:)`.

Modified `LoadStatCell` to accept an `isEstimated: Bool = false` parameter. When true, renders "EST" text below the value using `.font(.Tokens.micro)`, `.tracking(0.88)`, and `ColorTokens.text3`. Added `.accessibilityElement(children: .combine)` with conditional `.accessibilityLabel` for VoiceOver.

Updated all four LoadStatCell calls in TrainingLoadSection to pass `isEstimated: viewModel.isColdStartActive` and adjusted the dash display condition to account for cold-start (show values when cold-start active even if acwrZone is .noData).

Replaced the FatigueAttentionBanner conditional with cold-start awareness: when `viewModel.isColdStartActive`, renders "Building baseline..." text with `Font.Tokens.label`, `ColorTokens.text2`, `ColorTokens.surface` background, and hairline border. The existing FatigueAttentionBanner renders only when not in cold-start and zone is not low.

### Task 3: Verify cold-start dashboard experience (CHECKPOINT)
**Status:** Awaiting human verification

This checkpoint task requires building and running the app in Xcode simulator to visually verify the cold-start dashboard experience end-to-end.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed fatigueResult scope after cold-start conditional wrapping**
- **Found during:** Task 1
- **Issue:** After wrapping FatigueIndex computation in `if isColdStartActive` conditional, the `fatigueResult` local variable moved inside the else block. The recommendation input on the following line referenced `fatigueResult.index` which was now out of scope.
- **Fix:** Changed `fatigueIndex: fatigueResult.index` to `fatigueIndex: fatigueIndex` (using the class property which is set in both branches).
- **Files modified:** WorkloadApp/ViewModels/DashboardViewModel.swift
- **Commit:** 3d9694d

## Verification Results

1. DashboardViewModel.isColdStartActive correctly set based on TrainingProfile state -- PASS (5 references)
2. LoadStatCell renders "EST" below values during cold-start -- PASS (isEstimated parameter added with conditional Text)
3. TrainingProfileCard visible when no profile, hidden when profile exists -- PASS (showTrainingProfileCard computed property)
4. FatigueAttentionBanner replaced with "Building baseline..." during cold-start -- PASS (conditional rendering)
5. ACWR bar and zone badge display normally with estimated values (per D-10) -- PASS (no gating added to bar)
6. No WorkloadSnapshot contamination from seeded values -- PASS (only display properties set)
7. No design system violations (no RoundedRectangle, no .shadow, no accent color on cold-start elements) -- PASS

## Self-Check: PASSED

All modified files exist on disk. Both task commits (3d9694d, 5ca2f86) verified in git log.
