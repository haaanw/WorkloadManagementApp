---
phase: 09-foundation-cold-start-engine
verified: 2026-05-02T07:00:00Z
status: human_needed
score: 4/5
overrides_applied: 0
human_verification:
  - test: "Deploy migration 006_v1.2_foundation.sql via `supabase db push` from project root"
    expected: "training_profiles table exists, workout_templates has new columns, 4 RLS policies active (2 on training_profiles, 2 on workout_templates), 2 indexes created"
    why_human: "supabase db push requires interactive confirmation or SUPABASE_ACCESS_TOKEN; automated execution was blocked at Plan 03 Task 3 checkpoint"
---

# Phase 9: Foundation & Cold-Start Engine — Verification Report

**Phase Goal:** All data models, pure computation engines, Supabase schema migrations, and RLS policies are in place so that cold-start and template features can be built without infrastructure blockers
**Verified:** 2026-05-02T07:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | TrainingProfile model persists questionnaire answers, seeded ATL/CTL, and bias fields locally via SwiftData and syncs to Supabase | VERIFIED | `TrainingProfile.swift` is a complete @Model with all 20 fields (athleteId UUID foreign key, 4 required questionnaire fields, 4 optional fields, seededATL/CTL/seededAt, 5 bias fields, coldStartCompletedAt, timestamps). TrainingProfile.self registered in WorkloadApp schema array. SyncService has pushTrainingProfile + pullTrainingProfile both registered in pushAll/pullAll. Migration file creates training_profiles table. Deployment pending (see human_verification). |
| 2 | WorkoutTemplate model accepts athlete ownership (isAthleteOwned, isFavorite, isArchived, lastUsedAt, usageCount, scheduledDays) with zero migration errors for existing users | VERIFIED | All 7 new fields added to WorkoutTemplate.swift with explicit defaults (Bool=false, UUID?=nil, Date?=nil, Int=0, [Int]=[]). Lightweight migration safe — no breaking changes to existing fields. WorkoutTemplateRow in SyncService extended to include all 7 fields; pullWorkoutTemplates maps them back. |
| 3 | ColdStartEngine computes seeded ATL/CTL from questionnaire inputs (sessions/week, avg duration, sRPE) using the sRPE TSS formula, producing values compatible with the existing EWMA chain | VERIFIED | ColdStartEngine.swift is a pure struct (no @MainActor, no SwiftData) with SeedInput and SeedResult nested types. computeSeed delegates to WorkloadCalculator.sessionTSS for TSS calculation. Implements dailyTSS = (sessionTSS * sessionsPerWeek) / 7.0, seededATL = dailyTSS * 7.0, seededCTL = dailyTSS * 28.0 * ramp where ramp = max(0.3, min(1.0, weeksAtLevel / 6.0)). RPE clamped to [1.0, 10.0]. Zero sessions/duration guard returns safe all-zero result. |
| 4 | TemplateRepository provides fetch, save, duplicate, archive, and delete operations filtered by athlete ownership | VERIFIED | TemplateRepository.swift is an @MainActor final class with 6 methods: fetchAthleteTemplates (filters isAthleteOwned==true, isArchived==false, sorted by updatedAt), fetchFavorites (adds isFavorite==true filter), save (insert + timestamp), duplicate (deep copy via deepCopyGroups(), sets isAthleteOwned=true), archive (sets isArchived=true), delete (permanent). All predicates correctly filter by athleteId. In pbxproj (4 references). |
| 5 | Supabase RLS policies allow athlete-owned template CRUD without breaking existing coach template policies | UNCERTAIN | Migration file 006_v1.2_foundation.sql is complete and correct: 4 CREATE POLICY statements (Athletes manage own training profile, Coaches read linked athlete profiles, Athletes manage own templates, Athletes read coach templates via relationship). All use indirect RLS lookup pattern (athlete_id IN SELECT from athletes WHERE user_id = auth.uid()). Existing "Coaches manage own templates" policy is additive — not replaced. HOWEVER: deployment to Supabase is pending (Plan 03 Task 3 was a human-action checkpoint). Cannot verify live DB state without human action. |

