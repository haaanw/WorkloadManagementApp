---
phase: 15-template-sharing
plan: 01
subsystem: services
tags: [supabase, rls, universal-links, template-sharing, swift]

requires:
  - phase: 11-template-management-creation
    provides: WorkoutTemplate model, ExerciseGroup, TemplateExercise, TemplateSet models
  - phase: 03-coach-athlete
    provides: InviteService pattern (enum namespace, Supabase CRUD, deep link parsing)
  - phase: 02-supabase-backend
    provides: SyncService.encodeGroups/decodeGroups for JSON serialization
provides:
  - TemplateSharingService with share code generation, Supabase CRUD, import logic
  - Supabase shared_templates migration with RLS and pg_cron cleanup
  - Associated Domains entitlement for tuwa.app universal links
  - TemplateSharePayload versioned Codable type for template JSON
  - SharedTemplateResponse type for share code lookup results
affects: [15-02, 15-03]

tech-stack:
  added: [pg_cron]
  patterns: [versioned-json-payload, weight-stripping-on-import, 8-char-share-codes]

key-files:
  created:
    - WorkloadApp/Services/TemplateSharingService.swift
    - migrations/shared_templates.sql
  modified:
    - "workload management/workload management/workload management.entitlements"
    - "workload management/workload management.xcodeproj/project.pbxproj"

key-decisions:
  - "Used 8-char alphanumeric codes (36^8 keyspace) for sufficient collision resistance"
  - "Used .strength as default SessionType fallback since .regular does not exist in enum"
  - "Set coachId to athlete.id for athlete-owned imported templates (matching existing pattern)"

patterns-established:
  - "Template sharing payload: versioned JSON with v field for forward compatibility"
  - "Weight stripping: targetWeightKg = nil on all imported template sets for privacy"
  - "Share code retry: 3-attempt loop with unique constraint violation detection (23505)"

requirements-completed: [SHARE-01, SHARE-02, SHARE-05]

duration: 2min
completed: 2026-05-13
---

# Phase 15 Plan 01: Backend Foundation Summary

**TemplateSharingService with 8-char share codes, Supabase shared_templates table with RLS/pg_cron, and Associated Domains for tuwa.app universal links**

## Performance

- **Duration:** 2 min
- **Started:** 2026-05-13T12:11:28Z
- **Completed:** 2026-05-13T12:13:55Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- TemplateSharingService enum with makeShareCode, shareTemplate, lookupShareCode, importTemplate, handleDeepLink
- Supabase migration with shared_templates table, RLS policies (read-all, insert-owner, delete-owner), and pg_cron daily cleanup
- Associated Domains entitlement (applinks:tuwa.app) added while preserving HealthKit and Apple Sign-In
- Weight stripping on import prevents personal training data leakage between users

## Task Commits

Each task was committed atomically:

1. **Task 1: Supabase migration SQL and TemplateSharingService** - `c6f6b47` (feat)
2. **Task 2: Associated Domains entitlement and pbxproj update** - `b651dd2` (feat)

## Files Created/Modified
- `migrations/shared_templates.sql` - Supabase DDL with shared_templates table, RLS, pg_cron cleanup
- `WorkloadApp/Services/TemplateSharingService.swift` - Share code generation, Supabase CRUD, deep link parsing, import with weight stripping
- `workload management/workload management/workload management.entitlements` - Added associated-domains for tuwa.app
- `workload management/workload management.xcodeproj/project.pbxproj` - Added TemplateSharingService.swift to build sources

## Decisions Made
- Used `.strength` as default SessionType fallback instead of `.regular` (which does not exist in the SessionType enum) -- Rule 1 bug fix
- Set `coachId` to `athlete.id` for athlete-owned imported templates, matching the existing pattern where athlete-owned templates use the athlete's ID as coachId
- Used `athlete.id` for `athleteId` property instead of non-existent `athlete` relationship on WorkoutTemplate

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed SessionType.regular fallback**
- **Found during:** Task 1 (TemplateSharingService)
- **Issue:** Plan specified `SessionType.regular` as fallback but this case does not exist in the SessionType enum (cases are: strength, skill, cardio, match, recovery)
- **Fix:** Changed to `.strength` as the most common default
- **Files modified:** WorkloadApp/Services/TemplateSharingService.swift
- **Verification:** Grep confirms `.strength` used instead of `.regular`
- **Committed in:** c6f6b47

**2. [Rule 1 - Bug] Fixed WorkoutTemplate init and athlete assignment**
- **Found during:** Task 1 (TemplateSharingService)
- **Issue:** Plan code used `WorkoutTemplate(templateName:sportType:sessionType:)` without required `coachId` parameter, and set `template.athlete = athlete` but WorkoutTemplate has no `athlete` relationship (only `athleteId: UUID?`)
- **Fix:** Used `WorkoutTemplate(coachId: athlete.id, ...)` and `template.athleteId = athlete.id`
- **Files modified:** WorkloadApp/Services/TemplateSharingService.swift
- **Verification:** Code matches WorkoutTemplate model API
- **Committed in:** c6f6b47

---

**Total deviations:** 2 auto-fixed (2 bugs)
**Impact on plan:** Both fixes necessary for compilation. No scope creep.

## Issues Encountered
None

## User Setup Required

**External services require manual configuration:**
- Run `migrations/shared_templates.sql` in Supabase SQL Editor to create the shared_templates table
- Enable pg_cron extension in Supabase Dashboard (Database > Extensions > search pg_cron > Enable)
- The pg_cron schedule query is included in the migration SQL

## Next Phase Readiness
- TemplateSharingService API ready for UI integration in plans 15-02 (share sheet) and 15-03 (import flow)
- Universal link handling via handleDeepLink ready for AppRouter integration

---
*Phase: 15-template-sharing*
*Completed: 2026-05-13*
