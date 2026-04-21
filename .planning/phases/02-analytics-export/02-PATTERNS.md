# Phase 02: Analytics & Export - Pattern Map

**Mapped:** 2026-04-20
**Files analyzed:** 12 (new/modified)
**Analogs found:** 12 / 12

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `WorkloadApp/Services/AnalyticsEngine.swift` | engine | transform | `WorkloadApp/Services/WorkloadCalculator.swift` | exact |
| `WorkloadApp/Services/CSVExportEngine.swift` | engine | transform | `WorkloadApp/Services/WorkloadCalculator.swift` | role-match |
| `WorkloadApp/ViewModels/WorkloadViewModel.swift` | viewmodel | request-response | `WorkloadApp/ViewModels/DashboardViewModel.swift` | exact |
| `WorkloadApp/Views/Workload/WorkloadView.swift` | view | CRUD | (self - modify existing) | exact |
| `WorkloadApp/Views/Workload/RecoveryLoadChart.swift` | component | transform | `WorkloadApp/Components/HRVTrendChart.swift` | exact |
| `WorkloadApp/Views/Dashboard/DashboardView.swift` | view | CRUD | (self - modify existing) | exact |
| `WorkloadApp/Views/Dashboard/WeeklySummaryCard.swift` | component | transform | `WorkloadApp/Components/SpikeAlertBanner.swift` | role-match |
| `WorkloadApp/Components/TimeRangeSegmentedControl.swift` | component | event-driven | `WorkloadApp/Components/MetricTile.swift` | role-match |
| `WorkloadApp/Components/ChartTooltipOverlay.swift` | component | event-driven | `WorkloadApp/Components/HRVTrendChart.swift` | role-match |
| `WorkloadApp/Components/DeltaIndicator.swift` | component | transform | `WorkloadApp/Components/MetricTile.swift` | role-match |
| `WorkloadApp/Components/StalenessWarningBadge.swift` | component | transform | `WorkloadApp/Components/SpikeAlertBanner.swift` | exact |
| `WorkloadApp/Utilities/ShareSheet.swift` | utility | file-I/O | (no existing UIKit bridge) | no-analog |
| `WorkloadApp/Services/HealthKitService.swift` | service | request-response | (self - modify existing) | exact |
| `WorkloadApp/Services/RecoveryPipeline.swift` | service | request-response | (self - modify existing) | exact |

## Pattern Assignments

### `WorkloadApp/Services/AnalyticsEngine.swift` (engine, transform)

**Analog:** `WorkloadApp/Services/WorkloadCalculator.swift`

**Imports pattern** (line 1):
```swift
import Foundation
```

**Struct + static methods pattern** (lines 6-7, 22-26):
```swift
struct WorkloadCalculator {

    // MARK: - Data Types

    struct DailyLoad {
        let date: Date
        let tss: Double
    }
```

**Nested result types pattern** (lines 28-37):
```swift
    struct WorkloadResult {
        let date: Date
        let atl: Double
        let ctl: Double
        let acwr: Double
        let tsb: Double

        var zone: ACWRZone {
            ACWRZone.classify(acwr: acwr, ctl: ctl)
        }
    }
```

**Static method signature pattern** (lines 43-45):
```swift
    /// Training Stress Score for a single session using sRPE method (Foster).
    /// TSS = duration_hours x sessionRPE x (sessionRPE / 10)
    static func sessionTSS(durationSeconds: Int, sessionRPE: Double) -> Double {
```

---

### `WorkloadApp/Services/CSVExportEngine.swift` (engine, transform)

**Analog:** `WorkloadApp/Services/WorkloadCalculator.swift`

**Same pattern as AnalyticsEngine:** pure struct, static methods, `import Foundation` only.

**Key difference:** Methods return `String` (CSV content) instead of numeric results. No nested result types needed -- just static functions taking model arrays.

