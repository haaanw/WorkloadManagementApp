# Phase 17: Cycle Data Foundation - Research

**Researched:** 2026-05-14
**Domain:** Apple HealthKit menstrual cycle data integration, SwiftData modeling, cycle phase estimation
**Confidence:** HIGH

## Summary

Phase 17 adds zero-friction menstrual cycle data reading from HealthKit, a new `MenstrualCycleSnapshot` SwiftData model for daily cycle state, a `CycleTrackingService` that computes cycle day and estimated phase with confidence scoring, and a "Cycle & Hormones" section in ProfileView for contraceptive/pregnancy/lactation toggles. The phase is entirely a data foundation -- no algorithm modifications, no dashboard UI changes, no Supabase sync of menstrual data.

The implementation slots cleanly into existing patterns: `HealthKitService.readTypes` gains 6 new category types, `Athlete` model gains 3 optional Bool fields (synced via existing `pushAthlete`), `MenstrualCycleSnapshot` follows the `RecoverySnapshot` one-row-per-day pattern, and `CycleTrackingService` follows the `@MainActor final class` service pattern. The `CyclePhase` estimation algorithm uses day-counting from period starts as the primary method, with wrist temperature biphasic shift as an optional confidence booster.

**Primary recommendation:** Build in three layers: (1) HealthKit data reading + new types in `readTypes`, (2) `MenstrualCycleSnapshot` model + `CycleTrackingService` with phase estimation, (3) Athlete model fields + ProfileView "Cycle & Hormones" section. Keep `CycleContext` struct minimal -- it is consumed by Phase 18, not this phase.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Bundle menstrual data types (`.menstrualFlow`, `.contraceptive`, `.pregnancy`, `.lactation`, `.irregularMenstrualCycles`, `.ovulationTestResult`) into the existing `readTypes` set in `HealthKitService`. One permission sheet covers everything -- no separate menstrual-specific auth flow.
- **D-02:** If user declines menstrual permissions (or HealthKit returns no menstrual data), show a one-time soft prompt on Dashboard explaining cycle-aware benefits with a link to Settings to re-enable. Then never ask again. All cycle features remain invisible otherwise.
- **D-03:** Add a "Cycle & Hormones" section in `ProfileView` below the existing Training Profile section. Contains contraceptive status picker and pregnancy/lactation toggles. Section visible only after HealthKit menstrual permissions are granted (or menstrual data exists).
- **D-04:** Simple binary contraceptive model: "Hormonal contraceptive: Yes/No". All hormonal methods flatten the cycle similarly enough. OC users skip all phase-based adjustments downstream.
- **D-05:** Show phase info on Dashboard after 1 complete cycle (2 logged period starts in HealthKit). Low bar to deliver value quickly.
- **D-07:** Contraceptive status and exclusion flags (pregnancy, lactation) live on the `Athlete` model as optional fields: `isOnHormonalContraceptive: Bool`, `isPregnant: Bool`, `isLactating: Bool`. Syncs to Supabase with existing Athlete sync.
- **D-08:** `MenstrualCycleSnapshot` is a new `@Model` with one row per day. Fields: date, cycleDay, estimatedPhase (CyclePhase enum), confidence, cycleLength, wristTempDeviation, flowIntensity, isCycleStart, exclusionFlags.
- **D-09:** `CycleContext` is a lightweight struct (not @Model) that `CycleTrackingService` produces and passes to downstream engines.
- **D-10:** `CyclePhase` enum: earlyFollicular, lateFollicular, ovulatory, earlyLuteal, lateLuteal, unknown.
- **D-11:** `CycleTrackingService` is a `@MainActor final class` (stateful -- needs HealthKit store access).
- **D-12:** Raw menstrual data never syncs to Supabase. `MenstrualCycleSnapshot` is local-only -- no Supabase table, no sync.

