---
phase: 12-template-driven-workouts-smart-suggestions
plan: 02
subsystem: workout-log
tags: [template, ghost-targets, progression, fill-buttons, pro-gating]
dependency_graph:
  requires: [ProgressionEngine, WorkoutTemplate, SubscriptionService]
  provides: [template-loaded-ActiveWorkoutSheet, ghost-targets, fill-buttons, progression-overlay]
  affects: [ActiveWorkoutSheet, ExerciseEntryDraft, SetDraft, SetEntryRow]
tech_stack:
  added: []
  patterns: [ghost-target-placeholders, fill-button-bar, progression-suggestion-label]
key_files:
  created: []
  modified:
    - WorkloadApp/Views/WorkoutLog/ActiveWorkoutSheet.swift
decisions:
  - Ghost targets stored in targetReps/targetWeightKg/targetRPE fields of SetDraft; actual fields left nil until user fills
  - FillButtonBar positioned inline above exercise list, not as sticky keyboard toolbar
  - Progression suggestion label shows below each set row with arrow icon indicating direction
  - Fill suggested falls back to ghost targets when no ProgressionEngine suggestions available
metrics:
  duration: 4m
  completed: 2026-05-09
---

# Phase 12 Plan 02: Template-Driven ActiveWorkoutSheet Summary

Template-loaded ActiveWorkoutSheet with ghost targets from last-session history, Fill last/Fill suggested buttons, and ProgressionEngine suggestion overlays for Pro users.

## What Was Done

### Task 1: Add template parameter, loadFromTemplate, progression suggestions, fill buttons, and usage tracking

- Extended `ActiveWorkoutSheet.init` to accept optional `WorkoutTemplate` parameter
- Added `@State private var sourceTemplate: WorkoutTemplate?` for tracking template across session lifecycle
- Created `loadFromTemplate()` method that:
  - Populates session name, sport type, session type from template
  - Fetches exercise history via `ProgressionEngine.fetchHistory` for each exercise
  - Sets ghost targets (targetReps/targetWeightKg/targetRPE) from last-session actuals or template defaults
  - Leaves actual fields (reps/weightKg/rpe) as nil so ghost values are NOT auto-saved (T-12-03 mitigation)
  - Calls `ProgressionEngine.suggest()` for Pro users with history, storing suggestions and rationale
- Added `progressionSuggestions: [ProgressionEngine.SetSuggestion]?` field to `ExerciseEntryDraft`
- Created `FillButtonBar` view:
  - "Fill last" button visible to all users, copies ghost targets to actual fields
  - "Fill suggested" button visible only when `isPro` (T-12-05 mitigation), fills from ProgressionEngine suggestions with ghost target fallback
  - Styled per DESIGN.md: DM Sans Medium 17pt, 0pt corners, hairline border, no shadows
- Added progression suggestion display to `SetEntryRow`:
  - Shows directional arrow icon + weight text below each set's input fields
  - Uses `ColorTokens.text3` and `Font.Tokens.label` per UI-SPEC
  - Only renders when `progressionSuggestions` exists for the exercise (Pro-gated at data level)
- Updated `saveSession()` to:
  - Set `session.sourceTemplateId = sourceTemplate?.id` for template attribution
  - Update `source.lastUsedAt`, increment `source.usageCount`, update `source.updatedAt` after save

## Deviations from Plan

None - plan executed exactly as written.

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | 2fe39f9 | feat(12-02): template-driven ActiveWorkoutSheet with ghost targets, fill buttons, and progression overlay |

## Verification

- xcodebuild BUILD SUCCEEDED with iPhone 17 Pro Max simulator
- All acceptance criteria met per plan specification

## Self-Check: PASSED
