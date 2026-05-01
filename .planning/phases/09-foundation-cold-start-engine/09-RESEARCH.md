# Phase 9: Foundation & Cold-Start Engine - Research

**Researched:** 2026-05-01
**Domain:** SwiftData model creation, pure computation engine, Supabase schema migration, RLS policies
**Confidence:** HIGH

## Summary

Phase 9 establishes the data layer and computation engine for cold-start seeding and athlete-owned templates. The work is entirely infrastructure -- no UI, no views. The phase creates a new `TrainingProfile` SwiftData model, extends `WorkoutTemplate` with additive fields, implements a pure `ColdStartEngine` struct, builds a `TemplateRepository`, and deploys a Supabase migration with new RLS policies.

The primary risk is SwiftData migration -- all changes MUST be additive (new models with defaults, new optional fields) since the app uses no `VersionedSchema`. The secondary risk is RLS policy correctness: the existing policy on `workout_templates` uses `coach_id IN (SELECT id FROM athletes WHERE user_id = auth.uid())`, which already allows any user (coach or athlete) to CRUD rows where they own the `coach_id`. The new `isAthleteOwned` flag provides query-level disambiguation without requiring RLS changes for basic CRUD -- but D-15 specifies additional policies for coach visibility of athlete templates.

**Primary recommendation:** Build in strict dependency order: TrainingProfile model first, then WorkoutTemplate field additions, then ColdStartEngine (pure computation, testable independently), then TemplateRepository (depends on models), then Supabase migration, then SyncService integration last (depends on everything else).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Add `isAthleteOwned: Bool = false` and `athleteId: UUID? = nil` to WorkoutTemplate. Keep existing `coachId` untouched. Athlete templates filtered by `isAthleteOwned=true && athleteId==me`. Coach templates filtered by `isAthleteOwned=false && coachId==coach`.
- **D-02:** Also add to WorkoutTemplate: `isFavorite: Bool = false`, `isArchived: Bool = false`, `lastUsedAt: Date? = nil`, `usageCount: Int = 0`, `scheduledDays: [Int] = []` (ISO 8601 weekdays 1=Mon...7=Sun).
- **D-03:** Save-as-template (Phase 11) always creates athlete-owned template regardless of whether session was coach-prescribed. Athlete owns their template library.
- **D-04:** ColdStartEngine uses steady-state EWMA shortcut -- compute representative daily TSS from questionnaire inputs (sessions/week x avgSessionTSS / 7), then: `seededCTL = dailyTSS / ctlLambda`, `seededATL = dailyTSS / atlLambda`. No synthetic day-by-day history generation.
- **D-05:** Factor in `weeksAtLevel` as CTL discount: `ramp = max(0.3, min(1.0, weeksAtLevel / 6.0))`. Apply to CTL only. ATL unchanged (adapts fast). Athletes who recently changed programs get lower CTL seed.
- **D-06:** Session TSS uses existing formula: `WorkloadCalculator.sessionTSS(durationSeconds:sessionRPE:)` = hours x RPE x (RPE/10).
- **D-07:** Standalone `TrainingProfile` model (not on Athlete). One-to-one with athlete via `athleteId: UUID`.
- **D-08:** Required questionnaire fields: `sessionsPerWeek: Int`, `avgDurationMinutes: Int`, `typicalSRPE: Double` (1-10), `weeksAtLevel: Int`.
- **D-09:** Optional questionnaire fields: `trainingAgeYears: Int?`, `periodizationPreference: String?` (steady/periodized), `movementTypes: [String]?`, `injuryHistory: Data?` (JSON-encoded `[InjuryEntry]`).
- **D-10:** InjuryEntry is a Codable struct with `bodyRegion: BodyRegion` (enum: shoulder, knee, back, hip, ankle, wrist, elbow, neck), `notes: String?`, `isActive: Bool`.
- **D-11:** Seeded values stored on TrainingProfile: `seededATL: Double`, `seededCTL: Double`, `seededAt: Date`.
- **D-12:** Bias fields captured at 8-week mark: `biasEstimatedATL: Double?`, `biasEstimatedCTL: Double?`, `biasActualATL: Double?`, `biasActualCTL: Double?`, `biasCapturedAt: Date?`. Bias ratio computed (not stored).
- **D-13:** Cold-start window tracking: `coldStartCompletedAt: Date?` (nil = still in cold-start), set when switchover threshold met (3wk + 8 sessions).
- **D-14:** Single Supabase migration file (`v1.2_foundation.sql`) covering: ALTER TABLE workout_templates (additive columns), CREATE TABLE training_profiles, new RLS policies.
- **D-15:** Athlete RLS on workout_templates: SELECT allows own templates (isAthleteOwned=true + athleteId=me) AND coach-assigned templates (via coach_athlete_relationships join). INSERT/UPDATE/DELETE restricted to isAthleteOwned=true + athleteId=me.
- **D-16:** Existing coach RLS policies remain unchanged. New athlete policies are additive.
- **D-17:** training_profiles RLS: athlete can CRUD only their own row (athleteId=auth.uid()). Coach can SELECT linked athletes' profiles (via relationship join).

