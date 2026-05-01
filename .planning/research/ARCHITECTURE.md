# Architecture Patterns

**Domain:** Cold-start questionnaire + athlete-owned training templates for iOS fitness app
**Researched:** 2026-05-01

## Recommended Architecture

The new features integrate into the existing layer stack (Views -> ViewModels -> Pipelines -> Engines -> Repositories -> Models) with minimal disruption. No new architectural patterns are needed -- the existing patterns are well-suited. The key challenge is managing parallel data tracks (estimated vs real ATL/CTL) and broadening template ownership without breaking the coach template system.

### High-Level Integration Map

```
COLD-START FLOW:
  OnboardingView (modified, +4 steps)
    -> ColdStartEngine (NEW pure struct)
      -> Seeds TrainingProfile (NEW @Model)
      -> Seeds WorkloadSnapshot with isEstimated flag
    -> WorkoutPipeline (modified, parallel track logic)
      -> switchover check at 3wk + 8 sessions

TEMPLATE FLOW:
  DashboardView (modified, +quick-start cards)
    -> TemplateSuggestionEngine (NEW pure struct)
    -> TemplatePickerSheet (NEW view)
      -> ActiveWorkoutSheet (modified, accepts template)
        -> save-as-template flow (NEW, post-save option)
  TemplateManagementView (NEW, replaces coach-only TemplateListView for athletes)
    -> TemplateEditorSheet (modified, ownerId instead of coachId)
    -> TemplateRepository (NEW repository)
```

## Component Inventory: New vs Modified

### New Components (13 files)

| Component | Type | Layer | File |
|-----------|------|-------|------|
| TrainingProfile | `@Model` | Models | `Models/TrainingProfile.swift` |
| ColdStartEngine | pure struct | Services | `Services/ColdStartEngine.swift` |
| TemplateSuggestionEngine | pure struct | Services | `Services/TemplateSuggestionEngine.swift` |
| TemplateRepository | `@MainActor final class` | Repositories | `Repositories/TemplateRepository.swift` |
| ColdStartQuestionnaireView | SwiftUI View | Views | `Views/Onboarding/ColdStartQuestionnaireView.swift` |
| TemplatePickerSheet | SwiftUI View | Views | `Views/WorkoutLog/TemplatePickerSheet.swift` |
| TemplateManagementView | SwiftUI View | Views | `Views/WorkoutLog/TemplateManagementView.swift` |
| TemplateQuickStartCard | SwiftUI View | Views | `Views/Dashboard/TemplateQuickStartCard.swift` |
| SaveAsTemplateSheet | SwiftUI View | Views | `Views/WorkoutLog/SaveAsTemplateSheet.swift` |
| TemplateDetailView | SwiftUI View | Views | `Views/WorkoutLog/TemplateDetailView.swift` |
| TrainingProfileRow | Codable struct | Services | (inside `SyncService.swift`) |
| training_profiles | Supabase table | Backend | (migration SQL) |
| workout_templates RLS | Supabase policy | Backend | (migration SQL) |

### Modified Components (11 files)

| Component | What Changes | Risk |
|-----------|-------------|------|
| `WorkoutTemplate` model | Add `isFavorite`, `isArchived`, `lastUsedAt`, `usageCount`, `scheduledDays` fields (keep `coachId` as-is, used by both coaches and athletes) | LOW -- additive fields with defaults |
| `WorkloadSnapshot` model | Add `isEstimated: Bool = false` field | LOW -- additive, defaults false |
| `WorkoutSession` model | Add `templateId: UUID?` field for template linkback | LOW -- additive, optional |
| `OnboardingView` | Insert cold-start questionnaire sub-flow after experience level step | MEDIUM -- flow orchestration |
| `ActiveWorkoutSheet` | Accept `WorkoutTemplate?` init param alongside `PrescribedWorkout?`, add save-as-template option on finish | MEDIUM -- two init paths |
| `DashboardView` | Add template quick-start section after welcome card area | LOW -- additive UI |
| `WorkoutPipeline` | Parallel track logic: if estimated snapshots exist, write both estimated and real snapshots; switchover check | MEDIUM -- core data flow change |
| `WorkloadRepository` | Add `isEstimated` filtering, fetch methods for estimated vs real | LOW -- additive methods |
| `SyncService` | Add `pushTrainingProfile`, `pullTrainingProfile`; template push/pull already works for athletes (coachId = athleteId) | MEDIUM -- new table sync |
| `MainTabView` | Add Templates tab for athlete mode | LOW -- additive tab |
| `WorkloadApp` | Register `TrainingProfile` in Schema array | LOW -- one line |

