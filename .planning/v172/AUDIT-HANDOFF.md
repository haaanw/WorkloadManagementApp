# v1.7.2 Objective 2 — audit handoff

Findings this session could not act on, and why. Two reasons only:

1. **`WorkloadApp/Views/WorkoutLog/` is owned by the parallel logging-UI session.**
   HAN's instruction: write findings here, do not fix them.
2. **A `.pbxproj` edit is needed** (adding or removing a file from the app target,
   which is not file-system-synchronized). HAN serializes those.

Everything else from `.planning/v171-hotfix/AUDIT-2026-08-05.md` was either fixed
this session or re-verified as no longer reproducing — see the verification table
at the end.

---

## 1. Owned by the logging-UI session (`Views/WorkoutLog/`)

### 1.1 `TemplateSharingService` and its three sheets are unreachable AND broken

`ShareCodeSheet`, `ShareImportSheet` and `ShareImportPreviewSheet` are mounted by
nothing — no view presents them, and no deep link routes to them (the app's only
`onOpenURL` handlers are Google Sign-In and the Supabase OAuth callback).

They are also **dead on arrival even if mounted**. This is audit finding M2:
`TemplateSharingService`'s `Decodable` structs declare snake_case property names
(`share_code`, `template_id`, …) while `AppContainer` installs a
`.convertFromSnakeCase` key decoding strategy, so the decoder converts
`share_code` → `shareCode`, finds no matching property, and throws `keyNotFound`.
Every share-code lookup has always failed.

Decision needed from HAN: **fix or retire.** Retiring is cheaper and the surface
has never worked; template sharing is a plausible athlete feature, so it may be
worth keeping. Either way it is one decision, not two — the same defect and the
same reachability gap cover all three sheets and the service.

`InviteService` + `InviteConfirmationSheet` are the coach-era twin of this (same
snake_case defect, also unreachable). Those files are outside WorkoutLog and are
covered in §2.1 instead.

### 1.2 `ExercisePickerView.swift:509` — the optional-relationship `#Predicate` idiom

```swift
predicate: #Predicate { $0.athlete?.id == athleteID },
```

`RecoveryRepository` documents this shape as a SwiftData trap that crashes the
process with SIGABRT rather than throwing, and `backfillSleep` /
`upsertRecoverySnapshot` deliberately avoid it (date-only predicate, athlete
filtered in Swift).

**Measured, do not panic:** a probe against iOS 26.1 with both an owned row and an
orphan row present did NOT crash. The trap is either version-specific or
data-shape-specific. So this is a **consistency** finding, not a live crash — but
the codebase states a rule and 21 sites break it, including this one. See §3.2.

### 1.3 Not findings, recorded so a future sweep does not re-raise them

- `ShareImportPreviewSheet.swift:217` and `TextTemplateImportSheet.swift:299`
  delete rows in a save-failure rollback. They correctly do NOT write a
  `SyncTombstone`: the rows never reached the server.
- `ExercisePickerView.swift:551` / `:603` delete `CustomExercise`, which is not a
  synced entity. No tombstone needed.
- Session deletion in `WorkoutLogView` routes through
  `WorkoutRepository.deleteSession`, which now records a tombstone. Covered.

### 1.4 Not audited

The logging surfaces were read only for the defect classes above. A UI/UX review
of `ActiveWorkoutSheet`, `SetEntryFields`, `WorkoutLogView` and the import sheets
is the parallel session's own lane and was deliberately not duplicated.

---

## 2. Blocked on a `.pbxproj` edit (HAN serializes)

Adding or removing a file in the app target needs a hand-wired `.pbxproj` entry.
Each item below is otherwise ready.

### 2.1 Retire the coach-era invite surface — DELETE 2 files

- `WorkloadApp/Services/InviteService.swift`
- `WorkloadApp/Views/Profile/InviteConfirmationSheet.swift`

Unreachable (nothing presents the sheet), and broken by the same snake_case
decode defect as §1.1 — invite redemption has never worked. Coach mode was
dropped in v1.6 and the app is athlete-only, so there is no future that needs it.

### 2.2 `WorkoutLogViewModel` has no callers — DELETE 1 file

`WorkloadApp/ViewModels/WorkoutLogViewModel.swift` is referenced exactly once in
the whole repo: its own declaration. `WorkoutLogView` does not use it.

**Coordinate with the logging-UI session first** — a logging overhaul might
legitimately want to reintroduce a view model, in which case deleting and
rewriting is churn.

### 2.3 Prune the retired UIKit shell contracts in `AppShellContracts.swift`

Zero references anywhere, left over from the UIKit shell deleted in v1.6:
`AthleteTab`, `CoachTab`, `AppDestination`, `NavigationState`, `TodayViewState`,
`TrainHomeViewState`, `ActiveWorkoutSetRowState`, `InsightsOverviewViewState`,
`RecoveryInsightsViewState`, `LoadInsightsViewState`, `ProfileOverviewViewState`,
`CoachRosterViewState`.

