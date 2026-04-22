# Roadmap: Tonus

## Milestones

- ✅ **v1.0 Post-Launch** — Phases 1-4 (shipped 2026-04-22)
- 🚧 **v1.1 App Store Launch** — Phases 5-8 (in progress)

## Phases

<details>
<summary>✅ v1.0 Post-Launch (Phases 1-4) — SHIPPED 2026-04-22</summary>

- [x] Phase 1: App Store Launch (3/3 plans) — completed 2026-04-20
- [x] Phase 2: Analytics & Export (4/4 plans) — completed 2026-04-20
- [x] Phase 3: Training Intelligence (4/4 plans) — completed 2026-04-21
- [x] Phase 4: Onboarding & Polish (3/3 plans) — completed 2026-04-22

</details>

### 🚧 v1.1 App Store Launch (In Progress)

**Milestone Goal:** Get Tonus submitted and approved on App Store -- streaks, notifications, PDF export, metadata, QA, and compliance.

- [ ] **Phase 5: Streaks & Notifications** - Training consistency tracking and weekly push notification summaries
- [ ] **Phase 6: PDF Report Export** - Formatted athlete and coach reports with subscription gating
- [ ] **Phase 7: App Store Metadata** - Optimized listing, keywords, screenshots, and categories
- [ ] **Phase 8: QA, Performance & Compliance** - Systematic testing, performance audit, accessibility, and App Review readiness

## Phase Details

### Phase 5: Streaks & Notifications
**Goal**: Athletes can track training consistency and receive weekly summary notifications that reinforce engagement
**Depends on**: Phase 4
**Requirements**: STRK-01, STRK-02, NOTF-01, NOTF-02, NOTF-03
**Success Criteria** (what must be TRUE):
  1. User sees their current workout streak count on the dashboard
  2. User receives a weekly local notification summarizing sessions, PRs, and streak
  3. User sees a pre-permission screen before the iOS notification permission dialog
  4. User can toggle notifications on/off and configure day/time in Profile settings
**Plans**: TBD
**UI hint**: yes

### Phase 6: PDF Report Export
**Goal**: Athletes and coaches can generate professional PDF reports of training data for review and sharing
**Depends on**: Phase 5
**Requirements**: EXPRT-01, EXPRT-02, EXPRT-03
**Success Criteria** (what must be TRUE):
  1. User can generate a PDF report containing recovery scores, workload trends, and PRs (composite data only, no raw HealthKit values)
  2. Coach can generate a multi-athlete PDF summary report
  3. PDF export is gated behind Pro/Coach subscription; free users retain CSV export
**Plans**: TBD
**UI hint**: yes

### Phase 7: App Store Metadata
**Goal**: App Store listing is optimized for discoverability and conversion with polished screenshots and copy
**Depends on**: Phase 6
**Requirements**: ASO-01, ASO-02, ASO-03, ASO-04
**Success Criteria** (what must be TRUE):
  1. App Store title (30 chars), subtitle (30 chars), and keyword field (100 chars) are populated with targeted terms
  2. App Store description clearly communicates the recovery + load tracking value proposition
  3. Marketing screenshots with benefit-oriented captions exist for 6.7" and 6.5" device sizes
  4. App Store categories and age rating are configured correctly in App Store Connect
**Plans**: TBD

### Phase 8: QA, Performance & Compliance
**Goal**: App passes systematic testing, meets performance targets, and satisfies all App Review requirements for first-submission approval
**Depends on**: Phase 7
**Requirements**: QA-01, QA-02, QA-03, QA-04, CMPL-01, CMPL-02, CMPL-03, CMPL-04, CMPL-05
**Success Criteria** (what must be TRUE):
  1. All user flows, edge cases, and empty states tested with no P0/P1 bugs remaining
  2. Cold launch under 2 seconds, 60fps scrolling, no memory leaks on oldest supported device
  3. VoiceOver navigation works on all screens, Dynamic Type scales correctly, contrast meets WCAG AA
  4. Pre-seeded demo account with 2-3 weeks of data exists and credentials are documented for App Review
  5. All compliance items pass: PrivacyInfo.xcprivacy audit, subscription restore/cancel flows, in-app links resolve, HealthKit usage descriptions are accurate in Review Notes

## Progress

**Execution Order:**
Phases execute in numeric order: 5 -> 6 -> 7 -> 8

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. App Store Launch | v1.0 | 3/3 | Complete | 2026-04-20 |
| 2. Analytics & Export | v1.0 | 4/4 | Complete | 2026-04-20 |
| 3. Training Intelligence | v1.0 | 4/4 | Complete | 2026-04-21 |
| 4. Onboarding & Polish | v1.0 | 3/3 | Complete | 2026-04-22 |
| 5. Streaks & Notifications | v1.1 | 0/0 | Not started | - |
| 6. PDF Report Export | v1.1 | 0/0 | Not started | - |
| 7. App Store Metadata | v1.1 | 0/0 | Not started | - |
| 8. QA, Performance & Compliance | v1.1 | 0/0 | Not started | - |
