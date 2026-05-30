# Competitive-Algorithm Differentiation Analysis — Tuwa v1

**Status:** Strategy synthesis for build/no-build gate on algorithm v1.
**Date:** 2026-05-30
**Lens (non-negotiable):** the **amateur-serious / no-coach** athlete — trains hard, has an iPhone + maybe an Apple Watch / consumer wearable, often does strength or hybrid (not pure endurance), and has **no coach, physio, or sports scientist**. Every judgment below is made *for this user*, not for the general market.

**Inputs synthesized:** `competitor-research-wearables.md`, `competitor-research-load-apps.md`, `algorithm-moat-design.md` (PRS spec + codex addendum + revised "v1 Robust Personal Baseline"), `Tonus_Market_Competitive_Analysis.md`, and the live engines (`RecoveryScoreEngine`, `AutoregulationEngine`, `WorkloadCalculator`, `FatigueIndexEngine`).

**This document builds on the existing market analysis — it does not re-litigate market size, distribution, or the Apple-threat. It answers one question: is v1's *algorithm* genuinely differentiated for the no-coach athlete, and what to change before building.**

---

## 0. Code reality check (so every claim below is real, not aspirational)

| Claim Tuwa wants to make | Status in actual code today | Verdict |
|---|---|---|
| "Recovery is individualized, not population" | `RecoveryScoreEngine` baselines on a **7-day rolling mean** of the person's own data | TRUE but **commodity** — identical to every Whoop/Oura clone; weaker than Altini's 60-day band |
| "We fuse recovery with load" | Recovery + load are computed separately and **joined in `AutoregulationEngine` via a `(recoveryZone × ACWRZone)` matrix** | TRUE — fusion exists, but the load axis is ACWR (invalidated) |
| "We prescribe the day's training" | `AutoregulationEngine.recommend` emits **RPE cap + volume % + session type + plain-English headline/detail** | **TRUE and real** — this is the strongest asset in code |
| "Strength-inclusive load" | Load = **Foster sRPE** (`minutes × RPE`) — sport-agnostic, so a heavy-lifting session does register via RPE+duration. **But there is NO tonnage/mechanical-load model**; TRIMP (HR-based) is near-useless for lifting | **HALF-TRUE** — strength enters via sRPE only; no dedicated strength-load model |
| "Honest about ACWR" | ACWR is still a **load-bearing input** to the autoregulation matrix and drives warnings (`acwrDanger`/`acwrCaution`) | **FALSE today** — ACWR is currently central, not demoted. `FatigueIndexEngine` is ACWR-free, but it only *modulates* within ACWR-set guardrails |
| "Explainable" | `ReasoningEngine` produces ranked human factors; recovery components are surfaced | TRUE — genuine asset |
| "On-device, no extra hardware" | HealthKit reads only; composite scores sync, raw data never leaves device | **TRUE and structural** |

**Headline:** three of Tuwa's differentiators (prescription, explainability, on-device privacy) are **real in code today**. The recovery-individualization claim is real-but-commodity. The strength-load and ACWR-honesty claims are **not yet true** and are exactly what v1 must fix. v1's value is therefore less about new math and more about **(a) making the load axis strength-aware and ACWR-honest, and (b) hardening the personal baseline** — while keeping the prescription/explainability assets that already win.

---

## 1. Competitive landscape map — where the white space is

Three axes matter for the no-coach athlete. Plotting all competitors:

### Axis A — Passive wellness ↔ Prescriptive guidance
```
PASSIVE/DESCRIBES ──────────────────────────────────────► PRESCRIBES "what to do today"

Apple Vitals ── Oura ── Fitbit ── Elite HRV ── WHOOP ── Garmin ── Intervals.icu
  TrainingPeaks(PMC) ──────── HRV4Training/Altini ── Restwise ──┤
                                                                │
                          Athletica ── Fitbod ── Juggernaut ── RP ── Boostcamp ── ►[TUWA]
```
- **Left cluster (just measures / describes):** Apple, Oura, Fitbit, Elite HRV, WHOOP, Garmin, TrainingPeaks, Intervals.icu. They show a number or a chart; the athlete (or their coach) decides what to do.
- **Right cluster (prescribes):** the strength apps (Fitbod, Juggernaut, RP, Boostcamp), the AI endurance coach (Athletica), and **Tuwa**. Altini *guides* (green/amber/red) but stops short of the session.
- **The no-coach user needs the right side** — they have no coach to interpret a chart. This already eliminates the entire wearable cluster and TrainingPeaks/Intervals as adequate solutions for this user.

