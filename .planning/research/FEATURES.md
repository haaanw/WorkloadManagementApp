# Feature Landscape

**Domain:** iOS fitness/training app -- v1.2 Cold-Start Questionnaire & Athlete Training Templates
**Researched:** 2026-05-01
**Context:** Tonus has a working 3-step onboarding (frequency, experience, HealthKit), coach template models (WorkoutTemplate/ExerciseGroup/TemplateExercise/TemplateSet), HealthKit import, ProgressionEngine, and EWMA workload calculation. This research covers what the ecosystem does for cold-start data collection and template/routine management, to inform building both features into Tonus.

## Table Stakes

Features users expect. Missing = product feels incomplete or confusing.

### Cold-Start Questionnaire

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Training frequency (sessions/week)** | Every serious fitness app asks this: Fitbod, Juggernaut AI, Hevy Trainer, JEFIT. Required to estimate weekly training volume. Tonus already collects this (TrainingFrequency enum: 1-2, 3-4, 5-6, 7+). | Already built | Extend existing onboarding step; map to numeric midpoint for seeding math. |
| **Experience level** | Universal onboarding Q across Fitbod (beginner/intermediate/advanced), Juggernaut AI, JEFIT. Sets expectations for load tolerance. Tonus already collects this (ExperienceLevel enum). | Already built | Use as modifier for initial load estimates (beginners tolerate less absolute load). |
| **Typical session duration** | Fitbod asks "how long do you want to train." sRPE x duration is the core TSS formula (Foster method). Without duration, you cannot estimate session load. TrainingPeaks seeds CTL from weekly training hours. | Low | Single slider or segmented control (30/45/60/75/90+ min). Critical for TSS estimation: TSS = hours x RPE x (RPE/10). |
| **Typical session intensity (sRPE estimate)** | Juggernaut AI collects perceived effort context. sRPE is the other half of the TSS formula. Most athletes can estimate "how hard are your typical sessions" even if they have never used RPE before. | Low | Visual RPE scale (1-10) with anchor descriptions ("light conversation" to "maximal effort"). Default to 6-7 for most users since research shows sRPE tends to overestimate by ~15%. |
| **Save-from-session (template creation)** | Strong, Hevy, JEFIT all offer "Save as Template/Routine" after completing a workout. This is the #1 template creation path -- users build their first template from real sessions, not from scratch. Strong prompts this automatically at workout completion. | Medium | Post-workout sheet shows "Save as Template?" prompt. Map WorkoutSession exercises/sets to WorkoutTemplate/ExerciseGroup structure. Must handle the coach template model's `coachId` field (repurpose as `ownerId` or add `athleteId`). |
| **Template picker (start workout from template)** | Strong's primary Start Workout tab shows templates front and center. Hevy shows routines in the Workout tab with "Start Routine" button. Every workout tracker app with templates has this -- it is the primary way users begin sessions. | Medium | List view of templates with "Start Workout" action. Must convert template exercises/sets into a new WorkoutSession with pre-filled entries. Needs to work in the existing WorkoutLog tab or as a sheet from dashboard. |
| **Last-used values auto-fill** | Strong auto-populates previous weights for each exercise. Hevy shows a "PREVIOUS" column during logging with last-used weight/reps that users can tap to fill. This is THE core template feature -- without it, templates are just exercise lists. | Medium | When starting from template, look up last WorkoutSession containing each exercise and pre-fill weight/reps/duration. Hevy shows this as a column; Strong pre-fills the input fields. Either approach works. Depends on ProgressionEngine.fetchHistory() which already exists. |
| **Template editing (add/remove exercises, reorder)** | Every template system allows modification. Hevy asks "Update routine?" after completing a modified workout. Strong allows direct editing via template detail screen. Without editing, templates become stale fast. | Medium | Full CRUD on template structure: add/remove exercises, add/remove sets, reorder via drag-and-drop, rename. Hevy's "Update routine with changes?" prompt after workout completion is excellent UX -- reduces explicit editing friction. |

