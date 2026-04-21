# Phase 2: Analytics & Export - Context

**Gathered:** 2026-04-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Add multi-week trend charts, weekly training summaries, recovery-load correlation, and CSV data export. Also fix HealthKit silent error handling (PREREQ-01) which is a prerequisite for all analytics features — stale data corrupts downstream insights.

</domain>

<decisions>
## Implementation Decisions

### Chart Interactions
- **D-01:** Time range picker uses a segmented control (4w / 12w / 6m) above trend charts — matches Apple Health style, instant switch
- **D-02:** Tap data points for tooltip overlay showing exact value + date — standard Swift Charts chartOverlay pattern

### Weekly Summary Layout
- **D-03:** Weekly summary lives as a collapsible card section on the Dashboard (Home tab), below the readiness score — visible daily without navigating
- **D-04:** Week-over-week deltas shown as colored arrows + percentage (green ↑ +12% / red ↓ -8%) next to each metric

### HealthKit Staleness UX
- **D-05:** Stale HealthKit data surfaced via inline warning badge — yellow warning icon + "Last updated Xd ago" on affected metrics. Non-blocking, user still sees last known values
- **D-06:** Staleness threshold is 24 hours — if last HRV/sleep reading >24h old, mark stale. Athletes typically sync daily from wearables

### CSV Export Scope
- **D-07:** Two CSV export options: "Session Summary" (one row per workout session: date, sport, duration, RPE, volume, load, ATL, CTL, ACWR) AND "Detailed Sets" (one row per set: date, exercise, set#, reps, weight, RPE)
- **D-08:** Export triggered via share sheet button on Profile or Workload tab → generates CSV → system share sheet (AirDrop, Files, email)
- **D-09:** CSV must exclude raw HealthKit data per Apple guidelines — only composite scores (recovery score, not raw HRV/RHR values)

### Claude's Discretion
- Recovery-load correlation chart style (overlay approach, colors, axis scaling)
- Weekly summary metrics ordering and emphasis
- CSV file naming convention
- Exact placement of share sheet button (Profile vs Workload tab)

</decisions>

<canonical_refs>
## Canonical References

No external specs — requirements fully captured in decisions above and REQUIREMENTS.md (PREREQ-01, ANLYT-01 through ANLYT-04, EXPORT-01, EXPORT-02).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Swift Charts already used in 7 files (WorkloadView, RecoveryView, HRVTrendChart, SleepTrendChart, ClientDetailView, HRVDetailView, SleepDetailView)
- `WorkloadCalculator` engine has EWMA computation for ATL/CTL/TSB — data layer exists
- `RecoveryScoreEngine` computes composite recovery scores — can feed correlation view
- `HealthKitService` fetches HRV, RHR, sleep — needs staleness check added
- `ColorTokens` for zone colors (green/yellow/red) — reuse for delta arrows

### Established Patterns
- Charts use Apple's Charts framework with `BarMark`, `LineMark`, `AreaMark`
- ViewModels are `@Observable` with async `load()` methods
- Engines are pure structs with static methods — new analytics calculations follow this pattern
- Subscription gating via `container.subscriptionService.isPro`

### Integration Points
- DashboardView: insert weekly summary card section
- WorkloadView: add segmented time range control + tooltip overlay to existing charts
- New recovery-load correlation view on Workload tab or Dashboard
- ProfileView or WorkloadView: add export button
- RecoveryPipeline: add staleness check before computing scores

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches for chart rendering, CSV generation, and staleness detection patterns.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 02-analytics-export*
*Context gathered: 2026-04-20*
