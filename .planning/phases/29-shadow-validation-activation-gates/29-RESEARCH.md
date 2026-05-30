# Phase 29 — Shadow Validation + Activation Gates — RESEARCH

**Status:** Planner research synthesis. No engine code written by this document.
**Date:** 2026-05-31
**Author:** GSD planner (no human discuss-phase available — gray-area decisions recorded inline + in structured output).
**Milestone:** v1.6 Algorithm Moat (Personal Readiness v1) — the FINAL phase of the milestone.

This document grounds Phase 29 in the LOCKED research (`.planning/research/algorithm-moat-design.md` §4 "Validation plan" + §4.3 "Success metrics & gates" + §4.4 "Phased activation" + codex verdict §299-327; `.planning/research/competitive-algorithm-analysis.md` CHANGE 4 §154 + CONVERGED v1 §218) and the prior built substrate (Phases 24–28). It states what Phase 29 adds, what it must NOT do, and every gray-area assumption with rationale.

---

## 0. One-paragraph scope

Phase 29 builds the **activation-gate evaluation layer** on top of the already-complete shadow harness, and produces a **shadow-validation report artifact** — and does **NOTHING ELSE**. It does **NOT** activate anything. The Phase-28 PRS-v1 predicting arm is already logging unconditionally into `CyclePredictionLog`; the Phase-24 `ShadowMetrics` + `ShadowAnalyticsService` already compute MAE, calibration slope, Spearman ρ, blocked/purged CV, and the block-bootstrap paired-MAE-difference CI. Phase 29 adds (a) a **pure deterministic `ActivationGateEvaluator`** that consumes those existing metric outputs and decides — *report-only* — whether the four activation gates pass for the PRS arm vs the current/baseline arm, and (b) a **master activation flag that DEFAULTS FALSE and is NOT flipped this phase**, plus (c) a **seeded deterministic shadow-validation report generator** (test target, mirroring the Phase-26 convergence-report precedent) that drives the harness over synthetic prediction traces, runs the evaluator, emits a markdown artifact, and machine-asserts that the master activation flag stays FALSE and no live default flips. **Wires + evaluates only. Does NOT activate. The master activation flag defaults FALSE and stays FALSE.**

---

## 1. What already exists (prior substrate — do NOT rebuild)

| Artifact | Phase | Role for Phase 29 |
|---|---|---|
| `ShadowMetrics` (pure: `calibrationSlope`, `spearmanRho`, `blockedCVSplits`, `pairedMAEDifferenceBlockBootstrapCI`, `SplitMix64`) | 24 | **All gate math already exists.** Phase 29 consumes it; does NOT add new statistics. |
| `ShadowAnalyticsService.metricsReport(resolvedRows:armId:)` → per-outcome `OutcomeMetrics{ n, mae, calibrationSlope, spearmanRho, engineDerived }` | 24 | Per-arm per-outcome metric extraction. The evaluator consumes this for the PRS arm. |
| `ShadowAnalyticsService.pairedMAEDifferenceCI(resolvedRows:outcome:armA:armB:...)` → `(lower, upper, point)?` | 24 | The bootstrap CI for the MAE-beat gate (PRS vs baseline). The evaluator consumes this per outcome. |
| `ShadowAnalyticsService.aggregate(resolvedRows:)` → per-outcome `OutcomeMAE{ baselineMAE, cycleAwareMAE, prsMAE?, n }` | 24/28 | Convenience MAE comparison; `prsMAE` already plumbed. |
| `ShadowPredictor.Outcome` (`.recovery` engine-derived/secondary; `.wellness`, `.completion`(adherence), `.pain` raw self-report; `.niggleSeverity` no arm predicts in v1) + `engineDerivedOutcomes = [.recovery]` | 24/25 | The outcome set + which labels are gating vs secondary. **The MAE-beat "3/4 outcomes" gate uses the 4 CONTINUOUS outcomes, excluding `.niggleSeverity` (no arm predicts it) — see GA-2.** |
| `ShadowPredictor.prsPrediction` + `registeredArms()` includes the `"prs"` arm (UNCONDITIONAL, shadow-only) | 28 | The PRS-v1 arm being evaluated. Phase 29 does NOT modify it. |
| `CyclePredictionLog` + local-only never-synced `*PRS` columns + generic `ShadowArmPrediction` store | 24/28 | The resolved-row store the evaluator reads. Phase 29 adds NO new column / NO new model. |
| `PRSActivation.isEnabled` (default false, gates ONLY the live user-facing swap; shadow arm runs regardless) | 28 | The LIVE swap flag. Phase 29 does NOT flip it; the NEW master activation flag is a SEPARATE, also-false gate (see GA-1). |
| `CycleModifierActivation.isEnabled = false` + `CycleModifierGate` (the single reusable evidence-gate pattern) | 20 | **The precedent for Phase 29's gate-evaluator + activation-flag-defaults-false discipline.** Mirror this posture exactly. |
| `BaselineConvergenceReportTests` (seeded deterministic report generator + invariant asserts + hash-equality + markdown artifact write) | 26 | **The precedent for Phase 29's shadow-validation report generator.** Mirror this structure exactly. |
| `BaselineTierFenceTests`, `AutoregulationFlagFenceTests`, `DualRunFlagFenceTests` | 26/28 | The machine-locks for live recovery score + live recommendation byte-identity. MUST stay green. |

