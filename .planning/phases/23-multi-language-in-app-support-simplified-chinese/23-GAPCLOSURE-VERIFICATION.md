---
phase: 23-zh-hans-gap-closure
verified: 2026-05-31T00:00:00Z
status: gaps_found
score: 3/4 must-haves verified
re_verification:
  previous_status: n/a
  note: "Verifies the zh-Hans gap-closure workflow at HEAD 6a8fca1"
gaps:
  - truth: "Core screens have 0 remaining user-visible hardcoded English (app no longer half-English under zh-Hans)"
    status: failed
    reason: >-
      ~35-43 genuine user-visible English literals remain on CORE screens, NOT present
      as keys in the String Catalog. SwiftUI's LocalizedStringKey lookup fails for these,
      so they render verbatim English under the zh-Hans locale. Common toolbar labels
      ("Cancel", "Add", "Done", "Finish", "Close", "Delete") are not keyed AT ALL, and
      appear across nearly every sheet on the core WorkoutLog and Profile screens.
    artifacts:
      - path: "WorkloadApp/Views/WorkoutLog/ActiveWorkoutSheet.swift"
        issue: 'Hardcoded: "Cancel"(117), "Finish"(122), "Done"(672), "PRE-FILLED FROM LAST SESSION"(750), "Add Set"(796), "Session Name (optional)"(52), "Fill last"(962), "Fill suggested"(975), "sec"/"min"(909/920) — none in catalog'
      - path: "WorkloadApp/Views/WorkoutLog/ExercisePickerView.swift"
        issue: '"Exercise name"(199), "Category"(202), "Muscle Group (optional)"(213), "Add Exercise"(237 navTitle), "Cancel"(133/241), "Add"(244), "Custom"(103), "Delete"(118) — none in catalog'
      - path: "WorkloadApp/Views/WorkoutLog/WorkoutImportSheet.swift"
        issue: '"Select a PDF file containing your workout"(221), "Choose PDF"(231), "Take a photo of a workout or choose from your library"(249), "Camera"(260), "Library"(279), "Analyzing workout..."(302), "Retry"(322), "Cancel"(97) — none in catalog'
      - path: "WorkloadApp/Views/WorkoutLog/WorkoutImportBanner.swift"
        issue: '"IMPORT FROM WATCH"(13), "Add"(68) — not in catalog'
      - path: "WorkloadApp/Views/Profile/TrainingProfileSheet.swift"
        issue: '"\(count) selected"(300) and "\(count) area/areas"(333) interpolated English not keyed'
      - path: "WorkloadApp/Views/Profile/InviteConfirmationSheet.swift"
        issue: '"Cancel"(79) not in catalog'
      - path: "WorkloadApp/Views/WorkoutLog/TemplatePreviewSheet.swift"
        issue: '"Cancel"(79), "Edit Template"(84) not in catalog'
      - path: "WorkloadApp/Views/WorkoutLog/TemplatePickerSheet.swift, TemplateCarouselSection.swift, TextTemplateImportSheet.swift, ShareImportSheet.swift"
        issue: '"Cancel"/"Close" toolbar buttons not in catalog'
    missing:
      - "Key + translate the ~35 genuine residual literals (toolbar Cancel/Add/Done/Finish/Close/Delete, WorkoutImportSheet sentences, ExercisePicker form labels, navigationTitle 'Add Exercise', WorkoutImportBanner) into Localizable.xcstrings with byte-identical en defaultValues"
      - "Decide on borderline unit abbreviations 'sec'/'min'/'m' (TextField placeholders) — key or justify"
human_verification:
  - test: "Launch app on a zh-Hans simulator/device, open a workout (ActiveWorkoutSheet), the Add-Exercise picker, and Watch/PDF import sheets"
    expected: "All toolbar buttons, titles, and labels render in Chinese"
    why_human: "Confirms the static residual maps to visible English at runtime under the locale"
---

# Phase 23 zh-Hans Gap-Closure Verification Report

**Phase Goal:** Close the in-app localization gap so the Chinese (zh-Hans) build is no longer ~half English — every user-visible string keyed + translated, English behavior byte-identical, algorithm fences green.

**Verified at:** HEAD `6a8fca1f9407048449b770efedc74602b4236535`
**Status:** gaps_found

