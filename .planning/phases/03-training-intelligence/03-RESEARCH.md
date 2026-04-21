# Phase 3: Training Intelligence - Research

**Researched:** 2026-04-21
**Domain:** On-device training analytics (periodization detection, fatigue pattern correlation, behavior tagging)
**Confidence:** HIGH

## Summary

Phase 3 adds three intelligence features to Tonus: (1) periodization detection that classifies the athlete's current training phase from load history, (2) fatigue pattern analysis that correlates recovery dips with training load spikes, and (3) behavior tagging that lets users tag daily behaviors and see recovery impact percentages. All computation is on-device using pure Swift engines -- no ML frameworks, no server-side processing.

The existing codebase provides strong foundations: `WorkloadCalculator` already computes EWMA ATL/CTL/TSB, `AnalyticsEngine` computes weekly summaries, `ReasoningEngine` generates natural language factor explanations, and `WellnessCheckIn` already captures daily wellness data that behavior tags will extend. Three new pure engines (`PeriodizationEngine`, `FatiguePatternEngine`, `BehaviorCorrelationEngine`) follow the established pattern of structs with static methods.

**Primary recommendation:** Build three pure computation engines first, then integrate into existing ViewModels and Views. The data model change (behavior tags on WellnessCheckIn) is the only schema migration risk -- use a new `BehaviorTag` model with a relationship to WellnessCheckIn rather than extending the existing model with a JSON blob.

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Training phase label (Building / Pushing / Tapering) appears as a subtitle under the readiness score number on the Dashboard hero card -- minimal UI, always visible, consistent with DESIGN.md accent-on-score-only rule
- **D-02:** Phase transitions update silently -- label changes without notification or animation, user notices on next Dashboard visit
- **D-03:** Behavior tags are added to the existing WellnessCheckIn flow as toggle chips -- no new entry points, slots naturally into the daily check-in the user already does
- **D-04:** Ship with 4 default behavior tags: caffeine, alcohol, travel, stress
- **D-05:** Pro users can create custom behavior tags (e.g. 'night shift', 'menstrual cycle') -- custom tag management gated behind isPro subscription check
- **D-06:** Fatigue insights presented as natural language cards -- plain-English summaries like "Recovery typically drops 2 days after high-volume upper body sessions." Follows existing ReasoningEngine pattern
- **D-07:** Insights section lives on the Recovery tab below current recovery details -- new 'Insights' section with scrollable list of insight cards
- **D-08:** When data is insufficient (<8 weeks for periodization, <5 tagged days for behavior correlation), show a circular progress ring + week counter with encouraging text: "Keep logging -- periodization insights unlock after 8 weeks of consistent training"
- **D-09:** Behavior correlation waits for full statistical threshold (5+ yes AND 5+ no samples per tag) before showing any results -- prevents misleading correlations from small samples. Shows "X more tagged days needed" until threshold met

### Claude's Discretion
- Periodization detection algorithm design (which signals define Building/Pushing/Tapering, rolling window size, sensitivity)
- Fatigue pattern detection algorithm (correlation method, minimum sample size, significance threshold)
- Insight card design details (icon, color coding, ordering, max cards shown)
- Custom tag management UI (how to add/edit/delete custom tags within wellness check-in)
- Behavior tag data model (extend WellnessCheckIn vs separate BehaviorTag entity)
- Progress ring visual style and placement relative to readiness subtitle

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.

</user_constraints>

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| INTEL-01 | Training block detection -- auto-detect accumulation, intensification, deload phases from volume/intensity trends over rolling 3-4 week windows | PeriodizationEngine algorithm design using existing WorkloadSnapshot ATL/CTL/TSB + WorkoutSession volume/intensity data |
| INTEL-02 | Periodization display on dashboard showing current detected phase with plain-language labels | Dashboard hero card subtitle integration (D-01), silent updates (D-02) |
| INTEL-03 | Data sufficiency gate -- show empty state when insufficient data for periodization detection (minimum 8 weeks, 3+ sessions/week) | Progress ring component with week counter (D-08) |
| INTEL-04 | Fatigue pattern detection -- identify recurring recovery dips correlated with training load spikes at the individual level | FatiguePatternEngine using RecoverySnapshot + WorkloadSnapshot time-series correlation |
| INTEL-05 | Fatigue insights displayed as human-readable patterns | Natural language card generation following ReasoningEngine.Factor pattern (D-06, D-07) |
| INTEL-06 | Behavior tagging -- user can tag daily behaviors | BehaviorTag model + MorningCheckInSheet toggle chip extension (D-03, D-04) |
| INTEL-07 | Behavior correlation -- after sufficient data, show recovery impact percentage | BehaviorCorrelationEngine with statistical threshold gating (D-09) |

