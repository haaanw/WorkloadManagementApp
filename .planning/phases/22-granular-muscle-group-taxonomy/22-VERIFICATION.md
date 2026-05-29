---
phase: 22-granular-muscle-group-taxonomy
verified: 2026-05-30T00:30:00Z
status: passed_with_caveat
score: 6/6 success criteria verified (1 caveat: XCTest blocked by pre-existing host-app font assertion)
overrides_applied: 0
caveats:
  - "Unit-test target cannot execute in this environment: the #if DEBUG font-registration assertion in WorkloadApp.swift:11-36 crashes the test host on launch for ALL tests (verified with untouched SessionTypeTests). Pre-existing, not caused by Phase 22. Taxonomy logic verified via standalone Swift program instead. App build + build-for-testing both exit 0."
  - "parse-workout Edge Function requires manual `supabase functions deploy parse-workout` (external action reserved for user)."
deviations:
  - "New muscle-grouping enum named MuscleRegion (not the planned BodyRegion) — a BodyRegion enum already exists in Enums.swift for injury tracking. Localization keys are muscleRegion.* accordingly."
---

# Phase 22: Granular Muscle Group Taxonomy — Verification Report

**Phase Goal:** Replace the coarse 7-value `MuscleGroup` enum with an anatomically precise taxonomy organized by region, with a region→sub-group picker, graceful migration, sync compatibility, and specific-name displays.
**Verified:** 2026-05-30T00:30:00Z
**Status:** passed_with_caveat

---

## Goal Achievement — Success Criteria (ROADMAP.md)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | MuscleGroup expanded to ~25-30 specific muscles (all ROADMAP-named) | VERIFIED | `Enums.swift` MuscleGroup has 26 new specific cases + 7 retained coarse = 33 total. Standalone logic check: count==33. Every ROADMAP-named muscle present (quads…tibialisAnterior). |
| 2 | Muscle groups organized by body region for picker (Legs/Back/Chest/Shoulders/Arms/Core) | VERIFIED | `enum MuscleRegion` (legs/back/chest/shoulders/arms/core/fullBody); `MuscleGroup.region` exhaustive mapping; standalone check confirms every region has members and representative spread (quads→legs, lats→back, pecsUpper→chest, etc.). |
| 3 | Existing exercises migrate gracefully (Legs → prompt to specify / defaults to Quads) | VERIFIED | D-03 retention: all 7 old rawValues still decode (`MuscleGroup(rawValue:"legs") == .legs`). `suggestedSpecific(for: .legs) == .quads` (and full map, idempotent for specific). `MuscleGroupSelector` highlights the suggestion for coarse values without rewriting the binding. |
| 4 | ExercisePickerView selector shows region → sub-group hierarchy | VERIFIED | Flat `Picker(MuscleGroup.allCases)` removed; `AddCustomExerciseSheet` now NavigationLinks to `MuscleGroupSelector`, a grouped List with a None option + one text-headed section per MuscleRegion. Build exit 0. DESIGN.md grep clean (no RoundedRectangle/.shadow/.system/accent). |
| 5 | Supabase sync handles new enum values without breaking existing data | VERIFIED | No `muscle_group` PostgreSQL column (grep migrations → none); decode nil-safe both paths (SyncService.swift:1338, WorkoutLLMImportService.swift:206 via `flatMap MuscleGroup(rawValue:)`). parse-workout enum expanded to full taxonomy + null. Old coarse blobs decode via retained cases; new values degrade to nil on old clients (no crash). |
| 6 | Template/workout views display specific muscle group names | VERIFIED | All 4 read displays call `.displayName` (ActiveWorkoutSheet:713, SessionDetailView:117, TemplateEditorSheet:374, Coach/TemplateEditorSheet:281) — render specific names for new values, region names for coarse. No code change needed. Localized EN + zh-Hans for every new case. |

**Score:** 6/6 success criteria verified.

---

## Required Artifacts

