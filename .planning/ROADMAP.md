# Roadmap: Tonus

## Overview

Tonus is functionally complete through subscriptions (Phase 4) with App Store readiness ~80% done. This roadmap finishes the launch, then builds the analytics depth that makes power users love the app. Phase 1 ships to the App Store. Phase 2 adds table-stakes analytics and data export that every competitor offers. Phase 3 delivers the differentiating intelligence features (periodization detection, fatigue patterns, behavior tagging). Phase 4 adds onboarding polish once the analytics views exist to guide users toward.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: App Store Launch** - Finalize remaining submission tasks and ship v1 to the App Store
- [ ] **Phase 2: Analytics & Export** - Multi-week trend charts, weekly summaries, recovery-load correlation, and CSV export
- [ ] **Phase 3: Training Intelligence** - Periodization detection, fatigue pattern analysis, and behavior tagging
- [ ] **Phase 4: Onboarding & Polish** - First-run guidance and sport preference setup for new users

## Phase Details

### Phase 1: App Store Launch
**Goal**: Tonus is live on the App Store and available for download
**Depends on**: Nothing (first phase)
**Requirements**: STORE-01, STORE-02, STORE-03, STORE-04, STORE-05, STORE-06
**Success Criteria** (what must be TRUE):
  1. App has a production bundle identifier and builds cleanly with it
  2. App Store screenshots exist for 6.7" and 6.1" device sizes showing key screens
  3. Privacy policy, terms of service, and support URLs resolve in a browser
  4. App is submitted to App Store review (TestFlight build uploaded, metadata complete)
**Plans**: 3 plans

Plans:
- [x] 01-01-PLAN.md — Code prerequisites: bundle ID cleanup, pricing update, screenshot mode fix, URL verification
- [x] 01-02-PLAN.md — Screenshot capture and marketing frame generation
- [x] 01-03-PLAN.md — App Store Connect setup, build archive/upload, and submission

### Phase 2: Analytics & Export
**Goal**: Athletes can see how their training load and recovery trend over weeks and months, and export their data
**Depends on**: Phase 1
**Requirements**: PREREQ-01, ANLYT-01, ANLYT-02, ANLYT-03, ANLYT-04, EXPORT-01, EXPORT-02
**Success Criteria** (what must be TRUE):
  1. Stale or missing HealthKit data surfaces a visible indicator instead of silently showing outdated recovery scores
  2. User can view CTL/ATL/TSB trend charts on the Workload tab with selectable time ranges (4w / 12w / 6m)
  3. User can see a weekly training summary showing sessions, volume, avg recovery, load trend, and ACWR zone breakdown
  4. User can view a 28-day recovery-load correlation overlay (recovery line on load bars)
  5. Pro user can export workout history as CSV via the system share sheet, with no raw HealthKit data included
**Plans**: 4 plans
**UI hint**: yes

Plans:
- [x] 02-01-PLAN.md — HealthKit staleness detection + AnalyticsEngine + CSVExportEngine
- [x] 02-02-PLAN.md — Workload tab trend charts with time-range picker + recovery-load correlation
- [x] 02-03-PLAN.md — Dashboard weekly summary card with week-over-week deltas
- [x] 02-04-PLAN.md — CSV export flow with Pro gating and share sheet
### Phase 3: Training Intelligence
**Goal**: Athletes receive personalized insights about their training patterns that no competitor provides automatically
**Depends on**: Phase 2
**Requirements**: INTEL-01, INTEL-02, INTEL-03, INTEL-04, INTEL-05, INTEL-06, INTEL-07
**Success Criteria** (what must be TRUE):
  1. User with 8+ weeks of training history sees a detected training phase label (Building / Pushing / Tapering) on the dashboard
  2. User with insufficient data sees a progress indicator showing how much more data is needed for periodization detection
  3. User sees human-readable fatigue pattern insights correlating recovery dips with training load spikes
  4. User can tag daily behaviors (caffeine, alcohol, travel, stress) and see recovery impact percentages after sufficient data
**Plans**: 4 plans
**UI hint**: yes

Plans:
- [x] 03-01-PLAN.md — BehaviorTag model + 3 computation engines (Periodization, Fatigue, Correlation) + repository + sync
- [x] 03-02-PLAN.md — Reusable UI components (DataSufficiencyRing, BehaviorTagChip, InsightCard, BehaviorCorrelationRow)
- [x] 03-03-PLAN.md — Dashboard periodization integration (phase label + sufficiency ring in hero card)
- [x] 03-04-PLAN.md — Recovery tab insights + morning check-in behavior tags + custom tag management### Phase 4: Onboarding & Polish
**Goal**: New users know exactly what to do after signing up and the app captures their training context
**Depends on**: Phase 3
**Requirements**: ONBRD-01, ONBRD-02
**Success Criteria** (what must be TRUE):
  1. After signup, user sees clear guidance directing them to their first action (log a workout or complete a wellness check-in)
  2. Onboarding flow captures sport type, training frequency, and experience level before reaching the dashboard
**Plans**: 4 plans
**UI hint**: yes

Plans:
- [ ] 04-01: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. App Store Launch | 0/3 | Not started | - |
| 2. Analytics & Export | 0/3 | Not started | - |
| 3. Training Intelligence | 0/3 | Not started | - |
| 4. Onboarding & Polish | 0/1 | Not started | - |
