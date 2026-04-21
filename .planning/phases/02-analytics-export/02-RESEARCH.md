# Phase 02: Analytics & Export - Research

**Researched:** 2026-04-20
**Domain:** Swift Charts analytics, HealthKit staleness detection, CSV data export
**Confidence:** HIGH

## Summary

This phase adds multi-week trend visualization, weekly training summaries, recovery-load correlation, and CSV export to an existing SwiftUI + SwiftData iOS app that already has working chart infrastructure (Apple Charts framework), workload calculation engines, and recovery pipelines. The core challenge is extending existing patterns rather than building from scratch.

The prerequisite (PREREQ-01) requires adding staleness detection to the HealthKit fetch layer -- checking timestamps of last-received samples and surfacing a warning when data is >24h old. The analytics features (ANLYT-01 through ANLYT-04) extend existing `WorkloadSnapshot` and `RecoverySnapshot` queries with time-range filtering and new chart compositions. The export features (EXPORT-01, EXPORT-02) generate CSV strings from SwiftData models and present via `UIActivityViewController`.

**Primary recommendation:** Build incrementally on existing patterns -- pure engine structs for calculations, `@Query` with date predicates for data, Swift Charts `LineMark`/`BarMark`/`AreaMark` for visualization, and `.chartOverlay` with `DragGesture` for tooltips.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- D-01: Time range picker uses segmented control (4w / 12w / 6m) above trend charts
- D-02: Tap data points for tooltip overlay showing exact value + date using chartOverlay pattern
- D-03: Weekly summary lives as collapsible card section on Dashboard below readiness score
- D-04: Week-over-week deltas shown as colored arrows + percentage
- D-05: Stale HealthKit data surfaced via inline warning badge (yellow warning icon + "Last updated Xd ago")
- D-06: Staleness threshold is 24 hours
- D-07: Two CSV export options: "Session Summary" (one row per session) AND "Detailed Sets" (one row per set)
- D-08: Export via share sheet button on Profile or Workload tab
- D-09: CSV must exclude raw HealthKit data -- only composite scores

### Claude's Discretion
- Recovery-load correlation chart style (overlay approach, colors, axis scaling)
- Weekly summary metrics ordering and emphasis
- CSV file naming convention
- Exact placement of share sheet button (Profile vs Workload tab)

### Deferred Ideas (OUT OF SCOPE)
None.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PREREQ-01 | Fix HealthKit silent error handling -- surface stale data indicators | HealthKit sample timestamps available via `fetchMostRecentSample`; add date tracking to pipeline |
| ANLYT-01 | Multi-week trend charts (CTL/ATL/TSB) with time-range picker (4w/12w/6m) | Existing `WorkloadRepository.fetchSnapshots(last:)` supports date filtering; extend with 28/84/180 day queries |
| ANLYT-02 | Weekly training summary (sessions, volume, avg recovery, load trend, ACWR zone distribution) | `WorkoutSession` has all needed fields; `RecoverySnapshot.recoveryScore` for avg; `WorkloadSnapshot.zone` for distribution |
| ANLYT-03 | Week-over-week load comparison (delta percentage for volume and session count) | Compare current 7-day vs previous 7-day from same queries |
| ANLYT-04 | Recovery-load correlation (recovery line on load bars, 28-day) | Both `RecoverySnapshot` and `WorkloadSnapshot` keyed by date; join on calendar day |
| EXPORT-01 | CSV export of workout history gated behind Pro | SwiftData `@Query` for all sessions + entries; string construction + `UIActivityViewController` |
| EXPORT-02 | CSV excludes raw HealthKit data (only composite scores) | Export from `WorkoutSession` model fields only; recovery score from `RecoverySnapshot.recoveryScore` |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| HealthKit staleness detection | Frontend (RecoveryPipeline) | -- | Sample timestamps from HealthKit evaluated locally before UI render |
| Trend chart rendering | Views (SwiftUI) | -- | Pure view-layer concern using `@Query` data |
| Time-range data filtering | Repository / @Query | -- | SwiftData predicates handle date filtering efficiently |
| Weekly summary computation | Engine (pure struct) | ViewModel | Calculation logic belongs in engine; ViewModel orchestrates |
| CSV generation | Engine (pure struct) | -- | String manipulation is pure computation with no side effects |
| Share sheet presentation | Views (SwiftUI) | -- | UIActivityViewController presented from view layer |
| Pro subscription gating | ViewModel | Views | Gate check in ViewModel; view shows UpgradeSheet |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Swift Charts | iOS 16+ (bundled) | All chart rendering (LineMark, BarMark, AreaMark, chartOverlay) | Already in use across 7 files; Apple's first-party solution [VERIFIED: codebase grep] |
| SwiftData | iOS 17+ (bundled) | Data queries with date predicates | Already the persistence layer [VERIFIED: codebase] |
| SwiftUI | iOS 17+ (bundled) | UI composition, segmented controls, sheets | App framework [VERIFIED: codebase] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| UIKit (UIActivityViewController) | iOS 17+ | System share sheet for CSV export | Bridged via `UIViewControllerRepresentable` for share |
| Foundation (DateFormatter, ISO8601) | iOS 17+ | CSV date formatting | String generation for export |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| UIActivityViewController | ShareLink (SwiftUI) | ShareLink works for simple items but UIActivityViewController gives more control over file naming and MIME type |
| Manual CSV string building | TabularData framework | TabularData (DataFrame) is overkill for simple CSV; plain string concatenation is simpler and has no import cost |

