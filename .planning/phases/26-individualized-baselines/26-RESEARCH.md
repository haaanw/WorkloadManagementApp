# Phase 26: Individualized Baselines - Research

**Researched:** 2026-05-30
**Domain:** Robust online statistics (per-signal adaptive baselines) on-device, Foundation-only Swift, pure-struct engines + local-only SwiftData state
**Confidence:** HIGH (math is textbook-grounded + cited; integration is verified against actual code at file:line)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions (D-01 .. D-04 — binding, do NOT re-litigate)
- **D-01 — Substrate-only.** Phase 26 builds the baseline engine + prequential z-scores + Altini CV + per-day local-only state model + unit tests + a seeded convergence report. It does **NOT** register a predicting shadow arm. Any z→recovery mapping is deferred to Phase 28 fusion (shadow-run Phase 29). The result checkpoint judges engine **BEHAVIOR** (convergence/robustness), not accuracy.
- **D-02 — Day-bucketing.** One bucketed value per signal per calendar day. HRV/RHR = **median of the overnight / first-morning sample window** (robust to daytime spikes, Altini-aligned); sleep = last-night aggregate (existing `fetchLastNightSleepWithDate`). **No carry-forward.**
- **D-02a — Stale/gap rules.** No fresh bucketed value for a signal that day → that day is a **GAP** (not imputed). If the latest available bucketed value is older than ~2 days → **reduce confidence** (not physiology). Window/stale thresholds are tunable named constants.
- **D-03 — Confidence + cold-start.** Confidence = composite **0–1** of (observation-count, recency-of-gaps, innovation dispersion). Cold-start = **wide band + LOW confidence**, **NO population sex/age prior** (honest "not enough data yet" over borrowed physiology).
- **D-03a — Trust ramp.** Personal z-scores become "trusted" above a confidence floor (~14 bucketed days), reaching full confidence by the **60-day normal band**. Graceful ramp, no hard binary gate. Floor / full-confidence day-counts are tunable named constants.
- **D-04 — Result checkpoint format.** A **deterministic seeded convergence report** (markdown artifact emitted by the test harness) over synthetic + realistic traces, showing baseline tracking vs raw, z-score behavior, CV early-warning firing, confidence ramp, robustness to injected outliers / gaps / stale samples. Reproducible, no device.

### Locked by design (carried forward — NOT re-litigated)
- Robust **EWMA** mean + **Welford/MAD** spread; **Huber/winsorized** robust updates; **bounded** smoothing constants (algorithm-moat-design.md §299-327 codex v1 verdict).
- **Prequential / no-leak**: today's bucketed sample never feeds today's baseline used to score today.
- **Pure-struct engines**, static methods, Foundation-only (match WorkloadCalculator/RecoveryScoreEngine).
- **Local-only never-synced** per-day state model: no `Codable`, registered in `WorkloadApp.swift` Schema, ABSENT from `SyncService` (mirror `SorenessLog` / `CyclePredictionLog`).
- **Altini rolling-CV on innovations** (residuals from the baseline estimate), not raw HRV.
- **Fixed weights**, no per-user learning in v1.

### Claude's Discretion (planner picks principled named-constant defaults, grounded below)
- Exact EWMA half-life per signal; MAD vs Welford-σ as the dispersion estimator (or both); Huber tuning constant; the precise confidence formula weights.
- The per-day state model's exact field set.
- Report format details + how synthetic/realistic traces are generated (deterministic, no `Date.now`/random in engine).

### Deferred Ideas (OUT OF SCOPE — do not research alternatives)
- Predicting shadow arm / z→recovery mapping (Phase 28 fusion, Phase 29 shadow-run).
- Population sex/age cold-start prior (rejected for v1).
- In-app baseline/confidence debug surface.
- Per-user Q/R / weight learning (Kalman) — dropped from v1 entirely.
- Backfill shadow-metrics over personal history (needs the Phase 28 arm).
</user_constraints>

<phase_requirements>
## Phase Requirements

This phase has no `REQUIREMENTS.md` ID list; the binding scope is D-01..D-04 + the locked-by-design list above. The planner maps each below.

| Scope item | Source | Research support |
|------------|--------|------------------|
| Robust per-signal baseline (EWMA μ + Welford/MAD spread + Huber update) | D-01, locked design | §1 (exact recurrences, cited) |
| Prequential no-leak z-score | D-01, locked design | §2 (ordering + σ floor, tied to Pipeline:197) |
| Altini rolling-CV early-warning on innovations | D-01, locked design | §3 (window, fire/clear thresholds) |
| Composite 0–1 confidence, ~14→60d ramp, no population prior | D-03/D-03a | §4 (named constants) |
| Day-bucketing of HealthKit inputs | D-02/D-02a | §5 (window, gap rep, dedup) |
| Local-only per-day state @Model | locked design | §6 (field set, Schema, exclusion) |
| Seeded convergence report | D-04 | §7 (fixtures, artifact path, format) |
| Unit tests + risks | implicit | §8 |
</phase_requirements>

## Summary

Phase 26 replaces the flat 7-day rolling-mean baseline (`RecoveryScoreEngine.computeBaseline`, `RecoveryScoreEngine.swift:243-247`) with a **robust per-signal online state estimator** — but only as a parallel, gated-OFF substrate. The live recovery score does not change this phase. Three textbook, Foundation-only primitives compose the estimator: (1) an **EWMA mean** with a per-signal half-life→λ mapping (mirrors the existing `WorkloadCalculator.computeHistoryEWMA` fold at `:88-97`); (2) an **online dispersion** estimate — recommend **MAD on a small rolling buffer** as the primary scale (robust, matches the Huber/winsorize design intent) with **Welford M2** carried in parallel as a numeric cross-check and cold-start fallback; (3) a **Huber/winsorized update rule** that clips each innovation to ±k·scale before it moves the mean, so a single aberrant reading cannot drag the baseline. State (μ, M2, count, MAD buffer, last-bucketed-date, CV state, confidence) lives in a **new local-only never-synced `@Model`**; the engine stays a stateless pure struct.

The discipline that makes this defensible is **prequential (no-leak) scoring**: bucket day *t* → score *t* against baseline state carried through *t-1* → **then** fold *t* into state. This extends the prequential cutoff already enforced at `RecoveryPipeline.swift:196-202` (Phase 24 date contract). On top of the residuals (innovations `y_t − μ_{t-1}`) we track an **Altini-style rolling CV** as an early-warning flag for "variability in variability." Confidence is a continuous 0–1 composite of observation count, recency of gaps, and innovation dispersion, ramping from a ~14-day floor to full at 60 days, with **no population prior** — cold-start is honestly low-confidence. The deliverable is a deterministic seeded markdown convergence report generated entirely in the test target (no `Date.now`, seeded via the existing `SplitMix64` PRNG from `ShadowMetrics.swift:127`).

**Primary recommendation:** Build a stateless `BaselineEngine` (pure struct, static methods) exposing one `step(state:, observation:, signal:) -> NewState` recurrence + a `score(state:, observation:) -> (z, innovation)` read; persist state in a new local-only `@Model BaselineState` (one row per athlete per signal, or one row per athlete holding all three signal sub-states — planner picks; §6 recommends the latter for fewer rows). Use **MAD×1.4826** as primary scale with a hard floor, **Huber k=1.5** clip on innovations, and **per-signal EWMA half-life: HRV 7d, RHR 10d, sleep 7d**. Emit the convergence report from a `BaselineConvergenceReportTests` generator.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Robust baseline math (EWMA/MAD/Huber recurrence) | Engine (pure struct) | — | Project convention: deterministic, stateless, Foundation-only (matches WorkloadCalculator/RecoveryScoreEngine). |
| Prequential z-score (score-then-update) | Engine (pure struct) | Pipeline (orchestration order) | Math in engine; the score→update ordering is enforced by the caller, mirroring `RecoveryPipeline:196-202`. |
| Altini CV early-warning on innovations | Engine (pure struct) | — | Pure computation over carried CV state. |
| Confidence model (0–1 composite) | Engine (pure struct) | — | Deterministic function of carried state (count, gaps, dispersion). |
| Day-bucketing HealthKit → 1 value/signal/day | Helper (pure struct) | Database/Storage (HealthKit reads) | Bucketing is pure over `[(date,value)]`; the raw fetch is HealthKitService's job (`:187-373`). |
| Per-day baseline state persistence | Database/Storage (SwiftData) | — | New local-only `@Model`, Schema-registered, SyncService-excluded. |
| Seeded convergence report | Test target | — | No app/device tier; deterministic fixtures + `SplitMix64`. |

