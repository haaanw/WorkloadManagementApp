# Requirements: Tonus

**Defined:** 2026-04-22
**Core Value (redefined 2026-06-12):** Plan-aware decision support — the athlete (or their coach) authors the program; Tuwa ingests it whole, fuses it with physiology, and supports training decisions at three horizons: adjust today's numbers, go/modify/hold verdicts, and overreach forecasting — one fatigue budget across sport + strength + conditioning. Never writes the program; never a chatbot.

## v1.1 Requirements

Requirements for App Store launch. Each maps to roadmap phases.

### Streaks

- [ ] **STRK-01**: User can see current workout streak (consecutive weeks with 1+ logged session) on dashboard
- [ ] **STRK-02**: Dashboard displays streak badge showing current streak count

### Notifications

- [ ] **NOTF-01**: User receives weekly local push notification summarizing sessions, PRs, and streak
- [ ] **NOTF-02**: App shows pre-permission screen explaining notification value before iOS permission dialog
- [ ] **NOTF-03**: User can configure notification day/time and toggle on/off in Profile settings

### Export

- [ ] **EXPRT-01**: User can generate PDF athlete report with recovery scores, workload trends, and PRs (composite data only)
- [ ] **EXPRT-02**: Coach can generate PDF multi-athlete summary report
- [ ] **EXPRT-03**: PDF export is gated behind Pro/Coach subscription (free users retain CSV)

### App Store Metadata

- [ ] **ASO-01**: App Store listing has optimized title (30 chars), subtitle (30 chars), and keyword field (100 chars)
- [ ] **ASO-02**: App Store description communicates core value proposition
- [ ] **ASO-03**: Marketing screenshots with benefit-oriented captions for 6.7" and 6.5" device sizes
- [ ] **ASO-04**: App Store categories and age rating configured correctly

### App Review Compliance

- [ ] **CMPL-01**: Pre-seeded demo account with 2-3 weeks of data for App Review team
- [ ] **CMPL-02**: PrivacyInfo.xcprivacy audit passes (all API declarations accurate)
- [ ] **CMPL-03**: Subscription terms, restore purchase, and cancellation flows verified
- [ ] **CMPL-04**: All in-app links (privacy policy, ToS, support) resolve correctly
- [ ] **CMPL-05**: HealthKit usage descriptions are accurate and detailed in Review Notes

### QA & Performance

- [ ] **QA-01**: Systematic QA pass across all user flows, edge cases, and empty states
- [ ] **QA-02**: Performance audit -- cold launch < 2s, 60fps scroll, no memory leaks
- [ ] **QA-03**: Accessibility audit -- VoiceOver navigation, Dynamic Type support, contrast compliance
- [ ] **QA-04**: MetricKit telemetry integrated for post-launch crash and performance reporting

## v1.2 Requirements

Requirements for Training Onboarding & Templates milestone. Each maps to roadmap phases.

### Foundation

- [ ] **FOUND-01**: TrainingProfile model stores questionnaire answers, seeded ATL/CTL, and bias data with Supabase sync
- [ ] **FOUND-02**: WorkoutTemplate model extended with isAthleteOwned, isFavorite, isArchived, lastUsedAt, usageCount, scheduledDays fields (additive only, no renames)
- [ ] **FOUND-03**: Supabase RLS policies updated to allow athlete-owned template CRUD alongside existing coach policies
- [ ] **FOUND-04**: TemplateRepository provides fetch, save, duplicate, archive, and delete operations for athlete-owned templates

### Cold-Start Questionnaire

- [ ] **COLD-01**: User can complete 4 required questions (sessions/week, avg duration, typical sRPE 1-10, weeks at current level) via training profile card post-onboarding
- [ ] **COLD-02**: User can optionally answer 4 additional questions (training age in years, periodized vs steady schedule, current movement types, injury history with body region picker + free text)
- [ ] **COLD-03**: ColdStartEngine computes seeded ATL/CTL from questionnaire answers using sRPE TSS formula (hours x RPE x RPE/10)
- [ ] **COLD-04**: Estimated ATL/CTL stored on TrainingProfile only (never on WorkloadSnapshot), displayed on dashboard during cold-start window
- [ ] **COLD-05**: Dashboard switches from estimated to real ATL/CTL after 3+ weeks elapsed AND 8+ sessions logged
- [ ] **COLD-06**: App stores perceptual bias metric (estimated vs actual load) silently at 8-week mark on TrainingProfile
- [ ] **COLD-07**: FatigueIndex displays "insufficient data" state during cold-start window instead of computing from incomplete baselines