</phase_requirements>

## Project Constraints (from CLAUDE.md)

- **Platform:** iOS 17+ only, SwiftUI + SwiftData
- **Architecture:** Views -> ViewModels (@Observable) -> Pipeline Services -> Engines (pure structs) -> Repositories -> Models (@Model)
- **Engines:** Pure structs with static methods, no state, no dependencies
- **Design system:** 0pt border radius, no shadows, DM Sans Regular + Medium only, 8pt grid spacing, accent color ONLY on hero readiness score number
- **Font:** `Font.custom("DMSans-Regular/Medium", size:)` only -- no `.system()` or semantic styles
- **Colors:** All via `ColorTokens` enum -- never hardcode hex
- **HealthKit:** Raw data never leaves device -- only composite scores sync to Supabase
- **Subscription gating:** Via `container.subscriptionService.isPro`
- **Incremental build verification:** Every 3-5 files, run xcodebuild check

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Periodization detection algorithm | Engine (pure struct) | -- | Stateless computation from WorkloadSnapshot history; follows WorkloadCalculator pattern |
| Periodization display | View (Dashboard) | ViewModel (DashboardViewModel) | Label rendered in HeroReadinessCard, state managed in ViewModel |
| Data sufficiency gate | Engine + ViewModel | View | Engine computes sufficiency metrics, ViewModel exposes state, View renders progress ring |
| Fatigue pattern detection | Engine (pure struct) | -- | Correlation analysis on RecoverySnapshot + WorkloadSnapshot arrays |
| Fatigue insight display | View (Recovery tab) | ViewModel (RecoveryViewModel) | New InsightsSection in RecoveryView, insight cards managed by ViewModel |
| Behavior tagging data model | Model (@Model) | Repository | New BehaviorTag SwiftData model with CRUD repository |
| Behavior tag UI | View (MorningCheckInSheet) | -- | Toggle chips added to existing check-in flow |
| Behavior correlation | Engine (pure struct) | -- | Statistical comparison of recovery scores with/without tag presence |
| Custom tag management | View | ViewModel | Pro-gated UI within check-in flow for add/edit/delete |

## Standard Stack

### Core (already in project)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 17+ | UI framework | Project standard, already used everywhere |
| SwiftData | iOS 17+ | Persistence | Project ORM, all models use @Model |
| Charts (Apple) | iOS 17+ | Data visualization | Already used in WorkloadView for trend charts |

### No Additional Dependencies Required

This phase uses zero external libraries. All computation is pure Swift math (EWMA analysis, mean comparison, Pearson correlation). The existing project stack covers every need:
- **Statistical computation:** Simple enough for hand-rolled Swift (mean, standard deviation, correlation coefficient)
- **Progress ring:** SwiftUI `Circle().trim()` -- trivial to build, no library needed
- **Toggle chips:** SwiftUI `HStack` with `ForEach` -- standard pattern

## Architecture Patterns

### System Architecture Diagram

```
[Dashboard load / Recovery load / Check-in save]
         |                    |              |
         v                    v              v
  DashboardViewModel    RecoveryViewModel    MorningCheckInSheet
         |                    |              |
         |  +-----------------+              |
         |  |                                |
         v  v                                v
  PeriodizationEngine              BehaviorTag model
  FatiguePatternEngine             (persisted to SwiftData)
  BehaviorCorrelationEngine                |
         |                                 v
         |                     BehaviorCorrelationEngine
         |                                 |
         v                                 v
  WorkloadSnapshot[]              RecoverySnapshot[]
  RecoverySnapshot[]              WellnessCheckIn[] + BehaviorTag[]
  WorkoutSession[]
         |
         v
  SwiftData (local) --> SyncService --> Supabase
```

### Recommended Project Structure (new files only)