**Tier-correctness note for the planner:** NONE of this phase touches the live `RecoveryScoreEngine.compute` output, `RecoveryPipeline.run`'s recovery-score path, the shadow arm registry, or any network/sync tier. The new baseline runs in parallel (shadow), gated OFF. Any task that edits `RecoveryScoreEngine.compute`'s return, `AutoregulationEngine`, or `SyncService` payloads is OUT OF TIER for this phase.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Foundation | iOS 17+ SDK | `Calendar`, `Date`, `Double` math (`exp`, `pow`, `abs`, `sqrt`, median sort) | Locked: Foundation-only, no third-party math. [CITED: CONTEXT.md locked-by-design] |
| SwiftData | iOS 17+ SDK | New local-only `@Model` for per-day baseline state | Matches `SorenessLog`/`CyclePredictionLog` template. [VERIFIED: codebase] |
| XCTest | iOS 17+ SDK | Engine unit tests + seeded convergence-report generator | Existing test convention (`{Engine}Tests.swift`). [VERIFIED: codebase] |

**No external packages are installed in this phase.** All math is hand-implemented from cited textbook recurrences using Foundation only. The `## Package Legitimacy Audit` section is therefore **N/A** (no registry installs) — explicitly recorded so the planner does not insert a slopcheck gate.

### Reused in-repo assets (not packages)
| Asset | Location | Use |
|-------|----------|-----|
| EWMA fold pattern (`atl = atl*(1-λ) + tss*λ`) | `WorkloadCalculator.swift:88-97`, λ constants `:11,:13` | Exemplar for the baseline EWMA recurrence; mirror the λ-as-`static let` pattern. [VERIFIED: codebase] |
| `computeSlope` linear-regression | `RecoveryScoreEngine.swift:197-210` | Reuse if a trend/slope is wanted in the report; not required for core math. [VERIFIED: codebase] |
| `SplitMix64` seedable PRNG | `ShadowMetrics.swift:127-137` | Reuse verbatim for deterministic synthetic-trace noise in the report generator (NOT `SystemRandomNumberGenerator`). [VERIFIED: codebase] |
| Local-only `@Model` template | `SorenessLog.swift`, `CyclePredictionLog.swift` | Exact pattern for the new state model (no Codable, no `*Row`, absent from SyncService). [VERIFIED: codebase] |
| In-memory test container | `SorenessLogModelTests.swift:16-30` | Copy `makeContext()` (must add the new model to the test Schema). [VERIFIED: codebase] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| MAD×1.4826 scale | Welford-σ (sqrt(M2/(n-1))) | Welford-σ is cheaper (no buffer) but NOT robust — one outlier inflates it; defeats the Huber design. Recommend MAD primary, Welford parallel for cross-check/cold-start. |
| Huber clip (soft, k·scale) | Hard winsorize at a fixed percentile | Huber's ±k·scale clip on the innovation is simpler to carry online (no percentile buffer) and is the design-doc's named approach. |
| Rolling-buffer MAD | Online "FAMD"/streaming-median approximations | Streaming-median approximations add complexity and nondeterminism risk; a small fixed rolling buffer (e.g. last 21 innovations) is deterministic, trivially testable, and Foundation-only. |
| Kalman filter | Robust EWMA | **Explicitly rejected** (codex §304: Q/R unidentifiable on sparse consumer data). Do not reintroduce. |

## Package Legitimacy Audit

**N/A — this phase installs no external packages.** All statistics are implemented from cited public recurrences using the iOS SDK (Foundation/SwiftData/XCTest) only. No npm/PyPI/crates install occurs, so no slopcheck gate is required. (Recorded explicitly per the researcher protocol so the planner does not add a spurious `checkpoint:human-verify` for package installs.)

## Architecture Patterns

### System Architecture Diagram (data flow — shadow/parallel, gated OFF)

```
                          ┌─────────────────────────────────────────────┐
  HealthKit raw samples   │  (existing) HealthKitService                 │
  HRV [(date,value)] ─────▶  fetchHRVHistory(days:)        :187-194      │
  RHR latest+date    ─────▶  fetchLatestRestingHRWithDate  :334-338      │
  sleep last-night   ─────▶  fetchLastNightSleepWithDate   :341-373      │
                          └───────────────┬─────────────────────────────┘
                                          │ [(date,value)] per signal
                                          ▼
                          ┌─────────────────────────────────────────────┐
                          │  DayBucketer (NEW, pure struct, §5)          │
                          │  • group HRV/RHR by calendar day             │
                          │  • median of morning window per day          │
                          │  • sleep = last-night aggregate              │
                          │  • dedup repeated stale samples              │
                          │  → ordered [BucketedDay{date, value?}]       │
                          │    value=nil ⇒ GAP (no carry-forward)        │
                          └───────────────┬─────────────────────────────┘
                                          │ one bucketed value (or GAP) per day, ascending
                                          ▼
   ┌──────────────────────────────────────────────────────────────────────────┐
   │  PER DAY t  (PREQUENTIAL ORDER — no leak; mirrors RecoveryPipeline:196)    │
   │                                                                            │
   │   state_{t-1}  ──score──▶  BaselineEngine.score(state_{t-1}, y_t)          │
   │   (loaded from              → innovation = y_t − μ_{t-1}                    │
   │    BaselineState @Model)    → z_t = innovation / max(σ_{t-1}, floor)        │
   │                             → cv_flag (Altini, §3)                          │
   │                                          │                                 │
   │                                          ▼ THEN (never before scoring)     │
   │   state_{t-1}  ──update──▶  BaselineEngine.step(state_{t-1}, y_t)          │
   │                             → Huber-clip innovation to ±k·σ                 │
   │                             → μ_t  = EWMA fold of clipped obs               │
   │                             → M2_t, MAD-buffer_t, count++, cvState_t        │
   │                             → confidence_t  (§4)                            │
   │                                          │                                 │
   │                                          ▼                                 │
   │                          persist state_t in BaselineState @Model (NEW)     │
   │                          (local-only, NEVER synced)                        │
   └──────────────────────────────────────────────────────────────────────────┘
                                          │  (gated OFF)
                                          ▼
                          z_t, cv_flag, confidence_t  →  (Phase 28 fusion; UNUSED this phase)

   ── PARALLEL, LIVE, UNCHANGED ──
   RecoveryScoreEngine.computeBaseline (7-day mean) → RecoveryScoreEngine.compute → live score
```

### Recommended Project Structure (additive only)
```
WorkloadApp/
├── Services/
│   ├── BaselineEngine.swift        # NEW — pure struct: step(), score(), CV, confidence (all static)
│   └── DayBucketer.swift           # NEW — pure struct: HealthKit history → one value/signal/day
├── Models/
│   └── BaselineState.swift         # NEW — local-only @Model, per-athlete per-signal running state
└── App/
    └── WorkloadApp.swift           # EDIT — add BaselineState.self to Schema (additive migration)

WorkloadAppTests/
├── BaselineEngineTests.swift       # NEW — EWMA/MAD/Welford/Huber numerics vs hand-computed
├── DayBucketerTests.swift          # NEW — median window, gap, dedup, no-carry-forward
├── BaselineStateModelTests.swift   # NEW — persistence round-trip (copy SorenessLogModelTests pattern)
└── BaselineConvergenceReportTests.swift  # NEW — seeded report generator → markdown artifact
```

