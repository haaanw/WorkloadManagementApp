# 27-01 notes — StrengthLoadEngine (Wave 1)

## StrengthLoadState: SKIPPED (D-27-02)

The optional local-only `StrengthLoadState` @Model was **not** added. The est-1RM
reference is a cheap **pure rolling-best recompute** over the already-windowed,
athlete-scoped session history passed into the engine (`e1RMReferences(sessions:)` —
a single linear pass over sets reading the existing `SetRecord.estimated1RM`). It is
bounded by the caller's history window and monotone, so it needs no persisted per-day
state and triggers no unacceptable full-history scan. Per D-27-02 the model is therefore
omitted, which also means **no new SwiftData model, no Schema registration, and no
local-only/never-synced surface was introduced in Wave 1** (SyncService untouched).

## pbxproj registration (deviation — Rule 3)

The WorkloadApp **app target is NOT a synchronized file group**: only `WorkloadAppTests`
and `ScreenshotTests` are `PBXFileSystemSynchronizedRootGroup`s. The app target uses
**explicit** file membership, so a new app-source file is not auto-included. The first
build failed solely with `Cannot find 'StrengthLoadEngine' in scope`. Fixed by adding
the standard **four** entries for `StrengthLoadEngine.swift`, mirroring
`FatigueIndexEngine.swift`, with fresh unique ids:

- PBXBuildFile  `EE2701020000000000000001` (… in Sources)
- PBXFileReference `EE2701010000000000000001` (path = StrengthLoadEngine.swift)
- children entry in the Services group
- entry in the app target `PBXSourcesBuildPhase`

The test file needed **no** pbxproj edit (it lives in the synchronized
`WorkloadAppTests` group).

## Chosen named constants

| Constant | Value | Meaning |
|----------|-------|---------|
| `moderateCut` | 0.65 | rel-intensity light→moderate boundary |
| `heavyCut` | 0.80 | moderate→heavy boundary |
| `maximalCut` | 0.90 | heavy→maximal boundary |
| `hardSetIntensityThreshold` | 0.80 (= heavyCut) | rel-intensity ≥ this ⇒ hard set |
| `hardSetRIRThreshold` | 2 | RIR ≤ this ⇒ hard set |
| `rpeToRIRMax` | 10.0 | RIR = max(0, 10 − rpe) bridge |
| strain weight light / moderate / heavy / maximal / RIR-nil | 0.6 / 0.8 / 1.0 / 1.3 / 0.8 | per-bucket hard-set weight (NOT tonnage) |
| `elevationDeadband` | 0.20 | \|ratio−1\| ≤ this ⇒ 0 elevation |
| `elevationScale` | 1.0 | (excess / scale) clamped 0…1 |
| `acuteWindowDays` | 7 | acute window |
| `chronicWindowDays` | 28 | chronic window |

Elevation mirrors `FatigueIndexEngine.computeLoadElevation` philosophy (acute/chronic
ratio with a deadband, clamped 0…1) — increase-only, with a `chronic <= 0` guard. It is
**not** ACWR. Acute and chronic strength loads are per-day-normalised before the ratio so
the 7-day and 28-day windows compare on the same basis.

## Invariants

- Pure deterministic struct, Foundation-only; all date math takes a passed-in `asOf` +
  `Calendar` (no `Date.now` / `Calendar.current`).
- Reuses the EXISTING `SetRecord.estimated1RM` (Epley) — Epley is NOT reimplemented.
- NO raw `weight * reps` tonnage is summed anywhere.
- No live engine (`RecoveryScoreEngine`, `AutoregulationEngine`) modified; no
  master/activation flag added or flipped.

## Test result

- Targeted: `WorkloadAppTests/StrengthLoadEngineTests` → **TEST SUCCEEDED**, 23/23, 0 failures.
- FULL `WorkloadAppTests` suite → **TEST SUCCEEDED**, 0 compile errors, 0 failures.
- `BaselineTierFenceTests` (live recovery-score machine lock) → all 3 PASSED
  (`testEngineDoesNotImportLivePath`, `testLiveBaselineStillExists`,
  `testSubstrateNotWiredLive`) — live baseline byte-unchanged.
- No `.xcstrings` build-churn produced.
