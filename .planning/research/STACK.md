# Technology Stack

**Project:** Tonus v1.2 - Training Onboarding & Templates
**Researched:** 2026-05-01

## Current Stack (Keep As-Is)

Already in the project. No changes needed for any of these.

| Technology | Purpose | Status |
|------------|---------|--------|
| SwiftUI + SwiftData | UI + persistence | Existing, keep |
| Swift Charts | Data visualization | Existing, keep |
| HealthKit | Biometric data + workout detection | Existing, keep |
| Supabase Swift SDK | Auth + sync | Existing, keep |
| RevenueCat | Subscriptions | Existing, keep |
| Accelerate (vDSP) | Vectorized math | Existing, keep |
| UserNotifications | Local push notifications | Existing, keep |
| MetricKit | Production telemetry | Existing, keep |
| ImageRenderer + UIGraphicsPDFRenderer | PDF reports | Existing, keep |

## New Stack Additions for v1.2

### Zero new SPM dependencies. Zero new Apple frameworks.

v1.2 requires no new libraries or framework imports. Every new capability is built from:

1. **New SwiftData models** (TrainingProfile) -- lightweight migration handles new @Model classes automatically
2. **New pure struct engines** (ColdStartEngine, TemplateSuggestionEngine) -- zero dependencies, pure computation
3. **Extensions to existing models** (WorkoutTemplate gains `ownerId` field, new template-ownership semantics)
4. **Extensions to existing services** (WorkoutPipeline gets parallel-track EWMA, SyncService gets new table sync)

This is the right call because the new features are **domain logic and data modeling**, not new technical capabilities. The existing stack already provides everything needed.

---

## Feature 1: Cold-Start Questionnaire & ATL/CTL Seeding

### What's Needed: New Model + Pure Engine

| Technology | Purpose | Why | Confidence |
|------------|---------|-----|------------|
| SwiftData `@Model` (TrainingProfile) | Store questionnaire answers + seeded values + bias tracking | Separate model keeps Athlete clean. Preserves raw answers for perceptual bias comparison at 8 weeks. One-to-one relationship with Athlete. | HIGH |
| Pure struct engine (ColdStartEngine) | Convert questionnaire answers to initial ATL/CTL estimates | Pure computation, no dependencies. Takes (sport, frequency, experience, avgSessionDuration, avgRPE, sessionsPerWeek) and returns (estimatedATL, estimatedCTL). Follows existing engine pattern. | HIGH |

**TrainingProfile Model Design:**

```swift
@Model
final class TrainingProfile {
    @Attribute(.unique) var id: UUID
    var athleteId: UUID

    // Raw questionnaire answers (preserved for bias measurement)
    var sportType: SportType
    var trainingFrequency: TrainingFrequency
    var experienceLevel: ExperienceLevel
    var sessionsPerWeek: Int            // Required Q: "How many sessions per week?"
    var avgSessionMinutes: Int?         // Optional Q: typical session duration
    var avgPerceivedIntensity: Double?  // Optional Q: typical RPE (1-10 scale)
    var bodyweightKg: Double?           // Optional Q: for load normalization
    var trainingAge: Int?               // Optional Q: years of structured training

    // Computed seeds from ColdStartEngine
    var seededATL: Double
    var seededCTL: Double
    var seededDate: Date                // When seeding happened

    // Bias tracking fields
    var estimatedWeeklyLoad: Double?    // Athlete's self-reported weekly load perception
    var actualWeeklyLoadAt8Weeks: Double? // Computed actual load after 8 weeks
    var biasRatio: Double?              // estimatedWeeklyLoad / actualWeeklyLoadAt8Weeks
    var biasMeasuredDate: Date?         // When bias was computed

    // Switchover tracking
    var hasRealDataTakeover: Bool       // True once real data replaces seeded values
    var realDataTakeoverDate: Date?     // When switchover happened

    var createdAt: Date
    var updatedAt: Date
}
```

**Why a standalone model (not Athlete properties):**
- Athlete model already has 20+ properties and 7 relationships. Adding 15+ questionnaire/bias fields would bloat it.
- Raw questionnaire answers must be preserved indefinitely for bias analysis. They are not "settings" that get updated.
- TrainingProfile has its own lifecycle (created once during onboarding, bias measured once at 8 weeks, switchover once at 3 weeks).
- Supabase sync is simpler with a separate `training_profiles` table than adding 15 nullable columns to `athletes`.

