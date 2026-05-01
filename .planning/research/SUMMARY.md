# Project Research Summary

**Project:** Tonus v1.2 — Training Onboarding & Templates
**Domain:** iOS fitness app — cold-start questionnaire with ATL/CTL seeding + athlete-owned training templates
**Researched:** 2026-05-01
**Confidence:** HIGH

## Executive Summary

Tonus v1.2 adds two interrelated systems to an already-working SwiftUI/SwiftData fitness app: a cold-start questionnaire that seeds the EWMA workload engine for new users, and athlete-owned training templates with intelligent suggestions. Both features extend the existing layer architecture (Views → ViewModels → Pipelines → Engines → Repositories → Models) without requiring new SPM dependencies or Apple frameworks. The recommended approach is purely additive schema changes — new models, new optional fields with defaults, and new pure-struct engines following the existing WorkloadCalculator/RecoveryScoreEngine patterns — which keeps the migration story safe for all existing users upgrading from v1.1.

The primary risk is data contamination between the estimated ATL/CTL values (from the questionnaire) and the real EWMA chain (computed from logged sessions). Research is unambiguous: estimated values must live only on `TrainingProfile`, never on `WorkloadSnapshot`. A parallel-track architecture where the dashboard reads from `TrainingProfile` during the cold-start window and switches to `WorkloadSnapshot` after 3 weeks + 8 sessions is the correct design. The secondary risk is a SwiftData crash on update if any model field is renamed rather than added — the `coachId` → `ownerId` refactor must be avoided in favor of an additive `isAthleteOwned` boolean flag.

Template features are simpler architecturally but require discipline on ownership semantics. The existing `WorkoutTemplate` model's `coachId` field already stores "who owns this," and athletes should reuse it by storing their own UUID in that field alongside an `isAthleteOwned: Bool = false` discriminator. This avoids schema migrations and keeps existing coach template code unchanged. Supabase RLS policies must be updated before any template sync code is written — the current policies are scoped to coach role and will silently drop all athlete template upserts due to the SyncService's pervasive `try?` error suppression.

## Key Findings

### Recommended Stack

No new dependencies are required for v1.2. The full feature set — cold-start seeding, template management, day-of-week suggestions, ProgressionEngine overlay — is buildable with existing SwiftUI, SwiftData, HealthKit, Charts, and the Supabase/RevenueCat SDKs already in the project. Two new pure-struct engines (ColdStartEngine, TemplateSuggestionEngine) and one new repository (TemplateRepository) are the only architectural additions. All schema changes are additive with defaults, enabling SwiftData lightweight migration throughout.

**Core technologies:**
- SwiftData `@Model` (TrainingProfile, new): store questionnaire answers + seeded ATL/CTL + bias tracking — avoids bloating the Athlete model with 15+ write-once questionnaire fields that have a separate lifecycle
- ColdStartEngine (new pure struct): converts questionnaire answers to ATL/CTL seeds using the identical sRPE TSS formula already in WorkloadCalculator — deterministic, sport-science validated, no ML or external API needed
- WorkoutTemplate model (extended): reused for athlete ownership via `isAthleteOwned` discriminator and new `isFavorite`, `isArchived`, `lastUsedAt`, `usageCount`, `scheduledDays` additive fields with defaults
- TemplateSuggestionEngine (new pure struct): day-of-week frequency + recovery-aware ranking, ~100 lines of weighted scoring — no recommendation library needed, follows existing engine pattern
- ProgressionEngine (existing, unchanged): called per-exercise when loading a template; overlay approach (template = baseline, Progression = modifier) avoids dual-number confusion in the UI

### Expected Features

From competitor analysis (Strong, Hevy, JEFIT, Fitbod, Juggernaut AI, TrainingPeaks), the following features define user expectations for this milestone:

**Must have (table stakes):**
- Training frequency + experience questions in onboarding — every serious fitness app collects these; Tonus already has them
- Typical session duration + intensity (sRPE) — the two missing inputs needed for the TSS seeding formula (hours × RPE × RPE/10)
- Save-from-session — Strong and Hevy both auto-prompt at workout completion; this is the primary template creation path in every competitor
- Template picker with last-used auto-fill — the core template usage loop; Hevy shows a PREVIOUS column, Strong pre-fills inputs
- Template CRUD (edit, duplicate, archive, favorite, delete) — basic hygiene for a growing template library

