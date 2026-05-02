# Phase 9: Foundation & Cold-Start Engine - Pattern Map

**Mapped:** 2026-05-01
**Files analyzed:** 8 (3 new, 5 modified)
**Analogs found:** 8 / 8

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `WorkloadApp/Models/TrainingProfile.swift` | model | CRUD | `WorkloadApp/Models/WellnessCheckIn.swift` | exact |
| `WorkloadApp/Models/WorkoutTemplate.swift` | model | CRUD | (self -- additive fields only) | exact |
| `WorkloadApp/Models/Enums.swift` | config | transform | (self -- add BodyRegion enum) | exact |
| `WorkloadApp/Services/ColdStartEngine.swift` | service (engine) | transform | `WorkloadApp/Services/RecoveryScoreEngine.swift` | exact |
| `WorkloadApp/Repositories/TemplateRepository.swift` | repository | CRUD | `WorkloadApp/Repositories/WorkoutRepository.swift` | exact |
| `WorkloadApp/Services/SyncService.swift` | service | request-response | (self -- add push/pull methods + extend row struct) | exact |
| `WorkloadApp/App/WorkloadApp.swift` | config | N/A | (self -- add to schema array) | exact |
| `Supabase/migrations/006_v1.2_foundation.sql` | migration | N/A | `Supabase/migrations/005_prescribed_workouts.sql` | exact |

## Pattern Assignments

### `WorkloadApp/Models/TrainingProfile.swift` (model, CRUD) -- NEW

**Analog:** `WorkloadApp/Models/WellnessCheckIn.swift`

**Imports pattern** (lines 1-2):
```swift
import Foundation
import SwiftData
```

**Model declaration pattern** (lines 4-6):
```swift
@Model
final class WellnessCheckIn {
    @Attribute(.unique) var id: UUID
```

**Field pattern -- required fields with types** (WellnessCheckIn lines 7-11):
```swift
    var date: Date
    var sleepQuality: Int
    var soreness: Int
    var energy: Int
    var stress: Int
    var notes: String?
    var updatedAt: Date
```

**Init pattern** (WellnessCheckIn lines 25-42):
```swift
    init(
        id: UUID = UUID(),
        date: Date = .now,
        sleepQuality: Int = 3,
        soreness: Int = 3,
        energy: Int = 3,
        stress: Int = 3,
        notes: String? = nil
    ) {
        self.id = id
        self.date = date
        self.sleepQuality = sleepQuality
        self.soreness = soreness
        self.energy = energy
        self.stress = stress
        self.notes = notes
        self.updatedAt = .now
    }
```

**Secondary analog for standalone model (no `athlete` relationship):** `WorkloadApp/Models/RecoverySnapshot.swift` -- Note that `TrainingProfile` uses `athleteId: UUID` (foreign key by value, not a SwiftData `@Relationship`), matching the standalone pattern described in D-07. Do NOT add `var athlete: Athlete?` relationship. The `athleteId` is a plain UUID used for fetch predicates and Supabase sync.

---

### `WorkloadApp/Models/WorkoutTemplate.swift` (model, CRUD) -- MODIFIED

**Analog:** Self (additive fields only)

**Existing field block to extend** (WorkoutTemplate.swift lines 8-16):
```swift
    @Attribute(.unique) var id: UUID
    var coachId: UUID
    var templateName: String
    var sportType: SportType
    var sessionType: SessionType
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
```

**New fields to add after line 16** (all with defaults for lightweight migration safety):
```swift
    var isAthleteOwned: Bool = false
    var athleteId: UUID? = nil
    var isFavorite: Bool = false
    var isArchived: Bool = false
    var lastUsedAt: Date? = nil
    var usageCount: Int = 0
    var scheduledDays: [Int] = []
```

**Critical constraint:** All fields MUST have default values. No renames, no type changes on existing fields. SwiftData lightweight migration only supports additive changes.

---

### `WorkloadApp/Models/Enums.swift` (config, transform) -- MODIFIED

**Analog:** Self -- follow existing enum pattern

**Enum declaration pattern** (Enums.swift lines 5-39, SportType as reference):
```swift
enum SportType: String, Codable, CaseIterable, Identifiable {
    case lifting
    case running
    case cycling
    case teamSport
    case crossfit
    case swimming
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .lifting: "Lifting"
        case .running: "Running"
        case .cycling: "Cycling"
        case .teamSport: "Team Sport"
        case .crossfit: "CrossFit"
        case .swimming: "Swimming"
        case .custom: "Custom"
        }
    }
}
```

**New BodyRegion enum** -- add in a new `// MARK: - Injury Enums` section after the existing `// MARK: - Coach / Role Enums` section (after line 264). Conform to `String, Codable, CaseIterable, Identifiable`. Include `displayName` computed property. Cases: `shoulder, knee, back, hip, ankle, wrist, elbow, neck`.

