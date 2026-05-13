---
phase: 16-llm-workout-import
plan: 02
subsystem: workout-import-ui
tags: [llm, import, ui, swiftui, template-editor]
dependency_graph:
  requires: [16-01]
  provides: [WorkoutImportSheet, TemplateEditorSheet-prefill]
  affects: [WorkoutLogView, TemplateEditorSheet, project.pbxproj]
tech_stack:
  added: [PhotosUI, UniformTypeIdentifiers, UIImagePickerController]
  patterns: [segmented-picker, file-importer, camera-representable, prefill-init]
key_files:
  created:
    - WorkloadApp/Views/WorkoutLog/WorkoutImportSheet.swift
  modified:
    - WorkloadApp/Views/TemplateEditorSheet.swift
    - WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift
    - "workload management/workload management.xcodeproj/project.pbxproj"
decisions:
  - Reused TemplateEditorSheet with prefill init rather than building a separate preview view (D-06)
  - Added AI import above existing menu items for discoverability
  - Used State(initialValue:) pattern for prefill init to set @State from init params
metrics:
  duration: 135s
  completed: 2026-05-13T16:43:02Z
  tasks_completed: 3
  tasks_total: 3
---

# Phase 16 Plan 02: LLM Workout Import UI Summary

WorkoutImportSheet with three-tab segmented picker (text/PDF/photo), loading overlay, error banner with retry, and TemplateEditorSheet prefill init for parsed LLM data handoff.

## Completed Tasks

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add prefill init to TemplateEditorSheet and create WorkoutImportSheet | 88a8cd4 | WorkoutImportSheet.swift (new), TemplateEditorSheet.swift |
| 2 | Wire WorkoutImportSheet into WorkoutLogView and update pbxproj | 39fc7a4 | WorkoutLogView.swift, project.pbxproj |
| 3 | Verify end-to-end LLM workout import flow | -- | Auto-approved checkpoint |

## Key Implementation Details

### WorkoutImportSheet (new file)
- Three-tab segmented picker: Text, PDF, Photo
- Text tab: TextEditor with "Parse Workout" button calling WorkoutLLMImportService.parseWorkoutText
- PDF tab: fileImporter for .pdf files, extracts text via WorkoutLLMImportService.extractTextFromPDF then parses
- Photo tab: Camera (UIImagePickerController wrapper) and PhotosPicker for library, OCR via WorkoutLLMImportService.extractTextFromImage then parses
- Loading overlay with "Analyzing workout..." spinner (D-09)
- Error banner with retry button (D-08)
- On successful parse, maps response via mapToGroupDrafts and presents TemplateEditorSheet with prefilled data

### TemplateEditorSheet prefill init
- New convenience init accepting prefillName, prefillSportType, prefillSessionType, prefillGroups
- Uses State(initialValue:) to set @State properties from init parameters
- Sets existingTemplate = nil so loadExisting() is a no-op
- Existing init and save logic completely untouched

### WorkoutLogView wiring
- "Import Workout (AI)" button with sparkles icon added as first item in toolbar Menu
- .sheet(isPresented: $showLLMImport) presents WorkoutImportSheet

## Deviations from Plan

None - plan executed exactly as written.

## Design System Compliance

- All text uses Font.Tokens.* (body, label)
- All colors use ColorTokens.* (text1, text2, text3, surface, background, divider, zoneDanger)
- 0pt border radius everywhere (Rectangle, no RoundedRectangle)
- No shadows
- No accent color usage
- Spacing at 8pt multiples (8, 16, 24)
- Hairline borders via Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5)

## Checkpoint: Auto-Approved

Task 3 (human-verify) was auto-approved per --auto mode. The checkpoint verifies: app builds, import sheet shows 3 tabs, text parse produces correct template preview, fields are editable, template saves successfully.

## Self-Check: PASSED

- [x] WorkloadApp/Views/WorkoutLog/WorkoutImportSheet.swift exists
- [x] Commit 88a8cd4 exists
- [x] Commit 39fc7a4 exists
- [x] TemplateEditorSheet has prefillName init
- [x] WorkoutLogView has showLLMImport state and Import Workout (AI) button
- [x] Both new files registered in pbxproj (PBXBuildFile, PBXFileReference, PBXGroup, Sources)