```
WorkloadApp/
├── Models/
│   └── BehaviorTag.swift           # @Model for daily behavior tags
├── Services/
│   ├── PeriodizationEngine.swift   # Pure struct: training phase detection
│   ├── FatiguePatternEngine.swift  # Pure struct: recovery-load correlation
│   └── BehaviorCorrelationEngine.swift  # Pure struct: tag vs recovery impact
├── Repositories/
│   └── BehaviorTagRepository.swift # CRUD for behavior tags
├── Views/
│   └── Recovery/
│       └── InsightCard.swift       # Reusable insight card component
└── Components/
    ├── DataSufficiencyRing.swift   # Circular progress ring + week counter
    └── BehaviorTagChip.swift       # Toggle chip for behavior tagging
```

### Pattern 1: Pure Engine with Static Methods

**What:** All three new engines follow the project's established engine pattern -- pure structs with static methods, no state, no dependencies.
**When to use:** Always, for any computation logic.
**Example:**

```swift
// Source: Follows existing ReasoningEngine / WorkloadCalculator pattern [VERIFIED: codebase]
struct PeriodizationEngine {

    enum TrainingPhase: String {
        case building    // Volume increasing, intensity stable/moderate
        case pushing     // Intensity increasing, volume stable/decreasing
        case tapering    // Both volume and intensity decreasing
        case maintaining // Stable load, no clear trend
    }

    struct PhaseResult {
        let phase: TrainingPhase
        let confidence: Double    // 0-1
        let weeksSinceTransition: Int
        let label: String         // "Building" / "Pushing" / "Tapering"
    }

    struct SufficiencyResult {
        let isSufficient: Bool
        let weeksAvailable: Int
        let weeksRequired: Int      // 8
        let sessionsPerWeek: Double
        let minimumSessionsPerWeek: Double  // 3.0
    }

    static func detectPhase(
        workloadSnapshots: [WorkloadSnapshot],
        sessions: [WorkoutSession]
    ) -> PhaseResult? { ... }

    static func checkSufficiency(
        workloadSnapshots: [WorkloadSnapshot],
        sessions: [WorkoutSession]
    ) -> SufficiencyResult { ... }
}
```

### Pattern 2: Behavior Tag Data Model

**What:** Separate `@Model` entity linked to `WellnessCheckIn` via relationship, rather than embedding JSON in WellnessCheckIn.
**When to use:** For behavior tag storage.
**Rationale:** A separate model allows querying tags independently (needed for correlation engine), supports custom tags cleanly, and avoids schema migration complexity on the existing WellnessCheckIn table. [ASSUMED]

```swift
// New model
@Model
final class BehaviorTag {
    @Attribute(.unique) var id: UUID
    var date: Date
    var tagName: String          // "caffeine", "alcohol", "travel", "stress", or custom
    var isActive: Bool           // true = user toggled this tag ON for this day
    var isCustom: Bool           // false for the 4 defaults, true for Pro custom tags
    var updatedAt: Date

    var wellnessCheckIn: WellnessCheckIn?
    var athlete: Athlete?

    init(
        id: UUID = UUID(),
        date: Date = .now,
        tagName: String,
        isActive: Bool = true,
        isCustom: Bool = false
    ) {
        self.id = id
        self.date = date
        self.tagName = tagName
        self.isActive = isActive
        self.isCustom = isCustom
        self.updatedAt = .now
    }
}
```

**Schema registration required:** Add `BehaviorTag.self` to the Schema array in `WorkloadApp.swift`. [VERIFIED: codebase -- WorkloadApp.swift line 22-38]

**Relationship on WellnessCheckIn:** Add `@Relationship(deleteRule: .cascade, inverse: \BehaviorTag.wellnessCheckIn) var behaviorTags: [BehaviorTag] = []`

**Relationship on Athlete:** Add `@Relationship(deleteRule: .cascade, inverse: \BehaviorTag.athlete) var behaviorTags: [BehaviorTag] = []`

### Pattern 3: Toggle Chip UI in Check-in Flow

**What:** Behavior tags rendered as tappable chips in the MorningCheckInSheet between the wellness sliders and the notes field.
**When to use:** D-03 integration point.