### Claude's Discretion
- TemplateRepository method signatures and internal implementation details
- Exact Supabase column types and constraints (within the decided schema shape)
- ColdStartEngine struct organization and helper methods
- SwiftData model registration order in WorkloadApp.swift schema array

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| FOUND-01 | TrainingProfile model stores questionnaire answers, seeded ATL/CTL, and bias data with Supabase sync | TrainingProfile model design (D-07 through D-13), Supabase migration (D-14), SyncService push/pull pattern documented |
| FOUND-02 | WorkoutTemplate model extended with isAthleteOwned, isFavorite, isArchived, lastUsedAt, usageCount, scheduledDays fields (additive only, no renames) | Additive field pattern documented, SwiftData lightweight migration verified safe, Supabase ALTER TABLE migration specified |
| FOUND-03 | Supabase RLS policies updated to allow athlete-owned template CRUD alongside existing coach policies | Existing RLS analyzed (`005_prescribed_workouts.sql`), additive policy strategy designed per D-15/D-16/D-17 |
| FOUND-04 | TemplateRepository provides fetch, save, duplicate, archive, and delete operations for athlete-owned templates | Repository pattern from WorkoutRepository documented, method signatures researched |
| COLD-03 | ColdStartEngine computes seeded ATL/CTL from questionnaire answers using sRPE TSS formula | Steady-state EWMA math verified against WorkloadCalculator constants, formula derivation documented |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| TrainingProfile persistence | Database / Storage (SwiftData) | API / Backend (Supabase) | Local-first with cloud sync |
| WorkoutTemplate field extension | Database / Storage (SwiftData) | API / Backend (Supabase) | Additive schema change in both tiers |
| ColdStartEngine computation | API / Backend (pure computation) | -- | Stateless pure struct, no persistence dependency |
| TemplateRepository CRUD | Database / Storage (SwiftData) | -- | Wraps ModelContext operations |
| RLS policy enforcement | API / Backend (Supabase) | -- | Server-side authorization |
| SyncService integration | API / Backend (Supabase) | Database / Storage (SwiftData) | Bridges local and remote persistence |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftData | iOS 17+ built-in | Local ORM/persistence | Already in use, no alternative for this project |
| Supabase Swift SDK | Already in project | Remote sync + auth + RLS | Already integrated in AppContainer |
| Swift (language) | 5.9+ | All implementation | Project language |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Foundation | iOS 17+ built-in | Date, UUID, Codable, JSONEncoder | Always -- core data types |
| XCTest | Xcode built-in | Unit testing ColdStartEngine | Verifying computation correctness |

[VERIFIED: Codebase inspection -- no additional dependencies needed for this phase]

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| SwiftData additive migration | VersionedSchema + SchemaMigrationPlan | Unnecessary complexity since all changes are additive with defaults |
| Raw SQL migration | Supabase Dashboard UI | Migration file in repo provides version control and reproducibility |
| Separate AthleteTemplate model | Reuse WorkoutTemplate + isAthleteOwned flag | Avoids duplicating ExerciseGroup hierarchy (locked decision D-01) |

## Architecture Patterns

### System Architecture Diagram

```
COLD-START SEEDING FLOW:
  Questionnaire Input (Phase 10 UI)
      |
      v
  ColdStartEngine.computeSeed(input:)  [PURE COMPUTATION]
      |  uses WorkloadCalculator.sessionTSS formula constants
      v
  TrainingProfile model  [PERSISTENCE]
      |  stores seededATL, seededCTL, seededAt
      v
  SyncService.pushTrainingProfile()  [SYNC]
      |
      v
  Supabase training_profiles table  [REMOTE]


TEMPLATE OWNERSHIP FLOW:
  TemplateRepository  [PERSISTENCE LAYER]
      |  fetch/save/duplicate/archive/delete
      v
  WorkoutTemplate model  [SwiftData]
      |  isAthleteOwned, athleteId, isFavorite, etc.
      v
  SyncService.pushWorkoutTemplates()  [SYNC]
      |  includes new fields in WorkoutTemplateRow
      v
  Supabase workout_templates table  [REMOTE]
      |  RLS enforces athlete can only CRUD own templates
      v
  Coach can SELECT athlete templates via relationship join
```

