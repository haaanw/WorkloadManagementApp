# Phase 11: Template Management & Creation - Context

**Gathered:** 2026-05-09
**Status:** Ready for planning

<domain>
## Phase Boundary

Athletes can build and manage a personal library of reusable training templates with full CRUD operations. Includes manual creation, save-from-session, and a schedule-aware carousel display in the Workout Log tab. No template-driven workout launching (Phase 12), no suggestion engine (Phase 12), no LLM import (v1.3).

</domain>

<decisions>
## Implementation Decisions

### Template Display & Navigation
- **D-01:** Templates live inside the Workout Log tab — no new tab, no separate nav destination.
- **D-02:** Display as a centered carousel of template cards. Today's scheduled template is centered and enlarged; adjacent templates shown smaller. Uses `scheduledDays` weekday match (already on WorkoutTemplate model).
- **D-03:** Fallback when no template scheduled today: center on most recently used template (`lastUsedAt`). Pattern-based learning deferred to Phase 12 `TemplateSuggestionEngine`.
- **D-04:** Carousel tap action: Claude's discretion (start workout directly or show preview first).

### Save-as-Template Flow
- **D-05:** Save-as-template is a toggle/checkbox in the existing finish workout confirmation dialog (where RPE is set). No separate entry point needed.
- **D-06:** Confirmation/editing step after checking the toggle: Claude's discretion (quick save with auto-naming vs. opening TemplateEditorSheet pre-filled with session data).
- **D-07:** Save-as-template always creates athlete-owned template (`isAthleteOwned=true`) regardless of whether session was from a coach prescription (carried from Phase 9 D-03).

### Template Editor
- **D-08:** Reuse existing `TemplateEditorSheet` for athletes — same groups/exercises/sets editing, sport/type pickers, notes field. No simplified version.
- **D-09:** Add scheduled days picker to editor: weekday toggle row (M T W T F S S) writing to `scheduledDays: [Int]` (ISO 8601, 1=Mon...7=Sun).
- **D-10:** Add favorite toggle to editor.
- **D-11:** Editor sets `isAthleteOwned=true` and `athleteId` automatically for athlete-created templates.

### Management Actions
- **D-12:** Swipe left on carousel card reveals destructive actions (archive, delete).
- **D-13:** Long-press on carousel card shows iOS context menu with all actions: Edit, Duplicate, Favorite/Unfavorite, Archive, Delete.
- **D-14:** Delete requires confirmation. Archive is soft-delete (reversible). Both are existing patterns in `TemplateRepository`.

### Claude's Discretion
- Carousel tap action: start workout directly vs. preview-then-start (D-04)
- Save-as-template confirmation step: quick save vs. editor sheet (D-06)
- Carousel card visual design (sizing, spacing, information density)
- Empty state when user has zero templates (CTA to create first template)
- Whether "New Template" appears as a card in the carousel or as a separate button

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Models & Repository
- `WorkloadApp/Models/WorkoutTemplate.swift` — WorkoutTemplate, ExerciseGroup, TemplateExercise, TemplateSet models (all fields including isAthleteOwned, scheduledDays, isFavorite, isArchived already shipped in Phase 9)
- `WorkloadApp/Repositories/TemplateRepository.swift` — fetchAthleteTemplates, fetchFavorites, save, duplicate, archive, delete operations (already athlete-ready)

### Existing Views to Adapt
- `WorkloadApp/Views/TemplateEditorSheet.swift` — Full editor with GroupDraft/ExerciseDraft/TargetSetDraft models, GroupEditorCard, TemplateExerciseCard, TargetSetRow components. Add schedule picker + favorite toggle here.
- `WorkloadApp/Views/TemplateListView.swift` — Coach template list (reference for patterns, but carousel replaces this for athletes)
- `WorkloadApp/Views/WorkoutLog/ActiveWorkoutSheet.swift` — Finish confirmation dialog where save-as-template toggle goes
- `WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift` — Where carousel section gets added

### Design System
- `DESIGN.md` — 0pt border radius, no shadows, DM Sans, accent only on readiness score, 8pt grid

### Requirements
- `.planning/REQUIREMENTS.md` — TMPL-01, TMPL-02, TMPL-05
- `.planning/ROADMAP.md` — Phase 11 success criteria

### Prior Context
- `.planning/phases/09-foundation-cold-start-engine/09-CONTEXT.md` — D-01 through D-03 (template ownership model, save-as-template always athlete-owned)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `TemplateEditorSheet` — Full group/exercise/set editor with draft models. Reuse directly, add schedule + favorite fields.
- `TemplateRepository` — All CRUD operations ready for athlete-owned templates. No new repo methods needed.
- `ExercisePickerView` — Exercise picker already used by both ActiveWorkoutSheet and TemplateEditorSheet.
- `GroupEditorCard`, `TemplateExerciseCard`, `TargetSetRow` — All sub-components of editor, fully built.
- `GroupDraft`, `ExerciseDraft`, `TargetSetDraft` — Local draft models for editor state.

### Established Patterns
- Coach TemplateListView uses `@Query` + `FetchDescriptor` for template fetching
- TemplateEditorSheet uses draft models (`GroupDraft`, etc.) for editing state, converts to SwiftData models on save
- `ActiveWorkoutSheet.saveSession()` is where save-as-template toggle integrates
- SyncService.pushWorkoutTemplates() already handles sync after template save

### Integration Points
- `WorkoutLogView` — Add carousel section above session history
- `ActiveWorkoutSheet` finish confirmation alert — Add save-as-template toggle
- `TemplateEditorSheet` — Add scheduledDays picker and isFavorite toggle
- `AppRouter`/`MainTabView` — No changes needed (templates inside existing Workout Log tab)

</code_context>

<specifics>
## Specific Ideas

- Carousel auto-scrolls to center today's template on appear using `scheduledDays` weekday match (ISO 8601: 1=Mon...7=Sun matching `Calendar.current.component(.weekday, from: .now)` converted to ISO)
- Centered card rendered larger, adjacent cards smaller — standard iOS carousel pattern with `ScrollView(.horizontal)` + `GeometryReader` scale transform
- Long-press context menu uses SwiftUI `.contextMenu` modifier
- Swipe actions may need custom implementation since carousel cards aren't List rows (no built-in `.swipeActions`)

</specifics>

<deferred>
## Deferred Ideas

- Pattern-based template suggestion (learning which template user picks by day) — Phase 12 `TemplateSuggestionEngine` (TMPL-08)
- Template-driven workout launching with pre-filled exercises — Phase 12 (TMPL-03, TMPL-04)
- Dashboard quick-start cards — Phase 12 (TMPL-06)
- ProgressionEngine overlay on template targets — Phase 12 (TMPL-07)

</deferred>

---

*Phase: 11-template-management-creation*
*Context gathered: 2026-05-09*
