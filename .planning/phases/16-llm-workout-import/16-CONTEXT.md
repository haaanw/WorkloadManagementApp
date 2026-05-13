# Phase 16: LLM Workout Import - Context

**Gathered:** 2026-05-14
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can turn any workout they find — pasted text, a PDF from their coach, or a photo of a gym whiteboard — into a structured template in the app, reviewed and edited before saving. All LLM calls route through a Supabase Edge Function so the OpenAI API key never exists in the iOS binary.

</domain>

<decisions>
## Implementation Decisions

### Input Method UX
- **D-01:** Single import sheet with segmented picker for text/PDF/photo tabs. One "Import Workout" button in WorkoutLogView toolbar opens a sheet with three input modes.
- **D-02:** Text tab: multiline text field with "Parse" button. PDF tab: document picker (UTType.pdf). Photo tab: camera or photo library picker.

### Edge Function Architecture
- **D-03:** Single Supabase Edge Function (`parse-workout`) accepts plain text and returns structured JSON. Client handles PDF text extraction (PDFKit) and image OCR (Vision framework) on-device before sending text to the edge function.
- **D-04:** Edge function uses GPT-4o-mini with JSON Schema structured output enforcement per LLM-06. Response schema: exercise name, sets, reps, weight (optional), rest (optional), notes (optional).
- **D-05:** Edge function deployed in `supabase/functions/parse-workout/` with Deno runtime. OpenAI API key stored as Supabase secret, never in iOS binary.

### Parse Result Preview
- **D-06:** Reuse existing TemplateEditorSheet with pre-filled data from LLM response. User sees the same familiar editing interface, can modify any field before saving. No separate preview-only view needed.
- **D-07:** LLM response maps to WorkoutTemplate + ExerciseGroup + TemplateExercise + TemplateSet structure. Sport type and session type inferred by LLM if possible, default to .lifting/.strength.

### Error Handling UX
- **D-08:** Inline error banner with retry button on parse failure. Partial results display with missing fields highlighted — user can always fix manually.
- **D-09:** Loading state: full-sheet overlay with "Analyzing workout..." text and spinner. Parse typically takes 2-5 seconds.

### Claude's Discretion
- Edge function prompt engineering (system prompt for GPT-4o-mini)
- PDF text extraction approach (PDFKit vs other)
- Vision framework OCR configuration
- Timeout and retry logic for edge function calls

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` §LLM Workout Import — LLM-01 through LLM-06

### Existing Patterns
- `WorkloadApp/Services/InviteService.swift` lines 199-206 — `client.functions.invoke()` pattern for Supabase Edge Functions
- `WorkloadApp/Services/TemplateSharingService.swift` — Template creation from external data (importTemplate method)
- `WorkloadApp/Models/WorkoutTemplate.swift` — Template model structure
- `WorkloadApp/Models/ExerciseGroup.swift` — Exercise group model
- `WorkloadApp/Models/TemplateExercise.swift` — Template exercise model
- `WorkloadApp/Models/TemplateSet.swift` — Template set model

### Design System
- `DESIGN.md` — Font tokens, color tokens, spacing, 0pt corners, no shadows

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `client.functions.invoke()` — Supabase Edge Function call pattern (InviteService)
- `TemplateEditorSheet` — Full template editing UI (reuse for parsed result editing)
- `SyncService.decodeGroups()` / `encodeGroups()` — JSON ↔ ExerciseGroup conversion
- `SharpTextFieldStyle` — 0pt corner text field style (for text input)
- `WorkoutTemplate` init — Template creation with coachId, templateName, sportType, sessionType

### Established Patterns
- Snake_case Encodable structs for Supabase calls (TemplateSharingService, InviteService)
- @MainActor static methods on service enums (InviteService, TemplateSharingService)
- Template creation: new UUID, set athleteId, isAthleteOwned = true

### Integration Points
- WorkoutLogView toolbar — Add "Import Workout" button (alongside existing "Import Shared Template")
- AppContainer.supabaseClient — For edge function calls
- TemplateRepository — For saving imported template

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches for PDF extraction and OCR.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 16-llm-workout-import*
*Context gathered: 2026-05-14*
