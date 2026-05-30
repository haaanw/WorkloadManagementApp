---
phase: 25-soreness-tweak-self-log
plan: 02
subsystem: shadow-validation-harness
tags: [shadow-harness, niggle-severity, date-contract, local-only, swiftdata]
requires: [25-01]
provides:
  - "ShadowPredictor.Outcome.niggleSeverity (5th graded outcome, max SorenessLog severity 0-10, 0 if none)"
  - "CyclePredictionLog.niggleSeverityActual: Double? (additive, local-only column)"
  - "ShadowArmPrediction.outcomeRaw(.niggleSeverity) == \"niggleSeverity\" (stable key)"
  - "ShadowAnalyticsService date-contract-safe niggle resolution (max-on-targetDay, 0-if-none)"
affects:
  - WorkloadApp/Services/ShadowPredictor.swift
  - WorkloadApp/Models/CyclePredictionLog.swift
  - WorkloadApp/Models/ShadowArmPrediction.swift
  - WorkloadApp/Services/ShadowAnalyticsService.swift
  - WorkloadAppTests/ShadowDataContractTests.swift
tech-stack:
  added: []
  patterns:
    - "By-day max-severity grouping via date-only #Predicate + athlete-filter-in-Swift (dodges iOS 26.1 optional-relationship trap)"
    - "Dense always-resolvable label (?? 0.0) mirroring completionActual"
    - "Unpredicted outcome posture: both arms return nil; harness tolerates n=0"
key-files:
  created: []
  modified:
    - WorkloadApp/Services/ShadowPredictor.swift
    - WorkloadApp/Models/CyclePredictionLog.swift
    - WorkloadApp/Models/ShadowArmPrediction.swift
    - WorkloadApp/Services/ShadowAnalyticsService.swift
    - WorkloadAppTests/ShadowDataContractTests.swift
decisions:
  - "D-04: graded max-niggle-severity-in-window, 0 if none (dense label)"
  - "D-05: .pain (whole-body 1-5) left byte-unchanged; no binary breakdown outcome added"
  - "D-06: resolve strictly on startOfDay(targetDate) — no same-day leak"
  - "Both arms return nil for .niggleSeverity (nil, not the 50.0 neutral on a 0-10 scale)"
  - "SorenessLog.self registered in the test container schema (required — resolution test fetches SorenessLog through it)"
metrics:
  duration: "~1h"
  completed: 2026-05-30
  tasks: 2
  files_modified: 5
  branch: phase-25-02-niggle-severity-outcome
---

# Phase 25 Plan 02: Graded .niggleSeverity Shadow Outcome Summary

Added the 5th **graded** shadow-validation outcome `.niggleSeverity` end-to-end and date-contract-safe — its actual is the max `SorenessLog.severity` (0-10) on the prediction's `targetDate`, 0 if none — so Phase 27's localized Strain-Risk channel has a resolvable target the moment it ships. Validation plumbing only: no arm predicts it (both return nil), the harness stays gated OFF, and `.pain` is untouched.

## What was built

**Task 1 — the case + column + all switch-ripple sites** (`47fb9db`):
- `ShadowPredictor.Outcome` gains a 5th case `.niggleSeverity` (graded 0-10, max-in-window, 0 if none).
- Every `Outcome` switch the compiler flagged was updated: `phaseOffset` luteal switch (returns `0` — no cycle offset in v1), `recordPrediction.series(for:)` (returns `[]` — no input series), `ShadowArmPrediction.outcomeRaw` (returns `"niggleSeverity"`), and all three `actual(_:)` switches in `aggregate` / `pairs` / `pairedMAEDifferenceCI` (return `row.niggleSeverityActual`).
- `CyclePredictionLog` gains `var niggleSeverityActual: Double?` — additive, default nil, local-only, **no Codable**. Init param + assignment added alongside `painActual`.
- Both registered arms (`baseline`, `cycleAware`) guard `nil` for `.niggleSeverity` (`guard outcome != .niggleSeverity else { return nil }`) — returning the 50.0 neutral on a 0-10 scale would pollute metrics; nil is correct and the harness tolerates it.
- `.pain` branches are **byte-unchanged** everywhere (verified via diff grep).

**Task 2 — date-contract-safe resolution + test schema** (`9474d64`):
- New private helper `ShadowAnalyticsService.fetchMaxNiggleSeverityByDay(startDay:athlete:modelContext:)` — a date-windowed `FetchDescriptor<SorenessLog>` keyed by `date >= startDay` only, with the athlete match applied **in Swift** after the fetch (mirrors `SorenessLogRepository.fetchRecent` — dodges the iOS 26.1 in-memory optional-relationship `#Predicate` trap). Groups by `startOfDay(log.date)` taking the **max** `Double(severity)` per day.
- In `resolveOutcomes`, the per-row join sets `row.niggleSeverityActual = maxNiggleSeverityByDay[day] ?? 0.0`, where `day = startOfDay(row.targetDate)` — the **target day only**, never `predictionDate`/`row.date`. The `?? 0.0` makes it a dense, always-resolvable label (like `completionActual`); the row's existing `resolvedAt` logic is unchanged.
- `SorenessLog.self` registered in `ShadowDataContractTests.makeContext()`'s `Schema([...])` array — **required**: the round-trip test inserts/fetches `SorenessLog` through that container and SwiftData would `fatalError` without it.