### Training Templates (Management)

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Template list/library** | All apps show templates in a scrollable list. Users accumulate 5-15 templates over time. Without organization, templates become unwieldy. | Low | Simple list view with template name, sport type, exercise count, last-used date. Sorted by most-recently-used by default. |
| **Template deletion** | Basic CRUD. SwiftData cascade delete handles ExerciseGroup/TemplateExercise/TemplateSet relationships automatically. | Low | Swipe-to-delete or context menu with confirmation. |
| **Template creation from scratch** | While save-from-session is the primary path, some users want to plan workouts in advance. Strong and Hevy both offer a "+ Template" / "New Routine" button. | Medium | Exercise picker (search existing exercise database), set configuration (weight/reps/RPE targets), group structure (A/B/C/D). Reuse existing exercise search from ActiveWorkoutSheet. |

## Differentiators

Features that set Tonus apart. Not expected by every app user, but valued by Tonus's target audience (data-driven athletes) and align with the app's core value proposition.

### Cold-Start Questionnaire Differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Weeks-at-current-level question** | No competitor asks this directly. TrainingPeaks says to interpret seeded CTL "cautiously until 4-6 weeks of data." Knowing "I've been training at this level for 6 months" vs "I just started 2 weeks ago" dramatically changes CTL confidence. Tonus can weight its switchover threshold accordingly. | Low | Segmented control: <2 weeks / 2-4 weeks / 1-3 months / 3-6 months / 6+ months. Longer = higher confidence in seeded values, shorter = more conservative seed. |
| **Parallel data tracks (estimated vs actual)** | TrainingPeaks warns to "reset starting values back to zero" after 4-6 weeks. That is disruptive and lossy. Tonus's approach of maintaining estimated ATL/CTL alongside real values, then blending at switchover, is more sophisticated than any competitor. TrainingPeaks just overwrites. | High | Requires WorkloadSnapshot to carry both estimated and real ATL/CTL. Blending function at switchover (3wk + 8 sessions). Most architecturally complex piece -- need clear data model. |
| **Perceptual bias measurement (silent)** | No fitness app does this. Research shows sRPE overestimates by ~15% on average, but with "substantial interindividual variability." Comparing user's estimated sRPE (from questionnaire) with actual logged sRPE after 8 weeks gives a personalized bias coefficient. This could feed into more accurate load estimates long-term. | Low (capture) / High (use) | Capture is just comparing two numbers. Using it to calibrate future estimates is v1.3+ territory. For now, store the delta as a silent metric in TrainingProfile. |
| **Training age (optional)** | Juggernaut AI asks this. Training age (years of structured training) is a better predictor of load tolerance than experience level (beginner/intermediate/advanced). A 2-year lifter who trains 6x/week is very different from a 10-year lifter who trains 3x/week. | Low | Optional numeric input or segmented (<1yr / 1-3yr / 3-5yr / 5-10yr / 10+yr). Modifies initial ATL/CTL estimates -- higher training age = higher load tolerance for same frequency/intensity. |
| **Periodization preference (optional)** | Juggernaut AI asks this and offers block/undulating/alternating. Tonus already has PeriodizationDetector. Knowing user's intended approach lets the app compare detected vs intended periodization -- another calibration signal. | Low | Optional selection from existing periodization types. Does not drive functionality in v1.2 but enriches TrainingProfile for future intelligence features. |
| **Movement type preference (optional)** | Fitbod asks about equipment and training type. Knowing whether someone primarily does compound barbell, machines, bodyweight, or cardio helps contextualize load. A powerlifter doing 4 sessions/week at RPE 8 generates very different TSS than a runner doing the same. | Low | Multi-select from exercise categories (compound, isolation, cardio, plyometric, etc.) or sport-specific movements. Feeds into more nuanced TSS estimation. |
| **Injury history flag (optional)** | Juggernaut AI asks about weaknesses and injury concerns. Tonus has deferred injury-aware loading to future versions, but capturing the flag now (yes/no + optional area) costs nothing and enriches the profile. | Low | Boolean + optional body area tag. No functional impact in v1.2. Stored in TrainingProfile for future injury-aware features. |

