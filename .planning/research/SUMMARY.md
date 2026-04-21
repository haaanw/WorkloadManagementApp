# Project Research Summary

**Project:** Tonus — Training Analytics, Periodization Detection, and Data Export
**Domain:** Athlete workload management iOS app (analytics expansion)
**Researched:** 2026-04-20
**Confidence:** HIGH

## Executive Summary

Tonus is entering a well-understood product space: training analytics for strength athletes. The competitive landscape (WHOOP, TrainingPeaks, HRV4Training, Oura) makes the table stakes clear — multi-week trend charts, weekly summaries with week-over-week comparison, a recovery-load correlation view, and CSV export are non-negotiable for retaining power users. Critically, Tonus's existing data layer already captures everything required for all of these features. No new data collection is needed; this is purely an analytics and presentation problem. The recommended approach is to extend the existing layered MVVM + pipeline architecture with new pure-struct engines (`WeeklySummaryEngine`, `PeriodizationEngine`, `FatigueCorrelationEngine`) plugged into a new `AnalyticsPipeline`, using only Apple frameworks (Accelerate for vectorized math, UIGraphicsPDFRenderer for PDF, native string building for CSV). Zero new SPM dependencies are required.

The genuine competitive differentiation for Tonus lies in automatic periodization detection and fatigue pattern analysis — capabilities that no strength-focused app currently delivers without manual configuration. These are algorithmically tractable (slope-based CTL analysis, lag correlation) but data-hungry: they require at minimum 8 weeks of consistent training history before producing meaningful results. Building them on top of the visualization foundation established in Phase 1 is the correct dependency order.

The most significant risks are not technical — they are product and safety risks. ACWR has weak predictive validity for injury; presenting it as an injury risk indicator creates both user trust risk and potential liability. Periodization detection on insufficient data produces garbage labels that erode trust. HealthKit error handling is existing tech debt that silently corrupts recovery data; this must be fixed before any analytics features ship, or the analytics layer will inherit and amplify the corruption. Treating all analytics outputs as observations (not predictions or directives) and gating data-hungry features on sufficiency thresholds are the two most important mitigations.

## Key Findings

### Recommended Stack

The entire analytics and export feature set can be built using Apple frameworks only, with no new SPM dependencies. The existing stack (SwiftUI, SwiftData, Swift Charts, HealthKit, Supabase, RevenueCat) requires no changes. New additions are: `Accelerate` (vDSP) for vectorized math operations on time-series data (sliding window slope, variance, correlation); `UIGraphicsPDFRenderer` + `ImageRenderer` for PDF report generation that mirrors existing SwiftUI chart layouts; and `UniformTypeIdentifiers` for file type declarations in the share sheet. CSV generation requires only native String building (~30 lines) — no library is justified.

**Core technologies:**
- `Accelerate (vDSP)`: Vectorized sliding-window math for analytics engines — ships with iOS, hardware-accelerated, zero dependency cost
- `UIGraphicsPDFRenderer` + `ImageRenderer`: PDF generation capturing existing SwiftUI chart views — Apple-native, iOS 16+, no third-party layout rebuilding needed
- `Swift Charts (extended)`: Scrollable multi-series charts with annotations — iOS 17 features, already a dependency; note iOS 18 annotation+scroll conflict workaround required
- `ShareLink / UIActivityViewController`: Export delivery via system share sheet — standard iOS pattern
- Native String building: CSV export — trivial for write-only use case, no library justified

**What was explicitly rejected:** Create ML (overkill for structured numerical time series), CodableCSV (write-only use case), TPPDF (would duplicate existing SwiftUI layouts), DGCharts (redundant with native Swift Charts), Surge/SwiftNumerics (Accelerate covers everything).

### Expected Features

Features are well-validated against WHOOP, TrainingPeaks, HRV4Training, Oura, and AthleteMonitoring. The table stakes list is clear and all required data already exists in the app.

**Must have (table stakes):**
- Multi-week trend charts (4w/12w/6m CTL/ATL/TSB) — every competitor has this; data already in WorkloadSnapshot
- Weekly training summary with week-over-week load comparison — WHOOP, Oura, TrainingPeaks all deliver automated weekly recaps
- Recovery-load correlation view — fulfills Tonus's core cross-domain promise; data is already collected, this is visualization only
- CSV data export — expected by data-savvy athletes; portability requirement for retention

