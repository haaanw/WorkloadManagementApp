---
phase: 16-llm-workout-import
reviewed: 2026-05-13T12:00:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - Supabase/functions/parse-workout/index.ts
  - WorkloadApp/Services/WorkoutLLMImportService.swift
  - WorkloadApp/Views/TemplateEditorSheet.swift
  - WorkloadApp/Views/WorkoutLog/WorkoutImportSheet.swift
  - WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift
findings:
  critical: 1
  warning: 4
  info: 2
  total: 7
status: issues_found
---

# Phase 16: Code Review Report

**Reviewed:** 2026-05-13T12:00:00Z
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

The LLM workout import feature adds a Supabase Edge Function that proxies workout text to OpenAI for structured parsing, a Swift service for PDF/image OCR and edge function invocation, an import sheet with text/PDF/photo tabs, and integration into the existing WorkoutLogView and TemplateEditorSheet. The architecture is clean and follows project conventions (pure enum namespace for the service, draft models for editor state, pipeline-style data flow). However, there is one critical bug (missing security-scoped resource access for PDF files from the document picker), several warnings around dropped data and potential continuation misuse, and minor info items.

## Critical Issues

### CR-01: Missing Security-Scoped Resource Access for PDF File Import

**File:** `WorkloadApp/Views/WorkoutLog/WorkoutImportSheet.swift:108`
**Issue:** When a user selects a PDF via `fileImporter`, the returned URL is security-scoped. On iOS, you must call `url.startAccessingSecurityScopedResource()` before reading the file and `url.stopAccessingSecurityScopedResource()` when done. Without this, `PDFDocument(url:)` will fail with a permission error on real devices (it may work in the simulator). This is the most common cause of "could not read PDF" bugs in production.
**Fix:**
```swift
case .success(let url):
    let accessing = url.startAccessingSecurityScopedResource()
    defer { if accessing { url.stopAccessingSecurityScopedResource() } }
    handlePDFImport(url: url)
```
Note: since `handlePDFImport` launches an async Task, the `defer` would fire before the Task completes. The security-scoped access must be managed inside the Task, or the URL data must be copied synchronously before the `defer` fires. The cleanest fix is to pass the flag into `handlePDFImport` and stop access in the Task's completion:
```swift
case .success(let url):
    handlePDFImport(url: url) // move startAccessing inside handlePDFImport's Task

// In handlePDFImport:
private func handlePDFImport(url: URL) {
    isLoading = true
    errorMessage = nil
    Task {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            let text = try await WorkoutLLMImportService.extractTextFromPDF(url: url)
            let response = try await WorkoutLLMImportService.parseWorkoutText(
                text, client: container.supabaseClient
            )
            mapAndPresent(response)
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}
```

## Warnings

### WR-01: target_rpe from LLM Response Is Parsed but Silently Dropped

**File:** `WorkloadApp/Services/WorkoutLLMImportService.swift:208`
**Issue:** The edge function schema includes `target_rpe` per set, and `ParsedSet` decodes it (line 36), but `mapToGroupDrafts` maps `targetRIR: nil` and ignores `target_rpe` entirely (line 208). If the LLM returns RPE targets, users will never see them in the editor. This is a data loss bug -- the LLM correctly extracts RPE but it gets thrown away.
**Fix:**
```swift
TargetSetDraft(
    targetReps: set.target_reps,
    targetWeightKg: set.target_weight_kg,
    targetDurationSeconds: set.target_duration_seconds,
    targetRIR: nil,  // Consider mapping target_rpe to targetRIR or adding targetRPE to TargetSetDraft
    isWarmup: set.is_warmup
)
```
Either add a `targetRPE` field to `TargetSetDraft` and display it in the editor, or convert RPE to RIR (RIR = 10 - RPE) when mapping.

### WR-02: VNRecognizeTextRequest Continuation May Resume Twice