### Training Template Differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Exercise group structure (A/B/C/D)** | Strong and Hevy have flat exercise lists in templates. Tonus already has ExerciseGroup in the coach template model with `groupName` (e.g., "Group A", "Group B") and `orderIndex`. Exposing this to athletes enables superset/circuit organization that competitors lack in their template UX. | Low | Model exists. Just needs UI -- collapsible group headers with drag-and-drop between groups. Coaches already use this structure for prescribed workouts. |
| **Dashboard quick-start cards** | No competitor puts templates on the dashboard as tap-to-start cards. Strong and Hevy both require navigating to a separate Workout/Routines tab. Putting the most-used 2-3 templates on the Dashboard reduces workout-start friction from 3 taps to 1. | Medium | Horizontal scroll of template cards on DashboardView. Show template name, exercise count, last-used date. Tap to start session with pre-filled data. Requires dashboard layout changes. |
| **HealthKit workout-to-template matching** | No competitor does this. When a HealthKit workout is imported (from Apple Watch, Garmin, etc.), Tonus can try to match it against existing templates by activity type, duration, and exercise patterns. This auto-associates imported workouts with the user's template library, enabling template-based analytics even for watch-logged sessions. | High | Fuzzy matching: compare HKWorkout.workoutActivityType against template.sportType, duration within range, exercise overlap if available. May need to match by title string (many watch apps set workout title). WorkoutImportService already imports workouts; needs template-matching layer. |
| **Schedule-aware template suggestions (TemplateSuggestionEngine)** | Fitbod suggests muscle groups based on recovery; Juggernaut AI plans specific days. But suggesting "it's Tuesday, you usually do Push on Tuesdays" based on actual usage patterns is simple, personal, and not done by workout trackers (only by program-based apps like Juggernaut). | Medium | Analyze template usage by day-of-week. After 2+ weeks of pattern data, suggest today's most-likely template on dashboard. Pure computation engine -- no ML needed, just day-of-week frequency counting per template. |
| **Dynamic targets (last-used + ProgressionEngine overlay)** | Fitbod auto-adjusts weight/reps. PumpX suggests weights. But combining "what you actually did last time" (last-used values) with "what your recovery state allows" (ProgressionEngine, Pro-gated) is Tonus's unique angle. Templates that evolve with the athlete AND respond to recovery state. | Medium | Free tier: show last-used values as defaults. Pro tier: overlay ProgressionEngine suggestions (increase/maintain/deload with rationale). ProgressionEngine.suggest() already exists and produces SetSuggestion with weight/reps/RPE. |
| **Template duplication** | Hevy supports this. Users want to create "Push A" and "Push B" variants without rebuilding from scratch. | Low | Deep copy via existing `deepCopyGroups()` method on WorkoutTemplate. |
| **Template archiving** | Prevent template list bloat without losing data. Hevy has unlimited routines but no archive concept -- old routines clutter the list. | Low | Boolean `isArchived` flag on WorkoutTemplate. Filter archived from main list, show in separate "Archived" section. |
| **Template favoriting** | Quick access to most-used templates. Complements dashboard cards -- favorites feed the quick-start card selection. | Low | Boolean `isFavorite` flag. Favorited templates appear first in list and on dashboard cards. |

## Anti-Features

