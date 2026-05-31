---
phase: 28-readiness-fusion-explainable-decisions
plan: 05
subsystem: dashboard-prs-wiring
tags: [prs-v1, dashboard, autoregulation, readiness, strain-risk, flagged, dual-run]
requires: [28-01, 28-02, 28-03, 28-04]
provides:
  - PRSReadinessInputBuilder (pure, recomputes a real ReadinessInput)
  - DashboardViewModel.dualRunMessage (published, flag-gated)
  - DashboardViewModel.buildDualRunMessage() (synchronous, flag-gated)
  - PRSDualRunCard mounted under HeroReadinessCard (provisional)
affects:
  - WorkloadApp/Views/Dashboard/DashboardView.swift
tech-stack:
  added: []
  patterns: [pure-engine-recompute, flag-gated-build, synchronous-testable-flag-method]
key-files:
  created:
    - WorkloadApp/Services/PRSReadinessInputBuilder.swift
    - WorkloadAppTests/DashboardViewModelDualRunTests.swift
  modified:
    - WorkloadApp/ViewModels/DashboardViewModel.swift
    - WorkloadApp/Views/Dashboard/DashboardView.swift
    - workload management/workload management.xcodeproj/project.pbxproj
decisions:
  - "No live readiness/strain source existed to reuse — RECOMPUTED with the same engines over real history (the only non-fabricating option)."
  - "Flag-gated build factored into a SYNCHRONOUS buildDualRunMessage() so it is testable under the sync-scoped PRSActivation.withEnabled override."
  - "Cold-start personal z -> nil (excluded + renormalized by the fusion engine, never imputed); builder returns nil when the real FatigueResult is absent (no fabrication)."
metrics:
  duration_min: 16
  completed: 2026-05-31
  tasks: 3
  files: 5
  tests_full_suite: "481 passed, 0 failed"
---

# Phase 28 Plan 05: Flagged Dual-Run Card → Live Dashboard Wiring Summary

Wired the FLAGGED PRS-v1 dual-run "method updated" card into the live Dashboard with the master flag (`PRSActivation.isEnabled`) defaulting OFF: a new pure `PRSReadinessInputBuilder` recomputes a real `AutoregulationEngine.ReadinessInput` from the athlete's real history, `DashboardViewModel` builds the `DualRunMessage` inside a single `if PRSActivation.isEnabled` guard, and `DashboardView` mounts `PRSDualRunCard` below the hero readiness card — flag-off renders `EmptyView`, leaving the Dashboard byte-identical.

## What was built

### Task 1 — `PRSReadinessInputBuilder` (pure)
`enum PRSReadinessInputBuilder.build(...)` — Foundation-only, deterministic, `asOf`+`calendar`-injected. Recomputes a real `ReadinessInput`:
- **Readiness side:** folds `BaselineEngine.step` over the athlete's real `recentSnapshots` HRV/RHR/sleep series (ascending, gap-`compactMap`ped), then `BaselineEngine.score`s today's real raw value → real personal z per signal; real `BaselineEngine.confidence` from the HRV state; `ReadinessFusionEngine.compute(...)` → real readiness (0-100) + `ReadinessZone`.
- **Strain side:** real `StrengthLoadEngine.perMuscleStrengthLoad` + `LoadDistributionEngine.distribution` over real sessions, fused with the real `FatigueResult` via `StrainRiskEngine.fuse(...)` → real `StrainRiskZone`.
- **ACWR demotion (GA-4):** `acwrZone` → a short context LABEL only (e.g. `.optimal` → "Load Steady"); never a decision input.
- Returns `nil` (no fabrication) when the real `FatigueResult` is absent (cold-start suppressed it).

### Task 2 — `DashboardViewModel`
- Published `var dualRunMessage: PRSDualRunSurface.DualRunMessage?` (nil default).
- Hoisted the real `FatigueResult` into `fatigueResultForReadiness` (cold-start leaves it nil).
- Factored the flag-gated build into a SYNCHRONOUS `buildDualRunMessage(allSessions:fatigueResult:daysSinceRest:)`, called at the end of `load()`. The entire readiness/strain recompute + `PRSDualRunSurface.dualRunMessage(legacy:updated:)` assignment sit inside `if PRSActivation.isEnabled` — flag-off does literally nothing new.

