# Roadmap: Tuwa

## Milestones

- ✅ **v1.0 Post-Launch** — Phases 1-4 (shipped 2026-04-22)
- ✅ **v1.1 App Store Launch** — Phases 5-8 (shipped 2026-04-30)
- ✅ **v1.2 Training Onboarding & Templates** — Phases 9-12 (shipped 2026-05-10)
- ✅ **v1.3 LLM Import, Sharing & Polish** — Phases 13-16 (shipped 2026-05-14)
- ✅ **v1.4 Female Athlete Optimization** — Phases 17-20 (phase-complete 2026-05-30, pending UAT)
- ✅ **v1.5 UX Interaction Polish** — Phases 21-22 (phase-complete 2026-05-30, pending UAT)
- 🚧 **v1.6 Algorithm Moat (Personal Readiness v1)** — Phases 24-29 (started 2026-05-30; scope locked, see memory project_algorithm_v1_locked + .planning/research/competitive-algorithm-analysis.md)

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

**Status:** PLANNED 2026-05-31 (user chose fix-now over defer). Fix the 6 shadow/display/flag-on quality findings surfaced by Phase 27/28/29 adversarial review + codex review. ALL live behavior stays byte-identical (fences hold); nothing activated; master flag stays FALSE. Goal: clean shadow Strain-Risk + readiness inputs so the eventual activation-gate evaluation runs on correct data.

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