```swift
// Source: Follows DESIGN.md 0pt radius, hairline border pattern [VERIFIED: codebase]
struct BehaviorTagChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.Tokens.label)
                .foregroundStyle(isSelected ? ColorTokens.text1 : ColorTokens.text2)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? ColorTokens.surface : ColorTokens.background)
                .overlay(
                    Rectangle()
                        .stroke(isSelected ? ColorTokens.text2 : ColorTokens.divider, lineWidth: 0.5)
                )
        }
    }
}
```

### Pattern 4: Data Sufficiency Progress Ring

**What:** Circular progress indicator for gating intelligence features behind minimum data thresholds.
**When to use:** INTEL-03 (periodization gate), INTEL-07 (behavior correlation gate).

```swift
// Source: SwiftUI Circle().trim() standard pattern [ASSUMED]
struct DataSufficiencyRing: View {
    let progress: Double   // 0.0 to 1.0
    let label: String      // "3 of 8 weeks"
    let message: String    // "Keep logging -- periodization insights unlock after 8 weeks"

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(ColorTokens.divider, lineWidth: 2)
                    .frame(width: 48, height: 48)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(ColorTokens.text2, lineWidth: 2)
                    .frame(width: 48, height: 48)
                    .rotationEffect(.degrees(-90))
            }
            Text(label)
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text1)
            Text(message)
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text2)
                .multilineTextAlignment(.center)
        }
        .padding(16)
    }
}
```

### Anti-Patterns to Avoid

- **Embedding computation in ViewModels:** Periodization/fatigue/correlation logic MUST live in pure engines, not in DashboardViewModel or RecoveryViewModel. ViewModels only call engines and expose results.
- **Using accent color for phase labels:** D-01 says label appears as subtitle -- it must use `ColorTokens.text2`, NOT `ColorTokens.accent` (accent is reserved for the score number only per DESIGN.md).
- **Showing correlations with insufficient data:** D-09 explicitly requires 5+ yes AND 5+ no samples. Never show partial correlations or placeholder values.
- **Adding rounded corners to chips/cards:** DESIGN.md mandates 0pt radius everywhere. Use `Rectangle()`, never `RoundedRectangle`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Progress ring | Custom Canvas/Path drawing | `Circle().trim(from:to:)` | SwiftUI has a one-liner for this |
| Supabase sync for new model | Custom REST calls | Extend existing SyncService push/pull pattern | SyncService already handles 8+ model types with the same upsert pattern |
| Date range queries | Manual date math | Existing repository fetch patterns (fetchSnapshots(from:to:)) | RecoveryRepository and WorkloadRepository already have these |

**Key insight:** This phase is primarily algorithmic -- the hard part is getting the detection/correlation math right, not the infrastructure. Every infrastructure piece (data layer, sync, UI patterns, subscription gating) already exists in the codebase.

## Common Pitfalls

### Pitfall 1: Periodization Detection False Positives on Rest Weeks
**What goes wrong:** A single rest week (vacation, illness) gets classified as "Tapering" when it's actually a break.
**Why it happens:** Looking at volume trend alone without considering session frequency.
**How to avoid:** Require minimum session count within the analysis window. If sessions/week drops below 2, output "Insufficient recent data" rather than a phase label.
**Warning signs:** Phase label changes rapidly between visits.

### Pitfall 2: Correlation Confusion with Behavior Tags
**What goes wrong:** Showing "Caffeine improves recovery by 8%" when the correlation is actually driven by confounders (caffeine correlates with non-training days).
**Why it happens:** Naive mean comparison without controlling for load context.
**How to avoid:** Compare recovery scores on matched load days (similar ATL/CTL) with and without the tag. At minimum, mention this is a correlation, not causation, in the insight text.
**Warning signs:** All behavior tags show implausibly large effects.

### Pitfall 3: SwiftData Migration Crash
**What goes wrong:** Adding `BehaviorTag` as a new model causes SwiftData to fail on existing installations because the schema doesn't match the persistent store.
**Why it happens:** SwiftData lightweight migration handles new models automatically, BUT only if the model is purely additive (new entity, not modifying existing entities).
**How to avoid:** Adding a new `BehaviorTag` entity is safe for lightweight migration. Adding the `behaviorTags` relationship to `WellnessCheckIn` and `Athlete` requires default values (`= []`). This is a known-safe pattern for SwiftData. [ASSUMED -- verify with a migration test on a real device with existing data]
**Warning signs:** App crashes on launch after update for existing users.

