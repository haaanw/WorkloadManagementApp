# Phase 26: Individualized Baselines - Context

**Gathered:** 2026-05-30
**Status:** Ready for planning

<domain>
## Phase Boundary

Build the **robust individualized-baseline substrate**: per-signal (HRV / RHR / sleep)
adaptive baselines using **robust EWMA + Welford/MAD** (NOT Kalman — codex v1 verdict),
**personal prequential (no-leak) z-scores**, an **Altini-style rolling-CV early-warning**
on innovations, and a **local-only never-synced per-day baseline-state model**. All pure
structs. Replaces the flat 7-day rolling mean (`RecoveryScoreEngine.computeBaseline`,
`RecoveryScoreEngine.swift:238-246`) as the baseline source — behind the shadow harness,
gated OFF, no behavior change to the live recovery score yet.

**In scope:** the baseline engine, z-score + CV computation, confidence model, day-bucketing
of HealthKit inputs, the per-day local-only state model, unit tests, and a seeded convergence
report for the result checkpoint.

**Out of scope (later phases):** registering a PREDICTING shadow arm (D-01 → Phase 28
fusion / Phase 29 shadow-run); fusion to a Readiness scalar (Phase 28); Strain-Risk
strength-load model (Phase 27); ACWR demotion / AutoregulationEngine swap (Phase 28); any
live activation (Phase 29). No per-user Q/R or weight learning (codex: unidentifiable on
consumer data). No population sex/age physiology prior (D-03).
</domain>

<decisions>
## Implementation Decisions

### Scope boundary vs Phase 28 (Area 1)
- **D-01:** **Substrate-only.** Phase 26 builds the baseline engine + prequential z-scores +
  Altini CV + per-day local-only state model + unit tests + a seeded convergence report.
  It does NOT register a predicting shadow arm. Any z→recovery mapping is deferred to the
  Phase 28 fusion (shadow-run in Phase 29) to avoid an arbitrary pre-fusion mapping polluting
  early metrics. The result checkpoint judges engine BEHAVIOR (convergence/robustness), not accuracy.

### Day-bucketing rule (Area 2)
- **D-02:** One bucketed value per signal per calendar day. HRV/RHR = **median of the
  overnight / first-morning sample window** (robust to daytime spikes, Altini-aligned);
  sleep = last-night aggregate (existing `fetchLastNightSleepWithDate`). **No carry-forward.**
- **D-02a:** Stale/gap rules: no fresh bucketed value for a signal that day → that day is a
  GAP (not imputed). If the latest available bucketed value is older than ~2 days → reduce
  confidence (not physiology). Window/stale thresholds are tunable named constants.

### Confidence + cold-start (Area 3)
- **D-03:** Confidence = composite **0–1** of (observation-count, recency-of-gaps, innovation
  dispersion). Cold-start = **wide band + LOW confidence**, **NO population sex/age prior**
  (codex: consumer-data unidentifiability; honest "not enough data yet" over borrowed physiology).
- **D-03a:** Personal z-scores become "trusted" above a confidence floor (~14 bucketed days),
  reaching full confidence by the **60-day normal band**. Graceful ramp, no hard binary gate.
  Floor / full-confidence day-counts are tunable named constants.

### Result checkpoint format (Area 4)
- **D-04:** Checkpoint = a **deterministic seeded convergence report** (markdown artifact
  emitted by the test harness) feeding synthetic + realistic signal traces, showing: baseline
  tracking vs raw, z-score behavior, CV early-warning firing, confidence ramp, and robustness
  to injected outliers / gaps / stale samples. Reproducible, no device. I generate it; user reviews
  it as the Phase 26 result checkpoint.

### Locked by design (carried forward — NOT re-litigated; see canonical refs)
- Robust **EWMA** mean + **Welford/MAD** spread; **Huber/winsorized** robust updates; **bounded**
  smoothing constants (algorithm-moat-design.md §299-327 codex v1 verdict).
- **Prequential / no-leak**: today's bucketed sample never feeds today's baseline used to score today.
- **Pure-struct engines**, static methods, Foundation-only (match WorkloadCalculator/RecoveryScoreEngine).
- **Local-only never-synced** per-day state model: no `Codable`, registered in `WorkloadApp.swift` Schema,
  ABSENT from `SyncService` (mirror `SorenessLog` / `CyclePredictionLog`).
- **Altini rolling-CV on innovations** (residuals from the baseline estimate), not raw HRV.
- **Fixed weights**, no per-user learning in v1.

### Claude's Discretion
- Exact EWMA half-life per signal; MAD vs Welford-σ as the dispersion estimator (or both);
  Huber tuning constant; the precise confidence formula weights — planner picks principled
  defaults as named constants, grounded in the design doc + a short researcher pass.
- The per-day state model's exact field set (running EWMA μ, M2/Welford accumulators, MAD
  buffer or summary, obs-count, last-bucketed-date, CV state) — planner decides minimal sufficient state.
