---
phase: 25-soreness-tweak-self-log
plan: 03
subsystem: fatigue-derivation
tags: [fatigue, niggle, doms-exclusion, wellness, pure-engine, dashboard]
requires:
  - SorenessLog @Model (Plan 01)
  - NiggleType enum (Plan 01)
  - SorenessLogRepository.fetchRecent (Plan 01)
provides:
  - NiggleInjuryDeriver (pure static helper)
  - DashboardViewModel real 14d wellness + deriver-backed injury inputs
affects:
  - FatigueIndexEngine soft-tissue + wellness-trend components (now fed real data)
  - Phase 27 (localized Strain-Risk channel — shares the niggle qualification semantics)
tech-stack:
  added: []
  patterns:
    - "Pure static struct over [SorenessLog] (Foundation-only) — mirrors FatigueIndexEngine.baselineSessionsPer14Days"
    - "Cold-start guard: all new fetches/derivations gated inside the non-cold-start else branch"
    - "Inline date-windowed FetchDescriptor + Swift-side athlete filter (avoids iOS 26.1 optional-relationship #Predicate trap)"
    - "Pure-helper tests build plain [SorenessLog] arrays (no ModelContainer) — sidesteps the SwiftData predicate trap entirely"
key-files:
  created:
    - WorkloadApp/Services/NiggleInjuryDeriver.swift
    - WorkloadAppTests/NiggleInjuryDeriverTests.swift
  modified:
    - WorkloadApp/ViewModels/DashboardViewModel.swift
    - workload management/workload management.xcodeproj/project.pbxproj
decisions:
  - "28d window boundary is INCLUSIVE of day -28 (a log exactly 28 days ago counts); day -29 excluded"
  - "Wellness fetch is an INLINE FetchDescriptor<WellnessCheckIn> in the VM (PersonalRecord precedent), not a new repo — minimal surface, no new file"
  - "recentWellnessScores passes all 14 points per D-12 (NOT .suffix(7)); engine slope is count>=3-gated so 14 is valid"
  - "Severity threshold is INCLUSIVE at the cut (severity == 7 qualifies)"
  - "softTissueInjuryCount counts qualifying logs in window with NO region-dedup (v1, RESEARCH §4 A3)"
metrics:
  duration: "~17 min"
  completed: 2026-05-30
---

# Phase 25 Plan 03: Niggle-Derived Fatigue Inputs Summary

A pure static `NiggleInjuryDeriver` encodes the functional, DOMS-excluded injury-qualification rule (D-10/D-11) over `[SorenessLog]` arrays, and `DashboardViewModel.load()` now feeds the fatigue engine real 14-day wellness history (D-12) plus deriver-backed injury count / days-since — replacing the three hardcoded `[]` / `0` / `nil` inputs. All three new fetches/derivations are gated inside the non-cold-start branch so cold-start does no extra work. Built + tested green via real xcodebuild (22/22 tests pass, including the load-bearing DOMS-exclusion).

## What Was Built

**Task 1 — NiggleInjuryDeriver pure helper + tests** (commit `b7a54ee`)
- `WorkloadApp/Services/NiggleInjuryDeriver.swift` — a pure `struct` with static methods, **Foundation-only** (no `import SwiftData`/`HealthKit`), mirroring `FatigueIndexEngine.baselineSessionsPer14Days` (takes a model array, returns primitives).
  - Named tunable constants (D-13): `static let qualifyingSeverityCut: Int = 7`, `static let injuryWindowDays: Int = 28`.
  - `softTissueInjuryCount(logs:asOf:) -> Int` = count of qualifying logs in window (no region-dedup, v1).
  - `daysSinceLastInjury(logs:asOf:) -> Int?` = start-of-day day-diff to the most-recent qualifying log, `nil` if none.
  - Private `isQualifying(_:asOf:)` encodes D-10: `NiggleType(rawValue:) ∈ {.pain, .tweak}` **AND** (`limitedTraining` OR `severity >= qualifyingSeverityCut`) **AND** within `injuryWindowDays` (start-of-day comparison; day -28 boundary inclusive, future-dated logs excluded). `soreness` (DOMS) and any unknown rawValue are excluded by the type gate.
  - Honest framing in the doc-comment: "load-tolerance context, never an injury *prediction*."
