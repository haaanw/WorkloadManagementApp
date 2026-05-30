# Algorithm Moat Design — Tuwa Unified Readiness & Risk Model

**Status:** DESIGN SPEC for user sign-off. No engine code is written by this document.
**Date:** 2026-05-30
**Author:** research/design agent
**Constraint envelope:** iOS 17+, SwiftUI + SwiftData, **on-device only** (no server inference), pure-struct engines with static methods, raw HealthKit never leaves device, validated through the existing Phase-20 shadow harness before any user-facing activation.

This spec grounds everything in (a) the current engines as they actually exist in code today, (b) the user's own elite-sport injury research (`algorithm research file/`), (c) the female-athlete research, and (d) targeted external literature cited inline. It refines — not blindly accepts — the user-approved moat direction.

---

## 0. The one-paragraph thesis

The current engines are a competent assembly of **commodity** sports-science primitives (Foster sRPE-TSS, Banister TRIMP, EWMA/rolling ACWR, HRV-vs-7-day-mean). None of these is defensible: any competitor can rebuild them in a weekend, and the headline metric — ACWR — has been formally invalidated as an injury predictor (Impellizzeri 2020-21). The defensible asset is **not a single cleverer formula** but a **per-person longitudinal state model**: replace every flat 7-day rolling mean with an individualized adaptive baseline (a Bayesian/Kalman state estimate that learns each athlete's own normal *and its uncertainty*), demote ACWR to a non-load-bearing context line, and fuse recovery × load × cycle × injury-history into a single **Readiness** scalar plus a separately-reported **Strain-Risk** flag — with the fusion weights *learned and calibrated through the shadow harness on each user's own outcomes*, never shipped as fixed population constants. The moat is the compounding personal model + the honest validation gate, not the math primitives.

---

## 1. Diagnosis — what is commodity today and why it is not defensible

### 1.1 `WorkloadCalculator.swift` — commodity, partially invalidated

| Formula in code | What it is | Defensibility |
|---|---|---|
| `sessionTSS = hours × RPE × (RPE/10)` | Foster session-RPE TSS | Commodity. Foster 2001. Public. |
| `trimp = Σ(zoneMin × [1,1.5,2,3,5])` | Banister TRIMP | Commodity. Banister 1991. Public. |
| `atl = atl·(1−1/7) + tss·(1/7)`, `ctl` with `1/28` | EWMA ATL/CTL | Commodity decay constants. |
| `acwr = atl/ctl`, zone classify | **ACWR** | **Invalidated.** Impellizzeri & Tenan (2020), *Acute:Chronic Workload Ratio: Conceptual Issues and Fundamental Pitfalls*; Impellizzeri (2020) *Time to Dismiss ACWR*: randomized "contrived" chronic loads predict injury as well as real ACWR (OR 1.95 vs 2.45) — i.e. **no predictive advantage over raw acute load**. A 2025 meta-analysis (46 studies) confirms: even where ACWR shows modest association, *training to manage ACWR does not prevent injuries*. The user's own FEA research excludes ACWR for exactly this reason. |
| `detectSessionSpike` (≥1.5× recent mean) | acute-load spike | This is the *salvageable* primitive — raw acute load retains evidentiary support (Lewis 2018; Orringer 2022 in the FEA doc). |

**Verdict:** keep the load *primitives* (sRPE load, acute rolling minutes/TSS, spike detection), **demote ACWR** to a labeled context string, and add the load-distribution primitives that DO have support (Foster monotony/strain — see §2.6).

### 1.2 `RecoveryScoreEngine.swift` — commodity baseline, the core weakness

```
hrvScore from ratio = hrv / baseline,  baseline = 7-day rolling mean   (30%)
rhrScore from ratio = rhr / baseline                                    (20%)
sleepScore from duration step function                                  (25%)
wellnessScore (subjective 0-100)                                        (25%)
+ tanh(slope3/3)·10 trend modifier
```

Three commodity weaknesses:

1. **Flat 7-day rolling mean baseline.** This is the single most-copied recovery formula in the industry (every Whoop/Oura/Garmin clone uses a rolling mean). It has no memory of uncertainty, weights a 7-day-old reading equally with last night, and cannot distinguish "HRV is low because I'm fatigued" from "HRV is noisy and one bad reading dragged the mean." Altini's central published critique applies directly: *the day-to-day coefficient of variation often flags disrupted homeostasis before the baseline mean moves at all* ([Altini, "Variability in variability"](https://marcoaltini.substack.com/p/variability-in-variability)). Our engine throws that signal away.
2. **Hand-picked linear weights (30/20/25/25).** Arbitrary, population-fixed, identical for every user. No evidence they are optimal for any individual.
3. **`ratioToScore` linear map** (`0.7→20, 1.0→70, 1.2→100`) — an arbitrary piecewise line, not anchored to the person's own distribution.

The Phase-18 same-phase cycle baseline (`samePhaseBaseline`) is the **one genuinely differentiated** element here — it is per-person, phase-aware, sample-gated. It is the seed of the right idea; the design generalizes it to *all* baselines.

### 1.3 `FatigueIndexEngine.swift` — differentiated lineage, keep and elevate

This is the strongest existing asset. It is explicitly built on the user's FEA research: it *excludes ACWR* and uses evidence-tiered primitives (load elevation, session density, recovery trend, rest debt, wellness trend, soft-tissue injury memory with `1−exp(−0.5n)` exactly from FEA component x₇). This is the closest thing to a moat in the codebase today. **Keep its philosophy; upgrade its baselines and learn its weights.**

### 1.4 `AutoregulationEngine.swift` — commodity decision matrix

A hand-authored 3×5 `(recoveryZone × acwrZone)` lookup table with fixed cap/volume outputs. Defensible only as UX scaffolding. It depends on ACWR zones (invalidated input) and fixed thresholds. **Modify** to consume the new Readiness + Strain-Risk instead of ACWR zones; keep the explainable-recommendation shell.

### 1.5 `ProgressionEngine.swift` / `ReasoningEngine.swift`

`ProgressionEngine` is per-exercise overload logic — orthogonal to the recovery/load moat, keep as-is (it consumes the autoregulation output). `ReasoningEngine` is the **explainability layer** and is a genuine product asset: it produces ranked human-readable "why" factors. The new model must feed it richer, individualized factors (z-scores against personal baseline + uncertainty), but the pattern stays.

### 1.6 The honest summary of the diagnosis

> Tuwa today = (Foster + Banister + EWMA + ACWR + rolling-mean HRV) wrapped in a nice decision matrix and a good explanation layer. Four of those five are public commodity formulas and one is invalidated. The differentiated parts (FatigueIndexEngine's FEA lineage, the same-phase cycle baseline, ReasoningEngine) are real but small. **The moat must come from making the *baselines personal and probabilistic* and the *fusion weights learned*, not from inventing a new TSS.**

---

## 2. The model — Tuwa Personal Readiness State (PRS)

The model has four layers. Each is a **pure struct with static methods** (project convention). State between days is persisted in SwiftData, not held in the struct.

```
Layer 1  Per-signal individualized adaptive baseline   (replaces 7-day rolling mean)
Layer 2  Standardized deviation features (z + CV)       (replaces ratioToScore)
Layer 3  Fusion → Readiness scalar + Strain-Risk flag   (replaces weighted-mean + ACWR matrix)
Layer 4  Explainability (ranked personal factors)       (feeds ReasoningEngine)
```

### 2.1 Layer 1 — Individualized adaptive baseline (the heart of the moat)

For each tracked signal *s* (HRV SDNN, resting HR, sleep duration, body temp, and the subjective components), maintain a **local-level Bayesian state-space estimate** of the person's current "normal," updated once per day. This is a 1-D Kalman filter / Bayesian dynamic linear model — the standard tool for adaptive physiological baselines from sparse wearable data (cf. [Bayesian dynamical modelling of wearable biosensors, medRxiv 2022](https://www.medrxiv.org/content/10.1101/2022.08.20.22278813.full.pdf); risk-adjusted EWMA as the degenerate case).

**State.** For signal *s* on day *t*: latent baseline level `μ_t` with variance `P_t`.

**Predict (random-walk evolution):**
```
μ_t⁻ = μ_{t-1}
P_t⁻ = P_{t-1} + Q_s          // Q_s = process noise: how fast this person's true normal drifts
```

**Update with today's observation `y_t` (observation noise R_s):**
```
K_t  = P_t⁻ / (P_t⁻ + R_s)    // Kalman gain in [0,1]
μ_t  = μ_t⁻ + K_t·(y_t − μ_t⁻)
P_t  = (1 − K_t)·P_t⁻
```

**Why this beats the rolling mean (concretely):**
- `K_t` *automatically* down-weights noisy/uncertain signals. A single aberrant HRV reading moves `μ` less when `R_s` is large or `P_t` is small. The rolling mean cannot do this.
- `P_t` gives **uncertainty** for free. We surface confidence honestly ("baseline still settling") and gate downstream logic on it — directly echoing Altini: *individual response > population priors, and uncertainty matters*.
- Cold-start is principled (see §2.4): start `μ_0` at a sex/age population prior with large `P_0`, and the filter converges to the person within ~2–4 weeks, **with the convergence visible in `P_t`**.
- It degenerates to EWMA when `Q/R` is fixed — so it is strictly more general than what we ship today, and the steady-state gain `K* = (−Q + √(Q²+4QR))/2R` ties directly back to a familiar smoothing constant for explainability.

**Per-person adaptation of Q and R (the compounding moat).** `Q_s` and `R_s` are themselves estimated per athlete from their own residual history (innovation variance), so the model *learns how variable each person's physiology is*. Two users with identical mean HRV but different stability get different baselines and different sensitivity. **This is the asset that compounds with tenure and cannot be copied from a spec — it is each user's own data.**

**Co-existence with the Phase-18 same-phase cycle baseline.** The cycle baseline becomes a *second, phase-conditioned* state per signal (one filter per `PhaseBucket`). The active baseline for HRV/RHR is selected exactly as today (D-06/D-07 per-bucket fallback), but each candidate is now a Kalman estimate with uncertainty rather than a flat mean. No regression for the no-cycle path.

**Dual-timescale CV signal (Altini).** In parallel to `μ_t`, track the rolling **coefficient of variation** of the innovations. A rising CV is an *early* disruption flag even when `μ_t` has not moved — fed to Layer 4 as its own factor.

### 2.2 Layer 2 — Standardized deviation features

Each signal's contribution becomes a **personal z-score**, not an arbitrary ratio map:
```
z_s,t = (y_t − μ_t) / σ_s,t           σ_s,t = sqrt of the person's innovation variance
```
Sign-corrected so positive z always means "better recovered" (HRV positive-is-good, RHR/temp inverted). This replaces `ratioToScore`. Z-scoring against the person's *own* spread is exactly the RFI construction in the user's Chinese research file (`0.30·z(acute) + 0.20·z(congestion) + …` through a logistic), translated from team z-scores to **personal longitudinal z-scores** — the correct consumer adaptation.

Missing signals use **missing-data-indicator modeling** (RFI's explicit recommendation: do not mean-impute; carry a missingness flag and re-normalize weights over present signals). The current engine already redistributes weights on missing components; we keep that and *add the indicator* so the fusion layer can learn that "HRV chronically absent" is itself informative.

### 2.3 Layer 3 — Fusion into Readiness + Strain-Risk

Two **separate** outputs (a deliberate departure from cramming everything into one number):

**(A) Readiness (0–100)** — "how recovered are you today," a logistic fusion of standardized recovery deviations:
```
Readiness = 100 · σ( b0 + Σ_s w_s · z_s,t + w_cv · (−CV_excess) + w_trend · slope )
```
where `σ` is logistic, `w_s` are the fusion weights. **Critically: `w_s` are not the hand-picked 30/20/25/25.** They start at evidence-anchored priors (HRV/sleep highest, consistent with the recovery literature) and are **refined per-cohort/per-user by the shadow harness** against next-day outcomes (§4). This is the same "evidence-anchored prior, then calibrate" methodology the FEA doc prescribes for its weights — applied to recovery.

**(B) Strain-Risk (a flag + 0–100 secondary index)** — "is accumulated training stress + history elevating your near-term breakdown risk." This is the **upgraded FatigueIndexEngine**, kept as its own output because the FEA/RFI research is emphatic that *frequency/burden and per-event impact are different decision problems and must not be collapsed into one score* (Chinese research file, §排序算法设计: "把三者硬塞进一个回归器…会损失可解释性"). Strain-Risk fuses:
- load elevation vs **personal Kalman baseline** (not flat mean),
- **Foster monotony & strain** (§2.6) replacing the crude session-count density,
- rest debt / streak,
- recovery & wellness trend (declining = worse),
- **soft-tissue injury memory** `1−exp(−0.5·n)` with `exp(−days/τ)` recency decay — kept verbatim from FEA x₇, the most directly transferable team→consumer primitive,
- the **calf→Achilles-style cascade modifier** *generalized for consumers* (see §5.2 on what does and does not transfer).

**Why two outputs, not one fused readiness-and-risk scalar (refining the user's brief).** The user's stated direction was "one readiness-and-risk trajectory." I recommend **one trajectory, two channels**: a green/recovered athlete carrying dangerous accumulated load is the single most important case the product must surface, and a single blended number *hides* exactly that ("Feeling Good, But Load Is High" already exists in the autoregulation matrix for this reason). Keep them separate in the model; present them as one coherent daily story in the UI.

### 2.4 Cold-start behavior

| Tenure | Baseline behavior | Outputs |
|---|---|---|
| Day 0 | `μ_0` = sex/age population prior, `P_0` large | Readiness shown with explicit "calibrating" confidence; Strain-Risk suppressed (needs load history). |
| Weeks 1–3 | Kalman converges; `P_t` shrinks | Confidence rises automatically; z-scores stabilize. |
| ≥ 4 weeks / ≥ ~3 cycles | Per-person Q/R estimated; cycle baselines eligible (existing 4-reading / 3-cycle gates) | Full personalized model; fusion weights may switch from cohort prior to user-tuned if shadow data supports. |

Cold-start uses the **existing graceful-degradation pattern** (neutral 50, redistribute weights) but now with a principled uncertainty marker instead of a silent guess.

### 2.5 On-device inputs actually available (verified in code)

From `RecoveryPipeline` / `HealthKitService`: **HRV SDNN, resting HR, sleep duration, body temp, VO2 Max**, wrist-temp deviation (cycle). From `WellnessCheckIn`: **sleepQuality, soreness, energy, stress** (+ behavior tags, notes). From sessions: **sRPE, duration, TSS, volume, training streak, days-since-rest**. From injury history: count + recency. From cycle: phase + confidence + exclusions. **Everything the model needs is already on-device** — no new sensors required. (Respiratory rate is a possible future HealthKit add; out of scope.)

### 2.6 Foster monotony & strain (the one new load primitive worth adding)

Replaces `FatigueIndexEngine.computeSessionDensity`'s crude `sessions/14d`:
```
monotony_week = mean(daily_load) / sd(daily_load)
strain_week   = sum(daily_load) × monotony_week
```
Foster (1998, *Monitoring training in athletes with reference to overtraining syndrome*) tied high monotony (>2.0) and strain to overreaching/illness. This is evidence-supported, ACWR-free, and computable from data we already have. **Caveat (from project memory):** monotony needs consistent daily load; gate it on RPE-entry compliance and fall back to the count-based density when sparse. This was already flagged as deferred in `project_future_monotony_strain.md` — now is the time.

### 2.7 Layer 4 — Explainability (non-negotiable)

The model must produce, per day, ranked human-readable factors exactly as `ReasoningEngine.summarize` does today, but richer:
- "HRV 1.4σ below your personal normal (and unusually variable this week)" — z + CV.
- "Sleep 52 min below your baseline" — personal, not the fixed 420-min target.
- "Load up, but your week is monotonous (monotony 2.3) — vary intensity."
- "Confidence: baseline still settling (3 weeks of data)."

Every Readiness/Strain-Risk number must be decomposable back to these factors. A black-box score is a non-starter for this product (and the FEA doc's core thesis is that interpretable, evidence-anchored beats black-box on small-N injury data — §9: "evidence-anchored rather than ML-fit, and that is a feature").

---

## 3. What it replaces vs augments (engine-by-engine map)

| Engine | Action | Detail |
|---|---|---|
| `RecoveryScoreEngine` | **Replace internals, keep interface** | Swap `computeBaseline` (rolling mean) → Kalman state; swap `ratioToScore` → personal z; keep `compute(input:)` signature & same-phase logic so call sites and shadow harness are undisturbed. New `BaselineStateEngine` pure struct holds the predict/update math. |
| `WorkloadCalculator` | **Keep primitives, demote ACWR** | Keep `sessionTSS`, `srpeLoad`, `trimp`, `detectSessionSpike`, EWMA ATL/CTL (useful as *load* descriptors). `acwr` field stays computed for continuity but is **reclassified as context-only**, removed from any risk decision. Add `monotony`/`strain`. |
| `FatigueIndexEngine` | **Augment → becomes Strain-Risk engine** | Keep FEA-lineage components & weights philosophy; feed it Kalman baselines + Foster monotony; make weights shadow-calibratable. This is promoted from "input to autoregulation" to a **first-class output**. |
| `AutoregulationEngine` | **Modify inputs** | Replace `acwrZone` input with `strainRiskZone`; keep the explainable recommendation shell, warnings, cycle-modifier double-gate. The decision matrix becomes `(readinessZone × strainRiskZone)`. |
| `ProgressionEngine` | **Keep** | Unchanged; consumes autoregulation output. |
| `ReasoningEngine` | **Augment** | Feed richer personal factors (z, CV, confidence, monotony). Keep ranked-factor pattern. |
| `ShadowPredictor` / `ShadowAnalyticsService` / `CyclePredictionLog` / `CycleModifierGate` | **Reuse + extend** | The validation substrate for the *whole* model, not just cycle modifiers — see §4. |

All new engines remain `struct` + `static func`, Foundation-only, deterministic. Per-day Kalman state persists in a new local-only SwiftData model (e.g. `BaselineState` per signal per athlete) — **never synced** (same privacy posture as `MenstrualCycleSnapshot` / `CyclePredictionLog`, D-13).

---

## 4. Validation plan — shadow-mode against the current algorithm

**Principle: nothing ships live until it beats the incumbent on the user's own outcomes, through the existing harness.** The Phase-20 harness already logs baseline-vs-experimental predictions per day, resolves actuals, and aggregates MAE. We generalize it from "cycle offset vs no-offset" to "**PRS model vs current RecoveryScoreEngine/ACWR**."

### 4.1 Mechanism (extend, don't rebuild)

`ShadowPredictor` currently emits `baselinePrediction` (no cycle) vs `cycleAwarePrediction` (fixed offset). Add a third competing predictor: **PRS prediction** (Kalman baseline + z-fusion). `CyclePredictionLog` gains parallel `*PRS` fields alongside the existing `*Baseline`/`*CycleAware`. `ShadowAnalyticsService.aggregate` already computes per-outcome MAE over resolved rows — extend the tuple to report PRS MAE too. **The "current algorithm" is the baseline arm; PRS must beat it.**

### 4.2 Outcome labels (already plumbed in the harness, D-02)

- **next-day Readiness/recovery score** (continuous 0–100)
- **next-day wellness** (continuous 0–100)
- **next-day workout completion** (0/1 → treated as probability)
- **next-day reported soreness/pain** (1–5)
- *(new, low-frequency)* **self-reported injury / "tweak" event** — add a lightweight injury log; treated as a rare-event label for Strain-Risk, NOT for day-to-day Readiness.

### 4.3 Success metrics & gates (consumer-scaled, borrowing the research's gates where they transfer)

The research files specify elite gates (AUC ≥ 0.80, Spearman ρ ≥ 0.70, calibration slope 0.9–1.1, ≤10% drop without private biometrics). We **borrow the *structure*, scale the *thresholds* honestly** for consumer single-athlete data:

| Claim under test | Metric | Activation gate | Rationale |
|---|---|---|---|
| Personal baseline beats rolling mean | per-outcome **MAE reduction** (PRS vs current), paired bootstrap CI | PRS MAE < current MAE on ≥3 of 4 continuous outcomes, CI excludes 0 | Direct, already-built harness math. |
| Readiness predicts next-day state | Spearman ρ(predicted, actual) | ρ ≥ 0.50 (consumer-scaled from research's 0.70) | Published external-load AUCs are 0.55–0.70 (FEA §8); 0.70 is unrealistic for consumer self-report. |
| Readiness is well-calibrated | calibration slope (reliability) | slope ∈ [0.8, 1.2] (loosened from research's 0.9–1.1) | Honest about smaller N. |
| Strain-Risk ranks high-risk windows | top-decile risk-vs-actual-tweak AUC / PR-AUC | AUC ≥ 0.65 (matches FEA's own "useful" bar of >0.65) | The FEA doc explicitly sets 0.65 as the usefulness floor; injury base rates are tiny so PR-AUC + honest uncertainty mandatory. |
| Robustness | leave-one-period-out / purged CV | rank stability under purged season CV (no random split — the Chinese file warns random splits leak across an athlete's correlated days) | Adopt purged/blocked CV per research §验证方案. |

**Data-maturity gate:** no per-user weight tuning until ≥ N resolved prediction rows (suggest ≥60 days) — below that, use the cohort prior. **No flipping `isEnabled` live until gates pass on aggregate shadow data.** The existing `CycleModifierActivation.isEnabled = false` discipline is the template: PRS gets its own master activation flag, defaults false, flipped only on evidence.

### 4.4 Phased activation (mirrors the existing gate culture)

1. **Shadow-log PRS** beside current algorithm (no UI change). Collect.
2. When the **baseline-replacement** gate passes (MAE), activate *Layer 1+2 only* — Readiness now driven by Kalman baselines. ACWR demoted in UI. Fusion still cohort-prior.
3. When the **fusion** gate passes, activate learned weights and the separated Strain-Risk channel.
4. Per-user weight personalization last, behind the data-maturity gate, with per-user shadow confirmation.

---

## 5. Risk + honesty

### 5.1 Where the research over-promises for consumer data

- **The injury-ranking research is elite-team infrastructure.** Its inputs (squad rotation, fixture congestion, time zones crossed, position multipliers, tournament stage, public minutes) **do not exist for a single consumer lifter.** Translating the FEA/IRA wholesale would be cargo-culting. Honest position: we borrow the *philosophy* (ACWR-free, evidence-tiered, prior-then-calibrate, missing-data-indicator, separate impact-vs-burden) and the *individually-transferable primitives* (prior soft-tissue memory, acute-load elevation, monotony), and **explicitly drop** the team-sport primitives.
- **Injury events are vanishingly rare per single user.** A consumer app will see maybe 0–2 "tweaks" per user per year. You **cannot** train a per-user injury classifier; base rates make precision near-zero and false positives erode trust (confirmed by consumer-wearable injury-prediction literature). Strain-Risk must be framed as a **probability-shift context flag, never a prediction** — exactly the FEA doc's §8 closing caution ("risk *predictor*, not a *cause*… probability shifts, not deterministic signals"). Marketing it as "injury prediction" is a liability.
- **Strength-training load is poorly captured by HR-based metrics** (heavy squats/deadlifts barely move HR) — so TRIMP is weak here and sRPE/volume carry the load signal. Don't over-trust HR zone load for a strength app.

### 5.2 What translates vs what does not (explicit)

| Elite-team primitive | Consumer translation | Verdict |
|---|---|---|
| Prior soft-tissue injury memory (FEA x₇) | self-logged injury count + recency | **Translates** (already in FatigueIndexEngine). |
| Acute load elevation vs personal baseline | sRPE/TSS vs Kalman baseline | **Translates.** |
| Schedule density / fixture congestion | training streak, sessions/14d, monotony | **Partially** → use streak + Foster monotony. |
| Calf→Achilles cascade modifier | (no body-region load data for lifters) | **Does NOT translate** as a tendon-specific predictor. *Generalize* only to: "recurrent same-region soreness + recent load spike → elevate Strain-Risk." Do not claim Achilles-specific risk. |
| Position multiplier, travel, time zones, tournament stage | none | **Drop entirely.** |
| Multi-task Bayesian learning-to-rank over 5,000 events | none (single user, no event volume) | **Drop.** Use the *RFI z-score+logistic* form (their "small-sample / pilot" tier), not the production LTR model. |

### 5.3 Failure modes

- **Kalman misconfiguration** (Q/R wrong) → baseline too sluggish or too jumpy. Mitigation: estimate Q/R from innovations with sane bounds; shadow-validate before activation.
- **Over-personalization on thin data** → noise fit. Mitigation: data-maturity gate; shrink to cohort prior when `P_t` large.
- **Explainability debt** → if fusion weights are learned, "why" must still decompose. Mitigation: keep the model **glass-box** (logistic over named z-features), never a neural net.
- **Confidence theater** → surfacing uncertainty is good only if honest. Mitigation: derive confidence from `P_t` and resolved-row count, not a vibe.

### 5.4 Phased rollout (recap, with honesty)

Baseline replacement first (lowest risk, highest certainty of improvement) → fusion second → Strain-Risk separation third → per-user personalization last. Each gated by shadow evidence. **Ship nothing as "novel injury prediction."** Ship it as "a recovery model that learns *your* normal" — which is true, defensible, and validatable.

---

## 6. Open questions for the user (genuine product/science decisions)

1. **One number or two?** I recommend **Readiness + a separate Strain-Risk channel** (the research strongly supports separating recovery-state from accumulated-burden). The user's brief said "one trajectory." Confirm: one fused scalar, or one trajectory presented as two coherent channels?
2. **Risk framing & liability.** Are you willing to commit to "context flag / probability shift" language and **never** "injury prediction" in UI/marketing? This bounds the whole Strain-Risk design.
3. **Injury self-logging.** Strain-Risk validation needs *some* outcome label for breakdown. Will you add a lightweight injury/"tweak" log (type, region, date)? Without it, Strain-Risk can only be validated against soreness/completion proxies, not injury.
4. **Calibration data source.** Per-user calibration needs ~60+ days before it engages. Acceptable that new users run on cohort-prior weights for ~2 months? Or do you want a sharper cold-start (e.g. an onboarding questionnaire prior, per the deferred "perceptual bias" research)?
5. **Cohort priors without a server.** Learned fusion weights need *some* population/cohort prior. On-device-only means we ship a fixed prior in the app bundle and personalize locally — we cannot pool users' data server-side. Confirm that constraint holds (it aligns with the privacy posture), accepting that the cohort prior is static between app updates.
6. **Activation authority.** Who flips the PRS master activation flag after gates pass — automatic on-device once a user's own shadow data clears the gate, or a remote-config kill-switch you control? (Affects whether different users activate at different times.)
7. **VO2 Max / body temp role.** Both are available on-device but weakly tied to daily recovery. Include as low-weight context factors, or hold them out of the fusion entirely?

---

## Appendix A — Sources

- Impellizzeri & Tenan, *Acute:Chronic Workload Ratio: Conceptual Issues and Fundamental Pitfalls* (2020) — https://pubmed.ncbi.nlm.nih.gov/32502973/
- Impellizzeri et al., *Time to Dismiss ACWR and Its Underlying Theory* (2020) — https://pubmed.ncbi.nlm.nih.gov/33332011/
- *ACWR for predicting sports injury risk: systematic review & meta-analysis* (2025) — https://pubmed.ncbi.nlm.nih.gov/41029871/
- Altini, *Variability in variability* (HRV CV as early flag) — https://marcoaltini.substack.com/p/variability-in-variability
- Altini, *Stability in heart rate variability* — https://marcoaltini.substack.com/p/stability-in-heart-rate-variability
- *Monitoring Training Adaptation and Recovery via HRV (mobile), narrative review* — https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12787763/
- *Bayesian dynamical modelling of wearable biosensors* (medRxiv 2022) — https://www.medrxiv.org/content/10.1101/2022.08.20.22278813.full.pdf
- *Risk-Adjusted EWMA* (JASA 2007) — https://www.tandfonline.com/doi/abs/10.1198/016214506000001121
- Foster, *Monitoring training… overtraining syndrome* (monotony/strain) — https://pubmed.ncbi.nlm.nih.gov/9662690/
- *Training Load & Strain wearable limitations (strength training, false positives)* — https://medium.com/@CuriousCatalyst/training-load-strain-understanding-your-wearables-injury-prevention-system-and-its-7c9aa456e53a
- User's own research: `algorithm research file/Ranking sports injuries by fatigue-weighted performance impact.md` (FEA/IRA), `…/顶级职业体育伤病排序算法的开发与验证研究.md` (RFI, missing-data-indicator, validation gates), `.planning/research/female-athlete-optimization-research.md` (dual baselines, Altini individual>population).

## Appendix B — Current-code anchors (verified 2026-05-30)

- `WorkloadApp/Services/RecoveryScoreEngine.swift` — 7-day rolling `computeBaseline`, `ratioToScore`, same-phase baseline.
- `WorkloadApp/Services/WorkloadCalculator.swift` — Foster TSS, TRIMP, EWMA ATL/CTL, ACWR, spike detection.
- `WorkloadApp/Services/FatigueIndexEngine.swift` — FEA-lineage 6-component fatigue index (the differentiated asset).
- `WorkloadApp/Services/AutoregulationEngine.swift` — `(recoveryZone × acwrZone)` decision matrix, cycle double-gate.
- `WorkloadApp/Services/ReasoningEngine.swift` — ranked human-readable factors (explainability pattern to preserve).
- `WorkloadApp/Services/ShadowPredictor.swift`, `ShadowAnalyticsService.swift`, `Models/CyclePredictionLog.swift`, `Services/CycleModifierGate.swift` — the shadow-validation substrate to extend for PRS.
