# v1.7.1 patch 2 — decisions and the review that produced them

HAN picked six items from `AUDIT-2026-08-05.md`. Each design went through a multi-model
panel (`/multi`): **Grok** (opening statement + a second adversarial pass on the refined
design) and **Codex** (`gpt-5.6-sol`, independent review). The chair (this session)
verified every load-bearing claim in source before deciding — the panel is advice, not a
vote that binds.

> Tooling note: the Codex CLI first failed with `MODULE_NOT_FOUND`. Cause was a stale
> `NODE_OPTIONS` preload pointing at a deleted temp file, not Codex. `NODE_OPTIONS= codex …`
> works. The parliament script also has a bash-3.2 bug (`model_args[@]: unbound variable`)
> when no explicit model is passed — pass one.

## 1. HRV — day-bucketing, and the time-of-day question HAN asked

**HAN's question:** should HRV samples taken at different times of day carry different
weights, since waking HRV and midday HRV "mean different things"?

**Answer: he is right that they differ, and the correct response is to EXCLUDE the daytime
readings rather than weight them.** Both panel members converged on this independently, and
the literature agrees:

- Morning/waking measurement is what readiness protocols standardise on; it sits after
  sleep's restorative effect and is the state most predictive of the day ahead. Overnight
  measurement reflects the PREVIOUS day's load more than today's readiness.
  ([Morning vs nocturnal HRV](https://pmc.ncbi.nlm.nih.gov/articles/PMC11541970/),
  [Altini on measurement timing](https://medium.com/@altini_marco/thoughts-on-heart-rate-variability-hrv-measurement-timing-morning-or-night-b92bd5495bc8))
- Daytime HRV is dominated by posture, food, caffeine, stress and training — it measures the
  day, not recovery capacity. Consumer guidance is explicit that mixing measurement contexts
  produces confusing, inconsistent data.
- **Weighting was rejected for a specific reason:** no validated weighting kernel exists to
  defend. Coefficients would be invented, and they would HIDE the context-mixing rather than
  remove it. An athlete-facing app cannot defend numbers it made up.

**Shipped:** `HRVDailyStats` reduces raw samples to one value per calendar day — the median
of that day's samples before 11:00 local (`DayBucketer.bucketMorningWindow`, which already
existed and was never called). Gaps are never imputed.

Amendments the panel forced, all shipped:
- **Baseline excludes the day being compared to it**, and is gated at ≥3 prior mornings.
  Without this, one day of history gives a baseline equal to the reading itself — a
  permanent, false "0% — on baseline". (Grok #3, Codex both flagged.)
- **Never silently empty.** A midday-only wearer used to see a wrong-but-present number;
  going blank would read as a broken app. `Availability` distinguishes `noSamples` from
  `noMorningSamples` from `building(days:)`, and the screen says which.
- **Mean, not median, for the 7-day figure** — the day values are already medians, and mean
  matches `RecoveryScoreEngine.computeBaseline` so the two surfaces cannot disagree.

**Deferred deliberately:** wake-time-relative windowing. The principled key is the athlete's
own wake time (the clustered sleep session already carries `sessionEnd`), and the fixed
11:00 boundary genuinely mis-serves shift work, pre-midnight sleep onset, and waking after
11:00. Both members said not to wire it now: it would bind the HRV series to sleep-clustering
completeness, naps, and open nights. Copy therefore says "morning", never "your wake time".

**Known gap, stated plainly:** `RecoveryPipeline` still feeds the recovery SCORE from
`fetchLatestHRVWithDate()` — the latest raw sample, unbounded window. This patch fixes the
displayed statistics, not the score input. Both members said re-baselining the score does not
belong in a hotfix. **This is the next decision for HAN.** Also worth recording: Apple writes
SDNN, while most readiness research uses standardised LnRMSSD — this reduction is defensible
noise control, not validation of the algorithm.

## 2. Sleep — wake-day attribution, with the orphan guard

Sleep now lands on the day the athlete WOKE. Opening the app at 00:30 no longer writes the
previous morning's night onto the new day as "last night".

**Grok's critical catch, adopted:** gating alone would have made things WORSE. If the app's
first open after a night falls on a later calendar day, the night would belong to no row at
all — a silent loss, worst for a user with one night of history. `RecoveryRepository
.backfillSleep` therefore files such a night on its wake-day row, but only when that row
already exists and has no sleep yet. It never fabricates a row (a phantom row would carry an
invented recovery score) and never overwrites a measured value. It does not rescore that day
— the baselines that produced the stored score are gone, so the number the athlete saw stands.

Codex preferred no write-back at all as the more conservative hotfix. The chair sided with
Grok because losing a night is a data loss, whereas a narrow backfill is bounded and testable.

**Not shipped (Grok raised, deferred):** a "provisional / sleep not in yet" cue on a score
computed before the night has landed. Real, but it is UI scope beyond HAN's list.

## 3. Sync trust

- **`run()` seam** — success is now recorded where failure is. Pipeline- and UI-triggered
  pushes could previously only record a failure, so one flaky moment painted a row red and no
  amount of successful syncing cleared it. Ratified by both.
- **`.single()` → array + `limit(1)`** — zero training-profile rows is an ABSENCE, not an
  error. It was pinning a permanent red row AND, through `hasAnyFailure`, forcing a full
  push+pull on every foreground. Ratified by both.
- **The `>=` LWW change was REJECTED — by both members, and the chair agrees.** My original
  plan was to widen the guard so equal timestamps skip. Both pointed out that an equal
  timestamp does not imply an equal payload (the encoder truncates fractional seconds, so
  same-second edits on two devices collide), and skipping on equality could strand a real
  remote change. **Shipped instead:** compare the canonical `groupsJson` before the
  destructive rebuild. Identical content means nothing to rebuild; different content still
  applies. This removes the every-sync cascade-delete of every ExerciseGroup without touching
  conflict semantics.

## 4. Relative time — one renderer

`RelativeTimeStamp` floors `abs(interval) < 60` to "just now". Codex's amendment: the floor
must be on the ABSOLUTE interval, so a timestamp slightly in the future (clock skew, a server
stamp written ahead) does not render a forward count. Used by Sync Status and both template
sites that showed "Last used in 0 seconds".

## 5. Streak — an unfinished week is not a missed week

Current week has a session → count it. Current week empty → start at last week. Current AND
last both empty → 0.

Grok argued the grace is too generous (it holds the number through a full rest week) and
wanted it limited to Monday–Tuesday. Codex ratified the full-week form. **Chair sided with
Codex and with HAN's stated requirement ("it should be consistent"):** the number is TRUE —
the athlete did train those consecutive weeks — and it never claims the current week. It
drops only when a week actually completes untrained. A mid-week cutoff would introduce a
second, unexplainable rule.

## 6. Recovery tab midnight

`scenePhase == .active` plus `NSCalendarDayChanged` both call the same idempotent
`loadData()`, matching the Dashboard/WorkoutLog idiom. Ratified by both.

## Verification

Build green. Full unit suite **914 passed / 0 failed / 2 skipped** (916 total; was 895 —
19 new tests across `HRVDailyStatsTests`, `StreakEngineGraceTests`, `RelativeTimeStampTests`).

## Still open for HAN

1. **The recovery score's HRV input** (see §1) — the score still reads the latest raw sample.
2. Wake-time-relative HRV windowing, once sleep-v2 is trusted daily.
3. The remaining audit backlog in `AUDIT-2026-08-05.md`: deletion resurrection (needs
   tombstones + schema), athlete-field pull gaps, `bootstrapAthlete` zombie sign-out.
