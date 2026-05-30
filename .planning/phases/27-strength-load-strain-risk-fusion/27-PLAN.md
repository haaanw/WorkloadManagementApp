---
phase: 27-strength-load-strain-risk-fusion
plan: overview
type: overview
milestone: v1.6 Algorithm Moat (Personal Readiness v1)
depends_on: [25-soreness-tweak-self-log, 26-individualized-baselines]
waves: 3
autonomous: true
---

# Phase 27 — Strength-load model + Strain-Risk fusion (heuristic channel)

## Phase goal (from ROADMAP)

Build the strength-load model (per-muscle HARD SETS + relative-intensity buckets via
est-1RM / RPE / RIR derived from `SetRecord`/`ExerciseEntry`, **NOT raw tonnage**) and
fuse it with sRPE/TRIMP endurance load + `FatigueIndexEngine` (FEA lineage) + Foster
monotony/strain (**completeness-gated**) into the **Strain-Risk** channel — output as an
**honest heuristic flag** ("load-tolerance context / overreaching caution"), **NEVER
"injury prediction"**. Strain-Risk in v1 is a HEURISTIC flag, NOT the logistic fusion
(that is Readiness, Phase 28). Consumes Phase 25 (`SorenessLog`/`NiggleInjuryDeriver`)
and Phase 26 (`BaselineState`/`BaselineEngine`). Pure structs for engines; any per-day
state in a local-only never-synced model.

## HARD INVARIANTS (violation = HALT)

1. Shadow harness stays gated OFF. No live activation of any new arm. No master flag flipped.
2. Live recovery score BYTE-UNCHANGED — `BaselineTierFenceTests` MUST stay green;
   `RecoveryScoreEngine.computeBaseline` is NOT touched.
3. Strain-Risk is display/shadow context only this phase — it MUST NOT alter the live
   `AutoregulationEngine` recommendation or the recovery score.
4. Any new SwiftData model is local-only / never-synced (no Codable-sync, absent from `SyncService`).
5. New engines are pure structs with static methods, deterministic, Foundation-only.
6. Atomic commits directly to `main`. NO new branch. NEVER push to origin. NEVER flip a live default.
7. Run waves SERIAL. After any shared-type/enum change, run the FULL `WorkloadAppTests`
   suite (not just new tests). Discard `.xcstrings` build-churn before committing. Stale
   SourceKit diagnostics are not authoritative — only an `xcodebuild` run proves green.
8. Product name is "Tuwa". NEVER use "Faros"/"Tonus"/"Tutrice" in any user-facing copy.

## Wave structure (SERIAL — one at a time)

| Wave | Plan | Concern | Autonomous | Depends on |
|------|------|---------|------------|------------|
| 1 | 27-01-PLAN.md | `StrengthLoadEngine` (est-1RM Epley, rel-intensity buckets, RIR bridge, per-muscle hard sets + elevation + same-region recurrence) + optional local-only `StrengthLoadState` | yes | Phase 22 (MuscleGroup), Phase 26 |
| 2 | 27-02-PLAN.md | `LoadDistributionEngine` — unified daily-load series + Foster monotony/strain, completeness-gated with heuristic fallback | yes | Wave 1 |
| 3 | 27-03-PLAN.md | `StrainRiskEngine` fixed glass-box fusion — score + zone + ranked factors + confidence; reuses FatigueIndexEngine + NiggleInjuryDeriver + BaselineEngine; tier-fence + full-suite + no-prediction-copy guards | yes | Waves 1+2 |

All three waves are `autonomous: true` (no human checkpoint — this is engine substrate,
no UI). Run strictly serially per the parallel-executor collision gotcha.

## Source coverage audit

| Source item | Type | Covered by |
|-------------|------|-----------|
| ROADMAP P27: per-muscle hard sets + rel-intensity buckets (est-1RM/RPE/RIR, not tonnage) | GOAL | 27-01 |
| ROADMAP P27: fuse sRPE/TRIMP + FatigueIndexEngine + Foster monotony/strain (completeness-gated) | GOAL | 27-02 + 27-03 |
| ROADMAP P27: output honest heuristic Strain-Risk flag, never injury prediction | GOAL | 27-03 |
| ROADMAP P27: consumes Phase 25 SorenessLog/NiggleInjuryDeriver | GOAL | 27-03 |
| ROADMAP P27: consumes Phase 26 BaselineState/BaselineEngine | GOAL | 27-01 + 27-03 |
| moat-design §2.3(B): Strain-Risk = separate channel, FEA + monotony + soft-tissue + cascade | RESEARCH | 27-03 |
| moat-design §2.6: Foster monotony/strain with RPE-completeness gate + fallback | RESEARCH | 27-02 |
| moat-design §5.2: same-region recurrence cascade generalization (no tendon-specific claim) | RESEARCH | 27-01 + 27-03 |
| codex §301/§318: fixed sign-constrained glass-box, NO logistic, NO per-user fit | RESEARCH | 27-03 |
| codex §307/§4: NO injury AUC gate this phase; framed as context flag | RESEARCH | 27-03 (and deferred to P29) |
| competitive §3.1: strength-load is the structural moat — lean hard on it | RESEARCH | 27-01 |
| D-27-01..D-27-08 (planner gray-area decisions) | CONTEXT | 27-RESEARCH.md §7 + per-wave plans |

No unplanned items. Logistic Readiness fusion, ACWR demotion, AutoregulationEngine
matrix swap, and shadow validation/activation gates are explicitly **out of scope**
(Phases 28 + 29).

## Output

Per-wave SUMMARY files: `27-0N-SUMMARY.md`. Phase verification: `27-VERIFICATION.md`.
