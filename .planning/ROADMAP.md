# Roadmap: Faros

## Milestones

- ✅ **v1.0 Post-Launch** — Phases 1-4 (shipped 2026-04-22)
- ✅ **v1.1 App Store Launch** — Phases 5-8 (shipped 2026-04-30)
- ✅ **v1.2 Training Onboarding & Templates** — Phases 9-12 (shipped 2026-05-10)
- 🚧 **v1.3 LLM Import, Sharing & Polish** — Phases 13-16 (in progress)
- 📋 **v1.4 Female Athlete Optimization** — Phases 17-20 (planned)
- 📋 **v1.5 UX Interaction Polish** — Phases 21-22 (planned)

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

<details>
<summary>✅ v1.2 Training Onboarding & Templates (Phases 9-12) — SHIPPED 2026-05-10</summary>

- [x] Phase 9: Foundation & Cold-Start Engine (3/3 plans) — completed 2026-05-06
- [x] Phase 10: Cold-Start Questionnaire (3/3 plans) — completed 2026-05-08
- [x] Phase 11: Template Management & Creation (2/2 plans) — completed 2026-05-09
- [x] Phase 12: Template-Driven Workouts & Smart Suggestions (3/3 plans) — completed 2026-05-10

</details>

### 🚧 v1.3 LLM Import, Sharing & Polish

**Milestone Goal:** Enable AI-powered workout import from any format, let users share templates, rebrand typography to Alpino, and harden remaining tech debt from code review.

- [x] **Phase 13: Design Polish** - Alpino font migration and rounded border fix across all views (completed 2026-05-10)
- [x] **Phase 14: Sync Hardening** - Replace silent try? calls with structured error handling and per-entity sync timestamps (completed 2026-05-10)
- [x] **Phase 15: Template Sharing** - Share codes, universal links, preview-before-import for template exchange (completed 2026-05-13)
- [ ] **Phase 16: LLM Workout Import** - AI-powered text/PDF/image parsing into templates via Supabase Edge Function

### 📋 v1.4 Female Athlete Optimization

**Milestone Goal:** Make Faros the first workload management app with evidence-based cycle-aware training intelligence. Read existing HealthKit cycle data from other apps (zero friction), correct male-normative baseline bias in recovery scoring, and provide cycle-contextual guidance — all while working identically for users who don't track cycles.

**Research:** `.planning/research/female-athlete-optimization-research.md` (696 lines, 60+ sources)
**Cross-AI Review:** Claude + Codex adversarial review completed. Consensus: CycleContext-first (explanations), same-phase baselines as measurement correction (not modifier), defer algorithmic modifiers to Wave 2 pending shadow-mode validation.

- [ ] **Phase 17: Cycle Data Foundation** - CycleTrackingService (HealthKit menstrual + wrist temp reader), MenstrualCycleSnapshot model, CyclePhase enum, contraceptive status in profile, HealthKit permission flow
- [ ] **Phase 18: Cycle-Aware Recovery Baselines** - RecoveryScoreEngine same-phase baseline with confidence gating, dual baseline (7-day + same-phase), graceful degradation for <3 cycles / irregular / anovulatory / OC users
- [ ] **Phase 19: Cycle Context UI & Guidance** - Dashboard cycle day indicator, phase context in recovery card, fueling/recovery prompts (avoid fasted workouts, post-training nutrition), RED-S cycle irregularity alerts with clinician-referral language
- [ ] **Phase 20: Cycle Intelligence (Shadow Mode)** - Shadow-mode analytics measuring cycle context prediction value, evidence-gated AutoregulationEngine soft modifiers (yellow zone only), FatigueIndex phase-aware dampening (validated), ProgressionEngine phase awareness

### 📋 v1.5 UX Interaction Polish

**Milestone Goal:** Elevate Faros's interaction design with novel gesture-driven controls and anatomically precise muscle targeting, differentiating the app from generic fitness trackers.

- [ ] **Phase 21: Radial Gesture Picker** - iPod-wheel-inspired circular menu for sport type and session type selection — long press triggers radial ring, drag to select, release to confirm
- [ ] **Phase 22: Granular Muscle Group Taxonomy** - Replace coarse MuscleGroup enum (Chest/Back/Legs/Arms) with anatomically specific groups (quads, hamstrings, glutes, calves, hip flexors, psoas, anterior/posterior delts, long/short head biceps, etc.)

