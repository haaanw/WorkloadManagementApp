# Profile IA — review and fold plan (U10)

**Written 2026-09-09, R1-product lane. BLOCKED, not built.**
`ProfileView.swift` and `TrainingProfileSheet.swift` are inside the R1-fix lane's
live claim (`.pair/claude.md` C-r1fix-001, U6-mechanical: sheet header collision +
name-field keyboard dismissal). §4 forbids editing a file under another lane's claim,
so this is the plan that executes on their RELEASE. Sports multi-select is deliberately
NOT here — its own note is `SPORT-MULTISELECT-IMPACT.md`, and HAN rules on it first.

---

## 1. Why editing lives in a modal at all

There is no design reason. `TrainingProfileSheet` is the **cold-start questionnaire**
(D-03/D-08) — the thing that seeds ATL/CTL for a brand-new athlete — and Profile reuses
that whole sheet as its editor. That is why the section reads as a wizard behind a
button instead of a settings block: it *is* a wizard, mounted twice.

The other mount matters and constrains the fix: `DashboardView.swift:323` presents
`TrainingProfileSheet()` as the first-run setup path. **The sheet must survive.** U10
folds Profile's *editing*, it does not delete the sheet.

## 2. The larger fault the modal was hiding

The Profile section summarises **four** fields (`ProfileView.swift:66-78`):

    sessionsPerWeek · avgDurationMinutes · typicalSRPE · weeksAtLevel

The sheet collects **nine** (`TrainingProfileSheet.swift:22-34`): those four plus
`trainingAgeYears`, `scheduleType`, `movementTypes`, `selectedBodyRegions`, and
`injuryNotes`. So five persisted, athlete-authored fields are invisible on the page
that claims to show the training profile, and the only way to discover them is to press
Edit. A fold that copies the current four rows into editable rows would keep that fault
and just remove a tap.

**The fold must surface all nine**, or state which are deliberately not shown.

## 3. Section-logic review

| # | Section | Verdict |
|---|---|---|
| 1 | Athlete info — name, sport, training frequency, experience level | **Keep.** Frequency and experience are engine-dead (`.planning/v18/BUILD-PLAN.md` amendment 4) and left onboarding for exactly this page; Profile is now their only home. That is correct placement, and the reason they must not be trimmed here too. |
| 2 | Training profile | **Fold** (§4). |
| 3 | Exercise library → Movement Bank | Keep. One row, one destination. |
| 4 | Preferences — language, weight unit | **Merge with §9.** |
| 5 | Algorithm validation — morning-probe toggle + footer | Keep. Opt-in, default off, footer explains the cost. Good as built. |
| 6 | Notifications — toggle, day, time | Keep. The day/time rows correctly disable and grey when the toggle is off, and the denied-in-Settings hint is handled. The best-behaved section on the page. |
| 7 | Connected devices → HealthKit permissions | Keep. |
| 8 | Data sync → sync status | Keep. |
| 9 | Measurement → its own screen | **Merge into Preferences (4).** Weight unit sits in Preferences and a separate Measurement section sits five sections below it — two places for one idea, and neither name tells you which holds the unit. |
| 10 | Account — sign out, delete | Keep, last. Correct. |

One ordering note beyond the merge: sections 7 and 8 (Health, sync) are both "where your
data comes from and goes"; they read better adjacent to each other than split by nothing,
which they already are. No change needed.

**Dead strings found, not fixed here:** the coach-era section keys
(`profile.section.myAthletes` et al.) are still in the catalog with no call site
(APP-REORIENTATION R12). They belong to the audit-leftovers sweep, and the catalog is
under the R1-fix lane's claim this window.

## 4. The fold

Replace the four read-only `profileRow`s + `actionButton` with editable rows using the
primitives the Athlete Info section already uses — `editableTextField`,
`editablePicker`, `InstrumentFormRow`. Each row commits on change and saves, exactly as
`athlete.displayName` and `athlete.sportType` do (`ProfileView.swift:43-61`). No Save
button, no Discard, no dirty state — that grammar belongs to the wizard, not to a
settings page.

Rows, in the sheet's own order so the two surfaces stay recognisable:

1. Sessions per week — stepper or picker
2. Average duration — picker (minutes)
3. Typical effort — 1–10 with the `SessionRPEScale` anchor beside it, matching how
   session RPE already reads elsewhere (`8 · Very hard`)
4. Weeks at this level
5. Training age (years) — optional
6. Schedule type — optional
7. Movement types — multi-select (see `SPORT-MULTISELECT-IMPACT.md` §4; this row is
   where option B would land)
8. Body regions + injury notes — one navigation row into the existing detail, not
   inlined; free text and a region grid do not belong in a settings list

**The no-profile state stays a button.** An athlete with no `TrainingProfile` has
nothing to edit in place, and the cold-start questionnaire is a real sequence with a
seeding step at the end. So: profile exists → editable rows; profile absent → the
existing `profile.action.setupTrainingProfile` action opening the sheet. That also keeps
the Home first-run mount honest.

**Seeded values must not silently drift.** `seededATL`/`seededCTL` were computed from
the questionnaire answers at seed time. Editing `sessionsPerWeek` afterwards does not
and should not re-seed — the seed is a historical estimate that later real sessions have
already superseded. The fold writes the answer fields only; `seededAt` and the two
seeded values are untouched. Worth a comment at the write site so a later reader does
not "fix" it.

## 5. Order of work, once the claim releases

1. Merge Measurement into Preferences (smallest, independent).
2. Fold rows 1–6 using the existing primitives; no new components.
3. Row 8 as a navigation row into the sheet's existing region/injury detail.
4. Row 7 only after HAN rules on `SPORT-MULTISELECT-IMPACT.md`.
5. Strings: the sheet's field labels already exist (`profile.field.sessionsPerWeek`,
   `profile.field.avgDuration`, `profile.field.typicalEffort`,
   `profile.field.weeksAtLevel`, `profile.trainingProfile.*`) — the fold reuses them,
   so the append is small and can wait for the catalog to free up.
