---
phase: 44-suggest-and-confirm-verdict-surface
plan: 01
subsystem: ui
tags: [swiftdata, observable, verdict, autonomy, nocebo, suggest-and-confirm, mvvm]

# Dependency graph
requires:
  - phase: 43-today-verdict-engine
    provides: TodayVerdictService.evaluateAndWrite seam + makeDecisionInput; TemplateSet adjusted* / verdictReason slots
  - phase: 42-plan-input
    provides: TemplateSet verdictAppliedAt / athleteOverrode slots; PrescribedWorkout frozen-copy; PlannedSessionRepository
provides:
  - VerdictDecision.swift — FeelOverride / VerdictAction / VerdictDecision / TodayVerdictDisplay value types
  - VerdictDecisionApplier — pure static slot mutations (accept/keep/effectiveTargetKg) honoring SC1/SC3
  - TodayVerdictViewModel — @MainActor @Observable orchestration: assemble inputs, write slots, accept/keepPlan/feelOverride, emit VerdictDecision
affects: [44-02 (card consumes TodayVerdictDisplay + VM actions), 45-measurement (onDecisionRecorded logs VerdictDecision)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pure decision applier (enum + static funcs) mutating only the two Phase-44 slots — authored number never written"
    - "@MainActor @Observable VM holds service + repositories as STORED props (iOS-26.1-sim deinit-safety)"
    - "Decision event (VerdictDecision) + onDecisionRecorded closure seam so Phase 45 logs by wiring one closure"

key-files:
  created:
    - WorkloadApp/Services/VerdictDecision.swift
    - WorkloadApp/ViewModels/TodayVerdictViewModel.swift
    - WorkloadAppTests/VerdictDecisionApplierTests.swift
    - WorkloadAppTests/TodayVerdictViewModelTests.swift
  modified:
    - workload management/workload management.xcodeproj/project.pbxproj

key-decisions:
  - "effectiveTargetKg resolves the trained number at READ time from verdictAppliedAt — authored targetWeightKg is never overwritten (SC1)"
  - "feel.feelingStrong ⇒ keep-plan; feel.feelingRough ⇒ accept ONLY where the engine produced an adjustment (never fabricate a trim)"
  - "crossModalResult passed as nil (shadow gate OFF) — single line to revisit on a future gate flip"
  - "session headline = per-exercise top set with max weight across the session; decision methods apply to EVERY exercise's top set"

patterns-established:
  - "Slot-invariant unit tests prove accept/keep never touch targetWeightKg + source authored template untouched"
  - "Cold-start (built==nil) ⇒ deferred display + still-learning confidence note, hasAdjustment false"

requirements-completed: [MOD-10, MOD-11, MOD-12]

# Metrics
duration: ~35min
completed: 2026-06-14
---

# Phase 44 Plan 01: Suggest-and-Confirm State + Decision Layer Summary

**Pure VerdictDecisionApplier (accept/keep/feel slot mutations that never overwrite the authored number or the source template) plus a @MainActor @Observable TodayVerdictViewModel that assembles real readiness inputs, drives the Phase-43 service to write the verdict slots, and emits a loggable VerdictDecision.**

## Performance

- **Duration:** ~35 min
- **Started:** 2026-06-13T17:17:15Z
- **Completed:** 2026-06-14T01:35:00+08:00
- **Tasks:** 2
- **Files modified:** 5 (4 created + pbxproj)

## Accomplishments
- `VerdictDecision.swift`: `FeelOverride` (first-class feel input), `VerdictAction`/`VerdictDecision` (Phase-45 loggable event, composite-only), `TodayVerdictDisplay` (pure render value), and `VerdictDecisionApplier` (accept sets `verdictAppliedAt`; keep sets `athleteOverrode`; `effectiveTargetKg` resolves adjusted only once accepted).
- `TodayVerdictViewModel`: `refresh(athlete:)` assembles recovery/workload/session/fatigue inputs (mirroring DashboardViewModel), drives `TodayVerdictService.evaluateAndWrite` to populate the slots, and builds the headline `TodayVerdictDisplay`. `accept()`/`keepPlan()`/`feelOverride(_:)` apply pure slot mutations, persist, rebuild display, and emit a `VerdictDecision` via `onDecisionRecorded`.
- Cold-start defers honestly (no real history ⇒ `built == nil` ⇒ `.deferred` + still-learning note, no fabricated trim).
- 15 new tests green (8 applier + 7 VM); regression fences (DualRunFlagFence, VerdictSurfaceActivation, TodayVerdictService) still green — 40 across the combined run.

## Task Commits

1. **Task 1 (RED): failing slot-invariant tests** - `28b49fa` (test)
2. **Task 1 (GREEN): VerdictDecisionApplier slot mutations** - `ba5c0dc` (feat)
3. **Task 2: TodayVerdictViewModel** - `1fb0792` (feat)

## Files Created/Modified
- `WorkloadApp/Services/VerdictDecision.swift` - decision value types + pure applier (Foundation only)
- `WorkloadApp/ViewModels/TodayVerdictViewModel.swift` - @MainActor @Observable orchestration
- `WorkloadAppTests/VerdictDecisionApplierTests.swift` - accept/keep/effective + source-untouched proofs
- `WorkloadAppTests/TodayVerdictViewModelTests.swift` - refresh/display/decision-emit/cold-start
- `workload management/.../project.pbxproj` - 4 entries each for VerdictDecision (AA4401) + TodayVerdictViewModel (AA4402)

## Decisions Made
- Followed plan as specified. `feelingRough` accepts only top sets with a real adjustment (honest — never fabricates a trim the engine did not produce); `feelingStrong` dismisses via keep-plan.
- Headline display reads the session top set; decision methods apply to every exercise's per-exercise top set (matching the service's per-exercise write rule).

## Deviations from Plan
None - plan executed exactly as written. (TDD Task 1 followed RED→GREEN; Task 2 is non-TDD per the plan.)

## Issues Encountered
- A RED-phase test had an ambiguous `<` between bare numeric literals that cascaded into `XCTAssertEqual` enum inference; fixed by binding the operands to explicit `Double` lets so the RED compiled and failed on assertions (not on compile). Resolved before the RED commit.

## Next Phase Readiness
- Plan 44-02 can mount `TodayVerdictCard(display:weightUnit:onAccept:onKeepPlan:onFeel:)` against `TodayVerdictViewModel`.
- Phase 45 logs decisions by assigning `viewModel.onDecisionRecorded`.

## Self-Check: PASSED
- All 4 created files present on disk.
- All 3 task commits present in git (28b49fa, ba5c0dc, 1fb0792).

---
*Phase: 44-suggest-and-confirm-verdict-surface*
*Completed: 2026-06-14*
