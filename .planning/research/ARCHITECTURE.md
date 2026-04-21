# Architecture Patterns

**Domain:** Training analytics, data export, and onboarding for athlete workload management
**Researched:** 2026-04-20

## Recommended Architecture

New analytics features slot into the existing layered MVVM + pipeline architecture without structural changes. The key insight: the app already persists daily WorkloadSnapshot and RecoverySnapshot rows, plus every WorkoutSession with derived fields (TSS, ATL, CTL, volume). All analytics engines can be pure structs consuming this historical data. No new persistence layer needed -- only new engines, one new pipeline, one new repository method set, and export utilities.

### Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| **WeeklySummaryEngine** (new, pure struct) | Aggregate 7-day windows: total volume, session count, avg RPE, avg recovery score, load delta vs prior week, sport distribution | WorkloadSnapshot[], RecoverySnapshot[], WorkoutSession[] |
| **PeriodizationEngine** (new, pure struct) | Detect training phases (accumulation, intensification, deload, peaking) from rolling CTL slope + volume trends | WorkloadSnapshot[] (28-56 day window) |
| **FatigueCorrelationEngine** (new, pure struct) | Correlate recovery dips with training spikes: lag analysis (1-3 day offset), identify repeated patterns | RecoverySnapshot[], WorkloadSnapshot[], WorkoutSession[] |
| **AnalyticsPipeline** (new, @MainActor struct) | Orchestrate all three engines, gather data from repositories, return composite analytics result | WeeklySummaryEngine, PeriodizationEngine, FatigueCorrelationEngine, WorkloadRepository, RecoveryRepository, WorkoutRepository |
| **AnalyticsViewModel** (new, @Observable) | Expose analytics state to views, manage loading, hold date range selection | AnalyticsPipeline |
| **ExportService** (new, @MainActor struct) | Generate PDF and CSV from analytics data + raw session history | AnalyticsPipeline result, WorkoutRepository, PDFKit, UIActivityViewController |
| **OnboardingFlowViewModel** (new or extended) | Manage first-run guidance sequence, sport preference capture | Athlete model, AthleteRepository |

### How New Components Follow Existing Patterns

Every new component maps directly to an established pattern in the codebase:

- **Engines** follow the `WorkloadCalculator` / `RecoveryScoreEngine` pattern: pure structs, static methods, no dependencies beyond Models/Enums, deterministic output. This is the correct pattern for analytics computation.
- **AnalyticsPipeline** follows the `WorkoutPipeline` / `RecoveryPipeline` pattern: `@MainActor struct` with static methods that compose repositories and engines.
- **AnalyticsViewModel** follows the `DashboardViewModel` pattern: `@MainActor @Observable final class` with an async `load()` method.
- **ExportService** is the only genuinely new pattern -- it produces files rather than persisted snapshots. Keep it as a `@MainActor struct` with static methods returning `Data` (PDF) or `String` (CSV).

## Data Flow

### Analytics Pipeline (read-only, no new writes)

```
AnalyticsView appears
  |
  v
AnalyticsViewModel.load(athlete, modelContext, dateRange)
  |
  v
AnalyticsPipeline.run(athlete, modelContext, dateRange)
  |
  +-- WorkoutRepository.fetchSessions(last: N)     --> [WorkoutSession]
  +-- WorkloadRepository.fetchSnapshots(last: N)    --> [WorkloadSnapshot]
  +-- RecoveryRepository.fetchRecoveryHistory(N)    --> [RecoverySnapshot]
  |
  +-- WeeklySummaryEngine.compute(sessions, workloadSnapshots, recoverySnapshots)
  |     --> [WeeklySummary]  (one per week in range)
  |
  +-- PeriodizationEngine.detect(workloadSnapshots)
  |     --> [TrainingPhase]  (labeled date ranges)
  |
  +-- FatigueCorrelationEngine.analyze(recoverySnapshots, workloadSnapshots)
  |     --> [FatiguePattern] (spike-dip pairs with lag)
  |
  v
AnalyticsPipeline.Result (composite of all three)
  |
  v
AnalyticsViewModel exposes to AnalyticsView
```

Key property: **This pipeline is entirely read-only.** It reads existing snapshots and sessions but never writes new data. This means it cannot corrupt existing data flows and can be developed and tested in isolation.

### Export Flow

```
User taps "Export" in AnalyticsView or ProfileView
  |
  v
ExportService.generatePDF(analyticsResult, sessions, athlete)
  --> PDFDocument (via PDFKit or UIGraphicsPDFRenderer)
  |
  OR
  |
ExportService.generateCSV(sessions, snapshots, dateRange)
  --> String (CSV content)
  |
  v
UIActivityViewController (share sheet)
  --> Files app, email, AirDrop, etc.
```

