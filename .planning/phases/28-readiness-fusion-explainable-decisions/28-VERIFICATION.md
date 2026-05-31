# Phase 28 — Readiness Fusion + Explainable Decisions + ACWR Demotion — VERIFICATION

**Status:** Waves 1, 2, 3 COMPLETE + verified green. Wave 4 COMPLETE + verified green —
flagged dual-run surface + real-workout adjustment + fence tests (core) AND the live
`DashboardView` wiring (28-05). The **human visual-review checkpoint** (provisional card
placement, autonomous: false) is the only remaining step — by design.

**Genuinely-green HEAD = 560a194** (feat(28-05): wire flagged dual-run card into the live
Dashboard, gated off). Full `WorkloadAppTests`: **xcodebuild exit 0, `** TEST SUCCEEDED **`,
481 passed, 0 failures, 0 compile errors** (Xcode, iPhone 17 Pro Max simulator
id `8E872500-703D-4292-9758-38ADFCCFB126`).

**Build/test command (authoritative — uses `-project` with absolute path; the repo root is NOT
the project dir):**
```
xcodebuild test \
  -project "/Users/hanwen/Desktop/Tonus/workload management/workload management.xcodeproj" \
  -scheme "workload management" \
  -destination 'platform=iOS Simulator,id=8E872500-703D-4292-9758-38ADFCCFB126' \
  -only-testing:WorkloadAppTests
```

## Commits (atomic, on `main`, no push) — actual chain

| Commit | Kind | Summary |
|--------|------|---------|
| b9d3e56 | feat(28-01) | PRSActivation flag (default false) + ReadinessZone + pure ReadinessFusionEngine + tests |
| 8446260 | feat(28-02) | Flagged Autoregulation readiness×strain-risk swap + ReasoningEngine.explainDecision |
| fef8183 | feat(28-03) | PRS-v1 predicting arm in shadow harness (shadow-only, local-only *PRS columns) |
| 64efc06 | fix+feat | Repair Wave 2/3 test targets + Wave 4 PRSDualRunSurface/PRSDualRunCard + PrescribedWorkout local-only target fields + DualRunFlagFenceTests |
| a14422e | fix(28-03) | PRSShadowArmTests use `CycleContext.none` (compile fix) |
| eb10579 | fix(28-03) | ShadowPredictorTests arm-registry guard updated to expect 3rd PRS arm — first genuinely-green commit |
| 560a194 | feat(28-05) | **Wire flagged dual-run card into live Dashboard (gated off): PRSReadinessInputBuilder + DashboardViewModel.dualRunMessage/buildDualRunMessage() + PRSDualRunCard mount + DashboardViewModelDualRunTests — verified green HEAD (481 passed, 0 failures)** |

(607d103 / 6216b89 / 575dede / b478cf3 / fe8065f / ac98380 / 90cec6b are superseded VERIFICATION-doc
commits; this file is the final.)

## HARD INVARIANTS — all machine-verified on HEAD (green commit 560a194)