### Axis B — Cardio-only ↔ Strength + Endurance
```
CARDIO-ONLY ─────────────────────────────────────────────► STRENGTH + ENDURANCE

WHOOP(strain) ── Garmin(EPOC) ── Apple ── Polar ── TrainingPeaks ── Athletica ── Intervals
   Oura/Fitbit/Elite HRV (no load model at all)
                                                          Fitbod/Juggernaut/RP/Boostcamp ►(strength-only)
                                                                              [TUWA] ◄── spans both
```
- **Endurance pole:** every wearable load metric (WHOOP Strain, Garmin EPOC, Apple Effort×Duration, Polar Cardio/Muscle Load, TrainingPeaks TSS, Athletica) is **cardiovascular**. Polar's "Muscle Load" requires a running/cycling **power meter** — still no barbell.
- **Strength pole:** Fitbod/Juggernaut/RP/Boostcamp model strength well but have **zero endurance load and zero physiological recovery (no HRV/sleep)**.
- **The middle is empty.** Nobody fuses physiological recovery with a load model that covers **both** strength and endurance. This is the single emptiest cell on the map and the most defensible for a *hybrid* serious amateur. **Caveat:** Tuwa only half-occupies it today (sRPE covers strength volume-as-effort, but no tonnage model) — see §5.

### Axis C — Black-box ↔ Explainable
```
BLACK-BOX ───────────────────────────────────────────────► EXPLAINABLE / "tells you WHY"

WHOOP ── Restwise ── Athletica ── Oura ── Fitbit ── Polar ── Elite HRV ── Garmin(TR factors) ── Altini ──[TUWA]
```
- WHOOP (undisclosed weights, offloads "why" to a manual Journal), Restwise (patented weighting), and Athletica ("modified Banister + AI") are the black boxes.
- Garmin color-codes its Training Readiness factors (best of the hardware set); Altini is transparent about his 60-day band and CV logic.
- **Tuwa sits at the explainable extreme** (ReasoningEngine ranked factors + glass-box logistic in v1) — co-located with Altini, ahead of everyone who prescribes.

### The white space (intersection of all three)
> **No product is simultaneously (right on A) prescriptive, (right on B) strength+endurance, and (right on C) explainable — on hardware the user already owns.** Athletica is prescriptive + endurance-only + black-box. Fitbod is prescriptive + strength-only + no-recovery. Altini is explainable + endurance-leaning + describes-only. **Tuwa is the only candidate in the prescriptive ∩ hybrid ∩ explainable ∩ no-extra-hardware cell.** That cell — not "individualized baselines" — is the white space.

---

## 2. The 5 concrete gaps competitors leave for the no-coach amateur

Synthesized and de-duped across both research docs, ranked by **(defensibility × value)** for *this* user.

