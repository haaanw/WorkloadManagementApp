# v1.7.1 algorithm update — the input and baseline layer

HAN, 2026-08-05: fix the recovery score's HRV input, **as part of the algorithm-system
update**, as the next to-do for v1.7.1.

## What the survey found (verified in source, not assumed)

1. **The live recovery score reads one raw HealthKit sample per signal per day.**
   `RecoveryPipeline:39` takes `fetchLatestHRVWithDate()` — whatever sample HealthKit wrote
   last, which for an Apple Watch user is frequently a midday reading.
2. **Its baseline is a flat mean of the last 7 non-nil VALUES** (`RecoveryScoreEngine
   .computeBaseline:270`) — not 7 days: with gaps the window silently stretches. n=1 is
   accepted, producing a baseline equal to the reading (ratio 1.0 → score 70).
3. **The good estimator is already built, tested, and switched off.** `BaselineEngine`
   (441 lines, 15 tests) does EWMA with per-signal half-life, MAD×1.4826 robust scale with a
   σ floor, Huber-clipped update (detect on the raw innovation, fold the clipped one),
   prequential z that returns nil until it has earned an opinion, Altini dispersion-ratio CV
   with hysteresis, and a multiplicative confidence. It reaches production only through
   `PRSReadinessInputBuilder`, which re-folds it **from scratch on every call**.
4. **`BaselineState` has 27 generic fields for exactly this — never written.** Only the 19
   `sleepV2*` fields are live. `DayBucketer.foldBuckets`, which owns the W-1 idempotency
   guard, is dead code.
5. **As of today the charts and the score disagree.** `HRVDailyStats` (v1.7.1 patch 2) gives
   the HRV screens a morning-window daily median baseline; the score still uses the flat mean
   of raw samples. Two different "baselines" one tap apart.

So the work is **not new math**. It is: give the estimator the right input, persist its
state, and prove it before it drives anything.

## The split that governs this patch

"Fix the HRV input" is two changes with very different risk, and they ship differently.

**(i) The input series — a DEFECT, ships live.** Feeding the score a random midday sample as
"today's HRV" is wrong by the same argument that fixed the charts: daytime HRV reflects
posture, food, caffeine and stress, not recovery. Replacing it with the morning-window daily
value is a correction, not a re-baselining, and it makes the score and the chart agree.
Same treatment for RHR (`fetchRestingHRHistory` and `DayBucketer` both already exist, both
unused).

**(ii) The estimator — an ALGORITHM CHANGE, ships dark.** Replacing the flat 7-mean with
robust EWMA + personal z moves every number the athlete has ever seen. The user-approved
2026-05-30 scope is explicit: everything behind the shadow harness, master activation flag
OFF until parity gates pass. That ruling stands.

## Scope

### A. Daily inputs, one per signal (LIVE) — **SHIPPED**
- `ReadinessInputReducer` (new, pure) owns the reduction. **Amended after panel review: the
  two signals do NOT reduce identically.** HRV keeps the morning window because SDNN is a
  momentary measurement whose time of day changes its meaning; **RHR gets NO hour filter**
  (`DayBucketer.bucketAllDay`) because Apple computes resting heart rate as a daily aggregate
  and refines it through the day, so its timestamp does not mark a morning reading and an
  hour filter would keep or drop it essentially at random. Both reviewers raised this
  independently.
- `RecoveryPipeline` step 1 consumes today's daily value instead of the latest raw sample.
  When today has no morning value, the component is **nil** — the engine already
  renormalizes over present components, which is the honest behaviour.
- The baseline series switches from `compactMap` over snapshot values to the same daily
  series, so "7-day" means seven days.
- **Today excluded from its own baseline** (audit F5) **and from its own trend series** —
  the second exclusion was added on panel input: the trend modifier is an autoregression on
  the engine's own past output, and `recentScores` included today's row after the day's
  first run, so a same-day re-run moved the score with no new physiology.
- **Coalesce fix (ship-blocker, both reviewers).** `upsertRecoverySnapshot` coalesced
  `hrvSDNN ?? existing`, so on a day whose earlier run had stored a midday value, passing nil
  left that number on the row while the score deliberately ignored it — the row would display
  a reading the score never used. HRV is now written authoritatively when the pipeline did the
  reduction itself. RHR keeps the coalesce, because Apple's refinement means a transient
  absence is not evidence the day has no resting heart rate.
- **Coverage is stated, not silent.** A day with no morning HRV legitimately scores on three
  signals. `RecoveryResult.contributingSignalCount` + `ReasoningEngine.coverageNote` surface
  "Based on 3 of 4 signals" on the Dashboard, so a change in measurement COVERAGE cannot be
  mistaken for a change in physiology — the specific harm the panel named.

### B. Persist the baseline substrate — **DROPPED after panel review**
Both reviewers rejected it for this patch and the chair agrees. The current ephemeral
re-fold over recent snapshots is deterministic, reconstructable, and naturally absorbs
corrected or late HealthKit history; persistence via the W-1 monotonic guard
(`day <= lastBucketedDate` → skip) makes a missed or later-corrected day permanently
unabsorbable, and it adds migration risk on an existing install for no capability we need.
Nothing else in this plan depends on it. Revisit only as a versioned, replayable cache.

### C. Dual-run the score (SHADOW)
- Compute a v2 recovery score alongside v1 every run: same components and weights, but HRV
  and RHR scored from the persisted personal z + robust σ rather than the flat-mean ratio.
- Persist one record per day to a **new local-only model** (`RecoveryShadowDay`), carrying
  both scores, the z's, the confidence, the CV level, and the tier — mirroring
  `SleepShadowNight`.
- Report-only summary; **no code flips the gate**. HAN decides after reviewing parity, the
  same discipline `CrossModalShadowGate.validationSummary` already enforces with a
  source-level no-mutation test.

### D. Tests
- `RecoveryPipelineTests` — the orchestrator has **no test file today** (632 lines,
  including the wake-day gate and the orphan backfill just added). This is the largest
  coverage hole in the algorithm stack.
- Daily-value input path, today-excluded baselines, fold idempotency, and the shadow record.

## Explicitly NOT in this patch

From the locked 2026-05-30 scope — milestone-sized, each its own build:
- the per-muscle strength-load model,
- demoting ACWR out of the live decision matrix,
- splitting readiness and strain-risk in the LIVE surface (the PRS path already does this
  inside the verdict),
- learned fusion weights (the locked scope killed per-user Kalman/logistic learning as
  statistically unsound on consumer data — use fixed sign-constrained weights).

## Honesty notes to carry into the copy

- Apple writes **SDNN**; most athlete-readiness evidence uses standardised **LnRMSSD**. The
  reduction is defensible noise control, not validation of the algorithm.
- The 11:00 morning boundary is a heuristic. Wake-relative windowing is the principled key
  and is deferred until sleep-v2 is trusted daily.
- The trend modifier is an autoregression on the engine's **own past output**, not on
  physiology. Out of scope here; worth naming before anyone calls it a physiological trend.
