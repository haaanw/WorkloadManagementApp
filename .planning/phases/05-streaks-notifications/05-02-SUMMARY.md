---
phase: 05-streaks-notifications
plan: 02
subsystem: dashboard-streaks-notifications
tags: [streak-display, notification-pre-permission, dashboard-wiring]
dependency_graph:
  requires: [StreakEngine, NotificationService, AppContainer.notificationService]
  provides: [currentStreak-in-DashboardViewModel, NotificationPrePermissionCard, streak-row-in-WeeklySummaryCard]
  affects: [DashboardView, WeeklySummaryCard, DashboardViewModel]
tech_stack:
  added: []
  patterns: [appstorage-flag, inline-pre-permission-card]
key_files:
  created:
    - WorkloadApp/Views/Dashboard/NotificationPrePermissionCard.swift
  modified:
    - WorkloadApp/ViewModels/DashboardViewModel.swift
    - WorkloadApp/Views/Dashboard/WeeklySummaryCard.swift
    - WorkloadApp/Views/Dashboard/DashboardView.swift
    - workload management/workload management.xcodeproj/project.pbxproj
decisions:
  - Notification refresh via separate method (not inline in load()) to keep load() signature stable
  - Pre-permission flag set before system dialog fires to prevent card reappearing after denial
  - Streak row uses text1/text2 colors (not accent) per UI spec color contract
metrics:
  duration: 336s
  completed: 2026-04-22
  tasks: 2/2
---

# Phase 05 Plan 02: Dashboard Streak and Notification Pre-Permission Summary

Streak count wired into WeeklySummaryCard via StreakEngine, notification pre-permission inline card added to DashboardView, notification content refreshed on each dashboard load to prevent staleness.

## Task Completion

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add streak to DashboardViewModel and create NotificationPrePermissionCard | 130c736 | DashboardViewModel.swift, NotificationPrePermissionCard.swift, project.pbxproj |
| 2 | Wire streak row in WeeklySummaryCard and pre-permission card in DashboardView | 0a7f5c9 | WeeklySummaryCard.swift, DashboardView.swift |

## Implementation Details

### DashboardViewModel.swift
- Added `currentStreak: Int = 0` property (STRK-01, STRK-02)
- Streak computed in `load()` via `StreakEngine.computeStreak()` using 365-day session history
- Added `refreshNotificationContent(notificationService:modelContext:)` method (NOTF-01)
- Refresh method reads PR count from SwiftData, builds notification body, reschedules with stored day/time preferences

### NotificationPrePermissionCard.swift
- New inline card matching WelcomeActionCard pattern (surface background, divider border, no rounded corners, no shadows)
- "Enable Notifications" and "Not Now" buttons with exact UI spec copywriting
- Accessibility: `.accessibilityElement(children: .contain)` for VoiceOver grouping
- All design system constraints enforced: 0pt corners, DM Sans fonts via Font.Tokens, ColorTokens only, 8pt grid spacing

### WeeklySummaryCard.swift
- Added `streak: Int` parameter
- Streak row as first content inside expanded section: flame.fill icon (13pt, text2) + count (sectionHead, text1, monospacedDigit) + "week streak" label (label, text2)
- Row hidden when streak == 0 (D-02)
- Accessibility: flame icon `.accessibilityHidden(true)`, row has `.accessibilityLabel("{N} week training streak")`

### DashboardView.swift
- Added `@AppStorage("notificationPrePermissionShown")` flag
- Pre-permission card shown below WeeklySummaryCard when flag is false
- "Enable" taps: sets flag first (prevents reappear after denial), requests system permission, schedules Sunday 7PM default notification, stores preferences in UserDefaults
- "Not Now" taps: sets flag only, no system dialog
- `loadData()` calls `viewModel.refreshNotificationContent()` after each load for staleness prevention
- WeeklySummaryCard call site updated to pass `viewModel.currentStreak`

## Deviations from Plan

None -- plan executed exactly as written.

## Verification

- Build succeeded (xcodebuild, iPhone 17 Pro simulator)
- All acceptance criteria met for both tasks
- No RoundedRectangle or .shadow() in new code
- All fonts via Font.Tokens, all colors via ColorTokens
- All spacing multiples of 8pt

## Self-Check: PASSED

- All 4 source files exist on disk
- Both commits (130c736, 0a7f5c9) present in git log
- NotificationPrePermissionCard.swift has 4 pbxproj entries (PBXBuildFile, PBXFileReference, group child, Sources phase)
- Build succeeded
