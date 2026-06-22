---
phase: 38-ux-wave-1-workout-log-fast-entry-carry-forward-set-defaults-
plan: 01
subsystem: workout-log
tags: [ux, swiftui, fast-entry, set-stepper, i18n]
requires:
  - SharpTextFieldStyle
  - CardStyle/Spacing
  - WeightFormatter
  - ColorTokens
  - Font.Tokens
provides:
  - SetStepperDouble / SetStepperInt always-visible ± numeric control
  - stepper-primary SetEntryRow (carry-forward, collapsible RPE)
  - ExerciseEntryCard repeat-last + dashed add-set affordances
affects:
  - WorkloadApp/Views/WorkoutLog/ActiveWorkoutSheet.swift
tech-stack:
  added: []
  patterns:
    - "concrete Double/Int stepper variants (avoids generic Binding<Optional> friction)"
    - "ghost baseline via existing SetDraft.target* fields (no schema change)"
key-files:
  created:
    - WorkloadApp/Components/SetStepper.swift
  modified:
    - WorkloadApp/Views/WorkoutLog/ActiveWorkoutSheet.swift
    - WorkloadApp/Resources/Localizable.xcstrings
    - "workload management/workload management.xcodeproj/project.pbxproj"
decisions:
  - "Two concrete stepper structs (SetStepperDouble/Int) instead of one generic — Binding<Optional<Numeric>> is awkward; concrete keeps call sites clean"
  - "Carry-forward implemented on existing target* ghost fields, not new SetDraft fields — keeps SetRecord/SetDraft meaning unchanged"
  - "RPE column dropped from header; RPE now per-row collapsible chip — fast path = weight+reps only"
  - "Weight ± unit-aware (2.5 kg vs 5 lb), always stored in kg via WeightFormatter.toKg"
metrics:
  duration: ~15min
  completed: 2026-06-02
---

# Phase 38 Plan 01: Workout log fast entry — stepper-primary set entry Summary

Replaced the 3-text-fields-per-set entry model in ActiveWorkoutSheet with the locked Variant A stepper-primary interaction: always-visible ± steppers on weight and reps with tap-the-number keypad, within-session carry-forward rendered ghosted, a "Repeat last set" clone, a dashed "Add set" affordance, and a collapsible per-set "+ RPE" chip.

## What was built

**Task 1 — SetStepper component (`WorkloadApp/Components/SetStepper.swift`, commit `56176c4`)**
- `SetStepperDouble` (weight) and `SetStepperInt` (reps/RPE): one HStack of −, a tappable center `TextField` (decimalPad / numberPad), and +.
- Ghost behaviour: when `value == nil` and a `ghostBaseline` exists, the baseline renders in `text3` behind an empty field; first ± tap or keypad edit commits to `text1`.
- ± seeds from `value ?? ghostBaseline ?? floor`, then steps, clamped at `floor` (0 — no negative load persisted, mitigates T-38-01).
- 0pt square corners (Rectangle only), hairline `divider` segment separators + outer border, Font.Tokens sizing on SF Symbols, 8pt grid, no accent, no shadow.
- Registered in `project.pbxproj` (build file + file ref + Components group + Sources phase) — the project uses explicit file references, not a synchronized group.

**Task 2 — SetEntryRow + ExerciseEntryCard rewrite (`ActiveWorkoutSheet.swift`, `Localizable.xcstrings`, commit `d2aea9a`)**
- `weightReps` and `repsOnly` paths now use `SetStepper`; `distanceDuration`/`durationOnly` keep their existing fields (out of locked scope) but route RPE through the new chip too.
- Weight increment unit-aware: 2.5 kg for kg athletes, 5 lb (converted to kg) for lb athletes; reps ± 1. Stored value stays in kg.
- Carry-forward: `addCarriedSet()` copies the prior set's committed `weightKg`/`reps`/`rpe` into the new draft's `targetWeightKg`/`targetReps`/`targetRPE` (existing ghost-target fields) so a new row pre-fills ghosted without being marked committed.
- `repeatLastSet()` clones the prior set entirely as committed real values; hidden when `entry.sets` is empty.
- "+ Add set" is now a full-width dashed (`StrokeStyle dash: [4,4]`) affordance; "↻ Repeat last set" sits above it with a solid hairline border.
- Per-set RPE: `@State showRPE`; a "+ RPE" chip (text2, hairline border) expands to an inline RPE `SetStepperDouble` (increment 1, 0 fraction digits). Starts expanded if `set.rpe != nil` (e.g. from prescription). Fixed RPE column removed from `setHeaderRow`.
- Preserved: Pro progression suggestion label (`suggestionText`/`suggestionIcon`) and warmup-colored set index.
- New localized strings `set.action.repeatLast` ("Repeat last set" / "重复上一组") and `set.rpe.add` ("+ RPE" / "+ RPE") in en + zh-Hans; reused existing `set.action.add`, `table.header.*`, `exercise.label.prefilledFromLast`.
- `weightUnit` threaded from `athlete?.weightUnit` through `ExerciseEntryCard` → `SetEntryRow`.

## Verification

- `xcodebuild` BUILD SUCCEEDED on iPhone 17 Pro sim (`CAF84E71-BB64-491D-87C8-875A0143B26D`) after each task.
- Acceptance greps: `SetStepper` ×4 in the view (weight+reps both paths), `set.action.repeatLast` present, `showRPE`/`set.rpe.add` present, `dash`/`StrokeStyle` present, both new keys have zh-Hans entries.
- Regression gate on both edited Swift files: `ColorTokens.accent` == 0, `RoundedRectangle|.cornerRadius|.shadow(|.font(.system(` == 0.
- No change to SetRecord / SetDraft field meaning / any engine / any feature flag (dormant v1.6 PRS stays dormant). Carry-forward reuses existing `target*` fields. `git status` shows only the 3 planned files + pbxproj.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Registered SetStepper.swift in project.pbxproj**
- **Found during:** Task 1
- **Issue:** The Components group is an explicit PBXGroup (not a synchronized root group), so a new Swift file would not compile until added to the build file list, file references, group children, and Sources build phase.
- **Fix:** Added the four matching pbxproj entries mirroring `CardStyle.swift`.
- **Files modified:** `workload management/workload management.xcodeproj/project.pbxproj`
- **Commit:** `56176c4`

**2. [Rule 3 - Blocking] Doc-comment wording adjusted to keep regression gate clean**
- **Found during:** Task 1
- **Issue:** Initial header comment contained the literal token "RoundedRectangle"/".cornerRadius", which the acceptance grep counts.
- **Fix:** Reworded the comment to "0pt square corners (Rectangle only)" without the forbidden literals.
- **Commit:** `56176c4`

## Known Stubs

None. The `distanceDuration`/`durationOnly` input modes intentionally retain their existing text fields (explicitly out of the locked Variant A scope per plan); they are functional, not stubs.

## Manual smoke (pending human UAT)

Plan-specified manual checks not yet performed on-device (executor did not run interactive UAT): add a second set shows ghosted prior values; weight + commits and increments 2.5/5; tap number opens keypad; Repeat last set clones; + RPE reveals inline control. Recommend including in the phase UAT pass.

## Self-Check: PASSED
- FOUND: WorkloadApp/Components/SetStepper.swift
- FOUND: commit 56176c4
- FOUND: commit d2aea9a
