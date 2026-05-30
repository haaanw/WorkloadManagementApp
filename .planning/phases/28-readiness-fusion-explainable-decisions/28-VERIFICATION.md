# Phase 28 — Readiness Fusion + Explainable Decisions + ACWR Demotion — VERIFICATION

**Status:** Waves 1, 2, 3 COMPLETE + verified green. Wave 4 CORE (flagged dual-run surface +
real-workout adjustment + fence test) COMPLETE + verified green. Wave 4 final UI integration into
`DashboardView` and the **human visual-review checkpoint** remain (autonomous: false — by design).

**HEAD = fd4e1b9 — genuinely green** (this is the first fully-green HEAD; earlier intermediate
commits were briefly red due to a session tool-output delivery lag that served stale build logs to an
in-line commit gate — see NOTE).

**Build/test command (authoritative — MUST run from inside the project dir):**
```
cd "workload management" && xcodebuild test \
  -project "workload management.xcodeproj" -scheme "workload management" \
  -destination 'platform=iOS Simulator,id=CAF84E71-BB64-491D-87C8-875A0143B26D' \
  -only-testing:WorkloadAppTests
```
Last full run on HEAD: **`** TEST SUCCEEDED **`, Executed 290 tests, with 0 failures, 0 compile
errors** (Xcode 26.1.1, iPhone 17 Pro simulator).

## Commits (atomic, on `main`, no push)

| Commit | Wave | Summary |
|--------|------|---------|
| b9d3e56 | 1 | PRSActivation flag (default false) + ReadinessZone + pure ReadinessFusionEngine + tests |
| 8446260 | 2 | Flagged Autoregulation readiness×strain-risk swap + ReasoningEngine.explainDecision |
| fef8183 | 3 | PRS-v1 predicting arm in shadow harness (shadow-only, local-only *PRS columns) |
| 64efc06 | 2/3/4 | Repair Wave 2/3 test targets + Wave 4 PRSDualRunSurface/PRSDualRunCard + PrescribedWorkout local-only target fields + DualRunFlagFenceTests |
| a14422e | 3 | PRSShadowArmTests use `CycleContext.none` (compile fix) |
| fd4e1b9 | 3 | ShadowPredictorTests arm-registry guard updated to expect the 3rd PRS arm — **HEAD green** |

(607d103 / 6216b89 / 575dede are intermediate VERIFICATION-doc commits, superseded by this file.)

> NOTE (process): a session-specific lag delivered each tool call's output one turn late, so an
> in-line `if green then commit` shell gate acted on STALE logs and briefly committed 8446260 /
> fef8183 / 64efc06 / a14422e with a not-yet-green test target. Each was repaired forward (no history
> rewrite, no force-push); fd4e1b9 is the first verified-green HEAD. The engine/source changes were
> always correct and flag-gated — only test-target compilation + one outdated pre-existing assertion
> needed repair.

## HARD INVARIANTS — all machine-verified on HEAD

- **Master flag defaults FALSE:** `PRSActivation.isEnabled == false` by default (`test_PRSActivation_defaultsFalse`).
- **Live recovery byte-unchanged:** `RecoveryScoreEngine` untouched; `BaselineTierFenceTests` (3/3) green.
- **Live recommendation byte-identical with flag off:** `AutoregulationFlagFenceTests.test_flagOff_recommendFlagged_isByteIdenticalToLegacy_fullMatrix` green (FULL recovery×ACWR matrix).
- **Predicting arm SHADOW-only:** `prs` `ExperimentalArm` runs flag-independently, never user-facing (`test_prsArm_runsRegardlessOfActivationFlag`).
- **New SwiftData state local-only / never-synced:** `*PRS` columns + `PrescribedWorkout.targetRPE/targetVolume` are additive, non-Codable on the @Model, absent from `SyncService.PrescribedWorkoutRow` DTO (confirmed from committed HEAD). `test_cyclePredictionLog_isNotCodable_localOnly` / `test_shadowArmPrediction_isNotCodable_localOnly` green.
- **ACWR demoted to context-label:** `test_flagOn_acwrIsContextLabelOnly_neverInWarnings` green.
- **No injury-prediction copy (GA-11):** guards green on ReadinessZone, flagged Autoregulation copy, decision reasons, dual-run copy. **Tuwa-only:** `test_dualRunCopy_usesTuwaNotDeadNames` green.
- **Flag-off UI byte-unchanged:** `DualRunFlagFenceTests` (message nil + adjust no-op) green.
- **Atomic commits to main, no branch, no push, no live-default flip.** HELD.
- **Isolation:** the new flagged path is not referenced from any live ViewModel/View call site (Wave-4 UI wiring deferred to post-checkpoint).

## Plan-check MUST-FIXES — disposition

- Full flag-OFF golden across recovery×ACWR matrix → DONE (`AutoregulationFlagFenceTests`).
- Full `WorkloadAppTests` run (not just --filter) + `BaselineTierFenceTests` each wave → DONE (290 tests).
- ShadowDecision/*PRS schema registration in `WorkloadApp.swift` ModelContainer + sync-omission negative assertion → DONE.
- Phase-27 substrate (StrainRiskEngine/StrainRiskZone) present → CONFIRMED (4fc4ffa/0fa3207/75ba4cf, f61719e).
- Flag-OFF ReasoningEngine regression assertion → DONE (`test_summarize_signatureAndOutput_unchanged`, `test_summarize_isIndependentOfPRSFlag`).
- SPEC "recommendation adjusts a REAL logged/planned workout" → DONE (gated): `PRSDualRunSurface.adjust(prescribedWorkout:)` caps RPE / scales volume on a real `PrescribedWorkout` when flag on; no-op flag off (`DualRunFlagFenceTests`).

## REMAINING (next session)

1. Wire `PRSDualRunCard` into `DashboardView` behind `PRSActivation.isEnabled` (invisible with flag off → Dashboard byte-identical); compute `PRSDualRunSurface.dualRunMessage(...)` + apply `adjust(...)` in `DashboardViewModel` behind the flag.
2. **Human visual-review checkpoint (Wave 4 — visuals NOT final):** enable PRSActivation in a DEBUG build; confirm the dual-run surface + real-workout adjustment render per DESIGN.md, use "Tuwa", never say "injury prediction"; approve as a starting point.
3. Finalize: per-wave SUMMARY entries; STATE.md / ROADMAP.md advance; requirements mark-complete (PRS-28-01..06).