### Unchanged Components (rely on but do not modify)

| Component | Why Unchanged |
|-----------|---------------|
| `WorkloadCalculator` | ColdStartEngine calls `stepEWMA()` to seed -- no changes needed to calculator itself |
| `FatigueIndexEngine` | Operates on snapshots regardless of estimated flag |
| `RecoveryScoreEngine` | Independent of workload seeding |
| `AutoregulationEngine` | Consumes recovery + workload zone -- transparent to data source |
| `ProgressionEngine` | Template targets feed into its history lookup -- no API change |
| `PRDetector` | Session-based, template-agnostic |
| `HealthKitService` | No changes |
| `AuthService` | No changes |

## New Model: TrainingProfile

```swift
@Model
final class TrainingProfile {
    @Attribute(.unique) var id: UUID
    var athleteId: UUID

    // Required questions (cold-start)
    var sportType: SportType
    var trainingFrequency: TrainingFrequency
    var experienceLevel: ExperienceLevel
    var typicalSessionDurationMinutes: Int

    // Optional questions
    var typicalSessionRPE: Double?
    var trainingYears: Int?
    var currentPhase: String?    // "building" | "maintaining" | "peaking"
    var bodyWeightKg: Double?

    // Seeded values (output of ColdStartEngine)
    var seededATL: Double
    var seededCTL: Double
    var seededAt: Date

    // Bias measurement (silent)
    var estimatedWeeklyLoad: Double?
    var actualWeeklyLoadAt8Weeks: Double?
    var biasRatio: Double?

    // Switchover tracking
    var switchoverDate: Date?
    var switchoverSessionCount: Int?

    var createdAt: Date
    var updatedAt: Date
}
```

**Design rationale -- standalone model, not fields on Athlete:**
1. Preserves raw questionnaire answers for bias analysis at 8 weeks
2. Athlete model already has ~20 fields + 7 relationships -- adding 15 more creates maintenance risk
3. Clean separation: TrainingProfile is a one-time setup artifact, not a core domain entity
4. Separate Supabase table with its own RLS policy
5. One-to-one: one TrainingProfile per Athlete (enforced by unique athleteId)

**Relationship approach:** Use `athleteId: UUID` foreign key, not a SwiftData `@Relationship`. TrainingProfile is infrequently traversed (checked on dashboard load and in pipeline). Fetch via predicate:
```swift
#Predicate<TrainingProfile> { $0.athleteId == athleteId }
```

## New Engine: ColdStartEngine

```swift
struct ColdStartEngine {

    struct QuestionnaireInput {
        let sportType: SportType
        let trainingFrequency: TrainingFrequency
        let experienceLevel: ExperienceLevel
        let typicalSessionDurationMinutes: Int
        let typicalSessionRPE: Double?        // optional
        let trainingYears: Int?               // optional
        let currentPhase: String?             // optional
    }

    struct SeedResult {
        let atl: Double
        let ctl: Double
        let weeklyTSS: Double
        let confidence: SeedConfidence
    }

    enum SeedConfidence {
        case low        // Only required questions answered
        case medium     // Required + some optional
        case high       // All questions answered
    }

    static func seed(input: QuestionnaireInput) -> SeedResult {
        // 1. Estimate per-session TSS from duration + RPE
        let rpe = input.typicalSessionRPE ?? defaultRPE(for: input.experienceLevel)
        let hours = Double(input.typicalSessionDurationMinutes) / 60.0
        let sessionTSS = hours * rpe * (rpe / 10.0)
        // Uses same formula as WorkloadCalculator.sessionTSS()

        // 2. Weekly frequency midpoint from enum
        let weeklyFreq = frequencyMidpoint(input.trainingFrequency)

        // 3. Weekly TSS
        let weeklyTSS = sessionTSS * weeklyFreq

        // 4. CTL at EWMA steady state approximates daily average
        let ctl = weeklyTSS / 7.0

        // 5. ATL depends on current phase
        let atlMultiplier = phaseATLMultiplier(input.currentPhase)
        let atl = ctl * atlMultiplier

        // 6. Confidence level
        let optionalAnswered = [input.typicalSessionRPE != nil,
                                 input.trainingYears != nil,
                                 input.currentPhase != nil].filter { $0 }.count
        let confidence: SeedConfidence = optionalAnswered >= 3 ? .high
            : optionalAnswered >= 1 ? .medium : .low

        return SeedResult(atl: atl, ctl: ctl, weeklyTSS: weeklyTSS, confidence: confidence)
    }
}
```

