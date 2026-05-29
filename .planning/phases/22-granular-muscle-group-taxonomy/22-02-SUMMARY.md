---
phase: 22-granular-muscle-group-taxonomy
plan: 02
subsystem: workout-ui
tags: [muscle-group, picker, hierarchical, design-system, ui]
requires:
  - Plan 01 (MuscleGroup.region, MuscleRegion, suggestedSpecific)
provides:
  - MuscleGroupSelector (hierarchical region -> muscle picker)
  - AddCustomExerciseSheet NavigationLink-based muscle selector
  - ExerciseDatabase seed re-tagged to specific muscles (unambiguous entries)
affects: []
tech-stack:
  added: []
  patterns:
    - NavigationLink -> grouped List with text section headers (region grouping)
    - Rectangle hairlines + ColorTokens + Font.Tokens (DESIGN.md)
    - Coarse-value suggestion highlight without rewriting binding
key-files:
  created: []
  modified:
    - WorkloadApp/Views/WorkoutLog/ExercisePickerView.swift
decisions:
  - "Selector implemented as NavigationLink pushing a grouped List (option a from plan)"
  - "Uses MuscleRegion (Plan 01 rename) for grouping"
  - "D-08 seed re-tag applied to unambiguous single-muscle entries; compound/cardio/full-body/nil left coarse"
metrics:
  completed: 2026-05-30
  tasks: 2
  files_changed: 1
requirements: [UX-02]
---

# Phase 22 Plan 02: Hierarchical Muscle-Group Picker Summary

Replaced the flat `.menu` `Picker` over `MuscleGroup.allCases` in `AddCustomExerciseSheet` with a hierarchical region -> muscle selector grouped by `MuscleRegion`, verified the read-side displays need no change, and re-tagged unambiguous seed exercises to specific muscles. UI only; depends on Plan 01.

## What Was Built

**Task 1 — Hierarchical selector (`WorkloadApp/Views/WorkoutLog/ExercisePickerView.swift`):**
- The flat muscle `Picker` is gone. `AddCustomExerciseSheet` now shows a `NavigationLink` row (label = "Muscle Group (optional)" + current selection's `displayName` or "None" + chevron, with a hairline `Rectangle` divider below) that pushes a new `MuscleGroupSelector`.
- `MuscleGroupSelector` — a grouped `List` (`.listStyle(.plain)`, `ColorTokens.background`):
  - A top "None" section/row that clears the binding (`selection = nil`).
  - One `Section` per `MuscleRegion.allCases`, with a text header (`region.systemImage` monochrome `ColorTokens.text2` + `region.displayName`) and rows for `MuscleGroup.allCases.filter { $0.region == region }`.
  - Selecting any row sets `selection` and dismisses; a `checkmark` marks the current selection.
  - Coarse-value nudge: when the bound value is a coarse alias, `suggestedSpecific(for:)` is computed and the matching specific row shows a "Suggested" subtitle — highlighting the nudge WITHOUT rewriting the binding (the coarse value remains keepable; `nil` stays `nil`).
- Closure signatures unchanged: `ExercisePickerView.onSelect` and `AddCustomExerciseSheet.onAdd` remain `(String, ExerciseCategory, MuscleGroup?)`. The category Picker and save logic are untouched.
- Two new `String(localized:)` keys introduced for the selector chrome (`muscleGroup.none`, `muscleGroup.suggested`) — both have inline English `defaultValue` so they compile; their xcstrings entries (EN + zh-Hans) are added in Plan 03.

**Task 2 — Read-display verification + seed re-tag (D-08):**
- VERIFIED (no code change): the four read displays all call `.displayName` and therefore render specific names for new values and region names for retained coarse values automatically:
  - `ActiveWorkoutSheet.swift:713` `Text(muscle.displayName)`
  - `SessionDetailView.swift:117` `Text(muscle.displayName)`
  - `TemplateEditorSheet.swift:374` `Text(muscle.displayName)`
  - `Coach/TemplateEditorSheet.swift:281` `Text(muscle.displayName)`
- Re-tagged unambiguous single-muscle seed entries to specific values: Barbell Back Squat & Front Squat -> `.quads`, Romanian Deadlift -> `.hamstrings`, Leg Press / Leg Extension -> `.quads`, Hip Thrust -> `.glutes`, Lat Pulldown -> `.lats`, Bicep Curl -> `.biceps`, Tricep Pushdown -> `.triceps`, Lateral Raise -> `.lateralDelts`, Face Pull -> `.posteriorDelts`, Leg Curl -> `.hamstrings`, Calf Raise -> `.calves`, Plank & Hanging Leg Raise -> `.rectusAbdominis`.
- LEFT coarse/ambiguous: bench/incline presses (chest), Barbell Row / Deadlift / Pull Up / Seated Cable Row (back), Overhead Press / Dumbbell Shoulder Press (shoulders), Cable Fly (chest), all plyometric jumps (legs), all cardio/cycling/swimming/team-sport (fullBody/legs/back/nil). These remain valid via Plan 01 retention.

## Verification

- `xcodebuild build` on iPhone 17 Pro Max simulator → exit 0 (GREEN).
- DESIGN.md compliance grep on the file → no `RoundedRectangle`, no `.shadow(`, no `.system(`, no `ColorTokens.accent`. Grouping is via text section headers (region name + monochrome icon), not color; corners are square (Rectangle hairlines); spacing is 8pt multiples; typography is `Font.Tokens.*`; colors are `ColorTokens.*`.
- Closure signatures confirmed unchanged (`onSelect` / `onAdd` both `(String, ExerciseCategory, MuscleGroup?)`).
- Manual UAT (run-app visual confirmation of the hierarchy / None / Quads display) is pending — see Phase 22 verification notes; the build + static checks pass.

## Deviations from Plan

- Region grouping references `MuscleRegion` (Plan 01's rename from the planned `BodyRegion`, to avoid the pre-existing injury `BodyRegion` collision). No behavioral difference.
- Selector chrome introduces `muscleGroup.none` / `muscleGroup.suggested` localization keys (added to xcstrings in Plan 03). Minor, additive.

## Threat Surface

No new security surface. UI writes only typed `MuscleGroup` cases via the unchanged closures (no raw-string input). Seed re-tagging changes only in-binary defaults; it does not migrate existing user rows.

## Self-Check: PASSED

- File modified: ExercisePickerView.swift (selector + seed re-tag).
- `MuscleGroupSelector` present; flat `ForEach(MuscleGroup.allCases)` menu Picker removed.
- Build exit 0; DESIGN grep clean; closures unchanged; 4 read displays confirmed `.displayName`.