**Score:** 4/5 truths verified (1 uncertain pending deployment)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `WorkloadApp/Models/TrainingProfile.swift` | TrainingProfile @Model with questionnaire + seed + bias + cold-start fields | VERIFIED | 99 lines. Contains @Model, @Attribute(.unique) var id: UUID, athleteId UUID (not @Relationship), all D-07 through D-13 fields. In pbxproj (4 references). |
| `WorkloadApp/Models/WorkoutTemplate.swift` | Extended with athlete ownership and template management fields | VERIFIED | All 7 new fields (isAthleteOwned, athleteId, isFavorite, isArchived, lastUsedAt, usageCount, scheduledDays) with defaults. Existing coachId, templateName, etc. unchanged. |
| `WorkloadApp/Models/Enums.swift` | BodyRegion enum and InjuryEntry Codable struct | VERIFIED | enum BodyRegion: String, Codable, CaseIterable, Identifiable with 8 cases (shoulder, knee, back, hip, ankle, wrist, elbow, neck), displayName property. struct InjuryEntry: Codable with bodyRegion, notes, isActive. |
| `WorkloadApp/App/WorkloadApp.swift` | TrainingProfile.self in schema array | VERIFIED | Line 39: `TrainingProfile.self,` in schema array. |
| `WorkloadApp/Services/ColdStartEngine.swift` | Pure computation engine for cold-start ATL/CTL seeding | VERIFIED | 94 lines. struct ColdStartEngine with SeedInput, SeedResult, static computeSeed. Calls WorkloadCalculator.sessionTSS. All formula constants correct. In pbxproj (4 references). |
| `WorkloadApp/Repositories/TemplateRepository.swift` | Athlete-owned template CRUD repository | VERIFIED | 74 lines. @MainActor final class TemplateRepository with 6 methods. Correct predicate filtering. In pbxproj (4 references). |
| `WorkloadApp/Services/SyncService.swift` | TrainingProfileRow push/pull + extended WorkoutTemplateRow | VERIFIED | struct TrainingProfileRow: Codable with 21 fields and init(from: TrainingProfile). pushTrainingProfile + pullTrainingProfile defined and registered in pushAll (line 30) and pullAll (line 46). WorkoutTemplateRow extended with isAthleteOwned, athleteId, isFavorite, isArchived, lastUsedAt, usageCount, scheduledDays. pullWorkoutTemplates maps all new fields back to model. |
| `Supabase/migrations/006_v1.2_foundation.sql` | DB schema for training_profiles + workout_templates extensions + RLS | VERIFIED (file only) | 86 lines. Creates training_profiles with 20 columns + UNIQUE(athlete_id), enables RLS with 2 policies, extends workout_templates with 7 columns via ADD COLUMN IF NOT EXISTS, adds 2 athlete RLS policies, creates 2 indexes. NOT yet deployed to Supabase. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `WorkloadApp/Models/TrainingProfile.swift` | `WorkloadApp/Models/Enums.swift` | BodyRegion type used in InjuryEntry stored as Data on TrainingProfile | WIRED | TrainingProfile has `injuryHistory: Data?`; Enums.swift defines BodyRegion and InjuryEntry. InjuryEntry is Codable so it can be encoded as Data. |
| `WorkloadApp/App/WorkloadApp.swift` | `WorkloadApp/Models/TrainingProfile.swift` | schema array registration | WIRED | `TrainingProfile.self` present at line 39 of WorkloadApp.swift. |
| `WorkloadApp/Services/ColdStartEngine.swift` | `WorkloadApp/Services/WorkloadCalculator.swift` | calls WorkloadCalculator.sessionTSS(durationSeconds:sessionRPE:) | WIRED | Line 69: `WorkloadCalculator.sessionTSS(durationSeconds: durationSeconds, sessionRPE: clampedRPE)` — direct call. |
| `WorkloadApp/Repositories/TemplateRepository.swift` | `WorkloadApp/Models/WorkoutTemplate.swift` | SwiftData fetch predicates on isAthleteOwned + athleteId | WIRED | #Predicate uses `$0.isAthleteOwned == true && $0.athleteId == athleteId`. Relies on fields added in Plan 01. |
| `WorkloadApp/Services/SyncService.swift` | `Supabase/migrations/006_v1.2_foundation.sql` | Row struct fields must match Supabase column names | VERIFIED (structural) | TrainingProfileRow uses camelCase Swift properties with Codable — Supabase SDK handles snake_case mapping (typicalSrpe → typical_srpe, seededAtl → seeded_atl, etc.). Migration column names match. |
| `Supabase/migrations/006_v1.2_foundation.sql` | `WorkloadApp/Models/WorkoutTemplate.swift` | ALTER TABLE columns match model fields | WIRED | is_athlete_owned → isAthleteOwned, athlete_id → athleteId, is_favorite → isFavorite, is_archived → isArchived, last_used_at → lastUsedAt, usage_count → usageCount, scheduled_days → scheduledDays. All 7 columns align. |

### Data-Flow Trace (Level 4)

TemplateRepository and SyncService are data access layers, not UI rendering components. ColdStartEngine is a pure computation engine. TrainingProfile is a persistence model. None of these artifacts render dynamic data to the UI — they are infrastructure. Level 4 data-flow trace is not applicable for this phase. Phase 10 (questionnaire UI) and Phase 11 (template management UI) are the rendering consumers.

### Behavioral Spot-Checks