**Should have (differentiators):**
- Fatigue pattern detection — no strength-focused competitor does individual-level lag correlation automatically
- Training block / periodization detection — TrainingPeaks requires manual ATP setup; Tonus can infer it
- Coach PDF report — AthleteMonitoring charges enterprise prices; Tonus can offer it in the Coach tier
- Readiness-adjusted weekly plan suggestion — extends existing AutoregulationEngine to weekly scope
- Behavior tagging with correlation — WHOOP added this in 2026; Tonus can match it with local-only privacy advantage

**Defer to v2+:**
- Manual mesocycle/ATP planner — TrainingPeaks owns this; Tonus's value is automatic detection
- AI chatbot / conversational coach — LLM infrastructure cost + liability; rule-based autoregulation is correct approach
- Social/leaderboard features — Strava owns this; coach-athlete relationship is the right "social" layer
- Workout programming / plan builder — separate product category
- Real-time session analytics — requires Apple Watch companion app (out of scope)

### Architecture Approach

New features slot directly into the existing layered architecture without structural changes. The key design insight is that all analytics are read-only derived data — they consume existing WorkloadSnapshot, RecoverySnapshot, and WorkoutSession records and never write new models. This means analytics can be developed and tested in isolation without risk to existing data flows. The `AnalyticsPipeline` follows the established `WorkoutPipeline`/`RecoveryPipeline` pattern; new engines follow the `WorkloadCalculator`/`RecoveryScoreEngine` pure-struct pattern; `AnalyticsViewModel` follows `DashboardViewModel`; and `ExportService` is a new static-service pattern for data transformation with no persistence.

**Major components:**
1. `WeeklySummaryEngine` (pure struct) — aggregates 7-day windows of sessions + snapshots into typed `WeeklySummary` structs
2. `PeriodizationEngine` (pure struct) — classifies training phases from CTL slope + volume trends over rolling 28-56 day windows
3. `FatigueCorrelationEngine` (pure struct) — lag correlation between load spikes and recovery dips over multi-week windows
4. `AnalyticsPipeline` (@MainActor struct) — orchestrates all three engines, gathers data from existing repositories, returns composite `AnalyticsResult`
5. `AnalyticsViewModel` (@MainActor @Observable) — exposes analytics state, date range selection, loading state to views
6. `ExportService` (@MainActor struct) — transforms analytics data + session history into PDF (Data) or CSV (String) for share sheet delivery

No new SwiftData models are needed except a `BehaviorTag` model for behavior tagging (Phase 3 differentiator). Existing repositories need additional date-range fetch methods, but no structural changes.

### Critical Pitfalls

1. **HealthKit silent failure corrupts analytics** — `RecoveryPipeline.run()` already swallows HealthKit errors with `try?`. Analytics built on silently-stale recovery data produce wrong insights. Fix error handling and add a data-freshness indicator before shipping any analytics feature. This is prerequisite work, not Phase 1 work.

2. **ACWR framed as injury prediction** — ACWR has weak predictive validity (a 2021 RCT found zero injury rate difference between ACWR-guided and control groups). Never use "injury risk" language; always pair load metrics with recovery context; add informational disclaimer. Design the copy before the UI.

3. **Periodization detection on insufficient data** — Mesocycle detection requires at least 8 weeks / 3 sessions per week. Attempting detection on less data produces noisy labels that destroy user trust. Gate the feature with a "Collecting data: 6 of 8 weeks recorded" placeholder from day one.

4. **PDF/CSV export crashes on real-world data** — SwiftUI Charts degrades above ~10,000 points; PDF rendering loads entire view hierarchies into memory. Stream CSV (OutputStream, 100-row chunks); paginate PDF (12-week max); use pre-aggregated weekly data in PDF charts, not raw daily points. Profile with 6-month synthetic datasets before shipping.

5. **Weekly summary averaging ignores rest days** — Dividing total load by 7 misrepresents training density. Report training days and rest days separately; use training-day denominators for per-session averages; normalize load when mixing sRPE and TRIMP sessions.

## Implications for Roadmap

Based on combined research, five phases are suggested in dependency order:

