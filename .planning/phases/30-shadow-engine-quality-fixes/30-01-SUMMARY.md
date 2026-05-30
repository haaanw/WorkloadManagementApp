---
phase: 30-shadow-engine-quality-fixes
plan: 01
subsystem: strength-load-engine
tags: [shadow, strength-load, fractional-rpe, chronic-window, coverage-data]
requires: []
provides: [MuscleStrengthLoad.easyCount, MuscleStrengthLoad.hasChronicBaseline, estRIRPrecise, chronic-excludes-acute]
affects: [StrainRiskEngine (Wave 3), LoadDistributionEngine (Wave 2 — reuses corrected classify)]
key-files:
  modified:
    - WorkloadApp/Services/StrengthLoadEngine.swift
    - WorkloadAppTests/StrengthLoadEngineTests.swift
    - WorkloadAppTests/StrainRiskEngineTests.swift
decisions: [GA-30-C, GA-30-D, GA-30-E]
metrics:
  completed: 2026-05-31
commit: 1e5314a
---

# Phase 30 Plan 01: StrengthLoadEngine Findings 3+4 + Finding-5 data capture Summary

Corrected RPE→RIR truncation (Finding 4) and the chronic⊇acute double-count (Finding 3) in the pure shadow `StrengthLoadEngine`, and captured `easyCount` + `hasChronicBaseline` on `MuscleStrengthLoad` for Wave-3 coverage confidence (Finding 5 data).

## What changed

### Finding 4 (GA-30-D) — Double-precision RIR classification
- Added `static func estRIRPrecise(_:) -> Double?` returning the un-truncated bridge (`max(0, 10 − rpe)`, or `Double(rir)`).
- `classify` now computes `hardByRIR` from the precise Double vs `Double(hardSetRIRThreshold)` (2.0). RPE 7.5 → 2.5 RIR → not hard; RPE 8.0 → 2.0 → hard; RPE 7.6 → 2.4 → not hard.
- `estRIR` (Int, truncating) is UNCHANGED — kept for display/back-compat callers and the existing Int oracle tests (RPE 8→2, 10→0, 6→4 still green).

### Finding 3 (GA-30-C) — chronic excludes acute + zero-chronic flag + windowed off-by-one
- Replaced inclusive `windowed(diff >= 0 && diff <= days)` with half-open `windowedRange(lowerDayInclusive:upperDayExclusive:)` (`diff >= lower && diff < upper`).
- Acute = `[0, acuteWindowDays)`, chronic-exclusive = `[acuteWindowDays, chronicWindowDays)` — exact partition, no shared boundary day. A session at `diff == 7` lands in chronic, not acute.
- chronicPerDay normaliser = `chronicWindowDays − acuteWindowDays` (21d for 7/28), acutePerDay = `acuteWindowDays` (7d).
- Steady-state athlete → ratio ≈ 1 → elevation 0 (was the ~4× superset artefact).
- Zero chronic-exclusive load → `hasChronicBaseline = false` and `elevation = 0` (insufficient baseline; never 0-as-safe nor 4×-as-max).
- Muscle set built from acute ∪ chronic-exclusive so a brand-new acute-only muscle is still evaluated and flagged.

### Finding 5 data (GA-30-E) — easyCount capture
- `aggregateMuscle` now counts `.easy` scored sets (was `continue`).
- `MuscleStrengthLoad` gains `easyCount: Int` (acute-window easy scored sets) + `hasChronicBaseline: Bool`. Consumption (coverage formula) is Wave 3.

## New MuscleStrengthLoad shape
`hardSetCount: Int, strengthLoad: Double, unscoredCount: Int, elevation: Double, easyCount: Int, hasChronicBaseline: Bool`

### Every memberwise init site updated
1. `StrengthLoadEngine.perMuscleStrengthLoad` (engine) — populates all six fields.
2. `StrainRiskEngineTests.strengthResult(...)` builder — added `easyCount: Int = 0`, `hasChronicBaseline: Bool = true` params (compile-touch; Wave 3 exercises them).
- Grep confirmed NO other `MuscleStrengthLoad(` call sites (no PRSShadowArmTests usage).

## No-sync grep (Task 3)
`grep MuscleStrengthLoad|StrengthLoadResult WorkloadApp/Services/SyncService.swift` → **0 references**. Both remain pure value structs (no `@Model`, no sync Codable). Invariant intact.

## Verification
- `StrengthLoadEngineTests` — all green (incl. new estRIRPrecise, fractional-RPE classify, steady-state→0, new-exercise→0+flag-false, established+spike→>0+flag-true, easyCount, windowed-boundary tests).
- FULL `WorkloadAppTests` suite via real xcodebuild — `** TEST SUCCEEDED **` (shared-type change gate).
- `git diff --stat` on BaselineTierFenceTests / AutoregulationFlagFenceTests / DualRunFlagFenceTests — EMPTY (untouched).
- No `.xcstrings` churn. No flag default changed.

## Deviations from Plan
None — plan executed exactly as written.

## Self-Check: PASSED
- Commit 1e5314a present on main.
- StrengthLoadEngine.swift contains `hasChronicBaseline` and `estRIRPrecise`.
- StrengthLoadEngineTests.swift contains `hasChronicBaseline` assertions.
