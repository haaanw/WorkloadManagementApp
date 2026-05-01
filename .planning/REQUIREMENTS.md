# Requirements: Tonus

**Defined:** 2026-04-22
**Core Value:** Recovery + load tracked over time — giving athletes long-term insight into how their body responds to training, so they can train smarter and avoid injury.

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
- [ ] **QA-02**: Performance audit — cold launch < 2s, 60fps scroll, no memory leaks
- [ ] **QA-03**: Accessibility audit — VoiceOver navigation, Dynamic Type support, contrast compliance
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
- [ ] **COLD-03**: ColdStartEngine computes seeded ATL/CTL from questionnaire answers using sRPE TSS formula (hours × RPE × RPE/10)
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

## Future Requirements

### Deferred from v1.1

- **STRK-03**: Check-in streak (consecutive days/weeks with wellness check-ins)
- **STRK-04**: Streak freeze/forgiveness (48-hour grace period)
- **SHARE-01**: Share cards (social summaries via ImageRenderer)
- **NOTF-04**: Remote push notifications for coach-assigns-workout events
- **ASO-05**: Custom Product Pages for athlete vs coach search intents

### Deferred from v1.2

- **TMPL-09**: Template sharing between users/coaches (in-app link/code import)
- **TMPL-10**: LLM-powered file/image workout import (PDF, Word, screenshot, text parsing)
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
| Pre-built template library / marketplace | Content work, not engineering — defer post-v1.3 |

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
| FOUND-01 | TBD | Pending |
| FOUND-02 | TBD | Pending |
| FOUND-03 | TBD | Pending |
| FOUND-04 | TBD | Pending |
| COLD-01 | TBD | Pending |
| COLD-02 | TBD | Pending |
| COLD-03 | TBD | Pending |
| COLD-04 | TBD | Pending |
| COLD-05 | TBD | Pending |
| COLD-06 | TBD | Pending |
| COLD-07 | TBD | Pending |
| TMPL-01 | TBD | Pending |
| TMPL-02 | TBD | Pending |
| TMPL-03 | TBD | Pending |
| TMPL-04 | TBD | Pending |
| TMPL-05 | TBD | Pending |
| TMPL-06 | TBD | Pending |
| TMPL-07 | TBD | Pending |
| TMPL-08 | TBD | Pending |

**Coverage:**
- v1.1 requirements: 21 total, mapped: 21
- v1.2 requirements: 19 total, mapped: 0 (awaiting roadmap)
- Unmapped: 0

---
*Requirements defined: 2026-04-22*
*Last updated: 2026-05-01 — v1.2 requirements added*
