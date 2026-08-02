# Phase S3 status — shadow dual-run instrumentation

Session: S3. Branch `sleep-v2` (verified with `git branch --show-current`). NOT committed
(ground rule 1). Full suite NOT run (ground rule 2). Build + tests via
`-derivedDataPath ~/.tonus-dd-claude-s3`.

## Verification (real output)

`xcodebuild test … -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'
-derivedDataPath ~/.tonus-dd-claude-s3 -only-testing:WorkloadAppTests/SleepShadowTests
-only-testing:WorkloadAppTests/SleepStateBuilderTests
-only-testing:WorkloadAppTests/SleepScoreEngineTests`:

```
Test case 'SleepShadowTests.test_record_roundTrip_fieldsLandWhereSection6NamesThem()' passed on 'Clone 1 of iPhone 17 Pro Max - workload management (27129)' (0.012 seconds)
Test case 'SleepShadowTests.test_syncFence_sleepShadowNightAbsentFromSyncService()' passed on 'Clone 1 of iPhone 17 Pro Max - workload management (27129)' (0.002 seconds)
** TEST SUCCEEDED **
```

Per-suite counts (grep over the full log): SleepShadowTests **18 passed / 0 failed** ·
SleepStateBuilderTests **43 passed / 0 failed** · SleepScoreEngineTests **64 passed /
0 failed** — total **125 / 0**, exit code 0. Full log: scratchpad `s3-test-run-2.log`
(session-local).

Run 1 (`s3-test-run-1.log`) failed to COMPILE only: two call sites in the new
criterion-3 test passed `midpointSD14:` before `proxy:` (argument-order); fixed, no
logic change. No test ever failed at runtime.

## Files

Created:

- `WorkloadApp/Models/SleepShadowNight.swift` — the §6 per-night dual-run record
  (`@Model`, LOCAL-ONLY by omission like `VerdictEvent`/`BaselineState`: no Codable, no
  DTO, absent from `SyncService.swift`, grep-fenced). One row per folded night: night
  measurement (TST / stages / WASO / inBed / session start+end / source), the full v2
  audit (tier, raw component curve values, applied points, need base/tonight + the §4
  credit vector, active + latched profiles, confidence), the v1 arm (v1 sleep minutes +
  `sleepDurationToScore` over them), the state-vector composites (midpoint SD/deviation,
  prior wake h/z, prior-day load/energy z, naps, debt, per-stage q — the H-11 kill-test
  read), and the two nullable §6 join blocks (next-morning HRV/RHR/wellness/sleep-free
  proxy; next-evening RPE/felt-right/verdict-issued), each with a joined-at stamp.
- `WorkloadApp/Services/SleepShadowAnalysis.swift` — pure static struct computing the
  five §6 falsification criteria on demand over stored nights (or plain `NightRecord`
  values in tests). Spearman ρ and the seeded PRNG are REUSED from `ShadowMetrics`
  (`spearmanRho`, `SplitMix64`); the only added machinery is a moving-block resample loop
  (same block scheme as `pairedMAEDifferenceBlockBootstrapCI`, generalized to an index
  statistic) because §6 criterion 1 needs a CI on a Spearman DIFFERENCE, which the
  MAE-difference helper cannot express. Output: `Report` of five per-criterion structs,
  each verdict (`pass` / `fail` / `insufficientData`) + the underlying numbers — a debug
  readout can consume it later; NO UI this phase (PLAN: readout only if trivial —
  skipped; the struct is the deliverable).
- `WorkloadAppTests/SleepShadowTests.swift` — 18 tests (see below).

Modified:

- `WorkloadApp/Models/BaselineState.swift` — one additive field:
  `sleepV2PriorWakeBuffer: [Double] = []` (trailing ≤28 H-22-valid prior-wake hours, the
  priorWakeZ input; inline default ⇒ lightweight migration safe).
- `WorkloadApp/Services/SleepStateBuilder.swift` — S3 pass-through layer:
  `State.priorWakeBuffer` + fold push (capped 28); `validPriorWakeHours` (H-22 logic
  factored so makeInput and fold cannot disagree); `robustZ` (median + MAD ×
  `BaselineEngine.madScaleK`, ≥5 nights, MAD 0 ⇒ nil — H-34) wired into `makeInput`'s
  `priorWakeZ`; `NapCandidate` + `napMinutes(candidates:mainSessionStart:lastSleepEnd:)`
  (H-35); `priorDayLoadZ(dailyTSS:wakeDay:earliestSessionDay:calendar:)` (H-36);
  `priorDayEnergyZ(dailyEnergy:wakeDay:calendar:)` (H-37); `sampleZ`. H-33's "cannot
  fire" doc note replaced with the closure note.
