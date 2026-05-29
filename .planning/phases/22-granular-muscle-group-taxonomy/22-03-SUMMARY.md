---
phase: 22-granular-muscle-group-taxonomy
plan: 03
subsystem: localization-and-import
tags: [localization, xcstrings, zh-Hans, edge-function, serialization, backward-compat]
requires:
  - Plan 01 (final MuscleGroup rawValues + MuscleRegion)
provides:
  - muscleGroup.* (26 new) + muscleGroup.none + muscleGroup.suggested keys (EN + zh-Hans)
  - muscleRegion.* (7) keys (EN + zh-Hans)
  - parse-workout Edge Function muscle_group enum expanded to full taxonomy + null
  - parse-workout prompt nudges toward specific muscles
affects: []
tech-stack:
  added: []
  patterns:
    - xcstrings additive keys mirroring existing shape
    - JSON-schema structured-output enum expansion (nil-safe app-side decode)
key-files:
  created: []
  modified:
    - WorkloadApp/Resources/Localizable.xcstrings
    - Supabase/functions/parse-workout/index.ts
decisions:
  - "Localization keys use muscleRegion.* (Plan 01 rename) not bodyRegion.* — bodyRegion.* already used by the injury BodyRegion enum"
  - "Added two selector-chrome keys (muscleGroup.none, muscleGroup.suggested) introduced by Plan 02"
metrics:
  completed: 2026-05-30
  tasks: 3
  files_changed: 2
requirements: [UX-02]
---

# Phase 22 Plan 03: Localization + Edge Function + Backward-Compat Summary

Closed the localization and serialization loop for the expanded taxonomy: added EN + zh-Hans xcstrings keys for every new muscle, region, and selector-chrome string; expanded the `parse-workout` Edge Function's structured-output `muscle_group` enum + prompt to the full taxonomy; and confirmed (by inspection) that existing `groups_json` blobs need no SQL migration.

## What Was Built

**Task 1 — Localization (`WorkloadApp/Resources/Localizable.xcstrings`):**
- Added `muscleGroup.<case>` keys for all 26 new muscles (quads, hamstrings, glutes, calves, hipFlexors, psoas, adductors, hipRotators, tibialisAnterior, lats, trapsUpper, trapsMid, trapsLower, rhomboids, erectors, pecsUpper, pecsLower, anteriorDelts, lateralDelts, posteriorDelts, biceps, triceps, forearms, rectusAbdominis, obliques, transverseAbdominis), each with English + zh-Hans translated `stringUnit`s (translations per the 22-CONTEXT zh-Hans table).
- Added 7 `muscleRegion.<case>` keys (legs/back/chest/shoulders/arms/core/fullBody), EN + zh-Hans (腿部/背部/胸部/肩部/手臂/核心/全身).
- Added 2 selector-chrome keys introduced by Plan 02: `muscleGroup.none` (无), `muscleGroup.suggested` (建议).
- The 7 original `muscleGroup.*` entries are untouched. Structure mirrors the existing entries (`extractionState: manual`, `localizations -> en/zh-Hans -> stringUnit{state: translated, value}`).
- File validates as JSON (`python3 json.load` OK) and the app builds with it.

**Task 2 — Edge Function (`Supabase/functions/parse-workout/index.ts`):**
- Expanded the `muscle_group` JSON-schema `enum` from the 7 coarse values to the full 33-value taxonomy (7 retained coarse + 26 specific) plus `null`, preserving the `type: ["string","null"]` union. Enum strings are byte-identical to the Swift rawValues. `muscle_group` stays in the `required` array.
- Updated the prompt guidance (line 24) to instruct the model to emit the most specific primary muscle when identifiable (e.g. "quads" not "legs"), falling back to a coarse region value or null when ambiguous.

**Task 3 — Backward-compat confirmation (verification only, no edit):**
- Confirmed `grep -rn muscle_group Supabase/migrations/` returns nothing → no PostgreSQL column, no SQL migration, no data backfill required.
- Both Swift decode paths are pure rawValue round-trip and nil-safe: `SyncService.swift:1338` (`exDTO.muscleGroup.flatMap { MuscleGroup(rawValue: $0) }`) and `WorkoutLLMImportService.swift:206` (`exercise.muscle_group.flatMap { MuscleGroup(rawValue: $0) }`).
- Therefore: old `groups_json` blobs with coarse values (`"muscleGroup":"legs"`) decode via the retained cases; new blobs with specific values (`"muscleGroup":"quads"`) decode to the new case; an old (pre-22) client reading a new blob hits `MuscleGroup(rawValue:"quads") -> nil` and gracefully shows no muscle (never crashes).

## MANUAL DEPLOY REQUIRED (flagged)

The `parse-workout` Edge Function change takes effect ONLY after redeploy. The user must run:

    supabase functions deploy parse-workout

Until redeployed, LLM import keeps emitting the old coarse values (still valid) — no crash, just no new granularity from import. This is an external action reserved for the user; it was NOT run by this agent.

## Verification

- `xcodebuild build` → exit 0 (GREEN); xcstrings compiles into the app.
- `python3 json.load(Localizable.xcstrings)` → OK; 35 `muscleGroup.*` keys + 7 `muscleRegion.*` keys present.
- Edge Function spot-check: `quads`, `hamstrings`, `lats`, `pecsUpper`, `biceps` present in the enum; prompt updated.
- `grep -rn muscle_group Supabase/migrations/` → no matches (no DB column / SQL migration).

## Deviations from Plan

- Region localization keys are `muscleRegion.*`, not the planned `bodyRegion.*` — `bodyRegion.*` keys already exist and belong to the pre-existing injury `BodyRegion` enum (Plan 01 deviation 1). Reusing them would mislabel injury regions. Functionally equivalent; keys match the Plan 01 enum's `String(localized:)` calls.
- Two extra keys (`muscleGroup.none`, `muscleGroup.suggested`) added beyond the plan's list — they back the Plan 02 selector chrome. Additive, EN + zh-Hans.

## zh-Hans Confidence Note

Translations follow the 22-CONTEXT table / common fitness-app rendering. Lower-confidence terms a native reviewer may wish to confirm: `hipRotators` 髋旋转肌, `tibialisAnterior` 胫骨前肌, `transverseAbdominis` 腹横肌, `erectors` 竖脊肌. All are anatomically standard but phrasing varies across fitness apps. Flagged for human review (zh-Hans is a shipped language).

## Threat Surface

Per the plan threat model: structured-output enum constrains LLM values; app-side nil-safe `MuscleGroup(rawValue:)` rejects anything off-list to nil (no raw string trusted). No migration; retained cases decode every existing blob. New keys are additive; existing keys untouched; xcstrings validated.

## Self-Check: PASSED

- Files modified: Localizable.xcstrings, parse-workout/index.ts.
- 26 new muscleGroup keys + 7 muscleRegion keys + none/suggested present, EN + zh-Hans.
- Edge enum contains full taxonomy + null; prompt nudges specific; muscle_group still required.
- No SQL migration; nil-safe decode confirmed both paths. Build exit 0.
- Manual `supabase functions deploy parse-workout` flagged.