---

## 2. What Phase 29 ADDS (the ROADMAP Phase 29 spec, decomposed)

The ROADMAP Phase 29 bullet: *"run PRS-v1 arm in shadow vs current algorithm; gates: MAE beat on ≥3/4 outcomes (bootstrap CI excl 0), Spearman ≥0.50, calibration slope ∈[0.8,1.2]; no live activation until gates pass; master activation flag defaults false."*

1. **`PRSMasterActivation` flag (NEW)** — a master activation flag, separate from `PRSActivation`, that DEFAULTS FALSE and stays FALSE this phase. It represents the milestone-level "the gates passed and we chose to go live" switch. Phase 29 creates it as the single named place where activation authority will eventually live, asserts it false, and does NOT flip it. (See GA-1 for why this is separate from `PRSActivation`.)
2. **`ActivationGateEvaluator` (NEW pure struct, static methods)** — consumes the EXISTING `ShadowAnalyticsService` metric outputs for the PRS arm (vs the baseline arm) and evaluates the four activation gates, returning a structured `GateReport` (per-gate PASS/FAIL + per-gate evidence + overall pass) and a `recommendsActivation` boolean. **It NEVER flips any flag; it only reports.** The four gates (research §4.3):
   - **G-MAE** — PRS MAE beats the baseline arm on **≥3 of the 4 continuous outcomes** (`.recovery`, `.wellness`, `.completion`, `.pain`), each with a block-bootstrap paired-MAE-difference CI that **excludes 0** in PRS's favor (point < 0, i.e. PRS error lower; upper bound < 0). `.recovery` is `engineDerived`/secondary but is one of the 4 counted continuous outcomes per the ROADMAP "3/4" wording (GA-2 records the honest caveat).
   - **G-SPEARMAN** — PRS Spearman ρ(predicted, actual) **≥ 0.50** on the primary (raw self-report) outcomes (GA-3 selects which).
   - **G-CALIBRATION** — PRS calibration slope **∈ [0.8, 1.2]** on the primary outcomes (GA-3).
   - **G-DATA-MATURITY** — sufficient resolved rows before any gate is even *eligible* to pass (research §4.3 "no per-user weight tuning until ≥ N resolved prediction rows (suggest ≥60 days)"; codex CRITICAL #3/#4: thin data ⇒ metrics are `nil`/unstable). Implemented as a hard precondition: if `n < minResolvedRows`, the evaluator returns `recommendsActivation = false` with reason "insufficient data" REGARDLESS of the other gates (GA-4).
3. **Seeded deterministic shadow-validation report generator (NEW, test target)** — mirrors `BaselineConvergenceReportTests`: builds synthetic prediction/outcome traces with KNOWN ground truth (PRS-clearly-wins, PRS-clearly-loses, thin-data, ambiguous/straddles-zero), resolves them through the real harness path, runs `ActivationGateEvaluator`, emits `.planning/phases/29-shadow-validation-activation-gates/artifacts/29-shadow-validation-report.md`, and machine-asserts (XCTAssert, not just print): each scenario's gate verdict matches the known ground truth; the report is byte-reproducible (hash-equality under fixed seed); `PRSMasterActivation.isEnabled == false`; `PRSActivation.isEnabled == false`; live tier/flag fences green.
4. **`29-shadow-validation-report.md` artifact** — the human-review deliverable: per-scenario gate panels (MAE-beat count + per-outcome CI, Spearman, calibration slope, n / data-maturity) + overall PASS/FAIL + an explicit "NO ACTIVATION — flag remains FALSE" banner.

---

## 3. HARD INVARIANTS this phase MUST enforce (from task brief + memory)

1. **ABSOLUTELY NO live activation.** No flag flipped to true. The NEW `PRSMasterActivation.isEnabled` defaults FALSE and stays FALSE; `PRSActivation.isEnabled` stays FALSE; `CycleModifierActivation.isEnabled` stays FALSE. Gate evaluation is computed + reported ONLY.
2. **Live recovery score BYTE-UNCHANGED.** `BaselineTierFenceTests` (machine-locks `RecoveryScoreEngine.computeBaseline` = `.suffix(7)` mean) MUST stay green. Phase 29 does NOT touch `RecoveryScoreEngine`.
3. **Live user-facing recommendation BYTE-UNCHANGED with the PRS flag OFF.** `AutoregulationFlagFenceTests` + `DualRunFlagFenceTests` MUST stay green. Phase 29 does NOT touch `AutoregulationEngine` live path.
4. **All new SwiftData models / columns local-only / never-synced.** Phase 29 PREFERS to add NO new persisted model (the evaluator is pure recompute over existing resolved rows; the report generator is test-target only). If any state were added it MUST be absent from `SyncService` and non-Codable-sync. (GA-5: no new model.)
5. **Atomic commits directly to `main`. No new branch. NEVER push to origin. NEVER flip a live default.**
6. **Product name "Tuwa"** in all user-facing copy. Never Faros/Tonus/Tutrice. (Report artifact + any copy.)
7. **DESIGN.md** for any UI change — but Phase 29 adds NO UI (gate eval + report artifact only; the report is a markdown file, not an app screen). GA-6.
8. **After any shared-type/enum change run the FULL WorkloadAppTests suite**, not just new tests. Discard `.xcstrings` churn before commit.
9. **SERIAL waves**, one at a time. No self-branching parallel executors.

---

## 4. Gray-area decisions (no human discuss-phase) — recorded with rationale

- **GA-1 — Phase 29 introduces a NEW `PRSMasterActivation` flag, SEPARATE from the Phase-28 `PRSActivation`.** Rationale: research §219 / §4.4 describes a "master activation flag" that flips *only on evidence after gates pass* — a milestone-level decision, distinct from the Phase-28 `PRSActivation` which is the engineering swap gate. Keeping them separate makes the activation-authority surface (research Open Q6) explicit and auditable, and lets the evaluator's `recommendsActivation` be checked against the master flag without overloading the existing flag's meaning. Both default FALSE; Phase 29 flips NEITHER. (Alternative considered: reuse `PRSActivation` — rejected because it conflates "code path enabled for testing" with "gates passed, go live", muddying the no-activation invariant.)
- **GA-2 — The MAE-beat "≥3/4 outcomes" gate counts the FOUR CONTINUOUS outcomes `.recovery`, `.wellness`, `.completion`, `.pain` (NOT `.niggleSeverity`, which no v1 arm predicts).** Rationale: ROADMAP says "≥3/4 outcomes"; the harness has exactly four continuous outcomes that arms predict (`.niggleSeverity` is `nil` for all arms per Phase-25 D-04, so it cannot participate in a paired comparison). `.recovery` is `engineDerived`/circular (codex §315) — the evaluator INCLUDES it in the count to honor the literal "3/4" but TAGS it `engineDerived` in the report and additionally reports the "raw-self-report-only" sub-count (3 raw outcomes) so the human reviewer sees both. The gate threshold remains "≥3 of 4" per the ROADMAP; the honesty caveat is surfaced, not silently changed.
- **GA-3 — Spearman ≥0.50 and calibration-slope ∈[0.8,1.2] gates are evaluated on the PRIMARY (raw self-report) outcomes `.wellness`, `.completion`, `.pain` and must hold for the AGGREGATE/representative outcome the report names; the evaluator computes them per-outcome and the gate passes when the designated primary outcome(s) clear the threshold.** Rationale: research §4.3 ties Spearman/calibration to "Readiness predicts next-day state" against real outcomes; codex §315 forbids leaning on the engine-derived `.recovery` label. Concretely: the evaluator reports Spearman + calibration for ALL outcomes but the GATE verdict is keyed on the raw self-report outcomes (a conservative "all designated primaries must clear" or a named-primary rule — the executor picks the simplest defensible rule and documents it; default: gate passes if the primary outcome `.wellness` clears AND no primary outcome with sufficient n is worse than the threshold). Thresholds are FIXED named constants exactly as the ROADMAP states (0.50; [0.8,1.2]).
- **GA-4 — A data-maturity precondition gates ALL other gates.** Rationale: research §4.3 "no per-user weight tuning until ≥ N resolved prediction rows (suggest ≥60 days)"; codex CRITICAL #3 (harness math undefined on thin data) + #4 (rare-event/`nil` metrics). If `n < minResolvedRows` (named constant; default 60 per research) OR a gate's metric is `nil` (insufficient/degenerate data → `ShadowMetrics` returns nil), that gate is treated as NOT PASSED and `recommendsActivation = false` with an explicit "insufficient data" reason. This makes the evaluator honest about thin consumer data instead of fabricating a pass.
- **GA-5 — Phase 29 adds NO new persisted SwiftData model or column.** Rationale: the evaluator is pure recompute over EXISTING resolved `CyclePredictionLog` rows; the report generator is test-target only (writes a markdown file, no SwiftData). Mirrors Phase-27 "StrengthLoadState SKIPPED (pure recompute)" + Phase-26 convergence-report (test-only) precedents; honors the local-only/never-synced invariant trivially (nothing new to sync). A sync-omission test is therefore N/A; instead the report generator asserts no new `@Model` was introduced is unnecessary — the file-ownership in `files_modified` proves it.
- **GA-6 — Phase 29 adds NO app UI.** Rationale: the ROADMAP Phase 29 spec is "gate-evaluation logic + a shadow validation report artifact" — both are non-UI (a pure engine + a generated markdown file). The human-review deliverable is the markdown artifact, reviewed like the Phase-26 convergence report, NOT an in-app screen. No DESIGN.md surface is touched. (Any future "show the user their gate status" screen is out of scope / a later phase.)
- **GA-7 — The evaluator's `recommendsActivation` is REPORT-ONLY and is NEVER wired to any flag mutation.** Rationale: the no-activation invariant is absolute. The evaluator returns a boolean recommendation; NO code reads that boolean to set `PRSMasterActivation.isEnabled` (or any other flag). A grep/isolation guard asserts the evaluator's output does not feed any `isEnabled =` assignment. Activation authority (research Open Q6) is deferred — a human flips the master flag in a FUTURE phase after reviewing the report.
- **GA-8 — Gate thresholds are FIXED named constants on `ActivationGateEvaluator`, matching the ROADMAP verbatim** (MAE-beat ≥3/4 with bootstrap CI upper-bound < 0; Spearman ≥ 0.50; calibration slope ∈ [0.8, 1.2]; minResolvedRows = 60). Rationale: research §4.3 specifies these consumer-scaled thresholds; the ROADMAP locks them; named constants make them auditable + testable against an oracle.
- **GA-9 — The block-bootstrap CI used for G-MAE reuses `ShadowAnalyticsService.pairedMAEDifferenceCI` with `armA = "prs"`, `armB = "baseline"` (the "current algorithm" baseline arm).** Rationale: research §4.1 "The 'current algorithm' is the baseline arm; PRS must beat it." The CI excludes 0 in PRS's favor when the difference `d = |err_prs| - |err_baseline|` has an upper CI bound < 0 (PRS error strictly lower). The existing function computes `d = err_armA - err_armB`, so with `armA="prs"`, `armB="baseline"`, "PRS wins" ⇔ `upper < 0`. The evaluator documents this sign convention explicitly.
- **GA-10 — The report artifact carries an explicit, unmissable "NO ACTIVATION THIS PHASE — master flag remains FALSE" banner regardless of whether the synthetic scenarios show a pass.** Rationale: the report demonstrates the *machinery* on synthetic data; a synthetic "PASS" must NEVER be mistaken for an authorization to go live. The banner + the machine-asserted `isEnabled == false` make the no-activation invariant legible to the human reviewer.

---

## 5. Validation / verification strategy

- **Tier/flag fences:** `BaselineTierFenceTests`, `AutoregulationFlagFenceTests`, `DualRunFlagFenceTests` MUST stay green after every wave (live recovery + live recommendation byte-unchanged). Run FULL suite after enum/shared-type changes.
- **Activation-flag fence (NEW, machine-enforced):** a test asserts `PRSMasterActivation.isEnabled == false` AND `PRSActivation.isEnabled == false` AND `CycleModifierActivation.isEnabled == false` — the no-activation invariant as code. This test MUST exist and pass in BOTH waves.
- **Evaluator oracle tests:** `ActivationGateEvaluator` validated against hand-constructed metric inputs with KNOWN gate verdicts — clear-pass, clear-fail-on-each-gate, thin-data (n < min → fail), boundary (Spearman exactly 0.50, slope exactly 0.8/1.2, CI upper exactly 0). Deterministic, pure.
- **No-mutation / isolation grep guard (NEW):** a grep test asserts `ActivationGateEvaluator` contains no `isEnabled =` / `.isEnabled =` assignment and that no source file assigns `PRSMasterActivation.isEnabled` to anything but its `false` default (GA-7). Proves the evaluator cannot flip a flag.
- **Seeded report generator:** mirrors `BaselineConvergenceReportTests` — fixed `ShadowMetrics.SplitMix64(seed:)` for any synthetic noise; synthetic dates from a fixed anchor; hash-equality test proves byte-reproducible markdown; the report's per-scenario gate verdicts are XCTAsserted against known ground truth (not just printed); the artifact is written with a temp-dir fallback so sandboxed CI never hard-fails.
- **No-prediction-copy grep guard:** extend the existing Phase-27/28 guard to the report copy strings (no "injury prediction" language; Strain-Risk framed as load-tolerance/overreaching context).
- **Full suite green via REAL xcodebuild** (not SourceKit) after EACH wave — authoritative command (from inside `workload management/`):
  `xcodebuild test -project "workload management.xcodeproj" -scheme "workload management" -destination 'platform=iOS Simulator,id=<known-alive-sim-id>' -only-testing:WorkloadAppTests`

---

## 6. Out of scope (explicit)

- **ANY live activation** / flipping any flag to true (deferred to a FUTURE phase, after human review of the report — research Open Q6).
- Per-user weight learning, Kalman baselines (deferred — codex §326; not this milestone).
- New synced SwiftData fields / new persisted models (GA-5).
- New app UI / DESIGN.md surfaces (GA-6).
- Re-tuning Phase-26/27/28 engine math (Strain-Risk, Readiness fusion, baselines) — consumed as-is.
- New statistics in `ShadowMetrics` (all gate math already exists — Phase 24).
- Real-device shadow-data collection / longitudinal user validation (the report demonstrates the machinery on synthetic + any available real resolved rows; field validation is operational, not a build deliverable).