- Report format details + how synthetic/realistic traces are generated (deterministic, no `Date.now`/random in engine).
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Locked algorithm design (MANDATORY — this IS the Phase 26 contract)
- `.planning/research/algorithm-moat-design.md` — §12-14 intent; §79-118 adaptive-baseline + z-score layers; §142-148 cold-start/confidence; §209-219 validation gates; **§299-327 codex v1 verdict (EWMA/Welford/MAD not Kalman, bounded smoothing, Huber/winsorized, prequential, day-bucketed, fixed weights, separate Strain-Risk)** — the binding simplification.
- `.planning/research/competitive-algorithm-analysis.md` — honest-framing / no-moat positioning + codex addenda.
- `algorithm research file/` — RFI personal-longitudinal-z construct + Altini "variability in variability" CV source (referenced by the design doc).
- `.planning/ROADMAP.md` §"Phase Details — v1.6" lines 267 (Phase 26 scope) + 261-270 (neighbors; confirms fusion=28, shadow-run=29).

### Shadow harness + prior phases (substrate plugs in later, no changes now)
- `WorkloadApp/Services/ShadowPredictor.swift` — `Outcome` enum (now incl `.niggleSeverity`), `ExperimentalArm` + `registeredArms()` (Phase 28 adds the arm, NOT here).
- `.planning/phases/24-validation-data-contract/24-CONTEXT.md` — predictionDate/targetDate/outcome-window date contract (prequential discipline source).
- `.planning/phases/25-soreness-tweak-self-log/25-CONTEXT.md` — local-only model pattern just used (SorenessLog).

### Code being replaced / wired / reused
- `WorkloadApp/Services/RecoveryScoreEngine.swift:238-246` — the flat 7-day mean being superseded; `:292-295` same-phase baseline; `:197-210` `computeSlope` reuse.
- `WorkloadApp/Services/WorkloadCalculator.swift:88-97` — existing EWMA exemplar (λ pattern) to mirror.
- `WorkloadApp/Services/HealthKitService.swift:187-373` — signal fetch shapes; `fetchHRVHistory(days:)` returns `[(date,value)]` for bucketing; per-sample, currently unbucketed.
- `WorkloadApp/Services/RecoveryPipeline.swift:46-66,197` — signal entry + the existing prequential cutoff to respect.
- `WorkloadApp/Models/RecoverySnapshot.swift` — per-day recovery store (consumers); `WorkloadApp/Models/SorenessLog.swift` + `CyclePredictionLog.swift` — local-only @Model template.
- `WorkloadApp/App/WorkloadApp.swift` Schema — register the new per-day state model (additive, lightweight migration).
- `WorkloadAppTests/` — engine-test naming (`{Engine}Tests.swift`) for the new baseline-engine + bucketing + confidence + CV tests + the convergence-report generator.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `WorkloadCalculator.computeHistoryEWMA` — EWMA-fold pattern to mirror for the robust baseline.
- `RecoveryScoreEngine.computeSlope` / `clampScore` — reuse for any trend/bound needs.
- `SorenessLog` / `CyclePredictionLog` — exact local-only never-synced @Model template (Phase 25/24).
- `HealthKitService.fetchHRVHistory(days:)` — `[(date,value)]` source for day-bucketing.

### Established Patterns
- Pure-struct static engines, per-day state persisted in SwiftData (not engine state) — the baseline state lives in the new local-only model, the engine stays stateless.
- Prequential cutoff already enforced in RecoveryPipeline (`:197`) — extend, don't re-invent the leak boundary.
- Shadow harness is generic over arms (`registeredArms()` + `recordPrediction`) — Phase 28 adds the arm with zero harness change; Phase 26 touches none of it.

### Integration Points
- New `BaselineEngine` (pure) + new local-only `@Model` per-day state (Schema-registered, SyncService-excluded).
- Day-bucketing helper consuming `HealthKitService` history → one value/signal/day.
- The flat-mean baseline stays the LIVE source; the new baseline runs in parallel/shadow only (gated OFF) — no change to RecoveryScoreEngine output this phase.
- Seeded convergence-report generator lives in the test target.
</code_context>

<specifics>
## Specific Ideas

- Robust baseline = EWMA mean + Welford/MAD spread + Huber/winsorized updates; CV early-warning on innovations (Altini).
- Confidence is continuous 0–1 with a graceful ramp; cold-start is honestly low-confidence, never a borrowed population physiology.
- The checkpoint deliverable is a reproducible markdown convergence report, not in-app UI.
</specifics>

<deferred>
## Deferred Ideas

- **Predicting shadow arm / z→recovery mapping** — Phase 28 fusion, shadow-run Phase 29. (Area 1 alt.)
- **Population sex/age cold-start prior** — rejected for v1 (codex), revisit only if validation shows cold-start is a real UX gap. (Area 3 alt.)
- **In-app baseline/confidence debug surface** — possible dev tool later; not this phase. (Area 4 alt.)
- **Per-user Q/R / weight learning (Kalman)** — dropped from v1 entirely (unidentifiable on consumer data).
- **Backfill shadow-metrics over personal history** — needs the Phase 28 arm to score against.
</deferred>
