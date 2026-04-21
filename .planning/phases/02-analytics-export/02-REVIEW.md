---
phase: 02-analytics-export
reviewed: 2026-04-21T00:00:00Z
depth: standard
files_reviewed: 19
files_reviewed_list:
  - WorkloadApp/Components/ChartTooltipOverlay.swift
  - WorkloadApp/Components/DeltaIndicator.swift
  - WorkloadApp/Components/StalenessWarningBadge.swift
  - WorkloadApp/Components/TimeRangeSegmentedControl.swift
  - WorkloadApp/Repositories/RecoveryRepository.swift
  - WorkloadApp/Repositories/WorkloadRepository.swift
  - WorkloadApp/Repositories/WorkoutRepository.swift
  - WorkloadApp/Services/AnalyticsEngine.swift
  - WorkloadApp/Services/CSVExportEngine.swift
  - WorkloadApp/Services/HealthKitService.swift
  - WorkloadApp/Services/RecoveryPipeline.swift
  - WorkloadApp/Utilities/ShareSheet.swift
  - WorkloadApp/ViewModels/DashboardViewModel.swift
  - WorkloadApp/ViewModels/WorkloadViewModel.swift
  - WorkloadApp/Views/Dashboard/DashboardView.swift
  - WorkloadApp/Views/Dashboard/WeeklySummaryCard.swift
  - WorkloadApp/Views/Subscription/UpgradeSheet.swift
  - WorkloadApp/Views/Workload/RecoveryLoadChart.swift
  - WorkloadApp/Views/Workload/WorkloadView.swift
findings:
  critical: 1
  warning: 5
  info: 4
  total: 10
status: issues_found
---

# Phase 02: Code Review Report

**Reviewed:** 2026-04-21
**Depth:** standard
**Files Reviewed:** 19
**Status:** issues_found

## Summary

Reviewed 19 files comprising the Analytics & Export feature set: new components (ChartTooltipOverlay, DeltaIndicator, StalenessWarningBadge, TimeRangeSegmentedControl), analytics and CSV export engines, repository additions (date-range fetch methods), HealthKit staleness tracking, ViewModel changes for weekly summaries, dashboard integration (WeeklySummaryCard), workload view with export and time-range controls, and RecoveryLoadChart.

Overall the code is well-structured and follows project conventions (pure engines, @MainActor repositories, design system compliance). The main concerns are a CSV injection vulnerability in the export engine, several missing error-handling paths, and a data-scoping bug in the workload view's trend filtering.

## Critical Issues

### CR-01: CSV Injection via Unescaped Date/Numeric Fields

**File:** `WorkloadApp/Services/CSVExportEngine.swift:13-17`
**Issue:** The `escapeCSV` helper is only applied to string fields (`sport`, `exercise`), but the `date` field uses `ISO8601DateFormatter().string(from:)` which is safe, and numeric fields are formatted with `String(format:)` which is also safe. However, the `session.sessionName` (used elsewhere in the app) and any future string field additions would bypass escaping if developers follow the pattern of only escaping select fields. More critically, the `escapeCSV` function is `private` -- if a new CSV export method is added to this engine, the developer must remember to call it for every string field. This is a latent injection risk.

Additionally, the actual risk today: `session.sportType.rawValue` is passed through `escapeCSV`, but `SportType` is an enum with known safe values. The real exposure is in `detailedSetsCSV` at line 32 where `entry.exerciseName` (user-provided input) is correctly escaped. However, the pattern of building CSV rows via string interpolation (`"\(date),\(sport),..."`) means that if `escapeCSV` is ever missed on a user-input field, formula injection (`=CMD(...)`, `+CMD(...)`) could execute in spreadsheet applications.

**Fix:** Apply escaping to ALL fields uniformly, not selectively. Wrap each field in the CSV line through `escapeCSV`:
```swift
static func sessionSummaryCSV(sessions: [WorkoutSession]) -> String {
    var lines = ["Date,Sport,Duration (min),RPE,Volume,Load,ATL,CTL,ACWR"]
    for session in sessions.sorted(by: { $0.sessionDate < $1.sessionDate }) {
        let fields = [
            ISO8601DateFormatter().string(from: session.sessionDate),
            session.sportType.rawValue,
            String(format: "%.0f", session.durationMinutes),
            session.sessionRPE.map { String(format: "%.0f", $0) } ?? "",
            String(format: "%.1f", session.totalVolume),
            String(format: "%.1f", session.internalLoad),
            String(format: "%.1f", session.acuteLoad),
            String(format: "%.1f", session.chronicLoad),
            session.chronicLoad > 0 ? String(format: "%.2f", session.acuteLoad / session.chronicLoad) : ""
        ].map { escapeCSV($0) }
        lines.append(fields.joined(separator: ","))
    }
    return lines.joined(separator: "\n")
}
```