- **Master flag defaults FALSE:** `PRSActivation.isEnabled == false`; `PRSMasterActivation` default FALSE — neither flipped.
- **Live recovery byte-unchanged:** `RecoveryScoreEngine` untouched; `BaselineTierFenceTests` (3/3) green AND UNMODIFIED.
- **Live recommendation byte-identical with flag off:** `AutoregulationFlagFenceTests.test_flagOff_recommendFlagged_isByteIdenticalToLegacy_fullMatrix` green (FULL recovery×ACWR matrix) AND UNMODIFIED.
- **Live Dashboard byte-identical with flag off (NEW, 28-05):** `DashboardViewModel.load()` does NO new published-property work and leaves `dualRunMessage == nil` (`DashboardViewModelDualRunTests.test_flagOff_dualRunMessage_nilAfterLoad`); `PRSDualRunCard(message: nil)` renders `EmptyView` → layout unchanged. The entire readiness/strain recompute + message build sit inside `if PRSActivation.isEnabled`.
- **No fabrication (NEW, 28-05):** `PRSReadinessInputBuilder` recomputes readiness/strain with the real engines (BaselineEngine personal z → ReadinessFusionEngine; StrengthLoad + LoadDistribution + real FatigueResult → StrainRiskEngine.fuse); cold-start z → nil (excluded, never imputed); returns nil rather than synthesize when the real FatigueResult is absent (`test_flagOn_noFatigueResult_dualRunMessage_staysNil`).
- **Flag-on real build (NEW, 28-05):** under `PRSActivation.withEnabled(true)`, `buildDualRunMessage()` emits a non-nil `DualRunMessage` with `previousHeadline == recommendation.headline` and a non-empty `updatedHeadline` (`test_flagOn_buildDualRunMessage_nonNil_withLegacyAndUpdatedHeadlines`).
- **Predicting arm SHADOW-only:** `prs` arm runs flag-independently, never user-facing.
- **New SwiftData state local-only / never-synced:** no `@Model` / `Codable` / `SyncService` change in 28-05 (display-only recompute); `*PRS` columns + `PrescribedWorkout.targetRPE/targetVolume` remain additive, non-Codable, absent from the sync DTO.
- **ACWR demoted to context-label:** `test_flagOn_acwrIsContextLabelOnly_neverInWarnings` green; the 28-05 builder emits ACWR only as a label.
- **No injury-prediction copy (GA-11):** guards green; user-facing copy is "Tuwa"-only.
- **Flag-off UI byte-unchanged:** `DualRunFlagFenceTests` green AND UNMODIFIED.
- **Atomic commits to main, no branch, no push, no live-default flip.** HELD.

## Fence tests UNMODIFIED — evidence

`git diff --stat <pre-28-05>..560a194 -- WorkloadAppTests/AutoregulationFlagFenceTests.swift WorkloadAppTests/DualRunFlagFenceTests.swift WorkloadAppTests/BaselineTierFenceTests.swift` → **no output** (zero changes). The three fence suites are byte-identical to their pre-28-05 state and all pass on HEAD.

## Plan-check MUST-FIXES (28-05) — disposition

- Flag-on test must use the SYNCHRONOUS-method route (not `await load()` inside the sync `withEnabled` closure) → DONE: the flag-gated build is factored into a synchronous `buildDualRunMessage()` called at the end of `load()`, and the flag-on tests exercise that method directly under `PRSActivation.withEnabled(true)`. (The flag-off test runs `await vm.load()` then asserts nil.)
- Entire readiness/strain build INSIDE `if PRSActivation.isEnabled` → DONE.
- Mount `PRSDualRunCard` below `HeroReadinessCard` (provisional, commented) → DONE.
- New ViewModel test (flag-off → nil) → DONE; fence tests untouched → DONE.

### Deviations auto-fixed during 28-05 (documented in 28-05-SUMMARY.md)
- Unique pbxproj GUIDs (`EE2806…`) for the new source file — the initial `EE2805…` collided with `PRSDualRunCard.swift` (Rule 3 blocking build fix).
- Flag-on tests declared `async` to avoid a Swift-Concurrency `TaskLocal` double-free on synchronous `@MainActor` VM deinit (Rule 1); the flag-gated build remains synchronous.

## REMAINING (next session)

1. **Human visual-review checkpoint (Wave 4 — visuals NOT final, autonomous: false):** preview the
   flagged dual-run card (DEBUG/preview harness only — NEVER flip the shipped default); confirm it
   renders directly below the hero per DESIGN.md (0pt corners, hairline border, no shadow, General
   Sans, accent NOT on the card), uses "Tuwa", never says "injury prediction"; judge whether the
   placement (below the hero) is the right home or it should sit lower. PROVISIONAL.
2. Finalize: STATE.md / ROADMAP.md advance; requirements mark-complete (PRS-28-04, PRS-28-05).
