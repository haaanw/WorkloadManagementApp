# Roadmap: Tonus

## Milestones

- ✅ **v1.0 Post-Launch** — Phases 1-4 (shipped 2026-04-22)
- ✅ **v1.1 App Store Launch** — Phases 5-8 (shipped 2026-04-30)
- 🚧 **v1.2 Training Onboarding & Templates** — Phases 9-12 (in progress)
- 📋 **v1.3 LLM Import & Template Sharing** — Phases 13-14 (planned)
- 📋 **v1.5 UX Interaction Polish** — Phases 19-20 (planned)
- 📋 **v1.4 Female Athlete Optimization** — Phases 15-18 (planned)

## Phases

<details>
<summary>✅ v1.0 Post-Launch (Phases 1-4) — SHIPPED 2026-04-22</summary>

- [x] Phase 1: App Store Launch (3/3 plans) — completed 2026-04-20
- [x] Phase 2: Analytics & Export (4/4 plans) — completed 2026-04-20
- [x] Phase 3: Training Intelligence (4/4 plans) — completed 2026-04-21
- [x] Phase 4: Onboarding & Polish (3/3 plans) — completed 2026-04-22

</details>

<details>
<summary>✅ v1.1 App Store Launch (Phases 5-8) — SHIPPED 2026-04-30</summary>

- [x] Phase 5: Streaks & Notifications (3/3 plans)
- [x] Phase 6: PDF Report Export (3/3 plans)
- [x] Phase 7: App Store Metadata (3/3 plans)
- [x] Phase 8: QA, Performance & Compliance

</details>

### 🚧 v1.2 Training Onboarding & Templates (In Progress)

**Milestone Goal:** Bridge the cold-start data gap and streamline workout logging -- new athletes get useful guidance from day one, and returning athletes log sessions in seconds via reusable templates.

- [ ] **Phase 9: Foundation & Cold-Start Engine** - Data models, pure engines, Supabase schema, and RLS policies that everything else depends on
- [x] **Phase 10: Cold-Start Questionnaire** - Questionnaire UI with parallel-track ATL/CTL seeding, switchover logic, and silent bias capture (completed 2026-05-08)
- [x] **Phase 11: Template Management & Creation** - Athlete-owned template CRUD, manual creation, and save-from-session (completed 2026-05-09)
- [x] **Phase 12: Template-Driven Workouts & Smart Suggestions** - Template picker, dynamic targets, dashboard quick-start cards, and schedule-aware suggestions (completed 2026-05-10)

## Phase Details

### Phase 9: Foundation & Cold-Start Engine
**Goal**: All data models, pure computation engines, Supabase schema migrations, and RLS policies are in place so that cold-start and template features can be built without infrastructure blockers
**Depends on**: Phase 8
**Requirements**: FOUND-01, FOUND-02, FOUND-03, FOUND-04, COLD-03
**Success Criteria** (what must be TRUE):
  1. TrainingProfile model persists questionnaire answers, seeded ATL/CTL, and bias fields locally via SwiftData and syncs to Supabase
  2. WorkoutTemplate model accepts athlete ownership (isAthleteOwned, isFavorite, isArchived, lastUsedAt, usageCount, scheduledDays) with zero migration errors for existing users
  3. ColdStartEngine computes seeded ATL/CTL from questionnaire inputs (sessions/week, avg duration, sRPE) using the sRPE TSS formula, producing values compatible with the existing EWMA chain
  4. TemplateRepository provides fetch, save, duplicate, archive, and delete operations filtered by athlete ownership
  5. Supabase RLS policies allow athlete-owned template CRUD without breaking existing coach template policies
**Plans**: TBD