**ColdStartEngine Seeding Formula:**

The engine converts human-readable questionnaire answers into EWMA-compatible ATL/CTL seeds using the sRPE-based TSS formula that the app already uses:

```
TSS_per_session = (duration_hours) * RPE * (RPE / 10)
weekly_TSS = TSS_per_session * sessions_per_week
daily_TSS_avg = weekly_TSS / 7

seededCTL = daily_TSS_avg  (steady-state EWMA converges to daily average)
seededATL = daily_TSS_avg  (assume TSB = 0 at seed time)
```

Default RPE by experience level (when athlete skips the optional RPE question):
- Beginner: RPE 5 (moderate effort, learning movements)
- Intermediate: RPE 6.5 (established training habits, moderate-hard)
- Advanced: RPE 7.5 (structured periodized training, hard)

Default session duration by sport type (when athlete skips the optional duration question):
- Lifting: 60 min
- Running: 45 min
- Cycling: 75 min
- Swimming: 45 min
- CrossFit: 50 min
- Team Sport: 90 min
- Custom: 60 min

These defaults come from typical sRPE literature values. They produce CTL seeds that align with the TrainingPeaks CTL ranges validated in sport science: beginners ~15-30 CTL, intermediates ~30-60 CTL, advanced ~60-100+ CTL.

**Parallel Data Tracks (Estimated vs. Real):**

The WorkloadSnapshot model does NOT change. Instead, WorkoutPipeline is modified:

1. **Before switchover:** When computing EWMA after a session, the pipeline initializes EWMA with `previousATL = seededATL` and `previousCTL = seededCTL` instead of 0. This way seeded values bootstrap the EWMA warm-up period.
2. **Switchover threshold:** After 3 weeks AND 8+ sessions, real data has sufficient density for EWMA to stabilize. At this point, `hasRealDataTakeover = true` and the pipeline stops referencing seeded values.
3. **Bias measurement:** At 8 weeks, a background check in DashboardViewModel compares `estimatedWeeklyLoad` (from questionnaire: `TSS_per_session * sessions_per_week`) to actual computed weekly average load. The ratio is stored silently -- no UI surfacing in v1.2.

**What NOT to build:**
- No separate "estimated" WorkloadSnapshot model. The real snapshots are computed from real sessions; the seeds just bootstrap the EWMA starting point. One data track, not two parallel snapshot tables.
- No continuous bias recalibration. The single 8-week check is sufficient for v1.2. Continuous calibration needs longitudinal sRPE research (deferred to v1.3+).
- No ML model for seeding. The sRPE formula is deterministic and validated. An ML model would need training data we do not have.

### Integration Points

| Existing Component | Change Required |
|---------------------|-----------------|
| Athlete model | Add optional `@Relationship` to TrainingProfile (one-to-one) |
| OnboardingView | Extend from 3 steps to 7 steps (4 required + 3 optional + HealthKit) |
| WorkoutPipeline.processSession() | Initialize EWMA from seeded ATL/CTL when < 3 weeks of data |
| WorkloadCalculator.computeHistoryEWMA() | Add `initialATL`/`initialCTL` parameters (default 0 to preserve existing behavior) |
| DashboardViewModel.load() | At 8 weeks, compute bias ratio silently |
| SyncService | Add `training_profiles` table push/pull |
| Supabase schema | New `training_profiles` table with RLS |

### SwiftData Migration

Adding a new `TrainingProfile` model class is a **lightweight migration** in SwiftData. Adding a new model is one of the simplest schema changes SwiftData handles automatically. Adding an optional relationship property on Athlete (`var trainingProfile: TrainingProfile?`) is also lightweight.

Recommendation: Still define a `VersionedSchema` (V3 or whatever the current version is) for this change, because the project will continue evolving and having versioned schemas makes future complex migrations possible.

---

## Feature 2: Athlete-Owned Templates

### What's Needed: Model Extension + New Engine

| Technology | Purpose | Why | Confidence |
|------------|---------|-----|------------|
| WorkoutTemplate model (existing) | Reuse for athlete-owned templates | Already models the right structure: Template -> ExerciseGroup -> TemplateExercise -> TemplateSet. Adding an `ownerId` field + `ownerType` enum is cleaner than creating a parallel model hierarchy. | HIGH |
| Pure struct engine (TemplateSuggestionEngine) | Day-of-week and context-aware template ranking | Pure computation. Takes (templates, usage history, day of week, recovery context) and returns ranked suggestions. Same pattern as all other engines. | HIGH |
| ProgressionEngine (existing) | Dynamic target overlay for template sets | Already provides recovery-aware weight/rep suggestions per exercise. Template targets feed last-used values to ProgressionEngine for overlay. No changes to ProgressionEngine itself. | HIGH |

