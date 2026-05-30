# Phase 26 — Plan Check (Pre-Execution Goal-Backward Review)

**Phase:** 26-individualized-baselines
**Plans checked:** 4 (26-01 … 26-04)
**Reviewer stance:** FORCE (assume flawed until proven)
**Date:** 2026-05-30

## VERDICT: **PASS** (with 0 blockers, 3 warnings)

The four plans, executed serially (model → engine → bucketer+fence → report), deliver
every D-01..D-04 mandate and RESEARCH §1-8 substrate scope with no goal gaps. The
HIGH-risk no-live-change invariant is machine-enforced, not merely asserted in prose.
The 3 warnings are quality hardening that should be addressed during execution but do
not block the phase goal.

---

## 1. Goal coverage (D-01..D-04 + RESEARCH §1-8)

| Scope item | Source | Plan / Task | Status |
|------------|--------|-------------|--------|
| Local-only per-day state @Model | §6, locked | 26-01 T1 | COVERED |
| Robust baseline math (EWMA μ + Welford M2 + MAD×1.4826 + Huber clip) | §1, D-01 | 26-02 T1 | COVERED |
| Prequential no-leak z-score + σ floor + cold-start nil | §2, D-01 | 26-02 T1/T2 | COVERED |
| Altini rolling-CV early-warning on innovations (3-level hysteresis) | §3, D-01 | 26-02 T1/T2 | COVERED |
| Composite 0–1 confidence, 14→60 ramp, NO population prior | §4, D-03/D-03a | 26-02 T1/T2 | COVERED |
| Day-bucketing (median morning window, GAP no-carry-forward, dedup) | §5, D-02/D-02a | 26-03 T1 | COVERED |
| Additive fetchRestingHRHistory (open-q #1) | §5.5 | 26-03 T1 | COVERED |
| Seeded deterministic convergence report (7 traces) | §7, D-04 | 26-04 T1 | COVERED |
| Result checkpoint = human review (autonomous:false) | D-04 | 26-04 T2 | COVERED |
| Unit tests vs hand-computed oracles | §8 | 26-01/02/03/04 | COVERED |
| Tier fence (no live change) | §8.2 HIGH | 26-03 T2 | COVERED |
| Scope fence: NO shadow arm, NO z→recovery map | D-01 | 26-04 (asserted) | COVERED |

Every D-01..D-04 appears in a task action + must_haves. Researcher open questions #1
(RHR history) and #2 (one-row-flattened model) are explicitly RESOLVED by decision in
26-03 and 26-01. RESEARCH §"Open Questions" #3 (λ-match-incumbent) is correctly left as
a report-calibration concern, not a blocker. No D-XX is reduced to a "v1/static/stub"
shadow — no scope-reduction language found (Dimension 7b clean).

## 2. Tier-fence / no-live-change (HIGH-risk invariant) — MACHINE-ENFORCED ✓

Verified against actual code:
- `RecoveryScoreEngine.computeBaseline` (RecoveryScoreEngine.swift:243) body is
  `Array(values.suffix(7)) … reduce/+/count` — the 7-day mean. 26-03 T2
  `liveBaselineStillExists` asserts the signature + trailing-mean tokens ("suffix"/window)
  are present → real, will catch a regression.
- 26-03 T2 `substrateNotWiredLive` greps RecoveryPipeline.swift for
  BaselineEngine/DayBucketer/BaselineState → asserts ABSENT. Confirmed today the pipeline
  references none of these (they don't exist yet); the test locks that in.
- 26-02 T1 acceptance greps BaselineEngine.swift for
  RecoveryScoreEngine|RecoveryPipeline|SyncService → must return nothing (engine standalone).
- 26-03 T2 `engineDoesNotImportLivePath` re-asserts the fence from the consumer side.
- fetchRestingHRHistory is purely additive (new func; no existing fetch touched).

This is genuine machine enforcement (source-grep XCTest + build-time grep gates), not prose.
No task edits `RecoveryScoreEngine.compute`'s return, `RecoveryPipeline`'s recovery path,
`AutoregulationEngine`, `ShadowPredictor.registeredArms`, or `SyncService`. The live
recovery output cannot change. PASS.

## 3. Prequential no-leak — STRUCTURALLY PREVENTED ✓ (1 warning)

- 26-02 separates `score(state,y)` (reads σ through t-1) from `step(state,y)` (folds t) as
  two methods — fold-before-score is structurally impossible within a single call. The
  `noLeakOrdering` test constructs a divergent case and asserts score() yields the
  no-leak z. Good.
- σ divide-by-tiny floor present: `z = r / max(σ_mad, σ_floor)`; per-signal floors
  (3ms/1.5bpm/15min) named; `count<2 || madBuffer<W_min ⇒ z==nil` (no inf/NaN). The
  `sigmaFloorAndColdNil` test covers it. PASS.
- Tie to RecoveryPipeline:196-202 + Phase-24 date contract: 26-02 §2.4 references the
  monotonic `startOfDay(t) > lastBucketedDate` cutoff. Confirmed RecoveryPipeline:196-202
  uses the same `featureCutoff = startOfDay(.now)` + DEBUG assert pattern the plan mirrors.

**WARNING W-1 (idempotency cutoff ownership is under-specified).** §2.4 / 26-01 store
`lastBucketedDate` in state, and 26-02 T2 `idempotencyCutoff` says the guard is
"caller-side … or assert score+step are gated by the caller." But neither `score` nor
`step` takes a date argument, the engine is explicitly stateless/dateless, and Plan 04's
prequential loop description does not show an explicit `if startOfDay(t) > lastBucketedDate`
guard before calling step. Risk: a re-presented day double-folds because no single
component owns the cutoff. FIX: make 26-02 `step` either (a) take the day's `date` and
no-op when `date <= state.lastBucketedDate` (engine-owned, testable), or (b) require
Plan-04's loop to implement the guard explicitly and assert it. Pick one and state it in
the 26-02 action so the `idempotencyCutoff` test asserts a concrete contract, not an
"or". Severity: WARNING (the report loop feeds strictly-ascending days, so the leak won't
manifest in the checkpoint — but the contract is the phase's stated discipline and a
future Phase-28 caller could trip it).

## 4. Determinism ✓

- Engine: 26-02 acceptance greps `Date\(|\.now|Calendar\.current|SystemRandomNumberGenerator`
  → must return nothing. `BaselineEngine` takes all dates/seeds as input. Calendar/day
  logic confined to DayBucketer (which takes an injected `Calendar` param). PASS.
- Report: fixtures use fixed anchor `Date(timeIntervalSince1970:0)` + day offsets; noise via
  `ShadowMetrics.SplitMix64(seed:)` (verified at ShadowMetrics.swift:127, a real
  `RandomNumberGenerator`); hash-equality test asserts two same-seed runs are byte-identical.
  PASS.

## 5. Local-only invariant ✓

- 26-01: no Codable, no *Row, no push/pull; "BaselineState" absent from SyncService
  (verified: SyncService.swift has ZERO refs to any local-only model today — convention holds).
- Registered in app Schema (WorkloadApp.swift, after SorenessLog.self:80) AND in the test
  in-memory ModelContainer (copy SorenessLogModelTests makeContext + append). Both required
  and both present in the plan. Additive standalone model → SwiftData lightweight migration,
  no MigrationPlan (matches ShadowArmPrediction/SorenessLog precedent). PASS.
- Engine stateless, math in engine on a SignalState value mirror; model is a dumb carrier
  (§6.3) — 26-01 acceptance asserts NO statistics math in the model. PASS.

## 6. Numerical correctness ✓ (1 warning)

- EWMA fold, Welford M2 (vs two-pass oracle on a mean≫variance array), MAD×1.4826 (vs
  hand-computed median-of-abs-dev), Huber clip (μ-move ≤ k·σ AND strictly < unclipped)
  are each asserted to 1e-9 in 26-02 T2. Strong oracle coverage.
- detect-on-raw / update-on-clipped split is explicit and correct: z (§2) and cvUpdate (§3)
  consume RAW r_t; only the μ-fold uses clipped ŷ_t. 26-02 acceptance asserts the split in
  code. PASS.

**WARNING W-2 (Welford-mean vs EWMA-μ innovation basis).** §1.2 carries a SEPARATE
`welfordMean` for M2, while the MAD buffer stores raw innovations `r_t = y_t − μ_{t-1}`
(EWMA μ). The two dispersion estimators are thus computed against different centers
(Welford vs EWMA). This is defensible (and the plan documents it), but the
`welfordVsTwoPass` oracle test must feed the Welford path its OWN `welfordMean`-centered
deviations, not EWMA-μ deviations, or the 1e-9 assertion will spuriously fail. FIX: have
26-02 T2 state explicitly that the two-pass oracle is computed about the running
`welfordMean`, matching the engine's accumulator. Severity: WARNING (test-construction
correctness; not an algorithm defect).

## 7. Wave ordering + pbxproj ✓

- Waves: 01 (model, wave 1, no deps) → 02 (engine, wave 2, dep 01) → 03 (bucketer+fence,
  wave 3, deps 01+02) → 04 (report, wave 4, deps 01+02+03). Serial, acyclic, no forward
  refs. Correct: engine value-mirror needs the model shape; report drives engine+bucketer.
- pbxproj single-writer: 01, 02, 03 each add exactly one app-target file and each is the
  SOLE pbxproj writer in its own wave (different waves → no concurrent writes). Test files
  land in the synchronized WorkloadAppTests root group (no pbxproj edit) — verified that
  convention is real in this repo. 04 is test-only + an artifact md → no pbxproj edit.
  Correct.
- 04 marked `autonomous: false` with a `checkpoint:human-verify gate="blocking"` Task 2 —
  the human result checkpoint (D-04). Correct.

## 8. Atomicity + acceptance realism ✓ (1 warning)

- Every executable task ends in a REAL `xcodebuild test`/`build` against the correct
  project ("workload management.xcodeproj"), scheme ("workload management"), and a VERIFIED
  sim id (8E872500-… exists on this machine). Acceptance criteria prove behavior (oracles,
  Huber strictly-less-than, no-leak divergence, CV fires/quiet, confidence ramp, round-trip
  persistence, source-grep fences), not just compilation. Strong.

**WARNING W-3 (26-02 Task 1 verifies with `build`, defers all behavior to Task 2 `test`).**
26-02 T1's `<verify>` is `xcodebuild build` only; the ten numeric/behavior assertions live
in T2. That is acceptable atomicity (T1 = compile-green engine, T2 = prove it), but it
means T1 can "pass" with a numerically wrong engine. This is fine given T2 immediately
follows in the same plan, but note: if execution stops between T1 and T2, the engine is
unproven. Severity: WARNING (acceptable design; flagged for awareness — no change required
if the executor runs both tasks).

---

## Context Compliance (CONTEXT.md)

- All locked decisions D-01..D-04 + the locked-by-design list have implementing tasks.
- NO deferred idea appears: no predicting shadow arm, no z→recovery mapping, no
  population sex/age prior, no Kalman/per-user learning, no in-app debug surface,
  no backfill. 26-04 explicitly fences these out. PASS.
- Claude's-discretion items (half-lives, k, σ floors, CV thresholds, confidence weights,
  model field set, report format) are resolved with principled named-constant defaults
  grounded in §8.3 — not flagged.