**Pattern to follow:**
```swift
import Foundation

/// Pure CSV generation engine. No state, no side effects.
struct CSVExportEngine {

    // MARK: - Session Summary

    /// Generate CSV for session-level export (one row per workout).
    static func sessionSummaryCSV(sessions: [WorkoutSession]) -> String {
        // ...
    }

    // MARK: - Detailed Sets

    /// Generate CSV for set-level export (one row per working set).
    static func detailedSetsCSV(sessions: [WorkoutSession]) -> String {
        // ...
    }
}
```

---

### `WorkloadApp/ViewModels/WorkloadViewModel.swift` (viewmodel, request-response)

**Analog:** `WorkloadApp/ViewModels/DashboardViewModel.swift`

**Class declaration pattern** (lines 1-8):
```swift
import Foundation
import SwiftData

/// ViewModel for the Dashboard tab.
/// Runs recovery pipeline and autoregulation engine on appear/foreground.
@MainActor
@Observable
final class DashboardViewModel {
```

**Published state properties pattern** (lines 9-36):
```swift
    // Recovery
    var recoveryScore: Double = 50
    var recoveryZone: RecoveryZone = .yellow

    // Workload
    var acwr: Double = 0
    var acwrZone: ACWRZone = .noData

    var isLoading = true
```

**Async load method pattern** (lines 38-44):
```swift
    func load(
        athlete: Athlete,
        healthKitService: HealthKitService,
        modelContext: ModelContext,
        syncService: SyncService? = nil
    ) async {
        isLoading = true
```

**Error handling in load** (lines 55-67):
```swift
            do {
                let recoveryResult = try await RecoveryPipeline.run(
                    athlete: athlete,
                    healthKitService: healthKitService,
                    modelContext: modelContext,
                    syncService: syncService
                )
                recoveryScore = recoveryResult.score
                recoveryZone = recoveryResult.zone
            } catch {
                print("Recovery pipeline error: \(error)")
            }
```

---

### `WorkloadApp/Views/Workload/RecoveryLoadChart.swift` (component, transform)

**Analog:** `WorkloadApp/Components/HRVTrendChart.swift`

**Imports and struct pattern** (lines 1-5):
```swift
import SwiftUI
import Charts

/// 28-day HRV trend line chart with 7-day baseline rule mark.
struct HRVTrendChart: View {
    let data: [(date: Date, value: Double)]
```

**Chart body with LineMark pattern** (lines 22-43):
```swift
        Chart {
            ForEach(data.indices, id: \.self) { i in
                LineMark(
                    x: .value("Date", data[i].date),
                    y: .value("HRV", data[i].value)
                )
                .foregroundStyle(ColorTokens.chartHRV)
                .symbol(Circle())
                .symbolSize(20)
            }

            if let baseline {
                RuleMark(y: .value("Baseline", baseline))
                    .foregroundStyle(ColorTokens.text3)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
            }
        }
        .frame(height: 180)
        .chartYAxisLabel("ms")
```

**Empty state pattern** (lines 15-20):
```swift
        if data.isEmpty {
            Text("No HRV data available. Connect a wearable device through Apple Health.")
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 24)
        } else {
```

---

### `WorkloadApp/Views/Dashboard/WeeklySummaryCard.swift` (component, transform)

**Analog:** `WorkloadApp/Components/SpikeAlertBanner.swift`

**Card structure with flat design** (lines 23-77):
```swift
    var body: some View {
        HStack(spacing: 0) {
            // Colored left border strip
            Rectangle()
                .fill(borderColor)
                .frame(width: 2)

            VStack(alignment: .leading, spacing: 8) {
                Text(severityLabel)
                    .font(.custom("DMSans-Medium", size: 11))
                    .tracking(0.88)
                    .foregroundStyle(borderColor)

                // ... content ...
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)

            Spacer()
        }
        .background(ColorTokens.surface)
        .overlay(
            Rectangle()
                .stroke(ColorTokens.divider, lineWidth: 0.5)
        )
    }
```

---

### `WorkloadApp/Components/DeltaIndicator.swift` (component, transform)

**Analog:** `WorkloadApp/Components/MetricTile.swift`