**WorkoutTemplate Model Changes:**

The existing `WorkoutTemplate` has `coachId: UUID` which assumes coach ownership. For athlete-owned templates, two options:

**Option A (Recommended): Add `ownerId: UUID` + `ownerType: TemplateOwnerType`**
```swift
// New enum
enum TemplateOwnerType: String, Codable {
    case coach
    case athlete
}

// Changes to WorkoutTemplate
var ownerId: UUID       // replaces coachId semantically
var ownerType: TemplateOwnerType
var isFavorite: Bool = false
var isArchived: Bool = false
var lastUsedDate: Date?
var useCount: Int = 0
var scheduledDays: [Int]? // 1=Sun...7=Sat, nil = no schedule
```

**Why Option A over a separate AthleteTemplate model:**
- Identical structure (groups, exercises, sets). Duplicating the model hierarchy would mean duplicating ExerciseGroup, TemplateExercise, TemplateSet relationships or adding more polymorphism.
- Coach templates already have the full structure. Adding `ownerType` is a field addition, not an architectural change.
- SyncService already knows how to sync WorkoutTemplate. Adding a filter on `ownerType` is trivial.
- Template sharing (v1.3) becomes natural: a shared template just changes `ownerId`/`ownerType`.

**Migration concern:** The `coachId` field is non-optional and existing templates all have it set. Approach:
1. Add `ownerId` and `ownerType` with defaults (ownerType defaults to `.coach`, ownerId defaults to coachId value).
2. Keep `coachId` as a computed property that returns `ownerId` when `ownerType == .coach`.
3. Or simply: rename `coachId` to `ownerId` in a VersionedSchema migration. This is a rename + default value addition, which SwiftData can handle as a custom migration.

**Recommendation:** Use the additive approach (add `ownerId` + `ownerType` with defaults, deprecate `coachId` over time). This avoids a custom migration and keeps existing coach template code working. The `coachId` property can become a computed alias.

**Save-From-Session Flow:**

When an athlete completes a workout and taps "Save as Template":
1. Create a new `WorkoutTemplate` with `ownerType = .athlete`, `ownerId = athlete.supabaseUserId`
2. Deep-copy the session's exercise structure into ExerciseGroup -> TemplateExercise -> TemplateSet
3. Use the session's actual weights/reps/durations as the initial template target values
4. Template name defaults to session name (editable)

This uses the existing `deepCopyGroups()` pattern on WorkoutTemplate, adapted from session ExerciseEntry structure.

**Template Selection UX Data Flow:**

Dashboard quick-start cards and the template picker need these queries:
- Favorite templates: `@Query` with `isFavorite == true && isArchived == false && ownerType == .athlete`
- Recently used: `@Query` sorted by `lastUsedDate` descending
- Suggested for today: TemplateSuggestionEngine result (see below)

**Dynamic Targets:**

When starting a workout from a template:
1. Load template's target sets (base values)
2. For each exercise, call `ProgressionEngine.suggest()` with the athlete's training history
3. Overlay ProgressionEngine suggestions onto template targets
4. Show both: template target (gray) and suggested target (primary text)
5. Pro-gated: free users see template targets only; Pro users see ProgressionEngine overlay

This requires NO changes to ProgressionEngine. The engine already accepts `exerciseName`, `category`, `context`, and `recentEntries` and returns `ExerciseSuggestion` with `SetSuggestion` values.

### TemplateSuggestionEngine Design

```swift
struct TemplateSuggestionEngine {

    struct SuggestionInput {
        let templates: [TemplateInfo]
        let usageHistory: [UsageRecord]  // (templateId, date, dayOfWeek)
        let currentDayOfWeek: Int        // 1=Sun...7=Sat
        let recoveryZone: RecoveryZone
        let fatigueZone: FatigueIndexEngine.FatigueZone
    }

    struct TemplateInfo {
        let id: UUID
        let name: String
        let sportType: SportType
        let sessionType: SessionType
        let isFavorite: Bool
        let scheduledDays: [Int]?
        let lastUsedDate: Date?
        let useCount: Int
    }

    struct UsageRecord {
        let templateId: UUID
        let date: Date
        let dayOfWeek: Int
    }

    struct RankedTemplate {
        let templateId: UUID
        let score: Double       // 0-1, higher = better match
        let reason: String      // "Scheduled for today", "You usually do this on Mondays"
    }

    static func rank(input: SuggestionInput) -> [RankedTemplate]
}
```

