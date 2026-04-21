---
phase: 03-training-intelligence
plan: 01
subsystem: services, models, database
tags: [swift, swiftdata, supabase, periodization, fatigue-analysis, behavior-tags, pure-engines]

# Dependency graph
requires:
  - phase: 01-app-store-launch
    provides: Core models (Athlete, WorkoutSession, WorkloadSnapshot, RecoverySnapshot, WellnessCheckIn), SyncService, repository pattern
provides:
  - BehaviorTag SwiftData model with Athlete and WellnessCheckIn relationships
  - BehaviorTagRepository with CRUD and tag name sanitization
  - BehaviorTag Supabase sync (push/pull via SyncService)
  - PeriodizationEngine for training phase detection (Building/Pushing/Tapering/Maintaining)
  - FatiguePatternEngine for recovery-load lag correlation insights
  - BehaviorCorrelationEngine for behavior tag vs recovery impact analysis
affects: [03-training-intelligence plans 03 and 04 for UI integration]

# Tech tracking
tech-stack:
  added: []
  patterns: [lag-correlation analysis, volume+intensity trend classification, behavior-recovery correlation with minimum sample thresholds]

key-files:
  created:
    - WorkloadApp/Models/BehaviorTag.swift
    - WorkloadApp/Repositories/BehaviorTagRepository.swift
    - WorkloadApp/Services/PeriodizationEngine.swift
    - WorkloadApp/Services/FatiguePatternEngine.swift
    - WorkloadApp/Services/BehaviorCorrelationEngine.swift
  modified:
    - WorkloadApp/Models/Athlete.swift
    - WorkloadApp/Models/WellnessCheckIn.swift
    - WorkloadApp/App/WorkloadApp.swift
    - WorkloadApp/Services/SyncService.swift
    - workload management/workload management.xcodeproj/project.pbxproj

key-decisions:
  - "Used acuteLoad from WorkloadSnapshot + trainingStress from WorkoutSession as TSS proxy for fatigue pattern detection"
  - "90-day analysis window cap on all engines per T-03-03 threat mitigation"
  - "Sport-type-specific fatigue patterns detected via WorkoutSession.sportType grouping"

patterns-established:
  - "Lag-correlation pattern: collect recovery deltas at 1-3 day offsets from high-load events, compare against non-high-load baseline"
  - "Sufficiency check pattern: engines expose a static checkSufficiency() returning structured result before analysis"
  - "Behavior correlation requires 5+ samples in BOTH with-tag and without-tag groups before reporting"

requirements-completed: [INTEL-01, INTEL-03, INTEL-04, INTEL-06, INTEL-07]

# Metrics
duration: 10min
completed: 2026-04-21
---

# Phase 03 Plan 01: Training Intelligence Foundation Summary

**Three pure computation engines (periodization, fatigue patterns, behavior correlation) plus BehaviorTag model with Supabase sync and 5+ sample threshold enforcement**

## Performance

- **Duration:** 10 min
- **Started:** 2026-04-21T09:09:51Z
- **Completed:** 2026-04-21T09:19:38Z
- **Tasks:** 2
- **Files modified:** 10 (5 created, 5 modified)

## Accomplishments
- Created BehaviorTag SwiftData model with relationships to Athlete and WellnessCheckIn, repository with tag name sanitization (T-03-01), schema registration, and full Supabase sync
- Built PeriodizationEngine that classifies training phases from volume+intensity trends across 6-week windows with rest-week guard and data sufficiency checks
- Built FatiguePatternEngine that detects recovery dip patterns at 1-3 day lags after high-load sessions, including sport-type-specific breakdowns
- Built BehaviorCorrelationEngine that computes recovery impact percentages per behavior tag, enforcing 5+ minimum samples per group (D-09)

## Task Commits

Each task was committed atomically:

1. **Task 1: BehaviorTag model + repository + schema/relationship wiring + SyncService** - `af1f3b9` (feat)
2. **Task 2: PeriodizationEngine + FatiguePatternEngine + BehaviorCorrelationEngine** - `8b14f0f` (feat)

## Files Created/Modified
- `WorkloadApp/Models/BehaviorTag.swift` - SwiftData @Model with date, tagName, isActive, isCustom fields and relationships
- `WorkloadApp/Repositories/BehaviorTagRepository.swift` - CRUD with fetchTagsForDate, fetchAllTags, fetchActiveTags, fetchCustomTagNames, upsertTag (with T-03-01 sanitization), deleteCustomTag
- `WorkloadApp/Services/PeriodizationEngine.swift` - Pure struct: detectPhase() returns PhaseResult, checkSufficiency() returns SufficiencyResult
- `WorkloadApp/Services/FatiguePatternEngine.swift` - Pure struct: detectPatterns() returns up to 5 Insights with natural language text and confidence
- `WorkloadApp/Services/BehaviorCorrelationEngine.swift` - Pure struct: computeCorrelations() returns TagCorrelation array, checkSufficiency() returns SufficiencyInfo array
- `WorkloadApp/Models/Athlete.swift` - Added behaviorTags cascade relationship
- `WorkloadApp/Models/WellnessCheckIn.swift` - Added behaviorTags cascade relationship
- `WorkloadApp/App/WorkloadApp.swift` - Added BehaviorTag.self to Schema array
- `WorkloadApp/Services/SyncService.swift` - Added BehaviorTagRow, pushBehaviorTags, pullBehaviorTags
- `workload management/workload management.xcodeproj/project.pbxproj` - Added all 5 new files to compile sources

## Decisions Made
- Used acuteLoad from WorkloadSnapshot combined with trainingStress from WorkoutSession as dual TSS source for fatigue pattern detection, since not all days have both data sources
- Applied 90-day analysis window cap on all three engines per T-03-03 denial of service threat mitigation
- Sport-type-specific fatigue patterns leveraged existing WorkoutSession.sportType field with displayName for natural language output

## Deviations from Plan

None - plan executed exactly as written.

## User Setup Required

**Supabase behavior_tags table must be created.** Copy ONLY the SQL below and run it in Supabase Dashboard -> SQL Editor -> New Query -> Run.

Note: The Supabase UI may differ from what is described here. Please confirm what you see before proceeding.

```sql
-- Create behavior_tags table for INTEL-06/INTEL-07 behavior tagging sync
CREATE TABLE IF NOT EXISTS behavior_tags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    athlete_id UUID NOT NULL REFERENCES athletes(id) ON DELETE CASCADE,
    date TIMESTAMPTZ NOT NULL,
    tag_name TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    is_custom BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE behavior_tags ENABLE ROW LEVEL SECURITY;

-- RLS policy: athletes can only access their own tags
CREATE POLICY "athlete_own_tags" ON behavior_tags
    FOR ALL
    USING (athlete_id = auth.uid()::uuid)
    WITH CHECK (athlete_id = auth.uid()::uuid);

-- Index for common queries
CREATE INDEX idx_behavior_tags_athlete_date ON behavior_tags(athlete_id, date);
```

## Issues Encountered
- iPhone 16 Pro simulator not available (Xcode 26.1 uses iPhone 17 series) -- switched to iPhone 17 Pro simulator
- Gitignored config files (SupabaseConfig.swift, RevenueCatConfig.swift) missing from worktree -- copied from main repo

## Next Phase Readiness
- All three engines ready for UI integration in Plans 03 and 04
- BehaviorTag model and repository ready for wellness check-in UI integration
- Supabase table creation is a manual prerequisite before sync will function

---
*Phase: 03-training-intelligence*
*Completed: 2026-04-21*
