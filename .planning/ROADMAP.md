# Roadmap: Tonus

## Milestones

- ✅ **v1.0 Post-Launch** — Phases 1-4 (shipped 2026-04-22)
- ✅ **v1.1 App Store Launch** — Phases 5-8 (shipped 2026-04-30)
- 🚧 **v1.2 Training Onboarding & Templates** — Phases 9-12 (in progress)

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
- [ ] **Phase 11: Template Management & Creation** - Athlete-owned template CRUD, manual creation, and save-from-session
- [ ] **Phase 12: Template-Driven Workouts & Smart Suggestions** - Template picker, dynamic targets, dashboard quick-start cards, and schedule-aware suggestions

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
  1. User can complete 4 required questions (sessions/week, avg duration, typical sRPE, weeks at current level) via a training profile card after onboarding
  2. User can optionally answer 4 additional questions (training age, periodization preference, movement types, injury history) without blocking progress
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
**Plans**: TBD
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
**Plans**: TBD
**UI hint**: yes

## Progress

**Execution Order:**
Phases execute in numeric order: 9 -> 10 -> 11 -> 12
Note: Phase 10 and Phase 11 both depend on Phase 9 and could execute in parallel if desired.

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
| 10. Cold-Start Questionnaire | v1.2 | 3/3 | Complete   | 2026-05-08 |
| 11. Template Management & Creation | v1.2 | 0/0 | Not started | - |
| 12. Template-Driven Workouts & Smart Suggestions | v1.2 | 0/0 | Not started | - |
