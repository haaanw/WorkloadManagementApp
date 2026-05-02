# Phase 10: Cold-Start Questionnaire - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md -- this log preserves the alternatives considered.

**Date:** 2026-05-02
**Phase:** 10-cold-start-questionnaire
**Areas discussed:** Questionnaire entry point & flow, Dashboard cold-start display, Switchover UX, Bias capture & FatigueIndex handling

---

## Questionnaire Entry Point & Flow

### Entry Point

| Option | Description | Selected |
|--------|-------------|----------|
| Post-onboarding card | Dashboard card prompts setup, non-blocking, matches existing flow | ✓ |
| Extra onboarding steps | Extend 3-step onboarding to 5-7 steps, guarantees capture but adds friction | |
| Profile screen section | Manual navigation to Profile, lowest friction but easily missed | |

**User's choice:** Post-onboarding card
**Notes:** Non-blocking, user can fill when ready

### Form Layout

| Option | Description | Selected |
|--------|-------------|----------|
| Single scrollable form | One sheet, required at top, optional below divider | ✓ |
| Multi-step pages | One question per page with dot indicators, like OnboardingView | |
| You decide | Claude picks | |

**User's choice:** Single scrollable form

### Dismiss Behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Card reappears each launch | Persistent until completed | ✓ |
| Card appears once | Dismiss permanently, find in Profile | |
| You decide | Claude picks | |

**User's choice:** Card reappears each launch until completed

---

## Dashboard Cold-Start Display

### Estimated Values Display

| Option | Description | Selected |
|--------|-------------|----------|
| Same metrics with 'Estimated' label | Familiar layout, small text annotation | ✓ |
| Separate cold-start card | Different layout, obvious distinction | |
| Dimmed / lower opacity | Subtle, might be missed | |

**User's choice:** Same metrics with 'Estimated' label

### Trend Chart

| Option | Description | Selected |
|--------|-------------|----------|
| Hidden until real data | No chart during cold-start, avoids fake trend | ✓ |
| Flat reference line | Horizontal line at seeded level | |
| You decide | Claude picks | |

**User's choice:** Hidden until real data exists

---

## Switchover UX

### Transition Style

| Option | Description | Selected |
|--------|-------------|----------|
| Silent transition | Label disappears, chart appears, no notification | ✓ |
| Brief celebratory toast | Small non-blocking acknowledgment | |
| Milestone card | One-time congratulations card | |

**User's choice:** Silent transition

### Progress Indicator

| Option | Description | Selected |
|--------|-------------|----------|
| No progress indicator | Keep invisible, user just trains | ✓ |
| Subtle progress text | '3 of 8 sessions logged' somewhere | |
| You decide | Claude picks | |

**User's choice:** No progress indicator

---

## Bias Capture & FatigueIndex

### Bias Visibility

| Option | Description | Selected |
|--------|-------------|----------|
| Completely invisible | Silent capture, no UI | ✓ |
| Optional insight in Profile | Show perceived vs actual after 8 weeks | |

**User's choice:** Completely invisible

### FatigueIndex Cold-Start State

| Option | Description | Selected |
|--------|-------------|----------|
| Show 'Building baseline' text | Text where score normally shows | ✓ |
| Hide section entirely | Remove until cold-start completes | |
| You decide | Claude picks | |

**User's choice:** Show 'Building baseline' text

---

## Claude's Discretion

- Input control types for questionnaire fields
- "Estimated" label styling and placement
- "Building baseline..." text styling
- DashboardViewModel integration approach
- Pipeline architecture for cold-start data path

## Deferred Ideas

None