### Pitfall 4: Accent Color Leaking to Phase Labels
**What goes wrong:** Developer uses `ColorTokens.accent` for the phase label, breaking the design system rule that accent appears ONLY on the hero score number.
**Why it happens:** Natural instinct to highlight the new feature.
**How to avoid:** Phase label uses `ColorTokens.text2` (D-01 says "minimal UI"). Enforce in code review.
**Warning signs:** Visual diff shows color on subtitle.

### Pitfall 5: Insufficient Data UX Feels Broken
**What goes wrong:** New users see empty sections everywhere with no explanation, think the app is broken.
**Why it happens:** Intelligence features need 8+ weeks of data. Most users won't have this at launch.
**How to avoid:** D-08 specifies progress ring + encouraging text. Make this the PRIMARY experience for new users -- it should feel like a feature being unlocked, not a missing feature.
**Warning signs:** Low retention for new users who see empty intelligence sections.

## Code Examples

### PeriodizationEngine: Phase Detection Algorithm

```swift
// Source: Algorithm design based on sports science periodization principles [ASSUMED]
// Key signals: volume trend (weekly total volume), intensity trend (avg RPE), load trend (CTL change)
struct PeriodizationEngine {

    enum TrainingPhase: String, Codable {
        case building    // "Building" -- accumulation
        case pushing     // "Pushing" -- intensification
        case tapering    // "Tapering" -- deload/taper
        case maintaining // "Maintaining" -- no clear phase
    }

    struct PhaseResult {
        let phase: TrainingPhase
        let confidence: Double
        let label: String

        var displayLabel: String {
            switch phase {
            case .building:    return "Building"
            case .pushing:     return "Pushing"
            case .tapering:    return "Tapering"
            case .maintaining: return "Maintaining"
            }
        }
    }

    struct SufficiencyResult {
        let isSufficient: Bool
        let weeksAvailable: Int
        let weeksRequired: Int
        let avgSessionsPerWeek: Double
    }

    /// Check if athlete has enough data for periodization detection.
    /// Requires 8+ weeks of history with 3+ sessions/week average.
    static func checkSufficiency(
        sessions: [WorkoutSession],
        minimumWeeks: Int = 8,
        minimumSessionsPerWeek: Double = 3.0
    ) -> SufficiencyResult {
        let calendar = Calendar.current
        guard let earliest = sessions.min(by: { $0.sessionDate < $1.sessionDate })?.sessionDate else {
            return SufficiencyResult(isSufficient: false, weeksAvailable: 0,
                                     weeksRequired: minimumWeeks, avgSessionsPerWeek: 0)
        }
        let weeks = calendar.dateComponents([.weekOfYear], from: earliest, to: .now).weekOfYear ?? 0
        let avgPerWeek = weeks > 0 ? Double(sessions.count) / Double(weeks) : 0
        return SufficiencyResult(
            isSufficient: weeks >= minimumWeeks && avgPerWeek >= minimumSessionsPerWeek,
            weeksAvailable: weeks,
            weeksRequired: minimumWeeks,
            avgSessionsPerWeek: avgPerWeek
        )
    }

    /// Detect current training phase from rolling 3-4 week windows.
    /// Compares recent 3-week block to previous 3-week block.
    static func detectPhase(
        workloadSnapshots: [WorkloadSnapshot],
        sessions: [WorkoutSession],
        windowWeeks: Int = 3
    ) -> PhaseResult? {
        // Implementation: compute weekly volume and intensity for recent vs previous window
        // Compare slopes to classify phase
        // Building: volume +10%, intensity stable or +5%
        // Pushing: intensity +10%, volume stable or -5%
        // Tapering: both volume and intensity -10% or more
        // Maintaining: neither trend exceeds thresholds
        // ... (pure computation, no side effects)
        return nil // placeholder
    }
}
```

### FatiguePatternEngine: Recovery-Load Correlation

