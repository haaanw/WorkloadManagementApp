---
phase: 02-analytics-export
plan: 04
subsystem: export-flow
tags: [csv-export, share-sheet, subscription-gate, workload-tab]
dependency_graph:
  requires: [02-01, 02-02]
  provides: [csv-export-ui, share-sheet-utility, export-paywall-trigger]
  affects: [WorkloadView, UpgradeSheet]
tech_stack:
  added: [UIActivityViewController]
  patterns: [UIViewControllerRepresentable, confirmationDialog, temp-file-sharing]
key_files:
  created:
    - WorkloadApp/Utilities/ShareSheet.swift
  modified:
    - WorkloadApp/Views/Workload/WorkloadView.swift
    - WorkloadApp/Views/Subscription/UpgradeSheet.swift
    - workload management/workload management.xcodeproj/project.pbxproj
decisions:
  - Used @Query for allSessions directly in view rather than ViewModel since export is a simple one-shot operation
  - Date format in filename uses .dateTime.year().month().day() for clean cross-platform filenames
metrics:
  duration: 5m 26s
  completed: 2026-04-20T15:57:00Z
---

# Phase 02 Plan 04: CSV Export Flow Summary

Wire CSV export with Pro subscription gating on Workload tab via ShareSheet utility and confirmation dialog.

## One-liner

Pro-gated CSV export flow with format picker (Session Summary / Detailed Sets) and system share sheet on Workload tab.

## Completed Tasks

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | ShareSheet utility + Export flow in WorkloadView | eb50fd2 | ShareSheet.swift, WorkloadView.swift, UpgradeSheet.swift, project.pbxproj |

## What Was Built

1. **ShareSheet.swift** - UIViewControllerRepresentable bridge wrapping UIActivityViewController for file sharing via AirDrop, Files, email, etc.

2. **Export flow in WorkloadView** - Toolbar button (square.and.arrow.up) that:
   - Checks `container.subscriptionService.isPro` before showing options
   - Shows confirmation dialog with "Session Summary" and "Detailed Sets" format choices
   - Generates CSV via CSVExportEngine using @Query allSessions
   - Writes to temp file and presents system share sheet
   - Non-Pro users see UpgradeSheet with `.export` trigger

3. **UpgradeTrigger.export** - New enum case added to support export-specific paywall messaging.

## Threat Mitigations Applied

- **T-02-07 (Information Disclosure):** CSVExportEngine excludes raw HealthKit data by design - only composite load/ACWR values exported
- **T-02-08 (Elevation of Privilege):** Pro gate check occurs before CSV generation - non-Pro users never reach export logic

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None - all data flows are wired to real @Query data sources.

## Self-Check

- [x] ShareSheet.swift exists at WorkloadApp/Utilities/ShareSheet.swift
- [x] Commit eb50fd2 exists in git log
- [x] Build succeeds (xcodebuild passes with no Swift errors)