**InjuryEntry Codable struct** -- add immediately after `BodyRegion` enum. This is a plain `Codable` struct (NOT an `@Model`), stored as JSON `Data` on `TrainingProfile.injuryHistory`.

---

### `WorkloadApp/Services/ColdStartEngine.swift` (engine, transform) -- NEW

**Analog:** `WorkloadApp/Services/RecoveryScoreEngine.swift`

**Imports pattern** (RecoveryScoreEngine.swift line 1):
```swift
import Foundation
```

**Struct declaration pattern** (RecoveryScoreEngine.swift line 18):
```swift
struct RecoveryScoreEngine {
```

**Input struct pattern** (RecoveryScoreEngine.swift lines 20-51):
```swift
    struct RecoveryInput {
        let hrvSDNN: Double?
        let restingHR: Double?
        let sleepDurationMinutes: Double?
        let wellnessScore: Double?
        let hrvBaseline: Double?
        let restingHRBaseline: Double?
        let recentScores: [Double]

        init(
            hrvSDNN: Double? = nil,
            restingHR: Double? = nil,
            sleepDurationMinutes: Double? = nil,
            wellnessScore: Double? = nil,
            hrvBaseline: Double? = nil,
            restingHRBaseline: Double? = nil,
            recentScores: [Double] = []
        ) {
            // ...
        }
    }
```

**Result struct pattern** (RecoveryScoreEngine.swift lines 53-64):
```swift
    struct RecoveryResult {
        let score: Double
        let baseScore: Double
        let zone: RecoveryZone
        let hrvContribution: Double?
        // ...
    }
```

**Static compute method pattern** (RecoveryScoreEngine.swift lines 82-83):
```swift
    static func compute(input: RecoveryInput) -> RecoveryResult {
```

**Private constants pattern** (RecoveryScoreEngine.swift lines 68-76):
```swift
    private static let hrvWeight: Double = 0.30
    private static let rhrWeight: Double = 0.20
```

**Doc comment pattern** (RecoveryScoreEngine.swift lines 1-17):
```swift
/// Computes a composite recovery score (0-100) by fusing passive HealthKit data
/// with active subjective wellness data, then applying a trend modifier based on
/// recent recovery trajectory.
///
/// Component weights (base score):
/// - HRV vs personal baseline: 30%
/// - Resting HR vs baseline:   20%
```

**Key implementation detail:** ColdStartEngine calls `WorkloadCalculator.sessionTSS(durationSeconds:sessionRPE:)` (WorkloadCalculator.swift lines 43-46) and references the EWMA constants conceptually (`atlLambda = 1/7`, `ctlLambda = 1/28` from WorkloadCalculator.swift lines 11-12). Since these constants are `private static`, ColdStartEngine must duplicate the reciprocal values or use the mathematical equivalents directly (`dailyTSS * 7` for ATL, `dailyTSS * 28 * ramp` for CTL).

**WorkloadCalculator.sessionTSS signature** (WorkloadCalculator.swift lines 43-46):
```swift
    static func sessionTSS(durationSeconds: Int, sessionRPE: Double) -> Double {
        let hours = Double(durationSeconds) / 3600.0
        return hours * sessionRPE * (sessionRPE / 10.0)
    }
```

---

### `WorkloadApp/Repositories/TemplateRepository.swift` (repository, CRUD) -- NEW

**Analog:** `WorkloadApp/Repositories/WorkoutRepository.swift`

**Imports pattern** (WorkoutRepository.swift lines 1-2):
```swift
import Foundation
import SwiftData
```

**Class declaration pattern** (WorkoutRepository.swift lines 5-11):
```swift
@MainActor
final class WorkoutRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
```

**Fetch with predicate pattern** (WorkoutRepository.swift lines 31-39):
```swift
    func fetchSessions(last days: Int) throws -> [WorkoutSession] {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: .now)!
        let predicate = #Predicate<WorkoutSession> { $0.sessionDate >= startDate }
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.sessionDate)]
        )
        return try modelContext.fetch(descriptor)
    }
```

**Save pattern** (WorkoutRepository.swift lines 13-17):
```swift
    func saveSession(_ session: WorkoutSession) throws {
        session.recalculateDerivedFields()
        modelContext.insert(session)
        try modelContext.save()
    }
```

**Delete pattern** (WorkoutRepository.swift lines 19-22):
```swift
    func deleteSession(_ session: WorkoutSession) throws {
        modelContext.delete(session)
        try modelContext.save()
    }
```

**Secondary analog for upsert pattern:** `WorkloadApp/Repositories/WorkloadRepository.swift` (lines 13-38) shows a fetch-then-update-or-insert pattern useful for the `save` method on TemplateRepository.

---

