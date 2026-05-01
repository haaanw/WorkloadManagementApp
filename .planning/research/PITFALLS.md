# Domain Pitfalls

**Domain:** Cold-start questionnaire with ATL/CTL seeding, athlete-owned training templates, and integration with existing EWMA workload tracking
**Researched:** 2026-05-01

## Critical Pitfalls

Mistakes that cause data corruption, incorrect training recommendations, or require architectural rewrites.

### Pitfall 1: EWMA Initialization Bias from Questionnaire-Seeded ATL/CTL

**What goes wrong:** The cold-start questionnaire seeds initial ATL/CTL values, but these estimated values are injected into the same EWMA pipeline that computes real load. The EWMA decay formula `atl = atl * (1 - lambda) + tss * lambda` treats the seeded value as a genuine historical average. If the estimate is wrong (and self-reported training history is notoriously inaccurate due to recall bias), every subsequent EWMA calculation inherits and propagates this error. The seeded CTL (lambda=1/28) persists for approximately 84 days (3 time constants) before the estimate fully washes out.

**Why it happens:** EWMA has no "memory" concept -- it treats its current state as ground truth regardless of origin. Unlike a rolling average where old data drops off after N days, EWMA exponentially decays but never fully forgets. A badly seeded CTL of 200 (when real is 50) will still contribute ~5% error after 84 days.

**Consequences:**
- ACWR zone classification is wrong for weeks, producing incorrect autoregulation recommendations
- FatigueIndexEngine receives inflated/deflated load elevation scores
- AutoregulationEngine suggests inappropriate intensity caps and session types
- Athlete loses trust in the app's core value proposition (accurate readiness)

**Prevention:**
- The decision to use parallel data tracks (estimated vs real ATL/CTL) is correct and essential -- implement it rigorously
- The estimated track must be stored on `TrainingProfile`, NOT on `WorkloadSnapshot`
- `WorkloadSnapshot` must only ever contain EWMA values computed from actual logged sessions
- During cold-start period, the dashboard must show estimated values clearly labeled "Estimated" and never mix them into the real EWMA chain
- When the hybrid switchover occurs (3 weeks + 8 sessions), transition by seeding the real EWMA with the current estimated values PLUS real session data, not by retroactively modifying snapshots

**Detection:** Compare estimated ATL/CTL against real computed values after 8 sessions. If the ratio exceeds 2.0x or falls below 0.5x, the questionnaire answers were significantly off (expected for many users -- self-reported training load has 30-50% recall error in studies).

**Phase relevance:** Cold-start implementation (Phase 1 of milestone). This is the single most important architectural decision.

**Confidence:** HIGH -- based on EWMA mathematics, existing `WorkloadCalculator.computeHistoryEWMA` code review, and sport science literature on recall bias.

---

### Pitfall 2: WorkoutTemplate.coachId Field Semantics Collision

**What goes wrong:** The existing `WorkoutTemplate` model uses `coachId: UUID` as its owner field. The plan is to reuse this model for athlete-owned templates by interpreting `coachId` as a generic `ownerId`. However, the SyncService already has hardcoded assumptions about this field:
- `pushWorkoutTemplates` filters by `coachId == athlete.id`
- `pullWorkoutTemplates` fetches from Supabase with `.eq("coach_id", value: coachId)`
- The Supabase `workout_templates` table has a `coach_id` column with RLS policies tied to the coach role

Simply reusing `coachId` for athletes means:
1. Athlete-created templates are pushed to Supabase as `coach_id = athlete.id`
2. RLS policies designed for coach access may block athlete reads/writes
3. When a coached athlete creates their own templates, there is ambiguity: which templates belong to the coach's library vs the athlete's personal templates?
4. Coach-side sync may accidentally pull athlete templates (or vice versa)

**Why it happens:** The field name `coachId` was semantic -- it meant "the coach who created this." Repurposing it as "whoever owns this" breaks the semantic contract without changing the field name, leading to bugs that are hard to catch in code review.

**Consequences:**
- Supabase RLS violations: athlete templates fail to sync silently (SyncService uses `try?` which swallows errors)
- Coach pulls athlete's personal templates into their template library
- Athlete templates disappear after sync because RLS denies the upsert
- Data loss is silent due to the `try?` error suppression pattern in SyncService

