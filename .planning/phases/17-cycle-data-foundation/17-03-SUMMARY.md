---
phase: 17-cycle-data-foundation
plan: 03
subsystem: views
tags: [ui, profile, dashboard, cycle-data, healthkit]
dependency_graph:
  requires: [17-01]
  provides: [cycle-hormones-section, cycle-prompt-banner]
  affects: [ProfileView, DashboardView]
tech_stack:
  added: []
  patterns: [toggle-row, soft-prompt-banner, appStorage-dismissal]
key_files:
  created: []
  modified:
    - WorkloadApp/Views/Profile/ProfileView.swift
    - WorkloadApp/Views/Dashboard/DashboardView.swift
decisions:
  - "Section visibility driven by @Query on MenstrualCycleSnapshot + nil checks on athlete flags, avoiding HealthKit auth status ambiguity"
  - "Soft prompt uses @AppStorage for permanent dismissal -- simpler than Athlete model flag and works before login"
metrics:
  duration: 106s
  completed: "2026-05-14"
  tasks_completed: 2
  tasks_total: 3
  status: checkpoint-pending
---

# Phase 17 Plan 03: Profile & Dashboard Cycle UI Summary

Cycle & Hormones toggle section in ProfileView and one-time soft prompt banner in DashboardView for cycle-aware recovery onboarding.

## Completed Tasks

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Add "Cycle & Hormones" section to ProfileView | c7a7d4a | WorkloadApp/Views/Profile/ProfileView.swift |
| 2 | Add one-time soft prompt banner to DashboardView | 97fd941 | WorkloadApp/Views/Dashboard/DashboardView.swift |

## Pending Tasks

| # | Task | Status |
|---|------|--------|
| 3 | Visual verification of Cycle & Hormones section and soft prompt banner | checkpoint:human-verify -- awaiting user verification |

## Implementation Details

### Task 1: Cycle & Hormones Section

Added a new "CYCLE & HORMONES" section to ProfileView between Training Profile and Preferences sections. The section contains three toggle rows:

- **Hormonal Contraceptive** -- binds to `athlete.isOnHormonalContraceptive`
- **Pregnant** -- binds to `athlete.isPregnant`
- **Lactating** -- binds to `athlete.isLactating`

Section visibility is controlled by `showCycleSection` computed property which checks:
1. Whether any `MenstrualCycleSnapshot` records exist (via `@Query`)
2. Whether any of the three flags have been previously set (non-nil)

This approach avoids the HealthKit authorization status ambiguity (cannot distinguish "denied" from "not determined") by using actual data presence as the signal.

Each toggle immediately saves to the Athlete model via the existing `saveAthlete()` helper, which also triggers Supabase sync via `pushAthlete`.

### Task 2: Soft Prompt Banner

Added a one-time dismissible banner to DashboardView that appears when:
- No `MenstrualCycleSnapshot` records exist (via `@Query`)
- User has not previously dismissed it (`@AppStorage("cyclePromptDismissed")`)

Banner includes:
- Heading: "Cycle-Aware Recovery"
- Body: Explains benefits and mentions compatible apps (Clue, Flo, Apple Cycle Tracking)
- Dismiss button (X) with accessibility label
- "Open Settings" underlined link to iOS Settings

## Deviations from Plan

None -- plan executed exactly as written.

## Known Stubs

None -- all data bindings are wired to existing Athlete model fields from Plan 01.

## Self-Check: PENDING

Self-check will be completed after human verification checkpoint.
