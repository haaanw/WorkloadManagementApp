# Phase 17: Cycle Data Foundation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-14
**Phase:** 17-cycle-data-foundation
**Areas discussed:** HealthKit permission flow, Contraceptive status UX, Cycle phase confidence, Data model shape

---

## HealthKit Permission Flow

### Q1: When should menstrual HealthKit permissions be requested?

| Option | Description | Selected |
|--------|-------------|----------|
| Bundled with existing HK auth | Add menstrual types to existing readTypes set. One permission sheet. | ✓ |
| Separate opt-in prompt | Dedicated prompt for cycle data access. More explicit consent. | |
| Progressive — add when relevant | Only request when user interacts with cycle feature. | |

**User's choice:** Bundled with existing HK auth
**Notes:** Simplest UX — one permission sheet covers everything.

### Q2: If user declines menstrual permissions, how should the app behave?

| Option | Description | Selected |
|--------|-------------|----------|
| Silent — no cycle features appear | App works exactly like today. No nudge. | |
| Soft prompt once | One-time Dashboard card explaining benefits, link to Settings. | ✓ |
| You decide | Claude picks based on iOS best practices. | |

**User's choice:** Soft prompt once
**Notes:** None

---

## Contraceptive Status UX

### Q3: Where should contraceptive status be set?

| Option | Description | Selected |
|--------|-------------|----------|
| ProfileView new section | "Cycle & Hormones" section below Training Profile. Visible after HK perms. | ✓ |
| TrainingProfileSheet | Add to cold-start questionnaire. | |
| Standalone settings page | Dedicated "Cycle Settings" page from ProfileView. | |

**User's choice:** ProfileView new section
**Notes:** None

### Q4: How granular should contraceptive type options be?

| Option | Description | Selected |
|--------|-------------|----------|
| Simple binary | Hormonal contraceptive: Yes/No. All hormonal methods treated equally. | ✓ |
| Three categories | None / Hormonal / Hormonal IUD. | |
| Full list | Dropdown with specific types (OC, progestin-only, IUD, implant, etc.). | |

**User's choice:** Simple binary
**Notes:** None

---

## Cycle Phase Confidence

### Q5: How many complete cycles before showing phase info?

| Option | Description | Selected |
|--------|-------------|----------|
| 1 cycle minimum | Show phase after 2 logged period starts. Low bar for quick value. | ✓ |
| 2 cycles minimum | More reliable estimation. | |
| Show immediately with caveats | Estimated phase from first period start with "Low confidence" label. | |

**User's choice:** 1 cycle minimum
**Notes:** Phase 18 needs 3+ cycles for same-phase baselines anyway.

### Q6: What about users with irregular cycles?

| Option | Description | Selected |
|--------|-------------|----------|
| Show cycle day only, skip phase | Display "Day 23" but don't estimate phase. | |
| Show phase with wide uncertainty | Estimate phase with low confidence flag. | |
| You decide | Claude picks based on what works best for Phase 18. | ✓ |

**User's choice:** You decide
**Notes:** None

---

## Data Model Shape

### Q7: Where should contraceptive/exclusion flags live?

| Option | Description | Selected |
|--------|-------------|----------|
| On Athlete model | Optional fields on Athlete. Syncs with existing Athlete sync. | ✓ |
| On TrainingProfile | Add to existing model. Keeps Athlete lean. | |
| New CycleProfile model | Separate @Model. Clean separation but adds complexity. | |

**User's choice:** On Athlete model
**Notes:** These are athlete-level states, not per-snapshot.

### Q8: MenstrualCycleSnapshot — one row per day or one row per cycle?

| Option | Description | Selected |
|--------|-------------|----------|
| One per day | Daily snapshot matching RecoverySnapshot pattern. | ✓ |
| One per cycle | Store cycle start + length, derive daily phase on the fly. | |
| You decide | Claude picks based on existing patterns. | |

**User's choice:** One per day
**Notes:** None

---

## Claude's Discretion

- Irregular cycle handling strategy (show day only vs phase with low confidence)
- CyclePhase estimation algorithm details
- Wrist temperature biphasic shift detection thresholds

## Deferred Ideas

None