**File:** `WorkloadApp/Services/WorkoutLLMImportService.swift:144-180`
**Issue:** The `withCheckedThrowingContinuation` wrapping `VNRecognizeTextRequest` has a subtle risk: the completion handler (lines 146-168) can resume the continuation with a result, but if `handler.perform([request])` throws (line 178), the catch block also resumes the continuation (line 179). In the normal success path, the completion fires and then `perform` returns normally -- no double-resume. However, if the Vision framework both calls the completion with an error AND throws from `perform` (documented to be possible in edge cases), the continuation would be resumed twice, causing a crash. Using `withCheckedThrowingContinuation` (vs `withUnsafe...`) will at least trap this in debug builds rather than producing undefined behavior.
**Fix:** Guard with a flag or use a continuation wrapper that ignores subsequent resumes:
```swift
var hasResumed = false
let request = VNRecognizeTextRequest { request, error in
    guard !hasResumed else { return }
    hasResumed = true
    if let error { continuation.resume(throwing: error); return }
    // ... existing logic
}
// ...
do {
    try handler.perform([request])
} catch {
    guard !hasResumed else { return }
    hasResumed = true
    continuation.resume(throwing: error)
}
```

### WR-03: CORS Allows All Origins in Edge Function

**File:** `Supabase/functions/parse-workout/index.ts:6`
**Issue:** `Access-Control-Allow-Origin: "*"` allows any website to call this edge function. While Supabase Edge Functions require an `apikey` header for authorization, a wildcard CORS policy combined with the publishable anon key (which is public) means any website could invoke the function and consume OpenAI credits. The Supabase anon key is meant to be public but CORS should still be restricted to your app's domain or removed entirely (mobile apps do not send CORS preflight requests).
**Fix:**
```typescript
const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "https://your-app-domain.com",
  // Or remove CORS headers entirely if only mobile clients call this
};
```

### WR-04: TemplateEditorSheet Shown Conditionally on athlete but No Fallback

**File:** `WorkloadApp/Views/WorkoutLog/WorkoutImportSheet.swift:131-141`
**Issue:** The `.sheet(isPresented: $showEditor)` content checks `if let athleteId = athlete?.id` but provides no `else` branch. If `athlete` is nil (e.g., during bootstrap or data migration), `showEditor` becomes `true` but the sheet renders as an empty view. The user sees a blank sheet with no way to proceed. The same pattern appears in `WorkoutLogView.swift:301` for the template editor sheet.
**Fix:** Add an else branch that shows an error message or dismisses:
```swift
.sheet(isPresented: $showEditor, onDismiss: { dismiss() }) {
    if let athleteId = athlete?.id {
        TemplateEditorSheet(/* ... */)
    } else {
        Text("Unable to load athlete data.")
            .font(.Tokens.body)
            .foregroundStyle(ColorTokens.text2)
    }
}
```

## Info

### IN-01: User Input Passed Directly as LLM Prompt Content

**File:** `Supabase/functions/parse-workout/index.ts:177`
**Issue:** The raw `workout_text` from the user is sent directly as the `user` message content to OpenAI. While the structured output schema constrains the response format, a user could craft prompt injection text (e.g., "Ignore all previous instructions...") to manipulate the LLM's behavior within the schema constraints. The 10,000 character limit and strict JSON schema mitigate the risk, but consider adding a note that this is an accepted trade-off or adding a simple prefix like "Parse this workout text:\n\n" to reduce injection surface.
**Fix:** Wrap user input:
```typescript
{ role: "user", content: `Parse this workout text:\n\n${workout_text}` }
```

### IN-02: Retry Button for Photo Tab Does Nothing

**File:** `WorkloadApp/Views/WorkoutLog/WorkoutImportSheet.swift:401-402`
**Issue:** `retryLastAction()` has a `case .photo: break` -- tapping Retry after a photo parse failure does nothing. For text, it re-parses; for PDF, it re-opens the picker. Photo has no retry path because the image reference is not stored.
**Fix:** Store the last imported `UIImage` in a `@State` property and retry OCR + parse on it, or change the retry button text to "Try Again" and re-open the camera/library picker.

---

_Reviewed: 2026-05-13T12:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
