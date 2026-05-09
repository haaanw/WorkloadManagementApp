---
phase: 12-template-driven-workouts-smart-suggestions
plan: 01
subsystem: services
tags: [engine, suggestion, template, recovery]
dependency_graph:
  requires: []
  provides: [TemplateSuggestionEngine, sourceTemplateId]
  affects: [WorkoutSession]
tech_stack:
  added: []
  patterns: [pure-struct-engine, static-methods, frequency-analysis]
key_files:
  created:
    - WorkloadApp/Services/TemplateSuggestionEngine.swift
  modified:
    - WorkloadApp/Models/WorkoutSession.swift
    - workload management/workload management.xcodeproj/project.pbxproj
decisions:
  - Used exercise count as primary lighter-template heuristic with average TSS as tiebreaker
  - Fallback session name matching for pre-sourceTemplateId sessions
metrics:
  duration: 4m
  completed: "2026-05-09"
  tasks_completed: 1
  tasks_total: 1
  files_created: 1
  files_modified: 2
---

# Phase 12 Plan 01: TemplateSuggestionEngine + sourceTemplateId Summary

Day-of-week frequency-based template suggestion engine with recovery-aware lighter alternative swapping, plus sourceTemplateId field on WorkoutSession for accurate template-session linkage.

## What Was Built

### TemplateSuggestionEngine (new)
Pure struct with static methods following the project engine convention (same pattern as AutoregulationEngine, WorkloadCalculator). Provides:

- **`suggest()`** -- Primary method that analyzes 14-day session history to find the most-used template on today's weekday, with automatic fallback to a lighter template when recovery zone is red or yellow
- **`isoWeekday(from:)`** -- Public helper converting Apple Calendar weekday (1=Sun) to ISO 8601 (1=Mon...7=Sun)
- **`pickByFrequency()`** -- Builds frequency map of template usage per weekday, matching via sourceTemplateId (primary) or session name (fallback)
- **`findLighterAlternative()`** -- Finds lighter template by exercise count (primary) or average historical TSS (tiebreaker)

### WorkoutSession.sourceTemplateId (modified)
Added `var sourceTemplateId: UUID? = nil` to WorkoutSession model. Optional field with default nil means no SwiftData migration required. Links sessions to the template they were started from for accurate frequency counting.

## Task Commits

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Create TemplateSuggestionEngine and add sourceTemplateId | c6096b4 | TemplateSuggestionEngine.swift, WorkoutSession.swift, project.pbxproj |

## Deviations from Plan

None -- plan executed exactly as written.

## Verification

- xcodebuild BUILD SUCCEEDED with iPhone 17 Pro simulator
- TemplateSuggestionEngine.swift contains all required methods and types
- WorkoutSession.swift contains sourceTemplateId field
- File added to Xcode project (pbxproj updated)

## Self-Check: PASSED
