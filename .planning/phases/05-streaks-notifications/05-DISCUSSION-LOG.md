# Phase 5: Streaks & Notifications - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-22
**Phase:** 05-streaks-notifications
**Areas discussed:** Streak display & placement, Notification content & timing, Pre-permission screen, Notification settings UI

---

## Streak Display & Placement

| Option | Description | Selected |
|--------|-------------|----------|
| Inside WeeklySummaryCard | Add streak count as a row within the existing weekly summary section | ✓ |
| Standalone badge near hero | Small badge/chip between HeroReadinessCard and MetricsStrip | |
| In MetricsStrip | Add as fourth metric tile alongside HRV, RHR, Sleep | |

**User's choice:** Inside WeeklySummaryCard
**Notes:** Keeps related stats together, no new component needed.

### Zero State

| Option | Description | Selected |
|--------|-------------|----------|
| Hide streak row | Don't show the streak line at all when it's 0 | ✓ |
| Show "Start your streak" | Display a motivational CTA | |
| Show "0 weeks" | Always show with 0 count | |

**User's choice:** Hide streak row
**Notes:** Cleaner, avoids discouraging new users.

---

## Notification Content & Timing

### Content

| Option | Description | Selected |
|--------|-------------|----------|
| Mirror WeeklySummary | Sessions count, PRs, streak count, week-over-week delta | |
| Minimal — streak + sessions only | Short notification with just sessions and streak | |
| You decide | Claude picks the right content density | ✓ |

**User's choice:** You decide (Claude's discretion)

### Timing

| Option | Description | Selected |
|--------|-------------|----------|
| Sunday evening (7 PM) | End-of-week reflection | ✓ |
| Monday morning (8 AM) | Start-of-week motivation | |
| You decide | Claude picks a sensible default | |

**User's choice:** Sunday evening (7 PM)

---

## Pre-permission Screen

### Trigger

| Option | Description | Selected |
|--------|-------------|----------|
| After first workout logged | Natural moment after engagement | |
| During onboarding flow | Ask during initial setup | |
| On first dashboard visit | Show once on first dashboard visit | ✓ |

**User's choice:** On first dashboard visit

### Design

| Option | Description | Selected |
|--------|-------------|----------|
| Full-screen sheet | Modal with value prop and Enable/Not now buttons | |
| Inline card on dashboard | Non-blocking card in feed | |
| You decide | Claude picks based on existing patterns and DESIGN.md | ✓ |

**User's choice:** You decide (Claude's discretion)

---

## Notification Settings UI

| Option | Description | Selected |
|--------|-------------|----------|
| New NOTIFICATIONS section | Dedicated section between PREFERENCES and CONNECTED DEVICES | |
| Inside PREFERENCES | Add within existing PREFERENCES section | |
| You decide | Claude picks based on section density and design guidelines | ✓ |

**User's choice:** You decide (Claude's discretion)

---

## Claude's Discretion

- Notification content density (D-06)
- Pre-permission screen design format (D-07)
- Notification settings section placement in ProfileView (D-08)

## Deferred Ideas

None
