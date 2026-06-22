---
phase: 42-plan-input-today-s-planned-session-adjustable-targets
plan: 02
subsystem: database
tags: [swiftdata, repository, prescribedworkout, frozen-copy, deepcopygroups, planned-session]

requires:
  - phase: 42-01
    provides: TemplateSet additive-nullable verdict-target slots carried by frozen prescription copies
provides:
  - "PlannedSessionRepository — planFromTemplate (frozen deep-copy), planManualLift (one-off, templateId nil), fetchTodaysPlannedSession"
  - "Today's planned session expressed as an existing PrescribedWorkout (no new hierarchy), with no sync path"
affects: [42-03, 43-verdict-engine, 44-verdict-ui]

tech-stack:
  added: []
  patterns:
    - "@MainActor final class …Repository(modelContext:) constructed at point of use (mirrors TemplateRepository)"
    - "Frozen-snapshot designation via WorkoutTemplate.deepCopyGroups() — source template never mutated"
    - "fetch-all + Swift filter instead of optional-relationship #Predicate (iOS 26.1 in-memory trap)"
    - "Self-coached denormalization: athleteId reused as coachId on the PrescribedWorkout"

key-files:
  created:
    - WorkloadApp/Repositories/PlannedSessionRepository.swift
    - WorkloadAppTests/PlannedSessionRepositoryTests.swift
  modified:
    - workload management/workload management.xcodeproj/project.pbxproj

key-decisions:
  - "planManualLift reuses athleteId as coachId (self-coached) and sets templateId nil for one-off entries"
  - "Repository makes NO sync/push call — PrescribedWorkout has no sync path (verified absent from SyncService)"
  - "fetchTodaysPlannedSession filters out .skipped and bounds to [startOfDay, nextDay)"

patterns-established:
  - "Designate-today path produces an existing PrescribedWorkout; verdict writes the frozen copy, never the program"

requirements-completed: [PLAN-10, PLAN-11]

duration: 18min
completed: 2026-06-13
---

# Phase 42 Plan 02: PlannedSessionRepository Summary

**A `PlannedSessionRepository` that designates "today's planned session" two ways — frozen deep-copy of an existing template (source untouched) or a one-off manual lift (templateId nil) — producing an existing `PrescribedWorkout` whose working sets already carry the Plan-01 verdict slots at default, with no Supabase sync path.**

## Performance

- **Duration:** ~18 min (incl. resolving a toolchain test-host deinit crash)
- **Started:** 2026-06-13T14:52Z (approx, after 42-01)
- **Completed:** 2026-06-13T15:11:37Z
- **Tasks:** 2
- **Files modified:** 3 (2 created, 1 pbxproj)

## Accomplishments
- Implemented `PlannedSessionRepository` with three lean methods (`planFromTemplate`, `planManualLift`, `fetchTodaysPlannedSession`) mirroring `TemplateRepository` exactly.
- Frozen-copy isolation: `planFromTemplate` uses `deepCopyGroups()`; mutating the prescription leaves the source template unchanged (proven by test).
- Registered the new app-target file with 4 explicit pbxproj entries (mirrors the CrossModalFatigueEngine quad); exactly one fileRef, no stray duplicates, compiles into the app target.
- 4 green tests covering frozen-copy isolation, manual one-off graph, fetch-today, and verdict-slot defaults.

## Task Commits

1. **Task 1: PlannedSessionRepository + pbxproj registration** - `5c0409e` (feat)
2. **Task 2: Repository tests (frozen-copy / manual / fetch-today / verdict-slot)** - `fee4ca6` (test)

## Files Created/Modified
- `WorkloadApp/Repositories/PlannedSessionRepository.swift` - The 3-method `@MainActor final class` repository.
- `WorkloadAppTests/PlannedSessionRepositoryTests.swift` - 4-test suite (in-memory ModelContainer).
- `workload management/workload management.xcodeproj/project.pbxproj` - 4 entries for PlannedSessionRepository.swift (object id prefix EE4201).

## Decisions Made
- Self-coached: `athleteId` is reused as `coachId` on the created `PrescribedWorkout` (matches the existing prescribe denormalization; there is no coach in the self-coached reset).
- No sync/push call — `PrescribedWorkout` is absent from `SyncService` (verified), so planned sessions stay local. The stray dormant `pushPrescribedWorkout` was NOT reintroduced.
- `setCount` guarded with `max(1, setCount)` so a manual entry always has at least one working set.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Test-host SIGABRT on `@MainActor` repository deinit (toolchain bug)**
- **Found during:** Task 2 (running PlannedSessionRepositoryTests)
- **Issue:** All four tests crashed at 0.000s with `Abort trap: 6`. The crash log triggered thread showed `PlannedSessionRepository.__deallocating_deinit` → `swift_task_deinitOnExecutorMainActorBackDeploy` → `___BUG_IN_CLIENT_OF_LIBMALLOC_POINTER_BEING_FREED_WAS_NOT_ALLOCATED`. This is a known iOS 26.1-simulator libswift_Concurrency back-deploy bug deallocating a `@MainActor` class as a synchronous-test-method local. (No prior test in the suite instantiated a `@MainActor` class, which is why this surfaced here first.)
- **Fix:** Restructured the test to OWN the `ModelContainer` / `ModelContext` / `PlannedSessionRepository` as stored XCTestCase properties (set in `setUpWithError`, cleared in `tearDown`) instead of method locals. Lifetime is then managed at the (also `@MainActor`) XCTestCase level, sidestepping the mid-method back-deploy deinit. No production-code change — the repository itself is correct.
- **Files modified:** WorkloadAppTests/PlannedSessionRepositoryTests.swift
- **Verification:** All 4 tests pass on a single clone (no per-test crash restarts).
- **Committed in:** fee4ca6 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking, test-infra only)
**Impact on plan:** Test-harness lifetime adjustment only; no scope creep, no production behavior change. Documents the `@MainActor`-repo-in-XCTest pattern for future test authors (this is the first such test in the suite).

## Issues Encountered
The toolchain deinit crash above (resolved). Confirms the memory-noted "XCTest host crash blocker" manifests specifically when a `@MainActor` class is deallocated as a test-method local on this toolchain.

## Next Phase Readiness
- 42-03 (Plan-Today UI) can construct `PlannedSessionRepository(modelContext:)` at point of use and call `planFromTemplate` / `planManualLift` from the two designation paths. Signatures match the 42-03 interfaces block exactly.

## Self-Check: PASSED

- FOUND: WorkloadApp/Repositories/PlannedSessionRepository.swift
- FOUND: WorkloadAppTests/PlannedSessionRepositoryTests.swift
- FOUND: .planning/.../42-02-SUMMARY.md
- FOUND commits: 5c0409e (feat), fee4ca6 (test)

---
*Phase: 42-plan-input-today-s-planned-session-adjustable-targets*
*Completed: 2026-06-13*