**Installation:** No new dependencies needed. All capabilities come from Apple frameworks already linked. [VERIFIED: codebase]

## Architecture Patterns

### System Architecture Diagram

```
User taps time range (4w/12w/6m)
    |
    v
SegmentedControl updates @State enum
    |
    v
ViewModel.loadTrendData(range:)
    |
    v
WorkloadRepository.fetchSnapshots(last: days)  <-- SwiftData query
    |                                                    |
    v                                                    v
WorkloadSnapshot[] (sorted by date)      RecoverySnapshot[] (for correlation)
    |                                                    |
    v                                                    v
Chart(snapshots) {                           Chart {
  LineMark (ATL)                               BarMark (daily load)
  LineMark (CTL)                               LineMark (recovery score)
  AreaMark (TSB)                             }
}
    |
    v
.chartOverlay { proxy in DragGesture -> tooltip }
```

### Recommended Project Structure
```
WorkloadApp/
├── Services/
│   ├── AnalyticsEngine.swift       # NEW: weekly summary computation, delta calculations
│   └── CSVExportEngine.swift       # NEW: CSV string generation (pure struct, static methods)
├── ViewModels/
│   └── WorkloadViewModel.swift     # NEW: manages time range state, chart data, export trigger
├── Views/
│   └── Workload/
│       ├── WorkloadView.swift      # MODIFIED: add segmented control, correlation chart, export button
│       └── RecoveryLoadChart.swift  # NEW: correlation chart component
├── Views/
│   └── Dashboard/
│       ├── DashboardView.swift     # MODIFIED: insert WeeklySummaryCard
│       └── WeeklySummaryCard.swift  # NEW: collapsible weekly summary
├── Components/
│   ├── TimeRangeSegmentedControl.swift  # NEW
│   ├── ChartTooltipOverlay.swift        # NEW: reusable tooltip modifier
│   ├── DeltaIndicator.swift             # NEW: colored arrow + percentage
│   └── StalenessWarningBadge.swift      # NEW: inline warning badge
└── Utilities/
    └── ShareSheet.swift            # NEW: UIActivityViewController bridge
```

### Pattern 1: Swift Charts chartOverlay for Tooltip
**What:** Tap-and-drag gesture on chart to show exact values at data points
**When to use:** Any trend chart requiring exact value inspection (ANLYT-01, ANLYT-04)
**Example:**
```swift
// Source: Apple Swift Charts documentation (chartOverlay modifier) [ASSUMED]
Chart { /* marks */ }
    .chartOverlay { proxy in
        GeometryReader { geometry in
            Rectangle().fill(.clear).contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let xPosition = value.location.x - geometry[proxy.plotAreaFrame].origin.x
                            guard let date: Date = proxy.value(atX: xPosition) else { return }
                            // Find closest data point to `date`
                            selectedDate = date
                        }
                        .onEnded { _ in selectedDate = nil }
                )
        }
    }
```

### Pattern 2: Time Range Enum with Day Count
**What:** Strongly typed time range selection mapped to query parameters
**When to use:** ANLYT-01 segmented control
**Example:**
```swift
enum TimeRange: String, CaseIterable, Identifiable {
    case fourWeeks = "4W"
    case twelveWeeks = "12W"
    case sixMonths = "6M"

    var id: String { rawValue }
    var days: Int {
        switch self {
        case .fourWeeks: return 28
        case .twelveWeeks: return 84
        case .sixMonths: return 180
        }
    }
}
```