### Weekly Summary Data Requirements

Each `WeeklySummary` struct needs:

| Field | Source | Existing? |
|-------|--------|-----------|
| Total volume (kg or meters) | `WorkoutSession.totalVolume` | Yes |
| Session count | `count(WorkoutSession)` in date range | Yes |
| Average session RPE | `WorkoutSession.sessionRPE` | Yes |
| Total training stress | `WorkoutSession.trainingStress` | Yes |
| Average recovery score | `RecoverySnapshot.recoveryScore` | Yes |
| Week-over-week load delta | `WorkloadSnapshot.acuteLoad` | Yes |
| Sport type distribution | `WorkoutSession.sportType` | Yes |
| Days trained vs rest | `WorkoutSession.sessionDate` grouping | Yes |

All required data already exists in persisted models. No new data capture needed.

### Periodization Detection Data Requirements

| Signal | Source | Computation |
|--------|--------|-------------|
| CTL slope (4-week trend) | `WorkloadSnapshot.chronicLoad` | Linear regression over 28-day window |
| Volume trend | `WorkoutSession.totalVolume` weekly aggregates | Week-over-week delta |
| Intensity trend | `WorkoutSession.sessionRPE` weekly average | Week-over-week delta |
| TSB direction | `WorkloadSnapshot.tsb` | Slope over 14-day window |

Phase classification rules:
- **Accumulation:** CTL rising, volume rising, TSB declining
- **Intensification:** CTL rising, volume flat/dropping, RPE rising
- **Deload:** CTL dropping, volume dropping, TSB rising
- **Peaking:** CTL stable/slight drop, TSB rising sharply, volume very low
- **Maintenance:** CTL flat, volume flat

Minimum data requirement: 4 weeks of consistent training (at least 3 sessions/week) for meaningful detection. The engine must return `.insufficientData` if this threshold is not met.

### Fatigue Correlation Data Requirements

| Signal | Source | Window |
|--------|--------|--------|
| Recovery score drops | `RecoverySnapshot.recoveryScore` | 1-3 day lag after training spike |
| Training spikes | `WorkloadSnapshot.acuteLoad` or session TSS | Same-day and prior 3 days |
| HRV suppression | `RecoverySnapshot.hrvSDNN` vs `hrvBaseline` | Morning after heavy session |
| Sleep disruption | `RecoverySnapshot.sleepDurationMinutes` | Night of heavy session |

The engine identifies recurring patterns: "When your acute load exceeds X, your recovery score drops by Y within Z days." This is a correlation analysis, not causal -- the UI must communicate this clearly.

## Patterns to Follow

### Pattern 1: Pure Struct Engine (established)

**What:** Stateless computation with static methods, taking model data in, returning typed results out.
**When:** All new analytics computation.
**Why:** Every existing engine (WorkloadCalculator, RecoveryScoreEngine, PRDetector) follows this pattern. It enables unit testing without mocking SwiftData, HealthKit, or Supabase.

```swift
struct WeeklySummaryEngine {
    struct WeeklySummary {
        let weekStartDate: Date
        let sessionCount: Int
        let totalVolume: Double
        let totalTrainingStress: Double
        let averageRPE: Double?
        let averageRecoveryScore: Double?
        let loadDeltaPercent: Double?   // vs prior week
        let sportDistribution: [SportType: Int]
        let restDays: Int
    }

    static func compute(
        sessions: [WorkoutSession],
        workloadSnapshots: [WorkloadSnapshot],
        recoverySnapshots: [RecoverySnapshot],
        weeks: Int = 8
    ) -> [WeeklySummary] {
        // Group by ISO week, aggregate per group
    }
}
```

### Pattern 2: Pipeline Orchestration (established)

**What:** `@MainActor struct` with static methods that compose repository reads and engine calls.
**When:** The AnalyticsPipeline that feeds the AnalyticsViewModel.

```swift
@MainActor
struct AnalyticsPipeline {
    struct AnalyticsResult {
        let weeklySummaries: [WeeklySummaryEngine.WeeklySummary]
        let detectedPhases: [PeriodizationEngine.TrainingPhase]
        let fatiguePatterns: [FatigueCorrelationEngine.FatiguePattern]
        let dateRange: ClosedRange<Date>
    }

    static func run(
        athlete: Athlete,
        modelContext: ModelContext,
        weeks: Int = 8
    ) throws -> AnalyticsResult {
        // 1. Fetch data from repositories
        // 2. Run engines
        // 3. Return composite result
    }
}
```

