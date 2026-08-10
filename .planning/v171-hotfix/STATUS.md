# v1.7.1 — status log

**Authoritative status for the v1.7.1 release.** `.planning/STATE.md` is a v2.0 milestone
document last written 2026-06-14 and already carries its own correction banner; do not read
release state out of it.

Version **1.7.1 (build 19)**. Branch `main`. **Nothing pushed. Nothing sent to App Store
Connect.** Suite at last run: **977 passed / 0 failed / 2 skipped** (979 total; the baseline
before this work was 895).

## Origin

HAN's on-device dogfood report, 2026-08-05 (screenshots: Sleep trend, Apple Health Sleep, Sync
Status). Six issues reported, then a full similarity audit, then a HAN-directed algorithm
update. Reviewed throughout by a multi-model panel (Codex `gpt-5.6-sol` + Grok) via `/multi`,
with every load-bearing claim verified in source before acting.

## Commits, oldest first

| Commit | What |
|---|---|
| `7abf6cb` | Dogfood hotfix — sleep misread, sync DATE decode, chart domain + pinch, flat option cells |
| `8f52682` | Audit follow-up — nap/night pick, glance chart domains, pull hardening |
| `3b87a63` | HRV daily morning-window stats, sleep wake-day keying, sync trust, streak, midnight reload |
| `82a49b5` | Algorithm stage 1 — daily readiness inputs, today excluded from its own baseline |
| `3bf40b5` | Algorithm stage 2 — recovery estimator v2 dual-run, dark |
| `89b04ab` | Recovery pipeline + shadow test coverage, and a SwiftData predicate crash fix |
| `2d5ab65` | `BaselineCheckpoint` — persisted baselines that survive gaps and late data |
| `51fa08c` | Wire `BaselineCheckpoint` into the shadow arm |
| `9ef558f` | Held-out outcome capture — blinded morning probe, grip, respiratory rate |

## What HAN reported, and where each landed

1. **Sleep read 12h 45m vs Health's 5h 19m** — FIXED. The live fetch summed raw samples from
   every source over a ~48 h window; iPhone and Watch each wrote the night and the prior
   night's tail joined in. Now routed through the clustered dominant-source reduction that
   already existed for the sleep-v2 shadow.
2. **One giant purple block in the chart** — FIXED, on the detail screens *and* the glance
   cards, which carried the identical defect one tap above.
3. **Sync errors** — FIXED client-side. Postgres `DATE` columns could not be decoded; pushes
   were also silently day-shifting. Workouts needs `Supabase/migrations/007_v171_sync_repair.sql`
   run by HAN.
4. **"IN 0 SEC" timestamps** — FIXED, and the same defect was found and fixed on template cards.
5. **Flatter UI** — DONE, iteration 1 (option cells lost their raised plates and debossed wells).
6. **Charts not truly interactive** — DONE: pinch-to-zoom, 7–90 day window.

## Audit (`AUDIT-2026-08-05.md`)

35 verified findings across four axes. The urgent four were fixed in `8f52682`, including a
**regression the hotfix itself introduced**: the clustered fetch picked the most recent sleep
cluster, so an afternoon nap became "last night". 31 findings remain ranked in that file.

## Algorithm update (`../v171-algorithm/PLAN.md`)

The survey's key finding: **the robust estimator was already built and switched off.**
`BaselineEngine` (EWMA half-life, MAD scale, σ floor, Huber-clipped fold, Altini CV, honest
confidence) reached production only through one caller that re-folded it from scratch;
`BaselineState`'s 27 generic fields were never written. So this was wiring and validation, not
new math.

- **Live now:** `ReadinessInputReducer`. HRV reduces by morning window; **RHR by calendar day
  with no hour filter**, because Apple computes RHR as a daily aggregate and refines it through
  the day. Today is excluded from its own baseline and its own trend. HRV is written
  authoritatively so a stale midday value cannot sit on the row. Coverage is stated
  ("Based on 3 of 4 signals").
- **Dark:** `RecoveryShadowEngine` + `RecoveryShadowDay`. The v2 anchor is held fixed at 70 for
  z = 0 so divergence is attributable to the estimator alone; both stored scores are pre-trend.
- **Persistence:** `BaselineCheckpoint` — days older than a 14-day seal horizon fold into a
  saved checkpoint, everything newer is replayed each run. Gaps are a non-event; late data
  inside the horizon is absorbed; idempotent by recomputation. Its load-bearing test is the
  equivalence property (checkpoint + tail == full replay).
- **Dropped after review:** persisting via the forward-only guard, which would have made a
  missed or corrected day permanently unabsorbable.

## Validation (`../v171-algorithm/VALIDATION-PROTOCOL.md`)