**Should have (competitive differentiators):**
- Dashboard quick-start cards — no competitor puts templates on the dashboard; reduces session-start from 3 taps to 1
- Dynamic targets with ProgressionEngine overlay (Pro-gated) — "last-used" baseline + recovery-aware adjustment is unique to Tonus
- Schedule-aware suggestions — day-of-week pattern detection after 2+ weeks of data; "you usually do Push on Tuesdays"
- Perceptual bias measurement (silent) — questionnaire estimate vs. actual at switchover; no competitor does this
- Training age + periodization preference (optional) — enriches TrainingProfile for future intelligence features at zero engineering cost

**Defer to v1.3+:**
- Template sharing between users (explicitly scoped to v1.3 in PROJECT.md)
- LLM-powered workout import from photos/text (explicitly deferred in PROJECT.md)
- Template folders/organization (premature before users have 10+ templates)
- Pre-built template library / program marketplace (content work, not engineering)
- HealthKit workout-to-template matching (high false-positive risk; HealthKit provides no exercise-level data; demoted from differentiator to post-v1.2)

**Free vs Pro gate strategy:**
- Free: create templates, save from session, picker, last-used auto-fill, management, dashboard cards
- Pro: ProgressionEngine overlay on targets, suggestion reasoning text, schedule-aware suggestions

### Architecture Approach

The new features integrate into the existing five-layer stack without new patterns. Cold-start adds a `TrainingProfile` model with a parallel data track: estimated ATL/CTL lives on `TrainingProfile` and is displayed on the dashboard during the cold-start window; real ATL/CTL accumulates in `WorkloadSnapshot` as always; switchover at 3 weeks + 8 sessions transitions the dashboard to the real track permanently. Template features add a `TemplateRepository`, extend `ActiveWorkoutSheet` to accept a `WorkoutTemplate?` alongside the existing `PrescribedWorkout?`, and introduce a new `TemplateManagementView` for athlete mode (distinct from the coach `TemplateListView`).

**Major new/modified components:**
1. TrainingProfile (`@Model`) — write-once questionnaire answers + seeded ATL/CTL + bias tracking; fetched by DashboardViewModel and WorkoutPipeline during cold-start window
2. ColdStartEngine (pure struct) — sRPE TSS formula → ATL/CTL seeds; same formula as WorkloadCalculator so seeds are EWMA-compatible from day one
3. TemplateSuggestionEngine (pure struct) — ranks non-archived templates by schedule, frequency, recency, favorite flag, and recovery-awareness; returns top-3 for dashboard cards
4. TemplateRepository (`@MainActor final class`) — CRUD for athlete-owned templates; all queries include ownership filter to prevent coach/athlete data leakage
5. WorkoutPipeline (modified) — real EWMA track unchanged; parallel estimated track added as conditional block when `TrainingProfile` exists and `switchoverDate == nil`
6. DashboardViewModel (modified) — reads from `TrainingProfile` for estimated display vs. `WorkloadSnapshot` for real; gates FatigueIndex behind minimum real session count

**Recommended build order (from dependency analysis):**
Phase 1 → Foundation (models + engines + Supabase schema)
Phase 2 → Cold-start integration (questionnaire UI + pipeline parallel track)
Phase 3 → Template management (list/edit/archive/favorite)
Phase 4 → Template-driven workouts (picker + ActiveWorkoutSheet + save-from-session)
Phase 5 → Smart suggestions (TemplateSuggestionEngine + dashboard cards)
Phase 6 → Bias measurement + polish

### Critical Pitfalls

1. **EWMA contamination via parallel track** — estimated ATL/CTL must live only on `TrainingProfile`, never written to `WorkloadSnapshot`. The moment estimated values enter the real snapshot chain, every downstream recommendation engine inherits the error for 84+ days (3 EWMA time constants). Dashboard must read from `TrainingProfile` during cold-start, not from snapshots.

2. **SwiftData migration crash on update** — any field rename (e.g., `coachId` → `ownerId`) requires a custom `SchemaMigrationPlan` that the app currently has no infrastructure for. Without it, existing users hit the `fatalError` in `WorkloadApp.swift` on update. All model changes must be additive with defaults. Use `isAthleteOwned: Bool = false` instead of renaming.

