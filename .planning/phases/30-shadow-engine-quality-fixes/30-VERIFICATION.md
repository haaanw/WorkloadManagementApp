# Phase 30 — Shadow-engine quality fixes — VERIFICATION

**Status:** PENDING (scaffold — completed after Wave 4).

## Build / test command

```
cd "workload management" && xcodebuild test \
  -project "workload management.xcodeproj" -scheme "workload management" \
  -destination 'platform=iOS Simulator,id=CAF84E71-BB64-491D-87C8-875A0143B26D'
```

## Finding-by-finding verification matrix

| # | Finding | Wave | Verification | Status |
|---|---------|------|--------------|--------|
| 1 | StrainRisk soft-tissue/rest-debt double-count | 3 | Component 3 uses de-double-counted fatigue (re-normalised 4 components); single-count delta test; soft-tissue/rest-debt each counted once | PENDING |
| 2 | LoadDistribution scale mismatch | 2 | Per-stream z-standardised series feeds monotony/strain; strength measurably contributes; no NaN on zero-variance stream | PENDING |
| 3 | StrengthLoad chronic ⊇ acute + zero-chronic + windowed off-by-one | 1 | Chronic excludes acute (half-open partition); steady-state→0, new-exercise→0+hasChronicBaseline-false, spike→>0+true; windowed boundary test | PENDING |
| 4 | StrengthLoad RPE→RIR truncation | 1 | estRIRPrecise Double; RPE 7.5→2.5→.easy, 8.0→.hard | PENDING |
| 5 | StrainRisk coverage excludes easy | 1 (data) + 3 (use) | easyCount captured; coverage = (hard+easy)/(hard+easy+unscored); all-easy session → full coverage | PENDING |
| 6 | PRSDualRun nil-targetVolume discard + updatedAt | 4 | nil-targetVolume modifier applied to derived base; updatedAt bumped; flag-off no-op + existing-volume byte-identical | PENDING |

## Hard-invariant verification

| Invariant | Check | Status |
|-----------|-------|--------|
| Live byte-identical | BaselineTierFenceTests + AutoregulationFlagFenceTests + DualRunFlagFenceTests green | PENDING |
| Fence files untouched | `git diff --stat` on the 3 fence files = empty across all 4 waves | PENDING |
| No activation | `PRSActivation.isEnabled` + `PRSMasterActivation.isEnabled` defaults FALSE (grep) | PENDING |
| Local-only / never-synced | `MuscleStrengthLoad` / `StrengthLoadResult` absent from SyncService (grep == 0) | PENDING |
| No injury-prediction copy | grep guard clean | PENDING |
| Full suite green | `xcodebuild test` exit 0, 0 failures (excl. known XCUITest screenshot flake) | PENDING |
| Atomic to main, no branch, no push | git log on main; no remote push | PENDING |

## Commit chain

| Commit | Wave | Notes |
|--------|------|-------|
| _pending_ | 1 | StrengthLoadEngine Findings 3+4 + MuscleStrengthLoad fields |
| _pending_ | 2 | LoadDistributionEngine Finding 2 z-standardisation |
| _pending_ | 3 | StrainRiskEngine Findings 1+5 |
| _pending_ | 4 | PRSDualRunSurface Finding 6 |

## Notes

- These fixes intentionally change shadow OUTPUTS (Strain-Risk score, coverage confidence, per-muscle elevation, monotony, dual-run volume). Engine/oracle tests re-derived to new CORRECT values; the three live fences are NOT edited.
- DISCARD any `.xcstrings` build-churn before committing each wave.