### Pattern 3: Pure Engine for Weekly Summary
**What:** Static computation of weekly metrics from session arrays
**When to use:** ANLYT-02, ANLYT-03
**Example:**
```swift
struct AnalyticsEngine {
    struct WeeklySummary {
        let sessionCount: Int
        let totalVolume: Double
        let avgRecoveryScore: Double
        let loadTrendDirection: TrendDirection
        let acwrZoneDistribution: [ACWRZone: Int]
        let sessionCountDelta: Double  // percentage vs previous week
        let volumeDelta: Double        // percentage vs previous week
    }

    static func computeWeeklySummary(
        currentWeekSessions: [WorkoutSession],
        previousWeekSessions: [WorkoutSession],
        recoverySnapshots: [RecoverySnapshot],
        workloadSnapshots: [WorkloadSnapshot]
    ) -> WeeklySummary { /* ... */ }
}
```

### Pattern 4: CSV Export Engine
**What:** Pure string generation from model arrays, no side effects
**When to use:** EXPORT-01, EXPORT-02
**Example:**
```swift
struct CSVExportEngine {
    static func sessionSummaryCSV(sessions: [WorkoutSession]) -> String {
        var lines = ["Date,Sport,Duration (min),RPE,Volume,Load,ATL,CTL,ACWR"]
        for session in sessions {
            let date = ISO8601DateFormatter().string(from: session.sessionDate)
            let line = "\(date),\(session.sportType.rawValue),\(session.durationMinutes),\(session.sessionRPE ?? 0),\(session.totalVolume),\(session.internalLoad),\(session.acuteLoad),\(session.chronicLoad),\(session.acuteLoad > 0 && session.chronicLoad > 0 ? session.acuteLoad / session.chronicLoad : 0)"
            lines.append(line)
        }
        return lines.joined(separator: "\n")
    }

    static func detailedSetsCSV(sessions: [WorkoutSession]) -> String {
        var lines = ["Date,Exercise,Set,Reps,Weight (kg),RPE"]
        for session in sessions {
            for entry in session.sortedEntries {
                for set in entry.sortedSets where !set.isWarmup {
                    let date = ISO8601DateFormatter().string(from: session.sessionDate)
                    lines.append("\(date),\(entry.exerciseName),\(set.setIndex + 1),\(set.reps ?? 0),\(set.weightKg ?? 0),\(set.rpe ?? 0)")
                }
            }
        }
        return lines.joined(separator: "\n")
    }
}
```

### Pattern 5: HealthKit Staleness Detection
**What:** Track last sample date and flag when >24h
**When to use:** PREREQ-01
**Example:**
```swift
// Add to HealthKitService or create a StalenessChecker
struct HealthKitStaleness {
    let lastHRVDate: Date?
    let lastSleepDate: Date?
    let lastRHRDate: Date?

    var isHRVStale: Bool { isStale(lastHRVDate) }
    var isSleepStale: Bool { isStale(lastSleepDate) }
    var isRHRStale: Bool { isStale(lastRHRDate) }

    private func isStale(_ date: Date?) -> Bool {
        guard let date else { return true }
        return Date.now.timeIntervalSince(date) > 24 * 3600
    }

    func staleDaysAgo(_ date: Date?) -> Int? {
        guard let date, isStale(date) else { return nil }
        return Calendar.current.dateComponents([.day], from: date, to: .now).day
    }
}
```

### Anti-Patterns to Avoid
- **Fetching all snapshots in view body:** Use `@Query` with predicates or ViewModel with explicit date ranges. Never load unbounded data.
- **Mixing CSV logic with view code:** Keep export as pure engine. Views only trigger and present share sheet.
- **Hardcoding 28 in existing LoadTrendChartView:** Make it parameterized so the time range picker can control it.
- **Computing weekly summary in SwiftUI body:** Expensive computation must live in ViewModel's `load()` or a dedicated engine.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Share sheet | Custom share UI | `UIActivityViewController` via `UIViewControllerRepresentable` | System sheet handles AirDrop, Files, Mail, copy, all platform integrations |
| Chart tooltips | Custom overlay positioning math | `.chartOverlay { proxy in }` with `proxy.value(atX:)` | Charts framework handles coordinate conversion between plot space and screen space |
| Segmented control | Custom tab bar | `Picker` with `.pickerStyle(.segmented)` or custom using `HStack` + `Button` | Native accessibility support, but custom needed for 0pt corners per DESIGN.md |
| Date formatting | Manual string formatting | `DateFormatter` / `RelativeDateTimeFormatter` | Locale handling, edge cases |
| CSV escaping | Regex-based escaping | Wrap fields containing commas/quotes in double-quotes, escape inner quotes | RFC 4180 compliance for commas in exercise names |

