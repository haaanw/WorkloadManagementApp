---
phase: 22-granular-muscle-group-taxonomy
plan: 01
subsystem: domain-model
tags: [muscle-group, taxonomy, enum, backward-compat, pure-model]
requires:
  - MuscleGroup enum (7 coarse cases, pre-Phase-22)
provides:
  - MuscleGroup expanded to 33 cases (7 retained coarse + 26 specific)
  - MuscleRegion enum (legs, back, chest, shoulders, arms, core, fullBody)
  - MuscleGroup.region computed mapping (exhaustive)
  - MuscleGroup.systemImage (via region.systemImage)
  - MuscleGroup.suggestedSpecific(for:) default-mapping helper
affects:
  - Plan 22-02 (hierarchical picker consumes region + suggestedSpecific)
  - Plan 22-03 (localization keys muscleGroup.* / muscleRegion.*)
tech-stack:
  added: []
  patterns:
    - Additive enum cases over String rawValue (lightweight-migration safe)
    - Backward compat by retention (old rawValues kept as decodable aliases)
    - Pure static helper for default mapping (idempotent for specific inputs)
key-files:
  created:
    - WorkloadAppTests/MuscleGroupTaxonomyTests.swift
  modified:
    - WorkloadApp/Models/Enums.swift
decisions:
  - D-01..D-06 implemented as specified
  - "DEVIATION: new region enum named MuscleRegion (not BodyRegion) — a BodyRegion enum already exists in Enums.swift for injury tracking (joints). Localization keys use muscleRegion.* accordingly."
metrics:
  completed: 2026-05-30
  tasks: 1
  files_changed: 2
requirements: [UX-02]
---

# Phase 22 Plan 01: Granular Muscle Group Taxonomy (Pure Model) Summary

Expanded the coarse 7-value `MuscleGroup` enum into a 33-value anatomically specific taxonomy (7 original coarse cases RETAINED as decodable aliases + 26 new specific muscles), organized by a new `MuscleRegion` grouping enum, with a `region` mapping, a `systemImage` property, and a pure `suggestedSpecific(for:)` default-mapping helper. Pure model + tests only — no UI, no SwiftData migration, no sync.

## What Was Built

**`WorkloadApp/Models/Enums.swift`:**
- `enum MuscleRegion: String, Codable, CaseIterable, Identifiable` with cases `legs, back, chest, shoulders, arms, core, fullBody`, each with `displayName` (`String(localized: "muscleRegion.<case>", ...)`) and `systemImage` (figure.* / dumbbell SF Symbols). `fullBody` region retained (D-02) for cardio/running/team-sport seed exercises.
- `MuscleGroup` expanded: all 7 original cases (`chest, back, legs, shoulders, arms, core, fullBody`) kept with their EXACT original rawValues (D-03), plus 26 new specific lowerCamelCase cases (D-01): quads, hamstrings, glutes, calves, hipFlexors, psoas, adductors, hipRotators, tibialisAnterior, lats, trapsUpper, trapsMid, trapsLower, rhomboids, erectors, pecsUpper, pecsLower, anteriorDelts, lateralDelts, posteriorDelts, biceps, triceps, forearms, rectusAbdominis, obliques, transverseAbdominis.
- `displayName` extended to every case via `String(localized: "muscleGroup.<case>", defaultValue:...)`; retained coarse cases keep region-name labels (D-04).
- `var region: MuscleRegion` — exhaustive switch mapping every case (old + new) to exactly one region (no `default` arm).
- `var systemImage: String { region.systemImage }`.
- `static func suggestedSpecific(for:) -> MuscleGroup` — D-05 defaults (legs→quads, chest→pecsLower, back→lats, shoulders→lateralDelts, arms→biceps, core→rectusAbdominis, fullBody→fullBody); returns the input unchanged for already-specific values (idempotent via `default: coarse`).
- Conformances `String, Codable, CaseIterable, Identifiable` and `id == rawValue` preserved. No `VersionedSchema`/`SchemaMigrationPlan` added; no `@Model` file touched (D-06).

