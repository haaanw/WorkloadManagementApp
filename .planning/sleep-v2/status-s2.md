# Phase S2 status — state, fetch, pipeline shadow fold

Session: S2. Branch `sleep-v2` (verified). NOT committed (ground rule 1). Full suite NOT
run (ground rule 2). Build + tests via `-derivedDataPath ~/.tonus-dd-claude-s2`.

## Verification (real output)

Build:

```
** BUILD SUCCEEDED **
```

Test run (`xcodebuild test … -only-testing:WorkloadAppTests/SleepStateBuilderTests
-only-testing:WorkloadAppTests/SleepScoreEngineTests`):

```
passed: 97 failed: 0
** TEST SUCCEEDED **
Test case 'SleepStateBuilderTests…' lines: 34
Test case 'SleepScoreEngineTests…' lines: 64
```

34 SleepStateBuilderTests + 64 SleepScoreEngineTests = 98 tests, 0 failures. (The
97-vs-98 grep count is a log artifact: xcodebuild interleaved a timestamp mid-word into
one `test_stageEWMA_unstagedNightDoesNotFold` "passed" line; the suite verdict is
`** TEST SUCCEEDED **` with zero failing cases.)

Full log: scratchpad `s2-test-run.log` (session-local).

## Files

Created:
- `WorkloadApp/Services/SleepStateBuilder.swift` — the stateless folder (pure static
  struct; injected `Calendar`, no clock, no HealthKit, no SwiftData). Chosen as a NEW
  struct rather than an extension of `BaselineEngine`: BaselineEngine is the generic
  grep-gated robust estimator; the sleep-v2 fold is a domain state machine (source-keyed
  stage EWMAs, midpoint stats, debt, §4 need learning, profile latch) with its own test
  surface. Prequential split mirrors `score`/`step`: `makeInput` reads through t−1 only,
  `fold` advances.
- `WorkloadAppTests/SleepStateBuilderTests.swift` — 34 pure-math tests (no store, no
  HealthKit): EWMA fold math, midpoint SD windows + 14-cap, need gate (28 nights),
  bounds, deadband, hysteresis, freeze-in-chronic, source-change reset + 14-night
  stability recovery, debt accumulation + 6 h cap, SleepInput assembly, profile-latch
  round-trip, W-1 idempotency, plus one end-to-end builder→engine night.

Modified:
- `WorkloadApp/Models/BaselineState.swift` — sleep-v2 sub-state: 19 flattened
  `sleepV2*` fields, all Optional or inline-defaulted (lightweight migration safe),
  documented per field, NO math in the model, still absent from SyncService.
- `WorkloadApp/Services/HealthKitService.swift` — `LastNightSleepDetail` +
  `fetchLastNightSleepDetail()` (iOS 17 `HKCategoryValueSleepAnalysis`, same
  window/descriptor/auth pattern as the existing sleep fetch). Dominant source = bundle
  id writing the most asleep samples (ties by asleep minutes); aggregation is
  dominant-source-only (H-04 same-source discipline; avoids iPhone+Watch double count).
  `asleepUnspecified` counts toward TST here (the v1 fetch ignores it and is untouched).