## Warnings

### WR-01: Trend Data Filtering Uses Array Position Instead of Date

**File:** `WorkloadApp/Views/Workload/WorkloadView.swift:47-48`
**Issue:** The `trendData` computed property takes `visibleSnapshots.prefix(viewModel.selectedRange.days).reversed()`. Since `visibleSnapshots` is sorted by date descending (from the `@Query` on line 6), `.prefix(N)` takes the N most recent snapshots. But if there are gaps (days without workouts), this returns fewer than `N` days of data, which is correct. However, if the user is on the free tier, `visibleSnapshots` is filtered to only 7 days of data via `filterSnapshotsForFree`, so selecting "12W" or "6M" would still only show 7 days of data -- but the time range control is only shown for Pro users (line 87-94), so this is safe. The actual issue: `.prefix(viewModel.selectedRange.days)` limits by count, not by date range. If there are multiple snapshots per day (e.g., from re-running the workout pipeline), this would show fewer calendar days than expected.
**Fix:** Filter by date instead of count:
```swift
private var trendData: [WorkloadSnapshot] {
    let cutoff = Calendar.current.date(byAdding: .day, value: -viewModel.selectedRange.days, to: .now)!
    return visibleSnapshots.filter { $0.snapshotDate >= cutoff }.reversed()
}
```

### WR-02: WeeklySummaryCard State Sync Issue Between @AppStorage and @State

**File:** `WorkloadApp/Views/Dashboard/WeeklySummaryCard.swift:7-8`
**Issue:** `storedExpanded` (`@AppStorage`) and `isExpanded` (`@State`) are separate sources of truth. On toggle (line 16-17), both are updated. On appear (line 81), `isExpanded` is set from `storedExpanded`. However, if the view is recreated during the same app session (e.g., tab switching with identity change), `@State` initializes to `true` (line 8) before `onAppear` fires, causing a brief flash of expanded state even if the user collapsed it. The `@State` default should match the persisted default, or better, use only `@AppStorage`.
**Fix:** Remove the `@State` property and use `@AppStorage` directly as the single source of truth:
```swift
@AppStorage("weeklySummaryExpanded") private var isExpanded: Bool = true
// Remove: @State private var isExpanded: Bool = true
// Remove: .onAppear { isExpanded = storedExpanded }
// In toggle: just isExpanded.toggle() (AppStorage handles persistence)
```

### WR-03: DashboardViewModel.computeDaysSinceRest Checks Today First, Skipping Current Day

**File:** `WorkloadApp/ViewModels/DashboardViewModel.swift:193-210`
**Issue:** The function starts `checkDate` at `startOfDay(for: .now)` (today) and checks if today has a session. If there is no session today, it immediately returns 0 days since rest. This means if an athlete has trained 6 consecutive days and has not yet logged today's session, `daysSinceRest` returns 0 instead of 6. The autoregulation engine then underestimates consecutive training days, potentially giving less conservative advice.
**Fix:** Start checking from yesterday (the last completed day) rather than today:
```swift
private func computeDaysSinceRest(workoutRepo: WorkoutRepository) -> Int {
    guard let sessions = try? workoutRepo.fetchSessions(last: 14) else { return 0 }
    let calendar = Calendar.current
    var days = 0
    var checkDate = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: .now))!

    while days < 14 {
        let dayStart = checkDate
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        let hasSession = sessions.contains { s in
            s.sessionDate >= dayStart && s.sessionDate < dayEnd
        }
        if !hasSession { break }
        days += 1
        checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
    }
    return days
}
```

### WR-04: ISO8601DateFormatter Allocated Per Row in CSV Export