**`WorkloadAppTests/MuscleGroupTaxonomyTests.swift`** (new, in the WorkloadAppTests fileSystemSynchronized group — auto-included in target): covers old-rawValue decode for all 7 originals, unknown→nil, presence of all 26 new cases + count==33, rawValue round-trip, region representative spread, region totality (every region has members), full suggestedSpecific mapping + idempotence, and non-empty displayName/systemImage for every case and region.

## Verification

- **App build (ship target):** `xcodebuild build` on iPhone 17 Pro Max simulator → exit 0 (GREEN). The taxonomy code compiles cleanly.
- **Logic verification:** All test assertions were independently validated by extracting the enum + region + suggestedSpecific logic into a standalone Swift program (`swift mg_verify.swift`) → "ALL LOGIC CHECKS PASSED (33 cases)". This proves: 7 old rawValues decode, unknown→nil, count==33, full suggestedSpecific map, idempotence, region totality, region spread.
- **XCTest target run: BLOCKED by a pre-existing, unrelated environment issue** — see Deviations.

## Deviations from Plan

### DEVIATION 1 — Region enum named `MuscleRegion`, not `BodyRegion` (name collision)
The plan (and its interface extraction) specified a new `enum BodyRegion`. However, `WorkloadApp/Models/Enums.swift` ALREADY contains an `enum BodyRegion` (line ~516, "Injury Enums" section: cases `shoulder, knee, back, hip, ankle, wrist, elbow, neck`), used by `struct InjuryEntry` and persisted/synced via `TrainingProfileSheet`. Reusing the name caused `Invalid redeclaration of 'BodyRegion'` and `'BodyRegion' is ambiguous`. Renaming or repurposing the existing injury `BodyRegion` would break injury serialization and its already-shipped `bodyRegion.*` localization keys. **Resolution:** named the new muscle-grouping enum `MuscleRegion` and its localization keys `muscleRegion.*`. All Plan 01 truths are otherwise satisfied (a region enum exists with the 7 region cases + displayName + systemImage; `MuscleGroup.region` maps every case). Plans 02/03 updated to reference `MuscleRegion` / `muscleRegion.*`.

### DEVIATION 2 — XCTest could not execute (pre-existing host-app crash, NOT introduced by Phase 22)
Running ANY unit test (including the untouched `WorkloadAppTests/SessionTypeTests`) crashes the test host app on launch with `EXC_BREAKPOINT` / `assertionFailure` at `WorkloadApp.swift:32` inside `WorkloadApp.init()`. Crash report confirms it is the `#if DEBUG` font-registration `assert(...)` block (lines 11-36) firing because the bundled fonts' PostScript names aren't resolved at the moment the XCTest-injected host app initializes. The bundled fonts (`GeneralSans-Variable.ttf`, `NotoSansSC-Regular.otf`, `NotoSansSC-Medium.otf`) are present in the app bundle and have correct PostScript names (verified via fontTools), and the app `build`/`build-for-testing` both succeed. This is a pre-existing test-host launch issue affecting all unit tests equally; it is not caused by, and does not relate to, the Phase 22 enum changes. Per execution rules I did not modify `WorkloadApp.swift` (unrelated app behavior) to force the test green. Logic was instead verified standalone (above). **Flagged for the user.**

## Threat Surface

No new security surface. Per the plan threat model: old rawValues retained (a test asserts `init(rawValue:)` resolves each of the 7); unknown rawValue decode returns nil (never crashes — callers use `MuscleGroup?`); no sync/migration code added; one new test file in the existing test target.

## Self-Check: PASSED (with noted XCTest-execution blocker)

- Files present: Enums.swift (modified), MuscleGroupTaxonomyTests.swift (created), 22-01-SUMMARY.md.
- Symbols verified: `enum MuscleRegion`, `var region: MuscleRegion`, `static func suggestedSpecific(for`, all 7 original cases + 26 new cases.
- No `VersionedSchema`/`SchemaMigrationPlan` in Enums.swift.
- App build: exit 0. Taxonomy logic: standalone-verified PASS (33 cases).
- XCTest run blocked by pre-existing font-assert host crash (deviation 2, flagged).