### Phase 1: Analytics Foundation
**Rationale:** Table stakes that every competitor delivers. All required data already exists — this is visualization and aggregation, not new data capture. Establishes the AnalyticsPipeline infrastructure that all subsequent analytics phases plug into. Highest value-to-complexity ratio in the entire roadmap.
**Delivers:** Multi-week trend charts (Workload tab time range picker), weekly training summary card with week-over-week comparison, recovery-load correlation overlay.
**Addresses:** All three visualization table stakes from FEATURES.md.
**Avoids:** Rest-day averaging pitfall (design aggregation model with training-day denominators before building UI); MainActor blocking (fetch data on main actor, compute on plain structs off main actor from the start).
**Prerequisite (must complete first):** Fix HealthKit error handling in RecoveryPipeline — silent failure corrupts all analytics downstream.

### Phase 2: Data Export
**Rationale:** High user value, medium complexity, and independent of the higher-complexity analytics features. CSV export has zero dependency on analytics pipeline; PDF export requires only WeeklySummaryEngine output. Building export before periodization/fatigue means Pro users get a tangible deliverable while the complex algorithms are developed.
**Delivers:** CSV workout/snapshot export (Pro-gated), PDF weekly report (Coach-gated), share sheet delivery.
**Uses:** Native String building for CSV, UIGraphicsPDFRenderer + ImageRenderer for PDF, UniformTypeIdentifiers, ShareLink.
**Implements:** ExportService static struct.
**Avoids:** HealthKit data leakage (export only composite scores, never raw HRV/RHR values), subscription bypass (check entitlement before computation), memory crashes (stream CSV, paginate PDF, pre-aggregate chart data), PDF appearance mismatch (force light mode for rendering, provide preview).

### Phase 3: Periodization Detection
**Rationale:** High-complexity differentiator that needs AnalyticsPipeline infrastructure from Phase 1 to exist first. Requires the most data (4+ weeks minimum for meaningful results, 8+ weeks preferred). Building third means the pipeline pattern is established and battle-tested before the hardest algorithm is added.
**Delivers:** Automatic training phase labels (Building/Pushing/Tapering) on dashboard and analytics view, phase history timeline.
**Uses:** Accelerate (vDSP.linearRegression) for CTL slope detection over 28-56 day windows.
**Avoids:** Insufficient data garbage output (hard gate: 8 weeks + 3 sessions/week minimum); jargon labels (plain language: "Building" not "Accumulation"; scientific toggle for coaches).

### Phase 4: Fatigue Pattern Analysis
**Rationale:** Most analytically complex feature (lag correlation, pattern recognition). Needs substantial history. Building last among core analytics means all simpler features are shipping while this is developed. Extends recovery-load correlation view from Phase 1 to the algorithmic layer.
**Delivers:** Personalized fatigue pattern insights ("Your recovery drops 2 days after high-volume sessions"), competition-prep suppression mode, behavior tagging with correlation (BehaviorTag model, new SwiftData entity).
**Uses:** FatigueCorrelationEngine with 7-day rolling averages and 1-3 day lag offsets; Accelerate for Pearson correlation.
**Avoids:** Circular correlation (load-recovery correlation is mathematically tautological; only multi-week trends and lag patterns are insights); deload recommendation during planned peaking (suppress recommendations when coach marks competition prep); confounders (frame all outputs as observations, not explanations).

### Phase 5: Onboarding and Coach Value
**Rationale:** Independent of analytics; can be built in parallel or after Phase 4. Analytics views need to exist before onboarding can guide users toward them. Coach PDF report (Phase 2 deliverable) + readiness-adjusted weekly plan + deeper coach-athlete analytics surface constitute a monetization lever for the Coach tier.
**Delivers:** Sport preference capture during signup, first-run guided overlay pointing to analytics, readiness-adjusted weekly session plan (AutoregulationEngine extended to weekly scope), contextual empty states with data-collection progress indicators.
**Addresses:** Readiness-adjusted weekly plan differentiator from FEATURES.md; onboarding gap identified in PROJECT.md.

### Phase Ordering Rationale

