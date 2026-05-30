---
phase: 30-shadow-engine-quality-fixes
plan: 04
subsystem: prs-dual-run-surface
tags: [flag-on, dual-run, prescribed-workout, volume-modifier, updatedAt]
requires: [30-03]
provides: [nil-targetVolume-derivation, derivedBaseVolume, injected-now]
affects: []
key-files:
  modified:
    - WorkloadApp/Services/PRSDualRunSurface.swift
  created:
    - WorkloadAppTests/PRSDualRunSurfaceTests.swift
decisions: [GA-30-F]
metrics:
  completed: 2026-05-31
commit: 634e3f2
---

# Phase 30 Plan 04: PRSDualRunSurface Finding 6 Summary

The flag-ON `PRSDualRunSurface.adjust` no longer silently discards a volume recommendation when a first-time `PrescribedWorkout` has `targetVolume == nil`; it derives an effective base, applies the modifier, and bumps `updatedAt` (deterministically via an injected `now`).

## What changed (Finding 6 / GA-30-F)
- `adjust(prescribedWorkout:with:now:)` — added `now: Date = .now`. The flag-OFF guard stays FIRST (returns nil, mutates nothing → DualRunFlagFenceTests no-op byte-identical).
- Volume: `effectiveBase = workout.targetVolume ?? derivedBaseVolume(workout)`; `newVolume = effectiveBase * recommendation.volumeModifier` (always non-nil now). Existing-target path byte-identical (100 × 0.5 = 50). nil-target → derived base × modifier (0.5 → reduced; 0.0 rest → 0.0).
- `workout.updatedAt = now` on any mutation.

### derivedBaseVolume scheme
Volume proxy from the frozen template snapshot (`allExercises` → `TemplateSet`s):
1. Σ `targetReps` over non-warmup sets, if any reps specified; else
2. count of non-warmup working sets, if any; else
3. neutral `1.0` (modifier becomes the fraction-of-full so the reduction is never lost).

### Injected-now signature change
`adjust(prescribedWorkout:with:now: Date = .now)` — callers are unaffected (default `.now`); tests pass a fixed `Date` to assert the `updatedAt` bump deterministically.

## Test placement
New NON-fence `WorkloadAppTests/PRSDualRunSurfaceTests.swift` (lives in the synchronized `WorkloadAppTests` group, auto-included in the test target — confirmed by the passing run). `DualRunFlagFenceTests.swift` was NOT edited.

## Verification
- `PRSDualRunSurfaceTests` + `DualRunFlagFenceTests` — all green (flag-off nil no-op incl. updatedAt-unchanged; flag-on nil applies modifier to neutral 1.0 base → 0.5 and to template-derived base 13 → 6.5; rest 0.0 → 0.0; existing-volume byte-identical 100→50; updatedAt bumps to injected now; derivedBaseVolume fallbacks).
- FULL `WorkloadAppTests` — `** TEST SUCCEEDED **`.
- `git diff --stat` on the three fence files — EMPTY.
- `PRSActivation.isEnabled` + `PRSMasterActivation.isEnabled` defaults still `_override ?? false` (FALSE).
- No `.xcstrings` churn. The only "injury prediction" match is the pre-existing disclaimer comment (L13).

## Deviations from Plan
None — plan executed exactly as written.

## Self-Check: PASSED
- Commit 634e3f2 present on main.
- PRSDualRunSurface.swift contains `updatedAt` bump + `derivedBaseVolume`.
- PRSDualRunSurfaceTests.swift contains `targetVolume` nil-case coverage.
