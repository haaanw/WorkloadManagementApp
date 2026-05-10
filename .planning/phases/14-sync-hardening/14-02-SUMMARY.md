---
phase: 14-sync-hardening
plan: 02
subsystem: sync-ui
tags: [sync, profile, badge, ui]
dependency_graph:
  requires: [14-01]
  provides: [sync-status-view, sync-badge, sync-cleanup]
  affects: [ProfileView, AppRouter, AppContainer]
tech_stack:
  added: []
  patterns: [observable-tracking-stored-property, overlay-badge]
key_files:
  created:
    - WorkloadApp/Views/Profile/SyncStatusView.swift
  modified:
    - WorkloadApp/Views/Profile/ProfileView.swift
    - WorkloadApp/App/AppRouter.swift
    - WorkloadApp/App/AppContainer.swift
    - workload management/workload management.xcodeproj/project.pbxproj
decisions:
  - Used overlay approach for tab badge to achieve zoneCaution (yellow) color -- SwiftUI .badge() only supports red
  - Used SyncTimestampStore stored property in MainTabView for reliable @Observable tracking
  - Used .smallLabel (13pt) for timestamps in entity rows per existing font scale
metrics:
  duration: 169s
  completed: "2026-05-10T15:05:32Z"
  tasks_completed: 2
  tasks_total: 3
  status: checkpoint-pending
---

# Phase 14 Plan 02: Sync Status UI and Badge Summary

Sync health visibility wired into UI: per-entity status view, Profile tab badge, and sign-out cleanup via SyncTimestampStore.

## Completed Tasks

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create SyncStatusView and add Profile navigation row | 4bc6141 | SyncStatusView.swift (new), ProfileView.swift, project.pbxproj |
| 2 | Add tab badge on Profile, update AppContainer sign-out cleanup | ab463d9 | AppRouter.swift, AppContainer.swift |

## Pending Tasks

| Task | Name | Status |
|------|------|--------|
| 3 | Visual and functional verification | Awaiting human verification |

## Implementation Details

### SyncStatusView (New)
- Scrollable list of all 10 SyncEntity types with per-entity rows
- Each row has 8pt Circle indicator (zoneCaution for failed, zoneOptimal for success)
- Entity display name in .Tokens.label (15pt), relative timestamp in .Tokens.smallLabel (13pt)
- Failed entities show trailing error message text in zoneCaution
- Pull-to-refresh triggers pushAll/pullAll with isSyncing guard
- Accessibility labels combine entity name, status, and error info

### ProfileView Changes
- New "DATA SYNC" section between CONNECTED DEVICES and COACH
- NavigationLink row with arrow.triangle.2.circlepath icon
- Inline status: "Issues" (zoneCaution) when hasAnyFailure, "All data synced" (text2) otherwise

### AppRouter Changes
- MainTabView stores SyncTimestampStore.shared as property for @Observable tracking
- Yellow dot badge (8pt Circle, zoneCaution fill) via overlay on both coach and athlete Profile tabs
- 150ms linear fade transition on appearance/disappearance

### AppContainer Changes
- signOut() calls SyncTimestampStore.shared.clearAll() after auth sign-out, before data deletion
- deleteAccount() calls SyncTimestampStore.shared.clearAll() after auth deletion, before data deletion

## Deviations from Plan

None -- plan executed exactly as written.

## Known Stubs

None -- all data sources are wired to SyncTimestampStore.shared which was created in Plan 01.

## Design Compliance

- 0pt corner radius: Rectangle() used for dividers, no RoundedRectangle
- No shadows
- All fonts via Font.Tokens (Alpino): .micro, .label, .smallLabel, .body
- All colors via ColorTokens: text1, text2, text3, zoneCaution, zoneOptimal, divider, background
- Spacing multiples of 8pt: 8, 16, 24, 40, 48
- Accent color not used (reserved for hero score)

## Self-Check: PASSED