3. **Supabase RLS silently blocking athlete template sync** — existing `workout_templates` RLS policies are scoped to coach role. Athlete template upserts fail silently because SyncService uses `try?` throughout. Templates appear to save locally but never reach Supabase; data is lost on device change. RLS must be updated before any template sync code is written.

4. **coachId semantics collision** — reusing `coachId` for athlete templates without an explicit discriminator causes coach-mode views that query all `WorkoutTemplate` records to return athlete templates (and vice versa). Every `@Query` and `FetchDescriptor` on `WorkoutTemplate` must include an ownership filter from the moment athlete templates exist.

5. **TemplateSuggestionEngine noisy early suggestions** — with fewer than 2 occurrences of the same template on the same day-of-week, suggestions are noise that erodes user trust in the feature. Gate behind 3 weeks of data AND 2+ pattern occurrences; show "recently used" cards instead of "suggested" when below threshold.

## Implications for Roadmap

Based on combined research, the dependency graph enforces a clear 6-phase build order. Skipping phases or reordering will introduce data contamination (cold-start parallel track), migration crashes (model renames), or silent data loss (RLS before sync).

### Phase 1: Foundation — Models, Engines, Supabase Schema
**Rationale:** Every subsequent phase depends on models existing and Supabase being updated. The RLS update must happen before any template sync. The `TrainingProfile` model must exist before the questionnaire UI can save answers. Starting here de-risks the migration story for all existing users before any user-facing code is written.
**Delivers:** TrainingProfile model, WorkloadSnapshot.isEstimated field, WorkoutTemplate additive fields (isFavorite, isArchived, lastUsedAt, usageCount, scheduledDays, isAthleteOwned), WorkoutSession.templateId, ColdStartEngine pure struct, TemplateRepository, Supabase migration SQL, SyncService additions, WorkloadApp schema registration
**Addresses:** Template list prerequisites, cold-start questionnaire prerequisites
**Avoids:** Pitfall 3 (migration crash) — additive-only changes, no renames; Pitfall 10 (RLS denial) — Supabase updated before sync code; Pitfall 2 (coachId collision) — isAthleteOwned discriminator established from the start

### Phase 2: Cold-Start Questionnaire Integration
**Rationale:** New user experience must be complete before templates, because seeded ATL/CTL values improve the quality of ProgressionEngine suggestions that templates will display. New users who skip cold-start see worse dynamic targets in Phase 4.
**Delivers:** ColdStartQuestionnaireView (sub-flow), OnboardingView extension (4 required + optional steps, max 5 screens total), WorkoutPipeline parallel track logic, WorkloadRepository estimated filtering, DashboardViewModel switchover display logic, FatigueIndex data gating (min 5 real sessions)
**Addresses:** Session duration + sRPE questions (table stakes), weeks-at-level question (differentiator), estimated vs. actual ATL/CTL parallel tracking (differentiator)
**Avoids:** Pitfall 1 (EWMA contamination) — estimated values on TrainingProfile only, never WorkloadSnapshot; Pitfall 4 (pipeline contamination) — real pipeline unchanged; Pitfall 5 (onboarding friction) — merged into existing flow, max 5 screens; Pitfall 13 (FatigueIndex confusion) — gated on real session count

### Phase 3: Template Management
**Rationale:** Templates must be creatable and manageable before they can drive workouts. Establishing the management layer first ensures ownership filters are in place on all queries before any template-driven workout flows are built on top.
**Delivers:** TemplateManagementView (list/edit/archive/favorite/delete), TemplateEditorSheet athlete adaptation, MainTabView Templates tab for athlete mode, TemplateDetailView (usage stats, scheduled days)
**Addresses:** Template list/library (table stakes), template deletion (table stakes), template creation from scratch (table stakes), template editing (table stakes), template duplication (differentiator), template archiving (differentiator), template favoriting (differentiator)
**Avoids:** Pitfall 15 (coach query breakage) — ownership filters on all template queries; Pitfall 6 (cascade deletion bugs) — always deep-copy via deepCopyGroups(), never share ExerciseGroup instances between template and prescription parents