**Critical integration:** ColdStartEngine uses the identical TSS formula as `WorkloadCalculator.sessionTSS()`: `hours * RPE * (RPE/10)`. The seeded ATL/CTL values are directly compatible with `WorkloadCalculator.stepEWMA(previousATL:previousCTL:todayTSS:)`. When the first real session arrives, the pipeline feeds the seeded values as `previousATL`/`previousCTL` and the EWMA converges naturally.

## Parallel Data Track Architecture

This is the most architecturally significant change. Two concurrent workload tracks during the cold-start transition window.

### Track Design

**Track 1: Estimated** -- Starts from ColdStartEngine seed on day 1. Updated by WorkoutPipeline with each session using estimated baseline. Used for dashboard display and recommendations during cold-start window. `WorkloadSnapshot.isEstimated = true`.

**Track 2: Real** -- Starts from zero on day 1. Updated by WorkoutPipeline with each real session using EWMA from scratch. Not displayed until switchover criteria met. `WorkloadSnapshot.isEstimated = false`.

### Switchover Criteria

```
realSessionCount >= 8 AND daysSinceFirstRealSession >= 21
```

When met:
1. Stop writing estimated snapshots
2. Display real snapshots going forward
3. Record `switchoverDate` on TrainingProfile
4. Capture bias: `actualWeeklyLoadAt8Weeks = realCTL * 7`
5. If `estimatedWeeklyLoad` was provided: `biasRatio = estimated / actual`
6. All downstream consumers automatically use real data (they read from the same snapshot query)

### Implementation in WorkloadSnapshot

One additive field:
```swift
var isEstimated: Bool = false  // Default false preserves all existing data
```

Existing snapshots from before cold-start are `isEstimated = false` by default, so no migration issues.

### Implementation in WorkoutPipeline

```swift
// In processSession(), AFTER existing real EWMA computation:

// NEW: parallel estimated track
if let profile = fetchTrainingProfile(athleteId: athlete.id, modelContext: modelContext),
   profile.switchoverDate == nil {

    // Get last estimated snapshot or fall back to seed values
    let lastEstimated = try? workloadRepo.fetchLatestSnapshot(estimated: true)
    let prevATL = lastEstimated?.acuteLoad ?? profile.seededATL
    let prevCTL = lastEstimated?.chronicLoad ?? profile.seededCTL

    let estimatedResult = WorkloadCalculator.stepEWMA(
        previousATL: prevATL,
        previousCTL: prevCTL,
        todayTSS: session.trainingStress
    )
    try workloadRepo.upsertSnapshot(
        estimatedResult, weeklyVolume: weeklyVol,
        loadSource: athlete.loadMetricPreference,
        isEstimated: true
    )

    // Check switchover
    let realCount = try workoutRepo.fetchSessions(last: 365).count
    let daysSince = Calendar.current.dateComponents([.day],
        from: profile.seededAt, to: .now).day ?? 0
    if realCount >= 8 && daysSince >= 21 {
        profile.switchoverDate = .now
        profile.switchoverSessionCount = realCount
        profile.actualWeeklyLoadAt8Weeks = latestResult.ctl * 7
        try modelContext.save()
    }
}
```

### WorkloadRepository Changes

```swift
// Additive method:
func fetchLatestSnapshot(estimated: Bool? = nil) throws -> WorkloadSnapshot? {
    var descriptor: FetchDescriptor<WorkloadSnapshot>
    if let est = estimated {
        let predicate = #Predicate<WorkloadSnapshot> { $0.isEstimated == est }
        descriptor = FetchDescriptor(predicate: predicate,
            sortBy: [SortDescriptor(\.snapshotDate, order: .reverse)])
    } else {
        descriptor = FetchDescriptor(
            sortBy: [SortDescriptor(\.snapshotDate, order: .reverse)])
    }
    return try modelContext.fetch(descriptor).first
}
```

### Dashboard Display Logic

```swift
// In DashboardViewModel.load():
let profile: TrainingProfile? = /* fetch by athleteId */
let useEstimated = profile != nil && profile?.switchoverDate == nil

// Use estimated or nil (nil = legacy behavior, returns any snapshot)
let snapshot = try workloadRepo.fetchLatestSnapshot(
    estimated: useEstimated ? true : nil
)
// Rest of load() unchanged -- it reads from snapshot fields
```