### Training Templates

- [ ] **TMPL-01**: User can manually create a training template with named exercise groups (A/B/C/D), each containing exercises with target sets/reps/weight
- [ ] **TMPL-02**: User can save a completed workout session as a new template (actuals become targets, exercises in single default group)
- [ ] **TMPL-03**: User can select a saved template when starting a new session via template picker (accessible from "+" button)
- [ ] **TMPL-04**: Template-loaded session pre-fills exercises with last-used actual values as ghost targets
- [ ] **TMPL-05**: User can edit, duplicate, archive, favorite/pin, and delete templates from template management view
- [ ] **TMPL-06**: Dashboard and workout log tab show favorite/recent templates as quick-start cards for one-tap session start
- [ ] **TMPL-07**: When loading a template, ProgressionEngine overlays recovery-aware suggested targets alongside last-used values (Pro-gated)
- [ ] **TMPL-08**: TemplateSuggestionEngine learns day-of-week usage patterns and suggests most likely template when user opens the app (Pro-gated, requires 2+ weeks of data)

## v1.3 Requirements

Requirements for LLM Import, Sharing & Polish milestone. Each maps to roadmap phases.

### Design Polish

- [ ] **DESGN-01**: App uses Alpino font (Regular + Medium) from FontShare instead of DM Sans across all views
- [ ] **DESGN-02**: All `.roundedBorder` text field styles replaced with 0pt corner custom style per design system

### Sync Hardening

- [ ] **SYNC-01**: All SyncService pull-side `try?` calls replaced with `do/catch` + error logging
- [ ] **SYNC-02**: Per-entity sync timestamps track last successful sync per data type (workouts, snapshots, wellness, templates, PRs)
- [ ] **SYNC-03**: Partial sync failure for one entity type does not block other entity types from syncing

### Template Sharing

- [ ] **SHARE-01**: User can generate 8-char share code for any owned template
- [ ] **SHARE-02**: User can import a template by entering a share code
- [ ] **SHARE-03**: User can share template via universal link (tap opens app, imports template)
- [ ] **SHARE-04**: User sees preview of shared template (exercises, groups, sets/reps) before importing
- [ ] **SHARE-05**: Imported template is a deep copy — no reference to original, personal weight data stripped

### LLM Workout Import

- [ ] **LLM-01**: User can paste workout text and have it parsed into a template via LLM
- [ ] **LLM-02**: User can import a PDF file and have its text extracted and parsed into a template
- [ ] **LLM-03**: User can take a photo or select from library and have OCR + LLM parse it into a template
- [ ] **LLM-04**: User sees parsed template preview with exercises/sets/reps before saving
- [ ] **LLM-05**: LLM parsing runs via Supabase Edge Function proxy (API key never in iOS binary)
- [ ] **LLM-06**: LLM import uses GPT-4o-mini with structured output (JSON Schema enforcement)

## v1.4 Requirements

Requirements for the Female Athlete Optimization milestone (cycle-aware context & guidance). Each maps to roadmap phases. CYCLE-01..05 were delivered by the cycle-tracking foundation (Phases 17-18); CYCLE-06..08 are the user-facing surfacing delivered by Phase 19. All cycle features are 100% opt-in, readiness-first (context never a training directive), and local-only (no menstrual data leaves the device).

### Cycle Tracking Foundation (Phases 17-18)

- [ ] **CYCLE-01**: App reads menstrual flow history from HealthKit (read-only, opt-in) and detects cycle starts (metadata + gap-based fallback)
- [ ] **CYCLE-02**: CycleTrackingService estimates cycle phase via a 14-day fixed-luteal model and scores confidence from completed cycles, regularity, and optional wrist-temperature confirmation
- [ ] **CYCLE-03**: Daily MenstrualCycleSnapshot is persisted locally (never synced) and a CycleContext value type is produced for downstream engines
- [ ] **CYCLE-04**: RecoveryScoreEngine applies confidence-gated same-phase HRV/RHR baselines (only when confidence >= 0.7, phase != unknown, no exclusion)
- [ ] **CYCLE-05**: Reproductive-health flags and all menstrual data are excluded from every Supabase sync payload (privacy guardrail)

### Cycle Context & Guidance (Phase 19)

