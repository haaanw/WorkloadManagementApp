---
phase: 16-llm-workout-import
plan: 01
subsystem: services
tags: [llm, edge-function, ocr, pdf, openai, supabase]
dependency_graph:
  requires: []
  provides: [parse-workout-edge-function, workout-llm-import-service]
  affects: [supabase/functions, WorkloadApp/Services]
tech_stack:
  added: [OpenAI GPT-4o-mini structured outputs, Vision OCR, PDFKit text extraction]
  patterns: [Supabase Edge Function proxy, VNRecognizeTextRequest with reading-order sort, PDFKit-to-OCR fallback]
key_files:
  created:
    - supabase/functions/parse-workout/index.ts
    - WorkloadApp/Services/WorkoutLLMImportService.swift
  modified: []
decisions:
  - Used raw fetch() for OpenAI call in edge function (no npm dependencies)
  - TargetSetDraft.targetRIR set to nil since LLM schema uses target_rpe (RPE maps differently from RIR)
  - OCR sorting uses 0.01 threshold for Y-coordinate grouping to handle slight vertical misalignment
metrics:
  duration: 114s
  completed: 2026-05-13T16:38:00Z
  tasks: 2/2
  files_created: 2
  files_modified: 0
---

# Phase 16 Plan 01: Edge Function and Import Service Summary

Supabase Edge Function proxying GPT-4o-mini with JSON Schema structured outputs, plus Swift service with PDFKit text extraction, Vision OCR fallback, and response-to-GroupDraft mapping.

## Completed Tasks

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create Supabase Edge Function for workout parsing | 27a908c | supabase/functions/parse-workout/index.ts |
| 2 | Create WorkoutLLMImportService with PDF/OCR extraction and edge function call | 32f011b | WorkloadApp/Services/WorkoutLLMImportService.swift |

## Task Details

### Task 1: Edge Function

Created `supabase/functions/parse-workout/index.ts` with:
- `Deno.serve` handler accepting `workout_text` in JSON body
- Input validation: rejects missing/empty text, enforces 10,000 character limit
- OpenAI API key accessed via `Deno.env.get('OPENAI_API_KEY')` only
- GPT-4o-mini call with `response_format: { type: "json_schema" }` and `strict: true`
- System prompt: extraction-only behavior, kg normalization, null for unknown fields
- WORKOUT_SCHEMA with all enum values matching app's Swift enums exactly
- CORS headers for Supabase client compatibility
- 502 error response on OpenAI failures

### Task 2: WorkoutLLMImportService

Created `WorkloadApp/Services/WorkoutLLMImportService.swift` as an enum with static methods:
- `ParsedWorkoutResponse` Decodable struct matching edge function JSON schema
- `ImportError` enum with `LocalizedError` conformance (5 cases)
- `parseWorkoutText(_:client:)` - @MainActor edge function call via `client.functions.invoke`
- `extractTextFromPDF(url:)` - PDFKit text layer extraction with Vision OCR fallback for scanned PDFs
- `extractTextFromImage(_:)` - VNRecognizeTextRequest with Y-descending, X-ascending sort for reading order
- `mapToGroupDrafts(_:)` - Maps response to (name, sportType, sessionType, groups) tuple using GroupDraft/ExerciseDraft/TargetSetDraft

**Note:** The Swift file is NOT yet added to the Xcode project (.pbxproj). Plan 02 will handle pbxproj updates for all new files together.

## Deviations from Plan

None - plan executed exactly as written.

## Verification Results

All verification checks passed:
- Edge function contains: Deno.serve, WORKOUT_SCHEMA, gpt-4o-mini, json_schema, Deno.env.get
- Swift service contains: ParsedWorkoutResponse, extractTextFromPDF, extractTextFromImage, parseWorkoutText, mapToGroupDrafts
- No OpenAI API key anywhere in iOS source code
- VNRecognizeTextRequest used (not RecognizeTextRequest) for iOS 17 compatibility
- Zero new Swift package dependencies (all Apple frameworks)

## Self-Check: PASSED

All files exist, all commits verified, no unexpected deletions.
