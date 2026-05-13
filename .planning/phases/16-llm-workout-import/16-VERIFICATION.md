---
phase: 16-llm-workout-import
verified: 2026-05-13T17:00:00Z
status: gaps_found
score: 4/5
overrides_applied: 0
gaps:
  - truth: "User can paste freeform workout text and see it parsed into a structured template preview with exercises, sets, reps, and weights"
    status: failed
    reason: "WorkoutImportSheet.swift calls container.supabaseClient (lines 343, 362, 379) but AppContainer only exposes a property named supabase. This is an undefined member reference — the code will not compile."
    artifacts:
      - path: "WorkloadApp/Views/WorkoutLog/WorkoutImportSheet.swift"
        issue: "container.supabaseClient used on lines 343, 362, 379; AppContainer property is container.supabase (see AppContainer.swift line 11 and all other call sites: ShareImportSheet.swift line 112, ShareCodeSheet.swift line 161, ProfileView.swift lines 611, 780)"
    missing:
      - "Replace all three occurrences of container.supabaseClient with container.supabase in WorkoutImportSheet.swift"
human_verification:
  - test: "Build the Xcode project and confirm zero compile errors"
    expected: "Clean build with no 'value of type AppContainer has no member supabaseClient' errors"
    why_human: "Cannot run xcodebuild in this environment; compile verification requires Xcode"
  - test: "End-to-end text import: paste workout text, tap Parse Workout, observe TemplateEditorSheet pre-filled"
    expected: "After 2-5 seconds, TemplateEditorSheet appears with exercises, sets, reps, and weights populated from the pasted text"
    why_human: "Requires a deployed Supabase Edge Function with OPENAI_API_KEY set and a running app"
  - test: "End-to-end PDF import: select a digital PDF with workout content"
    expected: "Text layer extracted, parsed by LLM, TemplateEditorSheet appears pre-filled"
    why_human: "Requires file system access, deployed edge function, and running app"
  - test: "End-to-end photo import: choose a library photo of typed workout text"
    expected: "OCR extracts text, LLM parses it, TemplateEditorSheet appears pre-filled"
    why_human: "Requires photo library access and running app"
  - test: "Edit fields in TemplateEditorSheet after import: change an exercise name, adjust reps/weight"
    expected: "All fields are editable inline; changes persist when Save is tapped"
    why_human: "UI interaction cannot be verified programmatically"
---

# Phase 16: LLM Workout Import — Verification Report

**Phase Goal:** Users can turn any workout they find — pasted text, a PDF from their coach, or a photo of a gym whiteboard — into a structured template in the app, reviewed and edited before saving
**Verified:** 2026-05-13T17:00:00Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can paste freeform workout text and see it parsed into a structured template preview with exercises, sets, reps, and weights | FAILED | WorkoutImportSheet.swift references `container.supabaseClient` (lines 343, 362, 379) — property does not exist on AppContainer. App will not compile. AppContainer exposes `supabase` (AppContainer.swift line 11). All other call sites in the codebase use `container.supabase`. |
| 2 | User can select a PDF file and see its extracted content parsed into a template preview | FAILED | Same compile blocker as above — `container.supabaseClient` on line 362 prevents build. The PDF extraction logic itself (WorkoutLLMImportService.extractTextFromPDF with PDFKit + Vision OCR fallback) is correctly implemented and substantive. |
| 3 | User can take a photo or choose from library and see OCR-extracted text parsed into a template preview | FAILED | Same compile blocker — `container.supabaseClient` on line 379. The OCR implementation (VNRecognizeTextRequest, Y-descending sort, UIImagePickerController wrapper, PhotosPicker) is correctly implemented. |
| 4 | User can edit any field in the parsed template preview (exercise names, sets, reps, weights) before saving | VERIFIED | TemplateEditorSheet prefill init exists (TemplateEditorSheet.swift lines 28-42) using `State(initialValue:)` for name, sportType, sessionType, and groups. The existing editor UI (TextField for name, exercise name fields, rep/weight inputs) remains fully editable. mapAndPresent() sets all state variables and presents TemplateEditorSheet via .sheet. |
| 5 | All LLM calls route through a Supabase Edge Function — the OpenAI API key never exists in the iOS binary | VERIFIED | supabase/functions/parse-workout/index.ts exists and reads `Deno.env.get('OPENAI_API_KEY')`. No OpenAI key found anywhere in WorkloadApp/ (grep confirmed). WorkoutLLMImportService calls `client.functions.invoke("parse-workout")`. |

**Score:** 2/5 truths verified (Truths 1, 2, 3 fail due to a single shared compile-time error; Truths 4 and 5 are verified)

