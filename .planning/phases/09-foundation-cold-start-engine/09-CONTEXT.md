# Phase 9: Foundation & Cold-Start Engine - Context

**Gathered:** 2026-05-01
**Status:** Ready for planning

<domain>
## Phase Boundary

All data models, pure computation engines, Supabase schema migrations, and RLS policies needed for cold-start (Phase 10) and template features (Phases 11-12). No UI work in this phase -- only foundation infrastructure.

</domain>

<decisions>
## Implementation Decisions

### Template Ownership Model
- **D-01:** Add `isAthleteOwned: Bool = false` and `athleteId: UUID? = nil` to WorkoutTemplate. Keep existing `coachId` untouched. Athlete templates filtered by `isAthleteOwned=true && athleteId==me`. Coach templates filtered by `isAthleteOwned=false && coachId==coach`.
- **D-02:** Also add to WorkoutTemplate: `isFavorite: Bool = false`, `isArchived: Bool = false`, `lastUsedAt: Date? = nil`, `usageCount: Int = 0`, `scheduledDays: [Int] = []` (ISO 8601 weekdays 1=Mon...7=Sun).
- **D-03:** Save-as-template (Phase 11) always creates athlete-owned template regardless of whether session was coach-prescribed. Athlete owns their template library.

### Cold-Start Seeding Logic
- **D-04:** ColdStartEngine uses steady-state EWMA shortcut -- compute representative daily TSS from questionnaire inputs (sessions/week x avgSessionTSS / 7), then: `seededCTL = dailyTSS / ctlLambda`, `seededATL = dailyTSS / atlLambda`. No synthetic day-by-day history generation.
- **D-05:** Factor in `weeksAtLevel` as CTL discount: `ramp = max(0.3, min(1.0, weeksAtLevel / 6.0))`. Apply to CTL only. ATL unchanged (adapts fast). Athletes who recently changed programs get lower CTL seed.
- **D-06:** Session TSS uses existing formula: `WorkloadCalculator.sessionTSS(durationSeconds:sessionRPE:)` = hours x RPE x (RPE/10).

### TrainingProfile Field Design
- **D-07:** Standalone `TrainingProfile` model (not on Athlete). One-to-one with athlete via `athleteId: UUID`.
- **D-08:** Required questionnaire fields: `sessionsPerWeek: Int`, `avgDurationMinutes: Int`, `typicalSRPE: Double` (1-10), `weeksAtLevel: Int`.
- **D-09:** Optional questionnaire fields: `trainingAgeYears: Int?`, `periodizationPreference: String?` (steady/periodized), `movementTypes: [String]?`, `injuryHistory: Data?` (JSON-encoded `[InjuryEntry]`).
- **D-10:** InjuryEntry is a Codable struct with `bodyRegion: BodyRegion` (enum: shoulder, knee, back, hip, ankle, wrist, elbow, neck), `notes: String?`, `isActive: Bool`.
- **D-11:** Seeded values stored on TrainingProfile: `seededATL: Double`, `seededCTL: Double`, `seededAt: Date`.
- **D-12:** Bias fields captured at 8-week mark: `biasEstimatedATL: Double?`, `biasEstimatedCTL: Double?`, `biasActualATL: Double?`, `biasActualCTL: Double?`, `biasCapturedAt: Date?`. Bias ratio computed (not stored).
- **D-13:** Cold-start window tracking: `coldStartCompletedAt: Date?` (nil = still in cold-start), set when switchover threshold met (3wk + 8 sessions).

### Migration & RLS Strategy
- **D-14:** Single Supabase migration file (`v1.2_foundation.sql`) covering: ALTER TABLE workout_templates (additive columns), CREATE TABLE training_profiles, new RLS policies.
- **D-15:** Athlete RLS on workout_templates: SELECT allows own templates (isAthleteOwned=true + athleteId=me) AND coach-assigned templates (via coach_athlete_relationships join). INSERT/UPDATE/DELETE restricted to isAthleteOwned=true + athleteId=me.
- **D-16:** Existing coach RLS policies remain unchanged. New athlete policies are additive.
- **D-17:** training_profiles RLS: athlete can CRUD only their own row (athleteId=auth.uid()). Coach can SELECT linked athletes' profiles (via relationship join).

### Claude's Discretion
- TemplateRepository method signatures and internal implementation details
- Exact Supabase column types and constraints (within the decided schema shape)
- ColdStartEngine struct organization and helper methods
- SwiftData model registration order in WorkloadApp.swift schema array

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Models & Architecture
- `WorkloadApp/Models/WorkoutTemplate.swift` -- Existing template model to extend (contains ExerciseGroup, TemplateExercise, TemplateSet)
- `WorkloadApp/Services/WorkloadCalculator.swift` -- sessionTSS formula and EWMA constants (atlLambda=1/7, ctlLambda=1/28)
- `WorkloadApp/Models/Enums.swift` -- All domain enums (SportType, SessionType, ExerciseCategory, MuscleGroup)
- `.planning/codebase/ARCHITECTURE.md` -- Layer stack and patterns

### Requirements
- `.planning/REQUIREMENTS.md` -- FOUND-01 through FOUND-04 + COLD-03
- `.planning/ROADMAP.md` -- Phase 9 success criteria

### Research
- `.planning/research/ARCHITECTURE.md` -- Component inventory (new vs modified files)
- `.planning/research/PITFALLS.md` -- SwiftData migration risks, RLS silent failures

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `WorkloadCalculator.sessionTSS()` -- ColdStartEngine calls this for avg session TSS computation
- `WorkloadCalculator` EWMA constants (`atlLambda`, `ctlLambda`) -- ColdStartEngine uses same constants for steady-state calculation
- `WorkoutTemplate` + `ExerciseGroup` + `TemplateExercise` + `TemplateSet` -- Existing model hierarchy, additive fields only
- `SyncService` push/pull pattern -- Follow same pattern for TrainingProfile sync
- Repository pattern (`AthleteRepository`, `WorkoutRepository`) -- Follow for `TemplateRepository`

### Established Patterns
- Pure struct engines with static methods (WorkloadCalculator, RecoveryScoreEngine) -- ColdStartEngine follows this
- `@MainActor final class` repositories with `ModelContext` init -- TemplateRepository follows this
- `@Model final class` with `@Attribute(.unique) var id: UUID` -- TrainingProfile follows this
- Codable structs for JSON-encoded complex fields -- InjuryEntry follows this pattern

### Integration Points
- `WorkloadApp.swift` schema array -- Add TrainingProfile to ModelContainer registration
- `SyncService` -- Add pushTrainingProfile/pullTrainingProfile methods
- `AppContainer` -- May need TemplateRepository instance (or defer to Phase 11 views)

</code_context>

<specifics>
## Specific Ideas

- Steady-state EWMA math: `CTL = dailyTSS / (1/28) = dailyTSS * 28`, `ATL = dailyTSS / (1/7) = dailyTSS * 7`
- CTL discount ramp: `max(0.3, min(1.0, weeksAtLevel / 6.0))` -- floor at 0.3 so seed is never zero
- BodyRegion enum cases: shoulder, knee, back, hip, ankle, wrist, elbow, neck
- scheduledDays uses ISO 8601 weekday numbering: 1=Monday through 7=Sunday

</specifics>

<deferred>
## Deferred Ideas

None -- discussion stayed within phase scope

</deferred>

---

*Phase: 09-foundation-cold-start-engine*
*Context gathered: 2026-05-01*
