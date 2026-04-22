---
phase: 05-streaks-notifications
plan: 03
subsystem: views
tags: [notifications, profile-settings, user-preferences]
dependency_graph:
  requires: [NotificationService, AppContainer.notificationService]
  provides: [ProfileView NOTIFICATIONS section]
  affects: [ProfileView.swift]
tech_stack:
  added: []
  patterns: [app-storage-persistence, async-auth-check]
key_files:
  created: []
  modified:
    - WorkloadApp/Views/Profile/ProfileView.swift
decisions:
  - Used @AppStorage for notification preferences (day, time, enabled) for per-device persistence
  - Time picker uses hourly slots 6AM-10PM via editablePicker (simpler UX than DatePicker)
  - Day picker uses Calendar.current.weekdaySymbols for locale-aware day names
  - Denied state checked both on appear (.task) and on toggle-on for resilience
metrics:
  duration: 245s
  completed: 2026-04-22
  tasks: 1/1
---

# Phase 05 Plan 03: Notification Settings UI Summary

NOTIFICATIONS section added to ProfileView with toggle (auth-aware), locale-aware day picker, and hourly time picker between PREFERENCES and CONNECTED DEVICES sections.

## Task Completion

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add NOTIFICATIONS section to ProfileView | 73eac5b | WorkloadApp/Views/Profile/ProfileView.swift |

## Implementation Details

### ProfileView.swift Changes

- Added `@AppStorage` properties: `notificationsEnabled` (Bool, default false), `notificationDay` (Int, default 1/Sunday), `notificationTime` (String, default "19:00")
- Added `@State private var notificationsDenied: Bool` for tracking system auth denied state
- New NOTIFICATIONS section placed between PREFERENCES and CONNECTED DEVICES (per D-08)
- Toggle row ("Weekly Summary") with custom Binding that:
  - On enable: checks authorizationStatus, requests if notDetermined, shows guidance if denied
  - On disable: cancels pending weekly summary notification
- Day picker: uses `editablePicker` with `Calendar.current.weekdaySymbols` for locale-aware names
- Time picker: uses `editablePicker` with hourly slots from 6AM to 10PM, formatted in 12-hour AM/PM
- Both pickers disabled when toggle is off, with text3 color for disabled state
- `.task` modifier on appear syncs notificationsDenied state and forces toggle off if system denied
- Private `scheduleNotification()` helper builds placeholder body and calls NotificationService

## Deviations from Plan

None -- plan executed exactly as written.

## Self-Check: PASSED

- [x] WorkloadApp/Views/Profile/ProfileView.swift contains @AppStorage("notificationsEnabled")
- [x] ProfileView contains sectionHeader("NOTIFICATIONS")
- [x] ProfileView contains Weekly Summary toggle with auth handling
- [x] ProfileView contains day picker with Calendar.current.weekdaySymbols
- [x] ProfileView contains time picker with hourly slots
- [x] ProfileView contains notificationsDenied state and Settings guidance
- [x] ProfileView contains .disabled(!notificationsEnabled) on pickers
- [x] Commit 73eac5b exists