## CLAUDE.md / Architectural-Tier Compliance

- Pure-struct static engines, @Model carrier, repository/pipeline untouched — matches the
  project layer stack and the RESEARCH Architectural Responsibility Map exactly. No
  capability is mis-tiered (security-sensitive tiers N/A — no auth/network/crypto this phase).
- DESIGN.md N/A (no UI this phase). HealthKit privacy constraint honored (state never synced).

## Issues (structured)

```yaml
issues:
  - dimension: prequential_no_leak
    severity: warning
    id: W-1
    plan: "26-02"
    task: 1
    description: "Idempotency cutoff (startOfDay(t) > lastBucketedDate) has no single owner — engine is dateless, Plan-04 loop doesn't show the guard; 26-02 T2 hedges 'caller-side ... or'."
    fix_hint: "Make step() take the day date and no-op when date <= state.lastBucketedDate (engine-owned, testable), OR require Plan-04's loop to implement+assert the guard. Replace the 'or' with one concrete contract."
  - dimension: numerical_correctness
    severity: warning
    id: W-2
    plan: "26-02"
    task: 2
    description: "welfordVsTwoPass oracle must center deviations on the running welfordMean (not EWMA μ), matching the engine's separate Welford accumulator, or the 1e-9 assert spuriously fails."
    fix_hint: "State in 26-02 T2 that the two-pass oracle is computed about welfordMean."
  - dimension: atomicity
    severity: warning
    id: W-3
    plan: "26-02"
    task: 1
    description: "T1 verifies with `xcodebuild build` only; all behavior proof is in T2. Engine is unproven if execution halts between tasks."
    fix_hint: "Acceptable; ensure executor runs T1+T2 together. Optionally fold a smoke assert into T1's verify."
```

## Recommendation

No blockers. Plans WILL achieve the Phase 26 substrate goal with the live recovery score
provably unchanged. The 3 warnings are execution-time hardening (cutoff ownership, oracle
centering, T1 build-only verify) — recommend the planner tighten W-1 and W-2 in the
26-02 action/test text before execution, but they do not gate. **PASS — proceed to
execute-phase 26.**