- `WorkloadApp/Services/HealthKitService.swift` — `LastNightSleepDetail.napCandidates`
  (the dominant source's NON-main H-25 session clusters, reduced to
  start/end/unioned-asleep-minutes; selection stays in the pure builder) and
  `fetchDailyActiveEnergyByDay(days:)` (statistics-collection daily `.cumulativeSum`,
  kilocalories, keyed by start-of-day; days without samples ABSENT, never zero;
  `activeEnergyBurned` was already in `readTypes` — no new permission scope).
- `WorkloadApp/Services/RecoveryPipeline.swift` — step 6 now passes the v1 sleep minutes
  into the shadow and calls `runSleepShadowJoins` after it. `runSleepV2Shadow` computes
  the three pass-throughs on folding nights only (naps from the fetch's own candidates;
  load z from a 40-day session fetch day-summed; energy z from the new HK daily-sum
  fetch), feeds them to `makeInput`, and persists the `SleepShadowNight` row via
  `upsertShadowNight` (replacing the S2 print-only log; one save covers fold + record).
  New `runSleepShadowJoins` (internal, `now`/`calendar` injected for tests) +
  `joinMorning`/`joinEvening`. All fetches: date-only `#Predicate` + athlete filter in
  Swift (the optional-relationship trap). All new code sits AFTER the
  `runSleepV2Shadow` marker, so the `BaselineTierFenceTests` live-path fence still holds.
- `WorkloadApp/App/WorkloadApp.swift` — `SleepShadowNight.self` registered in the
  `Schema` (additive).
- `workload management.xcodeproj/project.pbxproj` — registered `SleepShadowNight.swift`
  (Models group) + `SleepShadowAnalysis.swift` (Services group), fresh prefixes
  `DD3801…`/`DD3802…`, all four parts each (PBXBuildFile, PBXFileReference, group child,
  Sources phase); backup at `project.pbxproj.bak-s3`; `plutil -lint` OK. Test file needs
  no registration (WorkloadAppTests is a fileSystemSynchronizedGroup).
- `.planning/v17-field-notes/research-sleep-score.md` — §9.5: H-33 status updated to
  CLOSED-by-S3 (with the dated process guard retained), rows H-34…H-40 added.

FROZEN respected: `SleepScoreEngine.swift` untouched.

## Design choices the brief asked to be reported

### Morning join — resolved ambiguity (H-39)

The brief says "the morning join fills yesterday's row with today's HRV/RHR/wellness".
Taken literally against the S2 fold key that misaligns the outcome: rows are keyed by the
WAKE day, so "today's" live-fetched HRV was measured during TONIGHT's row's night, not
yesterday's — and §6's "next morning" for a night IS that night's wake-day morning.
Implemented instead as the `ShadowAnalyticsService.resolveOutcomes` target-day discipline
(D-03): once a row's wake day has ELAPSED, join it with that wake day's PERSISTED
`RecoverySnapshot` (HRV/RHR/baselines) + `WellnessCheckIn` (wellness). This keeps both the
letter of the test requirement ("fills yesterday only, never today" — today's row is never
joined while its day is in progress) and the outcome alignment, and it captures the day's
final wellness (entered any time that day) instead of the morning nil. Joins stamp even
when the day had no data — absence is the record, no eternal re-scan. Rows older than
yesterday backfill on the same rule (the joined data is day-keyed history, so lateness is
harmless).

### Evening join — design choice

NOT wired into WorkoutPipeline / the VerdictEvent write path (that wiring is invasive:
three separate write sites, and felt-right arrives a day late by design). Chosen: a lazy
deferred join in the same pipeline join pass — once wakeDay + 1 has elapsed (so the
write-once next-day felt-right window has closed), the row joins the wake day's persisted
`WorkoutSession` (highest-`trainingStress` session's RPE) and `VerdictEvent` (existence ⇒
`eveningVerdictIssued`, plus `feltRightRaw`). Zero changes to the event-producing paths;
the values persist onto the row so `SleepShadowAnalysis` reads rows only. A missed
felt-right stays nil forever — absence is the record (the field's own write-once
discipline).

### Sleep-free readiness proxy — derivation (H-38)

