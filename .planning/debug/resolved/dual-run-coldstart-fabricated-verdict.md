---
status: resolved
trigger: "dual-run verdict surface fabricates a verdict on cold-start instead of deferring (violates LOCKED honest-confidence deferral). Failing test VerdictSurfaceActivationTests.test_coldStart_optIn_defersToLegacy expects vm.dualRunMessage == nil; currently non-nil."
created: 2026-06-13T00:00:00Z
updated: 2026-06-13T00:00:00Z
---

## Current Focus

reasoning_checkpoint:
  hypothesis: "build() emits a verdict on cold-start because its only deferral is `guard let fatigue = fatigueResult`, and on the test's cold-start path (no TrainingProfile → isColdStartActive=false) FatigueIndexEngine returns a non-nil neutral FatigueResult. The honest 'no usable personal baseline' signal (all personal z's nil) is ignored."
  confirming_evidence:
    - "DashboardViewModel cold-start path: no WorkloadSnapshot + no TrainingProfile → isColdStartActive=false → else branch computes a non-nil FatigueResult → lastDualRunFatigue non-nil."
    - "BaselineEngine.score returns nil z when μ==nil (count==0) — pure cold-start → all three personalZ nil. With 14 real snapshots: count=14, madBuffer=13>=5 → HRV z non-nil."
  falsification_test: "If the cold-start athlete somehow had a usable personal baseline (≥1 non-nil z) it would (correctly) still produce a verdict; the gate only fires when ALL z's are nil."
  fix_rationale: "Gate on usable personal baseline (≥1 non-nil personal z), reusing BaselineEngine.score's existing madMinValid cold-start convention. This is the root-cause honest signal (no real baseline → defer), not a symptom patch. It does NOT use composite confidence, which is 0 even at 14 days (cCount boundary) and would over-defer the passing 14-snapshot test."
  blind_spots: "Relies on score() returning nil for empty series; verified by reading the guard. The 14-snapshot test's HRV series (14 ascending values) must fold to count=14 — assumed each insert is a distinct day; test seeds 14 distinct days."

next_action: Run the verification test bundle on sim CAF84E71-BB64-491D-87C8-875A0143B26D, then app build.

## Symptoms

expected: On cold-start (no recovery/session history), dual-run opt-in defers → vm.dualRunMessage == nil (honest-confidence deferral, LOCKED).
actual: vm.dualRunMessage is non-nil — a verdict is fabricated from empty/neutral data.
errors: test_coldStart_optIn_defersToLegacy fails (XCTAssertNil on vm.dualRunMessage).
reproduction: VerdictSurfaceActivationTests.test_coldStart_optIn_defersToLegacy — insert Athlete with no history, vm.load(...), vm.activateVerdictSurface().
started: Phase 41 ACT-01 (verdict surface activation).

## Eliminated

## Evidence

- timestamp: 2026-06-13T00:00:00Z
  checked: DashboardViewModel.load() cold-start branch (lines 169-184, 248-296)
  found: In the test (no WorkloadSnapshot, no TrainingProfile) isColdStartActive=false → the else branch runs FatigueIndexEngine.compute over empty inputs → fatigueResultForReadiness is NON-NIL → lastDualRunFatigue non-nil.
  implication: The builder's only deferral guard (`guard let fatigue = fatigueResult`) does NOT fire on this cold-start path. Confirms task root cause.

- timestamp: 2026-06-13T00:00:00Z
  checked: BaselineEngine.confidence (lines 342-359) + cCount formula
  found: confidence = cCount*cRecency*cDisp; cCount = clamp01((count - confFloorDays=14)/(confFullDays=60 - 14)). So confidence == 0 for ALL count <= 14.
  implication: A `confidence == 0` (or `> 0`) gate would BREAK test_productionOptIn which seeds exactly 14 snapshots (count=14 → confidence==0). Composite confidence is NOT the right data-sufficiency signal at the boundary.

- timestamp: 2026-06-13T00:00:00Z
  checked: BaselineEngine.score cold-start gate (lines 256-265) + personalZ (PRSReadinessInputBuilder lines 138-146)
  found: score returns non-nil z only when state.mu != nil AND count >= 2 AND madBuffer.count >= madMinValid(5). With 14 folds: count=14, madBuffer=13 → z non-nil. With 0 folds: mu=nil → z=nil. This is the established "usable personal baseline" convention (madMinValid).
  implication: The honest gate = "do we have a usable personal baseline" = the personal z is non-nil for the signals we have. Reuses the existing madMinValid/score cold-start convention rather than inventing a number.

## Resolution

root_cause: PRSReadinessInputBuilder.build's ONLY deferral guard was `guard let fatigue = fatigueResult`. On the cold-start path (no WorkloadSnapshot + no TrainingProfile → DashboardViewModel.isColdStartActive=false) FatigueIndexEngine.compute returns a NON-NIL neutral FatigueResult over empty inputs, so the strain-channel guard passes and the builder emitted a verdict synthesized from no personal data — violating the LOCKED honest-confidence deferral.
fix: Added a data-sufficiency guard in build() AFTER computing the three personal z's — `guard hrvZ != nil || rhrZ != nil || sleepZ != nil else { return nil }`. personalZ is nil exactly in BaselineEngine.score's documented cold-start regime (μ==nil / count<2 / madBuffer<madMinValid=5). Pure cold-start → all three nil → defer. Reuses the engine's existing madMinValid convention; NOT composite confidence (which is 0 even at 14 days due to the cCount floor, and would over-defer the passing 14-snapshot tests).
verification: VerdictSurfaceActivationTests (6/6), DashboardViewModelDualRunTests (3/3), DualRunFlagFenceTests (7/7) all pass — ** TEST SUCCEEDED **. App build ** BUILD SUCCEEDED ** on sim CAF84E71-BB64-491D-87C8-875A0143B26D.
files_changed: [WorkloadApp/Services/PRSReadinessInputBuilder.swift]