### Phase 4: Template-Driven Workouts
**Rationale:** Depends on Phase 3 templates being manageable. The save-from-session and template picker flows are the core usage loop that generates the usage data Phase 5 needs for pattern detection.
**Delivers:** TemplatePickerSheet, ActiveWorkoutSheet dual-init (template + prescription paths), loadTemplate() with ProgressionEngine overlay (Pro), post-session template target refresh (lastUsedAt + usageCount + target values), SaveAsTemplateSheet with editable confirmation
**Addresses:** Template picker + last-used auto-fill (table stakes), save-from-session (table stakes), dynamic targets with ProgressionEngine overlay (Pro differentiator), "Update routine after workout" Hevy pattern (differentiator)
**Avoids:** Anti-pattern 4 (eager ProgressionEngine evaluation) — load base targets immediately, overlay suggestions in background Task; Pitfall 8 (conflicting numbers) — template = baseline, ProgressionEngine = modifier with explicit UI layering; Pitfall 14 (atypical session captured as default) — show editable confirmation before saving

### Phase 5: Smart Suggestions
**Rationale:** Suggestion quality depends on template usage data accumulated in Phase 4. Building TemplateSuggestionEngine before templates have usage history would produce the noisy-early-suggestions pitfall with no recovery path and would erode trust in the feature permanently.
**Delivers:** TemplateSuggestionEngine (day-of-week + recovery + schedule scoring), TemplateQuickStartCard component, DashboardView quick-start section (top-3 templates), schedule-aware suggestions with day-of-week pattern detection
**Addresses:** Dashboard quick-start cards (differentiator), schedule-aware template suggestions (differentiator)
**Avoids:** Pitfall 7 (noisy early suggestions) — minimum 3-week + 2-occurrence data gate, shows "recently used" before threshold; Pitfall 9 (HealthKit false positives) — no auto-match from HealthKit since HKWorkout contains no exercise-level data

### Phase 6: Bias Measurement + Polish
**Rationale:** Bias measurement is a silent background metric with no user-facing urgency and no dependencies on user action. Profile settings and template duplication are polish items that can ship any time without blocking other features.
**Delivers:** Switchover-time bias capture (store estimated vs. real ATL/CTL at transition moment on TrainingProfile), profile settings to view or re-trigger cold-start questionnaire, template duplication flow
**Addresses:** Perceptual bias measurement (differentiator), training age + optional questionnaire questions (differentiator)
**Avoids:** Pitfall 11 (bias timing mismatch) — capture at switchover moment, not a fixed 8-week clock; Pitfall 12 (favorite/archive sync state inconsistency) — these fields were included in Phase 1 Supabase migration

### Phase Ordering Rationale

The dependency graph is strict: models before UI, Supabase schema before sync code, cold-start before templates (for ProgressionEngine quality on new users), template management before template-driven workouts (for ownership model integrity), usage data before suggestions. The only flexibility is the ordering of optional questionnaire questions (Phase 2 or later) and bias capture (Phase 6). The parallel-track architecture in Phases 1-2 is the most novel technical work and should be validated with unit tests of the EWMA contamination boundary before template features build on top of it.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 2 (Cold-Start Pipeline):** WorkoutPipeline parallel track interaction with WorkloadRepository.upsertSnapshot has subtle edge cases — specifically, existing users who already have WorkloadSnapshot history before completing cold-start. The conditional branching ("pre-existing real data = skip seeding entirely") needs precise specification before implementation.
- **Phase 4 (Dynamic Targets UX):** The visual design for showing template baseline vs. ProgressionEngine modifier simultaneously in set entry cells is not specified. A design decision is required before implementation to avoid the conflicting-numbers anti-pattern manifesting in the UI.

Phases with standard patterns (skip research-phase):
- **Phase 1 (Foundation):** SwiftData lightweight migration for additive fields is well-documented. Supabase ALTER TABLE operations are standard SQL. Pure-struct engine pattern is established in the codebase.
- **Phase 3 (Template Management):** Standard SwiftUI CRUD with existing deepCopyGroups() method. No novel architecture.
- **Phase 5 (Suggestions):** TemplateSuggestionEngine is ~100 lines of weighted scoring. Follows existing FatigueIndexEngine data-sufficiency gating pattern.
- **Phase 6 (Polish):** Bias capture is two numbers compared at a known event. No research needed.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Zero new dependencies confirmed by checking all v1.2 feature requirements against existing framework capabilities. Lightweight migration confirmed by Apple WWDC23 documentation and Hacking with Swift guides. |
| Features | HIGH | Competitor matrix covers 6 direct competitors with source links. sRPE TSS formula validated by TrainingPeaks documentation and sport science literature. Free/Pro gating decision grounded in Hevy/Strong pricing comparison. |
| Architecture | HIGH | All decisions derived from direct codebase analysis — actual source files read for WorkloadCalculator.swift, WorkoutPipeline.swift, WorkoutTemplate.swift, SyncService.swift, FatigueIndexEngine.swift, OnboardingView.swift, ActiveWorkoutSheet.swift, DashboardViewModel.swift, WorkloadApp.swift. |
| Pitfalls | HIGH | 10 of 15 pitfalls rated HIGH confidence with direct code file + line number citations. EWMA contamination verified via WorkloadCalculator.swift. Migration crash verified via WorkloadApp.swift (no VersionedSchema). RLS issue verified via SyncService.swift try? pattern. |