### `WorkloadApp/Services/SyncService.swift` (service, request-response) -- MODIFIED

**Analog:** Self -- follow existing push/pull patterns

**Push method pattern** (SyncService.swift lines 695-701):
```swift
    func pushWorkoutTemplates(context: ModelContext, coachId: UUID) async {
        guard let templates = try? context.fetch(
            FetchDescriptor<WorkoutTemplate>(predicate: #Predicate { $0.coachId == coachId })
        ) else { return }
        let rows = templates.map { WorkoutTemplateRow(from: $0) }
        _ = try? await client.from("workout_templates").upsert(rows).execute()
    }
```

**Pull method pattern** (SyncService.swift lines 703-738):
```swift
    private func pullWorkoutTemplates(context: ModelContext, coachId: UUID) async {
        guard let rows: [WorkoutTemplateRow] = try? await client
            .from("workout_templates")
            .select()
            .eq("coach_id", value: coachId)
            .execute()
            .value
        else { return }

        for row in rows {
            let pred = #Predicate<WorkoutTemplate> { $0.id == row.id }
            let existing = try? context.fetch(FetchDescriptor(predicate: pred)).first
            if let existing, existing.updatedAt > row.updatedAt { continue }
            let template = existing ?? WorkoutTemplate(coachId: row.coachId, templateName: row.templateName)
            // ... update fields ...
            if existing == nil { context.insert(template) }
        }
        try? context.save()
    }
```

**Row struct pattern** (SyncService.swift lines 904-926):
```swift
struct WorkoutTemplateRow: Codable {
    let id: UUID
    let coachId: UUID
    let templateName: String
    let sportType: String
    let sessionType: String
    let notes: String?
    let groupsJson: String?
    let createdAt: Date
    let updatedAt: Date

    init(from model: WorkoutTemplate) {
        self.id = model.id
        self.coachId = model.coachId
        self.templateName = model.templateName
        self.sportType = model.sportType.rawValue
        self.sessionType = model.sessionType.rawValue
        self.notes = model.notes
        self.groupsJson = SyncService.encodeGroups(model.groups)
        self.createdAt = model.createdAt
        self.updatedAt = model.updatedAt
    }
}
```

**Modifications required:**
1. Extend `WorkoutTemplateRow` with new fields: `isAthleteOwned`, `athleteId`, `isFavorite`, `isArchived`, `lastUsedAt`, `usageCount`, `scheduledDays`
2. Add new `TrainingProfileRow` Codable struct following the same pattern
3. Add `pushTrainingProfile` / `pullTrainingProfile` methods following the push/pull pattern above
4. Add `pushTrainingProfile` and `pullTrainingProfile` calls to `pushAll` / `pullAll` methods (lines 19-45)
5. Update `pullWorkoutTemplates` to map new fields from row to model

**pushAll/pullAll registration pattern** (SyncService.swift lines 19-30):
```swift
    func pushAll(context: ModelContext) async {
        guard let athlete = try? context.fetch(FetchDescriptor<Athlete>()).first else { return }
        await pushAthlete(athlete)
        await pushWorkloadSnapshots(context: context, athleteId: athlete.id)
        // ... more push calls ...
        await pushWorkoutTemplates(context: context, coachId: athlete.id)
        UserDefaults.standard.set(Date(), forKey: "lastSyncedAt")
    }
```

---

### `WorkloadApp/App/WorkloadApp.swift` (config, N/A) -- MODIFIED

**Analog:** Self

**Schema array pattern** (WorkloadApp.swift lines 22-39):
```swift
            let schema = Schema([
                Athlete.self,
                WorkoutSession.self,
                ExerciseEntry.self,
                SetRecord.self,
                WorkloadSnapshot.self,
                RecoverySnapshot.self,
                WellnessCheckIn.self,
                PersonalRecord.self,
                CoachAthleteRelationship.self,
                WorkoutTemplate.self,
                ExerciseGroup.self,
                TemplateExercise.self,
                TemplateSet.self,
                PrescribedWorkout.self,
                CustomExercise.self,
                BehaviorTag.self,
            ])
```

**Modification:** Add `TrainingProfile.self` to the schema array. Position does not matter for SwiftData, but for readability place it after `BehaviorTag.self` (or before `WorkoutTemplate.self` since it is a new standalone model).

---

### `Supabase/migrations/006_v1.2_foundation.sql` (migration, N/A) -- NEW

**Analog:** `Supabase/migrations/005_prescribed_workouts.sql`