No `.pbxproj` edit needed (the file stays), but **held anyway**: the same file
holds `ActiveWorkoutViewState`, `ExerciseEntryDraft` and `SetDraft`, which the
logging-UI session is very likely to be editing right now. Land it after that
lane closes.

### 2.4 Ten unused components in `CardStyle.swift` — HAN's call, not mine

`InstrumentHero`, `MetricRail`, `ControlTray`, `DisclosureRow`,
`QuietActionButton`, `InstrumentToggle`, `SheetScaffold`, `LoadingStateView`,
`ErrorStateView`, `StaleDataView` have no call sites and no mention in
`DESIGN.md` or `design-system/`.

Deliberately NOT deleted. `IconButton` is in the same unused set but IS documented
(8 references in the design docs), which shows the set is a mix of "leftover" and
"vocabulary defined ahead of use". Deleting design-system primitives on an
engineer's judgement is a design decision; DESIGN.md is HAN's. Also a live
collision risk with any design-adjacent session.

---

## 3. Recorded, deliberately not acted on

### 3.1 Built-ahead surfaces that a naive dead-code sweep flags

`CycleTrackingService`, `REDSRiskEngine`, `CycleSnapshotRepository`,
`CycleFuelingCard`, `CycleStatusStrip`, `REDSAttentionBanner`, `NiggleLogSheet`,
`PreviewData` all scan as unreferenced. They are built-ahead work for the
female-athlete milestone, unmounted by the v1.5.2 self-coached-strength reset —
not accidental dead weight. **Do not delete.** Recorded here so the next sweep
stops at this line instead of re-deriving it.

### 3.2 The optional-relationship `#Predicate` convention is violated at 21 sites

`RecoveryRepository` documents `$0.athlete?.id == athleteId` inside a `#Predicate`
as a process-killing SwiftData trap, and two of its own methods avoid it. Twenty
one other sites still use it, across `RecoveryRepository`, `WorkloadRepository`,
`WorkoutRepository`, `BehaviorTagRepository`, `CycleSnapshotRepository`,
`CyclePredictionLogRepository`, `ShadowAnalyticsService` and
`ExercisePickerView`.

**A probe on iOS 26.1 did not reproduce the crash** (owned row + orphan row, real
repository call, clean pass). So the convention is defensive rather than
load-bearing on the current toolchain, and a 21-site sweep is churn with real
regression risk for no measured benefit. The honest options are: sweep it for
consistency, or amend the comment in `RecoveryRepository` to say the trap is
version-specific. Either is a decision, not a bug fix.

### 3.3 Unused localization keys

Not pruned. `Localizable.xcstrings` is a single large file that the voice-logging
and logging-UI lanes both add keys to; a bulk prune from this session would
conflict on nearly every line. Worth a pass once the parallel lanes close.

### 3.4 M11 — the detail subtitle vs the sparse-data stamp

`HRVDetailView`'s subtitle already renders `windowDays` (the pinch-zoom window), not a
hardcoded 28, so "28-day …" over a "1D ·" stamp is not a stale string: the subtitle
describes the WINDOW and the stamp describes the DATA. Both are accurate and they read
as a contradiction only because they sit two lines apart.

Fixing it means changing user-facing copy, which is HAN's. The options are: drive the
subtitle from visible data, drop it when the window is sparse, or reword the stamp.

### 3.5 L9 — two different "week"s on one card

`WeeklySummaryCard` shows a rolling-168-hour summary (`DashboardViewModel` builds it from
`now - 7 days`) beside a streak counted in ISO weeks (`StreakEngine`). Confirmed, and
deliberately NOT changed.

Moving the summary to ISO weeks would make "this week" mean the same thing in both places,
but it also compares a PARTIAL current week against a COMPLETE previous one, so every delta
reads negative on a Monday. That is a nocebo hazard the design system explicitly guards
against, and trading a quiet inconsistency for a daily false alarm is a product decision,
not a bug fix.

### 3.6 L6 — sleep stage intervals admitted unclipped

Real, and deliberately NOT changed. It affects the sleep-v2 SHADOW's inBed/WASO figures,
and that shadow is mid-way through a pre-registered ≥6-week dogfood window (started
2026-08-03). Changing the reduction now perturbs the data the §6 criteria will rule on.
Fix it after the window closes, or the window has to restart.

### 3.7 L7 — the cycle biphasic shift averages samples, not days

Real, and inside `CycleTrackingService`, which is unmounted built-ahead code (§3.1). Fix it
when the female-athlete milestone opens, alongside whatever else that surface needs.