**Why this design works:** All downstream consumers (FatigueIndexEngine, AutoregulationEngine, charts, recommendations) operate on `WorkloadSnapshot` fields. They do not care whether the data is estimated or real. The DashboardViewModel simply picks which track to query based on the training profile's switchover state. No engine changes needed.

## Template Ownership Architecture

### Problem

`WorkoutTemplate.coachId` is a non-optional UUID that currently couples templates to coaches. Athletes need to own templates too.

### Solution: Keep `coachId`, add alias

Do NOT rename `coachId` to `ownerId`. Renaming would require:
- SwiftData schema migration
- SyncService push/pull code changes
- Supabase column rename
- Breaking existing coach templates

Instead, use `coachId` for both coaches and athletes. Both user types put their own UUID in this field. Add a computed property for semantic clarity:

```swift
// On WorkoutTemplate:
var ownerId: UUID { coachId }  // Alias for clarity in athlete context
```

**RLS requires zero changes.** The existing Supabase policy `USING (coach_id = auth.uid())` already works because athletes store their own UUID in `coach_id`. The column name is misleading but the access control is correct.

### New Fields on WorkoutTemplate

All additive with defaults -- no migration required:

```swift
var isFavorite: Bool = false
var isArchived: Bool = false
var lastUsedAt: Date?
var usageCount: Int = 0
var scheduledDays: [Int]?  // e.g. [2, 4, 6] for Mon/Wed/Fri
```

### TemplateListView vs TemplateManagementView

The existing `TemplateListView` is coach-specific (lives at top level `Views/`, used in coach tab). Create a new `TemplateManagementView` for athlete mode with athlete-specific features (favorites, archive, usage stats, day scheduling). The two views share `TemplateEditorSheet` for editing.

| View | Mode | Features |
|------|------|----------|
| `TemplateListView` (existing) | Coach tab | Create, edit, prescribe to athletes |
| `TemplateManagementView` (new) | Athlete tab | Create, edit, favorite, archive, duplicate, view usage stats, schedule days |

## New Engine: TemplateSuggestionEngine

```swift
struct TemplateSuggestionEngine {

    struct Suggestion {
        let template: WorkoutTemplate
        let reason: SuggestionReason
        let score: Double  // 0-1 ranking score
    }

    enum SuggestionReason {
        case scheduledToday
        case frequentlyUsed
        case matchesHealthKit
        case recentlyUsed
        case favorite
    }

    static func suggest(
        templates: [WorkoutTemplate],
        dayOfWeek: Int,
        recentSessionNames: [String],
        healthKitSuggestions: [WorkoutImportSuggestion]
    ) -> [Suggestion] {
        // Score each non-archived template:
        // +0.5 if scheduledDays contains today
        // +0.3 if isFavorite
        // +0.2 * normalized(usageCount)
        // +0.1 if lastUsedAt within 7 days
        // +0.2 if HealthKit sportType matches template sportType
        // Sort descending, return top 3
    }
}
```

**HealthKit integration:** Receives `[WorkoutImportSuggestion]` from existing `WorkoutImportService.findUnmatchedWorkouts()`. Matches on `sportType` -- e.g., HealthKit "Strength Training" maps to `SportType.lifting`. No new HealthKit queries needed.

## Template-to-Session Flow

### ActiveWorkoutSheet Integration

Current signature:
```swift
struct ActiveWorkoutSheet: View {
    var prescription: PrescribedWorkout?
```

New signature:
```swift
struct ActiveWorkoutSheet: View {
    var prescription: PrescribedWorkout?
    var template: WorkoutTemplate?
```

Add `loadTemplate()` method mirroring the existing `loadPrescription()`. Both work on the same `ExerciseGroup -> TemplateExercise -> TemplateSet` hierarchy:

