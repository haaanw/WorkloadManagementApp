# Phase 24: Validation Data-Contract + Shadow-Harness Upgrade — Context

**Gathered:** 2026-05-30
**Status:** Ready for planning
**Milestone:** v1.6 Algorithm Moat (Personal Readiness v1) — FIRST / foundation phase

<domain>
## Phase Boundary

This phase builds the **measurement substrate** for the whole v1.6 algorithm moat. It writes **no scoring model, no baselines, no strength load, no readiness fusion.** It does exactly four things, all to the existing Phase-20 shadow harness:

1. **Formalize a prequential prediction data-contract** — give every shadow row an explicit `predictionDate` (day the prediction is *made*), `targetDate` (day the prediction is *about*), a **feature-cutoff** semantic (no information after `predictionDate` may enter a prediction), and an **outcome-window** semantic (a target-day prediction is resolved ONLY against `targetDate`'s actuals). Fix the existing same-day write/resolve bug (§bug).
2. **Replace the engine-derived outcome label** — the harness currently treats "next-day recovery score" (a `RecoveryScoreEngine` output) as an outcome, which is **circular** (a recovery model predicting its own future transformed inputs). Re-source the continuous-recovery label, and document the label set as **raw self-report / wellness / soreness / adherence**, none engine-derived.
3. **Upgrade the harness metrics** — `ShadowAnalyticsService.aggregate` is MAE-only. Add calibration slope, Spearman ρ, blocked/purged cross-validation, and a **block bootstrap** CI that respects daily autocorrelation — as pure functions over resolved rows.
4. **Add a generic "experimental arm" interface** — a registration shape so Phases 26–28 can plug a candidate predictor (baselines, strength-load, readiness fusion) alongside the current algorithm and the existing cycle arm **without re-plumbing** the log model, the pipeline call, or the analytics. Ship **zero new predictors** this phase.

Everything is **local-only, never synced** (mirrors `CyclePredictionLog` / `MenstrualCycleSnapshot` D-13 privacy posture). Pure structs with static methods where the logic is computational (predictor + metrics). The master activation flag stays **OFF** — Phase 24 changes no user-facing behavior whatsoever.

**This is backend/measurement only — no UI.**
</domain>

<the_bug>
## The existing same-day date-contract bug (codex CRITICAL #3)

**Symptom (as written in the code's own comments):** the harness *describes* its predictions as being "about tomorrow," but **writes them keyed to today and resolves them against today's actuals** — so a prediction made on day D for day D+1 is scored against day D's outcomes. This leaks: the "prediction" is effectively evaluated against the same day whose data partly produced it, and the cycle-offset signal is measured against the wrong day's physiology. Any MAE computed today is **not** a valid next-day forecast error.

**Exact evidence in code (file:line):**

1. **Model contract claims target-day, comment is honest about the lie:**
   `WorkloadApp/Models/CyclePredictionLog.swift:21` —
   `/// The prediction-target day (the day whose outcomes the predictions are about).`
   …but the field is populated with *today* (see #2), so `date` is actually the *prediction* day, not the *target* day. The doc-comment and the write disagree.

2. **Stage-1 writes the row keyed on TODAY while the prediction is for TOMORROW:**
   `WorkloadApp/Services/ShadowAnalyticsService.swift:57` —
   `try repo.upsertPrediction(date: .now, athlete: athlete) { row in …`
   The call site comment at `RecoveryPipeline.swift:184` even says *"Stage 1: write today's prediction row (predictions are about tomorrow)."* — i.e. the prediction is for D+1, but the row's `date` is D.

3. **Stage-2 resolves actuals against `row.date` — the SAME day the row was written (D), not D+1:**
   `WorkloadApp/Services/ShadowAnalyticsService.swift:124` —
   `let day = calendar.startOfDay(for: row.date)` then `recoveryByDay[day]`, `wellnessByDay[day]`, `sessionDays.contains(day)` (lines 126–132). All actuals are joined on `row.date` = the prediction day D, never D+1.

4. **`fetchUnresolved(olderThan:)` gates on `row.date < startOfDay(today)`** (`CyclePredictionLogRepository.swift:53-59`). Because `row.date` = the *prediction* day, a row written on D becomes "resolvable" on D+1 — but it is then resolved against D's stored actuals (which exist by D+1), so the join *succeeds* and produces a confidently-wrong same-day score. The bug is silent: nothing errors, the numbers are just measuring the wrong thing.

**Root cause:** the model conflates *prediction day* and *target day* into one `date` field. The predictor extrapolates "one step ahead" (`ShadowPredictor.baselinePrediction` returns `last + slope`, i.e. a D+1 estimate) and the cycle offset uses the *predicted day's* phase — but the storage and resolution both treat the row as same-day.

### The fix (locked)

Split the single `date` into two explicit dates and make resolution honor them:

- **D-01 — Two dates on the row.** Add `predictionDate` (the day the prediction is *made*, set to `startOfDay(.now)` at Stage 1) and `targetDate` (the day the prediction is *about* = `predictionDate + 1 day` for the current next-day outcomes). Keep the legacy `date` field temporarily as an alias of `predictionDate` for a clean migration, or rename with a lightweight migration (planner decides; SwiftData lightweight migration since this is a local-only additive model — see D-08).
- **D-02 — Feature cutoff = `predictionDate`.** All series fed to a predictor must contain **only** observations with day ≤ `predictionDate`. The pipeline already builds series from history up to "now"; the contract makes this explicit and the planner adds an assertion/guard. No future leakage.
- **D-03 — Resolution joins on `targetDate`, not `predictionDate`.** Stage-2 `resolveOutcomes` must key every actual join (`recoveryByDay`, `wellnessByDay`, `sessionDays`) on `row.targetDate`, and a row is only resolvable once `targetDate < startOfDay(asOf)` (i.e. the target day is fully in the past). This is the single behavioral fix that closes the leak.
- **D-04 — Upsert keys on `predictionDate`.** One row per athlete per *prediction* day (a prediction made on D about D+1). Re-running the pipeline on D updates the same row. (`upsertPrediction` keys on the prediction day, unchanged in spirit, just renamed.)
- **D-05 — Resolved-window query** (`fetchResolved`) and `fetchUnresolved` re-expressed against the new date fields with the corrected target-day gate.
</the_bug>

<decisions>
## Implementation Decisions

### Data-contract (the heart of the phase)
- **D-01:** Row carries explicit `predictionDate` + `targetDate` (see §bug fix). For the current next-day outcomes, `targetDate = predictionDate + 1 day`. The contract is **horizon-parameterized** — store the horizon so a future phase could log a 2-day-ahead arm without schema change (default horizon = 1).
- **D-02:** **Feature cutoff = `predictionDate`.** No observation dated after `predictionDate` may enter any predictor's input series. Enforced at the pipeline boundary (series construction) and documented as a contract assertion. This is the prequential / no-leak rule (codex MAJOR: "predict baseline from yesterday's state … THEN update").
- **D-03:** **Outcome window = `targetDate` only.** Resolution joins actuals strictly on `targetDate`. A prediction for D+1 is resolved against D+1's recovery snapshot / wellness check-in / session, never D's.

### Outcome labels (de-circularize)
- **D-06:** The outcome label set is **raw, non-engine-derived** wherever possible:
  - **wellness** — `WellnessCheckIn.wellnessScore` (subjective self-report composite; already raw, keep).
  - **soreness/pain** — `WellnessCheckIn.soreness` (1–5 raw self-report; keep).
  - **adherence (replaces "completion")** — planned-vs-completed, not a bare "session logged" flag. Phase-24 minimum: keep the **observed-session indicator** (0/1) but **rename/reframe** it as `adherence` and document that "planned rest correctly observed as rest" must NOT be scored as failure once a plan signal exists (Phase 25/28 supplies planned-vs-actual; Phase 24 documents the contract and keeps the raw observed-session label as the interim proxy).
  - **recovery (continuous)** — **PROBLEM: `RecoverySnapshot.recoveryScore` is engine-derived** (codex: circular). Phase-24 decision: **retain the recovery label as a SECONDARY/diagnostic arm only, clearly flagged `engineDerived = true`**, and treat the **raw self-report labels (wellness, soreness, adherence) as the PRIMARY validation targets**. We do not delete the recovery series (it is the only continuous physiological-composite signal and is useful for relative baseline-vs-baseline MAE), but the contract marks it non-load-bearing for activation gates. A truly raw continuous recovery label requires raw HRV/RHR/sleep z-targets, which is Phase-26 territory — **deferred**.
- **D-07:** Optional **injury/"tweak" self-log** as an outcome is **DEFERRED to Phase 25** (it needs its own SwiftData model + UI). Phase 24 only leaves the contract room (a label slot the harness can resolve once Phase 25 ships) — it adds **no** injury model or field that requires UI.

### Harness metric upgrade
- **D-09:** Add, as **pure functions over resolved rows** in a new `ShadowMetrics` pure struct (keep `ShadowAnalyticsService` as the `@MainActor` SwiftData orchestrator; metrics math is Foundation-only and testable in isolation):
  - **Calibration slope** — OLS slope of `actual ~ predicted` (reliability slope); target band documented for Phase 29, not gated here.
  - **Spearman ρ** — rank correlation of (predicted, actual) per outcome (robust to the nonlinearity of self-report scales).
  - **Blocked / purged CV** — partition resolved rows into contiguous time blocks (no random split — random splits leak across an athlete's autocorrelated days, per the Chinese research file §验证方案), with a **purge gap** of ≥ the prediction horizon between train/test blocks. Phase 24 ships the *splitter* + per-block metric aggregation; it does not fit any model (there is no model yet), so CV here = "compute metric stability across time-blocks of the existing arms."
  - **Block bootstrap CI** — resample **contiguous blocks** of rows (not individual rows) to preserve daily autocorrelation, producing a CI for the **paired MAE difference** between two arms. Default block length documented (e.g. 7 days ≈ one autocorrelation scale); seedable RNG for deterministic tests.
- **D-10:** All metrics return **structs**, are deterministic, and degrade gracefully (insufficient-N → `nil`/`.insufficientData`, never a crash or a fabricated number). MAE math (`aggregate`) is preserved and extended, not replaced — Phase-20 cycle MAE keeps working byte-identically.

### Experimental-arm interface
- **D-11:** Introduce a generic **arm abstraction** so future predictors register without touching the log model's column list. Shape (planner finalizes): an `ExperimentalArm` value with an `id: String` (e.g. `"baseline"`, `"cycleAware"`, `"prsBaselineV1"`), a `predict(outcome:context:) -> Double?` closure-or-protocol, and an `engineDerived: Bool` flag per outcome. Predictions for all registered arms are written into a **generic per-arm prediction store** (see D-12) rather than the current hard-coded `recoveryBaseline`/`recoveryCycleAware` column pairs.
- **D-12:** **Storage strategy for N arms (planner decides between two, both keep local-only/never-synced):**
  - **(a) Child-row model** — a new local-only `ShadowArmPrediction` `@Model` (fields: `armId`, `outcomeRaw`, `predicted`, parent `CyclePredictionLog`/renamed log via cascade relationship). Cleanest for arbitrary arms; one row per (prediction, arm, outcome).
  - **(b) Keyed-dictionary column** — a single `[String: Double]`-encoded blob/transformable on the existing row keyed by `"armId.outcome"`. Less schema churn, weaker queryability.
  - **Recommendation: (a) child-row**, because Phases 26–28 each add an arm and child rows avoid ever-growing column lists. Whichever is chosen, the existing `baseline`/`cycleAware` pairs are **migrated into the generic store as two registered arms** (`"baseline"`, `"cycleAware"`) so the Phase-20 cycle validation is preserved through the same code path (no parallel legacy path).
- **D-13:** **Phase 24 registers ONLY the two existing arms** (`baseline`, `cycleAware`). It ships **no new predictor**. The interface is proven by re-expressing today's two predictions through it and showing identical numbers.

### Privacy / convention locks
- **D-14:** `CyclePredictionLog` (and any new child model) stays **local-only, never-synced** — no `Codable`, no Supabase encoder, no sync field (D-13 of Phase 20 / Phase 17 D-12). The nil-cycle-service path stays byte-identical (Phase 20 D-12): when no cycle service is injected, the shadow block does not run; the date-contract fix and new metrics must not change that.
- **D-15:** Predictor + metrics are **pure structs, static methods, Foundation-only** (`ShadowPredictor`, new `ShadowMetrics`). `ShadowAnalyticsService` stays the `@MainActor` SwiftData orchestrator. No engine outside the shadow path is touched (`RecoveryScoreEngine`, `WorkloadCalculator`, `AutoregulationEngine`, `FatigueIndexEngine` unchanged).
- **D-16:** **Master activation flag stays OFF.** Phase 24 produces measurements only; it never flips `CycleModifierActivation.isEnabled` and introduces no new "live" flag in an on-state. A PRS master flag (default false) may be *declared* for later phases but must default OFF and gate nothing user-facing this phase.
</decisions>

<deferred>
## Explicitly DEFERRED (NOT in Phase 24)

- **No scoring model** — no Readiness scalar, no logistic fusion, no Kalman/EWMA/Welford/MAD baseline. (Phase 26 baselines, Phase 28 fusion.)
- **No individualized baselines** — no per-signal personal normal, no z-scores, no CV early-warning. (Phase 26.)
- **No strength-load model** — no per-muscle hard sets, no relative-intensity buckets, no tonnage, no Strain-Risk fusion. (Phase 27.)
- **No ACWR demotion / AutoregulationEngine change.** (Phase 28.)
- **No injury/"tweak" self-log model or UI** — Phase 24 only leaves a contract slot; the model + UI are **Phase 25**.
- **No actual new predictor arm** — the arm *interface* ships; a PRS arm registering through it is Phase 26+.
- **No activation-gate enforcement** — Phase 24 computes the metrics (calibration/Spearman/CV/bootstrap); the numeric gates (MAE beat ≥3/4, ρ≥0.50, slope∈[0.8,1.2]) are *applied* in Phase 29.
- **No per-user weight learning / cohort priors** (dropped from v1 entirely per codex; not this phase regardless).
- **No raw continuous-recovery label** — re-sourcing recovery to a non-engine raw target needs the Phase-26 baseline machinery; Phase 24 flags the existing recovery label `engineDerived` and demotes it from primary.
</deferred>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Locked scope + reviews
- `.planning/research/algorithm-moat-design.md` — PRS spec + codex addendum + revised "v1 Robust Personal Baseline". §4 (validation plan), §4.2 (outcome labels), codex CRITICAL #3 (date-contract bug + prequential requirement), MAJOR (leakage/prequential, stale HealthKit samples, circular labels).
- `.planning/research/competitive-algorithm-analysis.md` — CHANGE 4 (build the prequential validation data-contract FIRST), CHANGE 5 (Strain-Risk = context flag), converged minimum-credible v1, "validated against your own outcomes" as the honest claim.
- `.planning/ROADMAP.md` — Phase 24 line (:265) + v1.6 milestone goal (:261-263).

### Existing harness to upgrade (READ FULLY)
- `WorkloadApp/Services/ShadowPredictor.swift` — pure predictor (baseline `last+slope`; cycle-aware = baseline + fixed phase offset). `Outcome` enum (recovery/wellness/completion/pain). The arm interface generalizes this.
- `WorkloadApp/Services/ShadowAnalyticsService.swift` — Stage-1 `recordPrediction` (:34, writes `date:.now` — the bug at :57), Stage-2 `resolveOutcomes` (:88, joins on `row.date` — the bug at :124-132), `aggregate` (:174, MAE-only). The metric upgrade extends this.
- `WorkloadApp/Models/CyclePredictionLog.swift` — local-only `@Model`; `date` field conflation (:21 doc vs reality). Add `predictionDate`/`targetDate`/horizon; possibly a child arm model.
- `WorkloadApp/Repositories/CyclePredictionLogRepository.swift` — `upsertPrediction` (:20, keys on day), `fetchUnresolved` (:53, target-day gate), `fetchResolved` (:72). Re-express against new dates.
- `WorkloadApp/Services/RecoveryPipeline.swift:177-230` — the ONLY call site: Stage-2 resolve then Stage-1 record, gated on `cycleTrackingService != nil`. Series construction (recovery/wellness/completion/pain) — the feature-cutoff guard lives here.

### Tests (conventions + must-not-break)
- `WorkloadAppTests/ShadowAnalyticsServiceTests.swift` — MAE math tests (pure, in-memory); note the two `resolveOutcomes` SwiftData-in-memory **XCTSkip** (optional to-one relationship predicate traps on iOS 26.1 sim) — new SwiftData-backed tests must use the same skip pattern or a disk-backed temp store.
- `WorkloadAppTests/ShadowPredictorTests.swift` — pure predictor test style.

### Format reference
- `.planning/phases/18-cycle-aware-recovery-baselines/18-01-PLAN.md` + `18-CONTEXT.md` — PLAN/CONTEXT structure to match.

### Conventions
- `CLAUDE.md` — pure-struct engines, `@MainActor` repositories/services, local-only never-synced privacy posture, no new sync fields, deterministic engines.
</canonical_refs>

<assumptions>
## Top Assumptions (to confirm at plan-review)

1. **Horizon = 1 day for all current outcomes.** `targetDate = predictionDate + 1` matches the existing "predictions are about tomorrow" intent. Multi-day horizons are stored-but-unused this phase.
2. **Child-row arm storage (D-12a) preferred over a transformable blob (D-12b)** — confirm with planner; both satisfy local-only/never-synced. Recommendation is child-row to avoid column sprawl across Phases 26–28.
3. **Migrating the existing `baseline`/`cycleAware` columns into the generic arm store is in-scope** (one unified path, no legacy parallel) — this is the riskiest refactor; if too large, fallback is to keep the two legacy columns AND add the generic store alongside, with the arm interface writing both. Planner picks based on migration cost.
4. **The recovery label stays as a flagged secondary arm**, not deleted — needed for relative MAE continuity and harmless once marked `engineDerived`/non-gating. A raw continuous-recovery target is Phase-26 work.
5. **CV/bootstrap on current data will often be `insufficientData`** — there is little resolved history and only two near-identical arms; Phase 24 validates the *machinery* (determinism, correct blocking/purging, graceful degradation), not a real verdict. The verdict is Phase 29.
6. **SwiftData lightweight migration suffices** for the additive `predictionDate`/`targetDate` fields (local-only store, additive, optional/defaulted) — no destructive schema change. New child model added to the `Schema([...])` in `WorkloadApp.swift` and the test container.
7. **The feature-cutoff guard is enforceable at the pipeline series-construction boundary** (the series already come from history ≤ now); Phase 24 makes it explicit/asserted rather than discovering a leak — confirm no predictor reads same-day-post-cutoff data today.
8. **No nil-cycle-service regression** — the shadow block only runs when a cycle service is injected; the date-contract fix and metrics must keep the no-service path byte-identical (Phase 20 D-12).
</assumptions>

---

*Phase: 24-validation-data-contract*
*Context gathered: 2026-05-30*
