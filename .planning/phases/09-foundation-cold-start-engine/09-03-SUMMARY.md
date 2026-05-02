---
phase: 09-foundation-cold-start-engine
plan: 03
subsystem: persistence-sync
tags: [repository, supabase, rls, sync, training-profile, templates]
dependency_graph:
  requires: [TrainingProfile-model, WorkoutTemplate-athlete-fields]
  provides: [TemplateRepository, TrainingProfile-sync, workout-template-sync-extended, supabase-migration-006]
  affects: [SyncService, workout_templates-table, Supabase-schema]
tech_stack:
  added: []
  patterns: [repository-CRUD, Codable-row-struct, RLS-indirect-lookup, last-write-wins-sync]
key_files:
  created:
    - WorkloadApp/Repositories/TemplateRepository.swift
    - Supabase/migrations/006_v1.2_foundation.sql
  modified:
    - WorkloadApp/Services/SyncService.swift
    - workload management/workload management.xcodeproj/project.pbxproj
decisions:
  - TemplateRepository instantiated at point of use (not in AppContainer), same as WorkoutRepository
  - TrainingProfile injuryHistory synced as JSON string for JSONB column compatibility
  - scheduledDays mapped as [Int]? in row struct for PostgreSQL INT[] nullable safety
metrics:
  duration: 7m
  completed: "2026-05-02T06:14:29Z"
  tasks_completed: 2
  tasks_total: 3
  files_created: 2
  files_modified: 2
  status: checkpoint-blocked
---

# Phase 9 Plan 03: Repository, Sync & Migration Summary

TemplateRepository with full athlete-owned template CRUD, SyncService extended with TrainingProfile push/pull and 7 new WorkoutTemplateRow fields, Supabase migration with training_profiles table, workout_templates extensions, 4 RLS policies, and 2 indexes. Migration deployment pending (checkpoint:human-action).

## Task Results

### Task 1: Create TemplateRepository and Supabase migration file
- **Commit:** 5930d65
- **Files:** TemplateRepository.swift (created), 006_v1.2_foundation.sql (created), project.pbxproj (modified)
- **Result:** TemplateRepository @MainActor final class with 6 methods: fetchAthleteTemplates (non-archived, sorted by updatedAt), fetchFavorites (favorited + non-archived, sorted by lastUsedAt), save (insert + timestamp update), duplicate (deep copy groups, set athlete ownership), archive (soft delete via isArchived flag), delete (permanent). Migration SQL creates training_profiles table with 20 columns and UNIQUE(athlete_id), enables RLS with 2 policies (athlete CRUD own profile, coach read linked profiles), extends workout_templates with 7 new columns, adds 2 athlete-facing RLS policies (manage own templates, read coach templates via relationship), and creates 2 indexes. All RLS policies use indirect athlete_id lookup via `SELECT id FROM athletes WHERE user_id = auth.uid()` per threat model T-09-10.

### Task 2: Extend SyncService with TrainingProfile sync and updated WorkoutTemplateRow
- **Commit:** c93f2b5
- **Files:** SyncService.swift (modified)
- **Result:** TrainingProfileRow Codable struct with 21 fields and init(from: TrainingProfile) factory mapping Swift property names to snake_case JSON keys. pushTrainingProfile fetches by athleteId predicate and upserts to training_profiles table. pullTrainingProfile fetches single row by athlete_id, applies last-write-wins via updatedAt comparison, updates existing or creates new TrainingProfile with all fields including bias and injury data. Both registered in pushAll and pullAll. WorkoutTemplateRow extended with 7 new fields (isAthleteOwned, athleteId, isFavorite, isArchived, lastUsedAt, usageCount, scheduledDays). pullWorkoutTemplates updated to map all new fields from row to model.

### Task 3: Deploy Supabase migration (CHECKPOINT - PENDING)
- **Status:** Awaiting human action
- **Blocker:** Migration file created but needs `supabase db push` which requires interactive confirmation or SUPABASE_ACCESS_TOKEN

## Deviations from Plan

None - plan executed exactly as written for Tasks 1 and 2.

## Verification Results

| Check | Result |
|-------|--------|
| TemplateRepository in pbxproj | 4 entries |
| class TemplateRepository | 1 match |
| TrainingProfileRow struct | 1 match |
| pushTrainingProfile in pushAll | 1 match |
| pullTrainingProfile in pullAll | 1 match |
| WorkoutTemplateRow isAthleteOwned | 1 match |
| pullWorkoutTemplates maps isAthleteOwned | 1 match |
| CREATE TABLE in migration | 1 match |
| CREATE POLICY in migration | 4 matches |
| Swift compilation errors (excl. gitignored configs) | 0 |

Note: Full xcodebuild blocked by missing gitignored config files (SupabaseConfig.swift, RevenueCatConfig.swift) in worktree. No Swift compilation errors found in any modified files.

## Threat Surface Scan

No new threat surfaces introduced beyond what is documented in the plan's threat model. All RLS policies implement the indirect athlete_id lookup pattern (T-09-10). Training profile data crosses the client-Supabase trust boundary via SyncService with auth token (T-09-05). Athlete template RLS prevents tampering with coach templates (T-09-06, T-09-07). Coach profile read restricted to accepted relationships (T-09-08).

## Self-Check: PASSED

All created files exist. All commit hashes verified in git log.