Pre-registered before any data exists. Four held-out outcomes on `RecoveryShadowDay`, all
source-fenced against scoring: blinded morning readiness probe (primary), optional grip
strength, overnight respiratory rate, wrist temperature. Wellness, felt-right and next-day HRV
were each rejected with reasons recorded. Design: score only the days the two arms **disagree**.

## Open — HAN

1. ~~**Run `Supabase/migrations/007_v171_sync_repair.sql`**~~ — **DONE 2026-08-10** (HAN ran it
   in the SQL editor, success). Green Workouts row still unverified on device — see UAT below.
2. **On-device UAT:** sleep number vs Apple Health next morning; Sync Status all green after
   the SQL; pinch behaviour; the flat option cells (iteration 2 candidates are `ReadoutWell`
   and the `FormField` focus well, still debossed).
3. **Turn on Profile → Algorithm validation** to start the outcome clock. The gate needs ~40
   blinded days with ≥12 disagreement days, so starting early matters.
4. **Archive + upload 1.7.1 (19)** when satisfied. Push is also outstanding — nothing has left
   this machine.

## Incident 2026-08-10 — screenshot-mode wipe on HAN's device (RESOLVED, fixes owed)

The main shared Xcode scheme had `SCREENSHOT_MODE` **enabled** (left on since the 1.7 store
re-shoot), so a device run from Xcode wiped the local store and seeded the mock athlete
("Alex Chen", random UUID, nil `supabaseUserId`). Every push then failed RLS (unknown
athlete_id) while every pull returned empty and **painted the row green** — Sync Status merges
push and pull into one per-entity status, so pull success masks push failure. Diagnosed via
Supabase SQL forensics + `devicectl` container pull; the wipe lived only in the un-checkpointed
WAL, so the pre-wipe store was restored to the device byte-for-byte and verified. Scheme
argument now disabled (committed with this change). Full artifacts in the session scratchpad.

Separate finding from the same forensics, both halves HAN-confirmed 2026-08-11: the device
store was born 2026-08-04 because **HAN reinstalled the app that day** — the pre-reinstall
workout history was deleted with the old container, and the server never had workouts (their
push was broken until 007, run 2026-08-10). That history is unrecoverable unless an iCloud/
Finder device backup from before 08-04 still exists. The qq account `2583710743@…` is the
**App Review demo account** HAN created for Apple (its 112 recovery rows through 08-03 line
up with the build-18 review window) — not a real user; keep it working for future reviews.

All four pre-ship guards were **BUILT the same day** (suite **985/0/2**, +8 `SyncGuardTests`
incl. two source fences):

- **SCREENSHOT_MODE is now simulator-only** — every screenshot branch in AppRouter compiles
  under `#if DEBUG && targetEnvironment(simulator)`; a device launch can never wipe again.
- **Per-direction sync status** — `SyncTimestampStore` keys failures by entity AND direction;
  a pull success can no longer clear a push failure, and the push failure wins the row display.
- **Sign-out unsynced-data guard** — `hasPushRisk` (push failure or identity fault) gates the
  wipe behind a destructive confirmation alert in ProfileView.
- **Push identity guard** — every public SyncService seam verifies local athlete ↔ session
  user before the network; a refusal is recorded as an `IdentityFault` and rendered as a
  banner on SyncStatusView (en + zh-Hans strings added).

One latent test fragility was exposed and fixed while landing this:
`VerdictSurfaceActivationTests.test_productionOptIn…` depended on the test host's HealthKit
query THROWING (fast) rather than returning empty — the pipeline's authoritative today-write
clears seeded signals in the empty case, and which case you get depends on host-app dashboard
timing. The test now re-asserts the seeded today-signals post-load with the hazard documented.
The proper long-term fix — a HealthKit protocol seam so pipeline tests are hermetic — joins
the audit list.

## Open — engineering

- 31 ranked audit findings, highest: deletion resurrection (needs tombstones + schema),
  athlete-field pull gaps, `bootstrapAthlete` zombie sign-out.
- The **recovery score's HRV input is fixed, but the estimator swap is unproven** — v2 drives
  nothing until the protocol's gates pass.
- Wake-relative HRV windowing (rather than the fixed 11:00 heuristic), deferred until sleep-v2
  is trusted daily.

## Notes worth keeping

- A **latent shipped crash** was found while writing tests: `RecoveryRepository` traversed the
  optional `athlete` relationship inside a `#Predicate`, which SIGABRTs the process rather than
  throwing. Both sites now use a date-only predicate with the athlete filtered in Swift.
- **A design fence caught a real mistake and the code moved, not the fence.**
  `BaselineTierFenceTests` defines the sanctioned shadow region as everything after
  `runSleepV2Shadow`; new shadow code had been placed above that line.
- The Codex CLI failure in this session was a stale `NODE_OPTIONS` preload, not Codex —
  `NODE_OPTIONS= codex` works. `run-parliament.sh` needs an explicit model on bash 3.2.
