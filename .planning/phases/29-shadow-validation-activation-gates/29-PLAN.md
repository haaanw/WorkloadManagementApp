---
phase: 29-shadow-validation-activation-gates
plan: overview
type: overview
milestone: v1.6 Algorithm Moat (Personal Readiness v1)
waves: 2
serial: true
autonomous: false   # Wave 2 ends in a human review of the shadow-validation report artifact
requirements: [PRS-29-01, PRS-29-02, PRS-29-03]
hard_invariants:
  - "ABSOLUTELY NO live activation. New PRSMasterActivation.isEnabled defaults FALSE and is NOT flipped. PRSActivation + CycleModifierActivation also stay FALSE."
  - "Gate evaluation is computed + REPORTED only. recommendsActivation is report-only and NEVER wired to a flag mutation (isolation grep guard)."
  - "Live recovery score byte-unchanged; RecoveryScoreEngine untouched; BaselineTierFenceTests stays green."
  - "Live user-facing recommendation byte-unchanged with the PRS flag OFF; AutoregulationFlagFenceTests + DualRunFlagFenceTests stay green."
  - "NO new persisted SwiftData model/column (evaluator is pure recompute; report generator is test-target only). Nothing new to sync."
  - "Reuse the EXISTING Phase-24 ShadowMetrics + ShadowAnalyticsService math; add NO new statistics."
  - "Atomic commits to main; no branch; no push; no live-default flip."
  - "Product name Tuwa only. No 'injury prediction' copy (no-prediction-copy grep guard extended to report strings)."
  - "Run FULL WorkloadAppTests after any shared-type change via REAL xcodebuild. Discard .xcstrings churn."
  - "SERIAL waves; no parallel executors."
---

<objective>
Build the activation-gate evaluation layer on top of the already-complete shadow harness, and produce a human-reviewable shadow-validation report artifact — WITHOUT activating anything. Add (1) a NEW master activation flag (`PRSMasterActivation`, default FALSE, stays FALSE), (2) a pure deterministic `ActivationGateEvaluator` that consumes the EXISTING `ShadowAnalyticsService` PRS-vs-baseline metrics and reports whether the four ROADMAP gates pass (MAE beat ≥3/4 with bootstrap CI excl 0; Spearman ≥0.50; calibration slope ∈[0.8,1.2]; data-maturity precondition) — report-only, never flipping a flag, and (3) a seeded deterministic shadow-validation report generator (test target, mirroring Phase-26 convergence report) that drives the harness over synthetic traces, runs the evaluator, emits `29-shadow-validation-report.md`, and machine-asserts the master flag stays FALSE.

Purpose: complete the v1.6 Algorithm Moat milestone's validation discipline — the honest gate that must pass before ANY future live activation — while guaranteeing zero behavior change this phase (every flag FALSE, live recovery + live recommendation byte-identical, no new synced state).

Output: `PRSMasterActivation` flag, `ActivationGateEvaluator` + `GateReport` types, full evaluator oracle/boundary/thin-data test battery, an activation-flag fence test, an evaluator no-mutation isolation grep guard, a seeded shadow-validation report generator, and the `29-shadow-validation-report.md` artifact.
</objective>

<context>
@.planning/research/algorithm-moat-design.md
@.planning/research/competitive-algorithm-analysis.md
@.planning/phases/29-shadow-validation-activation-gates/29-RESEARCH.md
@WorkloadApp/Services/ShadowMetrics.swift
@WorkloadApp/Services/ShadowAnalyticsService.swift
@WorkloadApp/Services/ShadowPredictor.swift
@WorkloadApp/Services/PRSActivation.swift
@WorkloadApp/Services/CycleModifierGate.swift
@WorkloadApp/Models/CyclePredictionLog.swift
@WorkloadAppTests/BaselineConvergenceReportTests.swift
@CLAUDE.md
</context>

<wave_structure>

## SERIAL execution — one wave at a time. Do NOT parallelize.

| Wave | Plan | Concern | Autonomous | Depends on |
|------|------|---------|------------|------------|
| 1 | 29-01-PLAN.md | `PRSMasterActivation` flag (default FALSE) + pure `ActivationGateEvaluator` + `GateReport` types (consumes existing ShadowAnalyticsService metrics; report-only; no flag mutation) + evaluator oracle/boundary/thin-data tests + activation-flag fence test + no-mutation isolation grep + full suite | yes | — |
| 2 | 29-02-PLAN.md | Seeded deterministic shadow-validation report generator (test target; synthetic PRS-wins/loses/thin/ambiguous traces resolved through the real harness path → run evaluator → emit `29-shadow-validation-report.md`) + per-scenario gate-verdict XCTAsserts vs known ground truth + hash-equality + master-flag-stays-FALSE asserts + no-prediction-copy grep + full suite + HUMAN review of the artifact | no (human review) | Wave 1 |