**CREATE TABLE pattern** (005_prescribed_workouts.sql lines 4-14):
```sql
CREATE TABLE IF NOT EXISTS workout_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    coach_id UUID NOT NULL REFERENCES athletes(id) ON DELETE CASCADE,
    template_name TEXT NOT NULL,
    sport_type TEXT NOT NULL DEFAULT 'lifting',
    session_type TEXT NOT NULL DEFAULT 'strength',
    notes TEXT,
    groups_json TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

**RLS enable + policy pattern** (005_prescribed_workouts.sql lines 17-22):
```sql
ALTER TABLE workout_templates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Coaches manage own templates"
    ON workout_templates FOR ALL
    USING (coach_id IN (SELECT id FROM athletes WHERE user_id = auth.uid()))
    WITH CHECK (coach_id IN (SELECT id FROM athletes WHERE user_id = auth.uid()));
```

**ALTER TABLE additive column pattern** (not in existing migration, but standard PostgreSQL):
```sql
ALTER TABLE workout_templates
    ADD COLUMN IF NOT EXISTS is_athlete_owned BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS athlete_id UUID;
```

**Index pattern** (005_prescribed_workouts.sql lines 60-63):
```sql
CREATE INDEX idx_workout_templates_coach ON workout_templates(coach_id);
CREATE INDEX idx_prescribed_workouts_athlete ON prescribed_workouts(athlete_id);
```

**RLS indirect lookup pattern** (005_prescribed_workouts.sql line 21 + line 52):
```sql
-- For own-row access:
USING (coach_id IN (SELECT id FROM athletes WHERE user_id = auth.uid()))
-- For relationship-based access:
USING (athlete_id IN (SELECT id FROM athletes WHERE user_id = auth.uid()))
```

**Critical: athlete_id lookup** -- Per Pitfall 5 in RESEARCH.md, `training_profiles.athlete_id` stores the `Athlete.id` model UUID (NOT `auth.uid()`). RLS must use the indirect pattern: `athlete_id IN (SELECT id FROM athletes WHERE user_id = auth.uid())`.

---

## Shared Patterns

### Error Handling (try? swallow pattern)
**Source:** `WorkloadApp/Services/SyncService.swift` lines 52, 100-118, 147-149
**Apply to:** All SyncService push/pull methods for TrainingProfile
```swift
_ = try? await client.from("training_profiles").upsert(row).execute()
```
All sync operations use `try?` to suppress errors and continue -- this is an intentional design choice per existing SyncService pattern. No error propagation to callers.

### Repository ModelContext Init
**Source:** `WorkloadApp/Repositories/WorkoutRepository.swift` lines 5-11
**Apply to:** `TemplateRepository`
```swift
@MainActor
final class WorkoutRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
```
All repositories follow this exact pattern: `@MainActor final class`, `private let modelContext: ModelContext`, init takes `ModelContext`.

### Engine Pure Struct Pattern
**Source:** `WorkloadApp/Services/WorkloadCalculator.swift` lines 6-7, `WorkloadApp/Services/RecoveryScoreEngine.swift` line 18
**Apply to:** `ColdStartEngine`
```swift
struct WorkloadCalculator {
    // No stored properties, no init
    // All methods are static
    // Nested structs for input/output types
```
Engines are stateless structs with `static` methods only. No `@MainActor`, no dependencies, no instance creation.

### SwiftData Model Pattern
**Source:** `WorkloadApp/Models/WellnessCheckIn.swift` lines 4-6, `WorkloadApp/Models/RecoverySnapshot.swift` lines 4-6
**Apply to:** `TrainingProfile`
```swift
@Model
final class WellnessCheckIn {
    @Attribute(.unique) var id: UUID
```
All models: `@Model final class`, `@Attribute(.unique) var id: UUID`, `var updatedAt: Date`, init with `id: UUID = UUID()`.

### Codable Row Struct Pattern
**Source:** `WorkloadApp/Services/SyncService.swift` lines 904-926
**Apply to:** New `TrainingProfileRow` struct
```swift
struct WorkoutTemplateRow: Codable {
    let id: UUID
    // ... all fields as let ...
    init(from model: WorkoutTemplate) {
        self.id = model.id
        // ... map each field ...
    }
}
```
Row structs: `Codable`, all `let` properties, `init(from model:)` factory, enum raw values for string-based fields.

### Enum Declaration Pattern
**Source:** `WorkloadApp/Models/Enums.swift` lines 5-39
**Apply to:** `BodyRegion` enum
```swift
enum SportType: String, Codable, CaseIterable, Identifiable {
    case lifting
    // ...
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .lifting: "Lifting"
        // ...
        }
    }
}
```
All domain enums: conform to `String, Codable, CaseIterable, Identifiable`, include `id` and `displayName` computed properties.

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| (none) | -- | -- | All files have exact analogs in the existing codebase |

## Metadata

**Analog search scope:** `WorkloadApp/Models/`, `WorkloadApp/Services/`, `WorkloadApp/Repositories/`, `WorkloadApp/App/`, `Supabase/migrations/`
**Files scanned:** 12 existing files read for pattern extraction
**Pattern extraction date:** 2026-05-01