**Root cause:** A single property name mismatch — `supabaseClient` vs `supabase` — blocks all three input-mode flows at compile time.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `supabase/functions/parse-workout/index.ts` | Deno edge function proxying OpenAI structured outputs | VERIFIED | Exists. Contains `Deno.serve`, `WORKOUT_SCHEMA`, `gpt-4o-mini`, `json_schema` response_format, `Deno.env.get('OPENAI_API_KEY')`. Input validation (10k char limit, empty check). CORS headers present. Raw fetch() used, no npm deps. |
| `WorkloadApp/Services/WorkoutLLMImportService.swift` | PDF extraction, OCR, edge function call, response mapping | VERIFIED | Exists. Contains `ParsedWorkoutResponse`, `ImportError`, `parseWorkoutText`, `extractTextFromPDF`, `extractTextFromImage`, `mapToGroupDrafts`. VNRecognizeTextRequest with Y-descending sort. PDFKit text-layer with Vision OCR fallback. |
| `WorkloadApp/Views/WorkoutLog/WorkoutImportSheet.swift` | Import UI with text/PDF/photo tabs | STUB (compile error) | File exists and is structurally complete (NavigationStack, segmented picker, all three tab views, loading overlay, error banner, CameraPickerView UIViewControllerRepresentable). However, `container.supabaseClient` on lines 343, 362, 379 is an undefined member — will not compile. |
| `WorkloadApp/Views/TemplateEditorSheet.swift` | Pre-fill init for LLM-parsed data | VERIFIED | Prefill init added at lines 28-42. Uses `State(initialValue:)` correctly. Existing init and `loadExisting()` untouched. |
| `WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift` | Import Workout (AI) button in toolbar menu | VERIFIED | `showLLMImport` state (line 26), "Import Workout (AI)" button with sparkles icon in Menu (lines 187-190), `.sheet(isPresented: $showLLMImport)` presenting WorkoutImportSheet with `.environment(container)` (lines 286-289). |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| WorkoutImportSheet | WorkoutLLMImportService | `WorkoutLLMImportService.parseWorkoutText/extractTextFromPDF/extractTextFromImage` calls | WIRED (compile error) | Pattern `WorkoutLLMImportService\.` found at lines 342, 360-362, 377-379. Calls are structurally correct but blocked by `supabaseClient` naming error. |
| WorkoutImportSheet | TemplateEditorSheet | `TemplateEditorSheet(coachId:prefillName:prefillSportType:prefillSessionType:prefillGroups:)` in `.sheet` | WIRED | Lines 131-144. Uses prefill init. Also passes `.environment(container)`. |
| WorkoutLogView | WorkoutImportSheet | `showLLMImport` state + `.sheet(isPresented:)` | WIRED | Lines 286-289. `WorkoutImportSheet()` presented with container environment. |
| WorkoutLLMImportService | parse-workout edge function | `client.functions.invoke("parse-workout")` | WIRED | Line 79 in WorkoutLLMImportService.swift. Correct Supabase Swift SDK pattern, matches InviteService pattern. |
| parse-workout edge function | OpenAI API | `fetch("https://api.openai.com/v1/chat/completions")` | WIRED | Edge function line 167. Correct URL, Bearer token from env, json_schema response_format with strict:true. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| WorkoutImportSheet | `parsedGroups / parsedName / parsedSportType / parsedSessionType` | `mapAndPresent()` called after `WorkoutLLMImportService.parseWorkoutText()` response | Yes — LLM response decoded and mapped to GroupDraft/ExerciseDraft/TargetSetDraft | FLOWING (pending compile fix) |
| parse-workout/index.ts | `parsed` | `JSON.parse(data.choices[0].message.content)` from OpenAI | Yes — real GPT-4o-mini response with json_schema enforcement | FLOWING (requires deployed function + secret) |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Edge function file exists with required patterns | `grep -c "Deno.serve\|gpt-4o-mini\|json_schema\|OPENAI_API_KEY" supabase/functions/parse-workout/index.ts` | 4 matches | PASS |
| No OpenAI key in iOS source | `grep -r "sk-\|OPENAI_API_KEY" WorkloadApp/` | No matches | PASS |
| Both new Swift files in pbxproj Sources | `grep "WorkoutLLMImportService\|WorkoutImportSheet" project.pbxproj` | 6 entries (PBXFileReference x2, PBXBuildFile x2, PBXGroup x2) | PASS |
| AppContainer has `supabase` not `supabaseClient` | `grep "let supabase" WorkloadApp/App/AppContainer.swift` | `let supabase: SupabaseClient` at line 11 | CONFIRMED — naming mismatch |
| supabaseClient used in WorkoutImportSheet | `grep -c "supabaseClient" WorkloadApp/Views/WorkoutLog/WorkoutImportSheet.swift` | 3 occurrences (lines 343, 362, 379) | FAIL — undefined member |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| LLM-01 | 16-02 | User can paste workout text and have it parsed into a template via LLM | BLOCKED | WorkoutImportSheet text tab + handleTextParse() exist but compile error prevents execution |
| LLM-02 | 16-02 | User can import a PDF file and have its text extracted and parsed into a template | BLOCKED | WorkoutImportSheet PDF tab + handlePDFImport() exist but compile error prevents execution |
| LLM-03 | 16-02 | User can take a photo or select from library and have OCR + LLM parse it into a template | BLOCKED | WorkoutImportSheet photo tab + handlePhotoImport() exist but compile error prevents execution |
| LLM-04 | 16-02 | User sees parsed template preview with exercises/sets/reps before saving | VERIFIED (code) | TemplateEditorSheet prefill init implemented. mapAndPresent() → sets state → showEditor = true → sheet presents TemplateEditorSheet. All fields editable. |
| LLM-05 | 16-01 | LLM parsing runs via Supabase Edge Function proxy (API key never in iOS binary) | VERIFIED | parse-workout edge function exists with Deno.env.get(). No key in iOS. invoke("parse-workout") in WorkoutLLMImportService. |
| LLM-06 | 16-01 | LLM import uses GPT-4o-mini with structured output (JSON Schema enforcement) | VERIFIED | Edge function uses gpt-4o-mini, response_format type "json_schema", strict: true, WORKOUT_SCHEMA with additionalProperties:false and required arrays. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| WorkoutImportSheet.swift | 343, 362, 379 | `container.supabaseClient` — undefined member on AppContainer | BLOCKER | App will not compile. All three input modes (text, PDF, photo) are non-functional. Fix: replace `supabaseClient` with `supabase` (3 occurrences). |

