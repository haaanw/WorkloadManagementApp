# Phase 28 — Readiness Fusion + Explainable Decisions + ACWR Demotion — RESEARCH

**Status:** Planner research synthesis. No engine code written by this document.
**Date:** 2026-05-30
**Author:** GSD planner (no human discuss-phase available — gray-area decisions recorded inline + in structured output).
**Milestone:** v1.6 Algorithm Moat (Personal Readiness v1).

This document grounds Phase 28 in the LOCKED research (`.planning/research/algorithm-moat-design.md` §2.3/§3/§4 + codex verdict §299-327; `.planning/research/competitive-algorithm-analysis.md` CONVERGED v1 §217-218) and the prior built substrate (Phases 25/26/27). It states what Phase 28 adds, what it must NOT do, and every gray-area assumption with rationale.

---

## 0. One-paragraph scope

Phase 28 adds the **predicting shadow arm (PRS-v1)** of the algorithm moat: a FIXED, sign-constrained, glass-box **logistic fusion** of the Phase-26 prequential personal z-scores into a single **Readiness** scalar (0–100), kept **separate** from the Phase-27 heuristic Strain-Risk channel. It upgrades `ReasoningEngine` to explain the **decision** (not just the recovery score) with ranked personal factors + confidence. It swaps `AutoregulationEngine`'s decision axes from `(recoveryZone × acwrZone)` to `(readinessZone × strainRiskZone)`, demoting ACWR to a context-only label, and surfaces a dual-run "method updated" message. The new recommendation must adjust a REAL logged/planned workout. **Every new behavior ships BEHIND A FLAG defaulting to CURRENT behavior. The predicting arm runs SHADOW-ONLY. With the flag off, the live user-facing recommendation and live recovery score are BYTE-IDENTICAL to today.**

---

## 1. What already exists (prior substrate — do NOT rebuild)

| Artifact | Phase | Role for Phase 28 |
|---|---|---|
| `RecoveryScoreEngine.computeBaseline` (= `.suffix(7)` mean) | live | LIVE baseline. MUST stay byte-unchanged. `BaselineTierFenceTests` machine-locks it. |
| `BaselineEngine` (EWMA/Welford/MAD/Huber, prequential no-leak z + σ floor, Altini CV, 0–1 confidence) | 26 | **Input source** for Readiness z-features. Pure struct, gated OFF. |
| `BaselineState` (@Model, one row, local-only/never-synced) | 26 | Per-day baseline state. Phase 28 reads it (read-only); does NOT add synced fields. |
| `DayBucketer` (median morning window, gap, stale-dedup) | 26 | Upstream day-bucketing for z inputs. |
| `StrengthLoadEngine`, `LoadDistributionEngine`, `StrainRiskEngine` + `StrainRiskZone` | 27 | **Strain-Risk channel** — the SECOND axis of the new matrix. Already display/shadow only, gated OFF. Phase 28 consumes `StrainRiskZone`; does NOT modify these engines' math. |
| `SorenessLog`, `NiggleInjuryDeriver` | 25 | Soft-tissue / outcome substrate. Read-only here. |
| `AutoregulationEngine` (`(recoveryZone × acwrZone)` matrix, cap/volume/sessionType/headline, cycle double-gate) | live | The shell Phase 28 forks behind a flag. LIVE path untouched when flag off. |
| `ReasoningEngine.summarize` (ranked recovery factors, fixed 7h sleep target) | live | Augmented (additively) to explain the decision. LIVE call path unchanged when flag off. |
| `WorkloadCalculator` (sessionTSS, sRPE, TRIMP, EWMA ATL/CTL, **acwr**, spike) | live | ACWR stays COMPUTED for continuity; Phase 28 only reclassifies it as context-label in the NEW (flagged) path. |
| `ShadowPredictor` / `ShadowAnalyticsService` / `CyclePredictionLog` (Phase 24 upgraded: predictionDate/targetDate/cutoff/window, calibration + Spearman + blocked CV) | 24 | The harness Phase 28 extends with the PRS-v1 predicting arm. |

---

## 2. What Phase 28 ADDS (the ROADMAP Phase 28 spec, decomposed)

