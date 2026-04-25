---
phase: "06"
plan: "03"
subsystem: coach-export
status: checkpoint-pending
tags: [pdf, coach, export, subscription-gating]
dependency_graph:
  requires: [06-01]
  provides: [coach-roster-pdf-export]
  affects: [CoachRosterView, CoachExportSheet]
tech_stack:
  added: []
  patterns: [sheet-with-viewmodel-injection, subscription-gated-feature]
key_files:
  created:
    - WorkloadApp/Views/Export/CoachExportSheet.swift
  modified:
    - WorkloadApp/Views/Coach/CoachRosterView.swift
    - workload management/workload management.xcodeproj/project.pbxproj
decisions:
  - Passed CoachRosterViewModel by reference to CoachExportSheet to reuse loaded athlete and snapshot data without re-fetching
  - Used same chip and button styling patterns from plan spec for visual consistency with PDFGenerationSheet (06-02)
metrics:
  duration: "~6 min"
  completed_date: "2026-04-25"
  tasks_completed: 2
  tasks_total: 3
  tasks_pending_verification: 1
---

# Phase 06 Plan 03: Coach Roster PDF Export Summary

Coach roster PDF export with athlete multi-select picker, date range chips, and subscription-gated toolbar button in CoachRosterView

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create CoachExportSheet with athlete picker and roster report generation | 56fff82 | CoachExportSheet.swift, project.pbxproj |
| 2 | Add export button to CoachRosterView toolbar | c2b539b | CoachRosterView.swift |

## Tasks Pending

| Task | Name | Status |
|------|------|--------|
| 3 | Verify complete PDF export flow for athlete and coach | Awaiting human verification |

## Implementation Details

### CoachExportSheet (Task 1)
- Multi-select athlete picker with checkmark circles and Select All / Deselect All toggle
- Date range chips (4, 8, 12 weeks) matching design system (0pt corners, DM Sans, 8pt grid)
- Generates roster PDF via `PDFReportEngine.generateCoachRosterReport`
- Builds `RosterAthleteData` from ViewModel snapshot dictionaries and StreakEngine
- ShareSheet integration for system share flow
- Error handling with alert presentation
- All athletes pre-selected on first appearance

### CoachRosterView Toolbar (Task 2)
- Export button (doc.text SF Symbol) in `.topBarLeading` placement
- Subscription gating: `container.subscriptionService.isCoach` check
- Pro coaches see CoachExportSheet; free users see UpgradeSheet with `.export` trigger
- All existing functionality preserved (Add Client, NavigationLink, refresh, empty state)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Added undertrained case to zone color switch**
- **Found during:** Task 1
- **Issue:** ACWRZone enum has `.undertrained` case not mentioned in plan; exhaustive switch required it
- **Fix:** Added `.undertrained` case mapping to `ColorTokens.divider` alongside `.noData`
- **Files modified:** CoachExportSheet.swift
- **Commit:** 56fff82

## Known Stubs

None -- all data is wired through CoachRosterViewModel snapshot dictionaries and PDFReportEngine.

## Threat Surface

Threat model mitigations implemented:
- T-06-06: Export button checks `container.subscriptionService.isCoach` before presenting CoachExportSheet
- T-06-07: Athletes filtered through `viewModel.linkedAthletes` (only accepted CoachAthleteRelationship)
- T-06-08: Accepted (coach identity via Supabase auth session)

No new threat surface introduced beyond what was documented in the plan.

## Self-Check: PASSED
