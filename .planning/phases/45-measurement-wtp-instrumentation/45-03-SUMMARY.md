---
phase: 45-measurement-wtp-instrumentation
plan: 03
subsystem: measurement
tags: [green-light, metrics, profile, analytics, design-system, localization, honest-nil-states]

requires:
  - phase: 45-measurement-wtp-instrumentation
    provides: GreenLightEngine + VerdictEventRepository.fetchAll (45-01); live logging (45-02)
provides:
  - VerdictMeasurementView (quiet METRIC-02 readout — green-light / activation / Day-7-30 retention)
  - Quiet Profile NavigationLink (Validation section) into the readout
affects: [45-04]

tech-stack:
  added: []
  patterns:
    - "Read the clock ONCE at the view boundary; pass asOf/calendar into the pure engine"
    - "Honest nil-states (still-learning / too-early / lapsed) — never fabricated 0% / 100%"
    - "Quiet flat-row analytics surface (no hero number, no accent, no chart)"
    - "View→engine contract pinned by a test without rendering SwiftUI"

key-files:
  created:
    - WorkloadApp/Views/Profile/VerdictMeasurementView.swift
    - WorkloadAppTests/GreenLightSurfaceTests.swift
  modified:
    - WorkloadApp/Views/Profile/ProfileView.swift
    - WorkloadApp/Resources/Localizable.xcstrings
    - "workload management/workload management.xcodeproj/project.pbxproj"

key-decisions:
  - "greenLightRate / activationRate nil → 'still learning' placeholder (text3), never 0%"
  - "Retention: true→retained, false→lapsed (text2), nil→too early (text3)"
  - "Surface placed as a quiet 'Validation' section between Data Sync and Account — not promoted"

patterns-established:
  - "Boundary-only .now/.current with a date-injected pure engine behind it"
  - "Honest no-signal-yet analytics rows"

requirements-completed: [METRIC-02]

duration: 20min
completed: 2026-06-14
---

# Phase 45 Plan 03: Green-Light Surface Summary

**A quiet internal `VerdictMeasurementView` that runs `GreenLightEngine` over the athlete's logged `VerdictEvent`s and shows the green-light rate alongside activation and Day-7 / Day-30 retention — reachable from a low-key Profile 'Validation' row, honest about no-signal-yet states, never a hero affordance.**

## Performance

- **Duration:** ~20 min
- **Tasks:** 2
- **Files created:** 2 (1 view, 1 test)
- **Files modified:** 3 (ProfileView, xcstrings, pbxproj)

## Accomplishments
- `VerdictMeasurementView` fetches the current athlete's events via `VerdictEventRepository.fetchAll` and computes `GreenLightEngine.compute(events:asOf:calendar:)` ONCE at the boundary (the only place `.now` / `.current` appear) — the engine stays date-injected.
- Renders quiet composite rows: green-light rate (+ "on N differing-verdict days"), activation (+ "across N logged verdicts"), Day-7 / Day-30 retention — DESIGN-compliant (Rectangle, no shadow, Font.Tokens.*, 8pt grid, no accent).
- Honest nil-states: `greenLightRate`/`activationRate == nil` → "Still learning"; retention nil → "Too early", false → "Lapsed", true → "Retained". No fabricated 0% / 100%.
- Quiet Profile NavigationLink under a new low-key "Validation" section (between Data Sync and Account), mirroring the Sync row treatment.
- `GreenLightSurfaceTests` pins the view→engine contract: a seeded differing/acted/right fixture yields greenLightRate 0.5 over 2 differing days; an empty store yields nil (no SwiftUI rendered).

## Green-light surface binding (as implemented)
```
let repository = VerdictEventRepository(modelContext: modelContext)
let events = repository.fetchAll(athlete: athletes.first)
let metrics = GreenLightEngine.compute(events: events, asOf: .now, calendar: .current)  // boundary
```
Row formatters: `percentText(rate)` → `nil` ⇒ "Still learning" (no 0%); `retentionText(bool?)` → retained / lapsed / too early.

## Task Commits

1. **Task 1: VerdictMeasurementView + contract test + strings + pbxproj** — `0bf2530` (feat)
2. **Task 2: Quiet Profile entry point** — `3d1f84a` (feat)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] XCTAssertEqual accuracy on Optional<Double>**
- **Found during:** Task 1 (GreenLightSurfaceTests)
- **Issue:** `XCTAssertEqual(metrics.greenLightRate, 0.5, accuracy:)` failed to compile — `greenLightRate` / `activationRate` are `Double?`, and the `accuracy:` overload requires a non-optional `Double`.
- **Fix:** Unwrapped via `try XCTUnwrap(...)` before the accuracy comparison.
- **Files modified:** WorkloadAppTests/GreenLightSurfaceTests.swift
- **Verification:** Both contract tests green after the change.
- **Committed in:** `0bf2530`

---

**Total deviations:** 1 auto-fixed (1 bug, test-only).
**Impact on plan:** Test-harness fix only; no production change. No scope creep.

## Issues Encountered
None beyond the above.

## User Setup Required
None.

## Next Phase Readiness
- 45-04 can read `fetchAll(athlete:).count` to gate the Sean-Ellis trigger and reuse `UpgradeSheet`.

## Self-Check: PASSED
- WorkloadApp/Views/Profile/VerdictMeasurementView.swift — FOUND
- WorkloadAppTests/GreenLightSurfaceTests.swift — FOUND
- Commit 0bf2530 — FOUND
- Commit 3d1f84a — FOUND

---
*Phase: 45-measurement-wtp-instrumentation*
*Completed: 2026-06-14*