**Overall confidence:** HIGH

### Gaps to Address

- **SwiftData VersionedSchema infrastructure:** The app has no existing VersionedSchema. Even though v1.2 uses only additive changes (no migration needed), establishing VersionedSchema infrastructure now prevents future migration debt when a field rename eventually becomes necessary. Decision needed in Phase 1: invest in V2/V3 schema versioning now, or defer until a rename is truly required.
- **Existing-user cold-start edge case:** Users who already have WorkloadSnapshot history before completing the cold-start questionnaire should skip the parallel-track seeding entirely (they already have real data). This boundary condition is not fully specified and must be defined before Phase 2 implementation.
- **ProgressionEngine overlay UX design:** How to visually layer "template target" and "ProgressionEngine modifier" in the same set entry cell is unspecified. DESIGN.md constraints (0pt corners, DM Sans, 8pt grid, no color as sole indicator) apply. A design decision is required before Phase 4 to avoid the conflicting-numbers anti-pattern.
- **TemplateSuggestionEngine seeding for users with prior coach templates:** Users who had coach-prescribed templates before v1.2 will have zero usage history in the new athlete template system. The suggestion engine must degrade gracefully to "recently used" mode for all users in the first 3 weeks regardless of prior template history — this edge case should be explicitly handled in Phase 5.

## Sources

### Primary (HIGH confidence)
- Apple WWDC23: Model your schema with SwiftData — lightweight migration behavior for new models and additive properties
- TrainingPeaks: Science of the Performance Manager — EWMA cold-start seeding approach, CTL steady-state approximation
- TrainingPeaks: Estimating Training Stress Score (TSS) — sRPE-based TSS formula (hours × RPE × RPE/10), CTL ranges by athlete level
- HKWorkout / HKWorkoutActivityType documentation — HealthKit workout data limitations (activity type, duration, calories only — no exercise-level data)
- Existing codebase (WorkloadCalculator.swift, WorkoutPipeline.swift, WorkoutTemplate.swift, SyncService.swift, WorkloadApp.swift, OnboardingView.swift, ActiveWorkoutSheet.swift, DashboardViewModel.swift, FatigueIndexEngine.swift, AutoregulationEngine.swift, ProgressionEngine.swift, WorkoutImportBanner.swift, PrescribedWorkout.swift) — all architecture decisions verified against actual source lines

### Secondary (MEDIUM confidence)
- Hevy, Strong app feature analysis — template/routine feature expectations and competitor matrix; free vs. Pro gating models
- Juggernaut AI App Store reviews — onboarding questionnaire depth, training age and periodization preference collection
- Fitbod algorithm blog — cold-start population-data approach (Tonus uses formula instead; different but validated approach)
- sRPE validity research (Frontiers Neuroscience) — sRPE overestimates by ~15%, substantial interindividual variability, justifies using RPE defaults slightly conservative
- SwiftData migration guides (Hacking with Swift, Donny Wals, Atomic Robot) — VersionedSchema patterns and lightweight vs. custom migration boundaries

### Tertiary (LOW confidence)
- ProCyclingCoaching CTL Calculator — CTL target ranges by athlete type (secondary validation only, access restricted)
- EWMA theory (Towards Data Science) — mathematical basis for 84-day error persistence from bad seed value
- MadAppGang / Dataconomy fitness app UX articles — onboarding friction thresholds and 80% completion target benchmarks

---
*Research completed: 2026-05-01*
*Ready for roadmap: yes*