**Key insight:** This phase has zero external dependencies to add. Every capability comes from Apple frameworks already linked in the project.

## Common Pitfalls

### Pitfall 1: HealthKit Sample Timestamps vs Query Dates
**What goes wrong:** `fetchMostRecentSample` returns the most recent sample but doesn't expose WHEN it was recorded relative to now. Code may show a "fresh" score computed from 3-day-old HRV data.
**Why it happens:** The existing `RecoveryPipeline` uses `try?` to suppress errors and proceeds with nil values, never checking sample recency.
**How to avoid:** After fetching each sample, check `sample.startDate` against the 24h threshold. Store last-fetched timestamps in the `HealthKitStaleness` struct and pass through to views.
**Warning signs:** Recovery score shows the same value for multiple days without updating.

### Pitfall 2: SwiftData @Query Reactivity with Date Predicates
**What goes wrong:** `@Query` with a `#Predicate` referencing `Date.now` or a computed date doesn't re-evaluate when the date changes.
**Why it happens:** SwiftData's `@Query` evaluates the predicate at view construction time; the date boundary is fixed.
**How to avoid:** Use `@State` for the time range, pass it to a ViewModel that fetches explicitly via repository, or use `FetchDescriptor` in `task { }`. Avoid dynamic date expressions in `#Predicate`.
**Warning signs:** Switching time range doesn't update chart data until view is dismissed and re-opened.

### Pitfall 3: CSV Commas in Exercise Names
**What goes wrong:** Exercise names like "Bench Press, Incline" break CSV parsing.
**Why it happens:** Naive string interpolation doesn't quote fields.
**How to avoid:** Wrap any field containing a comma or quote in double-quotes per RFC 4180. Escape internal quotes by doubling them.
**Warning signs:** Imported CSV in Excel/Numbers has shifted columns.

### Pitfall 4: Dual Y-Axis in Swift Charts
**What goes wrong:** Recovery-load correlation chart needs two scales (load: 0-N, recovery: 0-100) but Swift Charts doesn't natively support dual y-axes.
**Why it happens:** Apple Charts has a single y-axis domain per chart.
**How to avoid:** Normalize both series to a common visual range, OR use `chartYScale(domain:)` for the primary axis and manually scale the secondary series. Alternatively, use two overlaid charts with different y-axis configurations.
**Warning signs:** Recovery line (0-100) and load values (0-500+) render at incompatible scales making one series invisible.

### Pitfall 5: Large Data Sets in Charts
**What goes wrong:** 180 days of daily snapshots (6M range) can create performance issues with many marks.
**Why it happens:** Each data point creates a SwiftUI view; hundreds of marks compound layout time.
**How to avoid:** For 6M range, consider downsampling to weekly averages, or limit to one point per day max. The existing data model (one snapshot per day) means max 180 points which should be acceptable.
**Warning signs:** Scroll stutter or delayed rendering when switching to 6M.

## Code Examples

### chartOverlay Tooltip (Verified Pattern from Existing Codebase)
```swift
// Source: Apple Swift Charts API [ASSUMED - standard pattern]
// Existing codebase uses Charts framework with LineMark, BarMark extensively
@State private var selectedDate: Date?

Chart { /* marks */ }
    .chartOverlay { proxy in
        GeometryReader { geo in
            Rectangle().fill(.clear).contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let origin = geo[proxy.plotAreaFrame].origin
                            let location = CGPoint(
                                x: value.location.x - origin.x,
                                y: value.location.y - origin.y
                            )
                            if let date: Date = proxy.value(atX: location.x) {
                                selectedDate = closestDataPoint(to: date)
                            }
                        }
                        .onEnded { _ in selectedDate = nil }
                )
        }
    }
    .chartOverlay { proxy in
        if let selectedDate, let value = dataValue(for: selectedDate) {
            // Position tooltip at selected point
            if let xPos = proxy.position(forX: selectedDate),
               let yPos = proxy.position(forY: value) {
                TooltipView(date: selectedDate, value: value)
                    .position(x: xPos, y: yPos - 24)
            }
        }
    }
```