| Artifact | Status | Details |
|----------|--------|---------|
| `WorkloadApp/Models/Enums.swift` | VERIFIED | MuscleGroup (33 cases), MuscleRegion enum, `region`, `systemImage`, `suggestedSpecific(for:)`. No VersionedSchema/SchemaMigrationPlan. |
| `WorkloadAppTests/MuscleGroupTaxonomyTests.swift` | PRESENT (created) | Covers rawValue stability, count, region totality, suggestedSpecific map + idempotence, non-empty labels. Auto-included via WorkloadAppTests fileSystemSynchronizedGroup. Execution blocked by pre-existing host-app crash (see caveat); logic validated standalone. |
| `WorkloadApp/Views/WorkoutLog/ExercisePickerView.swift` | VERIFIED | Hierarchical MuscleGroupSelector; seed re-tag of unambiguous single-muscle entries; closures unchanged. |
| `WorkloadApp/Resources/Localizable.xcstrings` | VERIFIED | 26 new muscleGroup.* + none/suggested + 7 muscleRegion.* keys, EN + zh-Hans. JSON valid. 7 original keys untouched. |
| `Supabase/functions/parse-workout/index.ts` | VERIFIED | muscle_group enum = full taxonomy + null; prompt nudges specific; still required. Requires manual redeploy. |

---

## Build / Test Status

- **Final full `xcodebuild build`** (iPhone 17 Pro Max, id 8E872500-...): exit 0 (GREEN).
- **`build-for-testing`**: exit 0.
- **Unit-test run**: BLOCKED — host app crashes on launch via `WorkloadApp.swift:32` `assertionFailure` (DEBUG font-registration assert). Confirmed pre-existing: the untouched `SessionTypeTests` crashes identically. Crash report: EXC_BREAKPOINT in `WorkloadApp.init()`. Bundled fonts are present with correct PostScript names; this is a test-host launch-timing issue, not a Phase 22 regression.
- **Taxonomy logic**: independently validated via a standalone Swift program replicating the enum + region + suggestedSpecific logic → "ALL LOGIC CHECKS PASSED (33 cases)".

---

## Deviations

1. **MuscleRegion vs BodyRegion (name collision).** A `BodyRegion` enum already exists in `Enums.swift` (injury tracking: shoulder/knee/hip/…), persisted via `InjuryEntry` with shipped `bodyRegion.*` localization keys. The new muscle-grouping enum was named `MuscleRegion` and its keys `muscleRegion.*` to avoid breaking injury serialization. All region-related criteria are satisfied; functionally equivalent.
2. **Two extra localization keys** (`muscleGroup.none`, `muscleGroup.suggested`) added for the selector chrome. Additive, EN + zh-Hans.

---

## Commits

| Hash | Subject |
|------|---------|
| 5c16e13 | feat(22-01): expand MuscleGroup to 33-value taxonomy + MuscleRegion grouping |
| 92b4c61 | feat(22-02): hierarchical region->muscle picker + seed re-tag |
| 9b9283e | feat(22-03): localize taxonomy (EN+zh-Hans) + expand parse-workout enum |

---

## Human Verification Required

1. **Manual UAT of the picker** — run the app, open Add Custom Exercise → Muscle Group: confirm the hierarchy (None + 7 regions each expandable to specific muscles), "Suggested" nudge on coarse values, and that a selected specific muscle (e.g. Quads) displays on the logged exercise row. Static checks pass; visual confirmation pending.
2. **Manual Edge Function deploy** — `supabase functions deploy parse-workout` (required for LLM import to emit specific muscles; not run by agent).
3. **zh-Hans review** — low-confidence terms: 髋旋转肌 (hipRotators), 胫骨前肌 (tibialisAnterior), 腹横肌 (transverseAbdominis), 竖脊肌 (erectors).
4. **Pre-existing test-host crash** — the DEBUG font assertion in WorkloadApp.swift blocks the unit-test target in this environment; out of Phase 22 scope but should be resolved so MuscleGroupTaxonomyTests (and all tests) can run in CI.

---

_Verified: 2026-05-30T00:30:00Z_
_Verifier: GSD execution agent (Claude Opus 4.8)_