```swift
private func loadTemplate() {
    guard let template else { return }
    sessionName = template.templateName
    sportType = template.sportType
    sessionType = template.sessionType

    entries = template.sortedGroups.flatMap { group in
        group.sortedExercises.map { exercise in
            var draft = ExerciseEntryDraft(
                exerciseName: exercise.exerciseName,
                exerciseCategory: exercise.exerciseCategory,
                muscleGroup: exercise.muscleGroup
            )
            draft.groupName = group.groupName

            // Base targets from template
            var baseSets = exercise.sortedSets.map { set in
                SetDraft(
                    reps: set.targetReps,
                    weightKg: set.targetWeightKg,
                    rpe: set.targetRPE,
                    rir: set.targetRIR,
                    isWarmup: set.isWarmup,
                    targetReps: set.targetReps,
                    targetWeightKg: set.targetWeightKg,
                    targetRPE: set.targetRPE
                )
            }

            // Pro: overlay ProgressionEngine suggestions
            if container.subscriptionService.isPro {
                let history = ProgressionEngine.fetchHistory(
                    exerciseName: exercise.exerciseName,
                    modelContext: modelContext
                )
                if !history.isEmpty {
                    let context = buildTrainingContext()
                    let suggestion = ProgressionEngine.suggest(
                        exerciseName: exercise.exerciseName,
                        category: exercise.exerciseCategory,
                        context: context,
                        recentEntries: history
                    )
                    if !suggestion.suggestedSets.isEmpty {
                        baseSets = zip(suggestion.suggestedSets,
                                       exercise.sortedSets).map { s, orig in
                            SetDraft(
                                reps: s.reps,
                                weightKg: s.weightKg,
                                rpe: s.rpe,
                                targetReps: orig.targetReps,
                                targetWeightKg: orig.targetWeightKg,
                                targetRPE: orig.targetRPE
                            )
                        }
                        draft.suggestionRationale = suggestion.rationale
                        draft.progressionType = suggestion.progressionType
                    }
                }
            }

            draft.sets = baseSets.isEmpty ? [SetDraft()] : baseSets
            return draft
        }
    }
}
```

### Post-Session Template Update

After `saveSession()`, if the session was started from a template:

```swift
if let template {
    template.lastUsedAt = .now
    template.usageCount += 1
    updateTemplateTargets(template: template, from: entries)
    try? modelContext.save()
}
```

`updateTemplateTargets()` writes the actually-performed values back to the template's `TemplateSet` targets, so next time the template loads with last-used values as the baseline.

### Save-As-Template Flow

After finishing a workout that was NOT started from a template, show an optional "Save as Template?" sheet. The `SaveAsTemplateSheet` receives the completed `[ExerciseEntryDraft]` and converts them into a `WorkoutTemplate` with `ExerciseGroup -> TemplateExercise -> TemplateSet`.

**Timing:** Presented after PR celebration and spike alert flows complete. Non-blocking -- user can dismiss and the session is already saved.

## Data Flow Diagrams

### Cold-Start Seeding Flow

```
OnboardingView (existing step 0: frequency, step 1: experience)
    |
    v
ColdStartQuestionnaireView (NEW, presented as sub-flow)
    step 0: "How long are your typical sessions?" (required)
    step 1: "How hard are your sessions? (RPE)" (optional, skip)
    step 2: "Current training phase?" (optional, skip)
    step 3: "Estimate your weekly training load" (optional, for bias)
    |
    v
ColdStartEngine.seed(input:) -> SeedResult(atl, ctl, weeklyTSS)
    |
    v
Create TrainingProfile (persisted)
    |
    v
WorkloadRepository.upsertSnapshot(atl, ctl, isEstimated: true)
    |
    v
SyncService.pushTrainingProfile()
    |
    v
Return to OnboardingView -> HealthKit step -> complete
```

### Parallel Track Flow (Every Session)

```
ActiveWorkoutSheet.saveSession()
    |
    v
WorkoutPipeline.processSession()
    |
    +--- EXISTING: compute real EWMA from all sessions
    |    upsertSnapshot(isEstimated: false)
    |
    +--- NEW: if TrainingProfile && !switchedOver:
         |
         +--- stepEWMA(prev: lastEstimated, tss: real)
         |    upsertSnapshot(isEstimated: true)
         |
         +--- check switchover(count >= 8 && days >= 21)
              if yes: profile.switchoverDate = .now
                      capture bias metric
```

### Template Selection Flow

```
DashboardView
    |
    +-- TemplateQuickStartCard (shows top 3 from TemplateSuggestionEngine)
    |
    v
User taps suggestion
    |
    v
ActiveWorkoutSheet(template: selected)
    |
    v
loadTemplate() -> fills entries from template + ProgressionEngine overlay
    |
    v
User performs workout -> Finish
    |
    v
saveSession()
    +-- WorkoutPipeline (existing)
    +-- template.lastUsedAt = .now; template.usageCount += 1
    +-- update template targets to last-used values
    +-- session.templateId = template.id
```

## Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| TrainingProfile | Store questionnaire answers + seeded values + bias data | ColdStartEngine (writes), WorkoutPipeline (reads switchover state), SyncService (syncs), DashboardViewModel (reads for track selection) |
| ColdStartEngine | Compute ATL/CTL estimates from questionnaire answers | WorkloadCalculator (uses same TSS formula), OnboardingView (called by) |
| TemplateSuggestionEngine | Rank templates for today's suggestions | WorkoutTemplate (reads), WorkoutImportSuggestion (reads), DashboardView (displays) |
| TemplateRepository | CRUD for templates owned by current user | WorkoutTemplate model, SyncService, TemplateManagementView, TemplateEditorSheet |
| WorkoutPipeline (modified) | Parallel track management during cold-start | TrainingProfile (reads), WorkloadCalculator (calls), WorkloadRepository (writes both tracks) |
| TemplateQuickStartCard | Display top 3 template suggestions on dashboard | TemplateSuggestionEngine (calls), ActiveWorkoutSheet (navigates to) |
| TemplateManagementView | List/edit/delete/archive/favorite athlete templates | TemplateRepository, TemplateEditorSheet, TemplateDetailView |
| SaveAsTemplateSheet | Convert completed session into reusable template | WorkoutTemplate, TemplateRepository |

## Patterns to Follow

### Pattern 1: Pure Engine for ColdStartEngine and TemplateSuggestionEngine
**What:** Stateless struct with static methods, matching WorkloadCalculator/RecoveryScoreEngine/FatigueIndexEngine.
**When:** All computation for seeding and suggestion ranking.
**Why:** Testable in isolation, deterministic, no side effects. Input struct in, result struct out.

### Pattern 2: Repository for Template CRUD
**What:** `@MainActor final class` with `ModelContext`, matching AthleteRepository/WorkoutRepository.
**When:** All template fetch/save/delete operations.
**Why:** Centralizes SwiftData queries, provides typed API, avoids scattered `modelContext.fetch()` calls in views.

### Pattern 3: Additive Schema Changes Only
**What:** New fields with defaults; no renames, no removals.
**When:** All model modifications.
**Why:** SwiftData handles additive fields without explicit migration. `isEstimated: Bool = false`, `isFavorite: Bool = false`, `lastUsedAt: Date?` all work seamlessly.

### Pattern 4: Separate Sub-Flow View for Cold-Start
**What:** Extract cold-start into `ColdStartQuestionnaireView` rather than embedding in `OnboardingView`.
**When:** Adding multi-step flows to onboarding.
**Why:** OnboardingView is already 295 lines with 3 steps. Adding 4 more steps inline would make it 500+ lines. A separate view can be re-triggered from Profile if user skipped, and has its own `currentStep` state.

### Pattern 5: Dual-Init Pattern for ActiveWorkoutSheet
**What:** Accept both `PrescribedWorkout?` and `WorkoutTemplate?`, with `onAppear` dispatching to `loadPrescription()` or `loadTemplate()`.
**When:** Views that serve multiple entry points.
**Why:** Both prescriptions and templates produce the same `[ExerciseEntryDraft]` output. The rest of the sheet (exercise editing, set entry, save) is identical.

## Anti-Patterns to Avoid

### Anti-Pattern 1: Mixing Estimated and Real in Same Snapshot Row
**What:** Using a single snapshot row and toggling between estimated and real values.
**Why bad:** Loses history. When switchover happens, you cannot compare estimated vs real. Bias measurement becomes impossible. Chart continuity breaks.
**Instead:** Write separate snapshot rows with `isEstimated` flag. Both tracks coexist until switchover.

### Anti-Pattern 2: Adding Template Structure to WorkoutSession
**What:** Storing template groups/exercises/sets inside WorkoutSession.
**Why bad:** WorkoutSession already has `exerciseEntries` with actual performed data. Duplicating template structure creates redundancy and confusion about source of truth.
**Instead:** Store only `templateId: UUID?` on WorkoutSession as a linkback reference.

### Anti-Pattern 3: Creating a Separate AthleteTemplate Model
**What:** Building `AthleteTemplate` as a new model hierarchy separate from `WorkoutTemplate`.
**Why bad:** Duplicates the entire `ExerciseGroup -> TemplateExercise -> TemplateSet` hierarchy. Coach prescriptions already reference `ExerciseGroup`, so a separate hierarchy fragments the model layer.
**Instead:** Reuse `WorkoutTemplate` with `coachId` serving dual duty (coach UUID or athlete UUID).