Features to explicitly NOT build for this milestone.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Pre-built template library / program marketplace** | JEFIT has 850+ plans; Hevy has 25+ programs. Building or curating a library is content work, not engineering. Premature before the template model is battle-tested. Also conflicts with Tonus's "your data, your insights" positioning. | Let users build their own templates from sessions. Coach templates already exist for coached athletes. Revisit content library in v1.4+. |
| **AI-generated workout plans** | Fitbod generates entire workouts via algorithm. Juggernaut AI plans full periodization blocks. This requires massive training data (Fitbod uses 150M+ logged workouts) or sophisticated periodization logic. Tonus has neither the data nor the mandate. | ProgressionEngine provides per-exercise suggestions within user-created templates. Intelligence overlays on user structure, not wholesale generation. |
| **Template sharing between users** | Explicitly deferred to v1.3 per PROJECT.md. Needs "battle-tested template model first." Sharing adds social/privacy complexity and Supabase schema work. | Build solid local template system first. Sharing is a natural v1.3 follow-up after the model proves stable. |
| **Complex periodization programming** | Juggernaut AI plans entire mesocycles with block/undulating periodization. TrainingPeaks Annual Training Plans are coach-driven. Manual mesocycle planning is explicitly out of scope per PROJECT.md ("TrainingPeaks owns this space"). | Tonus already detects periodization patterns passively. Templates are workout-level, not program-level. Keep it simple. |
| **Mandatory onboarding questionnaire** | Strong's 2-step onboarding with mandatory sign-up "introduces friction early on." Long questionnaires cause drop-off. Juggernaut AI's 20-minute onboarding is justified because it generates your entire program -- Tonus does not. | 4 required questions + 4 optional. Required Qs map to onboarding steps like existing flow. Optional Qs appear as "tell us more" expandable section or separate profile screen. User can skip optional Qs entirely. |
| **Muscle recovery heat map** | Fitbod's signature feature: color-coded body map showing recovery status per muscle group. Cool but orthogonal to Tonus's recovery model (composite score from HRV/RHR/sleep, not per-muscle). Would require a fundamentally different recovery architecture. | Tonus's whole-body recovery score is the right abstraction for workload management. Per-muscle recovery is a workout-planning feature, not a load-management feature. |
| **Equipment/gym filtering** | Fitbod asks what equipment you have. Tonus's template model does not constrain by equipment -- exercises are user-chosen. Equipment filtering matters for AI-generated workouts, not for user-built templates. | Not needed. Users select their own exercises when building templates. |
| **LLM-powered workout import from photos/text** | Explicitly deferred to v1.3 per PROJECT.md. Needs model research and introduces LLM cost/latency concerns. | Templates are manual-creation or save-from-session for v1.2. |
| **Rest timer per template set** | Strong and Hevy both have sophisticated rest timers. Nice-to-have but orthogonal to the template intelligence story. The existing rest timer in ActiveWorkoutSheet works independently of templates. | Rest timer is already in the workout logging flow. Template sets define targets (weight/reps/RPE), not rest periods. |

## Feature Dependencies

```
Cold-Start Dependencies:
  TrainingFrequency (exists) ─┐
  ExperienceLevel (exists) ───┤
  Session Duration (new Q) ───┼──> TrainingProfile model ──> ColdStartSeedingEngine
  Typical sRPE (new Q) ───────┤        │
  Weeks at Level (new Q) ─────┘        │
                                        ├──> Parallel ATL/CTL tracks ──> WorkloadSnapshot changes
  Training Age (optional) ─────────────┤
  Periodization Pref (optional) ───────┤
  Movement Types (optional) ───────────┤
  Injury History (optional) ───────────┘

  Seeded ATL/CTL ──> Switchover logic (3wk + 8 sessions) ──> Real ATL/CTL
  Seeded sRPE (questionnaire) ──> Actual sRPE (8 weeks) ──> Perceptual Bias (silent metric)

Template Dependencies:
  WorkoutTemplate model (exists) ──> Athlete ownership (coachId → ownerId refactor or athleteId add)
       │
       ├──> Save-from-session ──> Post-workout prompt
       │
       ├──> Create from scratch ──> Exercise picker + set configuration
       │
       ├──> Template picker ──> Start Workout from template
       │        │
       │        └──> Last-used auto-fill ──> ProgressionEngine overlay (Pro)
       │
       ├──> Dashboard quick-start cards
       │
       ├──> Template management (edit, duplicate, archive, favorite, delete)
       │
       ├──> HealthKit workout → template matching (depends on WorkoutImportService)
       │
       └──> TemplateSuggestionEngine (depends on 2+ weeks of template usage data)

Cross-Feature:
  Cold-start seeded ATL/CTL ──> ProgressionEngine context (recovery zone, ACWR zone)
       └──> Dynamic template targets benefit from accurate cold-start values
```

## Competitor Feature Matrix

### Cold-Start / Onboarding