### Recommended Project Structure
```
WorkloadApp/
├── Models/
│   ├── TrainingProfile.swift        # NEW: @Model with questionnaire + seed + bias fields
│   ├── WorkoutTemplate.swift        # MODIFIED: additive fields (isAthleteOwned, etc.)
│   └── Enums.swift                  # MODIFIED: add BodyRegion enum
├── Services/
│   ├── ColdStartEngine.swift        # NEW: pure struct, static methods
│   └── SyncService.swift            # MODIFIED: add TrainingProfile push/pull + template field sync
├── Repositories/
│   └── TemplateRepository.swift     # NEW: @MainActor final class
├── App/
│   └── WorkloadApp.swift            # MODIFIED: add TrainingProfile.self to schema array
└── Supabase/
    └── migrations/
        └── 006_v1.2_foundation.sql  # NEW: training_profiles table + workout_templates alterations + RLS
```

### Pattern 1: Pure Struct Engine (ColdStartEngine)
**What:** Stateless struct with static methods, input struct in, result struct out.
**When to use:** All computation for ATL/CTL seeding from questionnaire answers.
**Example:**
```swift
// Source: Existing pattern from WorkloadCalculator.swift, RecoveryScoreEngine
struct ColdStartEngine {
    struct SeedInput {
        let sessionsPerWeek: Int
        let avgDurationMinutes: Int
        let typicalSRPE: Double
        let weeksAtLevel: Int
    }

    struct SeedResult {
        let seededATL: Double
        let seededCTL: Double
        let dailyTSS: Double
    }

    static func computeSeed(input: SeedInput) -> SeedResult {
        let durationSeconds = input.avgDurationMinutes * 60
        let sessionTSS = WorkloadCalculator.sessionTSS(
            durationSeconds: durationSeconds,
            sessionRPE: input.typicalSRPE
        )
        let dailyTSS = (sessionTSS * Double(input.sessionsPerWeek)) / 7.0

        // Steady-state EWMA: seeded value = dailyTSS / lambda
        let atlLambda = 1.0 / 7.0
        let ctlLambda = 1.0 / 28.0

        let seededATL = dailyTSS / atlLambda  // = dailyTSS * 7
        let ramp = max(0.3, min(1.0, Double(input.weeksAtLevel) / 6.0))
        let seededCTL = (dailyTSS / ctlLambda) * ramp  // = dailyTSS * 28 * ramp

        return SeedResult(seededATL: seededATL, seededCTL: seededCTL, dailyTSS: dailyTSS)
    }
}
```
[VERIFIED: WorkloadCalculator.swift lines 10-13 confirm atlLambda = 1/7, ctlLambda = 1/28]

### Pattern 2: @MainActor Repository (TemplateRepository)
**What:** `@MainActor final class` with `ModelContext`, typed methods for CRUD.
**When to use:** All template fetch/save/duplicate/archive/delete operations.
**Example:**
```swift
// Source: Existing pattern from WorkoutRepository.swift, AthleteRepository
@MainActor
final class TemplateRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchAthleteTemplates(athleteId: UUID) throws -> [WorkoutTemplate] {
        let predicate = #Predicate<WorkoutTemplate> {
            $0.isAthleteOwned == true && $0.athleteId == athleteId && $0.isArchived == false
        }
        let descriptor = FetchDescriptor<WorkoutTemplate>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func duplicate(_ template: WorkoutTemplate, athleteId: UUID) throws -> WorkoutTemplate {
        let copy = WorkoutTemplate(
            coachId: athleteId,
            templateName: "\(template.templateName) (Copy)",
            sportType: template.sportType,
            sessionType: template.sessionType,
            notes: template.notes
        )
        copy.isAthleteOwned = true
        copy.athleteId = athleteId
        copy.groups = template.deepCopyGroups()
        modelContext.insert(copy)
        try modelContext.save()
        return copy
    }

    func archive(_ template: WorkoutTemplate) throws {
        template.isArchived = true
        template.updatedAt = .now
        try modelContext.save()
    }

    func delete(_ template: WorkoutTemplate) throws {
        modelContext.delete(template)
        try modelContext.save()
    }
}
```
[VERIFIED: WorkoutRepository.swift and WorkoutTemplate.deepCopyGroups() confirm pattern]

### Pattern 3: Additive SwiftData Schema Changes
**What:** New fields with defaults, new models registered in schema array. No renames, no type changes.
**When to use:** All model modifications in this phase.
**Why safe:** SwiftData performs lightweight migration automatically for additive changes. The app uses no `VersionedSchema` -- only a flat `Schema([...])` in `WorkloadApp.swift`.
```swift
// On WorkoutTemplate -- all additive with defaults:
var isAthleteOwned: Bool = false
var athleteId: UUID? = nil
var isFavorite: Bool = false
var isArchived: Bool = false
var lastUsedAt: Date? = nil
var usageCount: Int = 0
var scheduledDays: [Int] = []
```
[VERIFIED: WorkloadApp.swift lines 22-39 confirm no VersionedSchema in use]