## Tests (15 total in ShadowDataContractTests, all pass)

New Task 1 tests: `outcomeRaw` stable key, `phaseOffset == 0` in every phase, both arms return nil (with sanity that a normal outcome still predicts), not engine-derived, `aggregate` omits `.niggleSeverity` (n=0, no crash).

New Task 2 tests: `test_sorenessLog_roundTripsThroughContainer` (schema registration — insert/fetch through the container, no fatalError), `maxOnTargetDay` (severities 4+8 → 8.0), `zeroIfNone` (→ 0.0), `noSameDayLeak` (niggle on prediction-day D does NOT resolve the D→D+1 row; only a niggle on D+1 does → 5.0), `lateDayBucketsToStartOfDay` (23:30 on D+1 still resolves D+1).

The grouping/join semantics (max-in-window, 0-if-none, no-leak, late-day bucketing) are asserted via pure helpers over `[SorenessLog]` arrays that replicate `fetchMaxNiggleSeverityByDay` + the `?? 0.0` join — this sidesteps the iOS 26.1 optional-relationship trap (same XCTSkip rationale the existing `ShadowAnalyticsServiceTests.resolveOutcomes` uses), while the rows are still round-tripped through the (now SorenessLog-registered) container in the schema-registration test.

## Build verification

`xcodebuild test -only-testing:WorkloadAppTests/ShadowDataContractTests` on iPhone 17 Pro Max sim (id `8E872500-703D-4292-9758-38ADFCCFB126`, scheme `workload management`): **TEST SUCCEEDED**, 15/15 ShadowDataContractTests pass, 0 failures, 0 skipped. SourceKit diagnostics were ignored per plan; xcodebuild is the sole proof.

## Constraint compliance

- **D-05 (.pain untouched):** `git diff` shows no added/removed `.pain` lines — byte-unchanged.
- **Both arms nil:** `test_niggleSeverity_bothArmsReturnNil` passes; `aggregate` omits `.niggleSeverity` with n=0 (no crash).
- **D-06 (no same-day leak):** join uses `startOfDay(row.targetDate)` ONLY; the only `predictionDate`/`row.date` mention is a comment. `test_niggleResolution_noSameDayLeak` passes.
- **D-04 (0-if-none dense label):** `?? 0.0` always resolves once targetDate elapses.
- **Privacy (local-only):** `grep "SorenessLog\|niggleSeverity" SyncService.swift` returns nothing; no `Codable` on the new column. `niggleSeverityActual` lives on the already-local-only `CyclePredictionLog`.
- **pbxproj:** NOT touched by 25-02 (edits existing files only, as expected).

## Deviations from Plan

**[Process — branch isolation, not a code deviation]** 25-02 was executed in a working tree shared with the parallel Plan 25-03, which had switched the checkout onto branch `phase-25-03-niggle-injury-deriver` and left its own files staged in the index. An interim Task 2 commit accidentally swept 25-03's staged files (`NiggleInjuryDeriver.swift`, its tests, pbxproj additions) into the commit. This was corrected: the two clean 25-02 commits were moved onto a dedicated branch `phase-25-02-niggle-severity-outcome` (rooted on `main`), the contaminating 25-03 files were removed from the 25-02 Task 2 commit, and the `phase-25-03-niggle-injury-deriver` branch was reset back to `main` with 25-03's working-tree files preserved for its own process to commit. The final 25-02 branch diff vs `main` is exactly the 5 expected files — no pbxproj, no 25-03 files.

No code-logic deviations (Rules 1-4): the plan was implemented as written.

## Known Stubs

None. No arm predicts `.niggleSeverity` by design (validation plumbing only, master flag OFF) — this is the intended "accumulate the actual substrate without a misleading prediction" posture, not a stub; Phase 27 will register the predicting arm.

## Commits

- `47fb9db` — feat(25-02): add .niggleSeverity outcome case + niggleSeverityActual column + switch-ripple sites
- `9474d64` — feat(25-02): date-contract-safe .niggleSeverity resolution + SorenessLog test schema

(both on branch `phase-25-02-niggle-severity-outcome`, on top of `main` @ `d88b404`)

## Self-Check: PASSED
- `WorkloadApp/Services/ShadowPredictor.swift` — `.niggleSeverity` case + nil guards: present in commit `47fb9db`.
- `WorkloadApp/Models/CyclePredictionLog.swift` — `niggleSeverityActual`: present (3 refs).
- `WorkloadApp/Services/ShadowAnalyticsService.swift` — `fetchMaxNiggleSeverityByDay` + target-day join: present (2 refs).
- `WorkloadAppTests/ShadowDataContractTests.swift` — `SorenessLog.self` schema + niggle tests: present.
- Commits `47fb9db` and `9474d64` exist on `phase-25-02-niggle-severity-outcome`.
- xcodebuild: 15/15 ShadowDataContractTests pass.
