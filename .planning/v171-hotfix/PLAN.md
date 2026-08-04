# v1.7.1 hotfix — HAN dogfood report 2026-08-05

Source: HAN's on-device report (screenshots: Sleep trend screen, Apple Health Sleep,
Sync Status screen). Live build: v1.7 (18), in review/TestFlight. Branch: `main`.
This file organizes every reported issue, its root cause, and its status.

## Issues, root causes, status

### 1. Sleep time reading wrong (BIGGEST) — FIXED
- **Report:** App shows "Last night 12h 45m" (and 7-day avg 12h 45m); Apple Health
  shows 5h 19m for the same night (Aug 4).
- **Root cause:** the LIVE fetch `HealthKitService.fetchLastNightSleepWithDate()`
  summed raw sample durations from EVERY source over a ~24–48 h window: iPhone +
  Watch both write the night (double count), overlapping segments each counted in
  full, and the prior night's post-midnight tail joined the total. The correct
  reduction (dominant source, 90-min gap session clustering, per-stage interval
  union) already existed for the sleep-v2 shadow (`fetchLastNightSleepDetail`) but
  never fed the live number.
- **Fix:** the pipeline now fetches the clustered detail ONCE; the live score, the
  snapshot, and the shadow all consume it. `fetchLastNightSleepWithDate` delegates
  to the detail fetch; the dead `fetchLastNightSleep()` was deleted.
  `asleepUnspecified` now counts toward the live number (stage-less sources).
- **Residue:** snapshots recorded before the fix keep their inflated
  `sleepDurationMinutes` (history is not rewritten). Today's snapshot self-repairs
  on the next pipeline run. Shadow rows folded pre-fix carry the old v1 arm.

### 2. Sleep trend chart = one giant purple block — FIXED
- **Root cause:** no explicit `chartXScale` anywhere; Swift Charts infers the
  x-domain from the data, so one night = one day-wide bin = a bar filling the
  entire plot.
- **Fix:** `SleepDetailChart` and `HRVDetailChart` now pin an explicit trailing
  window domain (default 28 days, ending start-of-tomorrow). One night renders at
  1/28 width with a real axis.

### 3. Sync errors (Workouts "Sync error"; Recovery / Wellness / Training Load
"Data format error") — FIXED CLIENT-SIDE + SQL FOR HAN
- **Root cause (the three "Data format error" rows):** those three tables have
  Postgres `DATE` columns. PostgREST returns `"2026-08-05"`; the client's
  `.iso8601` decoder rejects any bare date → every PULL threw `DecodingError`.
  Exact correlation: every entity with a DATE column failed, every entity without
  one succeeded. Push appeared fine but was day-shifted: a start-of-day timestamp
  from UTC+8 casts to the PREVIOUS UTC day server-side.
- **Fix:** a `DateOnly` codec (encodes/decodes `yyyy-MM-dd` as the LOCAL calendar
  day) on the date-only fields of `RecoverySnapshotRow`, `WellnessCheckInRow`,
  `WorkloadSnapshotRow`, `AthleteRow.dateOfBirth`; plus a lenient client decoder
  (fractional seconds + bare-date fallback). The first full push repairs the
  day-shifted server rows (upsert by id).
- **Workouts "Sync error":** not a decode error — most likely PGRST204 (columns
  `total_volume` / `external_load` / `internal_load` / `training_stress` etc. were
  never created by any committed migration). Two measures: (a)
  `Supabase/migrations/007_v171_sync_repair.sql` — idempotent, HAN runs it in the
  SQL editor; (b) the Sync Status screen now shows the underlying error text under
  a failed row, so the next on-device look is a diagnosis, not a guess.
- **Also fixed:** stale-timestamp classification — `EncodingError` now maps to
  "Data format error"; `pullAthlete`'s silent failure still logged only (zombie
  bootstrap risk noted for later).

### 4. "IN 0 SEC" stamps on Sync Status — FIXED
- **Root cause:** `RelativeDateTimeFormatter` phrases a sub-second interval with
  FUTURE tense ("in 0 sec"), and the view never re-rendered: `Date()` was captured
  in the body and the success timestamps lived in un-observable UserDefaults.
- **Fix:** sub-minute floor → localized "Just now" (en) / 「刚刚」 (zh-Hans);
  a 30 s `TimelineView` tick; the timestamp store keeps an observable mirror.

### 5. Flatter UI on option boxes (sport column, training-frequency days) — DONE (iteration 1)
- **Report:** the raised light boxes inside darker debossed wells (Profile sport /
  frequency pickers, onboarding day grid) read as heavy; HAN wants flat.
- **Fix (HAN-approved deviation from the v6 relief grammar on option lists):**
  `MachinedOptionCell` dropped its `.raised` plate → flat cell with a hairline
  outline (selected = 1 pt ink outline + filled dot + medium face);
  `OptionChannel` dropped its `.debossed` well; the hand-rolled debossed bays in
  Onboarding (language) and TrainingProfileSheet (body regions) dropped too; the
  SignUpView sport grid lost its surface fills (outline only).
- **Open for iteration 2 (needs HAN's eyes):** `ReadoutWell` (the collapsed value
  pill) is still debossed; ditto `FormField` focus wells. Flatten those too if the
  first pass reads right on device.

### 6. Charts not truly interactive — pinch-to-zoom — DONE (v1)
- **Fix:** two-finger pinch on the HRV and Sleep detail charts retunes the visible
  window between 7 and 90 days (apart = fewer days, together = more history). Data
  feeds widened to 90 days (single fetch; the 28-day glance windows derive from
  it, glance cards unchanged). The header subtitle and the `ND ·` stamp track the
  live window.

## Verification
- Interim build (data + chart fixes): BUILD SUCCEEDED (see session log).
- Full suite run + final build: recorded in the session summary / commit message.
- On-device UAT (HAN): sleep number vs Apple Health next morning; Sync Status all
  green after running 007 SQL; pinch behavior; flat option cells look.

## Ship list for HAN
1. Run `Supabase/migrations/007_v171_sync_repair.sql` in the Supabase SQL editor.
2. Install the build, force a sync (pull-to-refresh on Sync Status), read the
   detail line on any still-red row.
3. Check tomorrow's sleep number against Apple Health.
4. Judge the flat option cells; order iteration 2 if wanted.