### Claude's Discretion
- Irregular cycle handling strategy (D-06) -- pick best approach for Phase 18 compatibility
- CyclePhase estimation algorithm details (day-count vs temperature-confirmed)
- Wrist temperature biphasic shift detection thresholds

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CYCLE-01 | Read menstrual cycle data from HealthKit (menstrual flow, ovulation tests, contraceptive, pregnancy, lactation, irregular cycles, wrist temp) | HealthKit API verification (Section 5 of research doc), `readTypes` extension pattern, `HKMetadataKeyMenstrualCycleStart` for cycle start detection |
| CYCLE-02 | MenstrualCycleSnapshot model stores daily cycle state with confidence scoring | RecoverySnapshot pattern (one-row-per-day @Model), CyclePhase enum, confidence algorithm design |
| CYCLE-03 | CycleContext struct provides phase estimation with exclusion flags for downstream engines | Lightweight struct pattern, exclusion flag logic for contraceptive/pregnancy/lactation users |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| HealthKit menstrual data reading | iOS Client (HealthKitService) | -- | HealthKit is device-local API only |
| Cycle phase estimation | iOS Client (CycleTrackingService) | -- | Pure computation from local data |
| MenstrualCycleSnapshot persistence | iOS Client (SwiftData) | -- | Local-only, never syncs (D-12) |
| Contraceptive/pregnancy/lactation flags | iOS Client (Athlete model) | Supabase (sync) | Athlete-level state syncs via existing pushAthlete |
| ProfileView "Cycle & Hormones" UI | iOS Client (SwiftUI) | -- | Standard profile section pattern |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| HealthKit | iOS 17+ SDK | Read menstrual flow, contraceptive, pregnancy, lactation, irregular cycles, ovulation test, wrist temp | Apple's only API for health data; already used in app [VERIFIED: existing HealthKitService.swift] |
| SwiftData | iOS 17+ SDK | MenstrualCycleSnapshot model persistence | Already used for all models in app [VERIFIED: WorkloadApp.swift schema] |
| SwiftUI | iOS 17+ SDK | ProfileView "Cycle & Hormones" section | Already used for all views [VERIFIED: ProfileView.swift] |

### Supporting
No new dependencies required. This phase uses only Apple frameworks already in the project.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Reading HealthKit directly | Third-party cycle tracking SDK | Unnecessary dependency; HealthKit provides all needed data types natively |
| Day-count phase estimation | Apple's internal cycle prediction | Apple does not expose predicted phase/ovulation via public API [CITED: research doc Section 5.3] |

## Architecture Patterns

### System Architecture Diagram

```
                    HealthKit Store
                         |
                    [HK Queries]
                         |
                         v
    HealthKitService.readTypes  <-- add 6 new category types (D-01)
         |                  |
    [menstrualFlow      [wristTemp
     contraceptive       (already
     pregnancy           in readTypes)]
     lactation
     irregularCycles
     ovulationTest]
         |                  |
         v                  v
    CycleTrackingService (@MainActor final class)
         |
         |-- fetchCycleHistory() --> [HKCategorySample] with metadata
         |-- computeCycleDay(from: periodStarts) --> Int?
         |-- estimatePhase(cycleDay:, cycleLength:) --> CyclePhase
         |-- detectBiphasicShift(tempHistory:) --> Date? (optional confidence boost)
         |
         v
    MenstrualCycleSnapshot (@Model, local-only)
         |-- date, cycleDay, estimatedPhase, confidence
         |-- cycleLength, wristTempDeviation, flowIntensity
         |-- isCycleStart, exclusionFlags
         |
         v
    CycleContext (struct, passed to engines in Phase 18)
         |-- phase, confidence, cycleDay, exclusionFlags

    Athlete model <-- add isOnHormonalContraceptive, isPregnant, isLactating
         |
    AthleteRow/SyncService <-- add new fields to pushAthlete
         |
    Supabase athletes table <-- add columns (migration)
```

### Recommended Project Structure
```
WorkloadApp/
├── Models/
│   ├── MenstrualCycleSnapshot.swift    # New @Model (CYCLE-02)
│   └── Enums.swift                     # Add CyclePhase enum (D-10)
├── Services/
│   ├── CycleTrackingService.swift      # New service (CYCLE-01, D-11)
│   └── HealthKitService.swift          # Extend readTypes (D-01)
├── Views/
│   └── Profile/
│       └── ProfileView.swift           # Add "Cycle & Hormones" section (D-03)
└── App/
    └── WorkloadApp.swift               # Register MenstrualCycleSnapshot in schema
```