### Human Verification Required

#### 1. Build Verification

**Test:** Open Xcode, build the scheme for the simulator
**Expected:** Zero compile errors after fixing `supabaseClient` -> `supabase`
**Why human:** Cannot invoke xcodebuild in this environment

#### 2. Text Parse End-to-End

**Test:** In simulator (with edge function deployed), tap "..." in Workout Log, select "Import Workout (AI)", paste `Upper Body Day\nBench Press 4x8 @80kg\nBarbell Row 4x8 @70kg`, tap "Parse Workout"
**Expected:** "Analyzing workout..." overlay appears, then TemplateEditorSheet opens pre-filled with 2 exercises, 4 sets each, weights 80kg and 70kg
**Why human:** Requires deployed Supabase edge function with OPENAI_API_KEY secret and running app

#### 3. Field Editing

**Test:** After a successful text import, modify the exercise name, change reps from 8 to 10, change weight, tap Save
**Expected:** Template saves with the edited values (not the original LLM values)
**Why human:** UI interaction cannot be verified programmatically

#### 4. PDF Import

**Test:** Switch to PDF tab, select a PDF containing workout content
**Expected:** Text extracted (digital PDF: text layer; scanned: Vision OCR), parsed, TemplateEditorSheet pre-filled
**Why human:** Requires file system and running app

#### 5. Photo Import

**Test:** Switch to Photo tab, select a photo of typed workout text from library
**Expected:** VNRecognizeTextRequest extracts text in reading order, LLM parses, TemplateEditorSheet pre-filled
**Why human:** Requires photo library access and running app

### Gaps Summary

One gap blocks the phase goal:

**Root cause:** `container.supabaseClient` is used in three places in WorkoutImportSheet.swift (lines 343, 362, 379) but the property on AppContainer is named `supabase` (AppContainer.swift line 11). Every other view in the codebase correctly uses `container.supabase` (ShareImportSheet.swift line 112, ShareCodeSheet.swift line 161, ProfileView.swift lines 611 and 780). This single naming error prevents the project from compiling, which blocks Success Criteria 1, 2, and 3.

**Fix is trivial:** Replace `container.supabaseClient` with `container.supabase` on lines 343, 362, and 379 of WorkoutImportSheet.swift. No logic changes are required.

Success Criteria 4 (editing) and 5 (API key security) are implemented correctly and need only a build + human run-through to fully confirm.

---

_Verified: 2026-05-13T17:00:00Z_
_Verifier: Claude (gsd-verifier)_