### Anti-Pattern 4: Eager ProgressionEngine Evaluation
**What:** Running ProgressionEngine for all exercises in a template at sheet load time.
**Why bad:** Each exercise requires a database fetch for history. A template with 8 exercises = 8 sequential fetches, causing visible lag on sheet appearance.
**Instead:** Load template base targets immediately (instant), then overlay progression suggestions per-exercise in a background Task or as exercises scroll into view.

### Anti-Pattern 5: Template Targets as Immutable Source of Truth
**What:** Always using template's original stored targets.
**Why bad:** Templates become stale as athletes progress. A template created with 60kg bench targets stays at 60kg even after the athlete hits 80kg.
**Instead:** Template targets are updated after each session (`lastUsedAt` + target refresh). ProgressionEngine overlay provides dynamic recovery-aware adjustments on top.

### Anti-Pattern 6: Renaming `coachId` to `ownerId`
**What:** Schema migration to rename the field.
**Why bad:** Breaks SwiftData schema (requires lightweight migration), breaks SyncService `WorkoutTemplateRow` encoding/decoding, breaks Supabase column name, breaks `TemplateListView` predicate, breaks `TemplateEditorSheet` parameter.
**Instead:** Keep `coachId`, add `var ownerId: UUID { coachId }` computed alias.

## Recommended Build Order

Based on dependency analysis:

### Phase 1: Foundation (Models + Engine + Backend)
Build order within phase:
1. `TrainingProfile` model
2. `WorkloadSnapshot.isEstimated` field
3. `WorkoutTemplate` additive fields (isFavorite, isArchived, lastUsedAt, usageCount, scheduledDays)
4. `WorkoutSession.templateId` field
5. `ColdStartEngine` (pure struct, no dependencies beyond models)
6. `TemplateRepository` (CRUD, depends only on models)
7. Supabase migration SQL (training_profiles table, template column additions)
8. SyncService additions (pushTrainingProfile, pullTrainingProfile, template field sync)
9. Register TrainingProfile in `WorkloadApp` Schema

**Rationale:** All subsequent phases depend on these models and engines existing.

### Phase 2: Cold-Start Integration
10. `ColdStartQuestionnaireView`
11. `OnboardingView` modification (insert sub-flow)
12. `WorkoutPipeline` parallel track logic
13. `WorkloadRepository` estimated filtering
14. `DashboardViewModel` switchover display logic

**Rationale:** Cold-start has highest new-user impact. Must be integrated before templates, since new users need guidance from day one.

### Phase 3: Template Management
15. `TemplateManagementView` (list/edit/archive/favorite/delete)
16. `TemplateEditorSheet` modification (works for athlete coachId)
17. `MainTabView` modification (add Templates tab for athletes)
18. `TemplateDetailView` (usage stats, scheduled days)

**Rationale:** Templates must exist and be manageable before they can be used in workouts.

### Phase 4: Template-Driven Workouts
19. `TemplatePickerSheet`
20. `ActiveWorkoutSheet` modification (accept template, loadTemplate())
21. Dynamic target overlay (ProgressionEngine in loadTemplate())
22. Post-session template update (lastUsedAt, usageCount, target refresh)
23. `SaveAsTemplateSheet`

**Rationale:** Depends on Phase 3 templates being manageable and Phase 1 models being in place.

### Phase 5: Smart Suggestions
24. `TemplateSuggestionEngine`
25. `TemplateQuickStartCard`
26. `DashboardView` modification (insert quick-start section)
27. HealthKit matching (connect WorkoutImportService to suggestion engine)
28. Schedule-aware suggestions (day-of-week pattern)

**Rationale:** Suggestion quality depends on templates having usage data from Phase 4.

### Phase 6: Bias Measurement + Polish
29. 8-week bias capture (background check in DashboardViewModel)
30. Profile settings (view/re-trigger cold-start)
31. Template duplicate flow

**Rationale:** Bias measurement is a silent background metric with no user-facing urgency. Polish items can ship any time.

## Supabase Schema Changes

### New Table: training_profiles