### Pattern 1: HealthKit Category Sample Fetch with Metadata
**What:** Fetching `.menstrualFlow` samples requires reading `HKMetadataKeyMenstrualCycleStart` to distinguish period starts from mid-cycle flow days.
**When to use:** Every time cycle data is refreshed.
**Example:**
```swift
// Source: Apple Developer Documentation — HKMetadataKeyMenstrualCycleStart
func fetchMenstrualFlowHistory(days: Int) async throws -> [(date: Date, flow: HKCategoryValueMenstrualFlow, isCycleStart: Bool)] {
    let type = HKCategoryType(.menstrualFlow)
    let startDate = Calendar.current.date(byAdding: .day, value: -days, to: .now)!
    let predicate = HKQuery.predicateForSamples(withStart: startDate, end: .now, options: .strictStartDate)

    let descriptor = HKSampleQueryDescriptor(
        predicates: [.categorySample(type: type, predicate: predicate)],
        sortDescriptors: [SortDescriptor(\.startDate)]
    )

    let samples = try await descriptor.result(for: store)
    return samples.map { sample in
        let flow = HKCategoryValueMenstrualFlow(rawValue: sample.value) ?? .unspecified
        let isCycleStart = (sample.metadata?[HKMetadataKeyMenstrualCycleStart] as? Bool) ?? false
        return (date: sample.startDate, flow: flow, isCycleStart: isCycleStart)
    }
}
```
[VERIFIED: Apple Developer Documentation — HKMetadataKeyMenstrualCycleStart, HKCategoryValueMenstrualFlow]

### Pattern 2: CyclePhase Day-Count Estimation
**What:** Estimate cycle phase from cycle day using standard phase boundaries, scaled to individual cycle length.
**When to use:** Core phase estimation when wrist temperature is unavailable.
**Example:**
```swift
// Source: Research doc Section 2.1 (phase day ranges) + D-10 (enum)
static func estimatePhase(cycleDay: Int, cycleLength: Int) -> CyclePhase {
    // Scale phase boundaries to individual cycle length
    // Standard 28-day boundaries: follicular 1-5, late follicular 6-13, ovulatory ~14, early luteal 15-21, late luteal 22-28
    // Luteal phase is relatively fixed at ~14 days; follicular varies
    let follicularLength = cycleLength - 14  // variable part
    let menstruationEnd = 5  // relatively fixed
    let ovulationDay = follicularLength  // ~day before luteal
    let lutealStart = ovulationDay + 1

    switch cycleDay {
    case 1...menstruationEnd:
        return .earlyFollicular
    case (menstruationEnd + 1)..<ovulationDay:
        return .lateFollicular
    case ovulationDay...(ovulationDay + 1):
        return .ovulatory
    case lutealStart...(lutealStart + 6):
        return .earlyLuteal
    default:
        return .lateLuteal
    }
}
```
[ASSUMED — phase boundary scaling is a standard approach in reproductive endocrinology but exact cutoffs are approximations]

### Pattern 3: One-Row-Per-Day SwiftData Model (RecoverySnapshot Pattern)
**What:** MenstrualCycleSnapshot follows the same daily upsert pattern as RecoverySnapshot.
**When to use:** Daily snapshot persistence.
**Example:**
```swift
// Source: Existing RecoverySnapshot pattern in codebase
@Model
final class MenstrualCycleSnapshot {
    @Attribute(.unique) var id: UUID
    var date: Date
    var cycleDay: Int?
    var estimatedPhase: CyclePhase?
    var confidence: Double  // 0.0 to 1.0
    var cycleLength: Int?
    var wristTempDeviation: Double?
    var flowIntensity: Int?  // HKCategoryValueMenstrualFlow raw value
    var isCycleStart: Bool
    var isOnHormonalContraceptive: Bool
    var isPregnant: Bool
    var isLactating: Bool
    var updatedAt: Date

    var athlete: Athlete?
    // ... init
}
```
[VERIFIED: RecoverySnapshot.swift pattern in codebase]