- [ ] **CYCLE-06**: Cycle context is surfaced read-only — an unobtrusive Dashboard day/phase indicator and a readiness-first phase-context line in the Recovery card — shown only with opt-in HealthKit menstrual data and high confidence, never as a training directive (SC1, SC2, SC5, SC6)
- [ ] **CYCLE-07**: Cycle-aware fueling & recovery prompts (avoid fasted hard sessions, post-training protein within ~45 min, luteal hydration/cooling) are offered as supportive suggestions, never a training override (SC3, SC5)
- [ ] **CYCLE-08**: A non-diagnostic RED-S monitoring notice surfaces when cycle patterns change (3+ missed periods OR consistent >35-day cycles), with clinician-referral language and full exclusion handling (pregnancy, lactation, hormonal contraceptive, perimenopause, PCOS) (SC4)

## Core Redefinition Requirements (unscheduled, defined 2026-06-12)

Core function redefined: plan-aware decision support engine — readiness-driven modulation of a user-authored hybrid plan with periodization-position awareness. See `.planning/notes/core-redefinition-plan-aware-engine.md`. Not yet mapped to a milestone; supersede generic monitoring framing in all future scoping.

### Plan Awareness

- [ ] **PLAN-01**: User can ingest a full training program (blocks/mesocycles, weekly structure, per-session exercises×sets×intensity) via LLM parsing of text/PDF/image/spreadsheet — extends v1.3 single-workout import to whole programs
- [ ] **PLAN-02**: App models periodization position from the ingested plan (current block type, week-in-block, deload proximity) — declared intent, not just detection
- [ ] **PLAN-03**: App tracks plan-vs-actual adherence (planned load vs executed load, per session and per week)

### Daily Modulation

- [ ] **MOD-01**: On a planned session day, app proposes concrete numeric adjustments within plan intent (intensity %, set count, back-off volume) driven by readiness, accumulated load, and periodization position
- [ ] **MOD-02**: App issues a go/modify/hold session verdict with plain-language reasoning citing the signals behind it
- [ ] **MOD-03**: Modulation is bounded and consent-based — app never silently rewrites the plan; athlete accepts/declines each adjustment, and declines are recorded

### Unified Hybrid Load

- [ ] **LOAD-01**: One fatigue budget across strength (tonnage + per-muscle local load), sport-skill sessions, and conditioning — sRPE as systemic common currency, TRIMP layered where HR data exists
- [ ] **LOAD-02**: All decision thresholds use individualized rolling baselines (Altini-style); no population cut-offs and no ACWR as a decision rule

### Forecast

- [ ] **FCST-01**: App projects fatigue trajectory against the remaining plan and forecasts overreach risk before the scheduled deload, including deload-timing recommendations
- [ ] **FCST-02**: App builds a long-term response profile — how this athlete's recovery responds to specific block types across mesocycles

## v2.0 Requirements — Plan-Aware Decision Engine (TODAY Verdict Wedge)

Milestone v2.0 scopes the TODAY horizon of the redefinition into a shippable, paid-validation wedge. Validated MODIFY-SCOPE against 51 real self-coached hybrid athletes + 5 adversarial kills (`.planning/research/plan-aware-thesis-pressure-test.md`); engine substrate ~70% pre-built and flag-gated OFF from dormant v1.6 work (`.planning/research/v2-verdict-engine.md`, `v2-crossmodal-and-measurement.md`). MID (FCST) and LONG horizons deferred until WTP clears. Subsumes the wedge-relevant slice of the unscheduled MOD/LOAD reqs; full PLAN-01 program ingestion stays deferred.

### Substrate Activation

- [x] **ACT-01**: The dormant PRS readiness pipeline (ReadinessFusionEngine + StrainRiskEngine + BaselineEngine + AutoregulationEngine readiness×strain matrix) is activated on a live verdict surface — Phase-28 UI review completed, runtime flag-gate removed, honest-confidence gating preserved
- [x] **ACT-02**: Directional cross-modal fatigue carry — endurance/conditioning sessions are regionalized (sRPE × sportType → muscle region) so yesterday's run penalizes today's squat but spares bench (anchor + saturating modifier, no naive linear stacking); shadow-validated via existing ShadowMetrics before it drives the verdict *(ENGINE BUILT 41-02: CrossModalFatigueEngine green, run-hits-squat-not-bench observable. SHADOW-GATE WIRED 41-03: crossModal logs as the 4th DARK arm through the existing ShadowMetrics/ShadowAnalyticsService harness, fenced from the verdict by CrossModalShadowGate.crossModalDrivesVerdict (default OFF, report-only, no-mutation), 10/10 tests green, existing arms byte-identical. The flag flips ONLY on a FUTURE explicit human shadow-validation pass — by design, not a code merge — before Phase 43 may consume it.)*

