# Roadmap: Tuwa

## Milestones

- ✅ **v1.0 Post-Launch** — Phases 1-4 (shipped 2026-04-22)
- ✅ **v1.1 App Store Launch** — Phases 5-8 (shipped 2026-04-30)
- ✅ **v1.2 Training Onboarding & Templates** — Phases 9-12 (shipped 2026-05-10)
- ✅ **v1.3 LLM Import, Sharing & Polish** — Phases 13-16 (shipped 2026-05-14)
- ✅ **v1.4 Female Athlete Optimization** — Phases 17-20 (phase-complete 2026-05-30, pending UAT)
- ✅ **v1.5 UX Interaction Polish** — Phases 21-22 (phase-complete 2026-05-30, pending UAT)
- 🚧 **v1.6 Algorithm Moat (Personal Readiness v1)** — Phases 24-29 (started 2026-05-30; scope locked, see memory project_algorithm_v1_locked + .planning/research/competitive-algorithm-analysis.md)
- 🚧 **v2.0 Plan-Aware Decision Engine — TODAY Verdict Wedge** — Phases 41-45 (started 2026-06-13; core-identity pivot, paid-validation MVP; see .planning/research/{plan-aware-thesis-pressure-test,v2-verdict-engine,v2-crossmodal-and-measurement}.md)

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

<details>
<summary>✅ v1.3 LLM Import, Sharing & Polish (Phases 13-16) — SHIPPED 2026-05-14</summary>

- [x] Phase 13: Design Polish (3/3 plans) — completed 2026-05-10
- [x] Phase 14: Sync Hardening (2/2 plans) — completed 2026-05-10
- [x] Phase 15: Template Sharing (3/3 plans) — completed 2026-05-13
- [x] Phase 16: LLM Workout Import (2/2 plans) — completed 2026-05-13

</details>

### ✅ v1.4 Female Athlete Optimization

**Milestone Goal:** Make Tuwa the first workload management app with evidence-based cycle-aware training intelligence. Read existing HealthKit cycle data from other apps (zero friction), correct male-normative baseline bias in recovery scoring, and provide cycle-contextual guidance — all while working identically for users who don't track cycles.

**Research:** `.planning/research/female-athlete-optimization-research.md` (696 lines, 60+ sources)
**Cross-AI Review:** Claude + Codex adversarial review completed. Consensus: CycleContext-first (explanations), same-phase baselines as measurement correction (not modifier), defer algorithmic modifiers to Wave 2 pending shadow-mode validation.

- [x] **Phase 17: Cycle Data Foundation** - CycleTrackingService (HealthKit menstrual + wrist temp reader), MenstrualCycleSnapshot model, CyclePhase enum, contraceptive status in profile, HealthKit permission flow (completed 2026-05-14)
- [x] **Phase 18: Cycle-Aware Recovery Baselines** - RecoveryScoreEngine same-phase baseline with confidence gating, dual baseline (7-day + same-phase), graceful degradation for <3 cycles / irregular / anovulatory / OC users (completed 2026-05-25)
- [x] **Phase 19: Cycle Context UI & Guidance** - Dashboard cycle day indicator, phase context in recovery card, fueling/recovery prompts (avoid fasted workouts, post-training nutrition), RED-S cycle irregularity alerts with clinician-referral language (completed 2026-05-30)
- [x] **Phase 20: Cycle Intelligence (Shadow Mode)** - Shadow-mode analytics measuring cycle context prediction value, evidence-gated AutoregulationEngine soft modifiers (yellow zone only, gated OFF pending shadow validation), FatigueIndex phase-aware dampening, ProgressionEngine phase awareness (completed 2026-05-30)

### ✅ v1.5 UX Interaction Polish

**Milestone Goal:** Elevate Tuwa's interaction design with novel gesture-driven controls and anatomically precise muscle targeting, differentiating the app from generic fitness trackers.

- [x] **Phase 21: Radial Gesture Picker** - iPod-wheel-inspired circular menu for sport type and session type selection — long press triggers radial ring, drag to select, release to confirm (completed 2026-05-30)
- [x] **Phase 22: Granular Muscle Group Taxonomy** - Replace coarse MuscleGroup enum (Chest/Back/Legs/Arms) with anatomically specific groups; expanded to 33-value taxonomy (26 specific + 7 retained aliases) across 7 MuscleRegion groups (completed 2026-05-30)

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

**Plans**: 3 plans

Plans:

- [x] 17-01-PLAN.md -- Types, models, sync (CyclePhase enum, MenstrualCycleSnapshot, CycleContext, Athlete fields, AthleteRow sync, migration SQL)
- [x] 17-02-PLAN.md -- CycleTrackingService (HealthKit reader, phase estimator, confidence scorer)
- [x] 17-03-PLAN.md -- UI (ProfileView Cycle & Hormones section, Dashboard soft prompt banner)

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

**Plans**: 2 plans

Plans:
**Wave 1**

- [x] 18-01-PLAN.md — RecoveryScoreEngine same-phase baseline algorithm (2-bucket mapping, same-phase average, 4-reading minimum, RecoveryInput extension, worked-example + identical-behavior tests)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 18-02-PLAN.md — Pipeline integration (CycleSnapshotRepository read-time join, confidence-gated derivation in RecoveryPipeline.run, AppContainer + ViewModel wiring, graceful 7-day fallback)

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

**Plans**: 3 plans

Plans:

- [x] 17-01-PLAN.md -- Types, models, sync (CyclePhase enum, MenstrualCycleSnapshot, CycleContext, Athlete fields, AthleteRow sync, migration SQL)
- [x] 17-02-PLAN.md -- CycleTrackingService (HealthKit reader, phase estimator, confidence scorer)
- [x] 17-03-PLAN.md -- UI (ProfileView Cycle & Hormones section, Dashboard soft prompt banner)

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
  8. Follows design system: 0pt corners, no shadows, General Sans font, 8pt grid

**Plans**: 3 plans

Plans:

- [x] 21-01-PLAN.md -- RadialPicker component + RadialSelectable protocol + ring geometry helper + SportType/SessionType conformance + pbxproj
- [x] 21-02-PLAN.md -- Integration into ActiveWorkoutSheet + Coach TemplateEditorSheet (segmented Picker replacement, defaultSessionType reset preserved)
- [x] 21-03-PLAN.md -- Behavior/genericity/source-compliance tests + docs hygiene (Alpino->General Sans, plan-list fix)

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
| 16. LLM Workout Import | v1.3 | 2/2 | Complete    | 2026-05-13 |
| 17. Cycle Data Foundation | v1.4 | 4/4 | Complete   | 2026-05-14 |
| 18. Cycle-Aware Recovery Baselines | v1.4 | 2/2 | Complete    | 2026-05-25 |
| 19. Cycle Context UI & Guidance | v1.4 | 3/3 | Complete | 2026-05-30 |
| 20. Cycle Intelligence (Shadow Mode) | v1.4 | 3/3 | Complete | 2026-05-30 |
| 21. Radial Gesture Picker | v1.5 | 3/3 | Complete | 2026-05-30 |
| 22. Granular Muscle Group Taxonomy | v1.5 | 3/3 | Complete | 2026-05-30 |