- `WorkloadAppTests/NiggleInjuryDeriverTests.swift` — 14 tests building plain `[SorenessLog]` arrays via the model init (no `ModelContainer` — the helper is pure, so the SwiftData predicate trap never applies). A fixed `asOf` makes day-diff math deterministic. Coverage:
  - **DOMS-exclusion (highest-value):** `soreness` severity-10 limitedTraining-true today → count 0, daysSince nil.
  - impact-only (`pain` sev 3 limited) → counts; severity-only (`tweak` sev 8 not-limited) → counts; neither (`pain` sev 3 not-limited) → not counted.
  - severity threshold inclusive at the cut (7 qualifies, 6 does not).
  - window edge: day -28 counted, day -29 excluded.
  - count: two qualifying same-region → 2; mixed qualifying + non-qualifying → only qualifying count.
  - days-since: most-recent qualifying; ignores more-recent non-qualifying; today → 0.
  - empty / only-non-qualifying → count 0, daysSince nil.
- `project.pbxproj` — `NiggleInjuryDeriver.swift` added to the **app target** (4 entries: PBXBuildFile, PBXFileReference, group child, Sources phase), mirroring `FatigueIndexEngine.swift`. The test file `NiggleInjuryDeriverTests.swift` needs **no** pbxproj edit — the `WorkloadAppTests` target is a `PBXFileSystemSynchronizedRootGroup`, so new test files auto-include (which is why sibling `SorenessLogModelTests` has zero pbxproj references).

**Task 2 — Wire real inputs into DashboardViewModel.load()** (commit `b59d494`)
- Removed the hoisted `let recentWellnessScores: [Double] = []  // TODO` that sat above the if/else.
- Inside the **non-cold-start `else` branch** only:
  - **14d wellness fetch (D-12):** inline `FetchDescriptor<WellnessCheckIn>` windowed to the last 14 days (`date >= now-14d`), sorted oldest-first, athlete filtered in Swift (`$0.athlete?.id == athleteId`), mapped to `\.wellnessScore` — all 14 points passed (no `.suffix(7)`).
  - **28d niggle fetch + derivations (D-10/D-11):** `SorenessLogRepository(...).fetchRecent(days: NiggleInjuryDeriver.injuryWindowDays, athlete:)`, then `softTissueInjuryCount:` and `daysSinceLastInjury:` come from `NiggleInjuryDeriver` over those logs — replacing the hardcoded `0` / `nil`.
- **Cold-start (`if isColdStartActive`) is unchanged** — it still only sets `fatigueIndex = nil; fatigueZone = nil` and performs none of the new fetches. A comment documents that all three new operations are gated in the else branch.

## Decisions Made

- **Wellness-fetch shape: inline FetchDescriptor in the VM** (not a new `WellnessRepository`). The plan permitted either; the `PersonalRecord` inline-FetchDescriptor precedent already exists in this same file, so inline keeps the surface minimal and adds no new file.
- **Window boundary inclusive at day -28** — documented in code and asserted by `test_windowEdge_day28Inclusive_day29Excluded`. Matches `SorenessLogRepository.fetchRecent`'s own inclusive start-of-day boundary, so the deriver and the repo agree on what "in window" means.
- **Severity threshold inclusive at the cut** (severity == 7 qualifies) — asserted by `test_severityThreshold_inclusiveAtCut`.
- **14 wellness points, not 7 (D-12)** — `FatigueIndexEngine.computeWellnessTrendFatigue` only uses the series for an OLS slope gated on `count >= 3`, so 14 elements are valid; no FatigueIndexEngine change was needed and its existing tests still pass.
- **No FatigueIndexEngine.FatigueInput changes** — the existing `recentWellnessScores: [Double]` / `softTissueInjuryCount: Int` / `daysSinceLastInjury: Int?` fields already accept the new data; the engine's `computeSoftTissueRisk` math is window-agnostic, so narrowing to 28d needed no engine edit.

## Deviations from Plan

