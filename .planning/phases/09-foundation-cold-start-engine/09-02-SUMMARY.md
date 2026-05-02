---
phase: 09-foundation-cold-start-engine
plan: 02
subsystem: cold-start-engine
tags: [computation, pure-engine, ewma, cold-start]
dependency_graph:
  requires: [WorkloadCalculator.sessionTSS]
  provides: [ColdStartEngine.computeSeed]
  affects: []
tech_stack:
  added: []
  patterns: [pure-struct-engine, steady-state-ewma-shortcut]
key_files:
  created:
    - WorkloadApp/Services/ColdStartEngine.swift
  modified:
    - "workload management/workload management.xcodeproj/project.pbxproj"
decisions:
  - "Used dailyTSS * 7.0 form instead of dailyTSS / atlLambda for clarity (mathematically equivalent)"
  - "Included sessionTSS in SeedResult for transparency and debugging"
metrics:
  duration: 6m 21s
  completed: 2026-05-02T05:59:39Z
  tasks_completed: 1
  tasks_total: 1
  files_created: 1
  files_modified: 1
---

# Phase 09 Plan 02: ColdStartEngine Summary

Pure computation engine for cold-start ATL/CTL seeding using steady-state EWMA shortcut with weeksAtLevel ramp discount, delegating TSS to WorkloadCalculator.

## What Was Built

ColdStartEngine is a stateless pure struct with a single static method `computeSeed(input:)` that converts questionnaire answers (sessions/week, average duration, typical RPE, weeks at current level) into seeded ATL and CTL values.

### Key Implementation Details

- **TSS delegation**: Calls `WorkloadCalculator.sessionTSS(durationSeconds:sessionRPE:)` for session stress computation -- single source of truth for the sRPE formula
- **Daily TSS**: `(sessionTSS * sessionsPerWeek) / 7.0` -- spreads weekly training stress across days
- **Seeded ATL**: `dailyTSS * 7.0` -- steady-state EWMA at atlLambda = 1/7
- **Seeded CTL**: `dailyTSS * 28.0 * ramp` -- steady-state EWMA at ctlLambda = 1/28, discounted by program duration
- **Ramp factor**: `max(0.3, min(1.0, weeksAtLevel / 6.0))` -- athletes who recently changed programs get 30-100% of theoretical steady-state CTL

### Input Validation

- RPE clamped to [1.0, 10.0] before computation
- Zero sessions or zero duration returns all-zero SeedResult (safe default)

### Sanity Check (Test 1 from plan)

sessionsPerWeek=4, avgDuration=60min, RPE=6.0, weeksAtLevel=8:
- sessionTSS = 1.0hr * 6.0 * 0.6 = 3.6
- dailyTSS = (3.6 * 4) / 7 = 2.057
- seededATL = 2.057 * 7 = 14.4
- seededCTL = 2.057 * 28 * 1.0 = 57.6 (ramp=1.0, capped since 8 > 6)

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Implement ColdStartEngine with input validation and steady-state EWMA computation | c264753 | ColdStartEngine.swift (new), project.pbxproj (modified) |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Copied gitignored config files for build verification**
- **Found during:** Task 1 verification
- **Issue:** SupabaseConfig.swift and RevenueCatConfig.swift are gitignored and not present in worktree, causing build failure
- **Fix:** Copied from main repo directory to enable build; files remain gitignored and untracked
- **Files modified:** None (gitignored files only)

### Pre-existing Issues (Out of Scope)

AppRouter.swift has build errors related to Supabase SDK import resolution (`property 'auth' is not available due to missing import of defining module 'Supabase'`). This is a pre-existing issue not introduced by this plan. ColdStartEngine.swift compiles without errors (no errors mentioning ColdStartEngine in build output).

## Decisions Made

1. **Used explicit multiplication form**: `dailyTSS * 7.0` and `dailyTSS * 28.0 * ramp` instead of `dailyTSS / atlLambda` and `(dailyTSS / ctlLambda) * ramp`. Mathematically equivalent but clearer for code review (follows research recommendation).
2. **Included sessionTSS in SeedResult**: Plan specified it in the struct. Useful for UI display and debugging questionnaire inputs.

## Known Stubs

None. ColdStartEngine is a complete, functional computation engine.

## Self-Check: PASSED

- [x] `WorkloadApp/Services/ColdStartEngine.swift` exists
- [x] Commit c264753 exists in git log
- [x] All 17 acceptance criteria verified
- [x] ColdStartEngine.swift included in pbxproj (4 references)