</wave_structure>

<must_haves>
truths:
  - "PRSMasterActivation.isEnabled exists, defaults FALSE, and is asserted FALSE by an activation-flag fence test in BOTH waves."
  - "ActivationGateEvaluator evaluates the four ROADMAP gates from EXISTING ShadowAnalyticsService metric outputs and returns a structured GateReport matching a hand-computed oracle."
  - "The MAE-beat gate counts the 4 continuous outcomes; passes only when PRS beats baseline on ≥3 with the paired-MAE-difference CI upper bound < 0 (PRS error strictly lower)."
  - "Spearman ≥0.50 and calibration slope ∈[0.8,1.2] gates use the FIXED named thresholds and are evaluated on the primary (raw self-report) outcomes."
  - "A data-maturity precondition (n < minResolvedRows OR nil metric) forces recommendsActivation = false with an explicit 'insufficient data' reason."
  - "recommendsActivation is report-only; no source assigns any *Activation.isEnabled (no-mutation isolation grep passes)."
  - "A seeded report generator drives the harness over synthetic traces, runs the evaluator, and emits a byte-reproducible 29-shadow-validation-report.md whose per-scenario gate verdicts match known ground truth (XCTAsserted)."
  - "The report carries a 'NO ACTIVATION THIS PHASE — master flag remains FALSE' banner and no 'injury prediction' copy."
  - "Live recovery score + live recommendation byte-unchanged; BaselineTierFenceTests + AutoregulationFlagFenceTests + DualRunFlagFenceTests green after each wave."
  - "No new persisted SwiftData model/column added; nothing new to sync."
artifacts:
  - path: "WorkloadApp/Services/PRSMasterActivation.swift"
    provides: "NEW master activation flag, default FALSE, stays FALSE this phase"
  - path: "WorkloadApp/Services/ActivationGateEvaluator.swift"
    provides: "Pure deterministic gate evaluation over existing shadow metrics; report-only"
  - path: "WorkloadAppTests/ActivationGateEvaluatorTests.swift"
    provides: "Oracle/boundary/thin-data + activation-flag fence + no-mutation isolation tests"
  - path: ".planning/phases/29-shadow-validation-activation-gates/artifacts/29-shadow-validation-report.md"
    provides: "Human-review deliverable: per-scenario gate panels + NO-ACTIVATION banner"
key_links:
  - from: "ActivationGateEvaluator"
    to: "ShadowAnalyticsService.metricsReport + pairedMAEDifferenceCI"
    via: "consumes existing per-arm metric outputs for armId 'prs' vs 'baseline'"
  - from: "shadow-validation report generator"
    to: "ActivationGateEvaluator + 29-shadow-validation-report.md"
    via: "seeded synthetic traces → real harness resolve → evaluate → String.write"
</must_haves>

<verification>
- Full `WorkloadAppTests` suite green after EACH wave (via real `xcodebuild`, not SourceKit).
- `BaselineTierFenceTests` + `AutoregulationFlagFenceTests` + `DualRunFlagFenceTests` green after each wave.
- Activation-flag fence test green (asserts PRSMasterActivation + PRSActivation + CycleModifierActivation all FALSE).
- `ActivationGateEvaluatorTests` green (oracle, per-gate fail, boundary, thin-data).
- No-mutation isolation grep guard green (evaluator + sources never assign *Activation.isEnabled).
- Hash-equality test green (report byte-reproducible under fixed seed).
- Per-scenario gate-verdict XCTAsserts green (verdict matches known ground truth).
- No-prediction-copy grep guard green (report strings).
- Human reviews `29-shadow-validation-report.md` (Wave 2 checkpoint).
</verification>

<success_criteria>
Both waves committed atomically to main (no push). NO flag flipped — PRSMasterActivation defaults FALSE and stays FALSE. Live recovery score + live recommendation byte-unchanged. Gate-evaluation logic + shadow-validation report artifact delivered. The v1.6 Algorithm Moat milestone's activation gate is built + reported, ready for a FUTURE human-authorized activation decision (out of scope here).
</success_criteria>

<output>
Create `.planning/phases/29-shadow-validation-activation-gates/29-VERIFICATION.md` after Wave 2, plus per-wave SUMMARY entries.
</output>