## Phase Details — v1.3

### Phase 13: Design Polish
**Goal**: Establish the correct visual baseline by migrating all typography to Alpino and eliminating every rounded corner, so all new UI built in later phases inherits the right design from the start
**Depends on**: Phase 12
**Requirements**: DESGN-01, DESGN-02
**Success Criteria** (what must be TRUE):
  1. Every text element in the app renders in Alpino (Regular or Medium) — zero instances of DM Sans or system font fallback remain
  2. All text fields use a custom 0pt-corner TextFieldStyle — zero instances of `.roundedBorder` or `RoundedRectangle` remain in text input styling
  3. Font sizes are adjusted where Alpino's smaller x-height causes text to feel too small (verified on physical device, not just simulator)
  4. The UIFont DEBUG assertion in WorkloadApp.swift validates Alpino font names at launch
**Plans**: 3 plans
Plans:
- [x] 13-01-PLAN.md — Font infrastructure: copy Alpino files, update FontTokens, Info.plist, pbxproj, assertions, PDFReportEngine
- [x] 13-02-PLAN.md — Rogue font cleanup: convert 40 raw Font.custom/system calls to Font.Tokens
- [x] 13-03-PLAN.md — SharpTextFieldStyle creation, application to 23 text fields, DESIGN.md update
**UI hint**: yes

### Phase 14: Sync Hardening
**Goal**: Make sync failures visible and isolated so that a problem pulling one entity type never silently corrupts or blocks other entity types
**Depends on**: Phase 13
**Requirements**: SYNC-01, SYNC-02, SYNC-03
**Success Criteria** (what must be TRUE):
  1. Every pull-side `try?` in SyncService is replaced with `do/catch` that logs the entity type, error description, and timestamp
  2. SyncService tracks per-entity-type last-successful-sync timestamps (workouts, snapshots, wellness, templates, PRs each independent)
  3. When one entity type fails to pull, all other entity types still complete their sync and update their timestamps
  4. `lastSyncedAt` for a given entity type is only updated when that entity's pull succeeds — a failed pull never advances its timestamp
**Plans**: 2 plans
Plans:
- [x] 14-01-PLAN.md — SyncEntity enum, SyncTimestampStore, SyncService do/catch hardening with Bool returns and per-entity orchestration
- [x] 14-02-PLAN.md — SyncStatusView, Profile tab dot badge, AppContainer sign-out cleanup
**UI hint**: yes

### Phase 15: Template Sharing
**Goal**: Users can share any template they own with anyone via a short code or link, and recipients can preview and import it as their own independent copy
**Depends on**: Phase 14
**Requirements**: SHARE-01, SHARE-02, SHARE-03, SHARE-04, SHARE-05
**Success Criteria** (what must be TRUE):
  1. User can tap "Share" on any owned template and receive an 8-character alphanumeric code copyable to clipboard
  2. User can enter a share code in an import sheet and see a full preview of the template (name, exercise groups, exercises, target sets/reps) before deciding to import
  3. User can tap a universal link containing a share code and the app opens directly to the import preview
  4. Imported template is a fully independent deep copy — new UUIDs, current user as owner, no personal weight data from the sharer
  5. Shared template data expires after 30 days and is cleaned up automatically
**Plans**: 3 plans
Plans:
- [x] 15-01-PLAN.md — TemplateSharingService, Supabase migration SQL, Associated Domains entitlement
- [x] 15-02-PLAN.md — ShareCodeSheet, context menu Share button, WorkoutLogView wiring
- [x] 15-03-PLAN.md — ShareImportSheet, ShareImportPreviewSheet, AppRouter deep links, WorkoutLogView import button
**UI hint**: yes

### Phase 16: LLM Workout Import
**Goal**: Users can turn any workout they find — pasted text, a PDF from their coach, or a photo of a gym whiteboard — into a structured template in the app, reviewed and edited before saving
**Depends on**: Phase 14
**Requirements**: LLM-01, LLM-02, LLM-03, LLM-04, LLM-05, LLM-06
**Success Criteria** (what must be TRUE):
  1. User can paste freeform workout text and see it parsed into a structured template preview with exercises, sets, reps, and weights
  2. User can select a PDF file and see its extracted content parsed into a template preview
  3. User can take a photo or choose from library and see OCR-extracted text parsed into a template preview
  4. User can edit any field in the parsed template preview (exercise names, sets, reps, weights) before saving
  5. All LLM calls route through a Supabase Edge Function — the OpenAI API key never exists in the iOS binary
