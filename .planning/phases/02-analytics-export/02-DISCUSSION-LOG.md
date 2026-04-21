# Phase 2: Analytics & Export - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-20
**Phase:** 02-analytics-export
**Areas discussed:** Chart interactions, Weekly summary layout, HealthKit staleness UX, CSV export scope

---

## Chart Interactions

### Time Range Picker

| Option | Description | Selected |
|--------|-------------|----------|
| Segmented control | Persistent 4w/12w/6m buttons above chart — Apple Health style | ✓ |
| Dropdown menu | Compact picker, saves space but adds one tap | |
| Swipe between ranges | Gesture-driven but low discoverability | |

**User's choice:** Segmented control
**Notes:** None

### Data Point Interaction

| Option | Description | Selected |
|--------|-------------|----------|
| Tap for tooltip | Tap point → overlay with exact value + date | ✓ |
| Always show labels | Key points always labeled, can get cluttered | |
| No interaction | View-only, values in summary cards | |

**User's choice:** Tap for tooltip
**Notes:** None

---

## Weekly Summary Layout

### Placement

| Option | Description | Selected |
|--------|-------------|----------|
| Dashboard card | Collapsible section on Home tab below readiness score | ✓ |
| Workload tab section | New section on Workload tab | |
| Dedicated tab/screen | New navigation entry | |

**User's choice:** Dashboard card
**Notes:** None

### Week-over-Week Deltas

| Option | Description | Selected |
|--------|-------------|----------|
| Colored arrows + percentage | Green ↑ +12% / Red ↓ -8% | ✓ |
| Mini sparkline per metric | Tiny 4-week trend line | |
| Text-only description | "Volume up 12% from last week" | |

**User's choice:** Colored arrows + percentage
**Notes:** None

---

## HealthKit Staleness UX

### Stale Data Surface

| Option | Description | Selected |
|--------|-------------|----------|
| Inline warning badge | Yellow icon + "Last updated Xd ago" on affected metrics | ✓ |
| Banner at top | Persistent banner, prominent but naggy | |
| Dim affected metrics | Reduce opacity + subtle label | |

**User's choice:** Inline warning badge
**Notes:** None

### Staleness Threshold

| Option | Description | Selected |
|--------|-------------|----------|
| 24 hours | Athletes typically sync daily | ✓ |
| 48 hours | More lenient, accommodates weekend gaps | |
| User configurable | Flexible but adds complexity | |

**User's choice:** 24 hours
**Notes:** None

---

## CSV Export Scope

### CSV Columns

| Option | Description | Selected |
|--------|-------------|----------|
| Session-level rows | One row per session — compact | |
| Set-level rows | One row per set — granular, large files | |
| Both options | Two export buttons | ✓ |

**User's choice:** Both options
**Notes:** None

### Export Trigger

| Option | Description | Selected |
|--------|-------------|----------|
| Share sheet button | Button → CSV → system share sheet | ✓ |
| Settings > Export | Buried in settings | |
| Long-press on session list | Contextual but limited scope | |

**User's choice:** Share sheet button
**Notes:** None

---

## Claude's Discretion

- Recovery-load correlation chart style
- Weekly summary metrics ordering
- CSV file naming convention
- Exact placement of share sheet button

## Deferred Ideas

None — discussion stayed within phase scope.