1. **`ReadinessFusionEngine`** — NEW pure struct, static methods. Fixed sign-constrained glass-box logistic over named Phase-26 z-features → Readiness scalar (0–100) + `ReadinessZone` enum + ranked contributing factors + confidence. Coefficients are FIXED, sign-locked, bundled population priors (NOT per-user learned — codex CRITICAL #2, locked). Separate output from Strain-Risk.
2. **`ReasoningEngine` decision-explanation upgrade** — additive: a new entry point that explains the DECISION (e.g. "volume cut because HRV −x%, sleep debt, high per-muscle hard sets, no rest day") with confidence, fed by Readiness factors + Strain-Risk ranked factors. Existing `summarize` signature preserved.
3. **`AutoregulationEngine` matrix swap (FLAGGED)** — new `recommend` path keyed on `(readinessZone × strainRiskZone)`; ACWR removed from the new decision/warnings and emitted only as a context label. Old `(recoveryZone × acwrZone)` path retained as the DEFAULT when flag off.
4. **Dual-run + "method updated" messaging** — a user-facing copy surface (FLAGGED for human visual review; visuals NOT final) that, when the new method is active, explains the recommendation method changed and shows both during a dual-run window.
5. **Recommendation adjusts a REAL logged/planned workout** — the new recommendation path applies to an actual planned/logged session (volume %, RPE cap), not a hypothetical — wired in the flagged path only.
6. **PRS-v1 predicting arm in the shadow harness** — `ShadowPredictor` emits a third competing prediction (PRS Readiness) alongside baseline/cycle-aware; `CyclePredictionLog` gains parallel `*PRS` fields; `ShadowAnalyticsService` reports PRS metrics. Shadow-only, never user-facing.

---

## 3. HARD INVARIANTS this phase MUST enforce (from task brief + memory)

1. **Master/feature flag defaults to CURRENT behavior.** Readiness path + AutoregulationEngine swap are behind a flag defaulting FALSE. No live default flipped.
2. **Live recovery score BYTE-UNCHANGED.** `RecoveryScoreEngine.computeBaseline` = `.suffix(7)` mean; `BaselineTierFenceTests` stays green. Phase 28 does NOT touch `RecoveryScoreEngine` internals.
3. **Predicting arm = SHADOW ONLY.** PRS Readiness never reaches the live user-facing recommendation while the flag is off.
4. **New SwiftData state (if any) is local-only / never-synced** — no Codable-sync, absent from `SyncService`. (Phase 28 prefers PURE recompute with NO new persisted model — see assumption GA-7.)
5. **Atomic commits directly to `main`. No new branch. No push. No live-default flip.**
6. **Product name "Tuwa"** in all user-facing copy. Never Faros/Tonus/Tutrice.
7. **DESIGN.md** for any UI/copy change (0pt corners, no shadows, General Sans, 8pt grid, accent only on hero number) — and FLAG all visuals for human review (NOT final).
8. **After any shared-type/enum change run the FULL WorkloadAppTests suite**, not just new tests.
9. **SERIAL waves**, one at a time. No self-branching parallel executors. Discard `.xcstrings` churn before commit.

---

## 4. Gray-area decisions (no human discuss-phase) — recorded with rationale

- **GA-1 — Readiness is a SEPARATE scalar from Strain-Risk (two channels).** Rationale: locked research §2.3(B) + §138 + competitive §189 strongly recommend two channels; a recovered athlete carrying dangerous load is the most important case to surface and a blend hides it. Codex retained "two channels" as a locked product decision (§325).
- **GA-2 — FIXED sign-constrained coefficients, bundled as population priors; NO per-user weight learning.** Rationale: codex CRITICAL #2 (§305) — per-user logistic weights on ~60 days of autocorrelated consumer data are statistically bogus. Coefficients are named constants in the engine, sign-locked (HRV/sleep positive-is-good, RHR/temp inverted), grouped for correlated channels.
- **GA-3 — `ReadinessZone` is a NEW 3-level enum (e.g. low / moderate / high) mirroring `RecoveryZone` granularity** so the `(readinessZone × strainRiskZone)` matrix has the same shape discipline as the existing `(recoveryZone × acwrZone)` matrix. Rationale: minimal new surface, reuses matrix-authoring pattern, keeps explainability tractable. Thresholds are FIXED named constants.
- **GA-4 — ACWR stays COMPUTED (`WorkloadCalculator.acwr` untouched) but is reclassified to a context-label string in the NEW flagged path only.** Rationale: research §3 + §180 "keep computed for continuity, demote in decision"; competitive CHANGE 2. The LIVE path keeps ACWR exactly as-is.
- **GA-5 — The AutoregulationEngine swap is implemented as a NEW method/branch selected by the flag, NOT an in-place rewrite of the existing matrix.** Rationale: guarantees byte-identical live behavior when flag off; the existing `(recoveryZone × acwrZone)` code path is left untouched.
- **GA-6 — Single master flag (`PRSActivation.isEnabled`, default false) gates BOTH the Readiness/Autoregulation swap AND any user-visible "method updated"/dual-run copy. The PRS predicting arm in the shadow harness runs UNCONDITIONALLY (shadow logging only, no user-facing effect), mirroring the existing Phase-20/24 shadow-log discipline.** Rationale: research §219 "PRS gets its own master activation flag, defaults false"; shadow logging must collect data even before activation (that is the whole point of the gate in Phase 29). The flag controls ONLY the live user-facing swap.
- **GA-7 — Phase 28 adds NO new persisted SwiftData model.** `ReadinessFusionEngine` is pure recompute from existing `BaselineState` + Phase-27 engine outputs + live inputs; the shadow arm writes to the EXISTING `CyclePredictionLog` (new local-only `*PRS` columns, never-synced, mirroring its current never-synced posture). Rationale: matches Phase-27's "StrengthLoadState SKIPPED (pure recompute)" precedent (D-27-02); minimizes schema/sync risk; honors local-only invariant. If a new column on `CyclePredictionLog` is required, it MUST be local-only and absent from any sync mapping.
- **GA-8 — Dual-run "method updated" copy is built per DESIGN.md but FLAGGED for human visual review (visuals NOT final), and only renders when the master flag is on.** Rationale: task brief phase-specific invariant; with flag off (default) it is invisible, so live UI is unchanged.
- **GA-9 — "Adjust a real logged/planned workout" = the flagged recommendation path applies its volume%/RPE-cap to an actual `PrescribedWorkout`/planned session if present, else to the next logged session context; it does NOT fabricate a workout.** Rationale: competitive CONVERGED v1 §218 "modifies a real logged/planned workout"; keeps the claim honest without a generator (out of scope for v1).
- **GA-10 — Strain-Risk math (Phase 27 engines) is consumed AS-IS; Phase 28 does not re-tune it.** Rationale: Phase 27 is DONE + tier-fence green; re-tuning is out of scope and would risk the fence.
- **GA-11 — Copy never says "injury prediction"; Strain-Risk framed as load-tolerance / overreaching-caution context.** Rationale: research §235 + competitive §174/§218 honesty guardrail; a `no-prediction-copy` grep guard already exists from Phase 27 and is extended to new copy.

---

## 5. Validation / verification strategy

- **Tier fence:** `BaselineTierFenceTests` MUST stay green after every wave (live 7-day mean unchanged). Run FULL suite after enum/shared-type changes.
- **Byte-identical-with-flag-off test (NEW, machine-enforced):** a test asserts that with `PRSActivation.isEnabled == false`, `AutoregulationEngine.recommend(...)` returns output identical to the pre-Phase-28 path for a fixed battery of inputs (golden snapshot). This is the central gating guard.
- **Engine numerics tests:** `ReadinessFusionEngine` validated against a hand-computed oracle (fixed coefficients → known logistic output), sign-constraint asserts (increasing a positive-is-good z never decreases Readiness; increasing an inverted signal never increases it), zone-threshold boundary tests, confidence monotonicity.
- **Isolation grep guard:** the new Readiness path must not be referenced from the LIVE (flag-off) call sites; a grep test asserts the new engine is only reached behind the flag or in shadow.
- **No-prediction-copy grep guard:** extend Phase-27 guard to new copy strings.
- **Shadow arm:** PRS prediction is written with correct predictionDate/targetDate/cutoff/window (Phase-24 contract), resolved against RAW self-report/soreness/adherence labels (never engine-derived recovery — codex §315). No new activation gate logic here (that is Phase 29).

---

## 6. Out of scope (explicit)

- Kalman baselines, per-user Q/R, per-user weight learning (deferred — codex §326).
- Flipping any live default / activating PRS (Phase 29 only, after gates pass).
- Workout generation (only adjustment of existing planned/logged workout).
- Re-tuning Phase-27 Strain-Risk math.
- Final UI visuals (flagged for human review).
- New synced SwiftData fields.
