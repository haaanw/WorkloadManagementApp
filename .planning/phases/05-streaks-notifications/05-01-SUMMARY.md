---
phase: 05-streaks-notifications
plan: 01
subsystem: services
tags: [streak-engine, notification-service, app-container]
dependency_graph:
  requires: []
  provides: [StreakEngine, NotificationService, AppContainer.notificationService]
  affects: [DashboardViewModel, ProfileView]
tech_stack:
  added: [UserNotifications]
  patterns: [pure-engine-struct, mainactor-service]
key_files:
  created:
    - WorkloadApp/Services/StreakEngine.swift
    - WorkloadApp/Services/NotificationService.swift
  modified:
    - WorkloadApp/App/AppContainer.swift
    - workload management/workload management.xcodeproj/project.pbxproj
decisions:
  - NotificationService is not @Observable -- called imperatively, not reactively bound
  - buildNotificationBody is static (pure function, matches engine pattern)
  - StreakEngine uses Calendar.current for locale-aware week boundaries
metrics:
  duration: 350s
  completed: 2026-04-22
  tasks: 2/2
---

# Phase 05 Plan 01: Foundational Services Summary

StreakEngine (pure struct) and NotificationService (UNUserNotificationCenter wrapper) created and registered in AppContainer for downstream consumption by Plans 02 and 03.

## Task Completion

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create StreakEngine pure computation struct | 2f92b8e | StreakEngine.swift, project.pbxproj |
| 2 | Create NotificationService and register in AppContainer | cc30176 | NotificationService.swift, AppContainer.swift, project.pbxproj |

## Implementation Details

### StreakEngine.swift
- Pure struct with single static method `computeStreak(sessions:) -> Int`
- Builds a set of (yearForWeekOfYear, weekOfYear) keys from all sessions
- Walks backward from current week counting consecutive weeks with sessions
- Returns 0 if current week has no sessions (streak hidden in UI per D-02)
- Uses `Calendar.current` for locale-aware week boundaries (not hardcoded Sunday start)
- No state, no side effects, no dependencies beyond Foundation

### NotificationService.swift
- `@MainActor final class` wrapping `UNUserNotificationCenter`
- `requestAuthorization()` -- requests alert + sound permissions
- `authorizationStatus()` -- queries system authorization state
- `scheduleWeeklySummary(weekday:hour:minute:body:)` -- cancels existing, schedules repeating `UNCalendarNotificationTrigger`
- `cancelWeeklySummary()` -- removes pending notification by identifier "weekly-summary"
- `static buildNotificationBody(sessionCount:streak:prCount:volumeDelta:)` -- pure content formatter

### AppContainer.swift
- Added `let notificationService: NotificationService` property
- Initialized with `self.notificationService = NotificationService()` in `init()`

## Deviations from Plan

None -- plan executed exactly as written.

## Self-Check: PASSED

- [x] WorkloadApp/Services/StreakEngine.swift exists
- [x] WorkloadApp/Services/NotificationService.swift exists
- [x] AppContainer.swift contains notificationService property and initialization
- [x] Both files registered in project.pbxproj
- [x] Project builds successfully
- [x] Commit 2f92b8e exists
- [x] Commit cc30176 exists