```swift
// Source: Algorithm design for lag-correlation analysis [ASSUMED]
struct FatiguePatternEngine {

    struct Insight {
        let text: String          // "Recovery typically drops 2 days after high-volume sessions"
        let confidence: Double    // 0-1
        let sampleSize: Int
    }

    /// Identify recurring patterns where recovery dips follow training load spikes.
    /// Looks at 1-3 day lag between high load days and recovery score changes.
    static func detectPatterns(
        workloadSnapshots: [WorkloadSnapshot],
        recoverySnapshots: [RecoverySnapshot],
        sessions: [WorkoutSession],
        minimumSamples: Int = 5
    ) -> [Insight] {
        // Algorithm:
        // 1. Identify "high load" days (TSS > 1.5x rolling average)
        // 2. For each lag (1, 2, 3 days), check average recovery delta after high load
        // 3. Compare to recovery delta on non-high-load days
        // 4. If difference is statistically meaningful (>5 points, 5+ samples), generate insight
        // 5. Generate natural language: "Recovery typically drops [X] points [N] days after [context]"
        return []
    }
}
```

### BehaviorCorrelationEngine: Tag Impact Analysis

```swift
// Source: Simple independent samples mean comparison [ASSUMED]
struct BehaviorCorrelationEngine {

    struct TagCorrelation {
        let tagName: String
        let recoveryWithTag: Double      // mean recovery score on days with tag
        let recoveryWithoutTag: Double   // mean recovery score on days without tag
        let impactPercentage: Double     // (with - without) / without * 100
        let sampleCountWith: Int
        let sampleCountWithout: Int
        let isSufficient: Bool           // both counts >= 5
    }

    struct SufficiencyInfo {
        let tagName: String
        let daysWithTag: Int
        let daysWithoutTag: Int
        let neededWith: Int     // max(0, 5 - daysWithTag)
        let neededWithout: Int  // max(0, 5 - daysWithoutTag)
    }

    /// Compute recovery impact for each behavior tag.
    static func computeCorrelations(
        tags: [BehaviorTag],
        recoverySnapshots: [RecoverySnapshot],
        minimumSamplesPerGroup: Int = 5
    ) -> [TagCorrelation] {
        // Group tags by name
        // For each tag: partition days into "tag active" and "tag not active"
        // Match to recovery scores by date
        // Compute mean difference
        // Only return results where both groups have 5+ samples
        return []
    }

    /// Check how close each tag is to having sufficient data.
    static func checkSufficiency(
        tags: [BehaviorTag],
        minimumSamplesPerGroup: Int = 5
    ) -> [SufficiencyInfo] {
        return []
    }
}
```

### Dashboard Integration: Phase Label Subtitle