## Goal Achievement — Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Catalog has 100% zh-Hans coverage (every key translated) | VERIFIED | 679/679 keys have a non-empty zh-Hans value; 0 missing; 0 `shouldTranslate=false` shortcuts; plural variations present |
| 2 | Converted strings keep exact English (byte-identical) | VERIFIED | 196 `defaultValue` strings across 49 files; all literal conversions verbatim; 19 interpolation→format-specifier conversions hand-verified byte-identical (e.g. `"RPE: \(Int(rpe))"`→`format("RPE: %d",...)`); plural `coach.prescribe.exerciseCount` en one/other = "%d exercise"/"%d exercises" matches old `count==1 ? ""`:"s"` |
| 3 | Algorithm fences green + unmodified behavior | VERIFIED | `xcodebuild test` exit `** TEST SUCCEEDED **`; 14/14 fence cases pass, 0 fail. Critically `AutoregulationFlagFenceTests.test_flagOff_recommendFlagged_isByteIdenticalToLegacy_fullMatrix()` PASSED (golden snapshot intact). BaselineTierFence (4) + DualRunFlagFence + AutoregulationFlagFence (4) all green |
| 4 | 0 residual user-visible hardcoded English on core screens | FAILED | ~35-43 genuine English literals on core screens (Dashboard/Recovery/Workload/WorkoutLog/Profile/Onboarding/Auth) are NOT catalog keys → render English under zh-Hans. Common labels "Cancel"/"Add"/"Done"/"Finish"/"Close"/"Delete" not keyed at all |

**Score:** 3/4 truths verified

## Catalog Coverage (Truth 1)

- sourceLanguage: `en`; total keys: **679**; zh-Hans covered: **679 (100.0%)**
- 0 empty zh values (single + plural variation forms checked); 0 keys bypassing translation via `shouldTranslate=false`
- Commit `2add0b0` added 346 keys; `6a8fca1` translated the remainder.

## English Byte-Identical Spot-Checks (Truth 2)

| File | Old | New | Identical |
|------|-----|-----|-----------|
| HRVTrendChart | `Text("7d avg: \(Int(baseline)) ms")` | `format("7d avg: %d ms", Int(baseline))` | yes |
| StalenessWarningBadge | `Text("Updated \(daysAgo)d ago")` | `format("Updated %dd ago", daysAgo)` | yes |
| FinishWorkoutSheet | `Text("RPE: \(Int(rpe))")` | `format("RPE: %d", Int(rpe))` | yes |
| SessionDetailView | `"Total: \(String(format:"%.0f kg",...))"` | `format("Total: %.0f kg", ...)` | yes |
| AutoregulationEngine | 56 engine literals | 56 `defaultValue` verbatim | yes (fence proves it) |

## Fence Execution (Truth 3)

```
xcodebuild test -scheme "workload management" \
  -destination 'platform=iOS Simulator,id=8E872500...iPhone 17 Pro Max' \
  -only-testing BaselineTierFenceTests / AutoregulationFlagFenceTests / DualRunFlagFenceTests
=> ** TEST SUCCEEDED **   (14 passed, 0 failed)
```

## Residual Hardcoded English on Core Screens (Truth 4 — FAILED)

Root cause: SwiftUI `Text("x")`, `Button("x")`, `Label("x",…)`, `TextField("x",…)`, `Picker("x",…)`, `.navigationTitle("x")` take a `LocalizedStringKey` and auto-look-up the literal as a catalog key. The Consolidate step did **not** add catalog entries for these literals, so under zh-Hans they fall through to the English literal.

**Count: 13 core-screen files, ~35-43 user-visible English strings.** By file (highest first):

| Count | File | Examples |
|-------|------|----------|
| 12 | ActiveWorkoutSheet.swift | "Cancel", "Finish", "Done", "PRE-FILLED FROM LAST SESSION", "Add Set", "Session Name (optional)", "Fill last", "Fill suggested" |
| 9 | ExercisePickerView.swift | "Add Exercise" (navTitle), "Exercise name", "Category", "Muscle Group (optional)", "Custom", "Delete", "Cancel", "Add" |
| 8 | WorkoutImportSheet.swift | "Select a PDF file containing your workout", "Choose PDF", "Take a photo of a workout or choose from your library", "Camera", "Library", "Analyzing workout...", "Retry", "Cancel" |
| 3 | WorkoutImportBanner.swift | "IMPORT FROM WATCH", "Add" |
| 2 | TemplatePreviewSheet.swift | "Cancel", "Edit Template" |
| 2 | TrainingProfileSheet.swift | "\(n) selected", "\(n) area/areas" |
| 1 ea | BehaviorCorrelationRow / TextTemplateImportSheet / TemplatePickerSheet / TemplateCarouselSection / ShareImportSheet / InviteConfirmationSheet / SyncStatusView | "Cancel" / "Close" / "Failed \(…)" |

Probe of catalog for common labels — ALL MISSING: `Cancel, Add, Delete, Custom, Done, Finish, Close, Camera, Library, Retry, Choose PDF, Add Exercise, Add Set, Edit Template, Category, Exercise name`.

**Justified non-user-facing (excluded from count):** `ABCD1234` (share-code placeholder), `athlete@example.com` / `you@example.com` (email field placeholders) — examples/placeholders, acceptable to leave. Borderline: `sec`/`min`/`m` TextField unit placeholders (English abbreviations) — recommend keying or explicit justification.

## Gaps Summary

The catalog work (Truths 1-3) is solid: 100% zh-Hans, byte-identical English, fences green and the byte-identical golden snapshot intact. However the central goal — eliminate residual English on core screens — is **not met**. The most-used screen (ActiveWorkoutSheet) and the exercise picker, watch/PDF import, and several profile sheets still ship un-keyed English, including the universal toolbar verbs Cancel/Add/Done/Finish/Close/Delete. A zh-Hans user will see English on every workout-logging and import flow. PASS requires residualHardcodedCoreScreens ≈ 0; actual is ~35-43.

---
_Verified: 2026-05-31_
_Verifier: Claude (gsd-verifier)_