| # | Gap | Who leaves it open | Defensible? | Valuable to no-coach user? | Rank |
|---|---|---|---|---|---|
| **G1** | **Recovery and load are siloed — nobody fuses physiological recovery WITH a load model into one prescriptive output.** Endurance/load tools (TP, Intervals) ignore HRV/sleep; recovery tools (Elite HRV, Restwise) and lifting apps (Fitbod, Juggernaut, RP) ignore load or use only subjective fatigue. | All of them, from both directions | **High** — requires *both* a recovery model and a load model done well; most companies are structurally committed to one side | **Very high** — fusing the two is exactly the coaching judgment this user lacks | **1** |
| **G2** | **Nobody prescribes the day's adjustment for a no-coach athlete who has no plan.** The best load tools (TP, Intervals) only describe; Altini guides but assumes you already have a coach-written program; the strength apps prescribe but on subjective inputs only. | TP, Intervals, Altini, Elite HRV, Oura, WHOOP, Garmin (generic only) | **Medium-high** — prescription is a product/UX problem more than a moat, but doing it *fused + explainable* is hard | **Very high** — this is the literal job-to-be-done (replace the coach) | **2** |
| **G3** | **Strength/hybrid athletes are abandoned by every recovery+load ecosystem.** Every wearable "load" is cardiovascular; the one "Muscle Load" (Polar) needs a power meter. Strength apps have no physiological recovery or endurance load. | Every wearable + every endurance app + every strength app | **High** — endurance-DNA companies won't pivot to barbells; strength apps won't add HRV/endurance models | **High** (for the hybrid/strength subset, which is a stated core of the user base) | **3** |
| **G4** | **No honest injury/overtraining lens — the category is dishonest about ACWR.** ACWR's injury-prediction has been substantially invalidated (Impellizzeri 2020-21; random-chronic finding; failed replications), yet apps still imply it predicts injury; strength apps reduce injury to a volume-ceiling heuristic. | WHOOP/Oura/Garmin (no injury lens), TP/Intervals (imply ACWR), strength apps (volume ceiling) | **Medium** — honesty is a *positioning* asset, easily copied if someone chooses to; but few will because it's less marketable | **Medium-high** — protects trust; the *absence* of false injury claims is a feature for a savvy user | **4** |
| **G5** | **Explainability is poor-to-partial across everyone who prescribes.** The apps that DO prescribe (Athletica, Restwise) are black boxes; the explainable ones (Garmin factors, Altini) only describe. Nobody both prescribes AND explains *why*, which is how a no-coach user learns. RCT evidence shows explained feedback measurably reduces injury. | Athletica, Restwise (black box); Garmin/Altini (explain but don't prescribe) | **Medium** — copyable, but only by someone who also has a glass-box model | **High** — learning *why* is how this user becomes self-sufficient; it's the "coach teaches you" value | **5** |
| **G6** | **(Lower) Hardware + subscription lock-in to a second ecosystem.** Every wearable forces a strap/ring/watch + sub. | WHOOP, Oura, Garmin, Polar, Fitbit | **Low** — Athlytic, HRV4Training already exploit "Apple-Watch-only / no extra hardware"; not unique | **High to user, low as a moat** | n/a (table-stakes, not a wedge) |

**Note:** G6 is real for the *user* but is NOT a differentiator vs Athlytic/HRV4Training, who already run on owned hardware. Treat "no extra hardware" as table-stakes-for-this-segment, not the wedge.

**The defensible core is G1 + G3 fused, prescribed (G2), honestly (G4), explainably (G5).** Each alone is copyable; the *combination* is what no incumbent is structurally positioned to assemble.

---

## 3. Does v1 actually win? — honest, gap-by-gap verdict

Testing the **revised codex-corrected v1** ("Robust Personal Baseline": robust EWMA/Welford/MAD baselines → prequential personal z-scores → fixed sign-constrained glass-box logistic fusion → Readiness scalar + separate heuristic Strain-Risk flag; recovery fused with a strength+endurance sRPE load model; prescriptive autoregulation; honest-about-ACWR; on-device; explainable).

| Gap | Does v1 win? | Honest verdict — real advantage vs marketing |
|---|---|---|
| **G1 (recovery⊕load fusion)** | **YES — and this is the genuine win.** v1 keeps the `(readiness × strain-risk)` autoregulation matrix that already fuses both axes, now with a hardened recovery baseline and an ACWR-demoted load axis. | **REAL.** No competitor fuses physiological recovery with a load model into one prescriptive output. This is structural, not cosmetic — and it's already half-built in code. The moat is the *fusion + prescription*, not the baseline math. |
| **G2 (prescription)** | **YES.** `AutoregulationEngine` already emits RPE cap + volume + session type + plain-English rationale. v1 swaps the ACWR input for Strain-Risk but keeps the prescriptive shell. | **REAL but copyable.** Prescription is product work, not a math moat. The advantage is that we prescribe *from a fused, explainable signal*, which Athletica (black-box, endurance) and the strength apps (no recovery) cannot. |
| **G3 (strength+endurance)** | **PARTIAL — the weakest link.** sRPE makes load sport-agnostic so lifting *registers*, but v1 as specified still has **no tonnage/mechanical-strength-load model**. A heavy 3×3 deadlift day and a moderate 5×10 day at the same RPE+duration score identically, which is wrong for strength stimulus. | **HALF-REAL.** "Spans strength" is true vs endurance apps (we don't ignore lifting) but is **not yet a strong strength model**. This is the gap most at risk of being marketing rather than substance. **v1 must make strength load first-class (see §5) or soften the claim.** |
| **G4 (honest ACWR / injury)** | **YES, if v1 actually demotes ACWR.** Today ACWR is still load-bearing in the matrix. v1's plan to reclassify ACWR as context-only and replace the matrix's load axis with the FEA-lineage Strain-Risk flag is the correct, honest move. | **REAL as positioning, only if shipped.** The honesty is a true differentiator *because few competitors will choose it* — but it's only real once the code stops gating decisions on ACWR. Right now this claim would be false. |
| **G5 (explainable prescription)** | **YES.** Glass-box logistic over named z-features + ReasoningEngine ranked factors + confidence markers. | **REAL.** This is the cleanest win after G1 — we both prescribe and explain, which nobody else does. RCT evidence (explained feedback ↓ injury) backs the *value*. |

### The brutal part — what makes us better than HRV4Training/Altini *specifically* for this user?

Altini is the right comparison and the spec is honest that he already does individualized baselines, is evidence-backed, and rejects population norms. **v1's baseline math does NOT beat Altini** — robust EWMA/Welford/MAD is, if anything, slightly *behind* his published 60-day-mean±SD band + CV early-warning, which is a more mature, validated construct. **If our pitch is "better individualized HRV baselines," we lose to Altini.**

We beat Altini on **four things he structurally does not do**, none of which are "better baseline math":
1. **We close the last mile — prescribe the actual session.** Altini gives green/amber/red and the *principle*; the athlete maps it onto a plan they already have. Our user has **no plan and no coach** — Altini's product assumes the very thing this user lacks. We supply both the readiness lens *and* the prescribed adjustment.
2. **We fuse recovery with a formal load model.** Altini is HRV-first with load as logged *context*; he explicitly says "monitoring load alone is insufficient" but does not run a CTL/ATL/strain engine fused into the readiness call. We do (G1).
3. **We span strength.** Altini is endurance-leaning; a serious lifter/hybrid amateur is not his user. (Contingent on §5 fixing strength-load.)
4. **We're a complete daily decision, not a research instrument.** HRV4Training's UX is researcher-grade (the market analysis flags this); ours is a single prescriptive daily story.

**So: v1's advantage over Altini is REAL but it lives entirely in fusion + prescription + strength + UX — NOT in the baseline statistics.** Any positioning that leads with "individualized baselines" is marketing we will lose on. Lead with the fusion+prescription, borrow Altini's *validated* baseline construct rather than inventing a weaker one, and credit him.

### Net verdict on v1-as-specified
- **G1, G2, G5: genuine wins, several already real in code.**
- **G4: a genuine win only once ACWR is actually demoted (not true today).**
- **G3: the soft spot — strength-load is half-built; the claim outruns the code.**
- **Baseline math: at parity-or-behind Altini; not a differentiator; do not lead with it.**

---

## 4. The defensible wedge (one paragraph)

> **Tuwa is the only app that fuses individualized physiological recovery with a load model that includes strength — and then *prescribes the day's training adjustment*, explainably, on hardware the athlete already owns, while being honest that no load ratio predicts injury.** Every competitor occupies exactly one corner of this: WHOOP/Oura/Garmin/Apple *measure* recovery but never prescribe and never model strength; TrainingPeaks/Intervals *model load* but ignore recovery and need a coach to read them; HRV4Training/Altini *guide by readiness* but assume you already have a coach-written plan and don't touch strength; Fitbod/Juggernaut/RP *prescribe strength* but are blind to HRV, sleep, and endurance. The no-coach serious amateur is forced to stitch two or three of these together and still do the integration — the coach's job — in their own head. Tuwa does that integration for them in one explainable daily decision. **The wedge is not "individualized baselines" (Altini already owns that and our math doesn't beat his) — it is the fusion-to-prescription across strength+endurance, explained, that no incumbent is structurally positioned to assemble.**

**Validated against the research, with one sharpening:** the original candidate wedge bundled "individualized recovery" as a lead differentiator. The research shows that is Altini's turf and our v1 baseline doesn't beat it — so the sharpened wedge **demotes baseline-individualization to table stakes and elevates fusion+prescription+strength+honesty as the load-bearing differentiation.** That is the true, defensible version.

---

## 5. What to CHANGE in v1 before building

Concrete adjustments to the `algorithm-moat-design.md` v1 scope so it maximally exploits the gaps. Ordered by leverage.

### CHANGE 1 — Make strength-load fusion the HERO, not an afterthought (closes G3, the soft spot)
v1 as specified treats the load model as "keep sRPE primitives, demote ACWR." That leaves strength under-modeled and makes the G3 claim marketing. **Add a first-class strength-load signal** so a heavy-low-rep day and a high-volume day differ:
- Compute a **mechanical/volume-load primitive for resistance sessions** (tonnage = Σ sets×reps×load, and/or hard-set count toward a personal volume-tolerance band — the RP "MEV…MRV" idea, which the strength apps validate). We already log sets/reps/weight (`SetRecord`), so the data exists on-device.
- **Fuse two load channels** (sRPE/TRIMP cardio-internal + tonnage/hard-set strength-mechanical) into the Strain-Risk flag, instead of one sRPE number. This is what *no* competitor has (Polar's muscle load needs a power meter; strength apps have no recovery).
- This converts G3 from "half-true" to "the most defensible cell on the map." **Highest-leverage change.**

### CHANGE 2 — Actually demote ACWR in the decision path, now (closes G4, makes honesty real)
Today ACWR drives the autoregulation matrix and warnings. v1 must:
- Replace the matrix's load axis `(recoveryZone × ACWRZone)` → `(readinessZone × strainRiskZone)`, where Strain-Risk is the ACWR-free `FatigueIndexEngine` lineage (+ strength load from CHANGE 1 + Foster monotony with a completeness gate).
- Keep ACWR computed **as a labeled context line only**, removed from every decision and warning.
- This is the difference between "honest about ACWR" being true vs being a slide. Do it in v1, not later.

### CHANGE 3 — Lead the product with explainability + honesty as FEATURES, harden the baseline modestly (re-prioritizes vs Altini)
- **Do not lead with "individualized baselines"** — we lose that comparison to Altini. Lead with "explains why, prescribes what, honest about limits."
- **Borrow Altini's *validated* construct explicitly** instead of a weaker home-grown one: a **rolling personal normal band (mean ± SD over a multi-week window) + a CV/volatility early-warning**, framed and credited the way he frames it. The codex-corrected v1 already moved to robust EWMA/Welford/MAD — extend it to *also* surface a normal-range band and a volatility flag (his two signature signals) so we're at least at parity, not behind. This is cheaper and more defensible than the deferred Kalman.
- Keep Kalman + per-user weight learning deferred (codex was right — not identifiable on ~60 days of autocorrelated consumer data).

### CHANGE 4 — Build the prequential validation data-contract FIRST (de-risks every claim)
Per the codex addendum: before any model code, fix `predictionDate / targetDate / feature-cutoff / outcome-window`, day-bucket HealthKit inputs (avoid stale-sample fake stability), and add calibration + Spearman + blocked CV + bootstrap CI to the shadow harness. **Use raw self-report/soreness/adherence as labels, not engine-generated "next-day recovery score"** (circular). This is what lets us *honestly* claim "validated against your own outcomes" — itself a differentiator vs black-box competitors.

### CHANGE 5 — Frame Strain-Risk as a context flag, never injury prediction (locks G4)
Ship the strain channel as "you're ramping faster than you've adapted / your week is monotonous" — a **probability-shift context flag**, never "injury risk: X%." Validate it against soreness/load-tolerance/adherence proxies, not injury AUC (near-zero events per user). This is both scientifically honest and a positioning asset.

**Summary of the v1 delta:** the original v1 scope is sound on baselines/validation but **under-weights strength-load and treats ACWR-demotion + explainability/honesty as background.** The corrected priority is: **strength-load fusion (hero) → ACWR actually demoted → explainability/honesty as the lead features → validation contract first → baseline math at parity-with-Altini, not the headline.**

---

## 6. Evidence + honesty guardrails (what we can and cannot claim)

**Can claim (defensible, sourced):**
- "Fuses your recovery with your training load and tells you how to adjust today" — true in code (autoregulation matrix), unique in market (§1 white space).
- "Explains *why* your readiness is what it is" — true (ReasoningEngine; glass-box logistic). RCT evidence that explained feedback reduces injury supports the *value* (PMC10905988).
- "Learns *your* normal, not a population average" — true, but **co-credit/parity with Altini**; do not claim superiority of the baseline statistics.
- "Runs on hardware you already own; raw health data never leaves your phone" — structurally true; differentiator vs cloud-uploading wearables.
- "We don't pretend a single ratio predicts injury" — true and honest; ACWR's injury-prediction is substantially invalidated (Impellizzeri & Tenan 2020; Impellizzeri 2020 *Time to Dismiss ACWR*; random-chronic-workload finding; 2025 meta-analysis; failed replications Sedeaud, Suarez-Arrones).

**Cannot / must NOT claim:**
- **NOT "injury prediction" or "injury risk score."** ACWR is invalidated as a predictor; per-user injury events are near-zero so no per-user injury model is possible. Strain-Risk is a **context flag / probability shift**, full stop.
- **NOT "the best/most accurate recovery baseline."** Altini's 60-day band + CV is more mature and published; our v1 math is at parity at best.
- **NOT "validated" in the clinical sense** until the shadow harness clears the (corrected) gates on real self-reported outcomes with blocked CV — and even then, frame as "shadow-validated against your own outcomes," not peer-reviewed.
- **NOT over-trust HR-based load (TRIMP) for lifting** — heavy strength barely moves HR; sRPE + tonnage carry the strength signal.
- **NOT cargo-cult the elite injury-ranking research** (fixture congestion, travel, position multipliers don't exist for a consumer); borrow only the individually-transferable primitives (soft-tissue memory, acute-load elevation, monotony).

**The honesty itself is a moat-adjacent asset:** in a category that implies causation it doesn't have (ACWR), being explicit about limits builds the trust this user needs to actually change behavior — and trust is the only durable advantage an on-device app has (no pooled-data network effect; a competitor can mimic "learns your normal" with EWMA+z-scores).

---

## 7. Open questions for the user (genuine positioning/scope calls)

1. **Strength-load investment.** CHANGE 1 (first-class tonnage/hard-set strength-load fused into Strain-Risk) is the highest-leverage differentiator but the most build. **Is v1 willing to add a real strength-load model, or do we ship sRPE-only and *narrow the positioning to "recovery + endurance load + light strength awareness"* to avoid over-claiming G3?** This is the single biggest scope fork.
2. **Positioning lead.** Confirm we lead with **"fuses recovery+load and prescribes, explainably"** and demote "individualized baselines" to table-stakes (we lose the baseline-math comparison to Altini). Agree?
3. **ACWR demotion timing.** Demoting ACWR out of the decision path is required to make the honesty claim true. Confirm we do it in v1 (it changes current recommendations for existing users) rather than deferring.
4. **One number or two.** The spec recommends Readiness + a separate Strain-Risk channel (one trajectory, two channels). Confirm — vs a single fused scalar. (Strongly recommend two; a recovered athlete carrying dangerous load is the most important case to surface and a blend hides it.)
5. **Injury self-log.** Strain-Risk can only be honestly validated against soreness/adherence proxies without an outcome label. Add a lightweight "tweak"/injury log, or accept proxy-only validation?
6. **Altini relationship.** Are we comfortable *explicitly crediting/borrowing* Altini's normal-band + CV approach (more defensible and honest) rather than claiming a novel baseline? This affects both the math and the marketing voice.
7. **Strength subset weight.** How central is the strength/hybrid athlete to the launch target? If they're the core, CHANGE 1 is mandatory; if endurance-leaning amateurs are the beachhead, sRPE-only v1 may suffice and G3 becomes a v2 expansion.