| Feature | TrainingPeaks | Juggernaut AI | Fitbod | Strong | Hevy | JEFIT | Tonus (current) | Tonus (v1.2 target) |
|---------|--------------|---------------|--------|--------|------|-------|-----------------|---------------------|
| Training frequency Q | Via ATP wizard | Yes | Yes | No (minimal onboarding) | No (minimal) | Yes | Yes (exists) | Yes |
| Experience level Q | No | Yes (detailed) | Yes | No | No | No | Yes (exists) | Yes |
| Session duration Q | Via weekly hours | Implied | Yes | No | No | No | No | Yes (new) |
| Intensity/RPE Q | No | Per-session readiness | No | No | No | No | No | Yes (new) |
| Weeks at level Q | No | No | No | No | No | No | No | Yes (differentiator) |
| Training age Q | No | Yes | No | No | No | No | No | Yes (optional) |
| Periodization Q | Via ATP | Yes (block/undulating) | No | No | No | No | No | Yes (optional) |
| Movement/equipment Q | No | Lift technique | Yes (equipment) | No | No | No | No | Yes (optional) |
| Injury history Q | No | Yes (weaknesses) | No | No | No | No | No | Yes (optional flag) |
| CTL/load seeding | Yes (manual) | Implicit (AI plans) | Implicit (population data) | No | No | No | No | Yes (formula-based) |
| Estimated vs actual comparison | Reset after 4-6 weeks | No (AI adapts continuously) | No | No | No | No | No | Yes (silent bias metric) |

### Template / Routine Management

| Feature | Strong | Hevy | JEFIT | Fitbod | Tonus (current) | Tonus (v1.2 target) |
|---------|--------|------|-------|--------|-----------------|---------------------|
| Save from session | Yes (prompt at end) | Yes (profile > save as routine) | Yes | N/A (AI-generated) | No | Yes |
| Create from scratch | Yes | Yes | Yes (web + mobile) | N/A | Coach only | Yes (athletes) |
| Template picker | Yes (Start Workout tab) | Yes (Workout tab) | Yes | N/A | Coach prescribed only | Yes |
| Folders/organization | Yes (folders + drag-drop) | Yes (folders + drag-drop) | Yes (categories) | N/A | No | No (v1.3 if needed) |
| Last-used auto-fill | Yes (auto-populate) | Yes (PREVIOUS column) | Yes | Yes (algorithm) | No | Yes |
| Progressive suggestions | No (manual only) | No | Yes (AI overload) | Yes (auto-adjust) | ProgressionEngine (Pro) | Yes, overlaid on templates (Pro) |
| Update routine after workout | No (separate edit) | Yes ("Update routine?") | No | N/A | No | Yes (Hevy pattern) |
| Exercise groups (supersets) | Supersets (implicit) | Supersets | Yes | Yes | ExerciseGroup (coach model) | Yes (A/B/C/D groups) |
| Dashboard quick-start | No (separate tab) | No (separate tab) | No | N/A | No | Yes (differentiator) |
| HealthKit workout matching | No | No | No | No | Import only | Yes (differentiator) |
| Schedule suggestions | No | No | No | Muscle-based | No | Yes (day-of-week, differentiator) |
| Dynamic targets | No | AI-driven entire plan | No | AI-driven per exercise | ProgressionEngine exists | Yes, per template (differentiator) |
| Free template limit | 3 | Unlimited | Unknown | N/A (subscription) | N/A | Unlimited (templates free) |
| Sharing | Yes | Yes (links + images) | Community | No | No | No (v1.3) |

## MVP Recommendation

### Must-have for v1.2 (build in this order):

**Cold-Start Questionnaire:**
1. **TrainingProfile model + 4 required questions** (Low) -- Session duration and sRPE are the two new data points needed for seeding. Frequency and experience already exist. Weeks-at-level is one segmented control. Wire into existing onboarding flow after experience step, before HealthKit.
2. **ColdStartSeedingEngine** (Medium) -- Pure struct that takes TrainingProfile inputs and produces initial ATL/CTL estimates using TSS = hours x RPE x (RPE/10), mapped to EWMA equivalents. Reference TrainingPeaks CTL estimation methodology (weekly hours -> CTL via TSS).
3. **Parallel data track storage** (Medium-High) -- WorkloadSnapshot gains `estimatedATL`/`estimatedCTL` fields. Switchover logic at 3 weeks + 8 sessions.

