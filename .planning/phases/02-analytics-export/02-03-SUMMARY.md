---
phase: 02-analytics-export
plan: 03
subsystem: dashboard-weekly-summary
tags: [analytics, dashboard, weekly-summary, delta-indicators]
dependency_graph:
  requires: [02-01]
  provides: [weekly-summary-card, delta-indicator-component]
  affects: [DashboardView, DashboardViewModel]
tech_stack:
  added: []
  patterns: [collapsible-card, week-over-week-delta, AppStorage-persistence]
key_files:
  created:
    - WorkloadApp/Components/DeltaIndicator.swift
    - WorkloadApp/Views/Dashboard/WeeklySummaryCard.swift
  modified:
    - WorkloadApp/ViewModels/DashboardViewModel.swift
    - WorkloadApp/Repositories/WorkoutRepository.swift
    - WorkloadApp/Repositories/RecoveryRepository.swift
    - WorkloadApp/Repositories/WorkloadRepository.swift
    - WorkloadApp/Views/Dashboard/DashboardView.swift
    - workload management/workload management.xcodeproj/project.pbxproj
decisions:
  - Used private WeeklyZoneBadge struct to avoid conflict with existing ZoneBadge component
  - Used explicit zone ordering array instead of adding CaseIterable conformance to ACWRZone
metrics:
  duration: 8m
  completed: 2026-04-20T15:48:12Z
  tasks_completed: 2
  tasks_total: 2
  files_created: 2
  files_modified: 6
---

# Phase 02 Plan 03: Weekly Summary Card Summary

Collapsible weekly training summary on Dashboard with DeltaIndicator showing colored week-over-week percentage changes for sessions, volume, and recovery.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | DeltaIndicator + Repository methods + ViewModel integration | 807bb91 | DeltaIndicator.swift, WorkoutRepository.swift, RecoveryRepository.swift, WorkloadRepository.swift, DashboardViewModel.swift |
| 2 | WeeklySummaryCard + Dashboard integration | 8b531ab | WeeklySummaryCard.swift, DashboardView.swift, project.pbxproj |

## Implementation Details

### DeltaIndicator (D-04)
- Green `arrow.up` with positive percentage for increases
- Red `arrow.down` with negative percentage for decreases
- Em dash in text2 for changes under 1% (negligible)
- Accessibility labels for VoiceOver

### Repository Date-Range Methods
- `WorkoutRepository.fetchSessions(from:to:)` - date-bounded session queries
- `RecoveryRepository.fetchSnapshots(from:to:)` - date-bounded recovery queries
- `WorkloadRepository.fetchSnapshots(from:to:)` - date-bounded workload queries

### WeeklySummaryCard (D-03, ANLYT-02, ANLYT-03)
- Collapsible card with chevron rotation animation (250ms easeOut)
- Collapse state persisted via `@AppStorage("weeklySummaryExpanded")`
- Metrics: session count, volume, avg recovery, load trend direction
- ACWR zone distribution shown as inline badges
- Each metric has DeltaIndicator for week-over-week comparison
- Empty state text when no sessions in current week

### Dashboard Integration
- Card inserted between MetricsStrip and TrainingLoadSection
- Only shown when `weeklySummary.sessionCount > 0`
- DashboardViewModel computes weekly summary via AnalyticsEngine on each load

## Design Compliance

- 0pt border radius: Rectangle() used throughout, no RoundedRectangle
- No shadows: hairline border overlays only
- DM Sans only: .Tokens.micro, .Tokens.label, .Tokens.body, .Tokens.sectionHead
- 8pt grid: 16pt padding, 8pt spacing, 4pt internal gaps
- ColorTokens: surface, divider, text1, text2, text3, zoneOptimal, zoneDanger
- Accent color not used (reserved for hero readiness score)

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED

- DeltaIndicator.swift: FOUND
- WeeklySummaryCard.swift: FOUND
- Commit 807bb91: FOUND (Task 1)
- Commit 8b531ab: FOUND (Task 2)
