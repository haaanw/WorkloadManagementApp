---
phase: 02-analytics-export
plan: 01
subsystem: analytics-core
tags: [healthkit, staleness, analytics-engine, csv-export, pure-engine]
dependency_graph:
  requires: []
  provides: [HealthKitStaleness, AnalyticsEngine.WeeklySummary, CSVExportEngine]
  affects: [DashboardView, RecoveryPipeline, HealthKitService]
tech_stack:
  added: []
  patterns: [staleness-detection, staleness-propagation, pure-engine]
key_files:
  created:
    - WorkloadApp/Components/StalenessWarningBadge.swift
    - WorkloadApp/Services/AnalyticsEngine.swift
    - WorkloadApp/Services/CSVExportEngine.swift
  modified:
    - WorkloadApp/Services/HealthKitService.swift
    - WorkloadApp/Services/RecoveryPipeline.swift
    - WorkloadApp/ViewModels/DashboardViewModel.swift
    - WorkloadApp/Views/Dashboard/DashboardView.swift
    - workload management/workload management.xcodeproj/project.pbxproj
decisions:
  - Used 24h threshold for staleness (matching D-06 spec)
  - Staleness-aware WithDate methods added alongside existing methods for backward compat
  - CSVExportEngine uses RFC 4180 escaping for proper comma/quote handling
  - AnalyticsEngine compares first-half vs second-half ATL for trend direction (5% threshold)
metrics:
  duration: ~8min
  completed: 2026-04-20
  tasks_completed: 2
  tasks_total: 2
  files_created: 3
  files_modified: 5
---

# Phase 02 Plan 01: HealthKit Staleness + Analytics/Export Engines Summary

HealthKit staleness detection with 24h threshold flowing through RecoveryPipeline to Dashboard inline warnings, plus two pure computation engines for weekly analytics and CSV export.

## Task Results

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | HealthKit staleness detection + RecoveryPipeline propagation + StalenessWarningBadge | dac0723 | HealthKitService.swift, RecoveryPipeline.swift, StalenessWarningBadge.swift, DashboardView.swift |
| 2 | AnalyticsEngine + CSVExportEngine (pure computation engines) | e5c5554 | AnalyticsEngine.swift, CSVExportEngine.swift |

## What Was Built

### Task 1: Staleness Detection Pipeline
- `HealthKitStaleness` struct with `isHRVStale`, `isSleepStale`, `isRHRStale` computed properties (24h threshold)
- `fetchLatestHRVWithDate()`, `fetchLatestRestingHRWithDate()`, `fetchLastNightSleepWithDate()` staleness-aware methods
- `fetchStaleness()` convenience method
- `RecoveryResult` extended with `staleness` field, propagated through pipeline
- `DashboardViewModel.staleness` property set from pipeline result
- `StalenessWarningBadge` inline SwiftUI component showing "Updated Xd ago"
- `MetricStripCell` extended with optional `staleDaysAgo` parameter

### Task 2: Pure Computation Engines
- `AnalyticsEngine.computeWeeklySummary()` returns `WeeklySummary` with session count, total volume, avg recovery score, load trend direction, ACWR zone distribution, and week-over-week percentage deltas
- `CSVExportEngine.sessionSummaryCSV()` generates one-row-per-workout CSV (date, sport, duration, RPE, volume, load, ATL, CTL, ACWR)
- `CSVExportEngine.detailedSetsCSV()` generates one-row-per-set CSV (date, exercise, set#, reps, weight, RPE) excluding warmup sets
- RFC 4180 CSV escaping for fields containing commas, quotes, or newlines
- No raw HealthKit data (HRV, RHR, sleep values) in any CSV output

## Deviations from Plan

None - plan executed exactly as written.

## Threat Mitigations Applied

| Threat ID | Mitigation |
|-----------|-----------|
| T-02-01 | CSVExportEngine excludes all raw HealthKit data; only composite scores (load, ACWR) included |

## Self-Check: PASSED