Step 7b: SKIPPED — Phase 9 delivers infrastructure (models, engine, repository, sync, migration). No runnable entry points are introduced. ColdStartEngine has no test harness yet, and TemplateRepository requires a live ModelContext. Full behavioral verification will occur when Phase 10 and Phase 11 UI layers exercise these components.

**Manual sanity check (from SUMMARY math):**
- Input: 4 sessions/week, 60min, RPE 6.0, 8 weeks at level
- sessionTSS = (60/60) * 6.0 * (6.0/10) = 1.0 * 6.0 * 0.6 = 3.6
- dailyTSS = (3.6 * 4) / 7 = 2.057
- seededATL = 2.057 * 7 = **14.4** (expected per plan Test 1)
- ramp = max(0.3, min(1.0, 8.0/6.0)) = min(1.0, 1.333) = 1.0
- seededCTL = 2.057 * 28 * 1.0 = **57.6** (expected per plan Test 1)
- Formula implementation matches expected values.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| FOUND-01 | 09-01, 09-03 | TrainingProfile model stores questionnaire answers, seeded ATL/CTL, and bias data with Supabase sync | SATISFIED | TrainingProfile.swift complete with all fields. SyncService pushTrainingProfile/pullTrainingProfile registered. Migration file creates table. Deployment pending. |
| FOUND-02 | 09-01 | WorkoutTemplate model extended with isAthleteOwned, isFavorite, isArchived, lastUsedAt, usageCount, scheduledDays fields (additive only, no renames) | SATISFIED | All 7 fields in WorkoutTemplate.swift with defaults. No existing fields modified or renamed. |
| FOUND-03 | 09-03 | Supabase RLS policies updated to allow athlete-owned template CRUD alongside existing coach policies | SATISFIED (file) / NEEDS DEPLOYMENT | Migration SQL defines 4 policies including athlete-facing policies. Indirect RLS pattern applied. Deployment pending. |
| FOUND-04 | 09-03 | TemplateRepository provides fetch, save, duplicate, archive, and delete operations for athlete-owned templates | SATISFIED | TemplateRepository.swift has all 6 required methods with correct athlete ownership filtering. |
| COLD-03 | 09-02 | ColdStartEngine computes seeded ATL/CTL from questionnaire answers using sRPE TSS formula (hours x RPE x RPE/10) | SATISFIED | ColdStartEngine.swift delegates to WorkloadCalculator.sessionTSS (which implements hours * RPE * RPE/10). Steady-state EWMA shortcut applied correctly. weeksAtLevel ramp factor implemented. |

No orphaned requirements: all 5 requirement IDs (FOUND-01, FOUND-02, FOUND-03, FOUND-04, COLD-03) claimed in plan frontmatter appear in REQUIREMENTS.md and are traced to Phase 9 in the Traceability table. No additional Phase 9 requirements exist in REQUIREMENTS.md beyond these 5.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `WorkloadApp/Services/SyncService.swift` | 752, 754 | `try?` suppresses sync errors silently | Info | Pre-existing architectural decision (T-09-09 in threat model — accepted risk). Sync failures are non-fatal; data remains local. Not introduced by this phase. |

No TODO/FIXME/placeholder comments found in any Phase 9 files. No empty implementations. No stubs. All new methods have complete implementations.

### Human Verification Required

#### 1. Deploy Supabase Migration 006

**Test:** From the project root, run `supabase db push` to deploy `Supabase/migrations/006_v1.2_foundation.sql`
**Expected:** Command succeeds. In Supabase SQL Editor, verify:
1. `SELECT * FROM information_schema.tables WHERE table_name = 'training_profiles';` returns 1 row
2. `SELECT column_name FROM information_schema.columns WHERE table_name = 'workout_templates' AND column_name = 'is_athlete_owned';` returns 1 row
3. `SELECT policyname FROM pg_policies WHERE tablename = 'training_profiles';` returns 2 policies: "Athletes manage own training profile" and "Coaches read linked athlete profiles"
4. `SELECT policyname FROM pg_policies WHERE tablename = 'workout_templates';` returns at least 4 policies (2 existing coach policies + 2 new athlete policies)
5. `SELECT count(*) FROM workout_templates;` returns the same count as before (existing data unaffected)
**Why human:** `supabase db push` requires interactive confirmation or `SUPABASE_ACCESS_TOKEN`. The executor reached this as a `checkpoint:human-action gate="blocking"` in Plan 03 Task 3. The migration file is complete and correct — only the deployment step is outstanding.

### Gaps Summary

No automated gaps found. All Swift artifacts exist, are substantive, and are correctly wired. The only outstanding item is migration deployment, which is a human-action checkpoint intentionally deferred to the developer. Once the migration is deployed and the verification checks above pass, all 5 roadmap success criteria will be fully satisfied.

---

_Verified: 2026-05-02T07:00:00Z_
_Verifier: Claude (gsd-verifier)_
