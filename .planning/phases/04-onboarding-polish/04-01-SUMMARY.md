---
phase: 04-onboarding-polish
plan: 01
subsystem: database
tags: [swiftdata, supabase, enums, sync, onboarding]

# Dependency graph
requires: []
provides:
  - TrainingFrequency and ExperienceLevel enums in Enums.swift
  - Nullable trainingFrequency and experienceLevel fields on Athlete model
  - SyncService round-trip support for onboarding fields (push/pull/bootstrap)
  - Supabase migration SQL for training_frequency and experience_level columns
affects: [04-02 onboarding-ui, 04-03 profile-settings, 04-04 approuter-gate]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Nullable Optional fields for SwiftData lightweight migration compatibility"
    - "Enum rawValue string serialization for Supabase text columns"

key-files:
  created:
    - .planning/phases/04-onboarding-polish/supabase-migration.sql
  modified:
    - WorkloadApp/Models/Enums.swift
    - WorkloadApp/Models/Athlete.swift
    - WorkloadApp/Services/SyncService.swift

key-decisions:
  - "Both fields are Optional with no default value to ensure SwiftData lightweight migration sets them to nil for existing records"
  - "Supabase columns are nullable text storing enum rawValue strings"

patterns-established:
  - "Onboarding enum pattern: String, Codable, CaseIterable, Identifiable with displayName and optional subtitle"

requirements-completed: [ONBRD-02]

# Metrics
duration: 7min
completed: 2026-04-22
---

# Phase 04 Plan 01: Onboarding Data Model Summary

**TrainingFrequency and ExperienceLevel enums with Athlete model fields and SyncService round-trip to Supabase**

## Performance

- **Duration:** 7 min
- **Started:** 2026-04-22T05:12:50Z
- **Completed:** 2026-04-22T05:20:18Z
- **Tasks:** 2 of 3 (Task 3 is checkpoint:human-action for Supabase migration)
- **Files modified:** 3

## Accomplishments
- Added TrainingFrequency enum with 4 cases and display names (1-2/3-4/5-6/7+ days/week)
- Added ExperienceLevel enum with 3 cases, display names, and subtitles
- Extended Athlete model with nullable trainingFrequency and experienceLevel fields
- Extended SyncService AthleteRow, pushAthlete, pullAthlete, bootstrapAthlete, and pullLinkedAthleteProfile with new fields
- Created Supabase migration SQL for the new columns

## Task Commits

Each task was committed atomically:

1. **Task 1: Add TrainingFrequency and ExperienceLevel enums + Athlete model fields** - `d095628` (feat)
2. **Task 2: Extend SyncService AthleteRow + push/pull/bootstrap for new fields** - `5ba5a51` (feat)
3. **Task 3: Run Supabase migration** - checkpoint:human-action (awaiting user)

## Files Created/Modified
- `WorkloadApp/Models/Enums.swift` - Added TrainingFrequency and ExperienceLevel enums with conformances
- `WorkloadApp/Models/Athlete.swift` - Added nullable trainingFrequency and experienceLevel properties
- `WorkloadApp/Services/SyncService.swift` - Extended AthleteRow, push/pull/bootstrap methods for new fields
- `.planning/phases/04-onboarding-polish/supabase-migration.sql` - ALTER TABLE adding two text columns

## Decisions Made
- Both Athlete fields are Optional with no default value for safe SwiftData lightweight migration
- Supabase columns are nullable text type storing enum raw values (camelCase strings like "oneToTwo", "beginner")

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added onboarding field mapping to pullLinkedAthleteProfile**
- **Found during:** Task 2 (SyncService extension)
- **Issue:** Plan only specified pushAthlete, pullAthlete, and bootstrapAthlete updates, but pullLinkedAthleteProfile also creates/updates Athlete records from AthleteRow and would silently drop the new fields
- **Fix:** Added trainingFrequency and experienceLevel mapping in both the existing-athlete update path and the new-athlete creation path of pullLinkedAthleteProfile
- **Files modified:** WorkloadApp/Services/SyncService.swift
- **Verification:** Build succeeds
- **Committed in:** 5ba5a51 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 missing critical)
**Impact on plan:** Essential for data consistency when coaches pull linked athlete profiles. No scope creep.

## Issues Encountered
- Worktree missing gitignored config files (RevenueCatConfig.swift, SupabaseConfig.swift) causing build failures unrelated to changes; resolved by copying from main repo

## User Setup Required

**Supabase migration must be run manually.** The migration SQL is at `.planning/phases/04-onboarding-polish/supabase-migration.sql`:

```sql
ALTER TABLE athletes
  ADD COLUMN training_frequency text,
  ADD COLUMN experience_level text;
```

Run in Supabase Dashboard SQL Editor. Note: The Supabase UI may differ from what is described -- confirm what you see before running.

## Next Phase Readiness
- Enums and model fields are ready for onboarding UI (plan 02)
- SyncService handles round-trip sync for both fields
- Supabase migration must be run before deploying app update (Task 3 checkpoint)

---
*Phase: 04-onboarding-polish*
*Completed: 2026-04-22*