**Prevention:**
- Rename the field from `coachId` to `ownerId` on the model. This is a SwiftData schema change requiring migration.
- Add an `ownerType` field (enum: `.athlete`, `.coach`) to disambiguate template ownership
- Update Supabase table: rename column `coach_id` to `owner_id`, add `owner_type` column
- Update RLS policies to allow athletes to CRUD their own templates (where `owner_id = auth.uid()` AND `owner_type = 'athlete'`)
- Update all SyncService template push/pull methods to handle both ownership types
- Alternatively: keep `coachId` but add a separate `isAthleteOwned: Bool` flag. Less clean but avoids SwiftData migration complexity.

**Detection:** After implementing template sync, test the following scenario: (1) Coach creates template, (2) Athlete creates template, (3) Both sync, (4) Coach views templates -- should NOT see athlete's templates. (5) Athlete views templates -- should see only their own, plus any prescribed by coach.

**Phase relevance:** Template model phase. Must be addressed before any template CRUD is built.

**Confidence:** HIGH -- directly verified in `WorkoutTemplate.swift` (line 9: `var coachId: UUID`) and `SyncService.swift` (lines 696-738: template push/pull filtering on `coachId`).

---

### Pitfall 3: SwiftData Schema Migration Crash on App Update

**What goes wrong:** Adding `TrainingProfile` as a new `@Model` class and modifying `WorkoutTemplate` (adding fields like `ownerId`, `lastUsedDate`, `isFavorite`, `isArchived`) requires a SwiftData schema migration. The existing app does NOT use `VersionedSchema` -- it passes a raw `Schema` array to `ModelContainer`. When an existing user updates from v1.1 to v1.2:
- Adding a new model (`TrainingProfile`) is a lightweight migration -- SwiftData handles this automatically
- Adding new stored properties with defaults to existing models is also lightweight
- BUT renaming `coachId` to `ownerId` is NOT a lightweight migration -- it requires a custom `SchemaMigrationPlan`
- Without a migration plan, the app will crash on launch with `"Failed to create ModelContainer"` -- which hits the existing `fatalError()` in `WorkloadApp.swift` line 43

**Why it happens:** SwiftData's lightweight migration can handle additive changes (new models, new optional properties, new properties with defaults) but cannot handle renames, type changes, or relationship restructuring. The app currently uses no `VersionedSchema` at all, meaning there is zero migration infrastructure.

**Consequences:** App crashes on launch for every existing user who updates. Since this hits a `fatalError`, there is no recovery path -- the user must delete and reinstall, losing all local data.

**Prevention:**
- Option A (recommended): Do NOT rename `coachId` to `ownerId`. Instead, keep `coachId` and add new fields (`isAthleteOwned: Bool = false`, `lastUsedDate: Date?`, `isFavorite: Bool = false`, `isArchived: Bool = false`). All new fields must have defaults. This stays within lightweight migration.
- Option B: Implement `VersionedSchema` with a migration plan. Define `SchemaV1` (current schema) and `SchemaV2` (new schema). Write a `SchemaMigrationPlan` that maps `coachId` to `ownerId`. This is significant implementation complexity and requires testing on devices with real v1.1 data.
- Regardless of option: Add `TrainingProfile.self` to the schema array in `WorkloadApp.swift` (currently lines 22-39). Missing this causes a crash.
- Test migration by: (1) building v1.1, (2) populating data, (3) updating to v1.2, (4) verifying no crash and data preserved.

**Detection:** Build v1.2, install on a device/simulator that already has v1.1 data. If the app crashes on launch, migration is broken. This MUST be tested before App Store submission.

**Phase relevance:** Model creation phase (first phase). Must be decided before writing any model code.

**Confidence:** HIGH -- verified that `WorkloadApp.swift` uses no `VersionedSchema`, confirmed by checking lines 22-43. SwiftData migration behavior documented in Apple's WWDC23/25 sessions and community guides.

---

### Pitfall 4: Parallel Track Contamination via WorkoutPipeline

**What goes wrong:** The existing `WorkoutPipeline.processSession()` computes EWMA from real sessions and writes to `WorkloadSnapshot`. During cold-start, estimated ATL/CTL values need to be shown on the dashboard. If the estimated values are written to `WorkloadSnapshot` (even temporarily), they permanently contaminate the real EWMA chain because:
1. `computeHistoryEWMA` rebuilds from `WorkloadSnapshot` data
2. `WorkloadRepository.upsertSnapshot` overwrites today's snapshot
3. `DashboardViewModel.load()` reads the latest `WorkloadSnapshot` -- it does not distinguish estimated from real