### Pattern 1: Stateless engine, state in SwiftData (project convention)
**What:** The engine never holds state between calls. Each call takes the prior `BaselineState` (a plain value struct mirrored from the `@Model`) + the new observation, returns the next state. The `@Model` is the only mutable carrier.
**When to use:** Always — this is the established pattern (CLAUDE.md: "engines are pure structs with static methods… per-day state persisted in SwiftData, not held in the struct").
**Example shape (NOT production code — illustrative):**
```swift
// Source: mirrors WorkloadCalculator.computeHistoryEWMA (WorkloadCalculator.swift:88-97)
struct BaselineEngine {
    // λ derived from half-life H (days): λ = 1 − 2^(−1/H). See §1.
    static func lambda(halfLifeDays H: Double) -> Double { 1.0 - pow(2.0, -1.0 / H) }

    // PREQUENTIAL read: score today against state carried through yesterday.
    static func score(state s: SignalState, observation y: Double) -> (z: Double, innovation: Double)

    // PREQUENTIAL update: fold today's (Huber-clipped) observation into state.
    static func step(state s: SignalState, observation y: Double, lambda: Double) -> SignalState
}
```

### Pattern 2: Prequential ordering enforced by the caller
**What:** `score()` MUST be called before `step()` for the same day. The Pipeline (or report harness) owns this ordering, exactly as `RecoveryPipeline.swift:196-202` clamps the feature cutoff and asserts it in DEBUG.
**When to use:** Every per-day fold.
**Anti-pattern:** Folding `y_t` into μ and then computing `z_t = (y_t − μ_t)/σ_t` — this leaks today into today's baseline and artificially shrinks z (codex CRITICAL: "predict baseline from yesterday's state, compute today's deviation vs the prior, THEN update").

### Anti-Patterns to Avoid
- **`Date.now` / `Calendar.current` inside the engine.** Engine must be pure and deterministic. All calendar/day logic lives in `DayBucketer` (which takes dates as input) and the caller. The report generator passes synthetic dates. [CITED: D-04, codex MINOR on determinism]
- **`SystemRandomNumberGenerator` in the report.** Use the seeded `SplitMix64` (`ShadowMetrics.swift:127`) so the report is byte-reproducible. [VERIFIED: codebase]
- **Updating from a repeated stale HealthKit sample.** Same physical sample reappearing across days fakes stability (codex MAJOR). Dedup by sample date in `DayBucketer`; a day with no *fresh* sample is a GAP, not an update. [CITED: D-02a]
- **CV of raw HRV as the "magic" signal.** CV on raw values centered near a large mean understates instability; CV must be on **innovations/residuals** and treated as context, not a hard predictor (codex MAJOR). [CITED: §3]
- **Mean-imputing a gap.** No carry-forward, no imputation — a gap reduces confidence and is skipped in the fold. [CITED: D-02/D-03]
- **Touching live `RecoveryScoreEngine.compute` output or `SyncService`.** Out of phase scope; gated OFF parallel only.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Numerically-stable online variance | Naive `Σx² − (Σx)²/n` | **Welford M2 recurrence** (§1) | Catastrophic cancellation produces negative variances when mean ≫ variance (HRV ~50ms, σ small). [CITED: en.wikipedia.org/wiki/Algorithms_for_calculating_variance] |
| Seedable deterministic RNG | New PRNG | Existing `ShadowMetrics.SplitMix64` | Already in-repo, tested deterministic under seed (`ShadowMetricsTests.swift:91`). [VERIFIED: codebase] |
| Robust scale from median | Custom outlier filter | **MAD × 1.4826** (§1) | The 1.4826 Fisher-consistency constant makes MAD a drop-in σ estimator under normality; reinventing thresholds is error-prone. [CITED: en.wikipedia.org/wiki/Median_absolute_deviation] |
| Local-only model plumbing | New sync-exclusion mechanism | Mirror `SorenessLog` (omission from SyncService) | Privacy-by-omission is the established convention; the type name simply never appears in `SyncService.swift`. [VERIFIED: codebase] |
| Prequential cutoff | New leak-boundary | Extend `RecoveryPipeline:196-202` discipline | Phase 24 already defines/asserts the cutoff; reuse the pattern, don't reinvent. [VERIFIED: codebase] |

**Key insight:** Every primitive here is a public, decades-old recurrence (Welford 1962, MAD 1.4826, Huber 1964, EWMA half-life). The value is the *composition under prequential discipline + honest confidence + on-device state*, not novel math. Hand-rolling the unstable variants (naive variance, raw-HRV CV, carry-forward imputation) is exactly what the codex verdict warns against.

---

## 1. Robust baseline math — exact per-signal update

Maintain, **per signal** *s* ∈ {HRV, RHR, sleep}, this carried state (all in the `@Model`, §6):
`μ` (EWMA baseline mean), `M2`, `count` (Welford accumulators), a small `madBuffer` (last *W* innovations), `lastBucketedDate`, plus CV state (§3) and confidence inputs (§4).

### 1.1 EWMA mean with per-signal half-life → λ

