---
phase: 45-measurement-wtp-instrumentation
plan: 01
subsystem: measurement
tags: [swiftdata, verdict-event, green-light, metrics, privacy, composite-only, local-only]

requires:
  - phase: 44-suggest-confirm-verdict-ux
    provides: VerdictDecision event shape + onDecisionRecorded hook + Verdict label
provides:
  - VerdictEvent composite-only local @Model (METRIC-01 substrate)
  - VerdictEventRepository (@MainActor log / recordOutcome / fetch / mostRecentAwaitingOutcome)
  - GreenLightEngine (pure green-light / activation / Day-7-30 retention with injected asOf+calendar)
affects: [45-02, 45-03, 45-04]

tech-stack:
  added: []
  patterns:
    - "Composite-only local @Model (no raw biometric field names; source-grep guarded)"
    - "Local-only by omission (type absent from SyncService.swift)"
    - "Pure date-injected engine (asOf + calendar injected, no baked .now)"
    - "Repository test uses non-throwing tearDown() to dodge iOS 26.1 @MainActor deinit SIGABRT"

key-files:
  created:
    - WorkloadApp/Models/VerdictEvent.swift
    - WorkloadApp/Repositories/VerdictEventRepository.swift
    - WorkloadApp/Services/GreenLightEngine.swift
    - WorkloadAppTests/VerdictEventModelTests.swift
    - WorkloadAppTests/VerdictEventRepositoryTests.swift
    - WorkloadAppTests/GreenLightEngineTests.swift
  modified:
    - WorkloadApp/App/WorkloadApp.swift
    - "workload management/workload management.xcodeproj/project.pbxproj"

key-decisions:
  - "VerdictEvent.planDate normalized to start-of-day in init so green-light day-collapse is stable"
  - "Green-light day representative = latest decision of that start-of-day (deterministic)"
  - "Retention returns nil before firstDay+N horizon is reached (honest 'cannot know yet')"

patterns-established:
  - "Composite-only @Model + source-grep privacy fence"
  - "Date-injected pure engine (asOf/calendar) for deterministic metric tests"

requirements-completed: [METRIC-01, METRIC-02]

duration: 30min
completed: 2026-06-14
---

# Phase 45 Plan 01: Measurement Substrate Summary

**Composite-only local `VerdictEvent` @Model + `@MainActor` repository + pure date-injected `GreenLightEngine` (green-light / activation / Day-7-30 retention) — the measurement data + compute layer for the v2.0 validation loop, with no raw biometric ever stored and the type local-only by omission.**

## Performance

- **Duration:** ~30 min
- **Tasks:** 3 (Task 1 + Task 3 TDD; Task 2 standard)
- **Files created:** 6 (3 source, 3 test)
- **Files modified:** 2 (schema + pbxproj)

## Accomplishments
- `VerdictEvent` composite-only local @Model registered additively in the app schema; round-trips, no raw-biometric field names, absent from SyncService.
- `VerdictEventRepository` logs decisions, records right/wrong/unsure outcomes, fetches newest-first athlete-filtered, and surfaces the past-day un-resolved event for the outcome prompt.
- `GreenLightEngine` computes green-light rate (differing-day collapse, keptPlan excluded, nil on no signal), activation rate, and Day-7/Day-30 retention — all from injected `asOf` + `calendar`.

## VerdictEvent fields (composite-only, proving METRIC-01 privacy)
`id`, `decidedAt`, `planDate` (start-of-day), `verdictKindRaw` ("go"/"modify"/"hold"/"defer"), `plannedTopSetKg`, `adjustedTopSetKg?`, `deltaKg`, `differed`, `actionRaw` ("accepted"/"keptPlan"/"feelStrong"/"feelRough"), `regionRaw` (MuscleRegion label), `reasonLine`, `confidenceNote?`, `outcomeRaw?` ("right"/"wrong"/"unsure"), `outcomeRecordedAt?`, `updatedAt`, `athlete?`. **No HRV/RHR/sleep/temperature/HealthKit values** — source-grep guard enforces this.

## Green-light formula (as implemented)
- Collapse `differed == true` events to days via `calendar.startOfDay(for: planDate)`; **denominator** = distinct differing days.
- **numerator** = differing days whose representative event (latest `decidedAt` that day) has `actionRaw != "keptPlan"` AND `outcomeRaw == "right"`.
- `greenLightRate = numerator / denominator`; `nil` when denominator == 0.
- `activationRate = (events where actionRaw != "keptPlan") / totalEvents`; nil when no events.
- `retention(N)`: `firstDay = startOfDay(min decidedAt)`; if `asOf < firstDay + N days` → nil; else `true` iff any `decidedAt >= firstDay + N days`.

## Task Commits

1. **Task 1: VerdictEvent @Model + schema + privacy guards** — `ea1be33` (test) → `0d4444f` (feat)
2. **Task 2: VerdictEventRepository** — `b1dd74d` (feat)
3. **Task 3: GreenLightEngine** — `65750a7` (test) → `bab384d` (feat)

## Decisions Made
- planDate normalized to start-of-day in the model init (callers can pass "today" raw; 45-02 relies on this).
- Day representative for green-light = latest `decidedAt` of the start-of-day group.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Repository test crashed on iOS 26.1 sim @MainActor deinit**
- **Found during:** Task 2 (VerdictEventRepositoryTests)
- **Issue:** Storing the `@MainActor VerdictEventRepository` as a test property and releasing it in `tearDownWithError()` tripped `swift_task_deinitOnExecutorMainActorBackDeploy` → libmalloc double-free → SIGABRT (every test failed at 0.000s on host launch). Confirmed via crash log stack.
- **Fix:** Switched to a non-throwing `tearDown()` (mirrors the documented PlannedSessionRepositoryTests pattern) so the `@MainActor` class releases inline on the main actor instead of inside the failable-teardown error-observation wrapper.
- **Files modified:** WorkloadAppTests/VerdictEventRepositoryTests.swift
- **Verification:** All 5 repository tests green after the change.
- **Committed in:** `b1dd74d`

---

**Total deviations:** 1 auto-fixed (1 blocking).
**Impact on plan:** Test-harness fix only; no production behavior change. No scope creep.

## Issues Encountered
- The @MainActor deinit SIGABRT (above) — resolved by the non-throwing tearDown pattern, now documented in the test file for the rest of the phase.

## User Setup Required
None.

## Next Phase Readiness
- 45-02 can wire `onDecisionRecorded → VerdictEventRepository.log` and present the outcome prompt via `mostRecentAwaitingOutcome`.
- 45-03 can bind `GreenLightEngine.compute` over `fetchAll`.

---
*Phase: 45-measurement-wtp-instrumentation*
*Completed: 2026-06-14*
