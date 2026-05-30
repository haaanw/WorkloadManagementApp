# Phase 27 Research — Strength-load model + Strain-Risk fusion (heuristic channel)

**Date:** 2026-05-30
**Status:** Locked planning research. No human discuss-phase was available; gray-area
decisions were made by the planner from the locked research and recorded in this file
(see §7) and in the structured planning output.
**Sources read:** `.planning/research/algorithm-moat-design.md` (esp. §1.3 FatigueIndex,
§2.3 Layer-3 Strain-Risk, §2.6 Foster monotony/strain, §5 risk+honesty, and the
**codex adversarial review §299–327**), `.planning/research/competitive-algorithm-analysis.md`
(§3.1 strength-training structural moat), ROADMAP Phase 27 bullet, Phase 25/26 substrate.

---

## 0. One-paragraph thesis for this phase

Phase 27 builds the **strength-load model** (per-muscle hard sets + relative-intensity
buckets from `SetRecord`/`ExerciseEntry`, derived via est-1RM / RPE / RIR — **never raw
tonnage**) and fuses it with the existing endurance load (sRPE/TRIMP), the FEA-lineage
`FatigueIndexEngine`, the Phase-25 soft-tissue memory (`NiggleInjuryDeriver`), the
Phase-26 individualized baselines (`BaselineEngine`/`BaselineState`), and a
**completeness-gated** Foster monotony/strain primitive — into a single **Strain-Risk
channel**. Per the codex verdict, Strain-Risk in v1 is an **honest heuristic flag**
("load-tolerance context / overreaching caution"), **not** the logistic fusion (that is
Readiness, Phase 28) and **never** "injury prediction". Everything is gated OFF, pure +
deterministic, and must NOT touch the live recovery score or live AutoregulationEngine
recommendation this phase.

---

## 1. What the codex verdict bounds (the hard scope fence)

From `algorithm-moat-design.md` §299–327 (codex adversarial review, the authoritative
v1 scope):

- **Strain-Risk in v1 = heuristic flag, NOT a fitted model.** "FIXED sign-constrained
  glass-box" fusion; **no per-user weight fitting**; **no logistic readiness regression**
  (that is Phase 28). Phase 27 produces a transparent, evidence-anchored, fixed-weight
  composite + a categorical zone label + ranked human-readable factors.
- **Per-user Strain-Risk AUC is meaningless** (near-zero injury events). Phase 27 does
  NOT gate on injury AUC and does NOT claim prediction. The output is framed as a
  *probability-shift context flag*, validated later (Phase 29) against soreness /
  load-tolerance proxies — not as injury prediction.
- **Foster monotony/strain is fragile on sparse consumer logs** (CRITICAL→MAJOR). It
  MUST be **completeness-gated**: only computed when enough daily load is logged; else
  fall back to streak / session-density / load-spike heuristics. This is the explicit
  "completeness-gated" requirement in the ROADMAP bullet.
- **Strength load must be relative-intensity-based, NOT raw tonnage.** Heavy low-rep
  work and light high-rep work differ in connective-tissue/neuromuscular cost; raw
  kg-volume conflates them. Use est-1RM-relative intensity buckets + hard-set counting.
  (competitive-analysis §3.1: the strength signal is the structural moat — get it right.)
- **Glass-box / explainability is non-negotiable** (§2.7, MINOR finding §323): every
  Strain-Risk number must decompose into named pre-fusion factors.

## 2. The strength-load model (Layer A of this phase)

### 2.1 Inputs available (verified in code)

`WorkoutSession` → `ExerciseEntry` (has `muscleGroup: MuscleGroup?`) → `SetRecord`
(`reps: Int`, `weight: Double`, `rpe: Double?`, `isWarmup: Bool`). `MuscleGroup` is the
Phase-22 33-value taxonomy with `var region: MuscleRegion` (legs/back/chest/shoulders/
arms/core). **No est-1RM, RIR, hard-set, or monotony code exists yet — all built here.**

### 2.2 Per-muscle HARD SETS (relative-intensity, not tonnage)

A "hard set" is a working set taken close enough to failure to drive adaptation/strain.
Standard sports-science definition (NSCA `optimized_essentials_of_strength_training`,
Schoenfeld hard-set volume literature): a non-warmup set at sufficient relative intensity
OR sufficient proximity to failure.

**Qualifying rule (deterministic, all named constants):**
- Exclude `isWarmup == true`.
- A set qualifies as a HARD SET when **either**:
  - relative intensity ≥ `hardSetIntensityThreshold` (fraction of est-1RM), **or**
  - estimated RIR ≤ `hardSetRIRThreshold` (close to failure), when RPE is logged.