The moment a real session is logged, the pipeline reads the contaminated snapshot as "previous ATL/CTL" and propagates the error forward.

**Why it happens:** The data architecture was designed for a single source of truth (real sessions). The parallel track is a new concept that doesn't fit the existing write path.

**Consequences:**
- Estimated values leak into real workload history
- Charts show discontinuities at switchover
- Bias metric (estimated vs actual comparison at 8 weeks) is meaningless because both tracks are contaminated

**Prevention:**
- Estimated ATL/CTL must live ONLY on `TrainingProfile` (never on `WorkloadSnapshot`)
- `DashboardViewModel.load()` must be modified to: (1) check if athlete is in cold-start period, (2) if yes, display estimated values from `TrainingProfile` instead of from `WorkloadSnapshot`, (3) if no, display real values from `WorkloadSnapshot` as before
- `WorkoutPipeline.processSession()` must NOT be modified to use estimated values as seed -- it should always start EWMA from 0 with real sessions only
- The switchover logic must live in a new `ColdStartEngine` or similar, NOT in the existing pipeline

**Detection:** After implementing cold-start, log 3 sessions. Check `WorkloadSnapshot` records: they should reflect EWMA computed only from those 3 sessions (ATL/CTL near 0 for first session). If values are higher, contamination has occurred.

**Phase relevance:** Cold-start implementation phase. Must be enforced during both cold-start engine and dashboard modifications.

