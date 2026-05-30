# Phase 28 — Readiness Fusion + Explainable Decisions + ACWR Demotion — VERIFICATION

**Status:** Waves 1–3 COMPLETE + verified green. Wave 4 core (engine + flagged surface + real-workout
adjustment + fence test) COMPLETE + verified green. Wave 4 final UI integration into `DashboardView`
and the **human visual-review checkpoint** remain (autonomous: false — by design).

**Build/test command (authoritative):**
```
cd "workload management" && xcodebuild test \
  -project "workload management.xcodeproj" -scheme "workload management" \
  -destination 'platform=iOS Simulator,id=CAF84E71-BB64-491D-87C8-875A0143B26D' \
  -only-testing:WorkloadAppTests
```
Last full run: `** TEST SUCCEEDED **`, 0 failures, 0 compile errors (Xcode 26.1.1, iPhone 17 Pro sim).

## Commits (atomic, on `main`, no push)

| Commit | Wave | Summary |
|--------|------|---------|
| b9d3e56 | 1 | PRSActivation flag (default false) + ReadinessZone + pure ReadinessFusionEngine + tests |
| 8446260 | 2 | Flagged Autoregulation readiness×strain-risk swap + ReasoningEngine.explainDecision |
| fef8183 | 3 | PRS-v1 predicting arm in shadow harness (shadow-only, local-only *PRS columns) |
| 607d103 | — | This 28-VERIFICATION doc (initial) |
| a1b3f9d | 2/3/4 | Repair Wave 2/3 test targets (RecoveryResult/Athlete inits, optional MAEs, card tokens) + Wave 4 PRSDualRunSurface/PRSDualRunCard + PrescribedWorkout local-only target fields + DualRunFlagFenceTests |

> NOTE: 8446260 and fef8183 were briefly committed with non-compiling NEW test files (a session
> tool-output delivery lag served stale "TEST SUCCEEDED" logs); a1b3f9d repaired the test targets to
> green. The engine/source changes in those commits were always correct and flag-gated. The final
> full `WorkloadAppTests` run is green: **287 tests, 0 failures, 0 compile errors.**

## HARD INVARIANTS — status

- **Master flag defaults FALSE:** `PRSActivation.isEnabled` returns `false` by default (test-only `withEnabled` override). VERIFIED (`test_PRSActivation_defaultsFalse`).
- **Live recovery byte-unchanged:** `RecoveryScoreEngine` untouched; `BaselineTierFenceTests` green after every wave. VERIFIED.
- **Live recommendation byte-identical with flag off:** `AutoregulationFlagFenceTests` golden snapshot across the FULL recovery×ACWR matrix (flag off == legacy `recommend(input:)`). VERIFIED.
- **Predicting arm SHADOW-only:** the `prs` `ExperimentalArm` runs unconditionally (flag-independent) and is never user-facing. VERIFIED (`test_prsArm_runsRegardlessOfActivationFlag`).
- **New SwiftData state local-only / never-synced:** `*PRS` columns on `CyclePredictionLog` + `PrescribedWorkout.targetRPE/targetVolume` are additive; `CyclePredictionLog`/`ShadowArmPrediction` are non-Codable and absent from `SyncService`. VERIFIED (sync-omission tests + grep).
- **ACWR demoted to context-label:** flag-on path keys on (readinessZone × strainRiskZone); ACWR appears only as a `Load context:` label, never in a decision or warning. VERIFIED (`test_flagOn_acwrIsContextLabelOnly_neverInWarnings`).
- **No injury-prediction copy (GA-11):** guards on ReadinessZone, flagged Autoregulation copy, decision reasons, and dual-run copy. VERIFIED.
- **Atomic commits to main, no branch, no push, no live-default flip.** HELD.
- **Tuwa-only copy.** dual-run copy guarded (`test_dualRunCopy_usesTuwaNotDeadNames`).

## Plan-check MUST-FIXES — disposition

- 28-03 full flag-OFF golden across recovery×ACWR matrix → DONE (`AutoregulationFlagFenceTests`).
- Full WorkloadAppTests run (not just --filter) + BaselineTierFenceTests each wave → DONE.
- ShadowDecisionLog schema registration + sync-omission negative assertion → `CyclePredictionLog`/`ShadowArmPrediction` confirmed in `WorkloadApp.swift` ModelContainer schema; non-Codable + SyncService-absent asserted.
- Phase-27 substrate exists (StrainRiskEngine/StrainRiskZone) → CONFIRMED present (commits 4fc4ffa/0fa3207/75ba4cf, f61719e); flagged path consumes its concrete API.
- Flag-OFF ReasoningEngine regression assertion → DONE (`test_summarize_signatureAndOutput_unchanged`, `test_summarize_isIndependentOfPRSFlag`).
- SPEC "recommendation adjusts a REAL logged/planned workout" → DONE (gated): `PRSDualRunSurface.adjust(prescribedWorkout:)` caps RPE / scales volume on a real `PrescribedWorkout` when the flag is on; no-op with flag off (`DualRunFlagFenceTests`).

## REMAINING (next session)

1. Wire `PRSDualRunCard` into `DashboardView` behind `PRSActivation.isEnabled` (invisible with flag off → Dashboard byte-identical); compute `PRSDualRunSurface.dualRunMessage(...)` + apply `adjust(...)` in `DashboardViewModel` behind the flag.
2. Human visual-review checkpoint (Wave 4 — visuals NOT final): enable PRSActivation in a DEBUG build, confirm the dual-run surface + real-workout adjustment render per DESIGN.md and copy, then approve as a starting point.
3. Finalize: per-wave SUMMARY entries, STATE.md / ROADMAP.md advance.