### UIActivityViewController Bridge
```swift
// Source: Standard UIKit bridge pattern [ASSUMED]
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// Usage: present as .sheet with temporary file URL
let csvString = CSVExportEngine.sessionSummaryCSV(sessions: sessions)
let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("tonus_sessions_\(dateString).csv")
try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
// Present ShareSheet(items: [tempURL])
```

### Segmented Control (0pt Corners per DESIGN.md)
```swift
// Source: DESIGN.md requires 0pt corners, so native Picker won't work [VERIFIED: DESIGN.md]
struct TimeRangeSegmentedControl: View {
    @Binding var selected: TimeRange

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TimeRange.allCases) { range in
                Button(range.rawValue) {
                    withAnimation(.easeOut(duration: 0.25)) {
                        selected = range
                    }
                }
                .font(selected == range ? .Tokens.bodyMedium : .Tokens.body)
                .foregroundStyle(selected == range ? ColorTokens.text1 : ColorTokens.text2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(selected == range ? ColorTokens.surface : ColorTokens.background)
            }
        }
        .overlay(
            Rectangle()
                .stroke(ColorTokens.divider, lineWidth: 0.5)
        )
        .padding(.horizontal, 16)
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `Charts` manual coordinate math | `.chartOverlay { proxy in }` with `proxy.value(atX:)` | iOS 16+ | No manual coordinate conversion needed |
| `UIActivityViewController` only | `ShareLink` (SwiftUI native) available | iOS 16+ | ShareLink is simpler but less flexible for file URLs; either works |
| `@FetchRequest` (Core Data) | `@Query` (SwiftData) | iOS 17+ | Already using SwiftData throughout |

**Deprecated/outdated:**
- Core Data `@FetchRequest`: This project uses SwiftData exclusively [VERIFIED: codebase]
- `Charts` pod (Daniel Gindi): Replaced by Apple's native Charts framework [VERIFIED: codebase uses Apple Charts]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `proxy.value(atX:)` returns the domain value at a given x coordinate in chartOverlay | Code Examples | Tooltip implementation would need different coordinate conversion approach |
| A2 | Swift Charts handles 180 data points without performance issues | Pitfall 5 | May need downsampling for 6M range |
| A3 | UIActivityViewController works with file URLs for CSV sharing | Code Examples | May need to use Data instead of URL, or use ShareLink |
| A4 | Two overlaid `.chartOverlay` modifiers can coexist on one Chart | Code Examples | May need single overlay with both gesture and rendering logic |

## Open Questions (RESOLVED)

1. **Dual Y-Axis for Recovery-Load Correlation** — RESOLVED: Normalize recovery score (0-100) to the load scale visually using a computed scale factor (`maxLoad / 100`). Use `.chartForegroundStyleScale` to differentiate series by color. No dual y-axis needed.

2. **ShareLink vs UIActivityViewController** — RESOLVED: Use UIActivityViewController wrapped in a `UIViewControllerRepresentable` bridge. Provides full control over file naming and reliable file URL sharing. Project already uses UIKit bridges elsewhere.

## Sources

### Primary (HIGH confidence)
- Codebase inspection: WorkloadView.swift, HealthKitService.swift, WorkloadCalculator.swift, RecoveryPipeline.swift, WorkloadRepository.swift, RecoveryRepository.swift, ExerciseEntry.swift, SetRecord.swift, WorkoutSession.swift
- UI Spec: 02-UI-SPEC.md (complete component inventory and layout)
- DESIGN.md constraints: 0pt corners, no shadows, DM Sans, 8pt grid

### Secondary (MEDIUM confidence)
- Apple Swift Charts API patterns (chartOverlay, proxy.value(atX:)) - well-established since iOS 16

### Tertiary (LOW confidence)
- Performance characteristics of 180-point charts (A2) - untested with this specific data

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - all frameworks already in use, zero new dependencies
- Architecture: HIGH - extending established patterns from existing codebase
- Pitfalls: MEDIUM - dual y-axis and large dataset concerns are theoretical until tested

**Research date:** 2026-04-20
**Valid until:** 2026-06-20 (stable Apple frameworks, no expected breaking changes)