### Task 3 — View mount + tests
- `DashboardView`: `PRSDualRunCard(message: viewModel.dualRunMessage)` mounted directly below `HeroReadinessCard` inside the existing `VStack(spacing: 0)`, with a PROVISIONAL/human-review comment. Flag-off → `EmptyView` → layout byte-identical.
- New `DashboardViewModelDualRunTests`: flag-off `load()` → `dualRunMessage` nil; flag-on `buildDualRunMessage()` under `withEnabled(true)` → non-nil with `previousHeadline == recommendation.headline` and non-empty `updatedHeadline`; flag-on with no `FatigueResult` → stays nil (no fabrication). Added to the synchronized `WorkloadAppTests` group automatically; `PRSReadinessInputBuilder.swift` added explicitly to the `WorkloadApp` PBXGroup + Sources phase.

## Central gray-area decision (no fabrication)

`ReadinessFusionEngine.compute` / `StrainRiskEngine.fuse` are called in unit tests ONLY — there is NO live production readiness/strain computation to "reuse". `BaselineState` (@Model) is in the schema but never written in production, so persisted personal z-scores do not exist at runtime. The only non-fabricating option was to **RECOMPUTE** with the same engines over the athlete's real history. Cold-start (`count < 2` / buffer below `madMinValid`) yields a `nil` z, which the fusion engine EXCLUDES and renormalizes over the present signals (never mean-imputed). When the real strain channel is unavailable (no real `FatigueResult`), the builder returns `nil` and the VM leaves `dualRunMessage` nil rather than synthesizing inputs.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Unique pbxproj GUIDs for the new source file**
- **Found during:** Task 3 build.
- **Issue:** The initially-chosen GUID prefix `EE2805` collided with `PRSDualRunCard.swift` (already using `EE2805…`), so the build resolved the new file to `Views/Dashboard/` and failed (`Build input file cannot be found`).
- **Fix:** Re-issued the file reference / build file with the unused `EE2806` prefix.
- **Files modified:** `workload management/workload management.xcodeproj/project.pbxproj`
- **Commit:** 560a194

**2. [Rule 1 - Bug] Flag-on tests declared `async` to avoid a Swift-Concurrency deinit crash**
- **Found during:** Task 3 test run.
- **Issue:** The two synchronous `@MainActor` flag-on tests crashed (SIGABRT, malloc double-free in `DashboardViewModel.__deallocating_deinit` via `swift::TaskLocal` cleanup) when the bare `@MainActor @Observable` VM deinitialized inside a synchronous `@MainActor` test (the known XCTest-host deinit interaction).
- **Fix:** Declared both flag-on tests `async`, giving the VM an enclosing concurrency context for clean teardown. The flag-gated build itself stays SYNCHRONOUS — `withEnabled` is sync and wraps the sync `buildDualRunMessage(...)` with no `await` straddling the override scope (the plan-check must-fix contract is preserved).
- **Files modified:** `WorkloadAppTests/DashboardViewModelDualRunTests.swift`
- **Commit:** 560a194

## Invariants verified

- Flag-off byte-identical: `test_flagOff_dualRunMessage_nilAfterLoad` green; AutoregulationFlagFenceTests / DualRunFlagFenceTests / BaselineTierFenceTests green AND unmodified (`git diff --stat` clean).
- No fabrication: builder traces every field to a real engine output; returns nil rather than synthesize.
- No new sync: no `@Model`, no `Codable`, no `SyncService.swift` touched.
- DESIGN: card already 0pt/hairline/General Sans/no-accent; mount adds no corner radius/shadow.
- Copy: no user-facing "injury prediction"; "Tuwa" only.
- Defaults: `PRSActivation` + `PRSMasterActivation` remain FALSE.
- Full `WorkloadAppTests`: 481 passed, 0 failed.

## Provisional / follow-up

- The card PLACEMENT (directly below the hero) is PROVISIONAL — flagged for human visual review (checkpoint:human-verify in the plan). It is NOT final; the human may relocate it (e.g. below the metrics strip / training-load section).

## Self-Check: PASSED
- `WorkloadApp/Services/PRSReadinessInputBuilder.swift` — FOUND
- `WorkloadAppTests/DashboardViewModelDualRunTests.swift` — FOUND
- Commit `560a194` — FOUND
- Full suite 481 passed / 0 failed; build SUCCEEDED on iPhone 17 Pro Max sim.