- Sets with neither weight nor RPE (e.g. pure bodyweight, no RPE) → counted under a
  separate `unscored` bucket so completeness gating can see the gap (do NOT silently
  treat as hard or easy).

Hard sets are aggregated **per `MuscleGroup`** (and rolled up per `MuscleRegion`) over a
configurable window (default last 7 days for acute, with a longer chronic comparison).

### 2.3 est-1RM and relative intensity (Epley, with RPE/RIR refinement)

- **est-1RM (Epley):** `e1RM = weight * (1 + reps / 30)`. Standard, deterministic,
  widely used. Per `MuscleGroup`+exercise-name, track a rolling best est-1RM as the
  per-muscle 1RM reference (no raw tonnage leaks into the strain math).
- **Relative intensity:** `relIntensity = weight / e1RMreference` for that exercise.
- **RIR/RPE bridge:** when `rpe` is logged, `estRIR = max(0, 10 - rpe)` (RPE 10 = 0 RIR).
  This is the standard RPE↔RIR mapping. RIR refines the hard-set decision when intensity
  data is thin.
- **Relative-intensity buckets** (for the strength-load descriptor, named constants):
  `light` (<0.65), `moderate` (0.65–0.80), `heavy` (0.80–0.90), `maximal` (≥0.90).
  Hard-set strain weight rises with the bucket.

### 2.4 Per-muscle strength-load descriptor

