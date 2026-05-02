---
phase: 09-foundation-cold-start-engine
plan: 01
subsystem: models
tags: [swiftdata, cold-start, training-profile, templates]
dependency_graph:
  requires: []
  provides: [TrainingProfile-model, BodyRegion-enum, InjuryEntry-struct, WorkoutTemplate-athlete-fields]
  affects: [WorkloadApp-schema, WorkoutTemplate]
tech_stack:
  added: []
  patterns: [SwiftData-model, Codable-struct, lightweight-migration]
key_files:
  created:
    - WorkloadApp/Models/TrainingProfile.swift
  modified:
    - WorkloadApp/Models/Enums.swift
    - WorkloadApp/Models/WorkoutTemplate.swift
    - WorkloadApp/App/WorkloadApp.swift
    - workload management/workload management.xcodeproj/project.pbxproj
decisions:
  - TrainingProfile uses plain UUID athleteId (not @Relationship) per D-07 pattern
  - All WorkoutTemplate new fields have defaults for lightweight migration safety
  - BodyRegion enum has 8 anatomical cases matching cold-start questionnaire needs
metrics:
  duration: 9m
  completed: "2026-05-02T05:02:18Z"
  tasks_completed: 2
  tasks_total: 2
  files_created: 1
  files_modified: 4
---

# Phase 9 Plan 01: Foundation Data Models Summary

SwiftData models for cold-start engine: TrainingProfile with questionnaire, seeded ATL/CTL, and bias fields; WorkoutTemplate extended with athlete ownership and template management fields; BodyRegion enum and InjuryEntry struct for injury history encoding.

## Task Results

### Task 1: Create TrainingProfile model and add BodyRegion enum + InjuryEntry struct
- **Commit:** 906a5a8
- **Files:** TrainingProfile.swift (created), Enums.swift (modified), project.pbxproj (modified)
- **Result:** TrainingProfile @Model with 20 fields covering D-07 through D-13: athleteId UUID foreign key, 4 required questionnaire fields (sessionsPerWeek, avgDurationMinutes, typicalSRPE, weeksAtLevel), 4 optional questionnaire fields (trainingAgeYears, periodizationPreference, movementTypes, injuryHistory as Data), seeded values (seededATL, seededCTL, seededAt), 5 bias fields, coldStartCompletedAt, and timestamps. BodyRegion enum with 8 cases (shoulder, knee, back, hip, ankle, wrist, elbow, neck) conforming to String, Codable, CaseIterable, Identifiable. InjuryEntry Codable struct with bodyRegion, notes, and isActive fields.

### Task 2: Extend WorkoutTemplate with additive fields and register TrainingProfile in schema
- **Commit:** 92b6998
- **Files:** WorkoutTemplate.swift (modified), WorkloadApp.swift (modified)
- **Result:** 7 new fields added to WorkoutTemplate with defaults: isAthleteOwned (Bool = false), athleteId (UUID? = nil), isFavorite (Bool = false), isArchived (Bool = false), lastUsedAt (Date? = nil), usageCount (Int = 0), scheduledDays ([Int] = []). TrainingProfile.self registered in ModelContainer schema array. All existing fields unchanged.

## Deviations from Plan

None - plan executed exactly as written.

## Verification Results

| Check | Result |
|-------|--------|
| TrainingProfile.self in schema | 1 match |
| isAthleteOwned in WorkoutTemplate | 1 match |
| @Model in TrainingProfile | 1 match |
| BodyRegion enum in Enums.swift | 1 match |
| InjuryEntry struct in Enums.swift | 1 match |
| TrainingProfile.swift in pbxproj | 4 entries |
| Swift syntax parse (TrainingProfile.swift) | No errors |
| Swift syntax parse (Enums.swift) | No errors |
| Swift syntax parse (WorkoutTemplate.swift) | No errors |

Note: Full xcodebuild verification was blocked by pre-existing worktree SPM resolution issues (Supabase Auth module import in AppRouter.swift). No errors were found in any of the files created or modified by this plan.

## Self-Check: PASSED

All created files exist. All commit hashes verified in git log.
