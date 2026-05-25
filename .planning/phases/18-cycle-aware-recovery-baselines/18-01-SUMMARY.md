---
phase: 18-cycle-aware-recovery-baselines
plan: 01
subsystem: recovery-scoring
tags: [recovery, cycle, baselines, pure-engine, tdd]
requires:
  - CyclePhase enum (Phase 17)
  - RecoveryScoreEngine 7-day baseline path
provides:
  - RecoveryScoreEngine.PhaseBucket (2-bucket cycle grouping)
  - RecoveryScoreEngine.bucket(for:) phase->bucket mapping
  - RecoveryScoreEngine.samePhaseBaseline(readings:) confidence-gated mean
  - RecoveryInput.samePhaseHRVBaseline / samePhaseRestingHRBaseline fields
  - compute() per-component baseline source selection (?? hard switch)
affects:
  - Plan 18-02 (CycleContext orchestration / data joins feeding these contracts)
tech-stack:
  added: []
  patterns:
    - Pure-struct static helpers extended without state
    - Additive optional fields preserve identical-behavior contract
    - Per-component baseline selection via Optional `??` (D-06/D-07)
key-files:
  created: []
  modified:
    - WorkloadApp/Services/RecoveryScoreEngine.swift
    - WorkloadAppTests/RecoveryScoreEngineTests.swift
    - WorkloadApp/Services/SubscriptionService.swift (Rule 3 build-unblock)
    - WorkloadApp/Views/Profile/ProfileView.swift (Rule 3 build-unblock)
    - WorkloadApp/Views/Profile/TrainingProfileSheet.swift (Rule 3 build-unblock)
    - "workload management/workload management.xcodeproj/project.pbxproj" (Rule 3 build-unblock)
decisions:
  - D-01 implemented as nested enum PhaseBucket + bucket(for:)
  - D-02/D-03 implemented as samePhaseBaseline equal-weight mean with 4-reading minimum
  - D-06/D-07 implemented as `samePhase ?? sevenDay` per HRV and RHR independently
metrics:
  duration: ~33 min
  completed: 2026-05-25
  tasks: 2
  files_changed: 6
requirements: [CYCLE-04]
---

# Phase 18 Plan 01: Same-Phase Recovery Baselines (Engine) Summary