### Phase 10: Cold-Start Questionnaire
**Goal**: New athletes can answer a brief training questionnaire and immediately see estimated workload data on their dashboard, with automatic switchover to real data as they log sessions
**Depends on**: Phase 9
**Requirements**: COLD-01, COLD-02, COLD-04, COLD-05, COLD-06, COLD-07
**Success Criteria** (what must be TRUE):
  1. User can complete 4 required questions (sessions/week, avg duration, typical sRPE 1-10, weeks at current level) via a training profile card after onboarding
  2. User can optionally answer 4 additional questions (training age in years, periodized vs steady schedule, movement types, injury history with body region picker + free text)
  3. Dashboard displays estimated ATL/CTL values during the cold-start window, and these values never appear on WorkloadSnapshot
  4. Dashboard automatically switches from estimated to real ATL/CTL after 3+ weeks elapsed AND 8+ sessions logged, with no user action required
  5. FatigueIndex shows an "insufficient data" state during the cold-start window instead of computing from incomplete baselines
**Plans:** 3/3 plans complete

Plans:
- [x] 10-01-PLAN.md — Questionnaire form, dashboard card, and TrainingProfile repository
- [x] 10-02-PLAN.md — Dashboard cold-start data path, EST annotations, and FatigueIndex suppression
- [x] 10-03-PLAN.md — Switchover logic, bias capture, and ProfileView re-edit section

**UI hint**: yes

### Phase 11: Template Management & Creation
**Goal**: Athletes can build a personal library of reusable training templates and manage them with full CRUD operations
**Depends on**: Phase 9
**Requirements**: TMPL-01, TMPL-02, TMPL-05
**Success Criteria** (what must be TRUE):
  1. User can manually create a training template with named exercise groups (A/B/C/D), each containing exercises with target sets/reps/weight
  2. User can save a completed workout session as a new template with an editable confirmation step before saving
  3. User can edit, duplicate, archive, favorite/pin, and delete templates from a dedicated template management view
**Plans:** 2/2 plans complete

Plans:
- [x] 11-01-PLAN.md — Template creation paths: editor enhancements (schedule picker, favorite toggle) and save-as-template from finished workouts
- [x] 11-02-PLAN.md — Template carousel display, preview sheet, and management actions (context menu, swipe, CRUD)

**UI hint**: yes

### Phase 12: Template-Driven Workouts & Smart Suggestions
**Goal**: Athletes can start sessions from templates in one tap with auto-filled targets, and the app learns their schedule to suggest the right template at the right time
**Depends on**: Phase 10, Phase 11
**Requirements**: TMPL-03, TMPL-04, TMPL-06, TMPL-07, TMPL-08
**Success Criteria** (what must be TRUE):
  1. User can select a saved template when starting a new session via a template picker accessible from the "+" button
  2. Template-loaded session pre-fills exercises with last-used actual values as ghost targets
  3. Dashboard and workout log tab show favorite/recent templates as quick-start cards for one-tap session start
  4. When loading a template, ProgressionEngine overlays recovery-aware suggested targets alongside last-used values (Pro-gated)
  5. TemplateSuggestionEngine suggests the most likely template based on day-of-week usage patterns when the user opens the app (Pro-gated, requires 2+ weeks of usage data)
**Plans:** 3/3 plans complete

Plans:
- [x] 12-01-PLAN.md — TemplateSuggestionEngine (pure logic) and WorkoutSession.sourceTemplateId field
- [x] 12-02-PLAN.md — ActiveWorkoutSheet template loading, ghost targets, fill buttons, ProgressionEngine overlay
- [x] 12-03-PLAN.md — Template picker sheet, carousel tap-to-start, suggestion badges, dashboard quick-start cards

**UI hint**: yes

### 📋 v1.4 Female Athlete Optimization

**Milestone Goal:** Make Tonus the first workload management app with evidence-based cycle-aware training intelligence. Read existing HealthKit cycle data from other apps (zero friction), correct male-normative baseline bias in recovery scoring, and provide cycle-contextual guidance — all while working identically for users who don't track cycles.

