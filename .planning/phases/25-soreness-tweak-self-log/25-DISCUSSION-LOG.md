# Phase 25 — Discussion Log

**Date:** 2026-05-30
**Mode:** discuss (default), all 4 gray areas selected by user.

Human-reference audit trail. NOT consumed by downstream agents (they read 25-CONTEXT.md).

## Area 1 — Niggle log granularity
- **Options presented:** (a) region+severity+type+limited-training+note [rec], (b) region+severity only, (c) single severity no region.
- **Selected:** (a) — full lightweight entry. → D-01, D-02, D-03.
- **Why:** functional-impact ("limited training") flag is the signal that separates real breakdown from DOMS, which is exactly the validation target.

## Area 2 — Validation outcome label
- **Options presented:** (a) graded niggle severity 0–10 max-in-window [rec], (b) binary breakdown event, (c) both, (d) reuse existing .pain only.
- **Selected:** (a) — new graded `.niggleSeverity` outcome; keep `.pain` untouched. → D-04, D-05, D-06.
- **Why:** dense + graceful on sparse consumer data; fits Phase 24 MAE/Spearman/calibration. Binary deferred (rare-positive instability).

## Area 3 — Entry point / friction
- **Options presented:** (a) Dashboard on-demand + post-workout nudge [rec], (b) Dashboard on-demand only, (c) folded into morning check-in.
- **Selected:** (a). → D-07, D-08, D-09.
- **Why:** post-workout is the highest-signal capture window for training tweaks; no daily nag preserves the optional ethos.

## Area 4 — Injury-count wiring
- **Options presented:** (a) functional: type∈{pain,tweak} AND (limited-training OR severity≥cut) [rec], (b) severity-only threshold, (c) limited-training only.
- **Selected:** (a). → D-10, D-11, D-12, D-13.
- **Why:** excludes routine soreness so DOMS doesn't inflate fatigue; honest framing. recentWellnessScores fetch (14d) confirmed as non-gray wiring fix.

## Deferred ideas captured
Binary breakdown outcome; niggle resolution/healing tracking; per-niggle trend UI; daily reminder (rejected for v1).