```swift
// Source: HeroReadinessCard integration point [VERIFIED: codebase DashboardView.swift line 127-131]
// Add BELOW the readiness score number, ABOVE the reasoning factors divider:
if viewModel.hasRealData {
    Text("\(Int(viewModel.recoveryScore))")
        .font(.Tokens.heroScore)
        .monospacedDigit()
        .foregroundStyle(ColorTokens.accent)

    // NEW: Phase label (D-01)
    if let phaseLabel = viewModel.trainingPhaseLabel {
        Text(phaseLabel)
            .font(.Tokens.label)
            .foregroundStyle(ColorTokens.text2)
    } else if let sufficiency = viewModel.periodizationSufficiency, !sufficiency.isSufficient {
        // Data sufficiency indicator (D-08)
        DataSufficiencyRing(
            progress: Double(sufficiency.weeksAvailable) / Double(sufficiency.weeksRequired),
            label: "\(sufficiency.weeksAvailable) of \(sufficiency.weeksRequired) weeks",
            message: "Keep logging -- periodization insights unlock after \(sufficiency.weeksRequired) weeks of consistent training"
        )
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Rule-based periodization detection | Same (rule-based) | Current | ML-based detection exists in research but requires large datasets; rule-based is appropriate for individual athlete with 8-12 weeks of data |
| Pearson correlation for behavior impact | Mean comparison with threshold | Current | Pearson requires continuous variables; behavior tags are binary, so independent samples t-test or simple mean comparison is more appropriate |

**Deprecated/outdated:**
- None applicable -- this is all custom domain logic, not library-dependent.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Separate BehaviorTag model is better than extending WellnessCheckIn with JSON | Architecture Patterns, Pattern 2 | Low -- either approach works, but separate model is cleaner for querying |
| A2 | SwiftData lightweight migration handles new entity + new relationship with default value safely | Pitfall 3 | HIGH -- if migration fails, existing users crash on update. Must test on device with existing data |
| A3 | Building/Pushing/Tapering/Maintaining are the right phase labels for general athletes | Code Examples | Medium -- endurance athletes use different terminology (base/build/peak/taper). Current labels work for strength-focused users |
| A4 | 3-week rolling window is appropriate for phase detection | Code Examples | Low -- 3-4 weeks is standard mesocycle length in periodization literature |
| A5 | Simple mean comparison (not t-test) is sufficient for behavior correlation | Code Examples | Low -- with small samples (5-20), a full t-test adds complexity without meaningful benefit. The insight text already frames results as correlational |
| A6 | Circle().trim() progress ring renders correctly for the DESIGN.md aesthetic | Pattern 4 | Low -- standard SwiftUI, but verify it matches the 0pt radius / no shadow / hairline aesthetic |

## Open Questions (RESOLVED)

1. **Supabase schema for BehaviorTag** (RESOLVED)
   - What we know: SyncService uses upsert pattern with Row structs for all models. BehaviorTag needs the same.
   - Resolution: Plan 03-01 Task 1 includes the SQL migration script to create the `behavior_tags` table in Supabase with RLS policy (`athlete_id = auth.uid()::uuid`). The executor presents the SQL to the user for execution in the Supabase Dashboard SQL Editor before testing sync. Table schema: id UUID PK, athlete_id UUID FK, date TIMESTAMPTZ, tag_name TEXT, is_active BOOL, is_custom BOOL, created_at TIMESTAMPTZ, updated_at TIMESTAMPTZ.

2. **Phase label for non-lifting sports** (RESOLVED)
   - What we know: Periodization terminology varies by sport. "Building" makes sense for strength athletes.
   - Resolution: Use "Building / Pushing / Tapering / Maintaining" labels for v1. These are generic enough for all sport types. Revisit if user feedback indicates confusion. No code change needed now.

3. **Behavior tag sync to coach** (RESOLVED)
   - What we know: Coaches can view athlete data via SyncService.
   - Resolution: Yes -- behavior tags sync to Supabase the same as WellnessCheckIn. The RLS policy uses `athlete_id = auth.uid()::uuid` which means coaches access tags through the existing coach data access pattern (same as how they access WellnessCheckIn data today). No additional coach-specific sync logic needed.

## Environment Availability

Step 2.6: SKIPPED -- this phase is purely code/config changes with no new external dependencies. All required frameworks (SwiftUI, SwiftData, Charts) are already in the project.

## Sources

### Primary (HIGH confidence)
- Codebase analysis: WorkloadCalculator.swift, ReasoningEngine.swift, AnalyticsEngine.swift, RecoveryScoreEngine.swift -- verified engine patterns, data flow, and available signals
- Codebase analysis: WellnessCheckIn.swift, MorningCheckInSheet.swift -- verified current check-in model and UI
- Codebase analysis: DashboardView.swift, DashboardViewModel.swift -- verified hero card structure and ViewModel load pattern
- Codebase analysis: RecoveryView.swift, RecoveryViewModel.swift -- verified recovery tab structure
- Codebase analysis: WorkloadApp.swift -- verified schema registration pattern
- Codebase analysis: SyncService.swift -- verified sync pattern for new models
- DESIGN.md -- verified color tokens, typography, 0pt radius, accent-only-on-score rule

### Secondary (MEDIUM confidence)
- Sports science periodization principles: mesocycle detection based on volume/intensity trends [ASSUMED from domain knowledge]
- Statistical correlation methods for binary variables with small samples [ASSUMED from domain knowledge]

### Tertiary (LOW confidence)
- None

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- no new dependencies, all existing frameworks
- Architecture: HIGH -- follows 100% established codebase patterns (pure engines, @Observable ViewModels, SwiftData models)
- Algorithm design: MEDIUM -- periodization detection and correlation algorithms are sound in principle but thresholds need tuning with real user data
- Pitfalls: HIGH -- SwiftData migration risk (A2) is the only high-risk item and is easily testable

**Research date:** 2026-04-21
**Valid until:** 2026-05-21 (stable -- no external dependency changes expected)