Scoring factors (weighted):
1. **Scheduled for today** (weight 0.40): If template has `scheduledDays` containing today's day, big boost. This is the primary scheduling mechanism.
2. **Day-of-week frequency** (weight 0.25): From usage history, compute P(template | dayOfWeek). Templates the athlete habitually does on this day of week get boosted.
3. **Recency penalty** (weight 0.15): Templates used in the last 24h get penalized (avoid suggesting the same workout back-to-back unless it is explicitly scheduled).
4. **Favorite boost** (weight 0.10): Favorites get a flat boost.
5. **Recovery-awareness** (weight 0.10): If recovery is red, deprioritize high-intensity templates (strength, HIIT) and boost recovery/cardio templates.

**Why build a custom engine instead of using a library:**
- The ranking logic is ~100 lines of weighted scoring. No library needed.
- Domain-specific scoring (recovery-aware, sport-type aware) would not be served by a generic recommendation library.
- Follows the project's pure struct engine pattern -- deterministic, testable, no dependencies.

---

## Feature 3: HealthKit Workout-Template Matching

### What's Needed: Extension to Existing WorkoutImportService

| Technology | Purpose | Why | Confidence |
|------------|---------|-----|------------|
| HealthKit HKWorkout (existing) | Detect external workouts | Already fetched by `WorkoutImportService.findUnmatchedWorkouts()`. No new HealthKit capabilities needed. | HIGH |
| WorkoutImportBanner (existing) | Show import suggestions with template matching | Extend the existing banner to suggest which template the detected workout likely maps to. | HIGH |

**Matching Algorithm:**

The existing `WorkoutImportSuggestion` already maps `HKWorkoutActivityType` to `SportType` and `SessionType`. Template matching adds one more layer:

```swift
extension WorkoutImportService {
    /// Find the best-matching template for a detected HealthKit workout
    static func matchTemplate(
        suggestion: WorkoutImportSuggestion,
        templates: [WorkoutTemplate],
        usageHistory: [(templateId: UUID, date: Date)]
    ) -> WorkoutTemplate? {
        // 1. Filter by sport type match
        // 2. Filter by session type match
        // 3. Among matches, prefer: scheduled for today > most frequently used > most recently used
        // 4. Return nil if no match (athlete logs manually)
    }
}
```

The matching is simple because `WorkoutImportSuggestion` already provides `sportType` and `sessionType`, and templates have the same fields. The match is:
- `suggestion.sportType == template.sportType` AND `suggestion.sessionType == template.sessionType`

When a match is found, the WorkoutImportBanner shows "Looks like your [Strength Training] -- use [Push Day A] template?" alongside the existing "Add" / "X" buttons.

**What NOT to build:**
- No exercise-level matching from HealthKit. HealthKit workouts from Apple Watch do not contain exercise names or sets -- only activity type, duration, calories, and HR. Exercise-level matching requires the Apple Watch companion app (out of scope).
- No automatic session creation from HealthKit. The existing manual-confirm flow (banner + RPE prompt) is correct for data quality. Auto-creating sessions without RPE would break the sRPE-based TSS calculation.

---

## Template Management Operations

Template management (edit, duplicate, archive, favorite, delete) requires no stack additions. These are CRUD operations on the existing SwiftData model:

| Operation | Implementation | Notes |
|-----------|----------------|-------|
| Edit | Update template properties in-place | Existing TemplateEditorSheet, adapted for athlete ownership |
| Duplicate | `template.deepCopyGroups()` into new template | Existing method on WorkoutTemplate |
| Archive | Set `isArchived = true` | New boolean field, filtered out of active queries |
| Favorite | Toggle `isFavorite` | New boolean field, used for quick-start cards |
| Delete | `modelContext.delete(template)` | Cascade deletes groups/exercises/sets |

---

## Full Stack Change Summary

### SwiftData Model Changes