```sql
CREATE TABLE training_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    athlete_id UUID NOT NULL REFERENCES athletes(id) ON DELETE CASCADE,
    sport_type TEXT NOT NULL,
    training_frequency TEXT NOT NULL,
    experience_level TEXT NOT NULL,
    typical_session_duration_minutes INT NOT NULL,
    typical_session_rpe DOUBLE PRECISION,
    training_years INT,
    current_phase TEXT,
    body_weight_kg DOUBLE PRECISION,
    seeded_atl DOUBLE PRECISION NOT NULL,
    seeded_ctl DOUBLE PRECISION NOT NULL,
    seeded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    estimated_weekly_load DOUBLE PRECISION,
    actual_weekly_load_at_8_weeks DOUBLE PRECISION,
    bias_ratio DOUBLE PRECISION,
    switchover_date TIMESTAMPTZ,
    switchover_session_count INT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(athlete_id)
);

ALTER TABLE training_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_own_profile" ON training_profiles
    USING (athlete_id = auth.uid())
    WITH CHECK (athlete_id = auth.uid());
```

### Modified Table: workout_templates (column additions)

```sql
ALTER TABLE workout_templates
    ADD COLUMN is_favorite BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN is_archived BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN last_used_at TIMESTAMPTZ,
    ADD COLUMN usage_count INT NOT NULL DEFAULT 0,
    ADD COLUMN scheduled_days INT[];
```

### Modified Table: workload_snapshots

```sql
ALTER TABLE workload_snapshots
    ADD COLUMN is_estimated BOOLEAN NOT NULL DEFAULT false;
```

### Modified Table: workout_sessions

```sql
ALTER TABLE workout_sessions
    ADD COLUMN template_id UUID;
```

**RLS note:** No changes needed to `workout_templates` RLS. The existing `coach_id = auth.uid()` policy works for athletes too since athletes put their own UUID in `coach_id`.

## Scalability Considerations

| Concern | At Current Scale | At 10K Users | Mitigation |
|---------|-----------------|--------------|------------|
| Template count per user | 1-5 | Could reach 50-100 | TemplateRepository pagination; archive old templates |
| Parallel snapshots | 2x snapshots during 3-week window | Same, self-limiting | Stops at switchover; no ongoing cost |
| ProgressionEngine per template | 1 query per exercise | 8-12 queries per template load | Batch fetch exercise history; cache for session duration |
| Suggestion computation | On dashboard appear | Every foreground resume | Cache in ViewModel for 1 hour; TemplateSuggestionEngine is fast (in-memory sort) |
| Supabase template rows | ~5 per user | ~50K total rows | Already indexed by coach_id; RLS handles scoping |

## Sources

- Existing codebase analysis (all source files read directly)
- `WorkloadCalculator.swift`: EWMA formulas, TSS calculation, `stepEWMA()` API
- `WorkoutPipeline.swift`: Post-session data flow, `buildDailyLoads()`, snapshot upsert
- `ProgressionEngine.swift`: Exercise suggestion API, `TrainingContext` struct, `fetchHistory()`
- `FatigueIndexEngine.swift`: Fatigue input requirements (snapshot-based, track-agnostic)
- `AutoregulationEngine.swift`: `DailyInput` struct (reads recovery zone + ACWR zone)
- `OnboardingView.swift`: Existing 3-step ZStack flow, `completeOnboarding()` save pattern
- `WorkoutTemplate.swift`: Coach template hierarchy (`ExerciseGroup -> TemplateExercise -> TemplateSet`)
- `ActiveWorkoutSheet.swift`: `loadPrescription()` pattern, `prefillFromHistory()`, `saveSession()` flow
- `TemplateEditorSheet.swift`: Draft model pattern (`GroupDraft`, `ExerciseDraft`, `TargetSetDraft`)
- `SyncService.swift`: Template push/pull with `WorkoutTemplateRow`, upsert pattern
- `WorkloadApp.swift`: SwiftData schema registration
- `AppRouter.swift`: Onboarding gate check (`trainingFrequency == nil || experienceLevel == nil`)
- `DashboardViewModel.swift`: `load()` orchestration, snapshot fetching, downstream engine calls
- `WorkoutImportBanner.swift`: `WorkoutImportSuggestion` model, `WorkoutImportService` API
- `PrescribedWorkout.swift`: Template-to-prescription model (reference for template-to-session)
- `PROJECT.md`: v1.2 milestone requirements, key decisions (parallel data tracks, hybrid switchover, template reuse)

---

*Architecture research: 2026-05-01 -- v1.2 Training Onboarding & Templates milestone*
