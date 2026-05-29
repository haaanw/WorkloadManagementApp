# Phase 22: Granular Muscle Group Taxonomy - Context

**Gathered:** 2026-05-29
**Status:** Ready for planning

<domain>
## Phase Boundary

Replace the coarse 7-value `MuscleGroup` enum (`chest, back, legs, shoulders, arms, core, fullBody`) with an anatomically precise ~28-value taxonomy that serious athletes expect, organized by **body region** (Legs, Back, Chest, Shoulders, Arms, Core, plus a Full Body catch-all) so the picker can present a **region → sub-group hierarchy**.

This is a **data-model + UI + serialization** phase. It touches:
1. The `MuscleGroup` enum (`Models/Enums.swift`) — add the new specific cases, a `BodyRegion` grouping, `displayName`, and (newly) `systemImage`.
2. The muscle-group picker UI (`ExercisePickerView` → `AddCustomExerciseSheet`'s flat `Picker`) — make it hierarchical.
3. Read-side displays that already show `muscleGroup.displayName` — they keep working unchanged because they call `displayName` (no enum-shape assumptions).
4. Serialization: the JSON blob inside `WorkoutTemplate.groupsJson` (Supabase `prescribed_workouts.groups_json` / template rows) and the **`parse-workout` Supabase Edge Function** structured-output enum.
5. Localization: every new `displayName` needs a `muscleGroup.<case>` key in `Resources/Localizable.xcstrings` (Phase 23 already localized the 7 existing keys to zh-Hans; the new keys must follow the same pattern).

**Out of scope:** No new analytics/charts keyed by muscle group exist today (verified — no per-muscle volume chart), so none are built here. No new Supabase table column is added (muscle group is NOT a Postgres column anywhere — see below). Exercise-database re-tagging to the new specific values is **optional polish** (the seed `ExerciseDatabase` can keep coarse tags that map forward, or be re-tagged — planner decides; see D-08).

</domain>

<verified_codebase_facts>
## Ground Truth (verified against source, NOT roadmap prose)

These were checked against the actual code on 2026-05-29. Where ROADMAP diverges from reality it is flagged.

### Current enum (`WorkloadApp/Models/Enums.swift:169`)
```swift
enum MuscleGroup: String, Codable, CaseIterable, Identifiable {
    case chest, back, legs, shoulders, arms, core, fullBody
    var id: String { rawValue }
    var displayName: String { /* String(localized: "muscleGroup.<case>", ...) */ }
}
```
- **DIVERGENCE FROM CLAUDE.md convention:** The enum has **NO `systemImage`** today (CLAUDE.md says enums "include systemImage where applicable"). Phase 22 should ADD `systemImage` to satisfy the convention and to support a richer hierarchical picker. This is additive, not a fix to existing behavior.
- `fullBody` exists today and is heavily used by cardio/running/team-sport seed exercises. ROADMAP's 6 regions (Legs/Back/Chest/Shoulders/Arms/Core) **omit a home for `fullBody`** — that is a DIVERGENCE. Decision D-02 resolves it (keep `fullBody`, add a `fullBody`/`other` region).

### Where `muscleGroup` is stored & used (all verified)
| Location | Kind | Notes |
|----------|------|-------|
| `Models/ExerciseEntry.swift:9` | SwiftData `@Model` field `var muscleGroup: MuscleGroup?` | Logged-session exercises. Local-only (NOT synced — see below). |
| `Models/CustomExercise.swift:9` | SwiftData `@Model` field | User custom exercises. Synced? No dedicated column (custom exercises sync via athlete payload — muscle only round-trips if present). |
| `Models/WorkoutTemplate.swift:127` (`TemplateExercise`) | SwiftData `@Model` field | Template exercises. Synced inside `groupsJson` blob. |
| `Views/WorkoutLog/ExercisePickerView.swift:185,209-214` | UI `@State` + flat `Picker` over `MuscleGroup.allCases` | **The primary UI to rebuild as hierarchical.** |
| `Views/WorkoutLog/ActiveWorkoutSheet.swift:669,712-713` | draft field + read display (`muscle.displayName`) | Display is shape-agnostic; keeps working. |
| `Views/WorkoutLog/SessionDetailView.swift:116-117` | read display | Shape-agnostic; keeps working. |
| `Views/TemplateEditorSheet.swift:503` + `Views/Coach/TemplateEditorSheet.swift:371` | **TWO** editor sheets, each with draft field + read display (`:373-374` / `:280-281`) | Both shape-agnostic on display; both feed picker via `ExercisePickerView`. |
| `Services/SyncService.swift:1338,1513,1519` | `ExerciseDTO.muscleGroup: String?` (JSON) | `init` writes `exercise.muscleGroup?.rawValue`; decode is `MuscleGroup(rawValue: $0)` (nil-safe on unknown). |
| `Services/WorkoutLLMImportService.swift:28,206` | `let muscle_group: String?` decoded via `MuscleGroup(rawValue:)` (nil-safe) | LLM import path. |
| `Supabase/functions/parse-workout/index.ts:70-92,110` | **Hardcoded JSON-schema `enum` of the 7 old values + null** | **CRITICAL:** structured-output schema. New raw values MUST be added here or the model is constrained to only emit old values (no crash, but new granularity never produced by import). |

### Serialization reality (CRITICAL for migration design)
- **`muscleGroup` is NOT a PostgreSQL column anywhere.** Verified: `grep muscle Supabase/migrations/*.sql` → zero matches. It lives only:
  1. Inside the `groups_json` TEXT blob on template/prescribed-workout rows (as `"muscleGroup":"chest"`), and
  2. In the `parse-workout` Edge Function's structured-output enum.
- `WorkoutSessionRow` (the synced shape for logged sessions, `SyncService.swift:958`) carries **no exercise breakdown at all** — only session-level aggregates (volume, loads, RPE). Therefore `ExerciseEntry.muscleGroup` is **device-local SwiftData only** and never leaves the device. This dramatically narrows the sync surface: only the `groupsJson` blob + the Edge Function enum need compatibility care.
- Both Swift decode paths use `MuscleGroup(rawValue:)` which returns `nil` for unknown strings — **a value the schema doesn't recognize silently becomes `nil`, never crashes.** This is the safety net for forward/backward compat.

### SwiftData migration reality
- There is **NO `VersionedSchema` / `SchemaMigrationPlan`** in the project (verified — only an ad-hoc `notificationService.migrateWeeklySummaryIfNeeded()` UserDefaults nudge in `AppContainer`). The schema is lightweight-migrated implicitly.
- Because `muscleGroup` is stored as the enum's **`String` rawValue**, and we are **adding** cases while **keeping all 7 existing rawValues as valid cases**, every existing SwiftData row decodes without migration. No destructive schema change. (This is the linchpin of the graceful-migration strategy — see D-04/D-05.)

### Localization
- `Resources/Localizable.xcstrings` already has `muscleGroup.{chest,back,legs,shoulders,arms,core,fullBody}` (7 keys, zh-Hans translated in Phase 23). Each NEW case needs a new `muscleGroup.<case>` key (English defaultValue + zh-Hans). This is a hard requirement, not optional — Phase 23 (zh-Hans) is shipped and complete.

### Requirement UX-02
- **DIVERGENCE / DATA NOTE:** `UX-02` is referenced by `ROADMAP.md:198` and the v1.2/v1.3 milestone roadmaps, but **has no definition row** in any `REQUIREMENTS.md` (verified: zero `UX-02` matches in `.planning/REQUIREMENTS.md` and milestone REQUIREMENTS files). The phase requirement is therefore defined operationally by the ROADMAP's 6 success criteria, which this context treats as the locked WHAT. Planner should not block on the missing requirement row; flag it to the user for backfill.
</verified_codebase_facts>

<decisions>
## Implementation Decisions

### Taxonomy & Regions
- **D-01:** Expand `MuscleGroup` to the ROADMAP's ~28 anatomically specific cases (see full list in the mapping table). All NEW cases use new rawValues that are **lowerCamelCase** matching the existing convention (e.g. `quads`, `hamstrings`, `anteriorDelts`, `pecsUpper`, `trapsUpper`, `rectusAbdominis`). RawValues are permanent serialization contracts — never rename once shipped.
- **D-02:** Introduce a `BodyRegion` enum (`String, Codable, CaseIterable, Identifiable`, with `displayName` + `systemImage`) with cases `legs, back, chest, shoulders, arms, core, fullBody`. `fullBody` region is RETAINED (ROADMAP's 6-region list omits it but the codebase depends on it for cardio/running/team-sport). `MuscleGroup` gains a computed `var region: BodyRegion` mapping every case (old + new) to its region. The picker groups `MuscleGroup.allCases` by `region`.

### Backward-Compat / Migration Strategy (the critical part)
- **D-03 — Keep old cases as decodable aliases (NON-destructive).** All 7 existing cases (`chest, back, legs, shoulders, arms, core, fullBody`) are **RETAINED** in the enum with their **exact original rawValues**. They become "region-level coarse" values that still decode every existing SwiftData row and every existing `groupsJson` blob without any data rewrite. This is the primary graceful-migration mechanism: no row ever fails to decode, no crash, no data loss.
- **D-04 — `displayName` of retained coarse cases stays the region name** (`chest` → "Chest", `legs` → "Legs"). They are still legal, still display correctly, and simply read as the broad region. New specific cases read as the specific muscle.
- **D-05 — Forward default mapping for "specify" UX, NOT a destructive rewrite.** Per success criterion 3 ("Legs → user prompted to specify or defaults to Quads"), provide a pure helper `MuscleGroup.suggestedSpecific(for coarse: MuscleGroup) -> MuscleGroup` returning the most-common default specific value per region (e.g. `legs → quads`, `chest → pecsLower`, `back → lats`, `shoulders → lateralDelts`, `arms → biceps`, `core → rectusAbdominis`, `fullBody → fullBody`). **This is used only when the user actively re-edits/re-specifies an exercise** (the picker pre-selects the suggestion when it encounters a coarse value), or by an OPTIONAL one-time non-destructive in-app prompt. It does **NOT** silently rewrite stored data on launch. Rationale: silent rewrite risks mis-tagging an athlete's deliberate "Legs" choice; the retained-alias approach (D-03) means we never *have* to rewrite, and re-specification is opt-in. Planner MAY add a lightweight one-time "Refine your muscle groups?" prompt but it must be user-driven and reversible — flagged as optional (P3).
- **D-06 — No SwiftData `VersionedSchema` needed.** Because the change is purely additive enum cases over a `String` rawValue field, lightweight migration handles it. No `SchemaMigrationPlan` is introduced. (If the planner finds any non-additive change creeping in, STOP and re-scope.)

### Sync Compatibility
- **D-07 — Supabase round-trips for free, but the Edge Function enum MUST be updated.** The `groups_json` blob stores rawValues as opaque strings; new values serialize and decode transparently (decode is `MuscleGroup(rawValue:)`, nil-safe). **The one mandatory backend edit** is `Supabase/functions/parse-workout/index.ts`: extend the `muscle_group` JSON-schema `enum` (lines ~70-92) AND the prompt guidance (line ~24) to include all new values, so LLM import can emit specific muscles. Without this, import still works but is capped at the 7 coarse values. Old rows authored by old clients (coarse values) remain valid because old cases are retained (D-03). New rows read by an old client (pre-22) would hit `MuscleGroup(rawValue:)` → `nil` → display "no muscle"; acceptable graceful degradation (documented), and the app is force-updated forward anyway.

### Seed Database
- **D-08 — Re-tagging `ExerciseDatabase` to specific values is OPTIONAL (P2 polish).** The ~70 seed exercises in `ExercisePickerView.swift` currently use coarse tags (`.chest`, `.legs`, …). They keep working under D-03. Re-tagging them to specific values (e.g. "Barbell Back Squat" → `.quads`, "Romanian Deadlift" → `.hamstrings`) materially improves out-of-box granularity and is recommended, but is isolated from the enum/migration/sync work. Planner: put it in its own plan/task so it can be cut without blocking the core change.

### Claude's Discretion (for planner/executor)
- Exact `systemImage` SF Symbol per region/muscle (use plausible body/figure symbols; `figure.strengthtraining.traditional`, `figure.core.training`, etc.).
- Whether `MuscleGroup.region` lives as a computed property on `MuscleGroup` or a `BodyRegion`-keyed grouping helper (prefer computed `var region` on `MuscleGroup` — single source of truth, easy `allCases` grouping).
- Hierarchical picker mechanics: `NavigationLink` region → muscle list, vs sectioned `List`/`Form` with region headers, vs a two-step menu. Prefer a sectioned `List` grouped by region (works in the existing sheet `Picker` replacement and respects DESIGN.md: 0pt corners, hairline dividers, General Sans, no color-only cues).
- Whether to ship the optional one-time re-specify prompt (D-05) this phase or defer.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirement / WHAT (locked)
- `ROADMAP.md` "### Phase 22: Granular Muscle Group Taxonomy" — goal + 6 success criteria + `Depends on: Phase 11` + `Requirements: UX-02` (UX-02 row itself is missing from REQUIREMENTS.md — flag).

### Existing code to modify
- `WorkloadApp/Models/Enums.swift:169` — `MuscleGroup` enum (expand; add `BodyRegion`, `region`, `systemImage`).
- `WorkloadApp/Views/WorkoutLog/ExercisePickerView.swift` — `AddCustomExerciseSheet` flat muscle `Picker` (lines 209-214) → hierarchical; also `ExerciseDatabase` seed (lines 282-413, optional re-tag per D-08).
- `WorkloadApp/Views/TemplateEditorSheet.swift` and `WorkloadApp/Views/Coach/TemplateEditorSheet.swift` — both consume `ExercisePickerView`; verify hierarchy flows through (read displays already shape-agnostic).
- `Supabase/functions/parse-workout/index.ts:24,70-92,110` — extend muscle_group schema enum + prompt (D-07, MANDATORY).
- `WorkloadApp/Resources/Localizable.xcstrings` — add `muscleGroup.<newCase>` keys (English + zh-Hans).

### Read-side (no change expected, verify only)
- `WorkloadApp/Views/WorkoutLog/ActiveWorkoutSheet.swift:712`, `SessionDetailView.swift:116`, both `TemplateEditorSheet` displays — all call `.displayName`; confirm unaffected.

### Serialization / sync (compat only, no schema change)
- `WorkloadApp/Services/SyncService.swift:1338,1500-1522` — `ExerciseDTO` / `GroupDTO` JSON round-trip (rawValue ↔ enum, nil-safe).
- `WorkloadApp/Services/WorkoutLLMImportService.swift:28,206` — LLM import decode (nil-safe).
- `Supabase/migrations/` — confirm NO muscle_group column (none exists; no SQL migration needed).

### Models persisting the field
- `WorkloadApp/Models/ExerciseEntry.swift:9` (local-only), `CustomExercise.swift:9`, `WorkoutTemplate.swift:127` (`TemplateExercise`).
</canonical_refs>

<full_migration_mapping>
## OLD → NEW Default Mapping Table

**Strategy summary:** OLD values are NOT deleted — they are RETAINED as valid decodable cases (D-03), so no stored data is rewritten. The "NEW default specific value" column is the `suggestedSpecific(for:)` value used only when a user actively re-specifies a coarse exercise (D-05). The "Region" column is the `BodyRegion` each value maps to.

| OLD coarse case (rawValue) | Retained? | Region | NEW default specific value (`suggestedSpecific`) | Rationale for default |
|---------------------------|-----------|--------|-------------------------------------------------|-----------------------|
| `chest` | Yes (alias) | `chest` | `pecsLower` | Most pressing volume targets sternal/lower pec |
| `back` | Yes (alias) | `back` | `lats` | Lats are the headline back muscle for most lifters |
| `legs` | Yes (alias) | `legs` | `quads` | Squat/press dominant default (matches ROADMAP example "Legs → Quads") |
| `shoulders` | Yes (alias) | `shoulders` | `lateralDelts` | Lateral delts = the "shoulder width" default |
| `arms` | Yes (alias) | `arms` | `biceps` | Most-tagged arm isolation default |
| `core` | Yes (alias) | `core` | `rectusAbdominis` | The visible "abs" default |
| `fullBody` | Yes (alias) | `fullBody` | `fullBody` | No meaningful specific split; stays full body |

### NEW specific cases by region (the ~28-value target taxonomy)

| Region (`BodyRegion`) | New `MuscleGroup` cases (rawValue : displayName) |
|-----------------------|--------------------------------------------------|
| `legs` | `quads` : "Quads" · `hamstrings` : "Hamstrings" · `glutes` : "Glutes" · `calves` : "Calves" · `hipFlexors` : "Hip Flexors" · `psoas` : "Psoas" · `adductors` : "Adductors" · `hipRotators` : "Hip Rotators" · `tibialisAnterior` : "Tibialis Anterior" |
| `back` | `lats` : "Lats" · `trapsUpper` : "Upper Traps" · `trapsMid` : "Mid Traps" · `trapsLower` : "Lower Traps" · `rhomboids` : "Rhomboids" · `erectors` : "Erectors" |
| `chest` | `pecsUpper` : "Upper Chest" · `pecsLower` : "Lower Chest" |
| `shoulders` | `anteriorDelts` : "Front Delts" · `lateralDelts` : "Side Delts" · `posteriorDelts` : "Rear Delts" |
| `arms` | `biceps` : "Biceps" · `triceps` : "Triceps" · `forearms` : "Forearms" |
| `core` | `rectusAbdominis` : "Rectus Abdominis" · `obliques` : "Obliques" · `transverseAbdominis` : "Transverse Abdominis" |
| `fullBody` | (retained `fullBody` coarse value only) |

New specific cases: 9 + 6 + 2 + 3 + 3 + 3 = **26 new** + 7 retained coarse = **33 total** (the ~25-30 specific muscles requested, plus retained coarse aliases). Planner MAY trim/merge (e.g. fold `psoas` into `hipFlexors`, or `hipRotators` into glutes) to land closer to 28 if anatomically defensible — but each ROADMAP-named muscle should have a home.
</full_migration_mapping>

<assumptions_full_auto>
## Assumptions (full-auto)

1. **UX-02 is operationally defined by the ROADMAP's 6 success criteria.** Since no `UX-02` row exists in any REQUIREMENTS.md, the 6 criteria are treated as the authoritative WHAT. (Flagged to user for backfill.)
2. **Old rawValues are sacred and retained forever.** No rename/removal of `chest/back/legs/shoulders/arms/core/fullBody`. This is the entire backward-compat guarantee; planner must not "clean up" by deleting them.
3. **No SwiftData VersionedSchema is introduced** — additive enum cases over a String rawValue are lightweight-migration-safe; existing rows decode unchanged.
4. **`ExerciseEntry.muscleGroup` is device-local only** (not in `WorkloadSessionRow`), so logged-session muscle tags never need sync compatibility work — only the template `groupsJson` blob and the Edge Function enum do.
5. **The `parse-workout` Edge Function enum + prompt WILL be updated** (D-07) — this is the single mandatory backend edit; deploying it is part of the phase.
6. **`fullBody` region is kept** despite ROADMAP listing only 6 regions, because cardio/running/team-sport seed exercises depend on it.
7. **`systemImage` is added** to satisfy the CLAUDE.md enum convention (currently absent) — additive.
8. **Seed `ExerciseDatabase` re-tagging is optional polish** (its own cuttable plan), not core to the migration.
9. **Every new case gets a `Localizable.xcstrings` key** (English + zh-Hans) because zh-Hans (Phase 23) is shipped; English-only would regress the localized build.
10. **The "re-specify" UX is opt-in/user-driven** (no silent destructive rewrite of stored muscle tags on launch).
</assumptions_full_auto>

<deferred>
## Deferred Ideas
- **Per-muscle volume analytics / weekly muscle-group volume charts** — not built today; granular taxonomy makes this newly valuable but it is a separate future phase (out of scope here).
- **Secondary/synergist muscle tagging** (an exercise hitting multiple muscles) — current model is single optional muscle; multi-muscle is a future model change.
</deferred>

---

*Phase: 22-granular-muscle-group-taxonomy*
*Context gathered: 2026-05-29*
