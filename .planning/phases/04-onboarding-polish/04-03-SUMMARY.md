---
phase: 04-onboarding-polish
plan: 03
subsystem: views
tags: [onboarding, dashboard, profile, welcome-card]
dependency_graph:
  requires: [04-01]
  provides: [welcome-action-card, profile-training-prefs]
  affects: [DashboardView, ProfileView]
tech_stack:
  added: []
  patterns: [conditional-card-rendering, reactive-dismissal]
key_files:
  created:
    - WorkloadApp/Views/Dashboard/WelcomeActionCard.swift
  modified:
    - WorkloadApp/Views/Dashboard/DashboardView.swift
    - WorkloadApp/Views/Profile/ProfileView.swift
    - workload management/workload management.xcodeproj/project.pbxproj
decisions:
  - Used MorningCheckInSheet for wellness CTA (existing standalone sheet, no extraction needed)
  - Default fallbacks for nil training frequency (.threeToFour) and experience level (.intermediate) in profile pickers
metrics:
  duration: 6m
  completed: "2026-04-22T05:36:13Z"
  tasks_completed: 3
  tasks_total: 3
---

# Phase 04 Plan 03: Welcome Action Card & Profile Training Prefs Summary

Welcome card on Dashboard for first-run guidance with Log Workout and Wellness Check-In CTAs, plus editable training frequency and experience level pickers in Profile settings.

## Completed Tasks

| # | Task | Commit | Key Files |
|---|------|--------|-----------|
| 1 | Create WelcomeActionCard + integrate into DashboardView | 0896777 | WelcomeActionCard.swift (new), DashboardView.swift, project.pbxproj |
| 2 | Add training frequency and experience level pickers to ProfileView | d1155c9 | ProfileView.swift |
| 3 | Verify full onboarding and welcome card flow (checkpoint) | -- | Auto-approved in auto mode |

## Implementation Details

### WelcomeActionCard (Task 1)
- New `WelcomeActionCard.swift` with GET STARTED section label, welcome text, and two CTA buttons
- Card follows DESIGN.md: `ColorTokens.surface` background, `Rectangle().stroke(ColorTokens.divider)` border, no rounded corners, no shadows, no accent color, DM Sans fonts via `.Tokens`, 8pt spacing grid
- Integrated into DashboardView with `showWelcomeCard` computed property checking `athlete.sessions.isEmpty && athlete.wellnessCheckIns.isEmpty`
- "Log Workout" CTA opens existing `ActiveWorkoutSheet`
- "Wellness Check-In" CTA opens existing `MorningCheckInSheet`
- Card auto-dismisses reactively via `@Query` when either action completes (no manual state tracking needed)

### Profile Training Prefs (Task 2)
- Added two new `editablePicker` rows in the ATHLETE section of ProfileView after Sport
- Training Frequency picker with `TrainingFrequency.allCases`, default `.threeToFour`
- Experience Level picker with `ExperienceLevel.allCases`, default `.intermediate`
- Both use existing `Binding(get:set:)` pattern with `saveAthlete(athlete)` for persistence and sync

### Checkpoint (Task 3)
- Auto-approved per `--auto` flag. Human verification skipped.

## Deviations from Plan

None -- plan executed exactly as written.

## Known Stubs

None -- all data sources are wired (athlete relationships for welcome card, athlete model fields for profile pickers).

## Self-Check: PASSED

- [x] WelcomeActionCard.swift exists
- [x] DashboardView.swift contains showWelcomeCard, WelcomeActionCard, showWellnessCheckIn
- [x] ProfileView.swift contains trainingFrequency and experienceLevel pickers
- [x] WelcomeActionCard.swift in pbxproj (4 references)
- [x] Commit 0896777 exists (Task 1)
- [x] Commit d1155c9 exists (Task 2)
- [x] Project builds successfully
