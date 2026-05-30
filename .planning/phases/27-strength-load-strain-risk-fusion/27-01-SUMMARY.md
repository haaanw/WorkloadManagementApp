---
phase: 27-strength-load-strain-risk-fusion
plan: 01
subsystem: algorithm-substrate
tags: [strength-load, hard-sets, relative-intensity, strain-risk, shadow-gated]
requires: [25-soreness-tweak-self-log, 26-individualized-baselines]
provides: [StrengthLoadEngine]
affects: [27-02, 27-03]
tech-stack:
  added: []
  patterns: [pure-static-engine, dateless-by-injection, named-constants, redistribution-not-imputation]
key-files:
  created:
    - WorkloadApp/Services/StrengthLoadEngine.swift
    - WorkloadAppTests/StrengthLoadEngineTests.swift
    - .planning/phases/27-strength-load-strain-risk-fusion/artifacts/27-01-notes.md
  modified:
    - workload management/workload management.xcodeproj/project.pbxproj
decisions:
  - "D-27-02: StrengthLoadState @Model skipped — e1RM reference is a cheap pure rolling-best recompute; no persisted per-day state needed"
  - "App target uses explicit pbxproj membership (not synchronized group) — engine file registered with 4 entries"
metrics:
  duration: single-session
  completed: 2026-05-30
---

# Phase 27 Plan 01: StrengthLoadEngine Summary

Pure deterministic `StrengthLoadEngine` that turns logged sets into per-muscle HARD-SET
counts and relative-intensity buckets (via the existing `SetRecord.estimated1RM`, never raw
tonnage), with acute-vs-chronic per-muscle elevation and a same-region recurrence flag — the
strength-load substrate the Phase-27 Strain-Risk channel consumes, fully unit-tested with the
live recovery score provably byte-unchanged.

## What was built

- **`StrengthLoadEngine.swift`** — pure `struct`, static methods, Foundation-only, dates +
  `Calendar` injected (no `Date.now` / `Calendar.current`). Public API:
  - `estRIR(_:)` — logged `rir` wins, else `max(0, 10 − rpe)`, else nil.
  - `relativeIntensity(set:e1RMReference:)` — `weightKg / ref`, nil when no weight / ref ≤ 0.
  - `intensityBucket(_:)` — light <0.65 / moderate / heavy ≥0.80 / maximal ≥0.90.
  - `classify(set:e1RMReference:)` → `.warmup` / `.unscored` / `.easy` / `.hard(IntensityBucket?)`.
  - `e1RMReferences(sessions:)` — rolling best of the EXISTING `SetRecord.estimated1RM`
    per (muscleGroup, exerciseName); Epley NOT reimplemented.
  - `perMuscleStrengthLoad(...)` → `StrengthLoadResult` { perMuscle (hardSetCount,
    strengthLoad, unscoredCount, elevation), perRegion rollup via `MuscleGroup.region`,
    recurrenceFlags over the 7 `MuscleRegion` cases }.
  - `perMuscleElevation(acute:chronic:)` — FatigueIndex deadband+clamp ratio philosophy,
    increase-only, `chronic ≤ 0` guard. NOT ACWR.
  - `sameRegionRecurrence(...)` — intersection of soreness regions ∩ elevated regions.
- **`StrengthLoadEngineTests.swift`** — 23 tests, fixed UTC anchor 2026-03-15.

## Decisions made

- **D-27-02 — StrengthLoadState skipped.** The est-1RM reference is a pure rolling-best
  recompute over already-windowed history; no persisted per-day state / full-history scan
  needed, so no new SwiftData model, no Schema change, no sync surface introduced.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] App target is not a synchronized file group**
- **Found during:** Task 1 build (first run failed: "Cannot find 'StrengthLoadEngine' in scope").
- **Issue:** Only `WorkloadAppTests` / `ScreenshotTests` are `PBXFileSystemSynchronizedRootGroup`s; the WorkloadApp app target uses explicit file membership, so the new app-source file was not auto-compiled.
- **Fix:** Registered `StrengthLoadEngine.swift` in the app target with the standard 4 pbxproj entries (PBXBuildFile `EE2701020000000000000001`, PBXFileReference `EE2701010000000000000001`, Services group child, app `PBXSourcesBuildPhase`), mirroring `FatigueIndexEngine.swift`.
- **Files modified:** `workload management/workload management.xcodeproj/project.pbxproj`
- **Verified:** targeted test then passed 23/23.

## Verification

- `WorkloadAppTests/StrengthLoadEngineTests` → **TEST SUCCEEDED**, 23/23, 0 failures.
- FULL `WorkloadAppTests` suite → **TEST SUCCEEDED**, 0 compile errors, 0 failures.
- `BaselineTierFenceTests` → all 3 PASSED (live recovery baseline byte-unchanged).
- `SetRecord.estimated1RM` reused; no raw-tonnage sum; no live engine modified; no
  master/activation flag touched; no `.xcstrings` churn.

## Self-Check: PASSED
- FOUND: WorkloadApp/Services/StrengthLoadEngine.swift
- FOUND: WorkloadAppTests/StrengthLoadEngineTests.swift
- FOUND: .planning/phases/27-strength-load-strain-risk-fusion/artifacts/27-01-notes.md
- Commit hash recorded at commit time.
