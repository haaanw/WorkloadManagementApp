---
phase: 45-measurement-wtp-instrumentation
plan: 02
subsystem: measurement
tags: [verdict-event, logging, sc4, post-session-outcome, design-system, localization]

requires:
  - phase: 45-measurement-wtp-instrumentation
    provides: VerdictEvent @Model + VerdictEventRepository + onDecisionRecorded hook (45-01)
  - phase: 44-suggest-confirm-verdict-ux
    provides: TodayVerdictViewModel.onDecisionRecorded seam + VerdictDecision shape
provides:
  - Live METRIC-01 logging (every accept/keep/feel decision writes one composite VerdictEvent)
  - SC4 ordering guard (WorkoutLogView wires onDecisionRecorded — seam never nil)
  - VerdictOutcomeSheet (no-guilt right/wrong/unsure post-session capture)
  - VM headline verdict + region capture (lastHeadlineVerdictRaw / lastHeadlineRegionRaw)
affects: [45-03, 45-04]

tech-stack:
  added: []
  patterns:
    - "Wire existing decision seam (no surface re-plumbing) → repository.log"
    - "Stable @State repository instance so the closure logs into one context (SC4)"
    - "Past-day-only outcome prompt via mostRecentAwaitingOutcome(before: startOfDay(today))"
    - "Source-grep SC4 guard: WorkoutLogView MUST contain onDecisionRecorded"

key-files:
  created:
    - WorkloadApp/Views/WorkoutLog/VerdictOutcomeSheet.swift
    - WorkloadAppTests/VerdictEventLoggingTests.swift
  modified:
    - WorkloadApp/ViewModels/TodayVerdictViewModel.swift
    - WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift
    - WorkloadApp/Resources/Localizable.xcstrings
    - "workload management/workload management.xcodeproj/project.pbxproj"

key-decisions:
  - "planDate logged as .now (today's planned session) — model normalizes to start-of-day"
  - "differed = decision.hadAdjustment (the surface already knows whether it adjusted)"
  - "Outcome prompt fires only for PAST planned-days (never mid-session; markCompleted unwired in prod)"
  - "Action mapping: .accepted→accepted, .keptPlan→keptPlan, .feel(.feelingStrong)→feelStrong, .feel(.feelingRough)→feelRough"

patterns-established:
  - "Non-visual VM enrichment: capture headline verdict/region the VM already computes but discarded"
  - "Equal-weight choice buttons via ONE shared builder (no color coding — DESIGN compliant)"

requirements-completed: [METRIC-01]

duration: 25min
completed: 2026-06-14
---

# Phase 45 Plan 02: Verdict-Event Logging + Post-Session Outcome Summary

**Wired the Phase-44 `onDecisionRecorded` seam into the 45-01 `VerdictEventRepository.log`, enriched the VM with the headline verdict/region it had been discarding, and added the no-guilt `VerdictOutcomeSheet` — making METRIC-01 LIVE and satisfying SC4 (the production surface provably wires the logger, so no validation user can reach the verdict without an event being recorded).**

## Performance

- **Duration:** ~25 min
- **Tasks:** 2
- **Files created:** 2 (1 view, 1 test)
- **Files modified:** 4 (VM, WorkoutLogView, xcstrings, pbxproj)

## Accomplishments
- `TodayVerdictViewModel` now captures `lastHeadlineVerdictRaw` ("go"/"modify"/"hold"/"defer") and `lastHeadlineRegionRaw` from the per-exercise `evaluateAndWrite` results (previously discarded) — non-visual enrichment, card untouched.
- `WorkoutLogView` constructs a stable `@State VerdictEventRepository` and wires `verdictVM.onDecisionRecorded` to `repository.log(...)` at VM construction — every accept/keep/feel decision logs exactly one composite VerdictEvent (SC4 seam never nil).
- `VerdictOutcomeSheet` presents for a past un-resolved VerdictEvent and writes right/wrong/unsure via `recordOutcome`; DESIGN-compliant (Rectangle, no shadow, Font.Tokens.*, no accent), en+zh-Hans.

## SC4 wiring (as implemented)
`WorkoutLogView.task(id: athletes.first?.id)` builds the VM + repository once, then sets:
```
vm.onDecisionRecorded = { [weak vm] decision in
    repository.log(
        decidedAt: decision.decidedAt,
        planDate: .now,                              // model applies start-of-day
        verdictKindRaw: vm.lastHeadlineVerdictRaw ?? "go",
        plannedTopSetKg: decision.plannedTopSetKg,
        adjustedTopSetKg: decision.adjustedTopSetKg,
        deltaKg: (decision.adjustedTopSetKg ?? decision.plannedTopSetKg) - decision.plannedTopSetKg,
        differed: decision.hadAdjustment,
        actionRaw: verdictActionRaw(decision.action),
        regionRaw: vm.lastHeadlineRegionRaw ?? MuscleRegion.fullBody.rawValue,
        reasonLine: decision.reasonLine,
        confidenceNote: vm.display?.confidenceNote,
        athlete: loggedAthlete)
}
```
The `VerdictEventLoggingTests.test_workoutLogView_wiresOnDecisionRecorded_sourceGrep()` asserts the literal `onDecisionRecorded` appears in WorkoutLogView.swift — the structural SC4 guard. The integration tests prove one composite event per decision with the correct action/differed/region/verdict.

## Post-session outcome
- `refreshOutcomePrompt()` queries `mostRecentAwaitingOutcome(athlete:, before: startOfDay(today))` on `.task(id:)` and on `showPlanToday` dismiss — only a PAST planned-day decision with no recorded outcome triggers the sheet (never mid-session).
- `VerdictOutcomeSheet` asks one calm question ("Was the call right?") with Right/Wrong/Not sure built from one shared `choiceButton` builder (equal weight, no color coding), shows the planned→adjusted number + reason as quiet read-only context, and emits "right"/"wrong"/"unsure" → `recordOutcome`.

## Task Commits

1. **Task 1: VM capture + onDecisionRecorded → log (SC4)** — `a87e156` (feat)
2. **Task 2: Post-session outcome capture (right/wrong/unsure)** — `6fafbfa` (feat)

## Deviations from Plan

None — plan executed as written. (The SUMMARY was authored in the subsequent serial execution pass; the two task commits had already landed on `main`.)

## Issues Encountered
None.

## User Setup Required
None.

## Next Phase Readiness
- 45-03 can bind `GreenLightEngine.compute` over `fetchAll` for the quiet Profile readout.
- 45-04 can read `fetchAll(athlete:).count` to gate the Sean-Ellis trigger and reuse `UpgradeSheet`.

## Self-Check: PASSED
- WorkloadApp/Views/WorkoutLog/VerdictOutcomeSheet.swift — FOUND
- WorkloadAppTests/VerdictEventLoggingTests.swift — FOUND
- Commit a87e156 — FOUND
- Commit 6fafbfa — FOUND

---
*Phase: 45-measurement-wtp-instrumentation*
*Completed: 2026-06-14*
