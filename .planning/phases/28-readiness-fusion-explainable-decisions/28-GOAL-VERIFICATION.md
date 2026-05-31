---
phase: 28-readiness-fusion-explainable-decisions
verified: 2026-05-31T00:00:00Z
status: human_needed
score: 8/8 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Enable PRSActivation in a DEBUG build; confirm the dual-run surface (PRSDualRunCard) + real-workout adjustment render per DESIGN.md (0pt corners, no shadows, General Sans, 8pt grid), use 'Tuwa', never say 'injury prediction'."
    expected: "Card renders both legacy + updated recommendation; copy is Tuwa-only; no injury-prediction framing; design-system compliant."
    why_human: "Visual appearance + DESIGN.md compliance cannot be verified by grep. Wave-4 UI wiring into DashboardView is deliberately deferred to the main loop; the human visual-review checkpoint is a planned post-phase gate, NOT a phase blocker."
gaps: []
deferred:
  - truth: "PRSDualRunCard wired into DashboardView behind PRSActivation.isEnabled"
    addressed_in: "Phase 28 Wave-4 final UI integration (deferred to main loop by design) + Phase 29 activation gate"
    evidence: "PRSActivation flag gates live swap; Wave-4 final DashboardView wiring + human visual review explicitly deferred per phase spec. Card + surface exist and are flag-gated; only the call-site wiring is deferred."
---

# Phase 28: Readiness Fusion + Explainable Decisions + ACWR Demotion + PRS-v1 Shadow Arm — Goal Verification Report

**Phase Goal:** Sign-constrained glass-box logistic Readiness fusion (separate from Strain-Risk) + flagged Autoregulation swap to (readiness × strain-risk) with ACWR demoted to a context label + ReasoningEngine decision explanation with confidence + PRS-v1 predicting arm added to the shadow harness — ALL behind PRSActivation defaulting FALSE so the live recommendation is byte-identical with the flag off.
**Verified:** 2026-05-31
**Status:** human_needed (all automated must-haves VERIFIED; one planned human visual-review checkpoint remains, deferred by design)
**Re-verification:** No — initial goal-backward verification. (The prior 28-VERIFICATION.md is a build/commit-honesty narrative, not a goal-backward gap report.)

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | PRSActivation master flag defaults FALSE | ✓ VERIFIED | `PRSActivation.swift:34` `static var isEnabled: Bool { _override ?? false }`. Confirmed in committed HEAD (`git show HEAD:...` identical). Test-only `withEnabled` override never called in app code. |
| 2 | Readiness fusion is a pure, sign-constrained, glass-box logistic, SEPARATE from Strain-Risk | ✓ VERIFIED | `ReadinessFusionEngine.swift` — `100·logistic(b0 + Σ wₛ·zₛ)`; weights are FIXED positive named constants (HRV .9, sleep .7, RHR .6, trend .3); intercept 0; no per-user learning; nil-z excluded with proportional renorm (no mean-imputation); confidence reported separately, never folded into scalar. Does not call StrainRiskEngine/RecoveryScoreEngine/AutoregulationEngine. |
| 3 | Flagged Autoregulation swap to (readiness × strain-risk); ACWR demoted to context label | ✓ VERIFIED | `AutoregulationEngine.recommendFlagged` (line 217) guards on `PRSActivation.isEnabled`; flag-off returns legacy `recommend(input:)` verbatim. `recommendReadiness` (line 237) is a full 3×3 readiness×strainRisk matrix; ACWR appears ONLY as `acwrContextLabel` appended to detail (line 333), never in a warning or decision branch. |
| 4 | ReasoningEngine explains the DECISION with ranked, confidence-annotated reasons | ✓ VERIFIED | `ReasoningEngine.explainDecision(input:)` (line 143) — interleaves Readiness factors + Strain-Risk factors ranked by \|contribution\|; carries Readiness confidence; personalized sleep-baseline line. Returns `[DecisionReason]`. |
| 5 | PRS-v1 predicting arm added to shadow harness as 3rd competing arm | ✓ VERIFIED | `ShadowPredictor.registeredArms()` returns `[baseline, cycleAware, prs]` (line 230); `prsPrediction` (line 147) deterministic, leak-free (uses only supplied historical series). `PRSShadowArmTests` asserts arm ids `["baseline","cycleAware","prs"]`. |
| 6 | Live recommendation BYTE-IDENTICAL with flag OFF (machine-locked) | ✓ VERIFIED | `AutoregulationFlagFenceTests.test_flagOff_recommendFlagged_isByteIdenticalToLegacy_fullMatrix` — full RecoveryZone×ACWRZone matrix × fatigue/rest/wellness grid, asserts cap/vol/type/headline/detail/warnings byte-equal at 1e-12. `DualRunFlagFenceTests` — flag-off message nil + adjust no-op (workout byte-unchanged). |
| 7 | Live recovery score BYTE-UNCHANGED (machine-locked) | ✓ VERIFIED | `BaselineTierFenceTests` — source-level grep-gate: `RecoveryScoreEngine.computeBaseline(values:)` still `.suffix(7)` mean (RecoveryScoreEngine.swift:243-244); RecoveryPipeline references none of BaselineEngine/DayBucketer/BaselineState; BaselineEngine standalone. |
| 8 | New SwiftData state local-only / never synced | ✓ VERIFIED | `CyclePredictionLog` is `@Model`, NO Codable; `*PRS` columns (recoveryPRS/wellnessPRS/completionPRS/painPRS) additive; 0 references to CyclePredictionLog in SyncService. `PrescribedWorkout.targetRPE/targetVolume` (lines 26-27) ABSENT from `PrescribedWorkoutRow` Codable DTO (lines 1465-1495). `PRSShadowArmTests` asserts non-Codable + store/read-back. |