- Phase 1 before everything: AnalyticsPipeline infrastructure is the foundation all other analytics plug into. Building it first with the simplest engine (WeeklySummaryEngine) de-risks the pattern before the hard algorithms are added.
- Phase 2 (export) before Phases 3-4 (complex analytics): Export delivers Pro/Coach monetization value independently. It does not need periodization or fatigue data — only weekly summaries (Phase 1). Shipping it early creates revenue while complex R&D continues.
- Phase 3 before Phase 4: Periodization detection is simpler algorithmically (slope detection) than fatigue correlation (lag analysis, pattern recognition). Both need sufficient data, but periodization detection will produce useful output sooner.
- Phase 5 last: Onboarding depends on knowing what the analytics views look like. Building it last means it can reference real screens and real data-sufficiency thresholds.
- Prerequisite work before Phase 1: HealthKit error handling must be fixed first. Silent recovery data corruption is tech debt that becomes exponentially worse once analytics features are built on top of it.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 3 (Periodization Detection):** Phase classification thresholds (CTL slope cutoffs, volume variance minimums) need sport-specific calibration. Existing research (EWMA/ACWR literature) focuses on endurance sports; strength athlete patterns may differ. Consider brief research-phase on classification rules.
- **Phase 4 (Fatigue Pattern Analysis):** Lag correlation implementation with HRV data that has 15-30% day-to-day CV (coefficient of variation) is statistically tricky. False positive rate needs careful threshold design. Consider research-phase on smoothing strategy and minimum insight confidence thresholds.

Phases with standard patterns (skip research-phase):
- **Phase 1 (Analytics Foundation):** Pure aggregation on existing data. No novel algorithms. Standard SwiftUI + Swift Charts patterns. Well-documented.
- **Phase 2 (Data Export):** UIGraphicsPDFRenderer and CSV string building are well-documented Apple patterns. No research needed.
- **Phase 5 (Onboarding):** Standard iOS onboarding patterns. No novel infrastructure.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All recommended technologies are Apple frameworks with official documentation. No third-party library decisions with uncertainty. iOS 18 Swift Charts annotation+scroll workaround is MEDIUM (Apple Developer Forums source, not official docs). |
| Features | HIGH | Validated against multiple live competitor products (WHOOP, TrainingPeaks, HRV4Training, Oura, AthleteMonitoring). Table stakes list is well-supported. |
| Architecture | HIGH | Derived directly from existing codebase conventions in CLAUDE.md and ARCHITECTURE.md. All new components follow established patterns with direct analogues in the codebase. |
| Pitfalls | HIGH | Critical pitfalls (ACWR validity, HealthKit error handling) are grounded in peer-reviewed literature (PMC, systematic reviews) and confirmed existing tech debt (CONCERNS.md). Export memory pitfalls are supported by Apple Developer Forums. |

**Overall confidence:** HIGH

### Gaps to Address

- **Phase classification thresholds for strength athletes:** The EWMA/ACWR literature is endurance-sport-dominated. CTL slope values that constitute "accumulation" vs "intensification" for strength training may differ from the endurance defaults. Address during Phase 3 planning with targeted research.
- **iOS 18 Swift Charts scrolling + annotations conflict:** The workaround (ZStack with two overlaid charts) is documented in Apple Developer Forums but not official docs. Validate during Phase 1 implementation on a real iOS 18 device before committing to the interaction pattern.
- **BehaviorTag data sufficiency threshold:** WHOOP uses 5+ yes/5+ no observations within 90 days for behavior correlation. Whether this threshold is appropriate for Tonus's smaller user base (recreational vs. professional athletes) is unvalidated. Address during Phase 4 planning.
- **Export schema HealthKit compliance:** The exact boundary between "composite score" (allowed in CSV) and "raw HealthKit sample" (not allowed) needs legal/guidelines review before the CSV schema is finalized in Phase 2. RecoveryScore is clearly composite; TSB is clearly derived. The grey area is session-level HRV recorded during workout (not HealthKit-sourced, so probably fine). Validate during Phase 2 planning.

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation: vDSP, UIGraphicsPDFRenderer, ImageRenderer — stack decisions
- PMC/ResearchGate: ACWR systematic review, EWMA sports science literature — pitfall validation
- Codebase: WorkloadCalculator.swift, WorkoutPipeline.swift, RecoveryPipeline.swift, DashboardViewModel.swift — architecture patterns

### Secondary (MEDIUM confidence)
- WHOOP, TrainingPeaks, HRV4Training, Oura product pages and help docs — feature landscape validation
- Swift with Majid (swiftwithmajid.com): Swift Charts scrolling (iOS 17) — chart implementation
- Apple Developer Forums: Swift Charts iOS 18 annotation+scroll conflict — known regression workaround
- Joyfill blog: iOS PDF generation constraints — export pitfall detail

### Tertiary (LOW confidence)
- Medium: Training load wearable limitations — corroborates ACWR pitfall with practitioner perspective
- arXiv: Fatigue monitoring AI paper — HRV confounder list

---
*Research completed: 2026-04-20*
*Ready for roadmap: yes*