### Pattern 4: SyncService Row Struct Extension
**What:** Extend `WorkoutTemplateRow` Codable struct to include new fields for sync.
**When to use:** When syncing modified models to Supabase.
```swift
// Source: Existing WorkoutTemplateRow in SyncService.swift
struct WorkoutTemplateRow: Codable {
    // ... existing fields ...
    let isAthleteOwned: Bool
    let athleteId: UUID?
    let isFavorite: Bool
    let isArchived: Bool
    let lastUsedAt: Date?
    let usageCount: Int
    let scheduledDays: [Int]?
}
```
[VERIFIED: SyncService.swift lines 904-926 show existing WorkoutTemplateRow pattern]

### Anti-Patterns to Avoid
- **Renaming `coachId` to `ownerId`:** Causes SwiftData migration crash. Keep `coachId`, add `isAthleteOwned` flag (locked decision D-01). [VERIFIED: PITFALLS.md Pitfall 2, 3]
- **Writing estimated ATL/CTL to WorkloadSnapshot:** Contaminates real EWMA chain. Estimated values live ONLY on TrainingProfile (locked decision D-11). [VERIFIED: PITFALLS.md Pitfall 4]
- **Forgetting TrainingProfile.self in schema array:** Causes `fatalError` on app launch. Must add to `WorkloadApp.swift` Schema initializer. [VERIFIED: WorkloadApp.swift line 43]
- **Modifying existing RLS policies:** Risk of breaking coach template sync. New policies are ADDITIVE only (locked decision D-16). [VERIFIED: 005_prescribed_workouts.sql]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Session TSS calculation | Custom formula in ColdStartEngine | `WorkloadCalculator.sessionTSS(durationSeconds:sessionRPE:)` | Formula already exists, ensures consistency across codebase |
| EWMA constants | Hardcoded `7.0` and `28.0` | Reference `atlLambda` and `ctlLambda` from WorkloadCalculator (or duplicate as documented constants) | Single source of truth for decay constants |
| Template deep copy | Manual relationship cloning | `WorkoutTemplate.deepCopyGroups()` | Existing method handles full ExerciseGroup hierarchy correctly |
| JSON encoding for Supabase | Manual string building | `JSONEncoder` with `.convertToSnakeCase` strategy (already configured in AppContainer) | Matches existing encoding configuration |
| UUID generation | Custom ID schemes | `UUID()` default in model init | Matches all other models in the project |

**Key insight:** ColdStartEngine is intentionally minimal -- it delegates TSS computation to the existing formula and only adds the steady-state EWMA shortcut math. No new calculation primitives needed.

## Common Pitfalls

### Pitfall 1: SwiftData Migration Crash from Non-Additive Changes
**What goes wrong:** Any field rename, type change, or removal on existing models causes `fatalError("Failed to create ModelContainer")` on app launch for existing users.
**Why it happens:** The app has no `VersionedSchema` or `SchemaMigrationPlan`. SwiftData only handles lightweight (additive) migrations automatically.
**How to avoid:** Every field addition MUST have a default value. `Bool = false`, `Int = 0`, `Date? = nil`, `[Int] = []`. The new `TrainingProfile` model is safe (new model = always lightweight). `WorkoutTemplate` additions are safe (all additive with defaults).
**Warning signs:** Build succeeds but app crashes on launch with existing data. Test by: build v1.1, seed data, update to v1.2, verify no crash.