**Training Templates:**
4. **Template ownership for athletes** (Low) -- Refactor `coachId` on WorkoutTemplate to `ownerId` or add `athleteId` so athletes can own templates. Critical prerequisite for all template features.
5. **Save-from-session** (Medium) -- Post-workout "Save as Template?" prompt. Highest-value template creation path. Maps session exercises/sets to template structure using existing model.
6. **Template picker + last-used auto-fill** (Medium) -- Start workout from template with pre-filled values from history. This is the core template UX loop: create from session -> reuse from picker -> update from changes.
7. **Dashboard quick-start cards** (Medium) -- 2-3 most recent/favorite templates as tap-to-start cards on dashboard. Differentiator that reduces friction.
8. **Template management (edit, duplicate, archive, favorite, delete)** (Medium) -- Full CRUD. Duplicate uses existing `deepCopyGroups()`. Archive/favorite are boolean flags.

### Build if time permits:
9. **Dynamic targets with ProgressionEngine overlay** (Medium) -- Pro-gated. ProgressionEngine.suggest() already produces suggestions. Wire suggestions into template auto-fill alongside last-used values.
10. **TemplateSuggestionEngine** (Medium) -- Day-of-week frequency analysis. Only useful after 2+ weeks of template usage data, so can ship slightly after core template features.
11. **Optional questionnaire questions (4)** (Low each) -- Training age, periodization pref, movement types, injury flag. Stored in TrainingProfile. No functional impact in v1.2 but enriches data.

### Defer to v1.3+:
- HealthKit workout -> template matching (High complexity, needs fuzzy matching logic)
- Perceptual bias calibration (use case unclear until more data)
- Template sharing between users (PROJECT.md scope)
- Template folders (premature optimization -- users need 10+ templates first)
- LLM-powered import (PROJECT.md scope)

## Complexity Estimates

| Feature | New Files | Existing File Changes | Subscription Gate | Risk |
|---------|-----------|----------------------|-------------------|------|
| TrainingProfile model | 1 (TrainingProfile.swift) | ModelContainer schema, Supabase sync | Free | Low -- simple @Model class |
| Cold-start questionnaire UI | 1-2 (new onboarding steps) | OnboardingView.swift (add steps), Enums.swift (new enums) | Free | Low -- follows existing onboarding pattern |
| ColdStartSeedingEngine | 1 (ColdStartSeedingEngine.swift) | WorkoutPipeline (invoke at onboarding), AppRouter (trigger seeding) | Free | Medium -- math must be validated |
| Parallel ATL/CTL tracks | 0 new | WorkloadSnapshot model, WorkloadCalculator, WorkloadRepository | Free | High -- most risky change, touches core data model |
| Template ownership refactor | 0 new | WorkoutTemplate model (coachId -> ownerId or add athleteId), sync schema | Free | Medium -- schema migration |
| Save-from-session | 1 (SaveAsTemplateSheet.swift) | ActiveWorkoutSheet (prompt trigger) | Free | Low -- model mapping |
| Template picker | 1 (TemplatePickerView.swift) | WorkoutLogView (entry point) | Free | Low -- list + start action |
| Last-used auto-fill | 0 new | ActiveWorkoutSheet (pre-fill logic), ProgressionEngine.fetchHistory() | Free | Low -- query exists |
| Dashboard quick-start cards | 1 (TemplateQuickStartCard.swift) | DashboardView, DashboardViewModel | Free | Low -- UI component |
| Template management CRUD | 1-2 (TemplateDetailView, TemplateEditorView) | WorkoutTemplate model (archive/favorite flags) | Free | Medium -- drag-drop reorder |
| Dynamic targets overlay | 0 new | Template auto-fill logic, ProgressionEngine integration | Pro | Medium -- UX for showing suggestion vs last-used |
| TemplateSuggestionEngine | 1 (TemplateSuggestionEngine.swift) | DashboardViewModel (suggestion query) | Free (suggestions) / Pro (reasoning) | Low -- day-of-week counting |
| Optional Qs (4) | 0 new | OnboardingView or ProfileView, TrainingProfile model, Enums.swift | Free | Low -- UI + storage only |
| Perceptual bias capture | 0 new | TrainingProfile (bias field), ColdStartSeedingEngine (comparison at 8wk) | Free | Low -- two numbers compared |

## Key Design Decisions for Implementation

### Template Ownership Model
The existing `WorkoutTemplate.coachId` needs to work for athletes too. Two options:
- **Option A:** Rename `coachId` to `ownerId` (cleaner, but migration needed)
- **Option B:** Add optional `athleteId` alongside `coachId` (additive, no migration)