**Research:** `.planning/research/female-athlete-optimization-research.md` (696 lines, 60+ sources)
**Cross-AI Review:** Claude + Codex adversarial review completed. Consensus: CycleContext-first (explanations), same-phase baselines as measurement correction (not modifier), defer algorithmic modifiers to Wave 2 pending shadow-mode validation.

- [ ] **Phase 15: Cycle Data Foundation** - CycleTrackingService (HealthKit menstrual + wrist temp reader), MenstrualCycleSnapshot model, CyclePhase enum, contraceptive status in profile, HealthKit permission flow
- [ ] **Phase 16: Cycle-Aware Recovery Baselines** - RecoveryScoreEngine same-phase baseline with confidence gating, dual baseline (7-day + same-phase), graceful degradation for <3 cycles / irregular / anovulatory / OC users
- [ ] **Phase 17: Cycle Context UI & Guidance** - Dashboard cycle day indicator, phase context in recovery card, fueling/recovery prompts (avoid fasted workouts, post-training nutrition), RED-S cycle irregularity alerts with clinician-referral language
- [ ] **Phase 18: Cycle Intelligence (Shadow Mode)** - Shadow-mode analytics measuring cycle context prediction value, evidence-gated AutoregulationEngine soft modifiers (yellow zone only), FatigueIndex phase-aware dampening (validated), ProgressionEngine phase awareness

## Phase Details — v1.4

### Phase 15: Cycle Data Foundation
**Goal**: Zero-friction cycle data integration — read existing HealthKit menstrual data from apps users already use (Clue, Flo, Apple Cycle Tracking), compute cycle day/phase with confidence scoring, and handle all edge cases (irregular, anovulatory, contraceptive, perimenopause, pregnancy, lactation)
**Depends on**: Phase 9 (TrainingProfile model)
**Requirements**: CYCLE-01, CYCLE-02, CYCLE-03
**Success Criteria** (what must be TRUE):
  1. CycleTrackingService reads .menstrualFlow (with HKMetadataKeyMenstrualCycleStart), .appleSleepingWristTemperature, .contraceptive, .pregnancy, .lactation, .irregularMenstrualCycles, .ovulationTestResult from HealthKit
  2. MenstrualCycleSnapshot model stores daily cycle state (cycleDay, estimatedPhase, confidence, cycleLength, contraceptiveStatus, wristTempDeviation, exclusionFlags)
  3. CycleContext struct provides confidence-scored phase estimation with exclusion flags (pregnancy, lactation, OC, perimenopause)
  4. Users who already track cycles in Apple Health see their data automatically — zero manual re-entry
  5. Users who don't track cycles experience zero change to existing app behavior
  6. Raw menstrual data never syncs to Supabase — only derivative scores (cycle phase, cycle day) influence algorithms
  7. Contraceptive status settable in ProfileView; OC users skip all phase-based adjustments
**Plans**: TBD
**UI hint**: yes

### Phase 16: Cycle-Aware Recovery Baselines
**Goal**: Replace the male-normative 7-day rolling HRV/RHR baseline with a confidence-gated same-phase baseline that removes predictable within-athlete cyclic variance, preserving genuine fatigue detection while eliminating false warnings during normal luteal-phase HRV suppression
**Depends on**: Phase 15
**Requirements**: CYCLE-04, CYCLE-05
**Success Criteria** (what must be TRUE):
  1. RecoveryScoreEngine accepts CycleContext as optional input; nil/unknown behaves identically to current engine
  2. When cycle confidence is high (3+ regular cycles), HRV and RHR baselines use same-phase historical average from prior cycles as denominator
  3. When cycle confidence is low (<3 cycles, irregular, anovulatory), engine falls back to existing 7-day rolling baseline
  4. OC users always use 7-day baseline (hormonal environment is stable)
  5. A woman with consistent 35ms late-luteal HRV (vs 42ms follicular) scores normally during luteal, not as "declining recovery"
  6. A woman with genuine 28ms HRV during luteal (vs her 36ms same-phase average) still triggers fatigue detection
  7. RecoveryPipeline.run() queries CycleTrackingService and passes CycleContext to engine