### Out-of-scope concurrency collision (no code deviation)
- **Found during:** Task 1 first build.
- **Issue:** The parallel Plan 25-02 executor was committing onto the **same shared git checkout** concurrently (no separate worktree). The working tree transiently contained 25-02's incomplete WIP — `ShadowAnalyticsService.swift:158` called `fetchMaxNiggleSeverityByDay`, which 25-02 had not yet declared — breaking the build. A `git add`/`commit` of mine was also swept into a 25-02 commit, and HEAD/branch were switched underneath me by the concurrent process.
- **Resolution (non-destructive, per the git-prohibition rules):** No force-rewind, no `git stash`, no `git clean`. I waited for 25-02 to stabilize (it finished and left the checkout on its own branch with the helper now declared), then re-pointed my `phase-25-03-niggle-injury-deriver` branch at `main` (`git branch -f` + checkout, preserving my untracked files and pbxproj edit) and re-committed my work cleanly in isolation. Final per-task commits (`b7a54ee`, `b59d494`) contain ONLY my four files; no 25-02 content is attributed to this plan.
- **Files modified:** None beyond the plan's four (the 25-02 files were never committed by me on my branch).
- This was an environment/orchestration issue (shared checkout for "parallel" plans), not a plan-content deviation — the plan executed exactly as written once isolated.

### pbxproj serialization (as instructed)
- Re-read `project.pbxproj` immediately before the membership add and confirmed it had no `NiggleInjuryDeriver` entries and that 25-04 had not yet touched it. The membership edit is minimal (4 lines, mirroring `FatigueIndexEngine`) and `plutil -lint`-valid. 25-04 ran after this plan.

## Threat Model Adherence

- **T-25-08 (Tampering — DOMS inflation, `mitigate`):** Satisfied. The qualification predicate excludes `soreness`-type logs, and `test_domsExclusion_sorenessNeverCounts_evenAtMaxSeverityAndLimited` (plus `test_count_mixedQualifyingAndNot_onlyQualifyingCount`, `test_daysSince_ignoresMoreRecentNonQualifying`) prove a routine soreness log never inflates the fatigue injury inputs.
- **T-25-07 (Information Disclosure, `accept`):** No new persistence or sync; the deriver is a pure read over local `SorenessLog`/`WellnessCheckIn` producing only an `Int` + `Int?` consumed locally by `FatigueIndexEngine`.
- **T-25-SC (`accept`):** No package installs — Apple frameworks only.

## Verification

- `xcodebuild build` (iPhone 17 Pro Max sim `8E872500-703D-4292-9758-38ADFCCFB126`, scheme `workload management`): **BUILD SUCCEEDED**.
- `xcodebuild test` (`NiggleInjuryDeriverTests` + `FatigueIndexEngineCycleTests` + `SorenessLogModelTests`): **22 passed, 0 failed, exit 0, TEST SUCCEEDED.**
  - 14 `NiggleInjuryDeriverTests` (incl. DOMS-exclusion, threshold/window edges, empty-data).
  - 4 `FatigueIndexEngineCycleTests` — **existing tests still pass (no regression).**
  - 4 `SorenessLogModelTests` (Plan 01) — still green.
- Purity: `grep -n "import SwiftData\|import HealthKit" NiggleInjuryDeriver.swift` → nothing.
- Cold-start guard: diff review confirms all three new fetches/derivations sit inside the non-cold-start `else`; nothing hoisted above the if/else; cold-start branch unchanged.
- D-12: `recentWellnessScores` is no longer `[]`; passes 14 points (no `.suffix(7)` on the wellness series — the `.suffix(7)` at line 234 is the pre-existing **recovery** series, untouched).

## Known Stubs

None. The three previously-hardcoded fatigue inputs are now wired to real data; the niggle/wellness sources are the Plan 01 model + the existing `WellnessCheckIn`.

## Self-Check: PASSED

- FOUND: `WorkloadApp/Services/NiggleInjuryDeriver.swift`
- FOUND: `WorkloadAppTests/NiggleInjuryDeriverTests.swift`
- FOUND: `.planning/phases/25-soreness-tweak-self-log/25-03-SUMMARY.md`
- FOUND: commit `b7a54ee` (Task 1), `b59d494` (Task 2)
- `DashboardViewModel.swift` modified in `b59d494`.
