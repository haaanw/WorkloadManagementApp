# Phase 18: Cycle-Aware Recovery Baselines - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-25
**Phase:** 18-cycle-aware-recovery-baselines
**Areas discussed:** Phase bucket granularity, Baseline window + min samples, Confidence gate mechanism, Transition + missing-data fallback

---

## Phase Bucket Granularity

| Option | Description | Selected |
|--------|-------------|----------|
| 2 buckets: follicular vs luteal | Group 5 phases into follicular (early/late foll + ovulatory) vs luteal (early/late luteal). Dense, robust, captures dominant luteal-suppression signal. | ✓ |
| 3 buckets: follicular / ovulatory / luteal | Keep ovulatory separate; nuance but ~2-day phase → noisy. | |
| All 5 phases | Distinct baseline per CyclePhase; ~18 samples/3 cycles spread thin → fragile. | |

**User's choice:** 2 buckets (follicular vs luteal)
**Notes:** Aligns with Altini (individual signal over sparse noise). 5-phase enum retained; bucketing is a mapping at grouping time.

---

## Baseline Window + Min Samples

| Option | Description | Selected |
|--------|-------------|----------|
| Last 3 cycles, min 4 readings/bucket | Equal-weight average over most recent 3 cycles; <4 valid readings → 7-day fallback. | ✓ |
| All available cycles, recency-weighted | Full history with exponential weighting; older cycles less relevant, adds tuning. | |
| Last 2 cycles, min 3 readings | Activates faster but thin and contradicts 3-cycle criterion. | |

**User's choice:** Last 3 cycles, min 4 readings/bucket
**Notes:** Short window → equal weight sufficient.

---

## Confidence Gate Mechanism

| Option | Description | Selected |
|--------|-------------|----------|
| CycleContext.confidence ≥ 0.7 AND no exclusion | Reuse Phase 17 confidence; engine doesn't recount cycles; exclusion/unknown → 7-day. | ✓ |
| Explicit 3+ regular cycles count in engine | Engine independently checks count + regularity; duplicates Phase 17 logic. | |

**User's choice:** CycleContext.confidence ≥ 0.7 AND no exclusion
**Notes:** Single source of truth. Irregular already lowers confidence upstream → auto fallback.

---

## Transition + Per-Bucket Missing Data

| Option | Description | Selected |
|--------|-------------|----------|
| Hard switch + per-bucket 7-day fallback | No blend; baseline changes only on bucket change (gradual); empty bucket falls back independently. | ✓ |
| Blend over N days at gate crossing | Interpolate 7-day → same-phase over ~7 days; smoother but more state. | |
| Borrow adjacent bucket when empty | Estimate empty bucket from neighbor + offset; risky modeling assumption. | |

**User's choice:** Hard switch + per-bucket 7-day fallback
**Notes:** Simplicity + predictability; rejected blend and borrow.

---

## Claude's Discretion

- Data-join mechanism (read-time `RecoverySnapshot` × `MenstrualCycleSnapshot` join vs write-time bucket stamping) — read-time preferred unless query cost concern.
- Exact `RecoveryInput` extension shape / separate computation path.
- Bucket→`CyclePhase` mapping helper location.
- Partial/missing HealthKit day handling in the 4-reading minimum count.

## Deferred Ideas

None — surfacing cycle context to the user is already scoped as Phase 19.