### Pitfall 2: RLS Silent Failure on Athlete Template Sync
**What goes wrong:** Athlete creates template locally (SwiftData succeeds), SyncService pushes to Supabase, RLS denies the upsert, `try?` swallows the error. Template appears saved but is lost on device change.
**Why it happens:** The existing RLS policy `"Coaches manage own templates"` uses `coach_id IN (SELECT id FROM athletes WHERE user_id = auth.uid())`. This DOES work for athletes (since `coach_id` will be set to the athlete's `id`), BUT the new D-15 policies add a more restrictive athlete-specific path. If the new policies are misconfigured, they could block instead of allow.
**How to avoid:** Deploy migration BEFORE implementing sync for new fields. Test with a non-coach athlete account: create template, sync, verify row exists in Supabase. The new policies must be additive (D-16).
**Warning signs:** Template count differs between local and remote. No error in logs (due to `try?`).

### Pitfall 3: Incorrect Steady-State EWMA Math
**What goes wrong:** The steady-state shortcut `seededCTL = dailyTSS / ctlLambda` gives a value that is incompatible with the EWMA chain when real sessions start arriving.
**Why it happens:** The steady-state formula assumes constant daily load. In reality, athletes train on specific days (not daily). The actual EWMA under intermittent training converges to a lower value than the theoretical steady state for uniform daily load.
**How to avoid:** This is a known approximation (discussed in D-04). The `weeksAtLevel` ramp factor (D-05) partially compensates by discounting CTL for recent program changes. The estimate is intentionally "rough" -- bias will be measured at 8 weeks (D-12). Ensure the formula is: `seededATL = dailyTSS * 7` (not `dailyTSS / atlLambda` which equals the same thing but is less clear). `seededCTL = dailyTSS * 28 * ramp`.
**Warning signs:** If seededCTL > 500 for recreational athletes (3-4 sessions/week, 60min, RPE 6), the math is wrong. Expected range: 50-300 for most users.

### Pitfall 4: `scheduledDays` Array Storage in SwiftData
**What goes wrong:** SwiftData stores Swift arrays as transformable attributes. `[Int]` requires the type to be `Codable`. If the default value is `[]` (empty array), SwiftData may store it as `nil` internally and return `nil` on decode if the backing store schema differs between versions.
**Why it happens:** SwiftData's handling of array properties has edge cases around nil vs empty array, especially during lightweight migration.
**How to avoid:** Declare as `var scheduledDays: [Int] = []` with a non-optional type. On the Supabase side, use `INT[]` (PostgreSQL native array) which maps naturally. In `WorkoutTemplateRow`, declare as `let scheduledDays: [Int]?` (optional for decode safety) and coalesce to empty array when mapping back to model.
**Warning signs:** Crash on accessing `.scheduledDays` after migration. Test with templates created before the field existed.

### Pitfall 5: TrainingProfile `athleteId` Not Matching Supabase `auth.uid()`
**What goes wrong:** RLS policy uses `athlete_id = auth.uid()` but `TrainingProfile.athleteId` stores the `Athlete.id` UUID (which is the local model ID), not the Supabase `auth.uid()` (which is `Athlete.supabaseUserId`).
**Why it happens:** In the existing schema, `athletes.id` is the model UUID but `athletes.user_id` is `auth.uid()`. The RLS policies on other tables (like `workout_templates`) use `coach_id IN (SELECT id FROM athletes WHERE user_id = auth.uid())` -- an indirect lookup.
**How to avoid:** The `training_profiles` RLS must use the same indirect lookup pattern: `athlete_id IN (SELECT id FROM athletes WHERE user_id = auth.uid())`. Do NOT use `athlete_id = auth.uid()` directly -- it will fail because athlete_id is the model UUID, not the auth UUID.
**Warning signs:** All TrainingProfile sync operations fail silently. Test: create profile, push, check Supabase.

## Code Examples

### ColdStartEngine Complete Implementation
```swift
// Source: Decisions D-04, D-05, D-06 + WorkloadCalculator.swift constants
import Foundation

struct ColdStartEngine {

    struct SeedInput {
        let sessionsPerWeek: Int       // D-08: required
        let avgDurationMinutes: Int    // D-08: required
        let typicalSRPE: Double        // D-08: required (1-10)
        let weeksAtLevel: Int          // D-08: required
    }

    struct SeedResult {
        let seededATL: Double
        let seededCTL: Double
        let dailyTSS: Double
        let sessionTSS: Double
    }

    /// Compute seeded ATL/CTL from questionnaire inputs using steady-state EWMA shortcut.
    /// D-04: dailyTSS = (sessionTSS * sessionsPerWeek) / 7
    /// D-05: CTL discounted by weeksAtLevel ramp factor
    static func computeSeed(input: SeedInput) -> SeedResult {
        // D-06: Use existing TSS formula
        let durationSeconds = input.avgDurationMinutes * 60
        let sessionTSS = WorkloadCalculator.sessionTSS(
            durationSeconds: durationSeconds,
            sessionRPE: input.typicalSRPE
        )

        // D-04: Representative daily TSS
        let dailyTSS = (sessionTSS * Double(input.sessionsPerWeek)) / 7.0

        // Steady-state EWMA: at equilibrium, value = dailyInput / lambda
        // ATL lambda = 1/7, so steady-state ATL = dailyTSS * 7
        // CTL lambda = 1/28, so steady-state CTL = dailyTSS * 28
        let seededATL = dailyTSS / (1.0 / 7.0)  // = dailyTSS * 7

        // D-05: CTL discount for athletes who recently changed programs
        let ramp = max(0.3, min(1.0, Double(input.weeksAtLevel) / 6.0))
        let seededCTL = (dailyTSS / (1.0 / 28.0)) * ramp  // = dailyTSS * 28 * ramp

        return SeedResult(
            seededATL: seededATL,
            seededCTL: seededCTL,
            dailyTSS: dailyTSS,
            sessionTSS: sessionTSS
        )
    }
}
```
[VERIFIED: atlLambda=1/7 and ctlLambda=1/28 confirmed in WorkloadCalculator.swift lines 11-13]

### TrainingProfile Model
```swift
// Source: Decisions D-07 through D-13
import Foundation
import SwiftData

@Model
final class TrainingProfile {
    @Attribute(.unique) var id: UUID
    var athleteId: UUID

    // D-08: Required questionnaire fields
    var sessionsPerWeek: Int
    var avgDurationMinutes: Int
    var typicalSRPE: Double
    var weeksAtLevel: Int

    // D-09: Optional questionnaire fields
    var trainingAgeYears: Int?
    var periodizationPreference: String?  // "steady" | "periodized"
    var movementTypes: [String]?
    var injuryHistory: Data?  // JSON-encoded [InjuryEntry]

    // D-11: Seeded values
    var seededATL: Double
    var seededCTL: Double
    var seededAt: Date

    // D-12: Bias fields (captured at 8-week mark)
    var biasEstimatedATL: Double?
    var biasEstimatedCTL: Double?
    var biasActualATL: Double?
    var biasActualCTL: Double?
    var biasCapturedAt: Date?

    // D-13: Cold-start window tracking
    var coldStartCompletedAt: Date?

    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        athleteId: UUID,
        sessionsPerWeek: Int,
        avgDurationMinutes: Int,
        typicalSRPE: Double,
        weeksAtLevel: Int,
        seededATL: Double,
        seededCTL: Double,
        seededAt: Date = .now
    ) {
        self.id = id
        self.athleteId = athleteId
        self.sessionsPerWeek = sessionsPerWeek
        self.avgDurationMinutes = avgDurationMinutes
        self.typicalSRPE = typicalSRPE
        self.weeksAtLevel = weeksAtLevel
        self.seededATL = seededATL
        self.seededCTL = seededCTL
        self.seededAt = seededAt
        self.createdAt = .now
        self.updatedAt = .now
    }
}
```

### InjuryEntry Codable Struct and BodyRegion Enum
```swift
// Source: Decisions D-09, D-10
// Add BodyRegion to Enums.swift
enum BodyRegion: String, Codable, CaseIterable, Identifiable {
    case shoulder, knee, back, hip, ankle, wrist, elbow, neck

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .shoulder: "Shoulder"
        case .knee: "Knee"
        case .back: "Back"
        case .hip: "Hip"
        case .ankle: "Ankle"
        case .wrist: "Wrist"
        case .elbow: "Elbow"
        case .neck: "Neck"
        }
    }
}

// Standalone Codable struct (not @Model), stored as JSON Data on TrainingProfile
struct InjuryEntry: Codable {
    let bodyRegion: BodyRegion
    let notes: String?
    let isActive: Bool
}
```

### WorkoutTemplate Additive Fields
```swift
// Source: Decisions D-01, D-02
// Add to existing WorkoutTemplate @Model class:
var isAthleteOwned: Bool = false
var athleteId: UUID? = nil
var isFavorite: Bool = false
var isArchived: Bool = false
var lastUsedAt: Date? = nil
var usageCount: Int = 0
var scheduledDays: [Int] = []  // ISO 8601: 1=Mon...7=Sun
```

### Supabase Migration (006_v1.2_foundation.sql)
```sql
-- Source: Decisions D-14 through D-17
-- v1.2 Foundation: TrainingProfile + WorkoutTemplate extensions + RLS

-- 1. New table: training_profiles
CREATE TABLE IF NOT EXISTS training_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    athlete_id UUID NOT NULL REFERENCES athletes(id) ON DELETE CASCADE,
    sessions_per_week INT NOT NULL,
    avg_duration_minutes INT NOT NULL,
    typical_srpe DOUBLE PRECISION NOT NULL,
    weeks_at_level INT NOT NULL,
    training_age_years INT,
    periodization_preference TEXT,
    movement_types TEXT[],
    injury_history JSONB,
    seeded_atl DOUBLE PRECISION NOT NULL,
    seeded_ctl DOUBLE PRECISION NOT NULL,
    seeded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    bias_estimated_atl DOUBLE PRECISION,
    bias_estimated_ctl DOUBLE PRECISION,
    bias_actual_atl DOUBLE PRECISION,
    bias_actual_ctl DOUBLE PRECISION,
    bias_captured_at TIMESTAMPTZ,
    cold_start_completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(athlete_id)
);

-- 2. RLS on training_profiles (D-17)
ALTER TABLE training_profiles ENABLE ROW LEVEL SECURITY;

-- Athlete CRUD own profile
CREATE POLICY "Athletes manage own training profile"
    ON training_profiles FOR ALL
    USING (athlete_id IN (SELECT id FROM athletes WHERE user_id = auth.uid()))
    WITH CHECK (athlete_id IN (SELECT id FROM athletes WHERE user_id = auth.uid()));

-- Coach can read linked athletes' profiles
CREATE POLICY "Coaches read linked athlete profiles"
    ON training_profiles FOR SELECT
    USING (athlete_id IN (
        SELECT athlete_id FROM coach_athlete_relationships
        WHERE coach_id IN (SELECT id FROM athletes WHERE user_id = auth.uid())
        AND status = 'accepted'
    ));

-- 3. Extend workout_templates (D-01, D-02)
ALTER TABLE workout_templates
    ADD COLUMN IF NOT EXISTS is_athlete_owned BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS athlete_id UUID,
    ADD COLUMN IF NOT EXISTS is_favorite BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS is_archived BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS last_used_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS usage_count INT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS scheduled_days INT[];

-- 4. Athlete RLS on workout_templates (D-15, D-16 -- additive, existing policy unchanged)
-- Athletes can manage their own athlete-owned templates
CREATE POLICY "Athletes manage own templates"
    ON workout_templates FOR ALL
    USING (
        is_athlete_owned = true
        AND athlete_id IN (SELECT id FROM athletes WHERE user_id = auth.uid())
    )
    WITH CHECK (
        is_athlete_owned = true
        AND athlete_id IN (SELECT id FROM athletes WHERE user_id = auth.uid())
    );

-- Athletes can SELECT coach-assigned templates (via relationship)
CREATE POLICY "Athletes read coach templates via relationship"
    ON workout_templates FOR SELECT
    USING (
        is_athlete_owned = false
        AND coach_id IN (
            SELECT coach_id FROM coach_athlete_relationships
            WHERE athlete_id IN (SELECT id FROM athletes WHERE user_id = auth.uid())
            AND status = 'accepted'
        )
    );

-- 5. Indexes
CREATE INDEX IF NOT EXISTS idx_training_profiles_athlete ON training_profiles(athlete_id);
CREATE INDEX IF NOT EXISTS idx_workout_templates_athlete ON workout_templates(athlete_id) WHERE is_athlete_owned = true;
```
[VERIFIED: Existing RLS pattern from 005_prescribed_workouts.sql uses same `IN (SELECT id FROM athletes WHERE user_id = auth.uid())` pattern]

### SyncService TrainingProfile Push/Pull
```swift
// Source: Existing push/pull pattern from SyncService.swift
func pushTrainingProfile(context: ModelContext, athleteId: UUID) async {
    let predicate = #Predicate<TrainingProfile> { $0.athleteId == athleteId }
    guard let profile = try? context.fetch(FetchDescriptor(predicate: predicate)).first else { return }
    let row = TrainingProfileRow(from: profile)
    _ = try? await client.from("training_profiles").upsert(row).execute()
}

func pullTrainingProfile(context: ModelContext, athleteId: UUID) async {
    guard let row: TrainingProfileRow = try? await client
        .from("training_profiles")
        .select()
        .eq("athlete_id", value: athleteId)
        .single()
        .execute()
        .value
    else { return }

    let predicate = #Predicate<TrainingProfile> { $0.athleteId == athleteId }
    let existing = try? context.fetch(FetchDescriptor(predicate: predicate)).first
    if let existing, existing.updatedAt > row.updatedAt { return }

    let profile = existing ?? TrainingProfile(
        athleteId: athleteId,
        sessionsPerWeek: row.sessionsPerWeek,
        avgDurationMinutes: row.avgDurationMinutes,
        typicalSrpe: row.typicalSrpe,
        weeksAtLevel: row.weeksAtLevel,
        seededATL: row.seededAtl,
        seededCTL: row.seededCtl,
        seededAt: row.seededAt
    )
    // Update fields...
    profile.updatedAt = row.updatedAt
    if existing == nil { context.insert(profile) }
    try? context.save()
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| CoreData with manual migrations | SwiftData lightweight migration | WWDC23 (iOS 17) | No explicit migration code needed for additive changes |
| Manual EWMA seed generation | Steady-state shortcut formula | This phase (new) | Eliminates synthetic history generation, single-step computation |
| Coach-only template model | Dual-ownership via isAthleteOwned flag | This phase (new) | Avoids schema migration, preserves existing coach flow |

**Deprecated/outdated:**
- VersionedSchema is available but unnecessary here -- all changes are additive [ASSUMED: additive-only pattern holds if implementations follow decisions exactly]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | SwiftData `[Int]` property with default `[]` survives lightweight migration without nil/crash issues | Architecture Patterns | App crash on template access for users upgrading from v1.1 |
| A2 | `Data?` property (for JSON-encoded injuryHistory) works correctly with SwiftData lightweight migration | Code Examples | TrainingProfile creation fails |
| A3 | `[String]?` property (movementTypes) properly serializes in SwiftData without custom transformer | Code Examples | movementTypes field inaccessible after save |
| A4 | PostgreSQL `INT[]` column works with Supabase Swift SDK's JSONDecoder without custom handling | Code Examples | scheduledDays sync fails silently |

## Open Questions

1. **SwiftData array property migration safety**
   - What we know: Simple optionals and booleans with defaults are safe for lightweight migration
   - What's unclear: Whether `[Int] = []` and `[String]? = nil` survive migration on devices with existing v1.1 data without requiring transformable attribute configuration
   - Recommendation: Test on simulator with pre-existing data before App Store submission. If issues arise, use `Data?` with manual JSON encode/decode (same pattern as `injuryHistory`).

2. **Supabase INT[] column compatibility with Swift SDK**
   - What we know: The Supabase Swift SDK uses `JSONDecoder` for response parsing
   - What's unclear: Whether PostgreSQL `INT[]` serializes as `[1,2,3]` in JSON response or requires special handling
   - Recommendation: If issues arise, store as `TEXT` with JSON encoding (e.g., `"[1,2,3]"`) and decode manually. This matches the `groups_json` pattern already in use.

3. **Existing coach RLS policy interaction with new athlete policy**
   - What we know: PostgreSQL RLS uses OR semantics between multiple policies for the same command. Multiple `USING` policies for SELECT are combined with OR.
   - What's unclear: Whether the existing "Coaches manage own templates" policy (which uses `FOR ALL`) conflicts with the new "Athletes manage own templates" policy when both evaluate for the same user
   - Recommendation: Verify in Supabase SQL editor that a non-coach athlete user can INSERT a template with `is_athlete_owned=true`. The OR semantics should allow it, but test explicitly.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode | Build verification | Assumed (iOS dev machine) | -- | -- |
| Supabase project | Migration deployment | Available (existing) | -- | -- |
| SwiftData | Model persistence | Available (iOS 17+) | iOS 17 built-in | -- |

Step 2.6: No external tool dependencies beyond what is already in the project. All work uses existing frameworks and services.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | Existing Supabase Auth unchanged |
| V3 Session Management | No | Existing session handling unchanged |
| V4 Access Control | Yes | Supabase RLS policies (row-level security) |
| V5 Input Validation | Yes | ColdStartEngine input bounds checking |
| V6 Cryptography | No | No cryptographic operations in this phase |

### Known Threat Patterns for This Phase

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Athlete accesses another athlete's TrainingProfile | Information Disclosure | RLS: `athlete_id IN (SELECT id FROM athletes WHERE user_id = auth.uid())` |
| Athlete modifies another athlete's template | Tampering | RLS: `is_athlete_owned=true AND athlete_id=own_id` check on INSERT/UPDATE/DELETE |
| Coach accesses non-linked athlete's profile | Information Disclosure | RLS: coach SELECT restricted to `coach_athlete_relationships` join |
| Malformed questionnaire input (RPE > 10, negative duration) | Tampering | ColdStartEngine input validation: clamp RPE to 1-10, duration >= 1 |

## Sources

### Primary (HIGH confidence)
- `WorkloadApp/Services/WorkloadCalculator.swift` -- EWMA constants (atlLambda=1/7, ctlLambda=1/28), sessionTSS formula
- `WorkloadApp/Models/WorkoutTemplate.swift` -- Current model structure, `deepCopyGroups()` method
- `WorkloadApp/Services/SyncService.swift` -- Push/pull pattern, WorkoutTemplateRow struct, error handling (`try?`)
- `WorkloadApp/App/WorkloadApp.swift` -- Schema registration array, no VersionedSchema
- `WorkloadApp/Repositories/WorkloadRepository.swift` -- Repository pattern
- `WorkloadApp/Repositories/WorkoutRepository.swift` -- Repository pattern
- `Supabase/migrations/005_prescribed_workouts.sql` -- Existing RLS policy structure
- `.planning/phases/09-foundation-cold-start-engine/09-CONTEXT.md` -- All locked decisions D-01 through D-17

### Secondary (MEDIUM confidence)
- `.planning/research/ARCHITECTURE.md` -- Component inventory and build order analysis
- `.planning/research/PITFALLS.md` -- 15 documented pitfalls with prevention strategies
- `WorkloadApp/Services/WorkoutPipeline.swift` -- Real EWMA computation flow (processSession)

### Tertiary (LOW confidence)
- SwiftData array property migration behavior -- based on training knowledge, not tested against iOS 17.5+ [ASSUMED]
- PostgreSQL INT[] to Swift SDK JSON decode compatibility [ASSUMED]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - all technologies already in use in the project
- Architecture: HIGH - follows existing patterns exactly, verified against source code
- Pitfalls: HIGH - verified against actual code paths and existing RLS policies
- ColdStartEngine math: HIGH - formula verified against WorkloadCalculator constants

**Research date:** 2026-05-01
**Valid until:** 2026-06-01 (stable -- all dependencies are Apple frameworks and existing project patterns)