**Score:** 8/8 truths verified

### Deferred Items

| # | Item | Addressed In | Evidence |
|---|------|--------------|----------|
| 1 | PRSDualRunCard wired into DashboardView behind the flag | Wave-4 final UI (deferred to main loop) + Phase 29 activation | `PRSDualRunCard` exists and renders only when `dualRunMessage` is non-nil (flag on); NOT referenced in DashboardView. Deferral explicitly stated in phase spec — not a phase blocker. |

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `WorkloadApp/Services/PRSActivation.swift` | Master flag default false | ✓ VERIFIED | 48 lines, real impl, override is test-only |
| `WorkloadApp/Services/ReadinessFusionEngine.swift` | Pure sign-constrained logistic | ✓ VERIFIED | 217 lines, full fusion + zone + factors + confidence |
| `WorkloadApp/Services/AutoregulationEngine.swift` | Flagged swap + ACWR demotion | ✓ VERIFIED | recommendFlagged/recommendReadiness; ACWR context-label only |
| `WorkloadApp/Services/ReasoningEngine.swift` | explainDecision w/ confidence | ✓ VERIFIED | DecisionReason ranking |
| `WorkloadApp/Services/ShadowPredictor.swift` | 3rd PRS arm, shadow-only | ✓ VERIFIED | registeredArms == [baseline, cycleAware, prs] |
| `WorkloadApp/Services/PRSDualRunSurface.swift` | Flag-gated surface + adjust | ✓ VERIFIED | both entry points guard on flag |
| `WorkloadApp/Models/CyclePredictionLog.swift` | Local-only PRS columns | ✓ VERIFIED | @Model, no Codable, *PRS columns |
| `WorkloadApp/Models/PrescribedWorkout.swift` | Local-only target fields | ✓ VERIFIED | targetRPE/targetVolume not in DTO |
| `WorkloadApp/Views/Dashboard/PRSDualRunCard.swift` | Flag-gated renderer | ⚠️ ORPHANED (by design) | Exists, not wired into DashboardView — Wave-4 deferred |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| recommendFlagged | recommend (legacy) | guard PRSActivation.isEnabled | ✓ WIRED | flag-off returns legacy path |
| PRSDualRunSurface.adjust | PrescribedWorkout | flag-gated in-place mutate | ✓ WIRED | no-op when flag off |
| ShadowPredictor prs arm | CyclePredictionLog *PRS / ShadowArmPrediction | registeredArms (unconditional) | ✓ WIRED | flag-independent shadow logging |
| CyclePredictionLog | SyncService | (must be ABSENT) | ✓ CORRECTLY ABSENT | 0 references |
| PrescribedWorkout.targetRPE/Volume | PrescribedWorkoutRow DTO | (must be ABSENT) | ✓ CORRECTLY ABSENT | DTO omits both fields |
| PRSDualRunCard | DashboardView | (deferred) | ⚠️ NOT WIRED (deferred) | Wave-4 UI integration to main loop |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (none) | — | No TODO/FIXME/TBD/XXX/HACK in any new phase-28 file | — | clean |
| ShadowPredictor.swift | 193-198 | Stale doc comment "EXACTLY two arms" while code returns three | ℹ️ Info | Comment is outdated prose; the code (line 230) and the updated `ShadowPredictorTests` arm guard (eb10579) correctly expect 3 arms. No functional impact. |

### Human Verification Required

#### 1. PRS dual-run surface visual review (DEBUG, flag ON)

**Test:** Build DEBUG, enable `PRSActivation`, open Dashboard once the card is wired; inspect the dual-run surface + real-workout adjustment.
**Expected:** Renders both previous + updated recommendation; copy is "Tuwa"-only; never says "injury prediction"; complies with DESIGN.md (0pt corners, no shadows, General Sans, 8pt grid, accent only on hero number).
**Why human:** Visual/design-system compliance is not grep-verifiable. This is the planned Wave-4 human checkpoint, deferred by design — NOT a phase blocker.

### Gaps Summary

No blocking gaps. All four hard invariants hold against committed source (HEAD 90cec6b, on the green chain culminating in eb10579):

- **shadowOff:** Shadow harness is gated — the PRS arm logs unconditionally by design (correct shadow discipline), but it NEVER feeds live output; the live user-facing swap is gated by `PRSActivation.isEnabled` which defaults FALSE.
- **liveUnchanged:** Live recovery score byte-locked by `BaselineTierFenceTests` (`.suffix(7)` intact); live recommendation byte-locked flag-off by `AutoregulationFlagFenceTests` (full matrix) + `DualRunFlagFenceTests`.
- **modelsLocalOnly:** `CyclePredictionLog` (+ `*PRS` columns) and `PrescribedWorkout.targetRPE/targetVolume` are non-Codable / absent from SyncService DTOs — confirmed by source + negative-assertion tests.
- **noLiveActivation:** No arm activated; `PRSActivation.isEnabled` defaults FALSE in committed HEAD; no live-default flip.

The only outstanding item is the deferred Wave-4 DashboardView UI wiring + human visual-review checkpoint, which the phase spec explicitly hands to the main loop. Recorded as deferred + a human-verification item, not a gap. Status is `human_needed` because a human visual checkpoint exists; the phase GOAL itself is fully achieved in code.

---

_Verified: 2026-05-31_
_Verifier: Claude (gsd-verifier)_
