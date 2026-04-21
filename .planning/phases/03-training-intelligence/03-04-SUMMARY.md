---
phase: 03-training-intelligence
plan: 04
subsystem: recovery-intelligence
tags: [fatigue-insights, behavior-tagging, correlation-engine, recovery-tab]
dependency_graph:
  requires: [03-01, 03-02]
  provides: [fatigue-insight-display, behavior-tag-checkin, correlation-display]
  affects: [RecoveryViewModel, RecoveryView, MorningCheckInSheet]
tech_stack:
  added: []
  patterns: [FlowLayout-custom-Layout, behavior-tag-all-states-recording]
key_files:
  created: []
  modified:
    - WorkloadApp/ViewModels/RecoveryViewModel.swift
    - WorkloadApp/Views/Recovery/RecoveryView.swift
    - WorkloadApp/Views/Recovery/MorningCheckInSheet.swift
decisions:
  - Record ALL behavior tags (active + inactive) on check-in save for correlation engine both-group analysis
  - FlowLayout kept file-private in MorningCheckInSheet as single-use layout helper
  - Custom tag management sheet is a private struct within MorningCheckInSheet
metrics:
  duration: ~8 minutes
  completed: 2026-04-21T09:43:00Z
  tasks_completed: 3
  tasks_total: 3
requirements: [INTEL-04, INTEL-05, INTEL-06, INTEL-07]
---

# Phase 03 Plan 04: Recovery Intelligence Integration Summary

RecoveryViewModel calls FatiguePatternEngine and BehaviorCorrelationEngine with 90-day data windows; RecoveryView renders INSIGHTS and BEHAVIOR IMPACT sections below existing charts; MorningCheckInSheet gains behavior tag chips with Pro custom tag management.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1a | RecoveryViewModel fatigue + correlation integration | e246ddb | WorkloadApp/ViewModels/RecoveryViewModel.swift |
| 1b | RecoveryView INSIGHTS and BEHAVIOR IMPACT sections | 67b23ac | WorkloadApp/Views/Recovery/RecoveryView.swift |
| 2 | MorningCheckInSheet behavior tag chips + custom tag management | 900ca31 | WorkloadApp/Views/Recovery/MorningCheckInSheet.swift |
| 3 | Visual and functional verification | -- | checkpoint:human-verify (pending) |

## What Was Built

### RecoveryViewModel (Task 1a)
- Added `fatigueInsights`, `behaviorCorrelations`, `behaviorSufficiency` properties
- `load()` calls `FatiguePatternEngine.detectPatterns()` with 90-day workload snapshots, recovery snapshots, and sessions
- `load()` calls `BehaviorCorrelationEngine.computeCorrelations()` and `checkSufficiency()` with 90-day behavior tags
- Follows existing inline repository creation pattern with `(try? ...) ?? []` error suppression

### RecoveryView (Task 1b)
- INSIGHTS section renders up to 5 InsightCard components for fatigue pattern insights
- BEHAVIOR IMPACT section renders BehaviorCorrelationRow for sufficient correlations first, then insufficient tags
- Empty state shows DataSufficiencyRing encouraging behavior tagging when recovery data exists but no insights yet
- Section headers use micro typography (11pt, tracking 1.2, uppercase, text3 color)
- Sections always expanded when data exists (not collapsible per UI-SPEC)

### MorningCheckInSheet (Task 2)
- BEHAVIORS section with 4 default tag chips: Caffeine, Alcohol, Travel, Stress
- FlowLayout (private, file-scoped) wraps chips to multiple rows
- Toggle state via `selectedTags: Set<String>`
- Pro-gated "Manage Tags" button opens CustomTagManagementSheet
- CustomTagManagementSheet: add/delete custom tags, max 8 custom tags, max 20 char names, swipe-to-delete
- Save creates BehaviorTag records for ALL tags (active + inactive) linked to WellnessCheckIn and Athlete
- Loads custom tag names on appear via BehaviorTagRepository

## Threat Mitigations Applied

| Threat ID | Mitigation |
|-----------|------------|
| T-03-07 | Custom tag name limited to 20 chars via onChange handler in CustomTagManagementSheet |
| T-03-08 | Fatigue insights capped at 5 via prefix(5); queries limited to 90-day window |
| T-03-09 | Custom tag management gated behind `container.subscriptionService.isPro` |

## Deviations from Plan

None - plan executed exactly as written.

## Verification

- xcodebuild succeeds with exit code 0 for all 3 tasks
- RecoveryViewModel contains FatiguePatternEngine.detectPatterns and BehaviorCorrelationEngine.computeCorrelations calls
- RecoveryView contains INSIGHTS and BEHAVIOR IMPACT section headers with correct typography
- MorningCheckInSheet contains BEHAVIORS section with BehaviorTagChip usage and BehaviorTag creation in save()
- All tags saved with both active and inactive states for correlation engine analysis

## Checkpoint: Visual Verification (Pending)

Task 3 is a human-verify checkpoint. The following needs visual confirmation in Simulator:

1. Recovery tab shows INSIGHTS section with fatigue pattern cards (when data exists)
2. Recovery tab shows BEHAVIOR IMPACT section with correlation rows (when data exists)
3. Morning check-in includes BEHAVIORS section with 4 default tag chips
4. Tag chips toggle on tap
5. Pro users see "Manage Tags" button
6. All UI follows DESIGN.md: 0pt radius, no shadows, DM Sans, ColorTokens, 8pt grid

## Self-Check: PASSED

All 3 modified files verified on disk. All 3 task commits verified in git log.
