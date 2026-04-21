---
phase: 02-analytics-export
verified: 2026-04-20T17:00:00Z
status: human_needed
score: 5/5
overrides_applied: 0
human_verification:
  - test: "Open Workload tab as Pro user, tap 4W/12W/6M segments and confirm chart data updates"
    expected: "Chart redraws with correct time range data and 250ms animation"
    why_human: "Chart rendering and animation cannot be verified without a running simulator"
  - test: "Drag finger across the CTL/ATL trend chart and confirm tooltip appears with exact value + date"
    expected: "TooltipBubble shows load value and date formatted as 'Mon DD'"
    why_human: "Gesture handling and tooltip positioning requires live interaction"
  - test: "Open Workload tab as Pro user and confirm RecoveryLoadChart shows load bars with recovery line overlay"
    expected: "BarMark bars visible for ATL, LineMark visible for recovery scaled to load axis; empty state shown if <7 days data"
    why_human: "Chart rendering requires running simulator with real data"
  - test: "Log a workout and check Dashboard shows WeeklySummaryCard with session count, volume, avg recovery, load trend, and zone distribution"
    expected: "Card appears below MetricsStrip; DeltaIndicators show green/red arrows for week-over-week changes"
    why_human: "Requires real data + visual confirmation"
  - test: "Collapse and re-open WeeklySummaryCard, then kill and relaunch app — confirm collapse state is remembered"
    expected: "Card is still collapsed after relaunch (AppStorage persistence)"
    why_human: "AppStorage persistence requires app lifecycle test"
  - test: "As free user, tap export button — confirm UpgradeSheet appears. As Pro, tap export and select a format — confirm share sheet presents CSV file"
    expected: "Non-Pro sees paywall; Pro gets system share sheet with .csv attachment"
    why_human: "Subscription gating and UIActivityViewController require live interaction"
  - test: "Export Session Summary CSV and verify it contains no HRV, RHR, or sleep values — only load/ACWR composite scores"
    expected: "CSV headers: Date,Sport,Duration (min),RPE,Volume,Load,ATL,CTL,ACWR — no biometric fields"
    why_human: "Requires generating and inspecting actual CSV output"
  - test: "Disconnect HealthKit data for 24+ hours and confirm staleness badges appear on HRV/RHR/Sleep metrics in Dashboard MetricsStrip"
    expected: "StalenessWarningBadge shows 'Updated Xd ago' beneath the stale metric"
    why_human: "Requires simulating stale HealthKit data in real device/simulator environment"
---

# Phase 2: Analytics & Export Verification Report