**Plans**: TBD
**UI hint**: yes

## Phase Details — v1.4

### Phase 17: Cycle Data Foundation
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

### Phase 18: Cycle-Aware Recovery Baselines
**Goal**: Replace the male-normative 7-day rolling HRV/RHR baseline with a confidence-gated same-phase baseline that removes predictable within-athlete cyclic variance, preserving genuine fatigue detection while eliminating false warnings during normal luteal-phase HRV suppression
**Depends on**: Phase 17
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

### Phase 19: Cycle Context UI & Guidance
**Goal**: Surface cycle awareness in the dashboard and recommendations as context and explanations — not deterministic overrides — following Dr. Sims's evolved position of "train by readiness, use cycle as context"
**Depends on**: Phase 17, Phase 18
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

### Phase 20: Cycle Intelligence (Shadow Mode)
**Goal**: Validate whether cycle context improves training outcome prediction before shipping algorithmic modifiers — evidence-gated approach prevents overconfident adjustments from unvalidated research
**Depends on**: Phase 18, Phase 19
**Requirements**: CYCLE-09, CYCLE-10
**Success Criteria** (what must be TRUE):
  1. Shadow-mode analytics silently measure: does cycle phase improve prediction of next-day readiness, wellness score, workout completion rate, or reported pain?
  2. If shadow mode shows signal: AutoregulationEngine accepts CycleContext, applies soft volume modifier (5-15%) only in yellow recovery zone, never overrides rest or green-zone recommendations
  3. FatigueIndex phase-aware dampening ships only if shadow mode confirms double-counting between luteal biomarker effects and trend components
  4. ProgressionEngine phase awareness: bias toward maintain (not increase) in late luteal when progression rate is marginal
  5. No upward training boost from cycle phase alone; no reduction from phase alone without readiness or symptom support
  6. All modifiers require 3+ usable cycles, no hormonal contraception exclusion, detected regularity, confidence threshold, and user-visible explanation
**Plans**: TBD

## Phase Details — v1.5

### Phase 21: Radial Gesture Picker
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
  8. Follows design system: 0pt corners, no shadows, Alpino font, 8pt grid
**Plans**: TBD
**UI hint**: yes

### Phase 22: Granular Muscle Group Taxonomy
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
- v1.2: 9 -> 10 -> 11 -> 12 (complete)
- v1.3: 13 -> 14 -> 15 & 16 (Phase 15 and 16 both depend on Phase 14, could execute in parallel)
- v1.4: 17 -> 18 -> 19 -> 20 (Phase 19 depends on both 17 and 18; Phase 20 depends on 18 and 19)
- v1.5: 21 & 22 (independent, both depend on Phase 11)

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
| 9. Foundation & Cold-Start Engine | v1.2 | 3/3 | Complete | 2026-05-06 |
| 10. Cold-Start Questionnaire | v1.2 | 3/3 | Complete | 2026-05-08 |
| 11. Template Management & Creation | v1.2 | 2/2 | Complete | 2026-05-09 |
| 12. Template-Driven Workouts & Smart Suggestions | v1.2 | 3/3 | Complete | 2026-05-10 |
| 13. Design Polish | v1.3 | 3/3 | Complete    | 2026-05-10 |
| 14. Sync Hardening | v1.3 | 2/2 | Complete    | 2026-05-13 |
| 15. Template Sharing | v1.3 | 3/3 | Complete    | 2026-05-13 |
| 16. LLM Workout Import | v1.3 | 0/0 | Not started | - |
| 17. Cycle Data Foundation | v1.4 | 0/0 | Not started | - |
| 18. Cycle-Aware Recovery Baselines | v1.4 | 0/0 | Not started | - |
| 19. Cycle Context UI & Guidance | v1.4 | 0/0 | Not started | - |
| 20. Cycle Intelligence (Shadow Mode) | v1.4 | 0/0 | Not started | - |
| 21. Radial Gesture Picker | v1.5 | 0/0 | Not started | - |
| 22. Granular Muscle Group Taxonomy | v1.5 | 0/0 | Not started | - |