### Pattern 3: Observable ViewModel (established)

**What:** `@MainActor @Observable final class` exposing computed state to views.
**When:** The AnalyticsViewModel driving the analytics tab/view.

```swift
@MainActor
@Observable
final class AnalyticsViewModel {
    var weeklySummaries: [WeeklySummaryEngine.WeeklySummary] = []
    var detectedPhases: [PeriodizationEngine.TrainingPhase] = []
    var fatiguePatterns: [FatigueCorrelationEngine.FatiguePattern] = []
    var isLoading = true
    var selectedWeeks: Int = 8

    func load(athlete: Athlete, modelContext: ModelContext) {
        isLoading = true
        // Call AnalyticsPipeline.run()
        isLoading = false
    }
}
```

### Pattern 4: Export as Static Service (new, minimal)

**What:** A service struct that transforms analytics data into shareable file formats.
**When:** PDF report generation and CSV export.
**Why:** Export is a pure data transformation (analytics result -> document). No persistence, no state.

```swift
@MainActor
struct ExportService {
    static func generateWeeklyReportPDF(
        athlete: Athlete,
        analytics: AnalyticsPipeline.AnalyticsResult,
        sessions: [WorkoutSession]
    ) -> Data {
        // UIGraphicsPDFRenderer for structured PDF
    }

    static func generateSessionsCSV(
        sessions: [WorkoutSession],
        dateRange: ClosedRange<Date>
    ) -> String {
        // Standard CSV with headers
    }

    static func generateSnapshotsCSV(
        workloadSnapshots: [WorkloadSnapshot],
        recoverySnapshots: [RecoverySnapshot]
    ) -> String {
        // Daily snapshot CSV for external analysis
    }
}
```

## Anti-Patterns to Avoid

### Anti-Pattern 1: Analytics Writing Back to Snapshots
**What:** Storing computed analytics (weekly summaries, detected phases) as new SwiftData models.
**Why bad:** Adds write complexity, sync concerns, migration burden. Analytics are derived data -- recompute on demand.
**Instead:** Compute in-memory from existing snapshots. Cache in ViewModel properties only. The data volume (8-12 weeks of daily snapshots) is trivially small for on-device computation.

### Anti-Pattern 2: Async Engines
**What:** Making analytics engines async because they process "a lot" of data.
**Why bad:** The actual data volume is tiny (56 daily snapshots for 8 weeks, maybe 200 sessions). Async adds complexity for no benefit. Existing engines are synchronous for the same reason.
**Instead:** Keep engines synchronous (pure struct, static methods). Only the pipeline needs to be callable from async context (to match ViewModel patterns), but the computation itself is synchronous.

### Anti-Pattern 3: Single Monolithic Analytics View
**What:** One massive view showing all analytics at once.
**Why bad:** Overwhelming UX, poor performance on first render, violates progressive disclosure.
**Instead:** Section-based layout: Weekly Summary card (always shown) -> Periodization section (if sufficient data) -> Fatigue Patterns (if patterns detected). Use NavigationLink for drill-down detail.

### Anti-Pattern 4: PDF Generation Blocking Main Thread
**What:** Generating PDF inline in a button action without background dispatch.
**Why bad:** PDF rendering with charts can take 500ms+ and freeze the UI.
**Instead:** Use `Task { }` with a loading indicator. PDFKit and UIGraphicsPDFRenderer are safe to use on main actor since they are UIKit-based, but wrap in a Task to keep the UI responsive.

### Anti-Pattern 5: Mixing Export Logic into ViewModels
**What:** Putting CSV string building or PDF rendering inside AnalyticsViewModel.
**Why bad:** Violates separation of concerns, makes ViewModel harder to test.
**Instead:** ExportService as a separate static struct. ViewModel calls it, receives Data/String, presents share sheet.

## Component Dependency Graph

```
Views (AnalyticsView, WeeklySummaryCard, PeriodizationView, ExportSheet)
  |
  v
AnalyticsViewModel
  |
  v
AnalyticsPipeline -----> ExportService
  |                           |
  +-- WeeklySummaryEngine     +-- UIGraphicsPDFRenderer (Apple)
  +-- PeriodizationEngine     +-- CSV string builder
  +-- FatigueCorrelationEngine
  |
  v
Repositories (existing: WorkoutRepository, WorkloadRepository, RecoveryRepository)
  |
  v
Models (existing: WorkoutSession, WorkloadSnapshot, RecoverySnapshot, Athlete)
```

No new models. No new repositories (though WorkloadRepository and WorkoutRepository need additional fetch methods for date-range queries). No new infrastructure services.

## Suggested Build Order

