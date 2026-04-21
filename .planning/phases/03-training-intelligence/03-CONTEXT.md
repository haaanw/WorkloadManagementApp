# Phase 3: Training Intelligence - Context

**Gathered:** 2026-04-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver personalized training intelligence: periodization detection (auto-detect training phases from load history), fatigue pattern analysis (correlate recovery dips with training spikes), and behavior tagging (user-tagged daily behaviors with recovery impact correlations). These are the differentiating features no competitor provides automatically.

</domain>

<decisions>
## Implementation Decisions

### Periodization Display
- **D-01:** Training phase label (Building / Pushing / Tapering) appears as a subtitle under the readiness score number on the Dashboard hero card — minimal UI, always visible, consistent with DESIGN.md accent-on-score-only rule
- **D-02:** Phase transitions update silently — label changes without notification or animation, user notices on next Dashboard visit

### Behavior Tagging UX
- **D-03:** Behavior tags are added to the existing WellnessCheckIn flow as toggle chips — no new entry points, slots naturally into the daily check-in the user already does
- **D-04:** Ship with 4 default behavior tags: caffeine, alcohol, travel, stress
- **D-05:** Pro users can create custom behavior tags (e.g. 'night shift', 'menstrual cycle') — custom tag management gated behind isPro subscription check

### Fatigue Insights Format
- **D-06:** Fatigue insights presented as natural language cards — plain-English summaries like "Recovery typically drops 2 days after high-volume upper body sessions." Follows existing ReasoningEngine pattern
- **D-07:** Insights section lives on the Recovery tab below current recovery details — new 'Insights' section with scrollable list of insight cards

### Data Sufficiency UX
- **D-08:** When data is insufficient (<8 weeks for periodization, <5 tagged days for behavior correlation), show a circular progress ring + week counter with encouraging text: "Keep logging — periodization insights unlock after 8 weeks of consistent training"
- **D-09:** Behavior correlation waits for full statistical threshold (5+ yes AND 5+ no samples per tag) before showing any results — prevents misleading correlations from small samples. Shows "X more tagged days needed" until threshold met

### Claude's Discretion
- Periodization detection algorithm design (which signals define Building/Pushing/Tapering, rolling window size, sensitivity)
- Fatigue pattern detection algorithm (correlation method, minimum sample size, significance threshold)
- Insight card design details (icon, color coding, ordering, max cards shown)
- Custom tag management UI (how to add/edit/delete custom tags within wellness check-in)
- Behavior tag data model (extend WellnessCheckIn vs separate BehaviorTag entity)
- Progress ring visual style and placement relative to readiness subtitle

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

No external specs — requirements fully captured in decisions above and REQUIREMENTS.md (INTEL-01 through INTEL-07).

### Key Requirement Definitions
- `REQUIREMENTS.md` §INTEL-01–INTEL-03 — Periodization detection, display, and data sufficiency gate
- `REQUIREMENTS.md` §INTEL-04–INTEL-05 — Fatigue pattern detection and insight display
- `REQUIREMENTS.md` §INTEL-06–INTEL-07 — Behavior tagging and correlation

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ReasoningEngine.summarize()`: Already generates human-readable factor explanations — pattern for fatigue insight cards
- `AutoregulationEngine`: Daily training recommendations from recovery+load — new intelligence builds on same inputs
- `AnalyticsEngine`: Weekly summary computation — extend for periodization rolling window analysis
- `WorkloadCalculator`: EWMA for ATL/CTL/TSB — foundation signals for periodization detection
- `WellnessCheckIn` model: Has sleepQuality, soreness, energy, stress, notes — extend with behavior tags
- `DeltaIndicator` component: Shows change arrows — reuse for behavior correlation percentages
- `WeeklySummaryCard`: Collapsible dashboard card pattern — follow for any new card sections

### Established Patterns
- Engines are pure structs with static methods (no state, no dependencies)
- ViewModels are @Observable with async load() methods
- Dashboard uses hero readiness score + card sections below
- Recovery tab shows recovery details + charts
- Subscription gating via `container.subscriptionService.isPro`
- WellnessCheckIn flow already exists in RecoveryViewModel

### Integration Points
- Dashboard hero card: add periodization subtitle under readiness score
- Dashboard hero card: add progress ring when data insufficient
- WellnessCheckIn flow: extend with behavior tag toggle chips
- Recovery tab: add new "Insights" section below existing recovery details
- New engines needed: PeriodizationEngine, FatiguePatternEngine, BehaviorCorrelationEngine
- New model: BehaviorTag (or extend WellnessCheckIn) for storing daily behavior toggles

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches for periodization algorithms, pattern correlation, and tag management UI.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 03-training-intelligence*
*Context gathered: 2026-04-20*