**Phase Goal:** Athletes can see how their training load and recovery trend over weeks and months, and export their data
**Verified:** 2026-04-20T17:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (Roadmap Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Stale or missing HealthKit data surfaces a visible indicator instead of silently showing outdated recovery scores | VERIFIED | `HealthKitStaleness` struct with 24h threshold in `HealthKitService.swift`; propagated through `RecoveryPipeline` → `DashboardViewModel.staleness` → `MetricStripCell.staleDaysAgo` → `StalenessWarningBadge` rendered conditionally (line 306 of DashboardView.swift) |
| 2 | User can view CTL/ATL/TSB trend charts on the Workload tab with selectable time ranges (4w / 12w / 6m) | VERIFIED | `TimeRange` enum (4W/12W/6M) in `WorkloadViewModel.swift`; `TimeRangeSegmentedControl` rendered in `WorkloadView` when Pro (line 88); `trendData` filtered by `viewModel.selectedRange.days`; `.onChange(of: viewModel.selectedRange)` triggers reload with 250ms animation |
| 3 | User can see a weekly training summary showing sessions, volume, avg recovery, load trend, and ACWR zone breakdown | VERIFIED | `AnalyticsEngine.computeWeeklySummary` produces `WeeklySummary` with all required fields; `DashboardViewModel.weeklySummary` set in `load()`; `WeeklySummaryCard` rendered in `DashboardView` between MetricsStrip and TrainingLoadSection; `DeltaIndicator` shows colored arrows for session count, volume, and recovery deltas |
| 4 | User can view a 28-day recovery-load correlation overlay (recovery line on load bars) | VERIFIED | `RecoveryLoadChart` in `WorkloadView/RecoveryLoadChart.swift` renders `BarMark` for ATL + `LineMark` for recovery score scaled to load axis; wired to `viewModel.correlationLoadSnapshots` and `viewModel.correlationRecoverySnapshots`; empty state for <7 days |
| 5 | Pro user can export workout history as CSV via the system share sheet, with no raw HealthKit data included | VERIFIED | `CSVExportEngine` confirmed to contain no HRV/RHR/sleep fields in output; `WorkloadView` has toolbar button checking `container.subscriptionService.isPro`; `UpgradeTrigger.export` case added; `ShareSheet` bridges `UIActivityViewController`; non-Pro sees `UpgradeSheet(trigger: .export)` |

**Score:** 5/5 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `WorkloadApp/Services/HealthKitService.swift` | Staleness-aware fetch with `HealthKitStaleness` struct | VERIFIED | `struct HealthKitStaleness` at line 7; `fetchLatestHRVWithDate()`, `fetchLatestRestingHRWithDate()`, `fetchLastNightSleepWithDate()`, `fetchStaleness()` all present |
| `WorkloadApp/Services/RecoveryPipeline.swift` | Staleness propagation through `RecoveryResult` | VERIFIED | `RecoveryResult.staleness: HealthKitStaleness` present; constructed from `WithDate` method results before score computation |
| `WorkloadApp/Services/AnalyticsEngine.swift` | Pure weekly summary computation engine | VERIFIED | `struct AnalyticsEngine` with `computeWeeklySummary`, `WeeklySummary` (sessionCount, totalVolume, avgRecoveryScore, loadTrendDirection, acwrZoneDistribution, sessionCountDelta, volumeDelta, recoveryDelta), `TrendDirection` enum |
| `WorkloadApp/Services/CSVExportEngine.swift` | Pure CSV string generation | VERIFIED | `struct CSVExportEngine` with `sessionSummaryCSV(sessions:)`, `detailedSetsCSV(sessions:)`, `escapeCSV` RFC 4180 helper; no HRV/RHR/sleep values in output |
| `WorkloadApp/Components/StalenessWarningBadge.swift` | Inline warning badge component | VERIFIED | `struct StalenessWarningBadge: View` with `exclamationmark.triangle.fill`, `ColorTokens.zoneCaution`, `"Updated Xd ago"` text |
| `WorkloadApp/ViewModels/WorkloadViewModel.swift` | Time range state management | VERIFIED | `enum TimeRange` (4W/12W/6M), `var selectedRange`, `func loadTrendData(modelContext:)` calling `fetchSnapshots(last:)` and `fetchRecoveryHistory(days:)` |
| `WorkloadApp/Components/TimeRangeSegmentedControl.swift` | Segmented control for time range selection | VERIFIED | `struct TimeRangeSegmentedControl: View` with `@Binding var selected: TimeRange`; 0pt corners (no `RoundedRectangle`); hairline border via `Rectangle().stroke` |
| `WorkloadApp/Components/ChartTooltipOverlay.swift` | Reusable chart tooltip with DragGesture | VERIFIED | `struct ChartTooltipGesture` with `DragGesture(minimumDistance: 0)`, `proxy.plotFrame`, `proxy.value(atX:)`, `closestDate`; `struct TooltipBubble` with value + date display |
| `WorkloadApp/Views/Workload/RecoveryLoadChart.swift` | 28-day correlation chart component | VERIFIED | `struct RecoveryLoadChart: View`; `BarMark` for ATL, `LineMark` for recovery; `ColorTokens.chartVolume`, `ColorTokens.zoneOptimal`; `"RECOVERY vs LOAD · 28 DAYS"` header; empty state for <7 days |
| `WorkloadApp/Views/Workload/WorkloadView.swift` | Integrated workload tab with all new components | VERIFIED | `TimeRangeSegmentedControl`, `RecoveryLoadChart`, export toolbar button, confirmation dialog, `ShareSheet`, `UpgradeSheet(trigger: .export)` all present; no `RoundedRectangle` |
| `WorkloadApp/Components/DeltaIndicator.swift` | Colored arrow + percentage inline component | VERIFIED | `struct DeltaIndicator: View`; `arrow.up`/`arrow.down`; `ColorTokens.zoneOptimal`/`ColorTokens.zoneDanger`; `abs(delta) < 1.0` threshold; em dash for negligible |
| `WorkloadApp/Views/Dashboard/WeeklySummaryCard.swift` | Collapsible weekly summary card | VERIFIED | `struct WeeklySummaryCard: View`; `"THIS WEEK"`, `"ZONE DISTRIBUTION"`, `DeltaIndicator(delta:)`, `@AppStorage("weeklySummaryExpanded")`, `chevron.down`, `.easeOut(duration: 0.25)`; no `RoundedRectangle` or `.shadow` |
| `WorkloadApp/ViewModels/DashboardViewModel.swift` | Weekly summary data from AnalyticsEngine | VERIFIED | `var weeklySummary: AnalyticsEngine.WeeklySummary?`; `AnalyticsEngine.computeWeeklySummary(...)` called with date-range repository results in `load()` |
| `WorkloadApp/Utilities/ShareSheet.swift` | UIActivityViewController bridge | VERIFIED | `struct ShareSheet: UIViewControllerRepresentable` with `UIActivityViewController` |
| `WorkloadApp/Views/Subscription/UpgradeSheet.swift` | Export trigger case for paywall | VERIFIED | `case export` present in `UpgradeTrigger` enum |
| Repositories (WorkoutRepository, RecoveryRepository, WorkloadRepository) | Date-range fetch methods | VERIFIED | `fetchSessions(from:to:)` in WorkoutRepository; `fetchSnapshots(from:to:)` in RecoveryRepository and WorkloadRepository |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `HealthKitService.swift` | `RecoveryPipeline.swift` | `HealthKitStaleness` struct passed through fetch results | WIRED | `fetchLatestHRVWithDate()` etc. called in pipeline; staleness constructed at line 51 of RecoveryPipeline |
| `RecoveryPipeline.swift` | `DashboardView.swift` | staleness exposed on `DashboardViewModel` | WIRED | `staleness = recoveryResult.staleness` in DashboardViewModel.load(); `viewModel.staleness.daysAgo(...)` used at lines 247/255/263 of DashboardView |
| `TimeRangeSegmentedControl.swift` | `WorkloadViewModel.swift` | `@Binding var selected: TimeRange` updates ViewModel state | WIRED | `$viewModel.selectedRange` passed as binding in WorkloadView |
| `WorkloadViewModel.swift` | `WorkloadView.swift` | ViewModel provides filtered snapshot arrays | WIRED | `viewModel.correlationLoadSnapshots`, `viewModel.correlationRecoverySnapshots` passed to `RecoveryLoadChart`; `viewModel.selectedRange.days` used in `trendData` computed property |
| `AnalyticsEngine.swift` | `DashboardViewModel.swift` | ViewModel calls `AnalyticsEngine.computeWeeklySummary` | WIRED | `AnalyticsEngine.computeWeeklySummary(...)` called at line 151 of DashboardViewModel |
| `DashboardViewModel.swift` | `WeeklySummaryCard.swift` | ViewModel passes `WeeklySummary` to card | WIRED | `WeeklySummaryCard(summary: summary)` where `summary = viewModel.weeklySummary` in DashboardView |
| `CSVExportEngine.swift` | `WorkloadView.swift` | ViewModel calls engine, writes temp file, presents share sheet | WIRED | `CSVExportEngine.sessionSummaryCSV(sessions: allSessions)` and `CSVExportEngine.detailedSetsCSV(sessions: allSessions)` in `exportCSV(format:)` method |
| `ShareSheet.swift` | `WorkloadView.swift` | Sheet presentation with file URL | WIRED | `.sheet(isPresented: $showShareSheet) { if let url = exportFileURL { ShareSheet(items: [url]) } }` |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|--------------|--------|-------------------|--------|
| `WeeklySummaryCard` | `summary: AnalyticsEngine.WeeklySummary` | `DashboardViewModel.load()` → `WorkoutRepository.fetchSessions(from:to:)`, `RecoveryRepository.fetchSnapshots(from:to:)`, `WorkloadRepository.fetchSnapshots(from:to:)` | Yes — SwiftData FetchDescriptor queries with date predicates | FLOWING |
| `RecoveryLoadChart` | `loadSnapshots`, `recoverySnapshots` | `WorkloadViewModel.loadTrendData()` → `WorkloadRepository.fetchSnapshots(last:)`, `RecoveryRepository.fetchRecoveryHistory(days:)` | Yes — SwiftData repository queries | FLOWING |
| `CSVExportEngine` (in WorkloadView) | `allSessions` | `@Query(sort: \WorkoutSession.sessionDate, order: .reverse)` | Yes — live SwiftData @Query | FLOWING |
| `StalenessWarningBadge` | `staleDaysAgo: viewModel.staleness.daysAgo(...)` | `RecoveryPipeline.run()` → `HealthKitService.fetchLatestHRVWithDate()` etc. | Yes — real HealthKit sample dates | FLOWING |

### Behavioral Spot-Checks

Step 7b: SKIPPED — verification requires a running iOS simulator; all relevant logic is confirmed via static code analysis. No CLI entry points exist for these features.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| PREREQ-01 | Plan 01 | Fix HealthKit silent error handling — surface stale data indicators | SATISFIED | `HealthKitStaleness` struct (24h threshold), staleness-aware fetch methods, `StalenessWarningBadge` wired to DashboardView MetricsStrip cells |
| ANLYT-01 | Plan 02 | Multi-week trend charts with time-range picker (4w/12w/6m) | SATISFIED | `TimeRange` enum, `TimeRangeSegmentedControl`, `trendData` filtered by range, `LoadTrendChartView` in WorkloadView |
| ANLYT-02 | Plans 01, 03 | Weekly training summary with sessions, volume, avg recovery, load trend, ACWR zone distribution | SATISFIED | `AnalyticsEngine.WeeklySummary` struct with all fields; `WeeklySummaryCard` renders all metrics |
| ANLYT-03 | Plans 01, 03 | Week-over-week load comparison showing delta percentage | SATISFIED | `sessionCountDelta`, `volumeDelta`, `recoveryDelta` in `WeeklySummary`; `DeltaIndicator` shows colored arrows |
| ANLYT-04 | Plan 02 | Recovery-load correlation view — recovery line on daily load bars (28-day) | SATISFIED | `RecoveryLoadChart` with `BarMark` (ATL) + `LineMark` (recovery scaled to load axis); wired to `WorkloadViewModel` 28-day data |
| EXPORT-01 | Plans 01, 04 | CSV export of workout session history — gated behind Pro subscription | SATISFIED | `CSVExportEngine.sessionSummaryCSV` and `detailedSetsCSV`; export toolbar in `WorkloadView` with `isPro` gate; `ShareSheet` wired |
| EXPORT-02 | Plans 01, 04 | CSV must exclude raw HealthKit data | SATISFIED | `CSVExportEngine` contains no HRV/RHR/sleep fields; confirmed by grep — no matches for biometric field names |

All 7 requirement IDs declared across plans (PREREQ-01, ANLYT-01, ANLYT-02, ANLYT-03, ANLYT-04, EXPORT-01, EXPORT-02) are satisfied. No orphaned requirements found for Phase 2.

### Anti-Patterns Found

| File | Pattern | Severity | Impact |
|------|---------|----------|--------|
| None | — | — | No anti-patterns detected across all new phase 2 files |

No TODO/FIXME comments, no placeholder returns, no hardcoded empty arrays flowing to render output, no RoundedRectangle or shadow violations in new files.

### Human Verification Required

The automated checks pass for all 5 roadmap success criteria. The following require live simulator/device testing:

#### 1. Time-Range Chart Switching (ANLYT-01)

**Test:** Open the Workload tab as a Pro user. Tap "4W", "12W", "6M" segments in sequence.
**Expected:** Chart redraws each time with data scoped to 28/84/180 days; 250ms easeOut animation visible; `RecoveryLoadChart` always shows 28-day fixed window regardless of time range
**Why human:** Chart rendering and animation cannot be verified by static analysis

#### 2. Chart Tooltip on Drag (ANLYT-01)

**Test:** In the Workload tab trend chart, drag a finger across the chart surface.
**Expected:** `TooltipBubble` appears showing "Load: XX" and a formatted date; bubble disappears on finger lift
**Why human:** `DragGesture` interaction and `ChartProxy.plotFrame` coordinate math require live gesture testing

#### 3. Recovery-Load Correlation Chart (ANLYT-04)

**Test:** On Workload tab as Pro user, scroll to `RecoveryLoadChart`. View with 7+ days of data.
**Expected:** Gray-ish load bars (ATL) render per day; green recovery line overlaid and scaled to the same axis; tooltip shows "Load: X | Recovery: Y" on tap
**Why human:** Dual-series chart with scale normalization requires visual confirmation

#### 4. WeeklySummaryCard Display and Collapse Persistence (ANLYT-02, ANLYT-03)

**Test:** Log at least one session in the current week. Open Dashboard. Collapse the WeeklySummaryCard by tapping the chevron. Kill and relaunch the app.
**Expected:** Card is still collapsed after relaunch (AppStorage); DeltaIndicators show green/red arrows where deltas exceed 1%; em-dash for <1% changes
**Why human:** Requires real SwiftData records and AppStorage lifecycle test

#### 5. CSV Export Flow (EXPORT-01, EXPORT-02)

**Test:** As a Pro user on Workload tab, tap the export button (share icon in toolbar). Select "Session Summary". Accept or dismiss the share sheet. Then repeat with "Detailed Sets".
**Expected:** System share sheet appears with a `.csv` file attachment named `tonus_sessions_YYYY-MM-DD.csv`. File contains correct headers (Date,Sport,Duration (min),RPE,Volume,Load,ATL,CTL,ACWR). No HRV, RHR, or sleep columns present. As free user, `UpgradeSheet` appears instead.
**Why human:** `UIActivityViewController` presentation and CSV file inspection require live testing

#### 6. HealthKit Staleness Badge (PREREQ-01)

**Test:** Simulate no HealthKit data for 24+ hours (e.g., delete HRV samples in Health app or use a device that hasn't synced a wearable). Open Dashboard.
**Expected:** `StalenessWarningBadge` showing "Updated Xd ago" appears beneath the stale metrics (HRV, RHR, or Sleep) in the MetricsStrip
**Why human:** Requires HealthKit data manipulation in a live environment; staleness depends on real sample timestamps

### Gaps Summary

No gaps found. All 5 roadmap success criteria are verified at the code level (artifacts exist, are substantive, are wired, and data flows). Human verification items above are required to confirm visual/behavioral correctness before closing the phase.

---

_Verified: 2026-04-20T17:00:00Z_
_Verifier: Claude (gsd-verifier)_