**File:** `WorkloadApp/Services/CSVExportEngine.swift:13,29`
**Issue:** `ISO8601DateFormatter()` is instantiated inside the loop body for every session row. While not a correctness bug, `ISO8601DateFormatter` is a relatively heavyweight object. For large export sets (hundreds of sessions), this creates unnecessary allocations. More importantly, this is a code quality issue -- the formatter should be a local constant outside the loop.
**Fix:** Move the formatter outside the loop:
```swift
static func sessionSummaryCSV(sessions: [WorkoutSession]) -> String {
    let formatter = ISO8601DateFormatter()
    var lines = ["Date,Sport,Duration (min),RPE,Volume,Load,ATL,CTL,ACWR"]
    for session in sessions.sorted(by: { $0.sessionDate < $1.sessionDate }) {
        let date = formatter.string(from: session.sessionDate)
        // ...
    }
}
```
Apply the same fix in `detailedSetsCSV`.

### WR-05: RecoveryPipeline Passes ModelContext to Background Task via Closure Capture

**File:** `WorkloadApp/Services/RecoveryPipeline.swift:96-101`
**Issue:** The `Task` block on line 98 captures `modelContext` (a `@MainActor`-isolated reference) and `syncService`. Since the `Task` inherits the `@MainActor` context from the `static func run` (which is in a `@MainActor struct`), this is technically safe in the current code. However, the pattern of spawning a fire-and-forget `Task` that uses `modelContext` is fragile -- if the calling code deallocates or the context is invalidated, the push could fail silently. The error is already suppressed (no `try` / catch around `pushRecoveryAndWellness`).
**Fix:** Add error handling to the fire-and-forget sync task:
```swift
if let syncService {
    let athleteId = athlete.id
    Task {
        do {
            await syncService.pushRecoveryAndWellness(context: modelContext, athleteId: athleteId)
        } catch {
            print("Recovery sync error: \(error)")
        }
    }
}
```

## Info

### IN-01: DeltaIndicator Treats All Positive Deltas as "Good" (Green)

**File:** `WorkloadApp/Components/DeltaIndicator.swift:21`
**Issue:** The component uses green (`zoneOptimal`) for positive deltas and red (`zoneDanger`) for negative deltas. However, context matters: for recovery score, a positive delta is good, but for training volume, a large positive delta might indicate overtraining risk. The component does not accept a `positiveIsGood` parameter to invert the color semantics.
**Fix:** Consider adding a `positiveIsGood: Bool = true` parameter to allow callers to invert the color mapping for metrics where increases are concerning.

### IN-02: StalenessWarningBadge Uses System Font for SF Symbol

**File:** `WorkloadApp/Components/StalenessWarningBadge.swift:12`
**Issue:** The exclamation mark SF Symbol uses `.font(.custom("DMSans-Regular", size: 11))`. SF Symbols render based on the font's metrics. Using a custom font for SF Symbols can cause inconsistent sizing and alignment compared to the system font. The design system mandates DM Sans for text, but SF Symbols are not text glyphs.
**Fix:** Consider using `.font(.system(size: 11))` for the SF Symbol image specifically, since SF Symbols are designed for the system font. The text label on line 14 correctly uses `.Tokens.micro`.

### IN-03: Unused `excludedActivityTypes` Property in ShareSheet

**File:** `WorkloadApp/Utilities/ShareSheet.swift:8`
**Issue:** `excludedActivityTypes` is declared as `let` with a default value of `nil` and is never overridden by any caller. This is dead code.
**Fix:** Either remove the property and pass `nil` directly on line 11, or make it a configurable `init` parameter if exclusion is planned.

### IN-04: UpgradeSheet Force-Unwraps URLs

**File:** `WorkloadApp/Views/Subscription/UpgradeSheet.swift:178-181`
**Issue:** The Terms and Privacy URLs are constructed with `URL(string:)!` (force-unwrap). While these are hardcoded valid URLs and will not crash at runtime, force-unwrapping is a code smell. If the URL strings are ever modified incorrectly, the app would crash.
**Fix:** Use `guard let` or provide the URLs as static constants validated at compile time:
```swift
private static let termsURL = URL(string: "https://haaanw.github.io/WorkloadManagementApp/terms.html")!
private static let privacyURL = URL(string: "https://haaanw.github.io/WorkloadManagementApp/privacy.html")!
```
Moving them to constants makes the force-unwrap intentional and auditable in one place.

---

_Reviewed: 2026-04-21_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