### Phase 23: Multi-language in-app support (Simplified Chinese)

**Goal:** Add Simplified Chinese (zh-Hans) localization to Tonus alongside English — full in-app coverage (core UI, errors, paywall, legal, push notifications), live language switching via LocaleManager + `.environment(\.locale)`, CJK font cascade (Noto Sans SC over General Sans), and zh-Hans App Store metadata + screenshots.
**Requirements**: TBD (derived from CONTEXT.md decisions D-01..D-22 + UI-SPEC visual contract + RESEARCH validation architecture)
**Depends on:** Phase 22
**Plans:** 6 plans (5 complete, 1 gap-closure pending)

Plans:

- [x] 23-01-PLAN.md — i18n infrastructure scaffold (LocaleManager, env-locale injection, empty String Catalogs, formatter Locale-refactor, language picker UI surfaces)
- [x] 23-02-PLAN.md — String sweep + catalog migration (enum displayNames, AuthError, View/Component literals, NotificationService deferred localization + reschedule migration, InfoPlist HealthKit consent)
- [x] 23-03-PLAN.md — Noto Sans SC bundle + UIFontDescriptor cascade in FontTokens
- [x] 23-04-PLAN.md — zh-Hans translations + marketing-tone second pass + density audit + human review checkpoint
- [x] 23-05-PLAN.md — App Store Connect zh-Hans metadata draft + scheme + screenshots (autonomous: false; human-verify gates per memory feedback_asc_caution.md)
- [ ] 23-06-PLAN.md — Gap closure: zh-Hans string-coverage sweep across Auth/Dashboard/Profile/Workload/Recovery/WorkoutLog views (closes VERIFICATION gap #2 / REVIEW WR-01 deferred)

## Phase Details — v1.6 Algorithm Moat (Personal Readiness v1)

**Milestone Goal:** Replace the commodity recovery+autoregulation core with a defensible, honest, strength-aware Personal Readiness v1 for the narrowed target user (amateur serious / part-time athletes without pro support). Scope locked + triple-reviewed 2026-05-30 (see `.planning/research/algorithm-moat-design.md` + `competitive-algorithm-analysis.md`, both with codex addenda; memory `project_algorithm_v1_locked`). Everything behind the shadow harness, gated OFF until parity gates pass. Defensibility = trust + transparency + strength-hybrid workflow quality, NOT algorithm exclusivity. Dropped from v1 (codex: unsound on consumer data): per-user Kalman Q/R learning + per-user logistic weight tuning.

- [ ] **Phase 24: Validation data-contract + shadow-harness upgrade** — define predictionDate/targetDate/feature-cutoff/outcome-window (fix the existing same-day date-contract bug); add calibration + Spearman + blocked/purged CV + bootstrap-with-autocorrelation handling to ShadowAnalyticsService; raw self-report/wellness/soreness/adherence outcome labels (NOT engine-derived recovery). No scoring model yet. Foundation.
- [x] **Phase 25: Soreness / tweak self-log** — lightweight optional pain/soreness/niggle log (SwiftData model + minimal UI), local-only, to honestly validate Strain-Risk against real breakdown. Wire wellness history + injury count into the dashboard fatigue path (currently empty/hardcoded-0).
  **Plans:** 4 plans (2 waves) — 1/4 complete
  - [x] 25-01-PLAN.md — Local-only SorenessLog @Model + NiggleType enum + repository + schema registration + persistence tests (foundation) ✅ 2026-05-30 (build+tests green 4/4)
  - [ ] 25-02-PLAN.md — `.niggleSeverity` graded shadow outcome end-to-end (enum + niggleSeverityActual column + date-contract-safe max-in-window resolution + all switch-ripple sites; both arms nil)
  - [ ] 25-03-PLAN.md — Pure NiggleInjuryDeriver (DOMS-excluded qualifying rule) + wire 14d wellness + injury count/days-since into DashboardViewModel fatigue path
  - [ ] 25-04-PLAN.md — DESIGN-compliant NiggleLogSheet + on-demand Dashboard affordance + non-blocking post-workout nudge (autonomous: false; human-verify checkpoint)
- [x] **Phase 26: Individualized baselines** — robust EWMA/Welford/MAD per-signal baselines + Altini-style 60-day normal-band + CV early-warning; prequential (no-leak) personal z-scores; day-bucketed inputs (never update from repeated stale HealthKit samples); stale/missing → reduce confidence, not learned physiology. Pure structs; per-day state in a local-only never-synced model.
  **Goal:** Build the robust individualized-baseline substrate (per-signal robust EWMA + Welford/MAD baselines, prequential no-leak personal z-scores, Altini CV early-warning on innovations, composite 0–1 confidence, day-bucketed inputs, a local-only never-synced `BaselineState` model, and a seeded convergence report) — parallel and gated OFF; the flat 7-day mean stays the LIVE baseline (D-01..D-04, substrate-only).
  **Plans:** 4 plans (4 waves)

Plans:
- [x] 26-01-PLAN.md — Local-only `BaselineState` @Model (one row, flattened HRV/RHR/sleep sub-states) + Schema registration + persistence/sync-omission tests (foundation) (2026-05-30; tests 4/4)
- [x] 26-02-PLAN.md — Pure `BaselineEngine`: EWMA/Welford/MAD/Huber, prequential no-leak z + σ floor, Altini CV, 0–1 confidence (all named constants) + numerics-vs-oracle unit tests (2026-05-30; tests 10/10, tier-fence held)
- [x] 26-03-PLAN.md — Pure `DayBucketer` (median morning window, gap, stale-dedup) + W-1 idempotency fold guard + additive `fetchRestingHRHistory(days:)` + machine-enforced tier-fence test (live 7-day mean unchanged) (2026-05-30; tests 14/14, tier-fence machine-enforced)
- [ ] 26-04-PLAN.md — Seeded deterministic convergence-report generator + invariant asserts + hash-equality; human reviews the markdown artifact (autonomous: false; Phase 26 result checkpoint, D-04)
- [x] **Phase 27: Strength-load model + Strain-Risk fusion** — per-muscle hard sets + relative-intensity buckets (est-1RM / RPE / RIR) from SetRecord/ExerciseEntry (NOT raw tonnage); fuse with sRPE/TRIMP endurance load + FatigueIndexEngine (FEA lineage) + Foster monotony/strain (completeness-gated) into the Strain-Risk channel. Honest "load-tolerance context / overreaching caution", never "injury prediction". **BUILT 2026-05-30** (3/3 waves committed to main, not pushed; substrate gated OFF, tier fence green).
  **Goal:** Build the strength-load model (per-muscle hard sets + est-1RM-relative-intensity buckets via the existing `SetRecord.estimated1RM` + RPE/RIR, never raw tonnage) and fuse it with endurance sRPE/TRIMP load + FatigueIndexEngine + completeness-gated Foster monotony/strain + Phase-25 soft-tissue memory (NiggleInjuryDeriver) + Phase-26 individualized baselines (BaselineEngine) into a FIXED sign-constrained glass-box heuristic **Strain-Risk** flag (score + zone + ranked factors + confidence) — display/shadow context only, gated OFF, NOT logistic fusion (that is Readiness, Phase 28), NEVER injury prediction. Pure deterministic structs; any per-day state local-only/never-synced; live recovery score + live recommendation provably unchanged (D-27-01..D-27-08, substrate-only).
  **Plans:** 3 plans (3 SERIAL waves)

Plans:
- [x] 27-01-PLAN.md — Pure `StrengthLoadEngine` (reuses `SetRecord.estimated1RM`/`rir`/`rpe`; relative-intensity buckets, hard-set rule, per-muscle hard sets + acute/chronic elevation + same-region recurrence); StrengthLoadState SKIPPED (D-27-02, pure recompute) ✅ 2026-05-30 (commit 4fc4ffa; targeted 23/23 + full suite green)
- [x] 27-02-PLAN.md — Pure `LoadDistributionEngine` (unified daily-load series + completeness-gated Foster monotony/strain with density/spike fallback) ✅ 2026-05-30 (commit 0fa3207; full suite green)
- [x] 27-03-PLAN.md — Pure `StrainRiskEngine` fixed glass-box fusion (score + `StrainRiskZone` + ranked factors + confidence; reuses FatigueIndexEngine/NiggleInjuryDeriver/BaselineEngine) + isolation + tier-fence + full-suite + no-prediction-copy guards ✅ 2026-05-30 (commit 75ba4cf; full suite green, isolation grep==0)

**Phase 27 verification-complete 2026-05-31:** xcodebuild green on HEAD (430 unit / 0 fail), gsd-verifier PASS 4/4 invariants, adversarial review 0 critical, codex review PASS. Strain-Risk display/shadow-only, NOT wired live. (Stale hashes 3f7b29c/9c8f9e1/6e8d9f2 corrected to real 4fc4ffa/0fa3207/75ba4cf.)

- [x] **Phase 28: Readiness fusion + explainable decisions + ACWR demotion** — fixed sign-constrained glass-box logistic fusion → Readiness scalar (separate from Strain-Risk); upgrade ReasoningEngine to explain the DECISION ("volume cut because HRV −x%, sleep debt, high per-muscle hard sets, no rest day") with confidence; swap AutoregulationEngine matrix (recovery × ACWR) → (readiness × strain-risk), ACWR → context label only; dual-run period + "method updated" messaging; the recommendation must adjust a real logged/planned workout.
**Phase 28 verification-complete 2026-05-31:** built behind `PRSActivation` (default FALSE) — commits b9d3e56, 8446260, fef8183, 64efc06, a14422e, eb10579. xcodebuild green (430/0), gsd-verifier PASS 4/4, adversarial review 0 critical, codex PASS. Flag-off live recommendation byte-identical (AutoregulationFlagFenceTests + DualRunFlagFenceTests). **OWED: human UI visual review of dual-run "method updated" surface + Wave-4 DashboardView wiring (deferred by design).**
**Phase 28 Wave-4 continuation (28-05, planned 2026-05-31):** closes the OWED DashboardView wiring — `28-05-PLAN.md` mounts the flagged `PRSDualRunCard` below the hero readiness card and has `DashboardViewModel` build a REAL `DualRunMessage` (legacy recovery×ACWR + updated readiness×strain-risk) entirely inside `if PRSActivation.isEnabled`. Flag-off → `dualRunMessage` nil → card EmptyView → Dashboard byte-unchanged. Readiness/strain RECOMPUTED with the real engines (no live source existed to reuse); cold-start → nil z (excluded, never imputed). Three fence tests stay green + unmodified. Placement PROVISIONAL — human visual review required.


- [x] **Phase 29: Shadow validation + activation gates** — run PRS-v1 arm in shadow vs current algorithm; gates: MAE beat on ≥3/4 outcomes (bootstrap CI excl 0), Spearman ≥0.50, calibration slope ∈[0.8,1.2]; no live activation until gates pass; master activation flag defaults false.
  **Goal:** Build the activation-gate evaluation layer (pure `ActivationGateEvaluator` consuming the EXISTING Phase-24 `ShadowMetrics`/`ShadowAnalyticsService` PRS-vs-baseline metrics — MAE-beat ≥3/4 with bootstrap CI excl 0, Spearman ≥0.50, calibration slope ∈[0.8,1.2], data-maturity precondition) plus a NEW `PRSMasterActivation` flag (defaults FALSE, stays FALSE) and a seeded deterministic shadow-validation report artifact. Wires + evaluates + reports ONLY; absolutely NO live activation; the master flag is not flipped (D-29-GA-01..GA-10, gate-eval + report-only).
  **Plans:** 2 plans (2 SERIAL waves)

Plans:
**Wave 1**
- [ ] 29-01-PLAN.md — `PRSMasterActivation` flag (default FALSE) + pure report-only `ActivationGateEvaluator` + `GateReport` (consumes existing shadow metrics; 4 gates w/ fixed named thresholds) + oracle/boundary/thin-data tests + activation-flag fence + no-mutation isolation grep

**Wave 2** *(blocked on Wave 1 completion)*
- [ ] 29-02-PLAN.md — Seeded deterministic shadow-validation report generator (test target; synthetic PRS-wins/loses/thin/ambiguous traces → real harness resolve → evaluator → `29-shadow-validation-report.md`) + per-scenario verdict XCTAsserts + hash-equality + master-flag-stays-FALSE asserts + no-prediction-copy grep + human review (autonomous: false)

**Phase 29 done — Wave 1 `7f5b03e`, Wave 2 `cb23fab`, docs `eb1fa0a`/`2cd41aa`.** xcodebuild green (448 unit / 0 fail; the lone red `ScreenshotTests.test03_Recovery` re-ran green in isolation — confirmed XCUITest flake). gsd-verifier PASS 11/11 + 4/4 invariants, adversarial review 0 critical (3 minor: maturity-n vs paired-CI-n, grep-guard whitespace, dead `withEnabled` helper), codex PASS. `PRSMasterActivation` defaults FALSE; gate evaluator pure/report-only; NOTHING activated.

### Phase 30: Shadow-engine quality fixes (pre-activation cleanup)

**Status:** DONE 2026-05-31 (user chose fix-now over defer). Fixed the 6 shadow/display/flag-on quality findings + the 3 follow-up review WARNINGS. ALL live behavior byte-identical (fences hold); nothing activated; master flag FALSE. Goal: clean shadow Strain-Risk + readiness inputs so the eventual activation-gate evaluation runs on correct data.

- **Waves 1-4** (`1e5314a`/`466df41`/`bd5739d`/`634e3f2`): the 6 findings. Build green. BUT adversarial review found Wave-2's monotony fix regressed.
- **Wave 5** (`510188f`/`02ad347`/`d45ae5a`): corrected the regression. Wave-2 had z-standardised the two load streams + added a +3.0 offset → Foster monotony pinned ~4-6 → StrainRisk `clamp01(monotony/3.0)` SATURATED at 1.0 for every gate-passing log (W1); gate ran on raw series while monotony ran on the standardised one (W2); Finding-3 half-open window was applied to StrengthLoadEngine but not LoadDistributionEngine (W3). Wave 5 replaced the z-offset hack with a SINGLE real-unit combined daily series (strength hard-set strain → sRPE-equivalent ×5.0) so Foster monotony lands in the natural ~1-3 band, is non-saturated, and moves with distribution (5 new `LoadDistributionEngine.distribution()`→`StrainRiskEngine.fuse()` integration tests prove it); gate now shares that series (W2 fixed structurally); half-open windows applied to LoadDistributionEngine lines 84/167/291 (W3). Build green 484/0 (lone ScreenshotTests flake passed isolated), verifier PASS (monotonyNotSaturated, 4/4 invariants), adversarial review 0 critical (1 unreachable dead-code note re confidence gateFactor for an impossible `.computed`+nil state).
- **Verification:** xcodebuild green, gsd-verifier PASS, adversarial review 0 critical, all three fences byte-unmodified, flags FALSE. Strain-Risk/Readiness remain shadow/display-only, NOT wired live.

Findings to fix:
1. `StrainRiskEngine` — soft-tissue + rest-debt double-count (FatigueIndex composite already folds them, then components 5/6 re-add standalone). [high conf, workflow]
2. `LoadDistributionEngine` — endurance sRPE load (10s–100s) summed with strength hard-set strain weights (~1) into one Foster series → strength drowned out. [high conf, workflow]
3. `StrengthLoadEngine:256-257` — chronic 28d window ⊇ acute 7d, ÷28 → artificial ~4× ratio for sparse/new-exercise history; exclude acute from chronic (or roll per training-day). [codex P2 + workflow]
4. `StrengthLoadEngine:119` — `Int(10-rpe)` truncates RPE 7.5→RIR 2; round-half-up or compare in Double before the ≤2 hard-set test. [codex P2 + workflow]
5. `StrainRiskEngine:200-204` — `confidence()` coverage uses `hard/(hard+unscored)`, omitting EASY scored sets; use `(hard+easy)/(hard+easy+unscored)`. [codex P3 + workflow]
6. `PRSDualRunSurface:75-79` — flag-on: `targetVolume` nil on first-time prescriptions → volume reductions discarded in else branch; populate or handle nil. [codex P2 + workflow]

Invariants: no live-path change (BaselineTierFence + AutoregulationFlagFence + DualRunFlagFence stay green), no activation, master flag FALSE, full xcodebuild green. Engine snapshot tests for changed shadow outputs updated to new correct values; fences untouched.

**Plans:** 4/5 plans executed

Plans:
- [ ] 30-PLAN.md — overview (wave structure, invariants, source audit)
- [x] 30-01-PLAN.md — Wave 1: StrengthLoadEngine (Findings 3+4 + MuscleStrengthLoad easyCount/hasChronicBaseline)
- [x] 30-02-PLAN.md — Wave 2: LoadDistributionEngine (Finding 2 per-stream z-standardised monotony series)
- [x] 30-03-PLAN.md — Wave 3: StrainRiskEngine (Findings 1+5: single-count fatigue + easy-inclusive baseline-discounted coverage)
- [x] 30-04-PLAN.md — Wave 4: PRSDualRunSurface (Finding 6 nil-targetVolume effective base + updatedAt)

## Phase Details — v1.5.1 UI Visual Enforcement

> NEW milestone, **appended** to the roadmap (user decision 2026-06-02: append, don't reset). The v1.6 Algorithm Moat milestone above remains **in-flight / dormant** (flags FALSE, 35 commits on `main` unpushed, held for UI review + push approval) — these UI phases stack on top and do NOT touch algorithm state. The dormant algorithm rides along; next App Store release **1.5** = UI/UX + dormant algorithm.
>
> **Spec for all phases:** `.planning/v1.5-audit/INVENTORY.md` (222 findings; 8 drift-class scans + 11 per-screen reviews). **Decision LOCKED:** enforce the existing elevation ladder (`background`/`surfaceEl`/`surface`); do **NOT** amend `ColorTokens` (audit found zero amend-candidates). Corners/shadows already clean (0/0).
>
> **Build-gate cautions (every phase):** run executors **SERIAL** (parallel self-branches the phase dir); pass a **KNOWN-ALIVE simulator id** (build-gate invents fake ids — get one via `xcrun simctl list devices available`); incremental build every 3–5 files; discard xcstrings build-churn; clean stale SourceKit on phantom errors.
>
> v1.5.2 (UX flow rework) is a separate later set, not yet on the roadmap.

### Phase 31: UI Wave 0 — Shared primitives + ladder source recipes

**Goal:** Route the 7 app-wide source recipes (`MetricTile`, `InsightCard`, `CycleFuelingCard`, `FatigueAttentionBanner`, `REDSAttentionBanner`, `SpikeAlertBanner`, `SharpTextFieldStyle`) through `.cardStyle()`/`surfaceEl`, and fix `SharpTextFieldStyle` padding 12→16. These are copied everywhere, so this one phase restores plane separation across the whole app — the highest-leverage fix. Done = all 7 use surfaceEl/.cardStyle(), build green, regression-gate passes for these files.
**Requirements**: INVENTORY.md §2.A, §6 Wave 0
**Depends on:** Phase 30
**Status:** ✅ DONE 2026-06-02 (`9c4f0f3` feat + `e15e8d3` docs). 7 source recipes → surfaceEl/.cardStyle(); SharpTextFieldStyle pad 12→16. Build GREEN (sim CAF84E71), regression-gate clean. SourceKit phantom diagnostics ignored (xcodebuild authoritative).
**Plans:** 1/1 plan

Plans:
- [x] 31-PLAN.md — route 7 shared recipes onto ladder + field-pad grid fix

### Phase 32: UI Wave 1 — Dashboard (hero screen)

**Goal:** Standardize all 5 Dashboard cards (Welcome/TrainingProfile/Notification/WeeklySummary/PRSDualRun) on `.cardStyle()`; fix `WeeklySummaryCard` `.system` fonts → Font.Tokens; PRSDualRunCard border 1→0.5; promote ACWR/ATL/CTL/TSB load stats to sectionHead weight; apply SectionHeader/SectionContainer grammar; snap off-grid 4/2 spacing. Done = Dashboard plane separation + section grammar correct, build green.
**Requirements**: INVENTORY.md §3 Dashboard, §6 Wave 1
**Depends on:** Phase 31
**Status:** ✅ DONE 2026-06-02 (`d7120e7`/`2744997` feat + `50b7a85` docs). 5 cards → .cardStyle(); WeeklySummary fonts tokenized; PRSDualRun border 0.5; load stats promoted; off-grid spacing snapped. Build GREEN. MetricsStrip kept on .surface (correct inline plane). HRV/Sleep detail views deferred to Wave 3/later.
**Plans:** 0 plans

Plans:
- [ ] TBD (run /gsd-plan-phase 32 to break down)

### Phase 33: UI Wave 2 — Workout Log (hero screen)

**Goal:** Apply SectionContainer + SectionHeader to Prescribed/My Templates/Watch sections with 32pt breaks; move tappable cards to `surfaceEl` (PrescribedWorkoutCard, TemplateCarouselSection, ActiveWorkoutSheet ExerciseEntryCard); fix flat SessionRow hierarchy; replace `.system` icons with tokens; localize SET/WEIGHT/REPS/RPE column headers; snap 12/10 spacing. Done = Workout Log hierarchy correct, build green.
**Requirements**: INVENTORY.md §3 Workout Log, §6 Wave 2
**Depends on:** Phase 32
**Status:** ✅ DONE 2026-06-02 (`0df9809` view + `6920aa8` i18n + `3187230` docs). SectionContainer/Header + 32pt breaks; tappable cards → surfaceEl; SessionRow hierarchy; icon glyphs → imageScale; SET/WEIGHT/REPS/RPE/DIST/TIME localized (+4 catalog keys en+zh); spacing snapped. Build GREEN. Deferred to Wave 4/5: TemplatePickerSheet glyph, PRCelebrationOverlay/ImportRPESheet spacing, SetEntryRow placeholder i18n.
**Plans:** 0 plans

Plans:
- [ ] TBD (run /gsd-plan-phase 33 to break down)

### Phase 34: UI Wave 3 — Elevation ladder, remaining screens

**Goal:** Apply the surfaceEl ladder across remaining screens — Recovery (InsightCard/BehaviorCorrelationRow/MorningCheckIn sliders), Profile (card each settings section group), Coach (ClientDetail heads+recoveryHero, Roster listRowBackground→surfaceEl, TemplateList, WorkoutEntry, Prescribe), Auth (form card + Sign In CTA dominance), Onboarding option tiles, UpgradeSheet (HistoryTeaserBanner + section grammar), Export sheets (extract shared RangeChip). Done = ladder applied app-wide, build green.
**Requirements**: INVENTORY.md §2.A/§3, §6 Wave 3
**Depends on:** Phase 33
**Status:** ✅ DONE 2026-06-02 (Recovery `68a90a7` · Auth `739d147` · Onboarding `ac275ea` · UpgradeSheet `1de2975` · Coach `c6c7ee3` · Profile `aeb5ee3` · Export `938723f` · docs `802d28d`). 18 files, ladder + section grammar across Recovery/Auth/Onboarding/UpgradeSheet/Coach/Profile/Export; ClientDetailView accent→text1 done here; RangeChip extracted; +1 i18n key. 7 builds GREEN. Wave-4 deferrals logged in Phase 35.
**Plans:** 0 plans

Plans:
- [ ] TBD (run /gsd-plan-phase 34 to break down)

### Phase 35: UI Wave 4 — Corner / font / color hard violations

**Goal:** Eliminate the remaining hard violations: `TemplateEditorSheet` `.roundedBorder` text fields → square custom style (CORNER violation the regex scan missed); `ShareImportPreviewSheet:138` → `.Tokens.bodyMedium`; remaining `.system(size:)` icon glyphs → tokens; `UpgradeSheet:146` `.red` → `ColorTokens.zoneDanger`; `ClientDetailView:138` accent → text1/2. Done = 0 corner/shadow/hardcoded-color/accent-misuse violations, build green.
**Requirements**: INVENTORY.md §2.D/E/F/G, §6 Wave 4
**Depends on:** Phase 34
**Status:** ✅ DONE 2026-06-02 (`dce703d` corners + `b1e4b15` fonts + `6b8b6c7` color + `0d2b685` docs). 10 files. roundedBorder→SharpTextFieldStyle; all .system fonts/glyphs→Font.Tokens; .red→zoneDanger. FULL-APP regression gate rules 1-5 CLEAN (0 corners/shadows/fonts/accent/hardcoded-color; PDFKit UIColor in Services justified). Build GREEN.
**Plans:** 0 plans

Plans:
- [ ] TBD (run /gsd-plan-phase 35 to break down)

### Phase 36: UI Wave 5 — Off-grid spacing sweep

**Goal:** Snap all residual 12/10/6/4/2 padding & spacing → `Spacing.*`; fix off-grid frames (44→48, 180→176/184, toggle 28/20, grabber 36/4); decide a documented sub-grid token for true hairlines/indicators (0.5/1/2/3pt rules); tighten the regression-gate off-grid lists to match. Done = regression-gate spacing rules pass app-wide, build green.
**Requirements**: INVENTORY.md §2.C, §6 Wave 5
**Depends on:** Phase 35
**Status:** ✅ DONE 2026-06-02 (9 feat + `926afb2` gate-tighten + `22e6ea4` docs). 22 files, all 75 residual off-grid hits → Spacing.*; added documented Spacing.baselinePair=4 token. Gate rules 6-7 CLEAN (justified hairline exceptions: 0.5/1/2/3pt). Rules 1-5 still 0. Build GREEN.
**Plans:** 0 plans

Plans:
- [ ] TBD (run /gsd-plan-phase 36 to break down)

### Phase 37: UI Wave 6 — Hierarchy / text-weight polish + motion (LAST)

**Goal:** Add per-row emphasis tiers (roster status, export zone labels, detail-view stat numbers, paywall price/SAVE% badge); fine-tune CTA dominance; THEN motion/transition tuning (confirmation/orientation only — must not be used to rescue contrast/hierarchy). Final build gate + run the full regression-gate script. Done = full regression-gate passes, motion polished, build green.
**Requirements**: INVENTORY.md §3/§6 Wave 6
**Depends on:** Phase 36
**Status:** ✅ DONE 2026-06-02 (`5b6befe` hierarchy + `1fca70c` motion + `fa9ac72` docs). Part 1: emphasis tiers on Roster/Export/SessionDetail/UpgradeSheet/Onboarding (Font.Tokens weights only). Part 2: 2 reduce-motion-aware transitions (hero reveal, roster insert/remove); decorative ones held for human review. FINAL regression gate rules 1-7 CLEAN. Build GREEN. **v1.5.1 COMPLETE — cumulative build independently re-verified.**
**Plans:** 0 plans

Plans:
- [ ] TBD (run /gsd-plan-phase 37 to break down)

## Phase Details — v1.5.2 UX Flow Rework

> Spec: `.planning/v1.5-audit/V152-UX-SPEC.md` (defined via /grill-me, grounded in a code flow-map). UX/flow only — NOT visual styling (v1.5.1 done) and NOT algorithm (dormant v1.6 stays dormant, flags FALSE). Onboarding deliberately excluded (already clean). Same build-gate cautions as v1.5.1 (serial executors, sim CAF84E71, incremental builds, localize new strings en+zh).

### Phase 38: UX Wave 1 — Workout log fast entry

**Goal:** Cut the ~15-taps-per-set loop. Carry-forward set defaults (new set pre-fills previous set's weight/reps, within-session); ± steppers on weight/reps (grid-valid increments) with tap-to-keypad for big edits; one-tap "repeat last set"; per-set RPE optional/collapsible (keep per-session RPE at finish); de-modal PR-celebration + spike-alert (inline/dismissible, don't block save — commit already happens first). Done = logging a straight-set workout takes far fewer taps; build green; no algorithm/flag change.
**Requirements**: V152-UX-SPEC.md §A
**Depends on:** Phase 37
**Plans:** 2/2 plans complete

Plans:
- [x] 38-01-PLAN.md — Stepper-primary set entry: always-visible ± steppers + tap-keypad, within-session carry-forward (ghosted), repeat-last-set, dashed add-set, collapsible per-set RPE (Variant A)
- [x] 38-02-PLAN.md — De-modal post-workout interrupts: inline dismissible PR + spike banners (zone-color left border), commit-first invariant + D-08 niggle sequencing preserved

### Phase 39: UX Wave 2 — Recovery quick mode + two-score clarity

**Goal:** (1) Quick mode for returning users — pre-fill yesterday's check-in answers / one-screen fast path, edit only deltas; full 5-section form stays available. (2) Clarify the two 0-100 scores — HealthKit recovery (HRV/RHR/sleep) vs subjective wellness check-in — via distinct labels/placement + a short "why these differ" note. NO FUSION (that's dormant v1.6 PRS algorithm — must not touch). Done = returning check-in is fast; the two scores are unmistakable; UX/labeling only, no engine change.
**Requirements**: V152-UX-SPEC.md §B
**Depends on:** Phase 38
**Plans:** 2/2 plans complete

Plans:
- [x] 39-01-PLAN.md — Quick-mode pre-fill: seed MorningCheckInSheet from latest prior check-in + subtle hint (read-only repo fetch, no schema change)
- [x] 39-02-PLAN.md — Two-score clarity: honest blend subtitle + distinct subordinate "how you feel" element + why-differ note (labeling only, no engine change)

### Phase 40: UX Wave 3 — Dashboard primary-action CTA + value-ranked card stack

**Goal:** (1) Surface the primary action under the hero — the recommendation / "Log Workout" CTA becomes a visible element right below the readiness score, not just a toolbar button. (2) Value-rank the card stack for the no-coach user: readiness → recommendation → today's load context up top; demote setup prompts, empty-states, HealthKit/cycle/training-profile cards below the fold. Done = the daily "am I ready + what do I do" answer + action are immediate; build green; no algorithm change.
**Requirements**: V152-UX-SPEC.md §C
**Depends on:** Phase 39
**Plans:** 1/1 plans complete

Plans:
- [x] 40-01-PLAN.md — C.1 recommendation-aware primary-action CTA under the hero + C.2 value-ranked / context-aware card stack reorder (DashboardView + xcstrings)

## Phase Details — v2.0 Plan-Aware Decision Engine (TODAY Verdict Wedge)

> **Milestone Goal:** Ship the validated MVP wedge — the plan-aware TODAY verdict for a single planned strength session. Fuse readiness + directional cross-modal fatigue + periodization position into a go/modify/hold verdict + an adjusted top-set number + a one-line why, presented as **suggest-and-confirm** (never overwrites the authored plan). This is the **core-identity pivot** from monitoring app to plan-aware decision engine, and the **first paid-validation milestone** — instrument the green-light signal + WTP before building further horizons (MID/LONG deferred until WTP clears).
>
> **Strategic basis:** Redefinition (2026-06-12) validated MODIFY-SCOPE against 51 real self-coached hybrid athletes + 5 adversarial kills (`.planning/research/plan-aware-thesis-pressure-test.md`). ~70% of the verdict engine **already exists, built + tested green, flag-gated OFF** from dormant v1.6 work (ReadinessFusionEngine, StrainRiskEngine, BaselineEngine, AutoregulationEngine.recommendReadiness 3×3 matrix, ProgressionEngine, ReasoningEngine.explainDecision, ShadowMetrics). v2.0 **activates and surfaces** these (`.planning/research/v2-verdict-engine.md`) — it does NOT rebuild them. The single genuine engine gap is **directional cross-modal fatigue carry** (`.planning/research/v2-crossmodal-and-measurement.md`), which must shadow-validate before driving the user-facing verdict.
>
> **Hard product constraints (gate the verdict surface, not polish):** suggest-and-confirm (never overwrite), feel-override-as-input, number+reason never a red "don't train" gate (nocebo guard). Measurement must be instrumented BEFORE the verdict ships to validation users (founder's-playbook MVP gate). Composite-only events — no raw HealthKit ever syncs.
>
> **Critical-path ordering (buildable):** substrate activation + cross-modal (shadow-gated) → plan input (additive-nullable, no migration) → verdict engine (thin translation) → suggest-and-confirm UX → measurement instrumentation → validation-ready. Cross-modal must shadow-validate before it drives the verdict; measurement must exist before user-facing launch.
>
> **Out of scope (v2.0):** MID-horizon overreach forecast (FCST), LONG-horizon response profiling, full multi-week program ingestion / LLM whole-plan parse, coach-as-plan-author, conditioning-PRIMARY verdict, AI chat coach.

### Phase 41: Substrate Activation + Cross-Modal Fatigue Carry (shadow-gated)

**Goal**: Activate the dormant PRS readiness pipeline on a real verdict-feeding surface and add the one genuine new engine — directional cross-modal fatigue carry — building it dark and shadow-validating it BEFORE it is allowed to drive any user-facing number.
**Depends on**: Phase 29 (PRS shadow-validation + activation gates), Phase 30 (shadow-engine quality fixes)
**Requirements**: ACT-01, ACT-02
**Success Criteria** (what must be TRUE):

  1. The PRS pipeline (BaselineEngine → ReadinessFusionEngine + StrengthLoadEngine → StrainRiskEngine → AutoregulationEngine.recommendReadiness) runs in **production** for the verdict surface — no longer tests-only — with the runtime flag-gate removed for that surface and honest-confidence gating preserved (low confidence / cold-start defers, never imputes).
  2. A new pure `CrossModalFatigueEngine` regionalizes endurance/conditioning sessions (sRPE × sportType → muscle region, anchor + saturating concave modifier, NOT naive linear stacking) so yesterday's run elevates today's leg-region carry but not chest.
  3. For a fried-legs day, the engine produces a meaningful leg-region penalty on a squat input and a near-zero penalty on a bench input (run-hits-squat-not-bench behaviour is observable in engine output).
  4. The cross-modal arm logs as a new prediction arm through the existing ShadowMetrics / ShadowAnalyticsService harness (paired-MAE CI, Spearman, calibration, blocked-CV) and is **gated OFF from the verdict** until shadow signal is confirmed — the green-light to let it drive the verdict is an explicit shadow-validation pass, not a code merge.
  5. All live (legacy) recovery/recommendation behaviour stays byte-identical when the verdict surface is not active (existing tier/flag fences remain green).

**Plans**: 3 plans
- [x] 41-01-PLAN.md — Activate the dormant PRS readiness/strain pipeline on the production verdict-feeding dashboard surface (surface-scoped flag, app-wide fences untouched, honest-confidence deferral preserved) + complete the deferred Phase-28 dual-run UI review (ACT-01)
- [x] 41-02-PLAN.md — Build the new pure `CrossModalFatigueEngine` (regionalize endurance/conditioning sRPE by sportType, personal-baseline normalization, anchor + saturating concave modifier, multiplicative systemic combine) — run-hits-squat-not-bench, TDD (ACT-02) — DONE 2026-06-13, 22/22 tests green, engine DARK
- [x] 41-03-PLAN.md — Register the cross-modal channel as a fourth DARK shadow arm through the existing ShadowMetrics/ShadowAnalyticsService harness + `CrossModalShadowGate` verdict-influence fence (default OFF, report-only, flipped only by an explicit human shadow-validation pass) (ACT-02) — DONE 2026-06-13, crossModal 4th arm + gate, 10/10 tests green, existing arms byte-identical, shadow-gate verified OFF (code-level), human flip deferred

### Phase 42: Plan Input — Today's Planned Session + Adjustable Targets

**Goal**: Let the athlete designate today's planned strength session (load an existing template OR enter a planned lift) and give each planned set the additive target fields the verdict reads from and writes a suggested adjustment into — with zero migration and zero sync-payload change.
**Depends on**: Phase 41
**Requirements**: PLAN-10, PLAN-11
**Success Criteria** (what must be TRUE):

  1. The athlete can designate "today's planned session" by loading an existing `WorkoutTemplate`/`PrescribedWorkout` OR entering a one-off planned lift with target weight/reps/RPE (manual today-entry path).
  2. A planned working set carries target fields (`targetWeightKg`/`targetReps`/`targetRPE`/`targetRIR`) the verdict can read, plus additive-nullable adjusted-target fields (`adjustedTargetWeightKg`, `adjustedTargetRPE`, `verdictReason`, `verdictAppliedAt`, `athleteOverrode`) the verdict writes into.
  3. The new fields are nullable-with-default so existing SwiftData rows decode unchanged (no migration) and `TemplateSet` stays out of the synced payload (no backend/RLS change — composite-only constraint upheld).
  4. The verdict writes adjusted targets onto the **prescription's frozen copy** only — the source authored template is never mutated (the "never writes the program" constraint holds).

**Plans**: 3 plans (3 waves)

Plans:

**Wave 1**
- [x] 42-01-PLAN.md — Additive-nullable verdict-target slots on TemplateSet (adjustedTargetWeightKg/adjustedTargetRPE/verdictReason/verdictAppliedAt/athleteOverrode) + persistence/no-migration/sync-omission tests (PLAN-11)

**Wave 2** *(blocked on Wave 1)*
- [x] 42-02-PLAN.md — PlannedSessionRepository: designate today's session from a template (frozen copy) OR a one-off manual lift + fetch-today + repository tests (PLAN-10, PLAN-11)

**Wave 3** *(blocked on Wave 2)*
- [x] 42-03-PLAN.md — Minimal DESIGN-compliant "Plan Today" UI (reuses TemplatePickerSheet + ManualLiftEntrySheet) wired to the repository + pbxproj registration + human-verify checkpoint (PLAN-10)

**UI hint**: yes

### Phase 43: TODAY Verdict Engine — Go/Modify/Hold + Adjusted Number + Reason

**Goal**: Produce the verdict itself — collapse the existing readiness×strain recommendation into a go/modify/hold trichotomy, compute an evidence-bounded adjusted top-set number / back-off volume cut for the planned lift, and assemble a one-line plain-language reason citing the driving signals.
**Depends on**: Phase 41, Phase 42
**Requirements**: VERDICT-01, VERDICT-02, VERDICT-03
**Success Criteria** (what must be TRUE):

  1. For today's planned strength session the engine outputs a **go / modify / hold** verdict driven by readiness + cross-modal fatigue + periodization position (where a plan position is known) — a pure derived function of the existing `intensityCap`/`volumeModifier`/`sessionType`, not a 4th model.
  2. The engine proposes a concrete adjusted top-set number and/or back-off volume cut bounded to evidence-defensible magnitude (−5% default, −10% ceiling, volume-cut preferred over load-cut) and **rounded to loadable plates** — no false precision (e.g. never "−6.2%").
  3. Each verdict carries a one-line plain-language reason from `ReasoningEngine.explainDecision` that names the driving signals, including the cross-modal cause when it is the driver ("legs still loaded from yesterday's run"), stays inside the no-injury-prediction grep guard, and reports confidence separately.
  4. On low confidence / cold-start the verdict defers to the plan ("going with your plan, still learning your baseline") rather than trimming on a guess.

**Plans**: 3 plans

Plans:
- [x] 43-01-PLAN.md — TodayVerdictEngine: go/modify/hold trichotomy + bounded plate-rounded adjusted top-set number (VERDICT-01, VERDICT-02)
- [x] 43-02-PLAN.md — VerdictReasonBuilder: one-line reason via explainDecision + separate confidence + gate-gated cross-modal cause + cold-start defer (VERDICT-03)
- [x] 43-03-PLAN.md — TodayVerdictService: read today's planned session, run the engines, write the suggestion into the Phase-42 verdict slots (VERDICT-01/02/03)

### Phase 44: Suggest-and-Confirm Verdict Surface (autonomy + nocebo guards)

**Goal**: Wrap the verdict in the nocebo-safe, autonomy-respecting UX that the validation hinges on — number + reason the athlete confirms, feel-override as a first-class logged input, one-tap keep-my-plan, and never a red don't-train gate. This UX is a hard product constraint that gates the surface, not optional polish.
**Depends on**: Phase 43
**Requirements**: MOD-10, MOD-11, MOD-12
**Success Criteria** (what must be TRUE):

  1. The verdict is **suggest-and-confirm**: the athlete explicitly accepts or declines each suggestion, declines are recorded, and the app never silently overwrites the planned (authored) numbers — accept and decline carry equal visual weight.
  2. The athlete can override the verdict with their own feel (feel-as-input that nudges/dismisses the suggestion and is logged), and a low/hold verdict is framed as a **number + reason** ("hold last week's weight, skip the PR"), never a red "don't train" gate.
  3. A one-tap "keep my plan as written" leaves the planned session unchanged and records the decline without friction or guilt copy.
  4. No bare pre-session readiness number is shown as the hero affordance; the surface leads with the action-on-the-plan + reason (the validated anti-nocebo framing).

**Plans**: 2 plans (2 waves)

Plans:

**Wave 1**
- [x] 44-01-PLAN.md — Decision/state layer: VerdictDecisionApplier (accept→verdictAppliedAt, keep→athleteOverrode, never overwrite the authored number) + TodayVerdictViewModel (assemble inputs, write Phase-42 slots via TodayVerdictService, display + feel-override + cold-start defer)

**Wave 2** *(blocked on Wave 1)*
- [x] 44-02-PLAN.md — TodayVerdictCard suggest-and-confirm surface (action+reason hero, equal-weight accept/keep, first-class feel-override, never a red gate) + WorkoutLog wiring + en/zh-Hans strings + source-grep DESIGN/nocebo guard + deferred human-verify UAT

**UI hint**: yes

### Phase 45: Measurement & WTP Instrumentation (must precede validation launch)

**Goal**: Instrument the founder's-playbook validation layer BEFORE the verdict ships to validation users — log a VerdictEvent per planned session, compute the green-light signal on differing-verdict days, and capture the Sean-Ellis + willingness-to-pay signals — all composite-only, wired into the existing shadow harness and RevenueCat.
**Depends on**: Phase 44
**Requirements**: METRIC-01, METRIC-02, METRIC-03
**Success Criteria** (what must be TRUE):

  1. A `VerdictEvent` is logged per planned session capturing the verdict, suggested-vs-planned numbers, whether they **DIFFERED**, accept/decline, and a post-session self-reported outcome — composite-only (no raw HealthKit; region labels and deltas only).
  2. The app computes the **green-light signal** = differing-verdict days where the athlete acted on the suggestion AND reported it was right, surfaced alongside activation rate and Day-7 / Day-30 retention.
  3. The app captures a Sean-Ellis disappointment question ("how would you feel if you could no longer use this") and a willingness-to-pay / card-on-file signal from the validation cohort (via the integrated RevenueCat trial→paid path).
  4. Instrumentation is verified live **before** the verdict surface is exposed to any validation user — measurement is a prerequisite, not a follow-up.

**Plans**: 4 plans — ALL COMPLETE (2026-06-14, on main)
- [x] 45-01-PLAN.md — VerdictEvent composite-only @Model + schema + repository + GreenLightEngine (METRIC-01 substrate, METRIC-02 compute)
- [x] 45-02-PLAN.md — Wire onDecisionRecorded → VerdictEvent log (SC4 guard) + post-session right/wrong/unsure outcome capture (METRIC-01)
- [x] 45-03-PLAN.md — Quiet green-light / activation / retention analytics surface in Profile (METRIC-02)
- [x] 45-04-PLAN.md — Sean-Ellis disappointment prompt + WTP/card-on-file via existing RevenueCat paywall (METRIC-03)
**UI hint**: yes
**Status**: Complete — METRIC-01/02/03 + SC4 all instrumented, app build green on sim CAF84E71, all new + regression test classes green, no " 2.swift" dupes. Deferred-external: RevenueCat dashboard trial→paid offering config + real-charge testing (human). Deferred-human: on-device visual UAT of the three new surfaces.

### v2.0 Execution Order

- **41 → 42 → 43 → 44 → 45** (strict critical path; coarse granularity).
- Phase 41's cross-modal arm builds dark and must clear its shadow-validation pass before it is permitted to drive the Phase 43 verdict.
- Phase 45 (measurement) must be live and verified before the Phase 44 surface is exposed to validation users — instrument before launch.

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 41. Substrate Activation + Cross-Modal Fatigue Carry | v2.0 | 1/3 | In Progress|  |
| 42. Plan Input — Today's Planned Session + Adjustable Targets | v2.0 | 3/3 | Complete   | 2026-06-13 |
| 43. TODAY Verdict Engine — Go/Modify/Hold + Number + Reason | v2.0 | 3/3 | Complete   | 2026-06-13 |
| 44. Suggest-and-Confirm Verdict Surface | v2.0 | 2/2 | Complete   | 2026-06-13 |
| 45. Measurement & WTP Instrumentation | v2.0 | 0/4 | Planned     | - |