The EWMA fold (mirroring `WorkloadCalculator.swift:92`):
```
μ_t = (1 − λ_s)·μ_{t-1} + λ_s·ŷ_t        // ŷ_t = Huber-clipped observation, §1.3
```
Half-life → λ conversion (standard exponential decay; half-life H = #days for weight to halve):
```
λ_s = 1 − 2^(−1/H_s) = 1 − exp(−ln2 / H_s)
```
[CITED: gregorygundersen.com/blog/2022/06/04/moving-averages — λ/half-life/α parameterizations] [VERIFIED: math — λ=1−2^(−1/H)]

**Recommended per-signal half-lives (named constants; Claude's-discretion picks, justified):**
| Signal | Half-life H_s | λ_s | Justification |
|--------|---------------|-----|---------------|
| HRV (SDNN) | **7 days** | ≈ 0.0943 | Altini publishes a 7-day baseline as the standard HRV reference; matches the incumbent 7-day mean's responsiveness so the shadow comparison is apples-to-apples while gaining robustness. [CITED: marcoaltini.substack.com/p/stability-in-heart-rate-variability] |
| RHR | **10 days** | ≈ 0.0670 | RHR drifts more slowly and is less noisy than HRV; a slightly longer half-life reduces day-to-day jitter without losing real fatigue trends. [ASSUMED] |
| Sleep duration | **7 days** | ≈ 0.0943 | Weekly rhythm (weekday/weekend) argues for ≥7-day memory; 7d keeps it responsive to a new routine. [ASSUMED] |

> Cross-check vs incumbent: a flat 7-day mean ≈ EWMA with α=1/7≈0.1429 (λ here uses half-life, not window, so 7-day *half-life* λ≈0.094 is intentionally a touch smoother — flag in report). The planner may alternatively set λ_HRV = 1/7 to match the incumbent exactly; recommend documenting whichever is chosen as a single named constant.

### 1.2 Online dispersion (carry BOTH; MAD primary)

**Welford M2 (numerically stable variance) — carried for cross-check + cold-start fallback:**
```
delta   = ŷ_t − μ_{t-1}^{welford}           // uses a SEPARATE simple running mean, not the EWMA μ
mean    = mean + delta / count
delta2  = ŷ_t − mean
M2      = M2 + delta · delta2
σ_welford = sqrt(M2 / (count − 1))           // sample SD, count ≥ 2
```
[CITED: en.wikipedia.org/wiki/Algorithms_for_calculating_variance — Welford M2 recurrence] [VERIFIED: math]

**Rolling MAD scale (PRIMARY robust spread):** keep a fixed-length ring buffer of the last **W = 21** *innovations* `r_i = y_i − μ_{i-1}` (pre-update residuals, NOT clipped). Each day:
```
m       = median(buffer)
MAD     = median(|r_i − m|  for r_i in buffer)
σ_mad   = 1.4826 · MAD
```
[CITED: en.wikipedia.org/wiki/Median_absolute_deviation — k=1/Φ⁻¹(0.75)≈1.4826] [VERIFIED: math]

**Active scale** used downstream (§2 z, §1.3 Huber, §3 CV):
```
σ_s = max(σ_mad, σ_floor_s)        // MAD primary; floor prevents divide-by-tiny, §2.3
```
Use `σ_welford` only (a) while `buffer.count < W_min` (e.g. < 5) as a cold-start fill, and (b) as a numeric-sanity assertion in tests (σ_mad and σ_welford should be the same order of magnitude on clean Gaussian fixtures).

**Why both:** MAD is robust (the whole point of the Huber design) but needs a buffer and ≥~5 points to be meaningful; Welford is cheap and always-available but non-robust. Carrying both gives a principled cold-start (Welford) → robust steady-state (MAD) handoff and a free test oracle. [VERIFIED: design reasoning grounded in cited sources]

### 1.3 Huber / winsorized update rule (bounded smoothing)

Before folding the observation into μ, **clip the innovation** to ±k·σ (Huber's bounded-influence idea applied online):
```
r_t  = y_t − μ_{t-1}                         // raw innovation (this is what §2/§3 also score on)
r̂_t = clamp(r_t, −k·σ_s, +k·σ_s)            // Huber clip
ŷ_t = μ_{t-1} + r̂_t                          // clipped observation fed to the EWMA fold (§1.1)
```
**Tuning constant k:** recommend **k = 1.5** (named constant `huberK`). Rationale: the classic Huber regression default is **k = 1.345** for ~95% Gaussian efficiency; on noisy single-subject HRV a slightly looser **1.5** keeps a touch more responsiveness to genuine multi-day shifts while still clamping a lone aberrant night to ≤1.5σ of influence. Both are defensible; 1.345 if the report shows the baseline chasing outliers, 1.5 as the default. [CITED: statsmodels HuberT default 1.345, 95% efficiency] [ASSUMED: 1.5 vs 1.345 choice for HRV]

**Bounded smoothing (codex requirement):** λ_s is a fixed named constant per signal (no per-user learning), and the Huber clip bounds each step's influence to ±k·σ. Together these guarantee the baseline can neither be yanked by one outlier (Huber) nor adapt unboundedly fast (fixed λ). [CITED: algorithm-moat-design.md §304]

**Note — what each consumer uses:**
- **z-score (§2)** and **CV (§3)** use the **raw** innovation `r_t` (we want to *detect* deviation, not hide it).
- **The μ update (§1.1)** uses the **clipped** `ŷ_t` (we don't want the baseline to chase the deviation).
This split is the crux: detect honestly, update robustly.

---

## 2. Prequential (no-leak) z-score

### 2.1 Exact ordering (per day t, ascending)
```
1. LOAD   state_{t-1}  (μ_{t-1}, σ_{t-1}=max(σ_mad,floor), buffers, count)   ← from BaselineState @Model
2. SCORE  innovation r_t = y_t − μ_{t-1}
          z_t = r_t / σ_{t-1}                    // σ from t-1 ONLY
          (sign-correct: HRV positive-is-good as-is; RHR negate so +z = better)
3. CV     update CV state from r_t (§3), read cv_flag_t
4. UPDATE state_t = step(state_{t-1}, y_t):  Huber-clip → EWMA μ → Welford M2 → push r_t to MAD buffer → count++
5. CONF   confidence_t (§4)
6. PERSIST state_t
```
The invariant: **step 4 never runs before steps 2–3.** This mirrors `RecoveryPipeline.swift:196-202` (feature cutoff = predictionDate, asserted in DEBUG) and the Phase 24 contract (`CyclePredictionLog` predictionDate/targetDate, `CyclePredictionLog.swift:36-43`). For Phase 26 the "prediction" is the baseline-as-of-yesterday; today's bucketed sample is the actual scored against it. [VERIFIED: codebase RecoveryPipeline:196-202]

### 2.2 σ definition for z
Use the **active scale σ_s = max(σ_mad, σ_floor_s)** from §1.2 (MAD-based, robust). Do NOT use the post-update σ. Do NOT use the EWMA-of-squared-innovations as the *primary* (it is non-robust); the planner MAY additionally carry an EWMA-σ for the report's comparison panel, but the shipped z uses MAD-scale.

### 2.3 Floor to avoid divide-by-tiny
`σ_floor_s` is a per-signal named constant in the signal's own units, preventing z blow-ups when early dispersion is ~0 (e.g. first few identical readings, or a very stable sleeper). Recommended starting floors (planner tunes from the report):
| Signal | Unit | `σ_floor` | Basis |
|--------|------|-----------|-------|
| HRV SDNN | ms | **3.0 ms** | Typical healthy SDNN day-to-day SD is ~5–15 ms; 3 ms is a conservative non-zero floor. [ASSUMED] |
| RHR | bpm | **1.5 bpm** | RHR day-to-day SD ~2–5 bpm; 1.5 floor. [ASSUMED] |
| Sleep | minutes | **15 min** | Sleep duration SD tens of minutes; 15-min floor. [ASSUMED] |

Also guard `count` / buffer size: while `count < 2` (Welford) and `madBuffer.count < W_min`, **z is undefined → return nil** (do not fabricate). The report and tests must cover this cold-start nil.

### 2.4 Tie to Phase-24 date contract
The bucketed day's `date` is `Calendar.startOfDay`. `state.lastBucketedDate` is the last day folded. A new day *t* is only scored/updated if `startOfDay(t) > lastBucketedDate` (strictly after) — this is the same monotonic-cutoff discipline as `RecoveryPipeline:199`. Re-presenting the same day (idempotency) must NOT double-update — the engine/caller checks `lastBucketedDate` first. [CITED: CyclePredictionLog.swift:36-43; RecoveryPipeline.swift:196-202]

---

## 3. Altini CV early-warning (rolling CV of innovations)

The design doc's core Altini citation: the day-to-day **coefficient of variation often flags disrupted homeostasis before the baseline mean moves** ("variability in variability"). [CITED: algorithm-moat-design.md:44; marcoaltini.substack.com/p/variability-in-variability]

### 3.1 What it runs on
**Innovations / residuals** `r_i = y_i − μ_{i-1}` (pre-update, raw), NOT raw HRV. Rationale: raw-HRV CV is dominated by the large mean and is "mathematically suspect, centered near a large value" (codex MAJOR). The residual stream is mean-centered-ish, so its *dispersion over time* is the volatility-of-volatility Altini describes.

### 3.2 Definition (rolling absolute-deviation, recommended over literal CV)
Because residuals are centered near 0, a literal `CV = SD/mean` of residuals is unstable (mean≈0). Instead track a **rolling robust dispersion of residuals** and compare short vs long windows — the operational form of "variability in variability":
```
recentScale  = 1.4826 · median(|r_i|  over last  N_short = 7 residuals)
baselineScale = 1.4826 · median(|r_i| over last  N_long  = 28 residuals)
cvRatio_t    = recentScale / max(baselineScale, σ_floor_s)
```
`cvRatio_t > 1` ⇒ recent residuals are *more* variable than the personal baseline variability = early disruption.

> Naming note: the design doc calls this "CV"; we implement it as a **dispersion ratio of innovations** (the honest, stable form). Keep the user-facing/report label "variability-in-variability (CV)" but document the ratio definition. [CITED: codex MAJOR — "use rolling SD/MAD … treat as volatility/context, not a magic signal"]

### 3.3 Fire / clear thresholds (hysteresis) + output
Output is a **3-level flag**, not a number gate (avoids flapping):
```
enum CVWarning { case normal, elevated, high }
fire  HIGH      when cvRatio ≥ 1.5  AND  N_long-window has ≥ 14 valid residuals
fire  ELEVATED  when cvRatio ≥ 1.25
clear to NORMAL when cvRatio ≤ 1.10           // hysteresis gap prevents oscillation
suppressed (.normal, low-confidence) when valid residuals < N_short_min (e.g. 7)
```
Recommended named constants: `cvShortWindow=7`, `cvLongWindow=28`, `cvElevated=1.25`, `cvHigh=1.5`, `cvClear=1.10`, `cvMinValid=14`. The thresholds are tunable; the report's "CV fires on injected instability, stays quiet on clean" panel is how the planner calibrates them. [ASSUMED: exact threshold values; structure is design-grounded]

**Early-warning semantics:** the flag is a *context* output for Phase 28, never a prediction this phase. It is carried in state (last cvRatio + current level for hysteresis) and emitted alongside z + confidence.

---

## 4. Confidence model (composite 0–1, no population prior)

Confidence is a continuous multiplier in [0,1] combining three honest factors. **No sex/age physiology prior** — cold-start is low because we genuinely lack data, not because we borrow a population mean. [CITED: D-03]

### 4.1 Three components
```
c_count   = clamp01( (validCount − floorDays) / (fullDays − floorDays) )     // observation count ramp
c_recency = exp( −daysSinceLastBucket / τ_recency )                          // staleness decay
c_disp    = clamp01( 1 − (cvRatio − 1) / dispSpan )                          // recent dispersion penalty
```
- `validCount` = number of non-gap days folded for this signal.
- `daysSinceLastBucket` = `startOfDay(today) − lastBucketedDate` in days (0 if fresh today).
- `cvRatio` from §3 (high recent variability ⇒ lower confidence).

### 4.2 Combine + ramp (D-03a)
```
confidence_s = c_count · c_recency · c_disp        // product: any one being low pulls it down (honest)
```
**Named constants (recommended defaults):**
| Constant | Value | Meaning | Basis |
|----------|-------|---------|-------|
| `floorDays` | **14** | below this, confidence floor ≈ 0; z "untrusted" | D-03a "~14 bucketed days" |
| `fullDays` | **60** | reaches full count-confidence here | D-03a "60-day normal band" |
| `τ_recency` | **2.0 days** | staleness half-ish-life; a 2-day-old value ⇒ c_recency≈0.37 | D-02a "older than ~2 days → reduce confidence" |
| `dispSpan` | **1.0** | cvRatio of 2.0 ⇒ c_disp=0; cvRatio≤1 ⇒ c_disp=1 | ties §3 to confidence |
| `staleHardCutDays` | **7** | beyond this, treat signal as effectively absent (confidence ~0) | D-02a generalization [ASSUMED] |

`clamp01(x) = min(1, max(0, x))`.

### 4.3 Cold-start behavior (explicit)
- Day 0–13: `c_count ≈ 0` ⇒ confidence ≈ 0, z may be nil (σ undefined) → report/consumer shows "calibrating, not enough data." No physiology claim.
- Day 14–59: confidence ramps linearly via `c_count`, modulated by recency/dispersion.
- Day ≥60 with fresh, stable data: confidence ≈ 1.
- A gap or stale stretch instantly cuts `c_recency` regardless of count (a 5-day-old baseline is low-confidence even at 200 observations). [CITED: D-03a, codex MAJOR "separate confidence from valid-sample count/staleness"]

**Composite (cross-signal) confidence** for the report: `min` or count-weighted mean of the per-signal confidences (planner picks; `min` is the honest/conservative choice). Recommend the report shows per-signal AND composite.

---

## 5. Day-bucketing (HealthKit → one value/signal/day)

`DayBucketer` (NEW pure struct) consumes existing HealthKitService outputs and emits, per signal, an ascending array of `BucketedDay { date: Date (startOfDay), value: Double? }` where `value == nil` is a GAP.

### 5.1 Per-signal rules (D-02)
| Signal | Source | Bucketing rule |
|--------|--------|----------------|
| HRV SDNN | `HealthKitService.fetchHRVHistory(days:)` → `[(date,value)]` (`:187-194`) | Group samples by `Calendar.startOfDay(of: sample.date)`; within each day keep only samples in the **morning window** (§5.2); the day's value = **median** of those. No morning sample ⇒ GAP for that day. [VERIFIED: fetch shape] |
| RHR | `fetchLatestRestingHRWithDate()` → `(value,date)` (`:334-338`) | RHR is published by HealthKit as a daily summary; bucket by `startOfDay(of: date)`. For history, a `fetchRestingHRHistory(days:)` of the same `[(date,value)]` shape should be added (mirror `fetchHRVHistory`) so RHR can be day-bucketed like HRV — **note this as a small additive helper the plan needs** (see Environment Availability). [VERIFIED: only `fetchLatest*` exists today] |
| Sleep | `fetchLastNightSleepWithDate()` → `(minutes,date)` (`:341-373`) | Already a last-night aggregate keyed to the night's end date. Bucket by `startOfDay(of: latestDate)`. One value per night = one value per day. [VERIFIED: fetch shape] |

### 5.2 Morning window definition (HRV/RHR)
"Overnight / first-morning sample window": recommend **00:00–11:00 local** (named constant `morningWindowEndHour = 11`), taking the **median** of in-window samples for the day. Rationale: HRV/RHR readings from wearables (Oura/Whoop/Apple Watch) are overnight/on-waking; excluding afternoon spikes is the Altini-aligned robust choice (D-02). The window bounds are tunable named constants. [CITED: D-02; ASSUMED exact 11:00 cutoff]

> If HealthKit returns only a single daily-summary sample (common for RHR, sometimes HRV), median-of-one = that value — the rule degrades gracefully.

### 5.3 Gap representation + no carry-forward (D-02/D-02a)
- A calendar day with no fresh in-window sample for a signal ⇒ `BucketedDay(date: day, value: nil)` (GAP).
- The fold **skips** GAP days for the μ/M2/MAD update (no carry-forward, no imputation) but **advances `daysSinceLastBucket`**, which lowers `c_recency` (§4). So gaps don't corrupt the baseline; they correctly erode confidence. [CITED: D-02a]

### 5.4 Stale-sample dedup (codex MAJOR)
HealthKit `fetchLatest*` can return the **same physical sample** across multiple days (watch not worn). Dedup rule:
```
A sample is "fresh for day t" only if startOfDay(sample.date) == t.
If the latest available sample's day < t  →  day t is a GAP (NOT an update from the stale sample).
Never fold the same (date,value) twice — guard via state.lastBucketedDate (§2.4).
```
[CITED: codex "HealthKit fetchLatest* can return the same stale sample across days → fake stability"]

### 5.5 Map to outputs (summary)
- HRV: history fetch exists (`:187`) → bucketable today. ✓
- Sleep: dated last-night fetch exists (`:341`) → bucketable today. ✓
- RHR: only `fetchLatest*WithDate` exists; needs an additive `fetchRestingHRHistory(days:)` helper (trivial mirror of HRV) for multi-day bucketing. ⚠ (planner task)

---

## 6. Per-day state model (NEW local-only `@Model`)

### 6.1 Shape (recommended: ONE row per athlete, all signals embedded)
Rather than three rows per athlete (one per signal), embed three signal sub-states in a single `BaselineState` row keyed by athlete — fewer rows, atomic upsert, mirrors how `CyclePredictionLog` holds many parallel columns. SwiftData `@Model` can't easily nest a Codable sub-struct without `Codable` (forbidden here), so **flatten** the three signals as prefixed scalar fields.

```swift
// Source: structure mirrors SorenessLog.swift / CyclePredictionLog.swift (local-only template)
@Model
final class BaselineState {
    @Attribute(.unique) var id: UUID
    var athlete: Athlete?              // bare inverse, like SorenessLog.athlete (no array on Athlete)
    var updatedAt: Date

    // ---- HRV sub-state ----
    var hrvMu: Double?                 // EWMA baseline μ (nil until first fold)
    var hrvWelfordMean: Double         // simple running mean for Welford
    var hrvM2: Double                  // Welford sum-of-squared-deviations
    var hrvCount: Int                  // valid (non-gap) folds
    var hrvMadBuffer: [Double]         // last W innovations (SwiftData supports [Double] of scalars)
    var hrvLastBucketedDate: Date?     // monotonic cutoff (§2.4)
    var hrvCvRatio: Double?            // last §3 ratio (for hysteresis)
    var hrvCvLevelRaw: String         // "normal"/"elevated"/"high" (hysteresis state)
    var hrvConfidence: Double          // last §4 confidence

    // ---- RHR sub-state ---- (same field set, rhr* prefix)
    // ---- Sleep sub-state ---- (same field set, sleep* prefix)

    init(id: UUID = UUID(), athlete: Athlete? = nil) { /* zero-init accumulators */ }
}
```
**Notes:**
- **No `Codable`.** No `*Row` DTO. No `push*`/`pull*`. The string "BaselineState" appears **nowhere** in `SyncService.swift` (privacy-by-omission — verified the existing local-only models are absent there). [VERIFIED: SyncService has zero refs to SorenessLog/CyclePredictionLog/MenstrualCycleSnapshot]
- **`[Double]` array attribute:** SwiftData persists arrays of scalar `Codable`-conforming primitives natively (Double is fine) — this does NOT make the *model* Codable and does not trigger sync. If the planner prefers to avoid any array, store the MAD buffer as a fixed set of `madSlot0..madSlotN` Doubles or a single packed string; the array is cleaner. [ASSUMED: planner confirms array attribute persists in the in-memory test container]
- **Welford mean is separate from EWMA μ** (different estimators; §1.2).
- `hrvMu` etc. are **Optional** so "no fold yet" is distinguishable from "μ==0".

### 6.2 Schema registration (additive, lightweight migration)
Add `BaselineState.self` to the `Schema([...])` array in `WorkloadApp.swift:70-81` (currently ends at `SorenessLog.self` `:80`). New standalone model with no relationships to existing required fields ⇒ SwiftData lightweight automatic migration; no manual migration plan needed. [VERIFIED: WorkloadApp.swift:70-80]

The **test** Schema in each model test must also include `BaselineState.self` (copy `SorenessLogModelTests.swift:17-24` and append). [VERIFIED: codebase pattern]

### 6.3 Engine stays stateless
`BaselineEngine` operates on a plain value mirror (e.g. `struct SignalState { var mu: Double?; var welfordMean: Double; var m2: Double; var count: Int; var madBuffer: [Double]; var lastBucketedDate: Date?; var cvRatio: Double?; var cvLevel: CVWarning; var confidence: Double }`). The caller reads the `@Model` → builds `SignalState` → calls `score`/`step` → writes fields back. This keeps the engine pure and trivially unit-testable without SwiftData. [CITED: CLAUDE.md engine convention]

---

## 7. Seeded convergence report (the D-04 deliverable)

### 7.1 Where it lives
`WorkloadAppTests/BaselineConvergenceReportTests.swift` — an XCTest that, when run, **generates a markdown artifact**. It is a "test" only as a deterministic execution harness (it asserts a few invariants AND writes the report). No app/device code.

### 7.2 Determinism (no `Date.now`, no system RNG)
- Synthetic dates: start from a fixed anchor `Date(timeIntervalSince1970: 0)` (or any constant) and add `i` days via `Calendar`. Never `.now`.
- Noise: `ShadowMetrics.SplitMix64(seed: …)` (`ShadowMetrics.swift:127`) — reuse verbatim. Each scenario uses a fixed seed so the report is byte-reproducible across runs/machines. [VERIFIED: codebase]
- The engine itself contains no time/RNG, so determinism is structural.

### 7.3 Synthetic + realistic traces (fixtures)
Generate, per signal, day-indexed traces with known ground truth so the report can show tracking error:
| Trace | Construction | What it proves |
|-------|--------------|----------------|
| **Stable** | constant mean + small Gaussian noise (seeded) | μ converges to truth; z ~ N(0,1); CV stays `.normal`; confidence ramps 14→60. |
| **Step change** | mean shifts +Δ at day k | baseline tracks the new level within ~half-life; z spikes then re-centers; bounded smoothing (no overshoot). |
| **Outlier injection** | stable + a single ±6σ spike | Huber clips it: μ barely moves (vs naive EWMA which jumps); z flags the spike; baseline robust. |
| **Gap stretch** | stable but days k..k+5 are GAPs | μ unchanged across gap; `c_recency` collapses then recovers; no carry-forward artifact. |
| **Stale repeat** | same sample value/date repeated 4 days | dedup ⇒ those days are GAPs, not 4 fake-stable updates; confidence drops. |
| **Rising instability** | variance ramps up over a window (mean flat) | **CV fires** (`.elevated`→`.high`) even though μ is flat — the Altini "variability in variability" demonstration. |
| **Realistic HRV** | seeded trace loosely modeled on overnight SDNN (mean ~50ms, weekly rhythm, occasional bad night) | end-to-end sanity: tracking, z distribution, CV, confidence together. |

### 7.4 Report contents (markdown)
For each scenario, emit:
- A small ASCII/Markdown table or sparkline-style series: `day | raw y | μ (EWMA) | 7-day-mean (incumbent) | z | σ | cvRatio | cvLevel | confidence`.
- Summary stats: tracking error `mean|μ − truth|` (robust vs incumbent 7-day mean, to show the win), z mean/SD (should be ~0/~1 on stable), day CV first fires, day confidence crosses 0.5 and 0.9.
- A PASS/FAIL line per invariant (e.g. "outlier moved μ by < X" — also asserted in-test so CI catches regressions).

### 7.5 Artifact path + format
Write to a stable, git-trackable path so the user can review it as the Phase 26 checkpoint:
```
.planning/phases/26-individualized-baselines/artifacts/26-convergence-report.md
```
Use `FileManager` + `String.write(to:atomically:encoding:)`. Resolve the repo path from a constant or an env var (`BASELINE_REPORT_DIR`) with a fallback to the test bundle's temp dir if the path is unwritable (so it never hard-fails in sandboxed CI). The planner decides whether the committed artifact or a re-generate-on-demand step is the checkpoint surface. [ASSUMED: exact path under the phase dir; matches repo's `.planning/` convention]

---

## 8. Test plan + risks

### 8.1 Unit tests (proving correctness)
| Test | File | Asserts |
|------|------|---------|
| EWMA fold matches hand-computed | `BaselineEngineTests` | Known λ + sequence ⇒ μ equals manually-computed value to 1e-9. |
| `lambda(halfLifeDays:)` = 1−2^(−1/H) | `BaselineEngineTests` | H=7 ⇒ λ≈0.0943; H=∞ ⇒ λ→0. |
| Welford M2 vs two-pass variance | `BaselineEngineTests` | On a fixed array, `M2/(n−1)` equals `Σ(x−x̄)²/(n−1)` to 1e-9 (numerical-stability oracle). |
| MAD×1.4826 vs hand-computed median-of-abs-dev | `BaselineEngineTests` | Known buffer ⇒ exact σ_mad. |
| Huber clips an outlier | `BaselineEngineTests` | A +6σ reading moves μ by ≤ the k·σ-bounded amount; un-clipped EWMA would move more (assert the gap). |
| Prequential no-leak ordering | `BaselineEngineTests` | `z` computed with σ_{t-1}; folding y_t first would change z — assert score-before-update via a constructed case where the two orders differ. |
| Divide-by-tiny floor | `BaselineEngineTests` | Identical early readings ⇒ σ floored, z finite (no inf/nan); count<2 ⇒ z nil. |
| Confidence ramp | `BaselineEngineTests` | confidence≈0 at day≤14, monotone ↑ to ~1 by day 60 on fresh stable data; collapses after a stale stretch. |
| CV fires on injected instability | `BaselineEngineTests` | flat-mean rising-variance trace ⇒ level reaches `.high`; clean trace stays `.normal`; hysteresis (no flap on a borderline ratio). |
| Bucketing: median window | `DayBucketerTests` | Multiple morning samples ⇒ median; afternoon samples excluded. |
| Bucketing: gap | `DayBucketerTests` | Day with no in-window sample ⇒ `value=nil`; not carried forward. |
| Bucketing: stale dedup | `DayBucketerTests` | Same (date,value) across calls ⇒ folded once; subsequent days = GAP. |
| Model persistence round-trip | `BaselineStateModelTests` | All fields (incl `[Double]` buffer) survive insert→save→fetch (copy `SorenessLogModelTests`). |
| Local-only (no sync) | `BaselineStateModelTests` or grep test | "BaselineState" absent from `SyncService.swift` (a string-grep test mirrors the privacy-by-omission convention). |
| Report determinism | `BaselineConvergenceReportTests` | Two runs with same seed ⇒ identical markdown (hash equality). |

### 8.2 Risks
| Risk | Severity | Mitigation |
|------|----------|------------|
| **Numerical stability** (HRV mean≫variance) | MED | Welford M2 (cited stable recurrence), never naive `Σx²−(Σx)²/n`; cross-check test vs two-pass. |
| **Sparse / cold-start data** (z nil, MAD buffer < W_min) | MED | Explicit nil-z + Welford-fallback scale + confidence≈0; tests cover the <14-day regime; report's "stable" trace shows the ramp. |
| **7-day mean MUST stay the LIVE source** | HIGH | NO edits to `RecoveryScoreEngine.compute` output or `RecoveryPipeline` recovery-score path; new baseline is parallel/gated-OFF; a test asserts `RecoveryScoreEngine.computeBaseline` is unchanged and still called. The phase's tier map explicitly fences live behavior. |
| **`[Double]` SwiftData attribute** persistence uncertainty | LOW | Round-trip test in the in-memory container; fallback to packed-scalar fields if it fails. |
| **RHR history fetch missing** | LOW | Additive `fetchRestingHRHistory(days:)` helper (trivial mirror of `fetchHRVHistory`); flagged in Environment Availability. |
| **CV threshold mis-tuning** (false fires) | MED | Hysteresis + min-valid gate + report calibration panel; thresholds are named constants, not magic. |
| **Determinism leak** (`Date.now`/system RNG sneaking into report) | MED | Engine has zero time/RNG; report uses fixed anchor + `SplitMix64`; hash-equality test. |
| **Over-personalization on thin data** | LOW (deferred) | No per-user learning this phase (fixed λ, fixed k); confidence honestly low until data accrues. |

### 8.3 Recommended tunable-constant defaults (single source for the planner)
| Constant | Default | §ref |
|----------|---------|------|
| `hrvHalfLifeDays` | 7 | §1.1 |
| `rhrHalfLifeDays` | 10 | §1.1 |
| `sleepHalfLifeDays` | 7 | §1.1 |
| `madScaleK` (1.4826) | 1.4826 | §1.2 |
| `madBufferLength W` | 21 | §1.2 |
| `madMinValid W_min` | 5 | §1.2 |
| `huberK` | 1.5 (or 1.345) | §1.3 |
| `hrvSigmaFloor` | 3.0 ms | §2.3 |
| `rhrSigmaFloor` | 1.5 bpm | §2.3 |
| `sleepSigmaFloor` | 15 min | §2.3 |
| `cvShortWindow` | 7 | §3.2 |
| `cvLongWindow` | 28 | §3.2 |
| `cvElevated` | 1.25 | §3.3 |
| `cvHigh` | 1.5 | §3.3 |
| `cvClear` | 1.10 | §3.3 |
| `cvMinValid` | 14 | §3.3 |
| `confFloorDays` | 14 | §4.2 |
| `confFullDays` | 60 | §4.2 |
| `confTauRecency` | 2.0 days | §4.2 |
| `confDispSpan` | 1.0 | §4.2 |
| `staleHardCutDays` | 7 | §4.2 |
| `morningWindowEndHour` | 11 | §5.2 |

## Runtime State Inventory

> This is an additive greenfield feature (new engine + new model), NOT a rename/refactor. Inventory included for safety; most categories are "None."

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | New `BaselineState` rows written on-device only. No existing data is renamed or migrated. | None — additive. |
| Live service config | None — no external service. | None. |
| OS-registered state | None. | None. |
| Secrets/env vars | Optional `BASELINE_REPORT_DIR` (test-only, report output path). | None — local dev convenience. |
| Build artifacts | New `@Model` requires `BaselineState.self` in `WorkloadApp.swift` Schema (additive lightweight migration) + each test Schema. | Schema edit (verified safe, §6.2). |

**Verified:** `SyncService.swift` contains zero references to existing local-only models (`SorenessLog`/`CyclePredictionLog`/`MenstrualCycleSnapshot`) — confirming the privacy-by-omission convention the new model follows.

## Common Pitfalls

### Pitfall 1: Same-day leak (folding before scoring)
**What goes wrong:** z_t computed against a μ that already absorbed y_t → z artificially small, baseline looks "too good."
**Why it happens:** Natural to update state then read it.
**How to avoid:** Enforce score()→step() ordering; assert in DEBUG like `RecoveryPipeline:201`. Test constructs a case where the two orders diverge.
**Warning signs:** z distribution far narrower than N(0,1) on the stable trace.

### Pitfall 2: Naive variance underflow on HRV
**What goes wrong:** `Σx²−(Σx)²/n` returns tiny/negative variance when mean (~50) ≫ variance.
**How to avoid:** Welford M2 only. **Warning signs:** negative variance, NaN σ, z = inf.

### Pitfall 3: Stale HealthKit sample faking stability
**What goes wrong:** `fetchLatest*` returns the same overnight sample for days → 4 "stable" updates that aren't real data.
**How to avoid:** Dedup by sample day; stale ⇒ GAP (§5.4). **Warning signs:** confidence high but `daysSinceLastBucket` large.

### Pitfall 4: CV on raw HRV (centered near 50ms) instead of innovations
**What goes wrong:** CV dominated by the mean, never fires meaningfully.
**How to avoid:** CV/dispersion-ratio on **innovations** (§3.1).

### Pitfall 5: Accidentally changing the live score
**What goes wrong:** A task edits `RecoveryScoreEngine.compute` or the pipeline's recovery path, shipping the new baseline live before validation.
**How to avoid:** Tier fence — new baseline is parallel/gated-OFF; test asserts `computeBaseline` unchanged and the live `compute()` signature/behavior is byte-identical.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Flat 7-day rolling mean (`computeBaseline`) | Robust EWMA + MAD/Welford + Huber, prequential z, Altini CV | This phase (parallel, gated OFF) | Personal probabilistic baseline with honest confidence; live behavior unchanged until Phase 28/29. |
| Kalman filter (original PRS spec) | Robust EWMA/Welford/MAD | codex v1 verdict 2026-05-30 | Q/R unidentifiable on consumer data; EWMA is the bounded, identifiable choice. |
| Raw-HRV CV | Dispersion-ratio of innovations | codex MAJOR | Mathematically sound volatility-of-volatility signal. |

**Deprecated/outdated for this phase:** Kalman per-user Q/R; per-user weight learning; population sex/age cold-start prior — all explicitly rejected in CONTEXT.md / codex verdict. Do not reintroduce.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | HRV half-life 7d / RHR 10d / sleep 7d are good defaults | §1.1 | LOW — tunable named constants; report calibrates; only affects shadow, not live. |
| A2 | Huber k=1.5 (vs canonical 1.345) | §1.3 | LOW — both defensible; report shows if baseline chases outliers → drop to 1.345. |
| A3 | σ floors (3ms / 1.5bpm / 15min) | §2.3 | LOW — only prevents divide-by-tiny; over-large floor flattens z, visible in report. |
| A4 | CV thresholds (1.25 elevated / 1.5 high / 1.10 clear) + windows (7/28) | §3.2-3.3 | MED — governs false-fire rate; calibrated via the report's CV panel before any Phase-28 use. |
| A5 | Confidence constants (τ=2d, dispSpan=1.0, staleHardCut=7d) | §4.2 | LOW-MED — honest-low-confidence is the safe failure mode; report shows the ramp. |
| A6 | Morning window = 00:00–11:00 local | §5.2 | MED — wrong cutoff could drop valid overnight samples on some wearables; tunable; verify against real device data in a later QA. |
| A7 | SwiftData persists a `[Double]` attribute in the in-memory test container | §6.1 | LOW — round-trip test catches it; packed-scalar fallback exists. |
| A8 | Report artifact path under `.planning/phases/26-individualized-baselines/artifacts/` | §7.5 | LOW — cosmetic; planner may relocate. |
| A9 | `fetchRestingHRHistory(days:)` is a trivial additive mirror of `fetchHRVHistory` | §5.5 | LOW — verified `fetchHRVHistory` shape; the mirror is mechanical. |

**No locked decision rests on an assumption** — every D-01..D-04 mandate is satisfied by design-grounded or cited mechanics; the assumptions are all tunable-constant values the seeded report exists to calibrate.

## Open Questions

1. **RHR history fetch**
   - What we know: only `fetchLatestRestingHRWithDate()` exists; HRV has `fetchHRVHistory(days:)`.
   - What's unclear: whether the planner adds the mirror helper now or buckets RHR from a different source.
   - Recommendation: add a trivial `fetchRestingHRHistory(days:)` (mirror of HRV) so all three signals bucket uniformly. Small additive HealthKitService task.

2. **One `BaselineState` row vs three (per-signal)**
   - What we know: both work; one-row is fewer rows + atomic upsert, three-row is cleaner separation.
   - Recommendation: one row, flattened signal sub-states (§6.1). Planner may override; either passes the local-only/no-Codable constraints.

3. **λ to match incumbent exactly?**
   - What we know: flat 7-day mean ≈ EWMA α=1/7≈0.143; 7-day *half-life* λ≈0.094 is slightly smoother.
   - Recommendation: keep half-life parameterization (cleaner story) but the report should panel both so the user sees the difference; trivially switchable to α=1/7 if a tighter match to the incumbent is wanted for the shadow A/B.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Foundation (`exp`,`pow`,`abs`,`sqrt`, median sort) | All math (§1-4) | ✓ | iOS 17+ SDK | — |
| SwiftData `@Model` + `[Double]` attribute | `BaselineState` (§6) | ✓ | iOS 17+ SDK | Packed-scalar fields if array attr fails |
| `HealthKitService.fetchHRVHistory(days:)` `[(date,value)]` | HRV bucketing (§5) | ✓ | `:187-194` | — |
| `HealthKitService.fetchLastNightSleepWithDate()` | Sleep bucketing (§5) | ✓ | `:341-373` | — |
| `HealthKitService` RHR **history** fetch | RHR bucketing (§5) | ✗ | only `fetchLatest*WithDate` | Add `fetchRestingHRHistory(days:)` mirror (additive) |
| `ShadowMetrics.SplitMix64` seeded PRNG | Report determinism (§7) | ✓ | `:127-137` | — |
| In-memory `ModelContainer` test harness | Model tests (§8) | ✓ | `SorenessLogModelTests.swift:16-30` | — |
| `FileManager` markdown write | Report artifact (§7.5) | ✓ | Foundation | Write to test temp dir if repo path unwritable |

**Missing dependencies with no fallback:** None.
**Missing dependencies with fallback:** RHR history fetch (add trivial mirror helper); `[Double]` SwiftData attribute (packed-scalar fallback).

## Security Domain

> `security_enforcement` is not set in `.planning/config.json`. This phase has **no auth, no network, no untrusted input, no cryptography, no secrets** — it is pure on-device statistics over HealthKit-derived numbers plus a local-only SwiftData model that is **never synced**. The only security-relevant property is **privacy-by-omission**: the new `BaselineState` model carries no `Codable` conformance and its name appears nowhere in `SyncService.swift`, so raw/derived health state never leaves the device — consistent with the project's HealthKit constraint ("raw HealthKit data must never leave device; only composite scores sync") and the `SorenessLog`/`CyclePredictionLog` precedent.

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V5 Input Validation | minimal | All inputs are numeric HealthKit-derived Doubles; guard against NaN/inf via σ floor + count gates (§2.3). |
| V6 Cryptography | no | None — no secrets, no crypto. |
| V8 Data Protection (privacy) | yes | Local-only `@Model`, no Codable, absent from `SyncService` (verified); health-derived state never syncs. |
| V2/V3/V4 (auth/session/access) | no | No auth/network surface in this phase. |

## Sources

### Primary (HIGH confidence)
- **Codebase (verified at file:line):** `WorkloadCalculator.swift:11,13,88-97` (EWMA λ pattern); `RecoveryScoreEngine.swift:100-136,197-210,243-247` (HRV ratio sign, computeSlope, 7-day baseline); `HealthKitService.swift:187-194,334-373` (fetch shapes); `RecoveryPipeline.swift:40-66,196-202` (signal entry + prequential cutoff); `SorenessLog.swift`, `CyclePredictionLog.swift:28-43` (local-only @Model template + date contract); `WorkloadApp.swift:70-80` (Schema); `ShadowMetrics.swift:127-183` (SplitMix64 + block-bootstrap); `ShadowMetricsTests.swift`, `SorenessLogModelTests.swift:16-30` (test conventions).
- **`.planning/research/algorithm-moat-design.md`** — §2.1 baseline, §2.2 z, §2.4 cold-start, §299-327 codex v1 verdict (the binding contract).
- **`.planning/phases/26-individualized-baselines/26-CONTEXT.md`** — D-01..D-04 + locked-by-design.

### Secondary (MEDIUM confidence — cited math)
- Welford M2 recurrence — https://en.wikipedia.org/wiki/Algorithms_for_calculating_variance
- MAD ×1.4826 consistency constant — https://en.wikipedia.org/wiki/Median_absolute_deviation
- Huber tuning constant 1.345 / 95% efficiency — https://www.statsmodels.org/stable/generated/statsmodels.robust.norms.HuberT.html
- EWMA half-life ↔ λ ↔ α parameterization — https://gregorygundersen.com/blog/2022/06/04/moving-averages/
- Altini, *Variability in variability* (HRV CV early flag) — https://marcoaltini.substack.com/p/variability-in-variability
- Altini, *Stability in heart rate variability* (7-day baseline) — https://marcoaltini.substack.com/p/stability-in-heart-rate-variability

### Tertiary (LOW confidence — flagged ASSUMED, calibrated by the report)
- Specific constant values (half-lives, k, σ floors, CV thresholds, confidence τ, morning window) — see Assumptions Log.

## Metadata

**Confidence breakdown:**
- Robust baseline math: **HIGH** — textbook recurrences (Welford/MAD/Huber/EWMA) cited; numerically-stable forms specified; mirrors existing in-repo EWMA.
- Prequential z + ordering: **HIGH** — directly extends the verified `RecoveryPipeline:196-202` cutoff + Phase 24 date contract.
- Altini CV: **MEDIUM** — design-grounded structure (dispersion-ratio of innovations) is sound; exact thresholds ASSUMED, calibrated by the report.
- Confidence model: **MEDIUM** — form is principled and honest-low cold-start is locked; constants ASSUMED/tunable.
- Day-bucketing: **HIGH** for HRV/sleep (verified fetch shapes); **MEDIUM** for RHR (needs additive history helper).
- State model + Schema + sync-exclusion: **HIGH** — mirrors verified local-only precedent; sync-omission confirmed.
- Seeded report: **HIGH** — deterministic by construction (no time/RNG in engine; reuses verified SplitMix64).

**Research date:** 2026-05-30
**Valid until:** 2026-06-29 (stable — pure math + iOS SDK; only the in-repo anchors could drift if other phases refactor the cited files).