### Plan Input

- [x] **PLAN-10**: User can designate "today's planned session" by loading an existing template OR entering a planned lift with target weight/reps/RPE
- [x] **PLAN-11**: A planned set carries target fields the verdict can read and against which it writes a suggested adjusted value (additive-nullable schema, no migration or sync-payload change)

### TODAY Verdict

- [x] **VERDICT-01**: For today's planned strength session, the app outputs a go / modify / hold verdict driven by readiness + cross-modal fatigue + periodization position (where a plan position is known)
- [x] **VERDICT-02**: The app proposes a concrete adjusted top-set number and/or back-off volume cut, bounded to evidence-defensible magnitude (−5% default, −10% ceiling, volume-cut preferred over load-cut), rounded to loadable plates — no false precision
- [x] **VERDICT-03**: Each verdict displays a one-line plain-language reason citing the driving signals (via ReasoningEngine)

### Verdict UX (autonomy + nocebo guards)

- [x] **MOD-10**: The verdict is suggest-and-confirm — the athlete accepts or declines each suggestion, declines are recorded, and the app never silently overwrites the authored plan
- [x] **MOD-11**: The athlete can override the verdict with their own feel (feel-as-input), and a low/hold verdict is framed as a number + reason, never a red "don't train" gate (nocebo guard)
- [x] **MOD-12**: One-tap "keep my plan as written" leaves the planned session unchanged and records the decline

### Measurement & WTP (instrumented before launch)

- [x] **METRIC-01**: The app logs a VerdictEvent per planned session — the verdict, suggested vs planned numbers, whether they DIFFERED, accept/decline, and a post-session self-reported outcome — composite-only (no raw HealthKit) — *Phase 45 (45-01 substrate, 45-02 live wiring + SC4)*
- [x] **METRIC-02**: The app computes the green-light signal (on differing-verdict days: athlete acted on the suggestion AND reported it was right) alongside activation and Day-7 / Day-30 retention — *Phase 45 (45-01 GreenLightEngine, 45-03 quiet Profile surface)*
- [x] **METRIC-03**: The app captures a Sean-Ellis disappointment question ("how would you feel if you could no longer use this") and a willingness-to-pay / card-on-file signal from the validation cohort — *Phase 45 (45-04 Sean-Ellis store/prompt + existing-RevenueCat WTP hop; dashboard offering config deferred-external)*

## Future Requirements

### Deferred from v1.1

- **STRK-03**: Check-in streak (consecutive days/weeks with wellness check-ins)
- **STRK-04**: Streak freeze/forgiveness (48-hour grace period)
- **SHARE-01**: Share cards (social summaries via ImageRenderer)
- **NOTF-04**: Remote push notifications for coach-assigns-workout events
- **ASO-05**: Custom Product Pages for athlete vs coach search intents

### Deferred from v1.2