For each muscle: `strengthLoad = Σ over hard sets of (intensityBucketWeight)`, plus a
per-muscle **acute-vs-chronic elevation** computed against the same muscle's own recent
baseline (NOT ACWR; a simple ratio with a deadband, matching FatigueIndex's
`loadElevationComponent` philosophy). Output is a clamped 0–1 per-muscle elevation +
a same-muscle-region recurrence flag that feeds the soft-tissue cascade generalization
(moat-design §5.2: "recurrent same-region soreness + recent load spike → elevate
Strain-Risk"; NEVER claim tendon-specific risk).

## 3. Foster monotony & strain (Layer B — completeness-gated)

Per moat-design §2.6 and the codex MAJOR finding:
- `monotony_week = mean(daily_load) / sd(daily_load)`
- `strain_week = sum(daily_load) * monotony_week`
- Daily load = combined sRPE endurance load + strength hard-set load (one unified daily
  series so monotony reflects total stress).

**Completeness gate (mandatory):** compute monotony/strain **only** when the window has
≥ `monotonyMinLoggedDays` of logged daily load AND non-zero variance. Otherwise return
`nil` and the fusion falls back to streak / session-density / load-spike heuristics
(already present in FatigueIndexEngine). The gate state (`computed` vs `fellBack`) is an
explicit factor surfaced to explainability, so we never silently pretend we have data.

## 4. Strain-Risk fusion (Layer C — fixed glass-box heuristic)

A pure struct `StrainRiskEngine` (static methods) producing a `StrainRiskResult`:
- `score: Double` (0–1), `zone: StrainRiskZone` (e.g. `.low/.moderate/.elevated/.high`),
  `factors: [StrainRiskFactor]` (ranked, named, human-readable), `confidence: Double`
  (0–1 from data completeness — reuses BaselineEngine confidence + monotony-gate state +
  hard-set data coverage).

**Fixed sign-constrained weights (named constants, evidence-anchored — NOT fitted):**
fuses, each clamped to 0–1 then weighted:
1. **strength-load elevation** (per-muscle hard-set elevation, max/aggregate) — the
   structural-moat input, highest single weight.
2. **endurance-load elevation** vs personal baseline (sRPE/TRIMP vs `BaselineEngine`).
3. **FatigueIndexEngine** composite (FEA lineage — reused, not duplicated).
4. **Foster monotony/strain** (completeness-gated; weight redistributed when nil).
5. **soft-tissue memory** from `NiggleInjuryDeriver` (`1−exp(−0.5n)` recency-decayed) +
   same-region recurrence cascade modifier.
6. **rest debt / streak** (reused FatigueIndex primitives; avoid double counting by
   choosing ONE source — see §7 gray-area D-27-05).

Weight redistribution on missing inputs follows the existing engine pattern (re-normalize
over present components; carry a missingness/confidence penalty — never mean-impute).
Logistic regression is explicitly OUT (Phase 28).

## 5. State persistence (local-only, never-synced)

Any per-day strength-load state (e.g. per-muscle rolling est-1RM reference, daily
combined-load series cache) persists in a **new local-only SwiftData model**
`StrengthLoadState` mirroring the Phase-26 `BaselineState` privacy posture: NOT Codable
for sync, absent from `SyncService`, registered in the schema. If per-day caching is not
needed (engines can recompute from `WorkoutSession` history each run), prefer a pure
recompute and SKIP the model — decision recorded as gray-area D-27-02.

## 6. Hard invariants this phase enforces (restated)

1. **Shadow harness stays gated OFF.** No live activation; no master flag flipped.
2. **Live recovery score BYTE-UNCHANGED.** `BaselineTierFenceTests` must stay green;
   Phase 27 does NOT modify `RecoveryScoreEngine.computeBaseline`.
3. **Strain-Risk must NOT alter live AutoregulationEngine recommendation or recovery
   score** (phase-specific invariant). It is display/shadow context only this phase. No
   call site in the live recommendation path consumes `StrainRiskEngine` output yet.
4. **New SwiftData models local-only / never-synced** (if any created).
5. **New engines pure structs + static methods + deterministic** (Foundation-only).
6. **Atomic commits directly to `main`. No new branch. Never push. Never flip a live default.**
7. **Run waves SERIAL.** After any shared-type/enum change, run the FULL
   `WorkloadAppTests` suite. Discard `.xcstrings` build-churn. Trust only `xcodebuild`,
   not stale SourceKit.
8. **No "Faros/Tonus/Tutrice"** in any user-facing copy; product is **Tuwa**.

## 7. Gray-area decisions (no human discuss-phase — planner-resolved)

- **D-27-01 — Strain-Risk is a heuristic flag, NOT logistic fusion.** Rationale: codex
  verdict §301/§318 explicitly defers logistic fusion to Readiness (Phase 28); fitting
  weights on consumer data is "statistically bogus". Phase 27 ships fixed sign-constrained
  glass-box weights only.
- **D-27-02 — Prefer pure recompute over a new persisted model where feasible; add
  `StrengthLoadState` only for the per-muscle rolling est-1RM reference** (which is a
  genuine running statistic that benefits from persistence and must not be recomputed
  from a full history scan every run). If the executor finds recompute is cheap and
  correct, the model may be skipped — but if added it MUST be local-only/never-synced.
  Rationale: minimize new synced-surface risk while honoring the moat-design persistence
  posture (§3 "per-day state in a local-only never-synced model").
- **D-27-03 — Hard-set definition uses intensity-OR-RIR, with an explicit `unscored`
  bucket.** Rationale: consumer logs are incomplete; silently classifying unscored sets
  would corrupt the strength signal and hide gaps from the completeness gate (codex
  missing-data-indicator principle).
- **D-27-04 — est-1RM via Epley.** Rationale: deterministic, standard, no external deps,
  matches the "no raw tonnage" requirement by converting to relative intensity.
- **D-27-05 — Avoid double-counting rest-debt/streak/density between FatigueIndexEngine
  and the new Foster monotony layer.** The fusion consumes FatigueIndex as ONE composite
  component and adds monotony/strain as a SEPARATE component only via the unified daily
  load series; rest-debt/streak are taken from FatigueIndex only. Rationale: codex MAJOR
  finding on conflated channels + explainability.
- **D-27-06 — Strain-Risk output is wired ONLY to shadow/display surfaces (or left
  unwired this phase), never to the live recommendation/recovery path.** Rationale:
  phase-specific invariant.
- **D-27-07 — Strain-Risk validation deferred to Phase 29; Phase 27 does NOT add
  activation gates or AUC.** Rationale: codex CRITICAL #4 (AUC meaningless per-user).
- **D-27-08 — Reuse `NiggleInjuryDeriver` and `BaselineEngine` as-is; do not duplicate
  soft-tissue or baseline math.** Rationale: consistency-enforcement; single source of truth.

## 8. Wave structure (serial)

- **Wave 1 (27-01):** Strength-load primitives — pure `StrengthLoadEngine` (est-1RM Epley,
  relative-intensity buckets, RIR bridge, per-muscle hard-set counting + per-muscle
  elevation, same-region recurrence flag) + (optional, D-27-02) local-only
  `StrengthLoadState` model. Pure + deterministic, fully unit-tested. No fusion yet.
- **Wave 2 (27-02):** Foster monotony/strain (completeness-gated) inside a pure
  `LoadDistributionEngine` (or extend StrengthLoadEngine) producing a unified daily-load
  series + gated monotony/strain + fallback flag. Unit-tested incl. the gate fallback path.
- **Wave 3 (27-03):** `StrainRiskEngine` fusion — fixed glass-box weights, zone label,
  ranked factors, confidence, missing-input redistribution. Consumes Waves 1–2 +
  FatigueIndexEngine + NiggleInjuryDeriver + BaselineEngine. Unit-tested incl.
  determinism, sign constraints, weight redistribution, "no-injury-prediction" copy
  audit, and a tier-fence + full-suite regression guard proving live recovery score and
  live recommendation are unchanged.