**Simple component pattern** (lines 1-34):
```swift
import SwiftUI

/// Reusable metric display tile used across Workload and Session detail views.
struct MetricTile: View {
    let title: String
    let value: String
    var subtitle: String?
    var color: Color = ColorTokens.text1

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.Tokens.micro)
                .tracking(1.2)
                .foregroundStyle(ColorTokens.text3)
            Text(value)
                .font(.Tokens.sectionHead)
                .monospacedDigit()
                .foregroundStyle(color)
        }
    }
}
```

---

### `WorkloadApp/Components/StalenessWarningBadge.swift` (component, transform)

**Analog:** `WorkloadApp/Components/SpikeAlertBanner.swift`

**Same card structure as SpikeAlertBanner** -- flat surface, colored left border, no shadows, no rounded corners. Replace severity-based color with `ColorTokens.zoneCaution` (yellow warning). Keep same font patterns (DMSans-Medium 11pt for label, DMSans-Regular 13pt for body).

---

### `WorkloadApp/Components/TimeRangeSegmentedControl.swift` (component, event-driven)

**Analog:** `WorkloadApp/Components/MetricTile.swift` (design) + Research pattern (interaction)

**Design tokens to match:**
```swift
.font(.Tokens.body)           // unselected
.font(.Tokens.bodyMedium)     // selected (if exists, else .Tokens.body with DMSans-Medium)
.foregroundStyle(ColorTokens.text1)  // selected
.foregroundStyle(ColorTokens.text2)  // unselected
.background(ColorTokens.surface)     // selected segment
.background(ColorTokens.background)  // unselected
.overlay(Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5))  // outer border
```

---

### `WorkloadApp/Services/HealthKitService.swift` (MODIFY - staleness detection)

**Current fetch pattern** (lines 49-52):
```swift
    func fetchLatestHRV() async throws -> Double? {
        let type = HKQuantityType(.heartRateVariabilitySDNN)
        let sample = try await fetchMostRecentSample(type: type)
        return sample?.quantity.doubleValue(for: .secondUnit(with: .milli))
    }
```

**Modification needed:** Return `(value: Double, sampleDate: Date)?` tuple OR add separate methods that return sample dates. The `fetchMostRecentSample` already returns `HKQuantitySample?` which has `.startDate` -- just expose it.

---

### `WorkloadApp/Services/RecoveryPipeline.swift` (MODIFY - staleness propagation)

**Current HealthKit fetch block** (lines 24-35):
```swift
        var hrv: Double?
        var rhr: Double?
        var sleep: Double?

        if healthKitService.isAuthorized {
            hrv = try? await healthKitService.fetchLatestHRV()
            rhr = try? await healthKitService.fetchLatestRestingHR()
            sleep = try? await healthKitService.fetchLastNightSleep()
        }
```

**Modification needed:** After fetching, also capture sample dates and construct `HealthKitStaleness` struct. Pass staleness info through `RecoveryResult` so views can display warning badges.

---

### `WorkloadApp/Views/Workload/WorkloadView.swift` (MODIFY - time range + export)

**Existing chart section pattern** (lines 73-76):
```swift
                    if visibleSnapshots.count > 1 {
                        LoadTrendChartView(snapshots: Array(visibleSnapshots.prefix(28).reversed()))
                    }
```

**Subscription gating pattern** (lines 13-16):
```swift
    private var visibleSnapshots: [WorkloadSnapshot] {
        container.subscriptionService.isPro
            ? snapshots
            : SubscriptionService.filterSnapshotsForFree(snapshots)
    }
```

**Sheet presentation pattern** (lines 97-100):
```swift
            .sheet(isPresented: $showUpgrade) {
                UpgradeSheet(trigger: .history(lockedWeeks: lockedWeeks))
            }
```

---

### `WorkloadApp/Views/Dashboard/DashboardView.swift` (MODIFY - weekly summary insertion)