- `WorkloadApp/Services/RecoveryPipeline.swift` — step 6 `runSleepV2Shadow(…)` after the
  live snapshot upsert: fetch detail → fetch-or-create the athlete's `BaselineState`
  (fetch-all + filter, dodging the optional-relationship #Predicate trap) → W-1
  once-per-wake-day guard → makeInput (t−1) → `SleepScoreEngine.compute` → fold → save →
  one print line. Non-throwing; every error degrades silently
  (`"Sleep v2 shadow error: …"`). Mirror/apply mapping helpers live here so the builder
  stays SwiftData-free.
- `workload management.xcodeproj/project.pbxproj` — registered `SleepStateBuilder.swift`
  (prefix `DD2702…`, all four parts; backup at `project.pbxproj.bak-s2`;
  `plutil -lint` OK). Test file needs no registration (WorkloadAppTests is a
  fileSystemSynchronizedGroup).
- `.planning/v17-field-notes/research-sleep-score.md` — §9.5 rows H-19…H-24 added.

## Shadow-result storage choice (deliverable D)

`RecoverySnapshot` carries NO shadow/diagnostic fields today (inspected: only live
metrics + baselines), so per the deliverable's rule the shadow result is LOGGED via the
existing print pattern and snapshot-side persistence is left to Phase S3
(`ShadowMetrics`-style instrumentation). Log line:
`Sleep v2 shadow: score=… tier=… profiles=… need=…min confidence=…`.

## Invented constants → H-IDs (all in §9.5, all tagged at point of use)

- **H-19** — interim need estimator: p75 of a trailing ≤90-NIGHT TST buffer, gated at
  28 nights. §4's unconstrained-night filter, day-indexed 90-day window, and
  response-based estimator (b) are deferred to S3 (they need history/readiness data the
  carrier does not hold and a constraint signal that is undecidable at morning-run time).
- **H-20** — `isSourceStable` false for the change night + 14 following nights (matches
  H-15's kill-test window).
- **H-21** — stage EWMAs at the sleep signal's 7-day half-life
  (`BaselineConstants.sleepHalfLifeDays`, never retyped); no scoring authority until ≥7
  same-source folds.
- **H-22** — prior-wake sanity window: span outside (0 h, 48 h] reads as missing.
- **H-23** — midpoint SD/deviation need ≥5 buffered nights (mirrors `madMinValid`).
- **H-24** — continuity opportunity window: explicit dominant-source `inBed` samples
  when present, else the dominant source's asleep+awake span; cross-source `inBed`
  never borrowed.

## Spec ambiguities + resolutions (recorded, pending HAN if he disagrees)

1. **First need value at gate-open.** §4's deadband/±10-min hysteresis are defined
   against "the current stored need"; at gate-open none exists. Ruling: the first
   learned value is the bounded estimate itself (snap); ramping from 7.5 h at
   10 min/week would leave a 9 h sleeper mis-targeted for months. Subsequent updates
   are deadbanded + rate-limited as written.
2. **"Freeze need" on source change (§4).** Implemented as: stored need keeps serving
   un-updated, TST buffer cleared, so the 28-night gate re-runs on new-source data —
   the cleared gate IS the freeze, with a natural thaw. The persistent
   `sleepV2NeedFrozen` flag tracks only the CHRONIC_IRREGULAR freeze (§7 Q9); frozen
   weeks do not stamp `needUpdatedAt`, so the first unfrozen due night updates.
3. **`daysSinceRhythmBreak` semantics.** Computed INCLUDING tonight (a first shifted
   night reads 0) so ACUTE_SHIFT can fire on the break night itself; the carried counter
   is "as of the last folded night" and reads +1 for tonight.
4. **Midpoint scalar.** Minutes relative to the WAKE-day midnight (signed, no modular
   wrap at 00:00), so night-to-night SD/median are continuous.
5. **Prequential midpoint stats.** `makeInput`'s SD14/deviation use the PRE-fold buffer
   (score against t−1, the `BaselineEngine.score` discipline; also what "prior
   midpointSD14" in the ACUTE_SHIFT trigger implies). The per-night irregularity flag
   and chronic-exit counter use the post-push SD (the fortnight ENDING that night —
   what "that night's SD14" means in the §9.3 chronic trigger).
6. **S2 state-vector gaps.** `priorWakeZ` (needs a 28-night wake buffer), nap fetch,
   and prior-day load/energy z's are not wired this phase — the builder accepts them as
   pass-throughs and nil never fires a trigger (engine rule). S3 items.

## Privacy

Raw stage minutes and timing history live only in `BaselineState` (local-only carrier,
no Codable, absent from SyncService — the existing grep test still guards) and in the
engine input. Nothing new syncs.

---

## Round 2 — adversarial-review fixes (2026-08-02)

All findings verified against source before fixing; none rejected. NOT committed (ground
rule 1). Full suite NOT run (ground rule 2). Verified serially with
`-derivedDataPath ~/.tonus-dd-claude-s2`.

### Verification (real output)

`xcodebuild test … -only-testing:WorkloadAppTests/SleepStateBuilderTests
-only-testing:WorkloadAppTests/SleepScoreEngineTests
-only-testing:WorkloadAppTests/BaselineTierFenceTests`:

```
Test case 'BaselineTierFenceTests.testEngineDoesNotImportLivePath()' passed …
Test case 'BaselineTierFenceTests.testLiveBaselineStillExists()' passed …
Test case 'BaselineTierFenceTests.testSubstrateNotWiredLive()' passed …
** TEST SUCCEEDED **
```

Counts: SleepScoreEngineTests 64 passed / 0 failed; SleepStateBuilderTests 43 passed
(34 old + 9 new) / 0 failed; BaselineTierFenceTests 3 passed / 0 failed. Total 110/0.
Full log: scratchpad `s2-fix-round-test.log` (session-local).

### Per-finding

- **F1 (fence)** — `testSubstrateNotWiredLive` NARROWED, not deleted: the substrate
  symbols must be absent from `RecoveryPipeline.swift` EXCLUDING the sleep-v2 shadow
  section (everything before the `private static func runSleepV2Shadow` declaration =
  the whole live compute path). The marker's existence is itself asserted so a renamed
  shadow entry fails loudly. Amendment documented in the test comment citing S2 and the
  shadow-only rule.
- **F2+SPEC-1 (session clustering)** — `fetchLastNightSleepDetail` now clusters the
  dominant source's asleep samples by gap: > 90 min starts a new session (H-25;
  exactly 90 bridges), takes the MOST RECENT session, and computes
  TST/stages/midpoint/inBed from that session only; awake and `inBed` samples associate
  to the session by overlap. Pure math lives in the new nonisolated `SleepSessionMath`
  (same file) so the test suite drives it directly.
- **F3+SPEC-2 (double-fold + truncated fold)** — (a) the fold key is
  `startOfDay(detail.sessionEnd)` (wake day), computed in the pipeline, never the run
  date; (b)+(c) `SleepStateBuilder.shouldFold(night:state:now:)`: skip when
  `sessionEnd <= lastSleepEndDate` (session identity) or when the session ended
  < 120 min before now (H-26 completeness hold; `now` injected — builder stays
  clock-free). Proven by
  `test_prematureMidNightFetch_skipped_thenFullNightFoldsLaterSameDay` (02:00 truncated
  165-min read skipped → 09:00 full night folds, buffers hold only the full night).
- **F4 (fetch cost)** — the once-per-day cutoff is now checked BEFORE any HealthKit
  work: cheap SwiftData read of the existing `BaselineState` row → early return when
  `sleepV2LastFoldedDate` is already today; row CREATION also moved after the fetch (no
  empty rows on early exits). Latency decision documented in the function comment (one
  HealthKit query on the day's first run; the F3 wake-day stamp makes same-day
  re-attempts exit at the pre-check).
- **SPEC-3 (unregistered rulings)** — §9.5 rows H-27…H-32 added (see below), each with
  claim / JUDGMENT / basis / kill test; the code comments at each point of use now cite
  the H-IDs instead of the loose "status-s2 ruling" references.
- **F5** — dominant-source tie-break adds the bundle id string as the final sort key
  (deterministic; a flip would trigger a full §4 source reset).
- **F6** — per-stage minutes union their intervals before summing
  (`SleepSessionMath.unionMinutes`); overlapping same-source samples count once.
- **SPEC-7** — a nil-source night no longer folds into the dominant source's stage
  EWMAs (fold step 3 requires a known source equal to `dominantSourceID`) and receives
  no baseline authority in `makeInput` (authority requires the night's source known AND
  matching); the false "same-source by construction" comment is corrected. The night's
  source-agnostic parts (TST/debt/midpoint/history) still fold.
- **SPEC-8** — ruling: DOCUMENT, not rename (persisted-field rename would churn the
  schema for a shadow field). `needFrozen` is documented as the CHRONIC-only freeze
  (read as `chronicFreeze`); the §4 source-change freeze is the cleared-gate mechanism
  (H-28), observable as the re-closed 28-night gate, with the flag false. Documented on
  `State.needFrozen`, at fold step 6, and in H-28.
- **SPEC-9** — deadband boundary tests added: |Δ| = 15 inside (no move), 16 outside
  (moves by the 10-min step).
- **SPEC-6** — §9.5 row H-33 records the S3 pass-through scope cut (priorWakeZ, nap,
  load z's): HIGH_STRAIN_DAY, NAP_DAY, and HIGH_PRESSURE's z-arm cannot fire in the S2
  shadow, and the shadow analysis must not read their absence as evidence.

### New §9.5 rows

H-25 (90-min session gap), H-26 (120-min completeness hold), H-27 (gate-open need
snap), H-28 (freeze-via-cleared-gate on source change), H-29 (break-includes-tonight
counting), H-30 (signed midpoint scalar), H-31 (prequential SD split), H-32 (rolling
≥7-day need cadence), H-33 (S3 pass-through scope cut).

### New tests (9)

`test_needDeadband_boundary_fifteenInside_sixteenOutside`,
`test_nilSourceNight_neverFoldsStageEWMAs_norReceivesBaselineAuthority`,
`test_prematureMidNightFetch_skipped_thenFullNightFoldsLaterSameDay` (F3),
`test_foldGuard_sessionIdentity_blocksRefoldOfSameSession` (F3),
`test_completenessHold_boundary_oneMinuteShortSkips` (F3/H-26),
`test_sessionClustering_twoNightsInOneWindow_mostRecentWins` (F2),
`test_sessionClustering_gapBoundary_ninetyBridges_ninetyOneSplits` (F2/H-25),
`test_sessionClustering_napSplitsFromMainSleep` (F2),
`test_unionMinutes_overlapsCountOnce_disjointSum` (F6).

### Files changed this round

`WorkloadApp/Services/HealthKitService.swift` (clustering + union + tie-break +
`SleepSessionMath`), `WorkloadApp/Services/SleepStateBuilder.swift` (`shouldFold` +
H-26 constant, SPEC-7 guards, SPEC-8/H-ID docs),
`WorkloadApp/Services/RecoveryPipeline.swift` (hoisted pre-check, wake-day fold key,
guard wiring), `WorkloadAppTests/SleepStateBuilderTests.swift` (+9 tests),
`WorkloadAppTests/BaselineTierFenceTests.swift` (narrowed fence),
`.planning/v17-field-notes/research-sleep-score.md` (§9.5 H-25…H-33). No `.pbxproj`
change needed (no new files; `SleepSessionMath` lives in `HealthKitService.swift`).