Build order is determined by data dependencies and testability:

### Phase 1: Weekly Summaries (foundation)
**Build:** WeeklySummaryEngine -> AnalyticsPipeline (summaries only) -> AnalyticsViewModel -> WeeklySummaryView
**Rationale:** Weekly summaries are the simplest analytics feature, require only existing data, and establish the AnalyticsPipeline pattern that periodization and fatigue analysis will plug into. This gives users immediate value while building infrastructure for the harder features.
**Dependencies:** None beyond existing repositories.
**Repository changes:** Add `WorkoutRepository.fetchSessions(in dateRange: ClosedRange<Date>)` for bounded queries.

### Phase 2: Data Export (high user value, low complexity)
**Build:** ExportService (CSV first, then PDF) -> ExportSheet (UIActivityViewController wrapper)
**Rationale:** CSV export is trivial (string concatenation). PDF requires UIGraphicsPDFRenderer but the layout is straightforward (tables + summary stats). Export depends on AnalyticsPipeline result for the PDF report, but CSV can work from raw sessions alone.
**Dependencies:** WeeklySummaryEngine (for PDF report content). CSV export has no analytics dependency.

### Phase 3: Periodization Detection
**Build:** PeriodizationEngine -> wire into AnalyticsPipeline -> PeriodizationView
**Rationale:** Requires the most historical data (4+ weeks minimum) and has the highest risk of producing meaningless results for new users. Building it after weekly summaries means the pipeline infrastructure exists and the view layer pattern is established.
**Dependencies:** AnalyticsPipeline (from Phase 1).

### Phase 4: Fatigue Correlation
**Build:** FatigueCorrelationEngine -> wire into AnalyticsPipeline -> FatiguePatternsView
**Rationale:** Most complex analytically (lag correlation, pattern recognition). Needs substantial historical data to produce meaningful results. Building last means all simpler features are shipping while this is developed.
**Dependencies:** AnalyticsPipeline (from Phase 1).

### Phase 5: Onboarding Improvements
**Build:** Sport preference capture during signup -> first-run guidance overlay -> contextual empty states
**Rationale:** Onboarding is independent of analytics features. It can be built in parallel or after. The PROJECT.md states "depth-first post-launch" -- analytics before onboarding polish. Building it last also means the analytics views exist, so the onboarding can guide users toward them.
**Dependencies:** None (touches Athlete model + AuthService flow).

## Scalability Considerations

| Concern | Current Scale (weeks) | At 6 Months | At 2 Years |
|---------|----------------------|-------------|------------|
| Snapshot query volume | ~56 rows (8 weeks) | ~180 rows | ~730 rows |
| Session query volume | ~100 sessions | ~300 sessions | ~1000 sessions |
| Computation time | <10ms | <50ms | <200ms |
| PDF generation | Instant | <500ms | <1s |
| CSV file size | <50KB | <200KB | <1MB |

All analytics computation stays well within on-device performance budgets even at 2-year scale. No need for background processing, caching layers, or pagination for the foreseeable future. If a user somehow logs 10,000+ sessions, the repository fetch methods already support date-range filtering, so the query window stays bounded.

## Technology Choices for Export

### PDF Generation: UIGraphicsPDFRenderer (Apple built-in)
Use Apple's native PDF renderer rather than a third-party library. It supports:
- Custom page layouts with Core Graphics drawing
- Text rendering with attributed strings (DM Sans font)
- Simple charts via manual drawing or embedding Swift Charts as images

Do NOT use a web-based PDF approach (rendering HTML in WKWebView). It adds async complexity, web view lifecycle management, and is fragile for structured reports.

### CSV Generation: String concatenation
CSV is trivial -- no library needed. Use `String` building with proper escaping (quotes around fields containing commas). Encode as UTF-8 with BOM for Excel compatibility.

### Share Sheet: UIActivityViewController via SwiftUI
Wrap `UIActivityViewController` in a `UIViewControllerRepresentable` for the share sheet. Pass `URL` for saved temp file (better than raw Data for large exports).

## Sources

- Codebase analysis: WorkloadCalculator.swift, WorkoutPipeline.swift, RecoveryPipeline.swift, RecoveryScoreEngine.swift, DashboardViewModel.swift, WorkloadRepository.swift, RecoveryRepository.swift, WorkoutRepository.swift
- Architecture patterns derived from existing codebase conventions (CLAUDE.md, .planning/codebase/ARCHITECTURE.md)
- EWMA/ACWR methodology already implemented in WorkloadCalculator.swift
- Periodization detection approach based on established sports science (CTL slope classification)

---

*Architecture research: 2026-04-20*