Recommend **Option A** -- `ownerId` is semantically correct for both coaches and athletes. Worth the migration.

### Questionnaire Placement
The 4 required questions should extend the existing 3-step onboarding:
- Step 1: Training frequency (exists)
- Step 2: Experience level (exists)
- Step 3: Session duration (NEW)
- Step 4: Typical sRPE (NEW)
- Step 5: Weeks at current level (NEW)
- Step 6: HealthKit permission (exists, stays last)

Optional questions belong in Profile settings, not onboarding. Reduce onboarding friction.

### Free vs Pro Gate Strategy
Following the PROJECT.md decision: **templates free, intelligence Pro-gated**.
- Free: create templates, save from session, picker, last-used auto-fill, management, dashboard cards
- Pro: ProgressionEngine overlay on targets (increase/maintain/deload), suggestion reasoning text, schedule-aware suggestions

This mirrors Hevy's model (unlimited free routines, analytics behind Pro) and Strong's inverse (3 free templates, unlimited Pro). Tonus's approach is more generous on templates but gates the intelligence layer.

## Sources

- [Strong Help Center - About Templates](https://help.strongapp.io/article/105-about-templates) -- template definition, creation methods, free vs Pro limits (3 free, unlimited Pro)
- [Hevy - Gym Routines](https://www.hevyapp.com/features/gym-routines/) -- routine creation, folder organization, drag-and-drop, duplication
- [Hevy - Exercise Programming](https://www.hevyapp.com/features/exercise-programming-options/) -- PREVIOUS column, auto-fill from last session
- [Hevy - Track Exercises](https://www.hevyapp.com/features/track-exercises/) -- previous workout values display
- [TrainingPeaks - Estimate Starting Fitness CTL](https://help.trainingpeaks.com/hc/en-us/articles/230903988-Estimate-Starting-Fitness-CTL) -- CTL seeding from weekly training hours, 4-6 week cautious interpretation period
- [TrainingPeaks - Suggested Weekly TSS and Target CTL](https://help.trainingpeaks.com/hc/en-us/articles/230904648-Suggested-Weekly-TSS-and-Target-CTL) -- TSS-to-CTL mapping tables
- [TrainingPeaks - A Coach's Guide to ATL, CTL, TSB](https://www.trainingpeaks.com/coach-blog/a-coachs-guide-to-atl-ctl-tsb/) -- EWMA methodology, time constants
- [ProCyclingCoaching CTL Calculator](https://www.procyclingcoaching.com/resources/fitness-ctl-calculator) -- CTL = 42-day exponential average, TSS-to-CTL target table
- [Juggernaut AI App Store](https://apps.apple.com/us/app/juggernautai/id1515756471) -- 10 Quadrillion permutations from intake questionnaire
- [Juggernaut AI Review (PowerliftingTechnique)](https://powerliftingtechnique.com/juggernaut-ai-review/) -- onboarding covers gender, age, size, strength, experience, recovery
- [Fitbod Algorithm](https://fitbod.me/blog/fitbod-algorithm/) -- cold-start uses population data from 150M+ workouts, muscle recovery model
- [Fitbod FAQ](https://fitbod.me/faqs/) -- onboarding quiz covers goals, experience, equipment
- [Strong App Review 2025](https://repreturn.com/strong-app-review/) -- contextual onboarding, minimal questionnaire
- [Strong App Showcase](https://screensdesign.com/showcase/strong-workout-tracker-gym-log) -- 2-step onboarding, mandatory sign-up friction
- [Strong vs Hevy 2026 comparison](https://setgraph.app/ai-blog/hevy-vs-strong-app-comparison-2026) -- pricing, free vs Pro limits
- [sRPE validity research (Frontiers)](https://www.frontiersin.org/journals/neuroscience/articles/10.3389/fnins.2017.00612/full) -- sRPE overestimates by ~15%, substantial interindividual variability
- [sRPE CrossFit validity 2025](https://www.mdpi.com/2076-3417/15/22/12159) -- sRPE valid but overestimates, learning curve effect
- [JEFIT features](https://www.jefit.com/) -- 850+ plans, AI progressive overload, 1500+ exercises
