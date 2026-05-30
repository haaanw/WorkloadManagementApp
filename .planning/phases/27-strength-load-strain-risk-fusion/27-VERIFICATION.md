# Phase 27 Verification — Strength-load model + Strain-Risk fusion

**Status:** COMPLETE — 3/3 waves executed SERIAL, each committed atomically to `main`.

| Wave | Plan | Commit | Result |
|------|------|--------|--------|
| 1 | 27-01 StrengthLoadEngine | `3f7b29c` | Green — targeted 23/23 + full suite |
| 2 | 27-02 LoadDistributionEngine | `9c8f9e1` | Green — targeted + full suite |
| 3 | 27-03 StrainRiskEngine + StrainRiskZone | `6e8d9f2` | Green — targeted + full suite (shared Enums.swift) |

## Success criteria (from ROADMAP / 27-PLAN)

- [x] Per-muscle HARD SETS + relative-intensity buckets via est-1RM/RPE/RIR from
      `SetRecord`/`ExerciseEntry`, NEVER raw tonnage — `StrengthLoadEngine` reuses the
      existing `SetRecord.estimated1RM` (Epley not reimplemented); no `weight*reps` sum.
- [x] Fuse sRPE/TRIMP endurance load + `FatigueIndexEngine` + completeness-gated Foster
      monotony/strain — `LoadDistributionEngine` (unified daily series + gate + fallback) and
      `StrainRiskEngine` (fusion).
- [x] Strain-Risk output = honest heuristic flag (score + `StrainRiskZone` + ranked factors +
      confidence); "load-tolerance / overreaching caution", NEVER "injury prediction"
      (string-audit test).
- [x] FIXED sign-constrained glass-box; NOT logistic, NOT fitted, NOT per-user tuned.
- [x] Consumes Phase 25 (`NiggleInjuryDeriver` via FatigueResult.softTissueRisk +
      recurrence) and Phase 26 (`BaselineEngine`-derived endurance elevation + confidence).
- [x] Pure deterministic structs; any per-day state would be local-only/never-synced —
      StrengthLoadState SKIPPED (D-27-02, pure recompute), so no new model/sync surface.

## HARD INVARIANTS

- [x] Shadow harness stays gated OFF; no live activation of any new arm; no master flag added
      or flipped (grep `NO_ACTIVATION_FLAG`).
- [x] Live recovery score BYTE-UNCHANGED — `BaselineTierFenceTests` GREEN + unchanged in all
      three full-suite runs (`testEngineDoesNotImportLivePath`, `testLiveBaselineStillExists`,
      `testSubstrateNotWiredLive`). `RecoveryScoreEngine.computeBaseline` not touched.
- [x] Strain-Risk does NOT alter the live `AutoregulationEngine` recommendation or recovery
      score — isolation grep == 0 in `AutoregulationEngine.swift` / `RecoveryScoreEngine.swift`.
- [x] No new SwiftData model added (StrengthLoadState skipped) → no sync surface; `SyncService`
      untouched.
- [x] New engines are pure structs, static methods, deterministic, Foundation-only (dates +
      Calendar injected; no `Date.now` / `Calendar.current`).
- [x] Atomic commits directly to `main`; NO new branch; NOT pushed; no live default flipped.
- [x] Waves run SERIAL; FULL `WorkloadAppTests` run after the shared `Enums.swift` change
      (Wave 3); `.xcstrings` churn checked (none produced).
- [x] Product name "Tuwa"; no Faros/Tonus/Tutrice in any user-facing copy added.

## Phase-specific invariant

- [x] Strain-Risk is display/shadow context ONLY this phase — standalone substrate, not wired
      into any live decision.

## Test evidence

All three waves: `xcodebuild test ... -only-testing:WorkloadAppTests` → `** TEST SUCCEEDED **`,
0 compile errors, 0 failures, BaselineTierFenceTests green.

## Notable deviation

The WorkloadApp **app target is not a `PBXFileSystemSynchronizedRootGroup`** (only
`WorkloadAppTests`/`ScreenshotTests` are). Each new app-source engine had to be explicitly
registered in `project.pbxproj` (4 entries each, ids `EE2701*` / `EE2702*` / `EE2703*`),
mirroring `FatigueIndexEngine`. Build-verified by passing targeted tests.
