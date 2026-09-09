# Sports multi-select — impact note (U6 / U10, for HAN's ruling)

**Written 2026-09-09, R1-product lane. Nothing is built.** HAN asked whether
`Athlete.sportType` should become a multi-select and what that means for the load
math. This note answers the second half so the first can be decided. Every claim
below is read from source, with `file:line`.

---

## 1. The short answer

**No engine reads `athlete.sportType`. Widening it costs the load math nothing.**

Load, fatigue and the verdict all read the SESSION's sport, never the athlete's:

- `CrossModalFatigueEngine.swift:204,212,244,251` — the cross-modal carry that drives
  the verdict maps `session.sportType` through `Constants.betaMap(for:)` to muscle
  regions. Per session.
- `WorkloadCalculator`, `LoadDistributionEngine`, `AutoregulationEngine`,
  `TodayVerdictEngine`, `StrainRiskEngine`, `FatigueIndexEngine` — **zero references**
  to `sportType` of any kind.
- `WorkoutSession.sportType` is set at capture time from the template, the resolved
  plan, the parsed voice log, or the picker — never inherited from the athlete.

So a multi-sport athlete is **already** modelled correctly by the engines today: their
Tuesday court session carries `.teamSport`, their Thursday lift carries `.lifting`, and
the cross-modal fold already sums them into one fatigue budget. That is the product's
whole thesis and it does not consult `athlete.sportType` to do it.

## 2. What `athlete.sportType` actually does

Six consumers, all of them cosmetic, configuration, or transport:

| Consumer | What it uses it for | Behaviour if it became a set |
|---|---|---|
| `ProfileView.swift:48-51` | the picker itself | becomes a multi-select |
| `MovementBankView.swift:152` | default sport for a NEW custom exercise | needs a rule: first sport, or ask |
| `PDFGenerationSheet.swift:23` | the report's title line, `"\(name) - \(sport.displayName)"` | needs a join, or drop the sport |
| `SyncService.swift:457,516-517` | pushes/pulls the `athletes.sport_type` **text** column | **schema change — see §3** |
| `AuthService.swift:23-29` | `sport_type` in the Supabase signup metadata | one value at signup; harmless |
| `MockDataSeeder.swift:68` | seeds `.teamSport` for screenshots | trivial |

`ExercisePickerView`'s catalog filter takes a sport as a **parameter**
(`ExercisePickerView.swift:418`); inside a session it receives the SESSION's sport.
Only the Movement Bank passes the athlete's.

## 3. The one real cost: the sync column

`athletes.sport_type` is a scalar text column. A set needs either a `text[]` column, a
join table, or a delimited string. All three are a migration, and migration 009 is the
cautionary tale here — five `athletes` columns the app pushed were never created, so
**every athlete push was silently rejected PGRST204 for months** because the athlete
push has no Sync Status row. A schema change on this table has to be paired with its
migration in the same release, not queued behind HAN's paste step.

Cheapest correct shape: **keep `sport_type` as the primary sport** (so nothing breaks,
no data is lost, and old clients keep reading a value they understand) and add
`sport_types text[]` beside it. New clients write both; old clients ignore the array.

## 4. There is already a multi-sport field, and it is dead

`TrainingProfile.movementTypes: [String]?` (`TrainingProfile.swift:29`) is exactly this
concept, already in the schema and already synced (`SyncService.swift:1097,1124,1767`).
`TrainingProfileSheet` collects it as `Set<SportType>`
(`TrainingProfileSheet.swift:31,266-273,395`), labelled "Movement types".

**Nothing reads it.** Grep across `WorkloadApp/` returns its own editor, its own model,
and the sync bridge — no engine, no view, no report. So the app already asks a
multi-sport question, already stores the answer, already syncs it, and has never used
it once.

That reframes the decision. There are three coherent options, not two:

- **A · Widen `athlete.sportType` to a set.** Costs the migration in §3, plus a rule
  for the two places that need "one" sport (Movement Bank default, PDF title). Leaves
  `movementTypes` still dead beside it — two fields for one idea.
- **B · Make `movementTypes` the multi-sport field and leave `sportType` as the
  primary.** No migration; the column and the sync already exist. `sportType` keeps
  meaning "the sport you'd name first", which is what the Movement Bank default and
  the PDF title actually want. The Profile edit surface presents both in one section
  once U10's fold lands: a primary picker plus a multi-select beneath it.
- **C · Do neither, and say why.** The engines never needed it. The honest question is
  what the athlete gains from telling us — and today the answer is nothing, because no
  surface consumes it.

## 5. What a reader should not conclude

Widening this field does **not** make the app multi-sport-aware. It already is, at the
session level, which is where the physiology is. The value of the athlete-level field
is entirely downstream — a smarter exercise-catalog default, a report header, and
whatever a future surface decides to do with "what sports do you play". If HAN wants
one of those surfaces, that is the argument for doing it; the load math is not.

## 6. Recommendation

**Option B**, and only if a consumer is named in the same breath. It reuses a field
that already exists and already syncs, needs no migration, keeps `sportType`'s two
legitimate single-value uses honest, and closes a standing oddity — the app has been
asking a question it throws away. Whichever way HAN rules, `movementTypes` should
either gain a reader or be deleted; a synced field nobody reads is how schema drift
starts.

**Not decided here:** whether the multi-select lives in the folded Training Profile
section or in the Athlete Info section beside the primary picker. That is a layout
call and it belongs with U10's fold, which is currently blocked on the R1-fix lane's
claim over `ProfileView.swift` and `TrainingProfileSheet.swift`.
