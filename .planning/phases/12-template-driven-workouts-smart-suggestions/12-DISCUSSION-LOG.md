# Phase 12: Template-Driven Workouts & Smart Suggestions - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-09
**Phase:** 12-template-driven-workouts-smart-suggestions
**Areas discussed:** Template picker flow, Ghost targets display, Dashboard quick-start, Suggestion engine UX

---

## Template Picker Flow

| Option | Description | Selected |
|--------|-------------|----------|
| Picker sheet first | '+' opens template picker sheet with carousel + 'Start blank' | ✓ |
| Inline in ActiveWorkoutSheet | '+' opens blank sheet, optional 'Load template' button | |
| Both paths | Carousel tap + '+' button both exist | |

**User's choice:** Picker sheet first
**Notes:** None

---

| Option | Description | Selected |
|--------|-------------|----------|
| Tap = start session | Carousel card tap opens pre-filled ActiveWorkoutSheet | ✓ |
| Tap = preview, then start | Keep Phase 11 behavior, add 'Start' to preview | |
| You decide | Claude picks | |

**User's choice:** Tap = start session
**Notes:** One-tap quick-start is the Phase 12 goal

---

| Option | Description | Selected |
|--------|-------------|----------|
| Skip picker, go to blank | No picker if zero templates | |
| Show picker with CTA | Always show picker with empty state + 'Start blank' | ✓ |
| You decide | Claude picks | |

**User's choice:** Show picker with CTA
**Notes:** None

---

## Ghost Targets Display

| Option | Description | Selected |
|--------|-------------|----------|
| Placeholder text | Gray ghost text in fields | ✓ (hybrid) |
| Pre-filled values | Real values pre-populated | |
| Label below field | Empty fields with reference text below | |

**User's choice:** Hybrid — placeholder ghost text, but enter/submit fills whole row. Dedicated 'fill all' button fills ALL rows at once.
**Notes:** User wanted both visual reference (placeholder) and practical speed (enter-to-fill + fill-all button). Key insight: ghost values should NOT auto-save if user doesn't interact.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Second line below ghost | Small suggestion text below fields | ✓ |
| Replace ghost with suggestion | Pro users see suggestions as ghost instead | |
| You decide | Claude picks | |

**User's choice:** Second line below ghost
**Notes:** User sees both last-used (ghost in field) and progression suggestion (text below)

---

| Option | Description | Selected |
|--------|-------------|----------|
| Single button, last-used only | One fill button for all users | |
| Two buttons for Pro | Free: 'Fill last'. Pro: 'Fill last' + 'Fill suggested' | ✓ |
| You decide | Claude picks | |

**User's choice:** Two buttons for Pro
**Notes:** None

---

## Dashboard Quick-Start

| Option | Description | Selected |
|--------|-------------|----------|
| Below hero card | After HeroReadinessCard, above metrics | ✓ |
| Above recent sessions | Between training load and sessions | |
| You decide | Claude picks | |

**User's choice:** Below hero card
**Notes:** Most prominent position

---

| Option | Description | Selected |
|--------|-------------|----------|
| Favorites + suggested | Favorites first, then suggestion engine pick | ✓ |
| Recent only | Most recently used templates | |
| Scheduled today | Only scheduledDays matches | |

**User's choice:** Favorites + suggested
**Notes:** None

---

| Option | Description | Selected |
|--------|-------------|----------|
| Hide section entirely | No section if zero templates | ✓ |
| Show CTA card | 'Create a template' card even with zero | |

**User's choice:** Hide section entirely
**Notes:** Dashboard stays clean for new users

---

## Suggestion Engine UX

| Option | Description | Selected |
|--------|-------------|----------|
| Highlighted card in carousel | 'Suggested' label, auto-centered | ✓ |
| Top banner on Workout Log | Separate banner above carousel | |
| Dashboard-only | Suggestion only on dashboard cards | |

**User's choice:** Highlighted card in carousel
**Notes:** Blends into existing carousel flow

---

| Option | Description | Selected |
|--------|-------------|----------|
| Fall back to scheduledDays | Silent fallback, no message | ✓ |
| Show learning message | 'Learning your schedule...' text | |
| You decide | Claude picks | |

**User's choice:** Fall back to scheduledDays
**Notes:** No 'not enough data' message — silent degradation

---

| Option | Description | Selected |
|--------|-------------|----------|
| Day-of-week only | Simple frequency-based | |
| Day + recovery zone | Recovery-aware template swapping | ✓ |
| You decide | Claude picks | |

**User's choice:** Day + recovery zone
**Notes:** User explicitly wanted recovery-aware suggestions

---

| Option | Description | Selected |
|--------|-------------|----------|
| Suggest lighter alternative | Swap to lighter template + 'Recovery-adjusted' note | ✓ |
| Keep usual, add warning | Suggest usual template with recovery warning text | |
| You decide | Claude picks | |

**User's choice:** Suggest lighter alternative
**Notes:** If only one template exists, still suggest it (no alternative available)

---

## Claude's Discretion

- Template picker sheet layout and visual design
- 'Fill last' / 'Fill suggested' button placement and styling
- Ghost placeholder text color/opacity
- ProgressionEngine suggestion text styling
- Dashboard quick-start card visual design
- 'Suggested' and 'Recovery-adjusted' label styling
- How to determine "lighter" template heuristic
- Animation/transition for template pre-fill

## Deferred Ideas

None — discussion stayed within phase scope
