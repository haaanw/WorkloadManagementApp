---
phase: 16-llm-workout-import
fixed_at: 2026-05-13T12:15:00Z
review_path: .planning/phases/16-llm-workout-import/16-REVIEW.md
iteration: 1
findings_in_scope: 5
fixed: 5
skipped: 0
status: all_fixed
---

# Phase 16: Code Review Fix Report

**Fixed at:** 2026-05-13T12:15:00Z
**Source review:** .planning/phases/16-llm-workout-import/16-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 5
- Fixed: 5
- Skipped: 0

## Fixed Issues

### CR-01: Missing Security-Scoped Resource Access for PDF File Import

**Files modified:** `WorkloadApp/Views/WorkoutLog/WorkoutImportSheet.swift`
**Commit:** 64ba6ac
**Applied fix:** Added `url.startAccessingSecurityScopedResource()` and a matching `defer { url.stopAccessingSecurityScopedResource() }` inside the `Task` block in `handlePDFImport`, so the security-scoped bookmark is held for the entire async operation (PDF extraction + parse). Without this, PDF reads fail on real devices due to sandbox permissions.

### WR-01: target_rpe from LLM Response Is Parsed but Silently Dropped

**Files modified:** `WorkloadApp/Services/WorkoutLLMImportService.swift`
**Commit:** 2cdf3d8
**Applied fix:** In `mapToGroupDrafts`, converted `target_rpe` (Double?) to `targetRIR` (Int?) using the standard formula RIR = 10 - RPE. This preserves the LLM-extracted RPE data by mapping it into the existing `TargetSetDraft.targetRIR` field, which the template editor already displays.

### WR-02: VNRecognizeTextRequest Continuation May Resume Twice

**Files modified:** `WorkloadApp/Services/WorkoutLLMImportService.swift`
**Commit:** a46d49e
**Applied fix:** Added a `hasResumed` boolean flag guarding both the completion handler and the `catch` block in `extractTextFromImage`. If Vision both calls the completion with an error and throws from `perform`, the second resume attempt is silently ignored instead of crashing.

### WR-03: CORS Allows All Origins in Edge Function

**Files modified:** `Supabase/functions/parse-workout/index.ts`
**Commit:** e7b4f07
**Applied fix:** Changed `Access-Control-Allow-Origin` from `"*"` to `"https://faros.app"`. Added a comment explaining this is a mobile-only endpoint -- mobile apps don't send CORS preflight, so this restriction primarily blocks unauthorized browser callers from consuming OpenAI credits.

### WR-04: TemplateEditorSheet Shown Conditionally on athlete but No Fallback

**Files modified:** `WorkloadApp/Views/WorkoutLog/WorkoutImportSheet.swift`
**Commit:** c2a03fa
**Applied fix:** Added an `else` branch to the `if let athleteId = athlete?.id` check inside the `.sheet` modifier. When athlete is nil, the sheet now displays "Unable to load athlete data." using project design tokens instead of rendering a blank view.

---

_Fixed: 2026-05-13T12:15:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