**Plans**: TBD

### Phase 17: Cycle Context UI & Guidance
**Goal**: Surface cycle awareness in the dashboard and recommendations as context and explanations — not deterministic overrides — following Dr. Sims's evolved position of "train by readiness, use cycle as context"
**Depends on**: Phase 15, Phase 16
**Requirements**: CYCLE-06, CYCLE-07, CYCLE-08
**Success Criteria** (what must be TRUE):
  1. Dashboard shows unobtrusive cycle day/phase indicator when data available (opt-in HealthKit permission)
  2. Recovery card includes phase context when cycle influences interpretation (e.g., "You're in your luteal phase — lower HRV and higher heart rate are expected")
  3. Fueling/recovery prompts: suggest avoiding fasted hard workouts, post-training protein timing (within 45 min per Sims), hydration/cooling in luteal heat-sensitivity window
  4. RED-S monitoring: alert when 3+ consecutive missed periods OR cycle length >35 days consistently, with clinician-referral language and exclusion handling (pregnancy, OC, perimenopause, PCOS)
  5. Cycle context never says "deload because luteal" — always readiness-first with cycle as explanation
  6. All cycle UI elements are 100% optional and invisible to users who don't grant HealthKit menstrual permissions
**Plans**: TBD
**UI hint**: yes

### Phase 18: Cycle Intelligence (Shadow Mode)
**Goal**: Validate whether cycle context improves training outcome prediction before shipping algorithmic modifiers — evidence-gated approach prevents overconfident adjustments from unvalidated research
**Depends on**: Phase 16, Phase 17
**Requirements**: CYCLE-09, CYCLE-10
**Success Criteria** (what must be TRUE):
  1. Shadow-mode analytics silently measure: does cycle phase improve prediction of next-day readiness, wellness score, workout completion rate, or reported pain?
  2. If shadow mode shows signal: AutoregulationEngine accepts CycleContext, applies soft volume modifier (5-15%) only in yellow recovery zone, never overrides rest or green-zone recommendations
  3. FatigueIndex phase-aware dampening ships only if shadow mode confirms double-counting between luteal biomarker effects and trend components
  4. ProgressionEngine phase awareness: bias toward maintain (not increase) in late luteal when progression rate is marginal
  5. No upward training boost from cycle phase alone; no reduction from phase alone without readiness or symptom support
  6. All modifiers require 3+ usable cycles, no hormonal contraception exclusion, detected regularity, confidence threshold, and user-visible explanation
**Plans**: TBD

### 📋 v1.5 UX Interaction Polish

**Milestone Goal:** Elevate Tonus's interaction design with novel gesture-driven controls and anatomically precise muscle targeting, differentiating the app from generic fitness trackers.

- [ ] **Phase 19: Radial Gesture Picker** - iPod-wheel-inspired circular menu for sport type and session type selection — long press triggers radial ring, drag to select, release to confirm
- [ ] **Phase 20: Granular Muscle Group Taxonomy** - Replace coarse MuscleGroup enum (Chest/Back/Legs/Arms) with anatomically specific groups (quads, hamstrings, glutes, calves, hip flexors, psoas, anterior/posterior delts, long/short head biceps, etc.)

## Phase Details — v1.5

### Phase 19: Radial Gesture Picker
**Goal**: Replace segmented pickers for sport type and session type with an iPod-wheel-inspired radial menu — long press triggers a circular ring of 6-8 customizable options, user drags finger to select, release confirms
**Depends on**: Phase 11
**Requirements**: UX-01
**Success Criteria** (what must be TRUE):
  1. RadialPicker is a reusable SwiftUI component accepting any CaseIterable enum
  2. Long press on sport/session type triggers circular overlay with options arranged evenly around a ring
  3. Drag gesture highlights option under finger with haptic feedback
  4. Release on an option selects it and dismisses the ring with animation
  5. Release outside ring cancels selection (no change)
  6. Works in both TemplateEditorSheet and ActiveWorkoutSheet
  7. Options are customizable per enum (icon + label around ring)
  8. Follows design system: 0pt corners, no shadows, DM Sans, 8pt grid