**Confidence:** HIGH -- directly traced through `WorkoutPipeline.processSession()` (lines 33-38: fetches 35 days of sessions, builds daily loads), `WorkloadRepository.upsertSnapshot()` (overwrites today's snapshot), and `DashboardViewModel.load()` (lines 140-149: reads latest snapshot).

---

## Moderate Pitfalls

Mistakes that cause user confusion, reduced trust, or significant rework.

### Pitfall 5: Questionnaire Length Kills Onboarding Completion

**What goes wrong:** The cold-start questionnaire is designed with 4 required + 4 optional questions. Combined with the existing 3-step onboarding (frequency, experience, HealthKit), new users face 7-11 screens before seeing their first dashboard. Research consistently shows that fitness app users decide whether to stay within the first 20 seconds to 3 minutes. Each additional screen reduces completion rate by 10-20%.

**Why it happens:** Each question feels necessary from a data perspective (every answer improves the estimate), but the cumulative friction compounds. The existing onboarding already asks training frequency and experience level -- questions that overlap with what the cold-start questionnaire needs.

**Consequences:**
- Drop-off during onboarding: users who never reach the dashboard never log a workout
- Users who skip optional questions get worse estimates, defeating the purpose
- The app feels academic rather than action-oriented

**Prevention:**
- Merge the cold-start questionnaire INTO the existing onboarding flow, replacing/extending the existing 2 steps (frequency + experience) rather than adding a separate flow
- The existing frequency and experience questions ARE cold-start data -- reuse them directly as inputs to the ATL/CTL estimation
- Keep the total to 4-5 screens maximum: (1) training frequency (already exists), (2) experience level (already exists), (3) typical session duration + intensity (new, combines 2 questions into 1), (4) HealthKit permission (already exists), (5) optional sport-specific detail (skippable)
- Show immediate value after: "Based on your answers, here's your estimated training profile" -- a mini dashboard preview

**Detection:** Track onboarding completion rate. If it drops below 80%, the flow is too long.

**Phase relevance:** Questionnaire design phase.

**Confidence:** MEDIUM -- based on fitness app UX research and the existing `OnboardingView.swift` flow analysis.

---

### Pitfall 6: ExerciseGroup Shared Between Template and Prescription Causes Cascade Deletion Bugs

**What goes wrong:** `ExerciseGroup` currently has TWO optional parent relationships: `template: WorkoutTemplate?` and `prescription: PrescribedWorkout?`. When athlete templates reuse this model, a single `ExerciseGroup` instance could theoretically be shared between a template and a prescribed workout (if the code doesn't properly deep-copy). If the template is deleted, `deleteRule: .cascade` on `WorkoutTemplate.groups` deletes the shared `ExerciseGroup`, which orphans the prescription's reference.

More subtly: when creating an athlete template from a completed session ("save-as-template"), the code must deep-copy exercise data from `ExerciseEntry`/`SetRecord` (session models) into `ExerciseGroup`/`TemplateExercise`/`TemplateSet` (template models). These are completely different model hierarchies. A shallow reference or incorrect relationship assignment will crash or corrupt data.

**Why it happens:** SwiftData cascade delete follows relationship graphs. The dual-parent pattern on `ExerciseGroup` creates an implicit data dependency that is easy to violate.

**Consequences:**
- Deleting a template crashes the app if groups are shared with a prescription
- "Save from session" creates template with orphaned or nil exercise data
- SwiftData relationship resolution fails silently, showing empty template groups

**Prevention:**
- The existing `deepCopyGroups()` method on `WorkoutTemplate` is the right pattern. ALWAYS use it for any operation that copies template structure.
- For "save-from-session": create a new `SessionToTemplateConverter` engine (pure struct) that maps `ExerciseEntry` -> `TemplateExercise` and `SetRecord` -> `TemplateSet`. Never try to reuse session model instances.
- For athlete templates: when a template is created, its `ExerciseGroup` instances must have `template` set and `prescription` nil. Never share instances across parents.
- Write a unit test that: (1) creates template with groups, (2) duplicates template, (3) deletes original, (4) verifies copy's groups still exist.

**Detection:** In DEBUG builds, add assertions in `ExerciseGroup` that either `template != nil` XOR `prescription != nil` (never both, never neither). If both are set, log a warning.

**Phase relevance:** Template CRUD phase. Must be enforced when building save-from-session and template duplication.

**Confidence:** HIGH -- verified in `WorkoutTemplate.swift` (line 86: `var template: WorkoutTemplate?`, line 87: `var prescription: PrescribedWorkout?`) and `PrescribedWorkout.swift` (line 24: `@Relationship(deleteRule: .cascade)`).

---

### Pitfall 7: TemplateSuggestionEngine Day-of-Week Table Gives Bad Suggestions Early

**What goes wrong:** The TemplateSuggestionEngine uses a day-of-week frequency table to suggest templates. In the first 2-3 weeks, the frequency table has so few data points that suggestions are essentially random. Worse, if a user happens to do "Leg Day" on Monday in week 1 and "Upper Body" on Monday in week 2, the engine concludes "Monday = Leg Day AND Upper Body" with equal confidence. This creates noisy, unhelpful suggestions that erode trust in the intelligence features.

**Why it happens:** Frequency-based pattern detection requires statistical significance. With N=1 or N=2 observations per day slot, every pattern is noise.

**Consequences:**
- Wrong template suggested prominently on dashboard -- user ignores suggestions permanently
- User who rejects suggestions repeatedly trains the system that "suggestions are always wrong" (negative feedback loop)
- Feature appears broken rather than data-insufficient

**Prevention:**
- Require a minimum threshold before showing suggestions: at least 3 weeks of data AND 2+ occurrences of the same template on the same day-of-week
- Below threshold, show "Quick Start" cards with recently used templates instead of "Suggested for today"
- Use recency weighting: last 4 weeks count more than weeks 5-8. This prevents stale patterns from persisting.
- Label early suggestions with lower confidence: "You often train on Mondays" vs "Based on your pattern, try Leg Day"
- FatigueIndex "insufficient data" pattern already exists -- follow the same gating approach

**Detection:** If suggestion acceptance rate (user picks suggested template) is below 20% after 4 weeks, the engine is not useful yet.

**Phase relevance:** Template suggestion engine phase (later phase). Non-critical early but should be designed for graceful degradation from the start.

**Confidence:** MEDIUM -- based on pattern recognition data sufficiency principles. No direct sport science source, but analogous to PeriodizationEngine.checkSufficiency pattern already in codebase.

---

### Pitfall 8: Dynamic Template Targets Conflict with ProgressionEngine Suggestions

**What goes wrong:** The plan calls for two overlapping systems:
1. Dynamic targets: templates auto-update to last-used values (e.g., last bench press was 80kg x 8, so template shows 80kg x 8)
2. ProgressionEngine overlay: recovery-aware suggestions that may increase, maintain, or deload (e.g., ProgressionEngine says "deload to 70kg today")

If both run independently, the template shows "80kg x 8" (from last-used) but the ProgressionEngine badge says "try 70kg" (recovery-based deload). The user sees contradictory information on the same screen.

**Why it happens:** These are two different optimization goals: (1) "what did I do last time" (historical) vs (2) "what should I do today" (recovery-aware). Both are valid but must be layered, not competing.

**Consequences:**
- User confusion: "Which number should I follow?"
- Users ignore ProgressionEngine suggestions because template targets "look right"
- During deload periods, templates suggest too much weight -- exactly when the athlete should be going lighter

**Prevention:**
- Make it explicit that the template target IS the last-used value (static baseline) and the ProgressionEngine IS the intelligent adjustment
- UI design: show template targets as the "plan" and ProgressionEngine as the "adjustment" modifier (e.g., "80kg --> 70kg (recovery deload)")
- When displaying templates, ALWAYS apply the ProgressionEngine overlay as the final step before showing to the user (if Pro)
- For free users: show only template targets (last-used). For Pro: show adjusted targets with explanation.
- Never store ProgressionEngine suggestions back into the template -- they are ephemeral, computed per-session

**Detection:** Review the template display code: if template targets and progression suggestions render in separate, non-connected UI components, this confusion will manifest.

**Phase relevance:** Dynamic targets + ProgressionEngine overlay phase (later phase). Design the data flow early.

**Confidence:** HIGH -- based on existing `ProgressionEngine.suggest()` code review (returns `ExerciseSuggestion` with `suggestedSets` and `rationale`) and the milestone context describing both features.

---

### Pitfall 9: HealthKit Workout Import and Template Matching False Positives

**What goes wrong:** The plan includes "HealthKit workout detection to template matching." The existing `WorkoutImportBanner` detects unmatched HealthKit workouts and offers to import them. The new feature would auto-match imported workouts to templates (e.g., "This looks like your Upper Body template"). However, HealthKit workout data is sparse: it provides activity type, duration, calories, and optionally heart rate. It does NOT provide exercise names, sets, reps, or weights. Matching a HealthKit "Traditional Strength Training" workout to a specific template based only on duration and activity type will produce many false positives.

**Why it happens:** HealthKit is designed for aggregate workout tracking, not exercise-level logging. The semantic gap between "45-minute strength session" and "Upper Body: Bench 4x8, Rows 4x10, OHP 3x8" is too wide for reliable matching.

**Consequences:**
- Template matched to wrong workout: user's last-used values get overwritten with incorrect data
- Template suggestion engine learns wrong day-of-week patterns
- If auto-matching triggers template target updates, the athlete's template degrades over time

**Prevention:**
- Do NOT auto-match HealthKit workouts to templates. Instead:
  - When importing a HealthKit workout, suggest it as a "session log" (the existing import flow)
  - After the user manually selects a template for their next session, offer to link the HealthKit import to that template as a usage record
  - Template matching should only work for sessions logged WITHIN the app (where exercise data exists)
- If matching is desired, require a minimum of 3 matching criteria: (1) activity type matches template sport type, (2) duration within 20% of template average, (3) day-of-week matches pattern. Even then, present as a suggestion, not an auto-link.
- Never update template last-used values from a HealthKit-imported session -- only from sessions logged through the template flow

**Detection:** If template matching runs on HealthKit imports, check the match confidence distribution. If >50% of matches have low confidence, the feature is creating noise.

**Phase relevance:** Template matching phase. Can be deferred or simplified to "recently used" rather than "pattern matched."

**Confidence:** HIGH -- verified that `WorkoutImportSuggestion` (lines 91-181 in WorkoutImportBanner.swift) contains only `sportType`, `durationSeconds`, `activeCalories`, `distanceMeters` -- no exercise-level data.

---

### Pitfall 10: Supabase RLS Policies Not Updated for Athlete Template Ownership

**What goes wrong:** The existing Supabase `workout_templates` table has RLS policies designed for coach ownership. When athletes create templates, the sync upsert to `workout_templates` will fail silently because:
1. The RLS INSERT policy likely requires `coach_id = auth.uid()` AND the user has the coach role
2. Athletes do not have the coach role in the auth context
3. The SyncService uses `try?` for all Supabase operations, swallowing the RLS denial

The template appears to save locally (SwiftData succeeds) but never reaches Supabase. When the user logs into a new device, their templates are gone.

**Why it happens:** RLS policies are invisible to the app code. The SyncService pattern of silent error suppression (`try?`) means RLS denials produce no user-visible error and no developer-visible log.

**Consequences:**
- Athlete templates never sync to Supabase
- Data loss on device change/reinstall
- Coach templates sync fine, creating an inconsistent experience
- Bug is invisible during development (local SwiftData always works)

**Prevention:**
- Before writing any template code, update Supabase RLS policies:
  ```sql
  -- Allow owner (coach OR athlete) to manage their own templates
  CREATE POLICY "owner_templates" ON workout_templates
  FOR ALL USING (owner_id = auth.uid());
  ```
- Add a `SyncService` diagnostic: for template sync specifically, use `try await` (not `try?`) and log failures. Template sync failure should be surfaced as a non-blocking warning.
- Test sync with both coach and athlete accounts in Supabase
- If using the `isAthleteOwned` flag approach (Pitfall 3), the RLS policy must be: `(coach_id = auth.uid() AND NOT is_athlete_owned) OR (coach_id = auth.uid() AND is_athlete_owned)`

**Detection:** After implementing template sync, create a template as an athlete. Check Supabase dashboard: if the row is not in `workout_templates`, RLS is blocking it.

**Phase relevance:** Template model + sync phase. Must be addressed alongside model changes.

**Confidence:** HIGH -- verified SyncService pushWorkoutTemplates (line 696-700) uses `try?` and filters on `coachId`.

---

## Minor Pitfalls

### Pitfall 11: Bias Metric (8-Week Comparison) Not Useful If Switchover Already Happened

**What goes wrong:** The plan captures a silent bias metric at 8 weeks: comparing estimated ATL/CTL from the questionnaire against actual computed values. However, the hybrid switchover threshold is 3 weeks + 8 sessions. For an athlete training 3-4x/week, switchover happens around week 2-3. By week 8, the estimated values have been dormant for 5+ weeks and the real values have fully stabilized. The comparison is between a stale estimate and a mature EWMA -- it measures questionnaire accuracy at a single historical point, not ongoing bias.

**Prevention:**
- Capture the bias comparison at the moment of switchover (when the system transitions from estimated to real), not at a fixed 8-week mark
- Store both the estimated and real ATL/CTL at switchover time on `TrainingProfile` for later analysis
- The 8-week mark can still be used as a secondary checkpoint, but the primary comparison should be at switchover

**Phase relevance:** Cold-start engine phase.

---

### Pitfall 12: Template "Favorite" and "Archive" State Not Synced Creates Inconsistency

**What goes wrong:** If `isFavorite` and `isArchived` are added as local-only flags (not synced to Supabase), the user's template organization is lost on device change. If they ARE synced, the Supabase schema needs new columns and the sync row struct (`WorkoutTemplateRow`) needs updating.

**Prevention:**
- Decide sync strategy upfront: these fields SHOULD sync (they represent meaningful user intent)
- Add `is_favorite` and `is_archived` columns to Supabase `workout_templates` table
- Update `WorkoutTemplateRow` struct in SyncService to include these fields
- Include in the same Supabase migration that adds `owner_type` / `is_athlete_owned`

**Phase relevance:** Template management phase.

---

### Pitfall 13: Cold-Start Estimated Values Confuse the FatigueIndexEngine

**What goes wrong:** `FatigueIndexEngine` uses `baselineSessionTSS` (from 90-day average) and `sessionsIn14Days` as inputs. During cold-start, there is no real session history. If the cold-start estimated ATL/CTL are passed as FatigueIndex inputs, the engine will compute a fatigue score based on imaginary data.

**Prevention:**
- During cold-start period, FatigueIndex should show "Insufficient Data" (the `FatigueZone` already supports this conceptually, though no explicit "noData" case exists)
- Add a `hasRealData` check in `DashboardViewModel.load()` before computing fatigue -- use session count as the gate (minimum 5 sessions)
- This aligns with the existing pattern: `PeriodizationEngine.checkSufficiency` gates periodization detection behind data thresholds

**Phase relevance:** Cold-start engine integration with dashboard.

---

### Pitfall 14: Save-From-Session Template Captures Workout-Specific Data as Template Defaults

**What goes wrong:** When saving a template from a completed session, the code must decide which data to carry over. If it naively copies ALL set data (including the specific weights/reps performed that day), the template targets become "what I did on a particular day" rather than "what I normally do." If the session was a deload day, the template targets are permanently low. If it was a PR day, they are permanently high.

**Prevention:**
- When creating a template from a session, copy exercise structure (names, categories, set count) but treat weight/rep values as initial defaults that the user can edit before saving
- Show a confirmation/edit screen: "Save as template? Review the target values:" with editable fields
- Mark these as `targetWeightKg`, `targetReps` etc. (which TemplateSet already has) -- NOT as "last performed"
- The "last-used" auto-update mechanism is a separate feature that runs after subsequent sessions -- the save-from-session is just the initial creation

**Phase relevance:** Save-from-session implementation phase.

---

### Pitfall 15: Existing Coach Template Queries Break When Athletes Also Own Templates

**What goes wrong:** Any existing code that queries ALL `WorkoutTemplate` records will now return both coach templates AND athlete templates. If coach-mode views show "Your Templates" using an unfiltered `@Query`, athlete templates leak into the coach view (and vice versa).

**Prevention:**
- Audit every `@Query` and `FetchDescriptor` for `WorkoutTemplate` in the codebase
- Add ownership filters to ALL template queries: `#Predicate { $0.coachId == currentUserId }` (or equivalent with the new ownership field)
- Coach template views should filter by `isAthleteOwned == false` (or `ownerType == .coach`)
- Athlete template views should filter by `coachId == athleteId` AND `isAthleteOwned == true`
- The existing coach template picker for prescriptions must continue to show ONLY coach-owned templates

**Detection:** In coach mode, check if any athlete-created templates appear in the template list. In athlete mode, check if any coach-created templates appear (unless prescribed).

**Phase relevance:** Template model phase -- same phase as ownership model changes.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| TrainingProfile model | SwiftData migration crash (Pitfall 3) | Use additive-only schema changes, no renames. Add TrainingProfile.self to schema array. |
| Cold-start questionnaire UI | Onboarding friction (Pitfall 5) | Merge into existing onboarding flow. Maximum 5 screens total. |
| Cold-start ATL/CTL seeding | EWMA contamination (Pitfalls 1, 4) | Estimated values on TrainingProfile only. Never write to WorkloadSnapshot. |
| Cold-start dashboard display | FatigueIndex confusion (Pitfall 13) | Gate FatigueIndex behind real session count. Show "Estimated" label. |
| Template model changes | coachId semantics (Pitfall 2), cascade delete (Pitfall 6) | Add isAthleteOwned flag instead of renaming. Always deep-copy groups. |
| Template CRUD | Coach query breakage (Pitfall 15) | Add ownership filter to every template query. Audit all existing queries. |
| Save-from-session | Atypical day captured as default (Pitfall 14) | Show editable confirmation before saving template. |
| Template sync | RLS denial (Pitfall 10), state sync (Pitfall 12) | Update Supabase RLS and columns FIRST. |
| TemplateSuggestionEngine | Noisy early suggestions (Pitfall 7) | Minimum 3-week data gate. Show "recent" not "suggested" when insufficient. |
| Dynamic targets + Progression | Conflicting numbers (Pitfall 8) | Template = baseline, Progression = modifier. Layer, don't compete. |
| HealthKit template matching | False positives (Pitfall 9) | No auto-match from HealthKit. Manual link only. |
| Bias metric | Timing mismatch (Pitfall 11) | Capture at switchover, not fixed 8 weeks. |

## Sources

- EWMA initialization bias: [Exponentially Weighted Moving Average Theory](https://towardsdatascience.com/time-series-from-scratch-exponentially-weighted-moving-averages-ewma-theory-and-implementation-607661d574fe/)
- Self-reported training load recall bias: [ACWR Systematic Review (PMC)](https://pmc.ncbi.nlm.nih.gov/articles/PMC12487117/)
- SwiftData migration patterns: [Unauthorized Guide to SwiftData Migrations](https://atomicrobot.com/blog/an-unauthorized-guide-to-swiftdata-migrations/)
- SwiftData VersionedSchema: [Donny Wals Deep Dive](https://www.donnywals.com/a-deep-dive-into-swiftdata-migrations/)
- Fitness app onboarding friction: [MadAppGang Fitness App Design](https://madappgang.com/blog/the-best-fitness-app-design-examples-and-typical-mistakes/)
- Fitness app first 3 minutes: [Dataconomy UX Practices 2025](https://dataconomy.com/2025/11/11/best-ux-ui-practices-for-fitness-apps-retaining-and-re-engaging-users/)
- Codebase verification: `WorkoutTemplate.swift`, `WorkloadCalculator.swift`, `WorkoutPipeline.swift`, `SyncService.swift`, `FatigueIndexEngine.swift`, `DashboardViewModel.swift`, `OnboardingView.swift`, `WorkloadApp.swift` (all verified via direct code read)