| Model | Change | Migration |
|-------|--------|-----------|
| TrainingProfile (NEW) | New `@Model` class | Lightweight (new model) |
| Athlete | Add optional `trainingProfile: TrainingProfile?` relationship | Lightweight (new optional property) |
| WorkoutTemplate | Add `ownerId`, `ownerType`, `isFavorite`, `isArchived`, `lastUsedDate`, `useCount`, `scheduledDays` | Lightweight (new properties with defaults) |

### New Pure Engines

| Engine | Type | Responsibility |
|--------|------|----------------|
| ColdStartEngine | `struct` with static methods | Convert questionnaire answers to ATL/CTL seeds |
| TemplateSuggestionEngine | `struct` with static methods | Rank templates for today based on schedule, history, recovery |

### Modified Existing Components

| Component | Modification |
|-----------|--------------|
| WorkloadCalculator.computeHistoryEWMA() | Accept optional `initialATL`/`initialCTL` parameters |
| WorkoutPipeline.processSession() | Bootstrap EWMA from seeded values when real data is insufficient |
| WorkoutImportService | Add template matching to detected workouts |
| SyncService | Add `training_profiles` table sync; extend `workout_templates` sync with new fields |
| OnboardingView | Extend to include cold-start questionnaire steps |
| DashboardViewModel | Add template suggestion loading; add 8-week bias check |

### Supabase Schema Additions

| Table | Purpose |
|-------|---------|
| `training_profiles` | Store questionnaire answers + seeded values + bias tracking |
| `workout_templates` (alter) | Add `owner_id`, `owner_type`, `is_favorite`, `is_archived`, `last_used_date`, `use_count`, `scheduled_days` columns |

RLS policies:
- `training_profiles`: Read/write own profile only (`auth.uid() = user_id`)
- `workout_templates`: Athletes can CRUD their own templates (`owner_type = 'athlete' AND owner_id = auth.uid()`). Coach template policies remain unchanged.

### No New Enums

Existing enums cover all needs:
- `SportType`, `SessionType`, `ExerciseCategory`, `MuscleGroup` -- already complete
- `TrainingFrequency`, `ExperienceLevel` -- already exist in Enums.swift
- New: `TemplateOwnerType` (2 cases, trivial)

---

## SPM Dependencies (NO additions for v1.2)

```
https://github.com/supabase/supabase-swift     -- existing
https://github.com/RevenueCat/purchases-ios.git -- existing
```

## Apple Frameworks (NO new imports for v1.2)

```
SwiftUI              -- UI
SwiftData            -- Persistence (new models use existing framework)
Charts               -- Visualization
HealthKit            -- Biometrics + workout detection (existing usage)
Accelerate           -- Vectorized math
UserNotifications    -- Local push notifications
MetricKit            -- Production telemetry
UIKit                -- PDF rendering
UniformTypeIdentifiers -- File type declarations
```

Every new v1.2 capability is pure Swift + SwiftData. Zero new imports.

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Cold-start seeding | sRPE formula with questionnaire inputs | ML model from training data | No training dataset available; deterministic formula is validated by sport science literature and uses the same TSS formula the app already runs |
| Cold-start seeding | ColdStartEngine (pure struct) | TrainingPeaks API integration | Adds external dependency, requires user to have TP account, data format mismatch |
| Training profile storage | Standalone TrainingProfile model | Additional Athlete properties | Athlete model already has 20+ properties; lifecycle is different (write-once vs settings); Supabase sync cleaner with separate table |
| Parallel data tracks | Single EWMA track with seeded initial values | Two separate WorkloadSnapshot streams (estimated vs real) | Doubles storage/sync/query complexity for a transitional 3-week period; single track with bootstrapped start is mathematically equivalent |
| Template ownership | Extend WorkoutTemplate with ownerType | Separate AthleteTemplate model | Would duplicate 4 model classes (Template, Group, Exercise, Set) and all their sync logic; identical structure should use identical models |
| Template suggestions | TemplateSuggestionEngine (pure struct) | CoreML on-device model | Scoring logic is ~100 lines of weighted arithmetic; ML adds model training/maintenance burden for a simple ranking problem |
| Template suggestions | TemplateSuggestionEngine (pure struct) | Third-party recommendation library | No Swift recommendation library fits this domain; scoring is exercise-type and recovery-aware |
| HealthKit matching | SportType + SessionType match | Exercise-name fuzzy matching | HKWorkout from Apple Watch contains no exercise names; matching is limited to activity type |
| Dynamic targets | ProgressionEngine overlay (existing) | Separate template progression system | ProgressionEngine already computes recovery-aware suggestions per exercise; calling it per template exercise avoids duplicating logic |
| Bias measurement | Silent 8-week single check | Continuous rolling calibration | Needs research on longitudinal sRPE adjustment that does not exist yet; deferred to v1.3+ |
| Day-of-week scheduling | Array of weekday integers on template | Full calendar/recurring event system | YAGNI for v1.2; athletes need "I do Push on Mon/Thu", not iCal-level recurrence |