- **TMPL-09**: Template sharing between users/coaches — promoted to v1.3 as SHARE-01 through SHARE-05
- **TMPL-10**: LLM-powered file/image workout import — promoted to v1.3 as LLM-01 through LLM-06
- **TMPL-11**: HealthKit workout → template auto-matching (high false-positive risk without exercise-level data)
- **TMPL-12**: Template folders/organization (premature before users accumulate 10+ templates)
- **COLD-08**: Continuous perceptual bias calibration (adjust sRPE calculations per user over time)
- **COLD-09**: Injury-aware loading management (deep longitudinal injury tracking + correlation)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Real-time chat between coach and athlete | High complexity, not core to training insight |
| Video analysis | Different product category |
| Android | iOS-first, revisit after establishing market fit |
| Apple Watch companion app | Defer until core iOS experience is polished |
| Manual mesocycle/ATP planner | TrainingPeaks owns this space; Tonus's value is automated detection |
| AI chatbot / conversational coach | LLM cost + liability; keep autoregulation rule-based |
| Pre-built template library / marketplace | Content work, not engineering -- defer post-v1.3 |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| STRK-01 | Phase 5 | Pending |
| STRK-02 | Phase 5 | Pending |
| NOTF-01 | Phase 5 | Pending |
| NOTF-02 | Phase 5 | Pending |
| NOTF-03 | Phase 5 | Pending |
| EXPRT-01 | Phase 6 | Pending |
| EXPRT-02 | Phase 6 | Pending |
| EXPRT-03 | Phase 6 | Pending |
| ASO-01 | Phase 7 | Pending |
| ASO-02 | Phase 7 | Pending |
| ASO-03 | Phase 7 | Pending |
| ASO-04 | Phase 7 | Pending |
| CMPL-01 | Phase 8 | Pending |
| CMPL-02 | Phase 8 | Pending |
| CMPL-03 | Phase 8 | Pending |
| CMPL-04 | Phase 8 | Pending |
| CMPL-05 | Phase 8 | Pending |
| QA-01 | Phase 8 | Pending |
| QA-02 | Phase 8 | Pending |
| QA-03 | Phase 8 | Pending |
| QA-04 | Phase 8 | Pending |
| FOUND-01 | Phase 9 | Pending |
| FOUND-02 | Phase 9 | Pending |
| FOUND-03 | Phase 9 | Pending |
| FOUND-04 | Phase 9 | Pending |
| COLD-01 | Phase 10 | Pending |
| COLD-02 | Phase 10 | Pending |
| COLD-03 | Phase 9 | Pending |
| COLD-04 | Phase 10 | Pending |
| COLD-05 | Phase 10 | Pending |
| COLD-06 | Phase 10 | Pending |
| COLD-07 | Phase 10 | Pending |
| TMPL-01 | Phase 11 | Pending |
| TMPL-02 | Phase 11 | Pending |
| TMPL-03 | Phase 12 | Pending |
| TMPL-04 | Phase 12 | Pending |
| TMPL-05 | Phase 11 | Pending |
| TMPL-06 | Phase 12 | Pending |
| TMPL-07 | Phase 12 | Pending |
| TMPL-08 | Phase 12 | Pending |
| DESGN-01 | Phase 13 | Pending |
| DESGN-02 | Phase 13 | Pending |
| SYNC-01 | Phase 14 | Pending |
| SYNC-02 | Phase 14 | Pending |
| SYNC-03 | Phase 14 | Pending |
| SHARE-01 | Phase 15 | Pending |
| SHARE-02 | Phase 15 | Pending |
| SHARE-03 | Phase 15 | Pending |
| SHARE-04 | Phase 15 | Pending |
| SHARE-05 | Phase 15 | Pending |
| LLM-01 | Phase 16 | Pending |
| LLM-02 | Phase 16 | Pending |
| LLM-03 | Phase 16 | Pending |
| LLM-04 | Phase 16 | Pending |
| LLM-05 | Phase 16 | Pending |
| LLM-06 | Phase 16 | Pending |
| CYCLE-01 | Phase 17 | Complete |
| CYCLE-02 | Phase 17 | Complete |
| CYCLE-03 | Phase 17 | Complete |
| CYCLE-04 | Phase 18 | Complete |
| CYCLE-05 | Phase 18 | Complete |
| CYCLE-06 | Phase 19 | Complete |
| CYCLE-07 | Phase 19 | Complete |
| CYCLE-08 | Phase 19 | Complete |
| ACT-01 | Phase 41 | Complete |
| ACT-02 | Phase 41 | Complete (engine built 41-02; shadow-gate wired 41-03, dark arm + verdict fence default-OFF; flip pending future human shadow-validation pass) |
| PLAN-10 | Phase 42 | Complete |
| PLAN-11 | Phase 42 | Complete |
| VERDICT-01 | Phase 43 | Complete |
| VERDICT-02 | Phase 43 | Complete |
| VERDICT-03 | Phase 43 | Complete |
| MOD-10 | Phase 44 | Complete |
| MOD-11 | Phase 44 | Complete |
| MOD-12 | Phase 44 | Complete |
| METRIC-01 | Phase 45 | Complete |
| METRIC-02 | Phase 45 | Complete |
| METRIC-03 | Phase 45 | Complete |

**Coverage:**
- v1.1 requirements: 21 total, mapped: 21
- v1.2 requirements: 19 total, mapped: 19
- v1.3 requirements: 16 total, mapped: 16
- v1.4 requirements: 8 total, mapped: 8
- v2.0 requirements: 13 total, mapped: 13
- Unmapped: 0

---
*Requirements defined: 2026-04-22*
*Last updated: 2026-06-13 -- v2.0 ACT/PLAN/VERDICT/MOD/METRIC (13 reqs) mapped to phases 41-45*
