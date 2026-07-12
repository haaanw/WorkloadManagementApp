# CODEX-G — Free-form exercise entry with hybrid understanding (dogfood blocker)

**Problem:** during strength logging the athlete can only pick from ~40 hardcoded movements. He needs to type ANY movement name (+ optional short description) and have the system understand it well enough that the load/cross-modal/PR engines still work. This blocks real dogfood logging — fix it well.

## Ground rules
- **RUN NO GIT COMMANDS AT ALL.** Orchestrator owns git. Leave edits in the working tree, report.
- Do NOT read `~/.claude/`, `.claude/skills/`, `agents/`.
- The RUNNING app is the UIKit shell (`WorkloadApp/App/AppShell.swift`). The SwiftUI `Views/` tree is DEAD — do not wire UI there.
- Never touch pbxproj (new files under the fs-synchronized test target are auto-picked; for NEW app source files, follow how the shell adds files — the app target lists sources explicitly, so a new app-source file DOES need registration; prefer adding your new resolver as a method/type inside an EXISTING Services file to avoid pbxproj edits, OR clearly report if a new file is unavoidable).

## The engine constraint (the whole reason this is delicate)
Read `WorkloadApp/Services/StrengthLoadEngine.swift` and `WorkloadApp/Services/CrossModalFatigueEngine.swift`. An `ExerciseEntry` / `CustomExercise` with `muscleGroup == nil` is SILENTLY DROPPED from per-muscle load AND contributes ZERO cross-modal regional carry. Therefore: **every exercise the athlete logs MUST end up with a real `muscleGroup` (and `exerciseCategory`).** The resolve flow may never persist a nil-muscleGroup exercise. This is the acceptance bar.

## Read first
`CLAUDE.md`, `CONTEXT.md`, `DESIGN.md`, then:
- `WorkloadApp/Views/WorkoutLog/ExercisePickerView.swift:413-525` — the hardcoded `ExerciseDatabase` (source of truth for the ~40; you'll reuse its list for local matching, but it lives in a DEAD SwiftUI file — consider whether the list should move to a shared location the shell can use; if the shell already reaches it, reuse as-is).
- `AppShell.swift` `ExercisePickerViewController` (~line 9671) + `openExercisePicker()` (~9028) + `allExercises()` (~9725, merges `CustomExercise`).
- `WorkloadApp/Models/CustomExercise.swift` (fields: name, exerciseCategory, muscleGroup, sportType, athlete).
- `WorkloadApp/Models/ExerciseEntry.swift`, `WorkloadApp/Models/Enums.swift` (`MuscleGroup`, its `.region`, `ExerciseCategory`).
- `WorkloadApp/Services/WorkoutLLMImportService.swift` — LIVE parse path → Supabase edge function `parse-workout`, returns exercise_name + exercise_category + muscle_group. This is the "understand the name" mechanism; reuse it.

## Build — the hybrid resolver
Add an "Add custom exercise" / free-text entry to the shell exercise picker (`ExercisePickerViewController`): a name field + optional one-line description. On submit, resolve to `(exerciseCategory, muscleGroup)` via:

1. **Local match first (instant, offline).** Normalize the typed name and fuzzy-match against `ExerciseDatabase` (for the current sportType) + the athlete's existing `CustomExercise`s. Confident match → adopt its category+muscleGroup, done, no network.
2. **LLM on miss.** No confident match → call the parse path (reuse `WorkoutLLMImportService`; the existing `parse-workout` function can parse a one-line "name — description" and return category + muscle_group). Map its response to `MuscleGroup`/`ExerciseCategory`.
3. **Confirm (suggest-and-confirm, per app ethos).** Show the resolved category + muscle group to the athlete to accept or adjust before saving — never silently commit muscle attribution that drives fatigue math. Pre-fill with the match/LLM result.
4. **Manual fallback.** If offline / LLM fails / low confidence → present a quick required picker: `ExerciseCategory` + muscle region/`MuscleGroup`. Required so the engines work (enforce the no-nil-muscleGroup bar).
5. **Persist** as a `CustomExercise` with the resolved muscleGroup+category+sportType. It then becomes a local-match hit next time (step 1) and flows into `allExercises()`, so the engines consume it exactly like a catalog exercise.

## Also
- **Lift the 3-custom-exercise free-tier cap for now** (this is the founder's personal dogfood build). Either remove the cap or gate it so the founder is unlimited; leave a `// TODO: revisit cap for commercial tiers` and report it. (See the cap at `ExercisePickerView.swift:14` / wherever the shell enforces it.)
- Keep it DESIGN.md compliant (UIKitDesign grammar: Rectangle, hairlines, Font.Tokens/ColorTokens equivalents, 8pt grid, no accent misuse, localized strings en+zh-Hans surgical xcstrings inserts).
- Add accessibilityIdentifiers per shell convention; don't break existing ones.

## Tests
- Resolver unit tests (pure logic): local-match hit returns catalog metadata; miss path maps an LLM response correctly; the no-nil-muscleGroup guarantee (a resolved exercise ALWAYS has a muscleGroup); manual fallback produces a valid muscleGroup. Mock the LLM call (don't hit the network in tests).
- A guard test that a persisted `CustomExercise` from this flow is never nil-muscleGroup.

## Gate (run yourself, exact numbers)
Build the app target + `xcodebuild test … -only-testing:WorkloadAppTests -derivedDataPath /tmp/dd-codexG` on iPhone 17 Pro Max sim. 0 failures (pre-existing skips OK). If the simulator service is flaky (it has been), report what you got.

## Report
The resolve flow as built (files, entry point line ranges); how you reused vs extended WorkoutLLMImportService; the no-nil-muscleGroup enforcement points; cap handling; whether any new app-source file (pbxproj) was needed; exact gate results; deviations.
