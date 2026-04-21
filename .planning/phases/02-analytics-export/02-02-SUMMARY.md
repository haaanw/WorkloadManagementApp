---
phase: 02-analytics-export
plan: 02
subsystem: workload-analytics
tags: [charts, time-range, tooltip, correlation, swift-charts]
dependency_graph:
  requires: [02-01]
  provides: [time-range-trends, recovery-load-correlation, chart-tooltip]
  affects: [WorkloadView, WorkloadTab]
tech_stack:
  added: []
  patterns: [ChartProxy-tooltip-gesture, time-range-segmented-control]
key_files:
  created:
    - WorkloadApp/ViewModels/WorkloadViewModel.swift
    - WorkloadApp/Components/TimeRangeSegmentedControl.swift
    - WorkloadApp/Components/ChartTooltipOverlay.swift
    - WorkloadApp/Views/Workload/RecoveryLoadChart.swift
  modified:
    - WorkloadApp/Views/Workload/WorkloadView.swift
    - workload management/workload management.xcodeproj/project.pbxproj
decisions:
  - Used @State viewModel pattern instead of environment injection for WorkloadViewModel
  - Gated TimeRangeSegmentedControl and RecoveryLoadChart behind Pro subscription
  - Used .overlay(alignment: .top) for tooltip positioning instead of nested chartOverlay
metrics:
  duration_seconds: 399
  completed: 2026-04-20T15:46:37Z
  tasks_completed: 2
  tasks_total: 2
  files_created: 4
  files_modified: 2
---

# Phase 02 Plan 02: Time-Range Trend Charts and Recovery-Load Correlation Summary

TimeRange enum with 4W/12W/6M options, WorkloadViewModel for filtered data loading, reusable ChartTooltipGesture for tap-scrub tooltips, and 28-day RecoveryLoadChart with load bars + recovery line overlay integrated into the Workload tab.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | WorkloadViewModel + TimeRangeSegmentedControl + ChartTooltipOverlay | d7ebdea | WorkloadViewModel.swift, TimeRangeSegmentedControl.swift, ChartTooltipOverlay.swift |
| 2 | RecoveryLoadChart + WorkloadView integration | 8e3dc3d | RecoveryLoadChart.swift, WorkloadView.swift |

## Implementation Details

### Task 1: ViewModel and Reusable Components
- Created `TimeRange` enum (4W/12W/6M) with `CaseIterable` and `Identifiable` conformance
- `WorkloadViewModel` fetches filtered snapshots from existing repository APIs (`fetchSnapshots(last:)` and `fetchRecoveryHistory(days:)`)
- `TimeRangeSegmentedControl` uses 0pt corners with hairline border per DESIGN.md
- `ChartTooltipGesture` provides DragGesture-based scrub with nearest-date matching
- `TooltipBubble` renders value + date in surfaceEl background

### Task 2: Correlation Chart and View Integration
- `RecoveryLoadChart` renders BarMark (daily ATL) + LineMark (recovery score scaled to load axis)
- Empty state shown when < 7 days of data
- `WorkloadView` now uses `WorkloadViewModel` for data management
- `LoadTrendChartView` enhanced with ATL/CTL lines, TSB area fill, and tooltip overlay
- Time range picker and correlation chart gated behind Pro subscription
- `.onChange(of: selectedRange)` triggers 250ms animated data refresh

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed deprecated plotAreaFrame API**
- **Found during:** Task 2 build verification
- **Issue:** `plotAreaFrame` deprecated in iOS 17.0, renamed to `plotFrame` (optional)
- **Fix:** Changed to `guard let plotFrame = proxy.plotFrame` with optional unwrap
- **Files modified:** WorkloadApp/Components/ChartTooltipOverlay.swift
- **Commit:** 8e3dc3d

**2. [Rule 3 - Blocking] Copied gitignored config files for build**
- **Found during:** Task 1 build verification
- **Issue:** SupabaseConfig.swift and RevenueCatConfig.swift are gitignored but needed for compilation
- **Fix:** Copied from main repo checkout to worktree (not committed, stays gitignored)
- **Files modified:** None (gitignored files)

## Decisions Made

1. **@State viewModel pattern**: Used `@State private var viewModel = WorkloadViewModel()` rather than environment injection, keeping the ViewModel lifecycle tied to the view.
2. **Subscription gating**: Time range picker and RecoveryLoadChart are Pro-only; free users see the default 28-day view without range selection.
3. **Tooltip via overlay**: Used `.overlay(alignment: .top)` for tooltip positioning rather than a second `.chartOverlay` with position calculation, which is simpler and avoids coordinate math issues.

## Known Stubs

None - all components render real data from existing repositories.

## Self-Check: PASSED