### Anti-Patterns to Avoid
- **Syncing raw menstrual data to Supabase:** D-12 explicitly forbids this. Only derivative values (cycle phase, cycle day) may influence algorithms. MenstrualCycleSnapshot has no SyncService integration.
- **Creating a separate menstrual HealthKit permission flow:** D-01 bundles all types into the existing `readTypes` set. One permission sheet.
- **Using HKCategoryValueContraceptive for contraceptive status:** D-04 simplifies to a binary Bool on Athlete. HealthKit's `.contraceptive` type has granular subtypes (IUD, implant, injection, etc.) but the decision is to not differentiate -- all hormonal methods are treated identically.
- **Modeling contraceptive status per-snapshot:** D-07 explicitly places these on the Athlete model, not MenstrualCycleSnapshot. They are athlete-level states.
- **Phase estimation without minimum data:** D-05 requires 2 logged period starts (1 complete cycle) before showing phase info. Guard against showing phase with only 1 period start.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Menstrual data reading | Custom tracking UI or manual date picker | HealthKit `.menstrualFlow` with `HKMetadataKeyMenstrualCycleStart` | Zero friction -- reads data users already log in Apple Health, Clue, Flo, etc. |
| Ovulation detection | Complex BBT charting algorithm | Apple wrist temperature deviation + simple biphasic shift detection | Apple Watch already computes wrist temp deviation from personal baseline |
| Cycle irregularity detection | Custom variability analysis | HealthKit `.irregularMenstrualCycles` | Apple computes this automatically from logged cycle data |
| Pregnancy/lactation tracking | Custom reproductive status system | HealthKit `.pregnancy` + `.lactation` + Athlete model Bools | Apple Health already tracks these states |

**Key insight:** The entire premise of this phase is "don't hand-roll cycle tracking." Users already track cycles in Apple Health or third-party apps that sync to HealthKit. Tonus reads that data via HealthKit -- zero re-entry.

## Common Pitfalls

### Pitfall 1: HealthKit Authorization Status Ambiguity
**What goes wrong:** `HKHealthStore.authorizationStatus(for:)` returns `.sharingDenied` both when the user explicitly denied permission AND when the user has never been asked. You cannot distinguish "denied" from "not determined" for read-only types.
**Why it happens:** Apple privacy design -- apps cannot know if a user chose not to share specific health data types.
**How to avoid:** Never branch logic on authorization status for individual types. Instead, always attempt to fetch data. If the fetch returns empty results, treat it as "no data available" regardless of the reason. For the D-02 soft prompt, use a UserDefaults flag (`hasShownCycleDataPrompt`) rather than checking authorization status.
**Warning signs:** Code that calls `authorizationStatus(for: .menstrualFlow)` and tries to distinguish denial from absence.
[CITED: Apple Developer Documentation -- HKHealthStore authorization behavior for read types]

### Pitfall 2: Missing HKMetadataKeyMenstrualCycleStart Metadata
**What goes wrong:** Not all third-party apps populate `HKMetadataKeyMenstrualCycleStart` correctly. Some write `.menstrualFlow` samples without the metadata key, or set it to `true` on every flow day instead of just the first.
**Why it happens:** Third-party apps (Clue, Flo, etc.) may implement HealthKit integration inconsistently.
**How to avoid:** Fall back to gap-based cycle start detection: if there is no `isCycleStart: true` metadata, treat a `.menstrualFlow` sample that follows a gap of 14+ days without flow as a cycle start. This handles both correct metadata and missing metadata.
**Warning signs:** Tests that only work with Apple Cycle Tracking data but fail with Clue/Flo data.
[ASSUMED -- based on common HealthKit integration issues reported in developer forums]