**Section insertion point** (lines 24-46 show VStack structure):
```swift
                VStack(spacing: 0) {
                    HeroReadinessCard(viewModel: viewModel)
                    // ... EmptyStateCard ...
                    MetricsStrip(viewModel: viewModel)
                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                    TrainingLoadSection(viewModel: viewModel)
                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                    RecentSessionsSection(sessions: Array(recentSessions.prefix(5)))
                }
```

**Pattern:** Insert `WeeklySummaryCard` between `MetricsStrip` and `TrainingLoadSection`, separated by dividers.

---

## Shared Patterns

### Design System (applies to ALL new view/component files)
**Source:** `WorkloadApp/Components/MetricTile.swift`, `WorkloadApp/Components/SpikeAlertBanner.swift`
**Apply to:** All new Views and Components

```swift
// 0pt corners - use Rectangle(), never RoundedRectangle
.background(ColorTokens.surface)
.overlay(Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5))

// Font tokens only - never .system() or semantic styles
.font(.Tokens.micro)       // 11pt labels
.font(.Tokens.label)       // 13pt body
.font(.Tokens.body)        // 15pt text
.font(.Tokens.sectionHead) // larger headings

// Color tokens only - never hardcoded hex
ColorTokens.text1    // primary text
ColorTokens.text2    // secondary text
ColorTokens.text3    // tertiary/label text
ColorTokens.surface  // card backgrounds
ColorTokens.background // page background
ColorTokens.divider  // borders and separators

// 8pt grid spacing
.padding(.horizontal, 16)
.padding(.vertical, 16)
```

### Subscription Gating
**Source:** `WorkloadApp/Views/Workload/WorkloadView.swift` (lines 11-16)
**Apply to:** Export features, extended chart history

```swift
@Environment(AppContainer.self) private var container
@State private var showUpgrade = false

// Gate check
guard container.subscriptionService.isPro else {
    showUpgrade = true
    return
}

// Sheet presentation
.sheet(isPresented: $showUpgrade) {
    UpgradeSheet(trigger: .exportData)
}
```

### Chart Styling
**Source:** `WorkloadApp/Components/HRVTrendChart.swift`, `WorkloadApp/Views/Workload/WorkloadView.swift` (lines 160-181)
**Apply to:** All new chart components

```swift
import Charts

Chart {
    ForEach(data.indices, id: \.self) { i in
        LineMark(
            x: .value("Date", data[i].date),
            y: .value("Value", data[i].value)
        )
        .foregroundStyle(ColorTokens.chartATL)  // Use chart-specific color tokens
    }
}
.frame(height: 160)  // Standard chart height: 160-180pt
.chartLegend(position: .bottom)
```

### Section Header Pattern
**Source:** `WorkloadApp/Views/Workload/WorkloadView.swift` (lines 155-158)
**Apply to:** All new card/section headers

```swift
Text("LOAD TREND · 28 DAYS")
    .font(.Tokens.micro)
    .tracking(1.2)
    .foregroundStyle(ColorTokens.text3)
```

### Pure Engine Pattern
**Source:** `WorkloadApp/Services/WorkloadCalculator.swift`, `WorkloadApp/Services/RecoveryScoreEngine.swift`
**Apply to:** `AnalyticsEngine.swift`, `CSVExportEngine.swift`

```swift
import Foundation

/// [Doc comment explaining purpose]
struct EngineName {

    // MARK: - Data Types

    struct InputType { /* ... */ }
    struct ResultType { /* ... */ }

    // MARK: - Computation

    /// [Doc comment]
    static func compute(input: InputType) -> ResultType {
        // Pure calculation, no side effects
    }
}
```

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `WorkloadApp/Utilities/ShareSheet.swift` | utility | file-I/O | No UIKit bridge files exist in codebase yet. Use standard `UIViewControllerRepresentable` pattern from RESEARCH.md |

## Metadata

**Analog search scope:** `WorkloadApp/` (Services, ViewModels, Views, Components, Utilities)
**Files scanned:** ~25 unique files (excluding .claude/worktrees duplicates)
**Pattern extraction date:** 2026-04-20
