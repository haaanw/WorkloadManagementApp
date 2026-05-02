---
phase: 10-cold-start-questionnaire
plan: 03
subsystem: cold-start-questionnaire
tags: [switchover, bias-capture, profile-view, pipeline]
dependency_graph:
  requires: [TrainingProfile model (10-01), TrainingProfileSheet (10-01), TrainingProfileRepository (10-01)]
  provides: [Cold-start switchover logic, Bias capture logic, ProfileView training profile section]
  affects: [WorkoutPipeline (post-session flow), ProfileView (new section)]
tech_stack:
  added: []
  patterns: [#Predicate local variable capture for SwiftData macro, idempotent timestamp guards]
key_files:
  created: []
  modified:
    - WorkloadApp/Services/WorkoutPipeline.swift
    - WorkloadApp/Views/Profile/ProfileView.swift
decisions:
  - "Extract athlete.id to local variable before #Predicate closure -- SwiftData macro cannot capture keypaths from outer scope objects"
  - "Switchover and bias checks run sequentially after every session save, both idempotent via nil guards on timestamp fields"
metrics:
  duration: 4m 16s
  completed: "2026-05-02T14:27:51Z"
  tasks_completed: 3
  tasks_total: 3
  files_created: 0
  files_modified: 2
---

# Phase 10 Plan 03: Switchover Logic and ProfileView Re-edit Summary

Cold-start switchover check (3wk + 8 sessions) and bias capture (8-week mark) in WorkoutPipeline.processSession(), plus TRAINING PROFILE section in ProfileView with summary rows and re-edit path via TrainingProfileSheet

## Task Execution

### Task 1: Add switchover check and bias capture to WorkoutPipeline
**Commit:** cccde76

Added two sequential blocks to `WorkoutPipeline.processSession()` after the main `modelContext.save()` and before the sync Task block:

1. **Cold-start switchover check (COLD-05):** Fetches the athlete's TrainingProfile, counts all lifetime sessions, calculates weeks elapsed since seeding using `.day` component divided by 7 (avoiding year-boundary edge case). When `weeksSinceSeeded >= 3 && totalSessionCount >= 8`, sets `coldStartCompletedAt = .now`. Guarded by `coldStartCompletedAt == nil` for idempotency.

2. **Bias capture (COLD-06):** Runs only when `coldStartCompletedAt` is set and `biasCapturedAt` is still nil. At the 8-week mark (56+ days since seeding), records `seededATL/seededCTL` as estimated values and `latestSnapshot.acuteLoad/chronicLoad` as actual values. Sets `biasCapturedAt = .now`. One-time capture, idempotent.

Also added `pushTrainingProfile` call inside the existing sync Task block so switchover/bias updates sync to Supabase.

### Task 2: Add Training Profile section to ProfileView
**Commit:** 012f0f6

Added `@Query private var trainingProfiles: [TrainingProfile]` and `@State private var showTrainingProfileSheet` to ProfileView. Inserted a "TRAINING PROFILE" section between the existing ATHLETE and PREFERENCES sections using the existing `sectionHeader`, `profileRow`, `actionButton`, `divider`, and `sectionDivider` helpers.

When a profile exists: shows 4 summary rows (Sessions / week, Avg duration, Typical effort, Weeks at level) plus an "Edit Profile" action button. When no profile exists: shows a "Set up training profile" action button. Both paths open `TrainingProfileSheet` via a `.sheet` modifier, passing `trainingProfiles.first` as `existingProfile` for re-edit pre-fill.

### Task 3: Build verification
**Commit:** 0114d06

xcodebuild BUILD SUCCEEDED. Required fixing a `#Predicate` capture issue -- the SwiftData `#Predicate` macro cannot capture keypaths from outer scope objects (like `athlete.id`). Fixed by extracting `athlete.id` into a local `let athleteIdForProfile` variable before the predicate closure.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed #Predicate capture of athlete.id in WorkoutPipeline**
- **Found during:** Task 3 (build verification)
- **Issue:** `#Predicate<TrainingProfile> { $0.athleteId == athlete.id }` fails to compile because the SwiftData `#Predicate` macro cannot resolve keypaths on captured outer-scope objects. The compiler error: "cannot convert value of type 'PredicateExpressions.Equal<...>' to closure result type".
- **Fix:** Extracted `athlete.id` to a local variable `let athleteIdForProfile = athlete.id` before the predicate, allowing the macro to capture a simple value type.
- **Files modified:** `WorkloadApp/Services/WorkoutPipeline.swift`
- **Commit:** 0114d06

## Verification Results

1. WorkoutPipeline checks switchover threshold after each session save -- PASS
2. Switchover sets coldStartCompletedAt when 3 weeks + 8 sessions met -- PASS
3. Bias capture runs at 8-week mark, writes estimated vs actual ATL/CTL -- PASS
4. Both switchover and bias capture are idempotent (nil guards) -- PASS
5. ProfileView shows TRAINING PROFILE section between ATHLETE and PREFERENCES -- PASS
6. Re-edit path opens TrainingProfileSheet with pre-filled values -- PASS
7. xcodebuild BUILD SUCCEEDED -- PASS

## Self-Check: PASSED

All 2 modified files exist on disk. All 3 task commits (cccde76, 012f0f6, 0114d06) verified in git log.