No existing sleep-free proxy was found: `PRSReadinessInputBuilder` recomputes FULL
readiness including a sleep z, and no shadow service computes a sleep-free variant. So the
proxy is derived exactly as the brief's fallback prescribes: the EXISTING
`RecoveryScoreEngine.compute` with `sleepDurationMinutes: nil` — its documented
missing-data path renormalizes the remaining weights (HRV 30 / RHR 20 / wellness 25 →
40/26.7/33.3) — and `recentScores: []` so the trend modifier is zero (trend history
contains sleep-bearing recovery scores; letting it in would leak the tested signal into
the outcome). `baseScore` is stored. When NO component scores (no snapshot, no wellness),
the engine's neutral 50 is discarded and the proxy stays nil — a fabricated outcome would
poison criterion 1.

### Criterion mechanics worth knowing

- Criterion 1 runs on Tiers A–C only (Tier D is v1 bit-identical by contract, Tier E
  scoreless — both dilute the comparison; the engine doc already says the analysis
  segments on the tier seam), gated at §6's own ≥60 nights, verdict = pass iff the
  moving-block bootstrap CI on Δρ has lower bound > 0.
- Criterion 2 measures per-stage q noise as the first-difference estimator
  √(Σd²/2m) over within-source consecutive stored nights, against the engine's stage-curve
  q-domain span (0.90, a registered mirror of the private anchors — H-40).
- Criterion 3 is the STATISTICAL arm only (§6's cut also requires HAN's "not actionable"
  report): pass ⇔ the bootstrap CI on ρ(midpointSD14, proxy) excludes zero.
- Criterion 4: bound-hit (exact clamp onto 390/570 within the first 90 days of learned
  need, tolerance 0.5 min) OR alternating-week split-half p75-TST delta > 30 min ⇒ fail;
  the (a)-vs-(b) comparison reports `estimatorBEvaluated: false` (estimator (b) was never
  built — H-19).
- Criterion 5: per-tier + per-source-per-tier counts, modal tier, and
  `stagelessSources` (≥7 nights, zero A/B) — the Whoop/Garmin coverage read; fail means
  "Tier C is that source's modal path", not "v2 dies".

## Invented constants → H-IDs (all in §9.5, all tagged at point of use)

- **H-34** — priorWakeZ: robust z (median + MAD × `madScaleK`) over the 28-night buffer,
  ≥5 nights, MAD 0 ⇒ nil.
- **H-35** — nap selection: non-main H-25 clusters, each ≥20 unioned asleep min (§9.3's
  own trigger), strictly between last main-sleep end and tonight's start; unknown last
  sleep end ⇒ 0.
- **H-36** — priorDayLoadZ: plain z of prior-day TSS sum vs the trailing 28 calendar
  days, zero-filled, requiring observed-history coverage of the full window (40-day fetch
  bound) and variance > 0.
- **H-37** — priorDayActiveEnergyZ: plain z vs PRESENT days of the trailing 28 (≥21
  present; missing ≠ zero; missing prior day ⇒ nil).
- **H-38** — the sleep-free readiness proxy derivation (above).
- **H-39** — join cadence: morning join after the wake day elapses (persisted target-day
  data); evening join one day later (felt-right window); stamps even on nil.
- **H-40** — analysis gates: split-half ≥14/half, stage residual ≥30 pairs, source
  coverage ≥7 nights, and the 0.90 stage-curve q-range mirror constant.
- **H-33** — status updated: CLOSED by S3; the process guard survives in dated form
  (pre-S3 nights carry absent pass-throughs and are segmented out of profile-frequency
  reads).

## Sign-out / account-deletion — inspected, matched

`AppContainer.signOut`/`deleteAccount` explicitly purge ONLY `ExerciseOverride` (because
it is NOT athlete-scoped) plus the raw-UUID-referencing models; the athlete-scoped
local-only models (`VerdictEvent`, `SorenessLog`, `BaselineState`,
`CyclePredictionLog`) have NO explicit purge — every read filters by the current
athlete's id. `SleepShadowNight` is athlete-scoped, so it matches the
`VerdictEvent`/`BaselineState` precedent exactly: no purge code added, documented in the
model header.

## Tests (18 in `SleepShadowTests`)

Round-trip (every §6 field), SyncService grep fence, morning join
(yesterday-only/never-today + H-38 proxy equality + no-data stamps-nil), evening join
(W+2 window, highest-TSS RPE, felt-right, verdict-issued true/false), robustZ
gates+math, makeInput priorWakeZ wiring, fold buffer push + 28 cap + no-push-on-gap,
nap selection, load-z coverage+math, energy-z present-day gate, criterion 1
(constructed pass passes / constructed fail fails; <60 and Tier-D-only ⇒ insufficient),
criterion 2 (noisy q fails, calm passes, thin insufficient), criterion 3 (association
passes, scrambled fails), criterion 4 (split-half 80-min delta fails / agreement passes;
bound hit detected with date), criterion 5 (counts + stageless source flagged + modal
tier).

