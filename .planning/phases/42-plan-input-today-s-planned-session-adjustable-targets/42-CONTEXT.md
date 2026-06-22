# Phase 42: Plan Input — Today's Planned Session + Adjustable Targets — Context

**Gathered:** 2026-06-13
**Status:** Ready for planning
**Source:** Orchestrator from v2.0 research (`.planning/research/v2-crossmodal-and-measurement.md` §plan-input)
**Requirements:** PLAN-10, PLAN-11

<domain>
## Phase Boundary

Give the app a notion of "today's planned strength session" and make each planned set carry the target fields the Phase-43 verdict will read from and write a suggested adjustment into.

**IN scope:**
- PLAN-10: The athlete can designate today's planned session two ways — (a) load an existing template (reuse the existing template→session flow), or (b) manually enter a planned lift with target weight/reps/RPE. Minimal entry affordance only.
- PLAN-11: A planned set carries additive-nullable target fields: the planned target (already exists on TemplateSet/PrescribedWorkout where applicable) PLUS a nullable "suggestedAdjusted" slot the verdict can write into later and an accepted/declined marker. The verdict ENGINE and UI are NOT built here — only the data the verdict needs.

**OUT of scope (later phases):**
- The go/modify/hold verdict + adjusted-number computation (Phase 43)
- The suggest-and-confirm verdict UI card / nocebo framing (Phase 44)
- Measurement / VerdictEvent / WTP (Phase 45)
- Full multi-week program ingestion / LLM parse (deferred from v2.0 entirely)
</domain>

<decisions>
## Locked Decisions

### Reuse existing models — do NOT invent a new plan system
- Per research: plan input REUSES the existing models. GREP and read them first: `WorkloadApp/Models/WorkoutTemplate.swift` (WorkoutTemplate → ExerciseGroup → TemplateExercise → TemplateSet), `WorkloadApp/Models/PrescribedWorkout.swift`. Find the real fields (e.g. TemplateSet target weight/reps/RPE, PrescribedWorkout.targetRPE/targetVolume) before designing anything.
- "Today's planned session" should be expressed in terms of these existing types (a chosen template / a PrescribedWorkout-like record for the day), NOT a brand-new parallel hierarchy.

### Additive-nullable only — zero migration, zero sync change
- Any new field is additive and nullable on an existing `@Model` (mirrors prior FOUND-02 / cycle-model discipline). No renames, no required fields, no new non-null columns.
- New fields must be EXCLUDED from Supabase sync payloads (composite-only rule) OR be harmless additive locals — verify the sync encoder does not break. No migration.

### The verdict's read/write contract (forward-looking, build the slots only)
- Each planned set needs: the planned target (exists), a nullable `suggestedAdjustedWeight`/value slot (verdict writes), and an accept/decline state (athlete confirms in Phase 44). Phase 42 creates these slots + the designation flow; it does NOT populate them from any engine.

### Minimal UI, DESIGN.md-compliant
- The plan-input affordance (load template / manual entry) follows DESIGN.md: 0pt corners (`Rectangle`, never `RoundedRectangle`), no shadows, `Font.Tokens.*` / General Sans, `ColorTokens.accent` ONLY on the hero readiness number (NOT here), 8pt-grid spacing. Reuse existing template-picker UI where it exists rather than building new.

### Build/test gate
- After file batches + at phase end: `cd "/Users/hanwen/Desktop/Tonus/workload management" && xcodebuild build -scheme "workload management" -destination "platform=iOS Simulator,id=CAF84E71-BB64-491D-87C8-875A0143B26D" -configuration Debug` must end `** BUILD SUCCEEDED **`. Known-alive sim id — never invent one.
- The main app target lists every `.swift` INDIVIDUALLY in project.pbxproj (NOT a synchronized group) — any NEW app-target file MUST be registered with explicit pbxproj entries or it won't compile in. (WorkloadAppTests IS synchronized — test files auto-discover.) Do NOT leave macOS " 2.swift" duplicate copies behind.
- Additive model changes: confirm the SwiftData schema still opens (no migration crash) via build + a smoke test.
</decisions>

<canonical_refs>
## Canonical References

- `.planning/research/v2-crossmodal-and-measurement.md` — plan-input data-model approach (reuse PrescribedWorkout, additive-nullable TemplateSet fields)
- `.planning/notes/core-redefinition-plan-aware-engine.md` — thesis + constraints
- `./CLAUDE.md`, `./DESIGN.md`
- Codebase: `WorkloadApp/Models/WorkoutTemplate.swift`, `WorkloadApp/Models/PrescribedWorkout.swift`, the existing template-picker / start-session UI under `WorkloadApp/Views/WorkoutLog/`, `WorkloadApp/Repositories/` (TemplateRepository)
</canonical_refs>

<deferred>
## Deferred
Verdict engine (43), verdict UI (44), measurement (45). Full program ingestion + MID/LONG horizons — out of v2.0.
</deferred>

---
*Phase: 42-plan-input-today-s-planned-session-adjustable-targets*
*Context gathered: 2026-06-13 by orchestrator*