---

## What NOT to Add

These were considered and explicitly rejected:

| Technology | Why Not |
|------------|---------|
| CoreML / CreateML | No training data for seeding model; deterministic formula is sufficient and interpretable |
| Firebase Analytics | Already have MetricKit for production telemetry; adding Firebase SDK adds ~10MB and Google dependency |
| Full calendar framework (EventKit) | Template scheduling is day-of-week, not calendar events; EventKit is overkill |
| Background App Refresh | Not needed for template suggestions or bias checks; these run on foreground app launch |
| CloudKit | Already using Supabase; adding CloudKit creates two sync systems |
| Third-party form/survey library | Questionnaire is 4-8 questions with simple SwiftUI pickers; no library needed |
| Workout plan / periodization library | Template suggestions are simple ranking; periodization detection is already built |
| WidgetKit for template quick-start | Possible future enhancement but not v1.2 scope; requires separate widget extension target |

---

## Integration Checklist

Pre-implementation verification points:

- [ ] SwiftData ModelContainer schema includes TrainingProfile in model list
- [ ] VersionedSchema defined for migration (V2 -> V3 or appropriate version bump)
- [ ] WorkoutTemplate new properties have default values for lightweight migration
- [ ] Supabase `training_profiles` table created with RLS policies
- [ ] Supabase `workout_templates` table altered with new columns (nullable for existing rows)
- [ ] SyncService extended with training_profiles push/pull
- [ ] SyncService extended with new workout_templates fields
- [ ] ColdStartEngine unit tests cover all experience/frequency/sport combinations
- [ ] TemplateSuggestionEngine unit tests cover scheduling, recency, recovery-awareness
- [ ] WorkloadCalculator.computeHistoryEWMA() backward-compatible (default initialATL/CTL = 0)
- [ ] WorkoutPipeline.processSession() backward-compatible (no TrainingProfile = existing behavior)

## Sources

- [Apple SwiftData Schema Migration](https://developer.apple.com/forums/thread/738812) -- HIGH confidence (lightweight migration for new models confirmed)
- [SwiftData Lightweight vs Complex Migrations (Hacking with Swift)](https://www.hackingwithswift.com/quick-start/swiftdata/lightweight-vs-complex-migrations) -- HIGH confidence
- [TrainingPeaks: Estimate Starting Fitness (CTL)](https://help.trainingpeaks.com/hc/en-us/articles/230903988-Estimate-Starting-Fitness-CTL) -- MEDIUM confidence (formula validated but access restricted)
- [TrainingPeaks: Science of the Performance Manager](https://www.trainingpeaks.com/learn/articles/the-science-of-the-performance-manager/) -- HIGH confidence (EWMA cold-start seeding approach)
- [TrainingPeaks: Estimating Training Stress Score (TSS)](https://www.trainingpeaks.com/learn/articles/estimating-training-stress-score-tss/) -- HIGH confidence (sRPE-based TSS formula)
- [TrainingPeaks: Suggested Weekly TSS and Target CTL](https://help.trainingpeaks.com/hc/en-us/articles/230904648-Suggested-Weekly-TSS-and-Target-CTL) -- HIGH confidence (CTL ranges by athlete level)
- [HKWorkout Documentation](https://developer.apple.com/documentation/healthkit/hkworkout) -- HIGH confidence
- [HKWorkoutActivityType Documentation](https://developer.apple.com/documentation/healthkit/hkworkoutactivitytype) -- HIGH confidence
- [Apple WWDC23: Model your schema with SwiftData](https://developer.apple.com/videos/play/wwdc2023/10195/) -- HIGH confidence
- [sRPE Literature: Research on session-RPE monitoring](https://www.frontiersin.org/journals/neuroscience/articles/10.3389/fnins.2024.1341972/full) -- MEDIUM confidence (academic, supports RPE defaults by level)
