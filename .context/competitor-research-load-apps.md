# Competitor Research: Training-Load, Autoregulation & Progression Algorithms

**Purpose:** Document how competitor training-load, autoregulation, and progression algorithms work, to position Tuwa's algorithm as differentiated and better for our target user.

**Target user (critical lens):** Amateur SERIOUS trainers and part-time athletes who train hard but have NO access to professional coaching, physiotherapy, or sports-science support. They need pro-grade guidance *in lieu of* a human expert. This means: an algorithm must PRESCRIBE (not just describe), must INTEGRATE recovery with load (not silo them), must be INDIVIDUALIZED (not population-baseline), must handle STRENGTH as well as endurance, and must surface an INJURY/overtraining lens — all without requiring a coach to interpret the output.

**Date:** 2026-05-30
**Confidence labels:** KNOWN = directly stated by vendor/publication. INFERRED = reasoned from available evidence, not explicitly confirmed.

---

## 1. TrainingPeaks (incl. WKO / Performance Manager Chart)

**Lineage (KNOWN):** Andrew Coggan's TSS system is a simplified version of Eric Banister's 1975 impulse-response model ("A systems model of training for athletic performance"), which used TRIMP (TRaining IMPulse). TrainingPeaks productized the Banister→Coggan lineage as the Performance Manager Chart (PMC).