## Privacy

The new record stores stage minutes and session timing (raw-adjacent, HAN Q2:
device-local): local-only by omission, grep-fenced against `SyncService.swift`, never
Codable. The joins read only already-persisted local rows. The active-energy fetch is
read-only inside the already-authorized scope.

---

## Round 2 — adversarial-review fixes (2026-08-03)

Branch re-verified `sleep-v2`. NOT committed. Full suite NOT run. `SleepScoreEngine`
untouched (FROZEN respected). Every finding verified in source before fixing; none
rejected.

### Majors — all five verified and fixed

- **M1 (wellness leak in the sleep-free proxy) — FIXED.** Verified:
  `WellnessCheckIn.wellnessScore = (sleepQuality+soreness+energy+stress)/20×100` and
  `joinMorning` fed it into the H-38 proxy — sleepQuality was ~8.3% (full input) to 25%
  (wellness-only) of the "sleep-free" outcome. Fix (the preferred form): `joinMorning`
  now keeps the check-in ROW and rebuilds a sleep-free wellness
  `(soreness+energy+stress)/15×100` for the proxy; the composite survives only in the
  `nextMorningWellness` audit field. The composite-only fallback (exclude wellness,
  HRV+RHR only) is documented but unreachable — the join always has the row. H-38 row
  REVISED naming the leak, the fix, and the kill test. New test:
  `test_morningJoin_proxyIdentical_whenOnlySleepQualityDiffers` (sleepQuality 1 vs 5 ⇒
  bit-identical proxies; audit composite differs by 20).
- **M2 (criterion 3 block 7 < dependence length 14) — FIXED.** Verified: criterion 3
  called `blockBootstrapCI` with the default `bootstrapBlockLength = 7` while
  `midpointSD14` is a 14-night rolling SD. New
  `regularityBootstrapBlockLength = 14` (kept simple, per the brief), passed only by
  criterion 3; criterion 1 keeps 7. H-40 row updated (per-criterion block lengths).
  The criterion-3 test did not pin the old width; it now pins the new one
  (`XCTAssertGreaterThanOrEqual(regularityBootstrapBlockLength, 14)`).
- **M3 (criterion 2 passes on one measured stage) — FIXED.** Verified: the old verdict
  passed when `deep.sd` existed and `rem.sd` was nil. New shared `Verdict.partial`
  case (chosen over overloading `.insufficientData` — the report consumer can tell
  "arms that ran were clean, one arm missing" from "no data"; per-stage pair counts
  already report which arm). `.pass` now requires BOTH stages ≥ `minStagePairs`; a
  measured-noisy stage still fails outright. Test:
  `test_criterion2_oneStageMeasured_oneUnmeasured_isPartial_neverPass` (deep 63 pairs
  calm, REM 9 pairs ⇒ `.partial`).
- **M4 (criterion 4 passes when split-half never ran) — FIXED.** Verified: halves below
  `minHalfNights` ⇒ `splitDelta` nil ⇒ old logic passed on the bound arm alone. Same
  `.partial` pattern: `.pass` requires the bound guard (a learned need existed) AND the
  split-half guard (both halves ≥ 14) to have run. The review's counterexample walked in
  `test_criterion4_splitHalfNeverRan_isPartial_neverPass` — note the review's "20-night"
  label yields even=13/odd=7; the stated even=14/odd=7 needs 21 nights, so the test uses
  21 and asserts exactly those counts. (The pre-existing agreement case gained an
  interior `needBase` so both guards run and `.pass` is still exercised.)