### Pitfall 3: Cycle Length Calculation with Irregular Data
**What goes wrong:** Using the gap between the first flow day and the next first flow day gives cycle length, but users with irregular cycles may have lengths of 21-60+ days. Averaging all cycles naively produces misleading "typical" cycle lengths.
**Why it happens:** Irregular cycles, missed logging, stress, travel, perimenopause all cause cycle length variation.
**How to avoid:** Use the median of the last 3-6 cycles (not mean) for cycle length estimation. If cycle lengths vary by more than 7 days, flag the user as irregular and reduce confidence. For D-06 (Claude's Discretion): show phase with a LOW confidence flag for irregular users -- this gives Phase 18 enough data to attempt same-phase baselines while signaling uncertainty. Phase 18 baselines fall back to 7-day rolling for irregular users anyway.
**Warning signs:** Tests that only use perfectly regular 28-day cycles.
[ASSUMED -- standard statistical approach for irregular time series data]

### Pitfall 4: SwiftData Migration When Adding MenstrualCycleSnapshot
**What goes wrong:** Adding a new @Model to the schema array in `WorkloadApp.swift` without handling existing installs. If the new model has required non-optional fields without defaults, existing users crash on launch.
**Why it happens:** SwiftData performs lightweight migration automatically for additive changes, but only if all new fields have defaults or are optional.
**How to avoid:** Ensure all fields in `MenstrualCycleSnapshot` are either optional or have default values in the init. The model is new (no existing rows), so the only migration concern is schema registration. SwiftData handles adding a new entity automatically.
**Warning signs:** Non-optional fields without defaults in the @Model init.
[VERIFIED: existing SwiftData migration behavior in codebase -- BehaviorTag, TrainingProfile were added in later phases without migration issues]

### Pitfall 5: Wrist Temperature Availability
**What goes wrong:** Assuming all users have wrist temperature data. `.appleSleepingWristTemperature` requires Apple Watch Series 8+ with 2+ months of nightly wear.
**Why it happens:** Many users have older Apple Watches, or don't wear them to sleep, or haven't used them long enough.
**How to avoid:** Treat wrist temperature as an optional confidence booster, never a requirement. Phase estimation must work with flow data alone. The existing `HealthKitService` already guards wrist temp with `if let wristTemp = HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature)`.
**Warning signs:** Phase estimation that requires wrist temp data to produce any result.
[VERIFIED: existing HealthKitService.swift wrist temp guard pattern]

## Code Examples

### CyclePhase Enum (D-10)
```swift
// Source: CONTEXT.md D-10
enum CyclePhase: String, Codable, CaseIterable, Identifiable {
    case earlyFollicular
    case lateFollicular
    case ovulatory
    case earlyLuteal
    case lateLuteal
    case unknown

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .earlyFollicular: "Early Follicular"
        case .lateFollicular: "Late Follicular"
        case .ovulatory: "Ovulatory"
        case .earlyLuteal: "Early Luteal"
        case .lateLuteal: "Late Luteal"
        case .unknown: "Unknown"
        }
    }
}
```
[VERIFIED: follows existing enum pattern in Enums.swift -- String, Codable, CaseIterable, Identifiable, displayName]

### CycleContext Struct (D-09)
```swift
// Source: CONTEXT.md D-09
struct CycleContext {
    let phase: CyclePhase
    let confidence: Double       // 0.0 to 1.0
    let cycleDay: Int?
    let cycleLength: Int?
    let isOnHormonalContraceptive: Bool
    let isPregnant: Bool
    let isLactating: Bool

    /// True when any exclusion flag is set -- downstream engines should skip phase-based adjustments
    var hasExclusion: Bool {
        isOnHormonalContraceptive || isPregnant || isLactating
    }

    /// Convenience: returns nil context when no cycle data is available
    static let none = CycleContext(
        phase: .unknown, confidence: 0, cycleDay: nil, cycleLength: nil,
        isOnHormonalContraceptive: false, isPregnant: false, isLactating: false
    )
}
```
[VERIFIED: follows existing lightweight struct patterns in codebase]

### Confidence Scoring Algorithm
```swift
// Source: Claude's Discretion -- algorithm design
static func computeConfidence(
    completedCycles: Int,
    cycleLengthCV: Double,  // coefficient of variation of cycle lengths
    hasWristTempConfirmation: Bool
) -> Double {
    var confidence = 0.0

    // Base: need at least 1 complete cycle (D-05)
    guard completedCycles >= 1 else { return 0.0 }

    // 1 cycle = 0.4, 2 = 0.6, 3+ = 0.7 (more data = higher confidence)
    switch completedCycles {
    case 1: confidence = 0.4
    case 2: confidence = 0.6
    default: confidence = 0.7
    }

    // Regularity bonus/penalty: CV < 0.10 = regular, > 0.20 = irregular
    if cycleLengthCV < 0.10 {
        confidence += 0.15
    } else if cycleLengthCV > 0.20 {
        confidence -= 0.20
    }

    // Wrist temp confirmation: +0.15 if biphasic shift detected
    if hasWristTempConfirmation {
        confidence += 0.15
    }

    return max(0.0, min(1.0, confidence))
}
```
[ASSUMED -- confidence scoring thresholds are designed for this use case, not from literature]

### Athlete Model Extension (D-07)
```swift
// Source: CONTEXT.md D-07, existing Athlete.swift pattern
// Add to Athlete model:
var isOnHormonalContraceptive: Bool?
var isPregnant: Bool?
var isLactating: Bool?
```
[VERIFIED: follows existing optional Bool pattern on Athlete (e.g., isCoach)]

### AthleteRow Sync Extension (D-07)
```swift
// Source: CONTEXT.md D-07, existing SyncService AthleteRow pattern
// Add to AthleteRow struct:
let isOnHormonalContraceptive: Bool?
let isPregnant: Bool?
let isLactating: Bool?
```
[VERIFIED: follows existing AthleteRow field pattern in SyncService.swift]

### Biphasic Shift Detection (Claude's Discretion)
```swift
// Source: Research doc Section 5.2, Claude's Discretion
/// Detect post-ovulation temperature rise from wrist temp deviation history.
/// Returns the estimated ovulation date if a biphasic shift is found.
static func detectBiphasicShift(tempHistory: [(date: Date, deviation: Double)]) -> Date? {
    // Need at least 10 days of temp data
    guard tempHistory.count >= 10 else { return nil }

    let sorted = tempHistory.sorted { $0.date < $1.date }

    // Sliding window: compare 5-day follicular mean vs 5-day luteal mean
    // Look for a sustained rise of >= 0.2 degrees C
    for i in 5..<(sorted.count - 4) {
        let preMean = sorted[(i-5)..<i].map(\.deviation).reduce(0, +) / 5.0
        let postMean = sorted[i..<(i+5)].map(\.deviation).reduce(0, +) / 5.0

        if postMean - preMean >= 0.2 {
            return sorted[i].date  // Estimated ovulation day
        }
    }
    return nil
}
```
[ASSUMED -- threshold of 0.2 degrees C based on research doc Section 5.2 stating "0.2-0.5 degrees C" biphasic shift; exact detection algorithm is custom]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Phase-deterministic training (Sims ROAR 2016) | Readiness-first + cycle context (Sims 2025 evolution) | 2025 | Cycle phase is metadata, not override -- validates Tonus's readiness-first architecture |
| Calendar-only cycle prediction | Wrist temperature + HR for retrospective ovulation | Apple Watch Series 8 (2022), validated Human Reproduction 2025 | Passive ovulation detection available without user logging |
| Population-level phase adjustments | Individual within-person monitoring (Altini/HRV4Training) | 2024-2025 | Phase 18's same-phase baselines are the correct approach, not group averages |

**Deprecated/outdated:**
- Rigid phase-based periodization (train strength only in follicular): Evidence does not support this as prescriptive. Use as soft context only.
- Assuming HRV cycle variation is uniform across women: Individual variation dwarfs population averages.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Third-party apps (Clue, Flo) may not populate HKMetadataKeyMenstrualCycleStart correctly | Pitfalls | Gap-based fallback would be unnecessary if all apps set metadata correctly; low risk |
| A2 | Phase boundary scaling (14-day fixed luteal, variable follicular) is standard | Architecture Patterns | Phase estimates could be systematically wrong for women with short/long luteal phases; mitigated by confidence scoring |
| A3 | Confidence scoring thresholds (0.4/0.6/0.7 for 1/2/3+ cycles) | Code Examples | Thresholds may need tuning but are conservative starting points; can be adjusted in Phase 18 |
| A4 | Biphasic shift detection threshold of 0.2 degrees C | Code Examples | May miss subtle shifts or false-positive on noisy data; mitigated by treating as optional confidence booster |
| A5 | Median cycle length is better than mean for irregular users | Pitfalls | Statistical choice; median is standard for skewed distributions, low risk |

## Open Questions

1. **Supabase athletes table migration for new fields**
   - What we know: D-07 adds `isOnHormonalContraceptive`, `isPregnant`, `isLactating` to Athlete, which syncs to Supabase via AthleteRow.
   - What's unclear: Need SQL migration to add these columns to the `athletes` table in Supabase.
   - Recommendation: Add nullable boolean columns with `ALTER TABLE athletes ADD COLUMN is_on_hormonal_contraceptive BOOLEAN;` (and similar for pregnancy/lactation). Nullable columns require no default and no backfill.

2. **D-02 soft prompt timing and persistence**
   - What we know: One-time soft prompt on Dashboard when no menstrual data and permissions not granted.
   - What's unclear: Exact trigger conditions -- should it show on first app open after phase ships, or only after N sessions?
   - Recommendation: Show after the first recovery pipeline run post-update if no menstrual data exists. Store `hasShownCycleDataPrompt` in UserDefaults. This is a minor UI detail that can be decided during implementation.

3. **HealthKit background delivery for menstrual data**
   - What we know: Current app fetches HealthKit data on foreground (app launch, pipeline run).
   - What's unclear: Whether menstrual data should trigger background updates via `HKObserverQuery`.
   - Recommendation: Not needed for Phase 17. Menstrual data changes infrequently (monthly). Foreground fetch on app launch is sufficient. Background delivery can be added in Phase 18 if needed.

## Environment Availability

Step 2.6: SKIPPED (no external dependencies identified -- phase uses only Apple frameworks already in the project).

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | Existing auth unchanged |
| V3 Session Management | No | Existing session management unchanged |
| V4 Access Control | No | No new API endpoints |
| V5 Input Validation | Yes | Validate cycle day bounds (1-60), cycle length bounds (14-90), confidence bounds (0.0-1.0) |
| V6 Cryptography | No | No crypto operations |

### Known Threat Patterns for HealthKit Menstrual Data

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Menstrual data leaking to Supabase | Information Disclosure | D-12: MenstrualCycleSnapshot has no SyncService integration; code review must verify no sync paths |
| Contraceptive/pregnancy status visible to coach | Information Disclosure | These fields sync to Supabase (D-07) but are only visible in the user's own ProfileView; coach dashboard does not display them |
| HealthKit data over-collection | Information Disclosure | Request only specific types needed; never request write access |

## Sources

### Primary (HIGH confidence)
- Existing codebase: HealthKitService.swift, RecoverySnapshot.swift, Athlete.swift, ProfileView.swift, SyncService.swift, WorkloadApp.swift, Enums.swift, TrainingProfile.swift, RecoveryPipeline.swift
- [Apple Developer Documentation: HKMetadataKeyMenstrualCycleStart](https://developer.apple.com/documentation/healthkit/hkmetadatakeymenstrualcyclestart)
- [Apple Developer Documentation: HKCategoryTypeIdentifier.menstrualFlow](https://developer.apple.com/documentation/healthkit/hkcategorytypeidentifier/menstrualflow)
- [Apple Developer Documentation: HKCategoryTypeIdentifier.irregularMenstrualCycles](https://developer.apple.com/documentation/healthkit/hkcategorytypeidentifier/3951062-irregularmenstrualcycles)
- [Apple Developer Documentation: HKCategoryTypeIdentifier.contraceptive](https://developer.apple.com/documentation/healthkit/hkcategorytypeidentifier/3552048-contraceptive)
- [Apple Developer Documentation: HKCategoryTypeIdentifier.pregnancy](https://developer.apple.com/documentation/healthkit/hkcategorytypeidentifier/pregnancy)
- [Apple Developer Documentation: HKCategoryTypeIdentifier.lactation](https://developer.apple.com/documentation/healthkit/hkcategorytypeidentifier/3552063-lactation)
- `.planning/research/female-athlete-optimization-research.md` -- 697-line evidence base (Sections 2, 5, 9 most relevant)

### Secondary (MEDIUM confidence)
- [Apple Developer Forums: Menstrual cycle start metadata](https://developer.apple.com/forums/thread/749026)

### Tertiary (LOW confidence)
- Confidence scoring thresholds and biphasic shift detection algorithm are custom designs (tagged [ASSUMED] throughout)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all Apple frameworks, already in use, APIs verified
- Architecture: HIGH -- follows existing codebase patterns exactly (RecoverySnapshot, HealthKitService, Athlete model)
- Pitfalls: MEDIUM -- HealthKit authorization ambiguity and third-party metadata inconsistency are well-known but specific edge cases are hard to verify without device testing
- Phase estimation algorithm: MEDIUM -- day-count approach is standard but thresholds need tuning with real data

**Research date:** 2026-05-14
**Valid until:** 2026-06-14 (stable -- Apple HealthKit APIs change at WWDC annually, next WWDC June 2026)
