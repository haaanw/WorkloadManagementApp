# Requirements: Tonus

**Defined:** 2026-04-22
**Core Value:** Recovery + load tracked over time -- giving athletes long-term insight into how their body responds to training, so they can train smarter and avoid injury.

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

**Coverage:**
- v1.1 requirements: 21 total, mapped: 21
- v1.2 requirements: 19 total, mapped: 19
- v1.3 requirements: 16 total, mapped: 16
- v1.4 requirements: 8 total, mapped: 8
- Unmapped: 0

---
*Requirements defined: 2026-04-22*
*Last updated: 2026-05-30 -- v1.4 CYCLE-01..08 mapped to phases 17-19*