**Plans**: TBD
**UI hint**: yes

### Phase 20: Granular Muscle Group Taxonomy
**Goal**: Replace the coarse 7-value MuscleGroup enum with an anatomically precise taxonomy that serious athletes expect, organized by body region with sub-groups
**Depends on**: Phase 11
**Requirements**: UX-02
**Success Criteria** (what must be TRUE):
  1. MuscleGroup enum expanded to ~25-30 specific muscles: quads, hamstrings, glutes, calves, hip flexors, psoas, adductors, anterior delts, lateral delts, posterior delts, pecs (upper/lower), lats, traps (upper/mid/lower), rhomboids, erectors, biceps, triceps, forearms, obliques, rectus abdominis, transverse abdominis, hip rotators, tibialis anterior
  2. Muscle groups organized by body region for picker UI (Legs, Back, Chest, Shoulders, Arms, Core)
  3. Existing exercises using old groups migrate gracefully (e.g., "Legs" -> user prompted to specify or defaults to "Quads")
  4. ExercisePickerView muscle group selector updated to show region -> sub-group hierarchy
  5. Supabase sync handles new enum values without breaking existing data
  6. TemplatePreviewSheet and workout views display specific muscle group names
**Plans**: TBD

## Progress

**Execution Order:**
- v1.2: 9 -> 10 -> 11 -> 12 (Phase 10 and 11 both depend on Phase 9, could execute in parallel)
- v1.3: 13 -> 14 (LLM import + template sharing)
- v1.4: 15 -> 16 -> 17 -> 18 (Phase 17 depends on both 15 and 16; Phase 18 depends on 16 and 17)

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. App Store Launch | v1.0 | 3/3 | Complete | 2026-04-20 |
| 2. Analytics & Export | v1.0 | 4/4 | Complete | 2026-04-20 |
| 3. Training Intelligence | v1.0 | 4/4 | Complete | 2026-04-21 |
| 4. Onboarding & Polish | v1.0 | 3/3 | Complete | 2026-04-22 |
| 5. Streaks & Notifications | v1.1 | 3/3 | Complete | - |
| 6. PDF Report Export | v1.1 | 3/3 | Complete | - |
| 7. App Store Metadata | v1.1 | 3/3 | Complete | - |
| 8. QA, Performance & Compliance | v1.1 | 0/0 | Complete | - |
| 9. Foundation & Cold-Start Engine | v1.2 | 0/0 | Not started | - |
| 10. Cold-Start Questionnaire | v1.2 | 3/3 | Complete | 2026-05-08 |
| 11. Template Management & Creation | v1.2 | 2/2 | Complete    | 2026-05-09 |
| 12. Template-Driven Workouts & Smart Suggestions | v1.2 | 3/3 | Complete    | 2026-05-10 |
| 13. LLM Workout Import | v1.3 | 0/0 | Not started | - |
| 14. Template Sharing | v1.3 | 0/0 | Not started | - |
| 15. Cycle Data Foundation | v1.4 | 0/0 | Not started | - |
| 16. Cycle-Aware Recovery Baselines | v1.4 | 0/0 | Not started | - |
| 17. Cycle Context UI & Guidance | v1.4 | 0/0 | Not started | - |
| 18. Cycle Intelligence (Shadow Mode) | v1.4 | 0/0 | Not started | - |
| 19. Radial Gesture Picker | v1.5 | 0/0 | Not started | - |
| 20. Granular Muscle Group Taxonomy | v1.5 | 0/0 | Not started | - |