- **M5 (false nap + prior-wake artifact from a missed-fold day) — FIXED.** Verified: a
  stale `lastSleepEndDate` let the unfolded previous night pass every nap filter
  (napMinutes ≈ 400 ⇒ false NAP_DAY) and its ~39.5 h span (inside H-22's 48 h) pushed
  into the H-34 buffer. Fix: new `lastSleepEndStalenessMaxHours = 24` — nap candidates
  count only when the stored end is within 24 h of the main session start (else 0 =
  unknown), and the H-34 buffer push is gated by the same rule (a stale prior-wake reads
  as missing, H-22's spirit; `makeInput` scoring keeps H-22's own 48 h bound, per the
  review's scope). Registered as **H-41** (new row, kill test named); noted in the H-34
  row. Test: `test_missedFoldDay_staleLastSleepEnd_noFalseNap_noPriorWakeBufferPush`
  (the Mon-fold → Tue-skip → Wed-fold walk: napMinutes == 0, buffer unchanged, fresh
  ≤24 h span still pushes).

### Minors — all fixed

- **Join-pass cost:** `runSleepShadowJoins` now fetches with
  `#Predicate { $0.morningJoinedAt == nil || $0.eveningJoinedAt == nil }` (athlete
  filter stays Swift-side — the optional-relationship trap); `upsertShadowNight`
  predicates on `wakeDate == wakeDay`.
- **Criterion 2 pairing:** first differences now run WITHIN each source's own
  time-ordered subsequence, pooled — strict two-source alternation no longer yields
  zero pairs (`test_criterion2_pairsWithinEachSourceSubsequence_underAlternation`:
  62 pairs per stage from 64 alternating nights).
- **Regularity verdict:** new `Verdict.statisticalNull` — criterion 3's null outcome;
  `.fail` is documented as unreachable by code alone (§6's cut = absent association AND
  HAN's not-actionable report). Test updated to expect `.statisticalNull`.
- **H-33 boundary:** `SleepShadowNight.schemaVersion: Int = 2` (inline default, additive
  migration) stamps the pass-through wiring generation on every row; H-33 row documents
  the persisted boundary. Round-trip test asserts the default.
- **Determinism test:** `test_analyze_deterministicUnderSeed_differentSeedMovesCI` —
  same seed twice ⇒ identical criterion-1 and criterion-3 CI bounds; different seed
  moves them (on a resample-varying construction).
- **Lower-bound test:** `test_criterion4_lowerBoundHit_registers` — a 390-min clamp hit
  fails with the hit date.
- **Doc nits:** `SleepShadowNight.swift` fence-test pointer corrected to
  `test_syncFence_sleepShadowNightAbsentFromSyncService`; `BaselineState.swift` buffer
  comment now says "additive NON-optional field with an inline `[]` default", not
  "nullable-by-default".
- **Registered deviations (no code change):** Tier-D/E exclusion in criterion 1 and the
  resample-degeneracy guard (≥ half the resamples must define the statistic) each got a
  sentence in the H-40 row.
- **Criterion 2 power (no code change):** the near-zero power of the 0.90 bar is
  recorded in the H-40 row, flagged **⚠ FOR HAN** (tightening §6's bar is HAN's call).

### Verification (real output, run 1, exit 0)

Same command as round 1 (serial, `~/.tonus-dd-claude-s3`). Tail:

```
Test case 'SleepStateBuilderTests.test_tstBuffer_capsAtNinety_andHistoryKeepsCounting()' passed on 'Clone 1 of iPhone 17 Pro Max - workload management (54267)' (0.002 seconds)
Test case 'SleepStateBuilderTests.test_unionMinutes_overlapsCountOnce_disjointSum()' passed on 'Clone 1 of iPhone 17 Pro Max - workload management (54267)' (0.000 seconds)
** TEST SUCCEEDED **
```

Counts (grep over the full log, `s3-review-run-1.log`, session scratchpad):
SleepShadowTests **25 passed / 0 failed** (18 + 7 new) · SleepStateBuilderTests
**43 / 0** · SleepScoreEngineTests **64 / 0** — total **132 / 0**, first run, no
iteration needed.

### Files changed this round

- `WorkloadApp/Services/SleepShadowAnalysis.swift` — Verdict cases (`.partial`,
  `.statisticalNull` + docs), `regularityBootstrapBlockLength`, criterion 2
  within-subsequence pairing + both-stages gate, criterion 3 block + null verdict,
  criterion 4 both-guards gate.
- `WorkloadApp/Services/SleepStateBuilder.swift` — `lastSleepEndStalenessMaxHours`
  (H-41), nap staleness gate, H-34 buffer-push staleness gate.
- `WorkloadApp/Services/RecoveryPipeline.swift` — sleep-free wellness reconstruction in
  `joinMorning` (M1), pending-set + same-day `#Predicate`s, H-38 doc revision.
- `WorkloadApp/Models/SleepShadowNight.swift` — fence-test name fix, H-38 doc revision,
  `schemaVersion` field.
- `WorkloadApp/Models/BaselineState.swift` — buffer comment wording fix.
- `WorkloadAppTests/SleepShadowTests.swift` — 7 new tests, 4 revised (proxy expectation,
  criterion 2 calm both-stages, criterion 3 null rename + block pin, criterion 4
  agreement needBase).
- `.planning/v17-field-notes/research-sleep-score.md` — §9.5: H-38 REVISED, H-40
  extended (blocks, deviations, HAN flag), H-34 + H-33 annotated, H-41 added.

No `.pbxproj` change needed (no new source files; the test target is a
fileSystemSynchronizedGroup).
