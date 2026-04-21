# Phase 3: Training Intelligence - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-20
**Phase:** 03-training-intelligence
**Areas discussed:** Periodization display, Behavior tagging UX, Fatigue insights format, Data sufficiency UX

---

## Periodization Display

### Where should the detected training phase label appear?

| Option | Description | Selected |
|--------|-------------|----------|
| Inside readiness hero | Subtitle under readiness score number — minimal UI, always visible | ✓ |
| Separate card below readiness | New card section like WeeklySummaryCard — more room for detail | |
| Badge on Workload tab | Phase label lives on Workload tab near ACWR chart | |

**User's choice:** Inside readiness hero
**Notes:** Follows DESIGN.md accent-on-score-only rule. Keeps Dashboard clean.

### When training phase changes, should the app call attention to it?

| Option | Description | Selected |
|--------|-------------|----------|
| Subtle label change only | Label updates silently — user notices on next Dashboard visit | ✓ |
| One-time insight card | Dismissible card explaining what triggered the change | |
| You decide | Claude picks approach fitting existing UX patterns | |

**User's choice:** Subtle label change only
**Notes:** None

---

## Behavior Tagging UX

### How should users tag daily behaviors?

| Option | Description | Selected |
|--------|-------------|----------|
| Add to wellness check-in | Extend existing WellnessCheckIn with toggle chips | ✓ |
| Quick-toggle on Dashboard | Row of toggle pills at bottom of Dashboard | |
| Standalone behavior log | Separate screen/sheet for behavior logging | |

**User's choice:** Add to wellness check-in
**Notes:** Zero new entry points — behaviors slot into existing daily flow.

### Which default behavior tags should ship?

| Option | Description | Selected |
|--------|-------------|----------|
| Core 4: caffeine, alcohol, travel, stress | Matches requirement spec exactly | |
| Extended 6: + poor sleep, illness | Two more common recovery factors | |
| Core 4 + custom tags | 4 defaults + Pro users can add custom tags | ✓ |

**User's choice:** Core 4 + custom tags
**Notes:** Custom tags gated behind Pro subscription.

---

## Fatigue Insights Format

### How should fatigue pattern insights be presented?

| Option | Description | Selected |
|--------|-------------|----------|
| Natural language cards | Plain-English summaries following ReasoningEngine pattern | ✓ |
| Timeline overlay on charts | Annotate recovery dips on trend chart with markers | |
| Structured table | Table showing pattern → effect → frequency | |

**User's choice:** Natural language cards
**Notes:** Follows existing ReasoningEngine.summarize() pattern.

### Where should fatigue insights live?

| Option | Description | Selected |
|--------|-------------|----------|
| Recovery tab section | New 'Insights' section below current recovery details | ✓ |
| Dashboard card | Collapsible card on Dashboard | |
| Dedicated Insights tab | New tab in tab bar | |

**User's choice:** Recovery tab section
**Notes:** Contextually near recovery data. Dashboard already dense with periodization + weekly summary.

---

## Data Sufficiency UX

### What should users see when data is insufficient?

| Option | Description | Selected |
|--------|-------------|----------|
| Progress ring + week counter | Circular progress showing '3 of 8 weeks' with encouraging text | ✓ |
| Milestone checklist | Checklist showing data milestones with gamification | |
| Hidden until ready | Don't show sections until data threshold met | |

**User's choice:** Progress ring + week counter
**Notes:** Compact, fits under readiness subtitle.

### Should behavior correlation show partial results?

| Option | Description | Selected |
|--------|-------------|----------|
| Wait for threshold | Show 'X more tagged days needed' until 5+ yes AND 5+ no | ✓ |
| Show with confidence label | Show results early with 'Low confidence' badge | |
| You decide | Claude picks based on statistical validity | |

**User's choice:** Wait for threshold
**Notes:** Prevents misleading correlations from small samples.

---

## Claude's Discretion

- Periodization detection algorithm design
- Fatigue pattern detection algorithm
- Insight card design details
- Custom tag management UI
- Behavior tag data model
- Progress ring visual style

## Deferred Ideas

None — discussion stayed within phase scope.
