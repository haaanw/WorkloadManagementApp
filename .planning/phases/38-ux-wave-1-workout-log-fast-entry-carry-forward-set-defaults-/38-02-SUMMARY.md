---
phase: 38-ux-wave-1-workout-log-fast-entry-carry-forward-set-defaults-
plan: 02
subsystem: workout-log
tags: [ux, swiftui, post-workout, banners, de-modal, i18n]
requires:
  - SpikeAlertBanner
  - PersonalRecord
  - ColorTokens
  - Font.Tokens
provides:
  - PRBanner inline dismissible PR-celebration banner (zone-optimal left border)
  - ActiveWorkoutSheet post-save flow rewired to non-blocking inline banner stack
affects:
  - WorkloadApp/Views/WorkoutLog/ActiveWorkoutSheet.swift
tech-stack:
  added: []
  patterns:
    - "inline banner stack at .bottom — PR + spike can coexist, commit-first preserved"
    - "advancePostSave() gate — niggle nudge fires only after BOTH banners dismissed"
key-files:
  created:
    - WorkloadApp/Components/PRBanner.swift
  modified:
    - WorkloadApp/Views/WorkoutLog/ActiveWorkoutSheet.swift
    - "workload management/workload management.xcodeproj/project.pbxproj"
decisions:
  - "PRBanner mirrors SpikeAlertBanner exactly (surfaceEl + 2pt left strip + hairline divider + tap-to-dismiss) for visual consistency"
  - "PR uses zoneOptimal left border (PR = optimal zone); no accent fill — accent stays Dashboard-hero-only per DESIGN.md"
  - "Reused existing workout.pr.title string — no new localizable strings needed (tap-to-dismiss like SpikeAlertBanner, no dismiss label)"
  - "Both banners rendered in one bottom VStack so PR + spike show together; advancePostSave() only advances when both are dismissed, preserving strict D-08 niggle sequencing"
metrics:
  duration: ~12min
  completed: 2026-06-02
---

# Phase 38 Plan 02: De-modal post-workout PR/spike interrupts Summary

Replaced the full-screen `PRCelebrationOverlay` blocking modal with an inline, dismissible `PRBanner` and presented it alongside the existing `SpikeAlertBanner` in a single non-blocking bottom banner stack. The session is still committed to SwiftData before any banner appears, banners never block dismissing the sheet, and the D-08 niggle nudge now sequences strictly after both banners are dismissed.

## What was built

**Task 1 — PRBanner component (`WorkloadApp/Components/PRBanner.swift`, commit `0ef25eb`)**
- `struct PRBanner: View` with `let prs: [PersonalRecord]` + `let onDismiss: () -> Void`, mirroring `SpikeAlertBanner`'s layout exactly.
- 2pt left `Rectangle` strip filled `ColorTokens.zoneOptimal` (PR = optimal zone) — sanctioned zone signal, no accent.
- Micro all-caps title (zoneOptimal) reusing the existing localized `workout.pr.title` string with the same `"s"` pluralization the old overlay used, then one compact row per PR: exercise name (`smallLabel`, text1) + `recordType.displayName: value` (`smallLabelMedium`, monospacedDigit, text2).
- `.background(surfaceEl)` + `.overlay(Rectangle().stroke(divider, 0.5))` + `.contentShape(Rectangle())` + `.onTapGesture { onDismiss() }`. 16pt padding, 0pt corners, no shadow.
- Registered in `project.pbxproj` (build file + file ref + Components group child + Sources phase) mirroring `SetStepper.swift` — the project uses explicit file references.

**Task 2 — ActiveWorkoutSheet rewire + overlay deletion (`ActiveWorkoutSheet.swift`, commit `02f90f6`)**
- Removed the `.overlay { if showPRCelebration { PRCelebrationOverlay(...) } }` full-screen block and deleted the `struct PRCelebrationOverlay` type (confirmed unreferenced repo-wide before deletion).
- Both banners now render in one bottom-aligned `VStack(spacing: 8)`: `PRBanner(prs:)` when `showPRCelebration`, `SpikeAlertBanner(alert:)` when `showSpikeAlert` — so PR + spike can show together when both fire. Each carries `.transition(.move(edge:.bottom).combined(with:.opacity))`; added a matching `.animation` keyed on `showPRCelebration` alongside the existing one for `showSpikeAlert`. 16pt bottom/horizontal padding retained.
- New `advancePostSave()` helper: `guard !showPRCelebration, !showSpikeAlert else { return }; finishOrNudge()`. Each banner's dismiss sets its own flag false then calls `advancePostSave()`, so `finishOrNudge()` (D-08 niggle nudge) fires only once the LAST visible banner is dismissed — never colliding with the banner branches.
- `saveSession()` control flow: kept commit-first ordering unchanged (`modelContext.insert` + `try modelContext.save()` before `WorkoutPipeline.processSession`). Replaced the modal-coupled early returns (`if !result.newPRs.isEmpty { ...; return }` and `if showSpikeAlert { return }`) with: set `spikeAlert`/`newPRs` + their show flags, then `if showPRCelebration || showSpikeAlert { return }` to let the inline banner stack render (sheet stays open but NOT blocked). If neither fires, `finishOrNudge()` as before.

## Verification

- `xcodebuild` BUILD SUCCEEDED on iPhone 17 Pro sim (`CAF84E71-BB64-491D-87C8-875A0143B26D`) after each task.
- Acceptance greps: `struct PRBanner` ×1; `zoneOptimal` present in PRBanner; `onTapGesture`/`onDismiss` present; `PRBanner` referenced in the view; `PRCelebrationOverlay` == 0 in the file AND repo-wide; `advancePostSave`/`finishOrNudge` present.
- Commit-first invariant verified by reading `saveSession`: `try modelContext.save()` (line 522) precedes `WorkoutPipeline.processSession` (line 539).
- Regression gate on both edited Swift files: `ColorTokens.accent` == 0; `RoundedRectangle|.cornerRadius|.shadow(|.font(.system(` == 0.
- Diff scope: only `PRBanner.swift`, `ActiveWorkoutSheet.swift`, and `project.pbxproj` (no engine/flag/pipeline/schema file touched). `git diff --name-only` confirmed.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Registered PRBanner.swift in project.pbxproj**
- **Found during:** Task 1
- **Issue:** The Components group is an explicit PBXGroup, so a new Swift file would not compile until added to the build file list, file references, group children, and Sources build phase (same as SetStepper.swift in Plan 01).
- **Fix:** Added the four matching pbxproj entries mirroring `SetStepper.swift`.
- **Files modified:** `workload management/workload management.xcodeproj/project.pbxproj`
- **Commit:** `0ef25eb`

The plan's "diff lists only ActiveWorkoutSheet.swift, PRBanner.swift, Localizable.xcstrings (+ possible .pbxproj)" acceptance explicitly anticipated the pbxproj edit. No `Localizable.xcstrings` change was needed — the only visible string (`workout.pr.title`) already exists and was reused, and tap-to-dismiss required no new dismiss label (matching SpikeAlertBanner).

## Known Stubs

None.

## Manual smoke (pending human UAT)

Plan-specified interactive checks not run by the executor: finish a workout that triggers a PR and/or spike → inline bottom banner(s) appear, sheet not blocked, tapping a banner dismisses it; after the last banner the niggle nudge appears; a normal workout (no PR/spike) goes straight to the niggle nudge. Recommend including in the phase UAT pass.

## Self-Check: PASSED
- FOUND: WorkloadApp/Components/PRBanner.swift
- FOUND: commit 0ef25eb
- FOUND: commit 02f90f6