### 3.8 RecoveryLoadChart's tooltip is hardcoded English

Found while fixing M9. `TooltipBubble` renders `"Load: … | Recovery: …"` as a Swift string
literal, so a zh-Hans athlete scrubbing the correlation chart reads English. NOT fixed here
only because it needs two new keys in `Localizable.xcstrings`, and that file is being
appended to by the voice-logging and logging-UI lanes right now — a merge on a large JSON
is worse than the defect. Two keys, one commit, once those lanes close.

### 3.9 L8 — the push has no watermark

Every row of every entity uploads on every cycle. Still true, still a real cost
that grows with history. Fixing it means a per-entity `updatedAt` watermark and a
`gt` filter on the push, which is a design change to the sync contract rather than
a bug fix — out of scope for an audit pass.

---

## 4. Verification table — the 31 ranked findings

Every one was re-checked against source before being touched. "Fixed earlier"
means one of the eight 1.7.1 UAT rounds already closed it.

| # | Finding | State |
|---|---------|-------|
| H1 | "7-day avg" over raw HRV samples | Fixed earlier (`HRVDailyStats` is wired everywhere) |
| H2 | Live sleep keyed on run date | Fixed earlier (wake-day key + orphan backfill) |
| H3 | Sticky red sync rows | Fixed earlier (`run()` records both outcomes) |
| H4 | `.single()` on `pullTrainingProfile` | Fixed earlier; **fenced** this session |
| H5 | Template pull rebuilds every group | Fixed earlier (`groupsJson` comparison) |
| H6 | **Deletion resurrection** | **Fixed** — `SyncTombstone` + migration 010 |
| H7 | `bootstrapAthlete` zombie sign-out | **Fixed** — three-way `BootstrapOutcome` |
| H8 | Streak collapses every Monday | Fixed earlier |
| H9 | "Last used in 0 seconds" | Fixed earlier (no `.relative(` remains) |
| H10 | RecoveryView never re-evaluates today | Fixed earlier (scenePhase + `NSCalendarDayChanged`) |
| M1 | Athlete pull restores 4 of 11 fields | **Fixed** — `SyncService.apply` + migration 009 |
| M2 | Invite / share-code snake_case decode | **Handoff** — §1.1, §2.1 (retire-or-fix decision) |
| M3 | behavior_tags DDL, link, churn | **Fixed** — in-place reconcile, link synced, migration 011 |
| M4 | `training_profiles` PK conflict | **Fixed** — `onConflict: "athlete_id"` |
| M5 | No UNIQUE(athlete_id, date) | **Fixed** — `DailyRowIndex`, half-open keys, migration 011 |
| M6 | `DateOnly` freezes the time zone | **Fixed** — `CalendarDay`, zone read per call |
| M7 | Body temp / VO2 max unbounded + no staleness | **Fixed** — bounded fetch windows |
| M8 | Same-day re-run self-drift | Does not reproduce (v1.7.1 algorithm stage 1) |
| M9 | RecoveryLoadChart defects | **Fixed** — symbol, zero-load guard, x-domain, both-series scrub |
| M10 | Load trend renders over nothing | **Fixed** — insufficient-data message |
| M11 | "28-day" subtitle over sparse data | **Recorded** — §3.4 (copy decision) |
| L1 | Unconstrained axis tick granularity | **Fixed** — `ChartAxisTicks.dayStride` on six charts |
| L2 | Duplicate y-labels, no `chartYScale` | **Fixed** — bounded y-axis stop count |
| L3 | `daysAgo` counts 24h blocks | **Fixed** — calendar days |
| L4 | Dashboard date label goes stale | **Fixed** — `NSCalendarDayChanged` |
| L5 | Dead HealthKit surface, unused `.stepCount` | **Fixed** |
| L6 | Stage intervals admitted unclipped | **Recorded** — §3.6 (shadow window is live) |
| L7 | Cycle biphasic shift averages samples | **Recorded** — §3.7 (unmounted surface) |
| L8 | Push has no watermark | **Recorded** — §3.9 |
| L9 | Two different "week"s on one card | **Recorded** — §3.5 (nocebo trade-off) |
| L10 | Doc drift in chart comments | **Fixed** — no-op `.chartLegend` removed |

---

## 5. SQL for HAN

Three new migrations, none applied. Each is idempotent and safe to re-run.

- `Supabase/migrations/009_v172_athlete_profile_columns.sql`
- `Supabase/migrations/010_v172_sync_tombstones.sql`
- `Supabase/migrations/011_v172_daily_identity_and_behavior_tags.sql`

Run them in that order. 009 is the most urgent: without it, **every athlete
profile push is rejected PGRST204 and silently** — the athlete push has no Sync
Status row, so unit, ACWR method, load metric, max HR and date of birth have never
reached the server.