### The model (KNOWN)
- **TSS (Training Stress Score):** single-session load score. For cycling, normalized power relative to FTP; a 1-hour all-out effort at threshold = 100 TSS. Endurance/power-meter-centric.
- **CTL (Chronic Training Load) = "Fitness":** exponentially-weighted moving average (EWMA) of daily TSS, default time constant **42 days**. Analogous to the positive (fitness) term in the impulse-response model.
- **ATL (Acute Training Load) = "Fatigue":** EWMA of daily TSS, default time constant **7 days**. Analogous to the negative (fatigue) term.
- **TSB (Training Stress Balance) = "Form":** `TSB = CTL − ATL` (yesterday's values, in the standard formulation).
- **EWMA formula (KNOWN):** `ATL_today = ATL_yesterday · e^(−1/k) + TSS_today · (1 − e^(−1/k))`, with k = 7 (ATL) or 42 (CTL). Equivalent recursive form: `today = yesterday + (TSS_today − yesterday) · (1/k)`.

### How form/ramp-rate is used (KNOWN)
- **TSB interpretation bands** (approximate, vendor + coach consensus):
  - TSB > +10 (and especially +15 to +25): "fresh"/race-ready — used for tapering/peaking.
  - −10 to +10: neutral.
  - −10 to −30: productive training/overload zone (Friel and others treat this as the optimal training stress band).
  - < −30: "high risk" zone — extreme overreaching trending to overtraining if sustained.
  - TrainingPeaks' own science article cautions these are approximate and "should not be applied too literally."
- **CTL ramp rate guidance (KNOWN):** Coggan warns that increasing CTL faster than **>5–7 TSS/d/wk for four+ weeks** is "a recipe for disaster"; coach guidance often tightens this to **3–5 CTL points/week** to limit injury/overtraining risk. This is TrainingPeaks' de facto "ramp rate" analog to ACWR.
- **ACWR:** Not the native PMC metric, but TrainingPeaks/WKO and the broader ecosystem compute acute:chronic ratios; the EWMA 7d/42d structure is itself a form of acute-vs-chronic comparison.

### Recovery integration (KNOWN)
**None in the PMC.** The Performance Manager is purely training-load based — it ingests TSS only. No HRV, sleep, or RHR feeds into Fitness/Fatigue/Form. (TrainingPeaks the platform lets users *log* HRV/wellness as separate metrics, but they do not enter the load model.)

### Prescribe vs describe (KNOWN)
**Describes.** The PMC is an analytical/monitoring tool; it does not generate "what to do today." A human coach (or the athlete) interprets the chart and writes the plan. This is the core friction for our user.

### Validation / criticism
- The Banister impulse-response model is foundational but the **fixed 42/7-day constants are population defaults**, not individualized (INFERRED from the "default time constant" framing — TrainingPeaks/WKO does allow advanced users to fit personalized constants, but most users run defaults).
- TSS is power/HR-centric and endurance-biased; it does not natively model strength training load well.

### Gap for our target user
- **Describes only — requires a coach to interpret.** This is the single biggest barrier for the no-coach athlete.
- **No recovery integration** (HRV/sleep/RHR don't touch the load model).
- **Endurance/power-meter-centric** — poor fit for strength athletes (subset of our users).
- **No injury lens** beyond the soft "TSB < −30 is risky" heuristic.
- Complexity/jargon (TSS/CTL/ATL/TSB/IF/NP) assumes literacy our user may lack.

---

## 2. Intervals.icu

### The model (KNOWN)
- Same Banister/Coggan core: **CTL (Fitness, 42d EWMA)**, **ATL (Fatigue, 7d EWMA)**, **Form (TSB = CTL − ATL)**.
- Recursive formula it publishes: `CTL_today = CTL_yesterday + (TSS_today − CTL_yesterday)·(1/42)`; same for ATL with 1/7. Constants are user-adjustable (a differentiator vs locked TrainingPeaks).
- Supports load from multiple sources (power, HR, pace) and a "Fitness, Fatigue & Form" chart.

### ACWR (KNOWN)
- Intervals.icu (and the ecosystem) also exposes **ACWR**: acute 7-day vs chronic 28-day rolling load, acute ÷ chronic. The classic "sweet spot" framing (0.8–1.3) and danger >1.5 is the heuristic layered on top.

### Recovery integration (KNOWN/INFERRED)
- Intervals.icu **does ingest wellness/HRV/RHR/sleep as logged fields** and plots them alongside load, and supports HRV-guided flags — but these are **displayed alongside** the load model, not fused into a single readiness-adjusted prescription (INFERRED: it is a power-user analytics dashboard, not an autoregulating coach).

### Prescribe vs describe (KNOWN)
**Primarily describes** (analytics-first). It is a free/cheap power-user tool; users self-interpret. Some planned-workout and target features exist, but it does not autoregulate "today's session" from readiness for you.

### Validation / criticism
- Inherits all Banister-lineage and ACWR critiques (see §8). Constants are adjustable, which is more honest than fixed defaults, but still leaves the user to choose.

### Gap for our target user
- **Power-user analytics, not guidance.** Steep interpretation burden — the opposite of "pro-grade guidance without a coach."
- Recovery is shown, not fused — user must mentally combine HRV + Form themselves.
- No strength progression model; no injury prescription.

---

## 3. Athletica (athletica.ai)

### The model (KNOWN)
- Built on peer-reviewed endurance sports science; uses **its own modification of the Banister model** to describe fitness, form, and fatigue.
- Can ingest **up to ~2 years of historical training** to shape its fitness/fatigue understanding.
- Ingests workouts from Garmin/Coros/Wahoo/Strava and analyzes performance, fatigue, **and HRV trends**, then reshapes future sessions in the background.
- Incorporates **subjective inputs (RPE/feeling, notes field)**; if a session differs from plan, downstream workouts adjust.

### Recovery integration (KNOWN)
- **Yes — partial.** It says it analyzes "HRV trends" and subjective measures alongside training stress to judge how well you responded and adjust tomorrow's sessions. This makes Athletica one of the few that *claims* recovery-aware adaptation. (INFERRED: depth/transparency of the HRV fusion is not publicly specified — likely a trend nudge rather than a formal readiness-gated prescription.)

### Prescribe vs describe (KNOWN)
- **Prescribes.** This is its headline value: adaptive plans that "quietly reshape future sessions." It is an AI coach, not just a chart.

### Validation / criticism
- "Modification of the Banister model" + "AI" = **black box.** No published formula for how HRV/RPE adjust load. Marketing-grade transparency only.
- Endurance-only: triathlon, running, cycling, rowing, duathlon, HYROX. **No strength/hypertrophy model.**

### Gap for our target user
- **Endurance-only** — excludes the strength athletes among our users.
- **Black-box AI** — no explainability; our no-coach user can't learn *why*, only *what*.
- HRV integration is opaque and a "trend" nudge, not a transparent readiness gate.
- Higher price point and triathlete-oriented framing.

---

## 4. HRV4Training / Marco Altini (CLOSEST PHILOSOPHICAL NEIGHBOR — read carefully)

This is the most important competitor for Tuwa's positioning: Altini is the canonical voice for **individualized HRV baselines and "train by readiness,"** which is the direction Tuwa's recovery engine already leans toward. We overlap on philosophy and must differentiate on execution.

### The methodology (KNOWN — well-documented by Altini)
- **Metric:** morning **rMSSD**, measured first thing on waking, then **log-transformed** (ln rMSSD; HRV4Training also rescales `2 · ln(rMSSD)` into a friendly ~6–10 "Recovery Points" range).
- **Baseline:** a **7-day moving average of ln rMSSD** (the "baseline" line). KNOWN.
- **Normal range (the key construct):** the **60-day mean ± 60-day standard deviation** of ln rMSSD. The shaded "normal values" band represents a positive/stable physiological response. The 60-day window is kept rolling/current. KNOWN.
- **Decision rule ("train by readiness"):** when the **7-day baseline falls OUTSIDE (below) the normal range band**, that is a "red light" → reduce/adjust training (shift high-intensity to low-intensity or rest; good timing for a recovery week). When inside the band → proceed as planned. KNOWN.
- **Coefficient of variation (CV) as early warning:** Altini emphasizes that **stability** (low CV, narrow normal band) — not merely higher absolute HRV — signals good adaptation/coping; rising CV / widening swings is an early warning even before the baseline crosses the band. KNOWN.

### Explicit critique of population baselines (KNOWN — quote-worthy)
- Altini's core published position: HRV is meaningful **only relative to your own individual frame of reference (days/weeks/months), not population-level values**, because **inter-individual differences are huge**. Comparing your HRV to a normative chart or another person is, in his framing, not useful. This is the exact critique Tuwa should adopt and lean into.

### Recovery integration with LOAD (KNOWN/INFERRED)
- HRV4Training Pro combines **HRV trend + RHR + CV + subjective/training-load logs** to estimate physiological response — so it *does* relate readiness to load, but **load is logged/contextual, not a formal CTL/ATL/ACWR engine fused with HRV into one number.** Altini's stance is that "monitoring training load alone is insufficient" — readiness is the lens. (KNOWN that load and HRV are shown together; INFERRED that the fusion is interpretive rather than a single prescriptive output.)

### Prescribe vs describe (KNOWN/INFERRED)
- **Guides more than most, but stops short of full prescription.** It tells you "today is a green/amber/red light" and the principle (reduce intensity on red), but it **does not generate the specific session** ("do 4×4min at this power" or "squat 3×5 at X kg"). The athlete still maps the readiness signal onto their own plan.

### Validation / criticism (KNOWN)
- Altini's approach is among the **most evidence-grounded** consumer HRV methods (he cites controlled studies, e.g. Javaloyes et al., where an HRV-guided endurance group outperformed a predefined-plan control on VO2max, peak power, ventilatory thresholds, and 40-min TT). This is a genuine strength — and a bar Tuwa must respect, not hand-wave.
- Limitation: it is fundamentally a **readiness lens, not a complete training system** — no progression engine, no strength model, no per-session prescription.

### Where Tuwa OVERLAPS with Altini (must acknowledge)
- Individualized rolling baseline + normal-range band (mean ± SD over a multi-week window).
- "Train by readiness" decision logic (reduce when baseline drops below personal normal).
- Rejection of population/normative HRV baselines.
- Use of CV / stability as a signal, not just absolute HRV.

### Where Tuwa must DIFFERENTIATE from Altini (the opening)
- **Altini describes readiness; Tuwa should PRESCRIBE the session.** Close the last mile: turn "red light" into "here is today's adjusted workout."
- **Altini is HRV-first with load as context; Tuwa FUSES recovery (HRV+sleep+RHR) WITH a real load model (ACWR/EWMA) into one readiness→autoregulation output.** That fusion is Tuwa's core value ("recovery AND load over time").
- **Altini is endurance-leaning; Tuwa spans STRENGTH too** (PR detection, progression, RPE/RIR-aware lifting).
- **Altini requires the athlete to map the signal onto a plan they already have; Tuwa serves the athlete who has NO coach and NO plan** — it must supply both the readiness lens *and* the plan.

---

## 5. Elite HRV

### The model (KNOWN)
- Metric: morning **rMSSD → ln(rMSSD)**, rescaled to a **0–100 "HRV Score"** using a normalization built from 6M+ readings (so even elite athletes fit on 0–100).
- **Morning Readiness:** compares each reading to the user's **rolling individual baseline** to classify "more stress / more recovery / similar to baseline" — explicitly **relative to the individual, not population**.
- **1–10 Relative Balance Score:** how close you are to your own morning baseline; the gauge **auto-adjusts sensitivity to your baseline trends** (i.e., it adapts the band like Altini's normal range).

### Recovery integration with LOAD (KNOWN)
- **None.** Elite HRV is a pure recovery/ANS monitor. It has no training-load model (no TSS/CTL/ATL/ACWR). Load is the user's problem.

### Prescribe vs describe (KNOWN/INFERRED)
- **Describes readiness** (green/amber/red style). Does not prescribe sessions. No strength or endurance training engine.

### Validation / criticism
- Methodology (ln rMSSD vs individual baseline) is sound and individualized — philosophically aligned with Altini. The 0–100 normalization uses a population distribution for *scaling* (KNOWN), though the *readiness judgment* is individual.

### Gap for our target user
- **Recovery only, no load** — exactly the silo Tuwa is built to eliminate.
- Describes, doesn't prescribe; no training plan; no strength model; no injury management.

---

## 6. Restwise

### The model (KNOWN)
- **Multi-marker subjective+objective recovery score** from ~**12 daily inputs**: resting heart rate, **blood O2 saturation** (finger pulse oximeter; O2 not strictly required), hours of sleep, sleep quality, mood/energy, muscle soreness, perceived performance, **urine color**, appetite, illness, etc.
- Proprietary, **patented** weighting → a single **daily recovery score (0–100)** with a color-coded trend chart and a plain-language explanation.
- Notably **does not require HRV or a chest strap** — deliberately low-tech inputs. (Acquired by Svexa, 2023-era, to strengthen "intelligent athlete recovery.")

### Recovery integration with LOAD (KNOWN/INFERRED)
- **Recovery-centric.** It produces a recovery score and advises whether you're "training appropriately," but it is **not a load-modeling engine** (no CTL/ATL/ACWR). It nudges training based on recovery; it doesn't fuse a formal load model. (INFERRED.)

### Prescribe vs describe (KNOWN/INFERRED)
- **Describes + light guidance** ("you're recovered / not recovered, adjust accordingly"). Not a per-session prescriptive engine; no strength model.

### Validation / criticism
- "Proprietary/patented algorithm" with **undisclosed weightings** = black box. Manual daily data entry (12 inputs) is high friction — a notable UX cost vs passive HealthKit reads.

### Gap for our target user
- **Black-box weighting; heavy manual input.** Tuwa's passive HealthKit reads + transparent scoring are a clear contrast.
- Recovery-only; no integrated load model; no prescription; no strength.

---

## 7. Strength-Training Apps (our users include lifters)

Endurance apps ignore strength; this cluster is where the strength-athlete subset of our users is served today. None of these integrate physiological recovery (HRV/sleep) — they autoregulate on **performance + RPE/RIR + subjective readiness** only.

### 7a. Fitbod (KNOWN)
- Generates each session from three real-time inputs: (1) logged performance on prior sets, (2) optional self-reported **fatigue slider**, (3) an internal **muscle-recovery half-life model** (e.g., quads ~48h, rear delts ~36h post-stimulus).
- **Progressive overload:** nudges 1RM/load up gradually; cites ~10–15%/week volume increase as fastest-gains zone.
- **RPE handling:** log 3×10 @ RPE 7 → suggests +weight next time; log @ RPE 9 with a missed rep → holds weight + adds a set, or reduces load and extends rest.
- **"Fresh muscle" reallocation:** if chest is fatigued but legs fresh, it redistributes volume to fresh groups to manage fatigue/injury risk.
- Recovery integration: **performance + subjective fatigue + muscle half-life model only — NO HRV/sleep/RHR.** Prescribes (it builds the workout). No endurance/ACWR; no physiological readiness; injury handling is the soft "don't overload a fatigued muscle" heuristic.

### 7b. Juggernaut AI (KNOWN)
- Powerlifting/strength AI coach. Logs **RPE and RIR** per set; makes real-time and week-to-week adjustments.
- **Readiness check-in before each session** (subjective) → if readiness drops, **auto-reduces accessory volume** and may recommend an **extra rest day**.
- Computes individualized **Volume Landmarks (MEV…MRV)**, optimizes frequency, and periodizes to manage fatigue (RP-derived science).
- Recovery integration: **subjective readiness check-in + RPE/RIR only — NO HRV/sleep.** Prescribes. Injury/overtraining handled via MRV ceiling + readiness-driven deloads.

### 7c. RP Hypertrophy App (Renaissance Periodization; Israetel/Hoffmann) (KNOWN)
- The canonical **Volume Landmarks** system: **MEV** (minimum effective volume), **MAV** (maximum adaptive volume), **MRV** (maximum recoverable volume).
- **Autoregulation via per-muscle feedback:** after sessions the user rates **soreness, pump, performance, and joint feedback (the "stimulus-to-fatigue" signals)** → app adjusts next session's volume in real time (add sets toward MAV, or deload when approaching MRV).
- Recovery integration: **subjective per-muscle feedback only — NO HRV/sleep/RHR.** Prescribes (auto-adjusts volume/progression). Injury/overtraining handled via the MRV ceiling + joint-pain feedback → deload.

### 7d. Boostcamp (KNOWN)
- Library of established programs (5/3/1, GZCLP, Sheiko, Smolov, Candito, PHUL/PHAT, coach blocks). Every set logs **RPE (5–10) and RIR**; offers both **%1RM and RPE** targets; auto-fills progression weights; surfaces **fatigue trends across a block** and estimated 1RMs.
- Recovery integration: **RPE/RIR autoregulation only — NO HRV/sleep.** Prescribes via the chosen program's progression; the user picks the program (it's a program-runner, not a from-scratch adaptive coach). No injury model beyond RPE-based load adjustment.

### Strength-cluster summary (the pattern)
- They **prescribe** and **autoregulate** — but **exclusively on performance + RPE/RIR + subjective readiness**. **NONE fuse physiological recovery (HRV/sleep/RHR).** **NONE model endurance/ACWR.** Injury handling is volume-ceiling + perceived-effort heuristics, not a physiological injury lens.

---

## 8. ACWR Validation/Criticism Literature (cross-cutting — informs how Tuwa should HEDGE its load model)

This matters because any app (including Tuwa) leaning on ACWR/sweet-spot must not over-claim injury prediction.

### Key critiques (KNOWN)
- **Impellizzeri et al. (2020), "Acute:Chronic Workload Ratio: Conceptual Issues and Fundamental Pitfalls" (Int J Sports Physiol Perform):** ACWR has conceptual + statistical problems — ratio-data pitfalls, mathematical coupling (acute is part of chronic), and unrecognized assumptions undermining its use as a causal/prognostic factor.
- **Time-window arbitrariness:** no physiological rationale for the specific 7d acute / 28d (or 42d) chronic spans; the windows are arbitrary (Impellizzeri 2020a,b).
- **Training load ≠ mechanical load:** ACWR (often GPS/sRPE-based) is a *training-load* metric, but **repetitive mechanical load — not training load — drives tissue damage**; so ACWR is mismatched to the injury mechanism.
- **The "random chronic workload" finding (damaging):** the acute-to-**random** chronic ratio is *as* associated with injury as the acute-to-*actual* chronic ratio — implying ACWR may carry **no real predictive value** over random data.
- **Empirical non-replication:** Sedeaud et al. found no support for the 0.8–1.3 "sweet spot"; Suarez-Arrones et al. found ACWR spikes unrelated to subsequent injury in pro soccer.
- **Editorial (Frontiers in Physiology, 2021, "Acute:Chronic Workload Ratio: Is There Scientific Evidence?"):** acknowledges heavy criticism but concludes simple monitoring tools "should not be abandoned" while calling for mechanism-based research and independent injury validation.

### Implication for Tuwa (positioning, not a competitor)
- Tuwa should **use ACWR/EWMA as a workload-trend and autoregulation input, NOT advertise it as an injury predictor.** Frame it as "are you ramping faster than your body has adapted to," fused with recovery — and be explicit that no single load ratio predicts injury. This honesty is itself a differentiator vs black-box apps that imply causation.

---

## 9. Summary Comparison Table

| Product | Load / progression method | Recovery-integrated (HRV/sleep+load)? | Prescribes ("what to do today")? | Validated / criticized | Gap for amateur no-coach user |
|---|---|---|---|---|---|
| **TrainingPeaks (PMC)** | Banister→Coggan: TSS + CTL(42d EWMA)/ATL(7d EWMA)/TSB; ramp-rate 3–7 CTL/wk | **No** — load only | **No** — describes; coach interprets | Foundational but fixed pop. constants; endurance/power-centric; ACWR critiques apply | Needs a coach to read it; no recovery fusion; no strength; jargon-heavy; no injury Rx |
| **Intervals.icu** | Same CTL/ATL/TSB (adjustable constants) + ACWR (7d:28d) | Partial — HRV/sleep **shown**, not fused | **No** — analytics dashboard | Inherits Banister/ACWR critiques; honest (adjustable) | Power-user analytics, not guidance; user must fuse recovery+load mentally; no strength |
| **Athletica** | Modified Banister fitness/fatigue/form + RPE + HRV trend, AI-adaptive | **Partial/yes** — claims HRV-trend-aware adaptation | **Yes** — adaptive plans | "AI" black box; no published formula; endurance-only | Endurance-only (no strength); black-box (no "why"); opaque HRV fusion |
| **HRV4Training / Altini** | No formal load engine; **individual HRV: 7d baseline vs 60d mean±SD normal range; CV early warning** | Readiness-first; load is logged **context**, not fused | **Partial** — green/amber/red lens, not the session | **Strongest evidence base** (Javaloyes RCT); explicit pop.-baseline critique | Readiness lens only — no progression engine, no strength model, no per-session Rx, assumes you have a plan |
| **Elite HRV** | None (pure ANS monitor) | **No** — recovery only, no load | **No** — readiness only | Individualized ln rMSSD vs personal baseline (sound); pop. scaling for 0–100 | Recovery silo; no load; no plan; no strength; no injury mgmt |
| **Restwise** | None (12-input recovery score) | **No** — recovery only | Light guidance, not per-session | Patented/proprietary **black box**; 12 manual inputs | Black-box weighting; high manual friction; no load model; no strength |
| **Fitbod** | Performance + fatigue slider + muscle-recovery half-life; ~10–15%/wk volume; RPE-reactive | **No** — subjective fatigue only, no HRV/sleep | **Yes** — builds the session | Reasonable heuristics; no physiological validation published | No physiological recovery; no endurance/ACWR; injury = soft muscle-freshness heuristic |
| **Juggernaut AI** | RPE/RIR + readiness check-in + Volume Landmarks (MEV–MRV), periodization | **No** — subjective readiness only | **Yes** — adaptive powerlifting plan | RP-derived science; powerlifting-specific | No physiological recovery (HRV/sleep); strength-only; no endurance load model |
| **RP Hypertrophy** | Volume Landmarks (MEV/MAV/MRV) + per-muscle soreness/pump/perf/joint feedback | **No** — subjective per-muscle feedback only | **Yes** — auto-adjusts volume/progression | Evidence-informed (Israetel/Hoffmann); hypertrophy-specific | No physiological recovery; hypertrophy-only; no endurance; injury = MRV ceiling/joint feedback |
| **Boostcamp** | Established programs (5/3/1, Sheiko, etc.) + %1RM/RPE/RIR autoregulation | **No** — RPE/RIR only | **Yes** (program-driven) | Runs validated programs; not adaptive from scratch | No physiological recovery; strength-only; program-runner not a coach; no injury model |
| **→ Tuwa (target position)** | EWMA/ACWR load **fused with** individualized recovery; strength PR/progression + endurance | **YES — recovery (HRV/sleep/RHR) FUSED with load** | **YES — readiness→autoregulated prescription** | Honest about ACWR (trend not injury-predictor); Altini-grade individualization | — fills every gap above for the no-coach athlete |

---

## 10. Six-Sentence Summary of Biggest Gaps for Our Target User

1. **No competitor fuses physiological recovery with a training-load model into a single prescriptive output** — endurance tools (TrainingPeaks, Intervals.icu) model load but ignore HRV/sleep, while recovery tools (Elite HRV, Restwise) and lifting apps (Fitbod, Juggernaut, RP, Boostcamp) ignore load or use only subjective readiness, leaving the no-coach athlete to mentally combine two siloed signals.

2. **The best load tools only DESCRIBE** — TrainingPeaks' Performance Manager and Intervals.icu are analytics dashboards that assume a coach (or expert athlete) will interpret CTL/ATL/TSB/ACWR, which is precisely the expertise our target user lacks.

3. **Marco Altini/HRV4Training is the closest philosophical neighbor and the most evidence-backed** (individual 7-day baseline vs 60-day mean±SD normal range, CV early-warning, explicit rejection of population baselines), but it stops at a green/amber/red *readiness lens* and never prescribes the actual session or supplies a plan — so it serves an athlete who already has a coach-written program, not one who has nothing.

4. **Strength athletes are entirely abandoned by the endurance/HRV ecosystem**, while the strength apps that do prescribe (Fitbod, Juggernaut AI, RP, Boostcamp) autoregulate purely on performance + RPE/RIR + subjective fatigue and **integrate zero physiological recovery data and no endurance load model**, so a hybrid serious amateur is forced to stitch two apps together.

5. **Injury/overtraining is handled weakly and dishonestly across the board** — ACWR's "sweet spot" has been substantially invalidated (Impellizzeri 2020; the random-chronic-workload finding; failed replications), yet apps still imply it predicts injury, while strength apps reduce injury to a volume-ceiling heuristic; an honest, recovery-fused "are you ramping faster than you've adapted" lens is an open lane.

6. **The adaptive options that do prescribe are black boxes** (Athletica's "modified Banister + AI," Restwise's patented weightings) that never explain *why*, denying the no-coach athlete the chance to learn — leaving a clear opening for Tuwa to combine Altini-grade individualized, transparent recovery scoring + an honest fused load model + actual per-session prescription across BOTH strength and endurance.

---

## Sources

- TrainingPeaks — Science of the Performance Manager: https://www.trainingpeaks.com/learn/articles/the-science-of-the-performance-manager/
- TrainingPeaks — Coach's Guide to ATL/CTL/TSB: https://www.trainingpeaks.com/coach-blog/a-coachs-guide-to-atl-ctl-tsb/
- Joe Friel — Managing Training Using TSB: https://joefrieltraining.com/managing-training-using-tsb/
- FasCat — Performance Manager Chart (WKO/TrainingPeaks): https://fascatcoaching.com/blogs/training-tips/performance-manager-chart/
- Intervals.icu — Fitness, Fatigue & Form Chart: https://www.intervals.icu/features/fitness-chart/
- Intervals.icu Forum — CTL/ATL/TSB calculations: https://forum.intervals.icu/t/weekly-calculations-for-ctl-atl-tsb-required-tss-for-optimal-tsb-etc/59297
- Athletica — homepage / adaptive endurance engine: https://athletica.ai/
- Athletica — How AI is Shaping Endurance Training: https://athletica.ai/the-athletes-compass-podcast/how-ai-is-shaping-endurance-training-insights-from-athletica/
- Simple Endurance Coaching — Athletica adaptive training review: https://simpleendurancecoaching.com/watch-your-workouts-adapt-to-past-training-stress-on-athleticas-ai-responsive-training-platform/
- Marco Altini — HRV-Guided Training to Improve Performance: https://medium.com/@altini_marco/heart-rate-variability-hrv-guided-training-to-improve-performance-24b0ec24e6f8
- Marco Altini — On HRV and Readiness: https://medium.com/@altini_marco/on-heart-rate-variability-hrv-and-readiness-394a499ed05b
- Marco Altini — What's your normal range for HRV (60d mean±SD): https://marcoaltini.substack.com/p/whats-your-normal-range-for-heart
- Marco Altini — HRV4Training Pro user guide: https://marcoaltini.substack.com/p/hrv4training-pro-user-guide
- Triathlete — All You Need to Know About Training with HRV (Altini): https://www.triathlete.com/training/all-you-need-to-know-about-training-with-heart-rate-variability/
- Elite HRV — How is Morning Readiness determined: https://help.elitehrv.com/article/56-how-is-morning-readiness-determined
- Elite HRV — 1–10 Relative Balance Score (Morning Readiness): https://help.elitehrv.com/article/57-the-1-10-relative-balance-score-morning-readiness
- Elite HRV — How is the HRV score calculated: https://help.elitehrv.com/article/54-how-do-you-calculate-the-hrv-score
- Restwise — ESP Fitness overview: https://esp-fitness.com/software/restwise/
- Svexa acquires Restwise: https://svexa.com/svexa-acquires-restwise-bolstering-strength-in-intelligent-athlete-recovery-solutions/
- Fitbod — How Fitbod's AI knows when to lift heavier/recover: https://fitbod.me/blog/how-fitbods-ai-knows-exactly-when-you-should-lift-heavier-and-when-to-recover/
- Fitbod — Progressive overload built in: https://fitbod.me/blog/what-is-progressive-overload-and-how-fitbod-builds-it-into-every-workout-automatically/
- JuggernautAI review (Dr. Muscle): https://dr-muscle.com/juggernaut-workout-app-review/
- PowerliftingTechnique — Juggernaut AI review: https://powerliftingtechnique.com/juggernaut-ai-review/
- Renaissance Periodization — Training Volume Landmarks (MEV/MAV/MRV): https://rpstrength.com/blogs/articles/training-volume-landmarks-muscle-growth
- Arvo — RP Training Volume Landmarks & Mesocycles guide: https://arvo.guru/resources/methods/rp-training
- Boostcamp — RPE vs Percentage Training: https://www.boostcamp.app/blogs/rpe-vs-percentage-training-comparison
- Boostcamp — Features: https://www.boostcamp.app/features
- Impellizzeri et al. (2020), ACWR Conceptual Issues and Fundamental Pitfalls (IJSPP): https://journals.humankinetics.com/view/journals/ijspp/15/6/article-p907.xml
- Frontiers in Physiology (2021) Editorial — ACWR: Is There Scientific Evidence?: https://pmc.ncbi.nlm.nih.gov/articles/PMC8138569/
- SimpliFaster — The ACWR: Not an Injury Predictor: https://simplifaster.com/articles/acwr-high-performance-tool/