Extended the pure `RecoveryScoreEngine` so HRV and RHR recovery components can score against a confidence-gated **same-phase** baseline (the athlete's own same-bucket cycle history) instead of the male-normative 7-day rolling baseline — while producing byte-identical output when no same-phase data is supplied.

## What Was Built

**Task 1 — Bucket mapping + same-phase baseline math (pure helpers):**
- `enum PhaseBucket { follicular, luteal }` nested in `RecoveryScoreEngine` (D-01).
- `static func bucket(for: CyclePhase) -> PhaseBucket?` — maps `earlyFollicular`/`lateFollicular`/`ovulatory` → `.follicular`, `earlyLuteal`/`lateLuteal` → `.luteal`, `unknown` → `nil`.
- `static func samePhaseBaseline(readings: [Double]) -> Double?` — equal-weight mean (D-02, no recency decay), returns `nil` when `readings.count < 4` (D-03 minimum). Documented contract: caller supplies already-filtered same-bucket readings from the most recent 3 cycles.
- `computeBaseline(values:)` (7-day rolling) left untouched.

**Task 2 — RecoveryInput same-phase fields + compute() selection (additive, non-breaking):**
- `RecoveryInput` gains optional `samePhaseHRVBaseline` and `samePhaseRestingHRBaseline`, both defaulting to `nil` in the memberwise init (existing call sites compile unchanged).
- `compute()` HRV denominator = `input.samePhaseHRVBaseline ?? input.hrvBaseline`; RHR denominator = `input.samePhaseRestingHRBaseline ?? input.restingHRBaseline`. This delivers D-06 per-bucket fallback (each component picks its own source) and D-07 hard switch (`??` selects exactly one source, no blending).
- `ratioToScore`, the `baseline > 0` guards, weights, trend math, sleep, wellness, and the no-data neutral-50 path are all unchanged — only the denominator value feeding the existing math changes.

## Verification

- `xcodebuild test -only-testing:WorkloadAppTests/RecoveryScoreEngineTests` → **TEST SUCCEEDED** on iPhone 17 Pro Max simulator. All new tests plus all pre-existing engine tests pass.
- New tests cover: full bucket mapping incl. `unknown→nil`; 4-vs-3 reading boundary; equal-weight (no recency decay); empty/nil; identical-behavior regression (nil same-phase vs original initializer across 4 representative inputs); worked example 5 (35ms vs same-phase 35 scores normal ~68, higher than 35 vs 42); worked example 6 (28ms vs same-phase 36 still depresses HRV / detects fatigue); D-06 per-bucket fallback (HRV same-phase + RHR 7-day simultaneously); RHR same-phase denominator selection.
- Engine purity confirmed: `RecoveryScoreEngine.swift` imports only `Foundation` (no HealthKit, no SwiftData).

## Deviations from Plan

### Auto-fixed Issues (Rule 3 — blocking build issues)

The committed base (33ff301) did **not compile** — the WorkloadApp test target could not build, which blocked running `RecoveryScoreEngineTests` entirely. Root cause: the developer's main checkout has uncommitted local edits to several files; those edits were never committed, so the worktree (which reflects committed state) was missing them. Three independent compile blockers were fixed under Rule 3 so the engine tests could execute. None relate to the same-phase baseline algorithm.

**1. [Rule 3 - Blocking] MenstrualCycleSnapshot.swift missing from Xcode compile sources**
- **Found during:** Task 1 RED build.
- **Issue:** Phase 17 committed `WorkloadApp/Models/MenstrualCycleSnapshot.swift` to git but never added it to the `.pbxproj` compile sources. Result: `cannot find type 'MenstrualCycleSnapshot'` / `cannot find type 'CycleContext'` across CycleTrackingService, DashboardView, ProfileView, Athlete. (Confirmed the main repo's committed `.pbxproj` also lacks the reference.)
- **Fix:** Added `PBXBuildFile`, `PBXFileReference`, group child, and Sources-phase entries for `MenstrualCycleSnapshot.swift` (mirrored `Athlete.swift`), using fresh non-colliding IDs.
- **Files modified:** `workload management/workload management.xcodeproj/project.pbxproj`
- **Commit:** 8ea80a9

**2. [Rule 3 - Blocking] SubscriptionService.logIn(userId:) missing**
- **Found during:** Task 1 RED build.
- **Issue:** `AppRouter` calls `container.subscriptionService.logIn(userId:)` (lines 73, 149) but the committed `SubscriptionService` had no such method (`value of type 'SubscriptionService' has no member 'logIn'`). The method exists only in the main repo's uncommitted working tree.
- **Fix:** Added `func logIn(userId: UUID) async` wrapping `Purchases.shared.logIn(...)` and applying the returned `CustomerInfo`, matching the main repo's uncommitted implementation. (Did NOT pull in the unrelated `lockedWeeks` heuristic change also present in main's uncommitted diff — out of scope.)
- **Files modified:** `WorkloadApp/Services/SubscriptionService.swift`
- **Commit:** 8ea80a9

**3. [Rule 3 - Blocking] Redundant `if let athlete` on non-optional**
- **Found during:** Task 1 RED build.
- **Issue:** `ProfileView.swift:93` and `TrainingProfileSheet.swift:452` bind `if let athlete` where `athlete` is already non-optional (unwrapped by an enclosing `guard let`/`if let`), producing `initializer for conditional binding must have Optional type, not 'Athlete'`.
- **Fix:** Removed the redundant inner bindings, using the already-unwrapped non-optional `athlete`.
- **Files modified:** `WorkloadApp/Views/Profile/ProfileView.swift`, `WorkloadApp/Views/Profile/TrainingProfileSheet.swift`
- **Commit:** 8ea80a9

### Test-expectation correction (during GREEN, not a deviation)

Two worked-example tests initially asserted an HRV/RHR contribution of `70` for ratio 1.0. The engine's existing `ratioToScore(1.0, ...)` formula (`20 + (1.0 - 0.7) * 160`) yields `68`, not `70` (the plan's "ratio 1.0 = 70" was an approximate doc note). The relational assertions (same-phase scores higher than 7-day; fatigue still depresses) were always correct; only the exact expected value was tightened to `68`. No engine behavior changed.

## Environment Notes (worktree)

- The worktree did not contain the gitignored `SupabaseConfig.swift` / `RevenueCatConfig.swift` (required as build inputs). They were copied into the worktree filesystem from the main checkout purely to allow `xcodebuild` to run; both remain gitignored (`.gitignore` lines 2-3) and were verified absent from `git status` — they were **not** committed.
- The plan's verify command hardcodes `/Users/hanwen/Desktop/Tonus/workload management` (main repo). Tests were instead run against the worktree's own `workload management/workload management.xcodeproj`, whose `WorkloadApp` group resolves via `path = ../WorkloadApp` to the worktree-root source — i.e. the edited files.

## Threat Surface

No new security surface. Per the plan's threat model: the engine accepts only aggregate `Double` baseline values (means), never raw menstrual records, cycle dates, or `MenstrualCycleSnapshot` rows. New `RecoveryInput` fields are transient in-memory doubles on a value type, never persisted or encoded. No sync/repository/model files touched by the engine work. No HealthKit/SwiftData imports added.

## Known Stubs

None. This plan defines algorithm contracts consumed by Plan 18-02 (which performs the same-bucket / most-recent-3-cycle data join and gating). The `nil` same-phase path is the intended default until Plan 02 wires real cycle history — this is documented in the plan, not a stub.

## Self-Check: PASSED

- Files: RecoveryScoreEngine.swift, RecoveryScoreEngineTests.swift, 18-01-SUMMARY.md all present.
- Commits 8ea80a9, 18f15f0, 995c0d8, c838286 all present in branch history.
- Symbols verified in source: `enum PhaseBucket`, `static func bucket(for`, `static func samePhaseBaseline(`, `samePhaseHRVBaseline ?? input.hrvBaseline`.
- `xcodebuild test` for RecoveryScoreEngineTests: TEST SUCCEEDED.
