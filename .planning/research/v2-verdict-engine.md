# v2.0 Verdict Engine — Math + UX Research

**Dimension:** The TODAY-verdict engine's MATH and UX for the v2.0 wedge.
**Job-to-be-done:** given (a) a planned strength session with a target top set, (b) today's readiness vs the athlete's own baseline, and (c) cross-modal fatigue (yesterday's run hits today's squat, barely touches bench), output **an adjusted top-set number + a go/modify/hold verdict + a one-line why**, as **suggest-and-confirm**, feel-overridable, never overwriting the plan.
**Researched:** 2026-06-13
**Overall confidence:** MEDIUM-HIGH on the math (evidence-defensible bands exist; existing engines already produce the inputs); HIGH on the "reuse not rebuild" mapping (verified in code); MEDIUM on UX precedent (forum-mined + vendor docs, not controlled trials).

> **Framing constraint inherited from the pressure-test (hard product constraint):** the verdict is a *number + reason the athlete confirms*, never a red don't-train gate. The two validated cracks — **nocebo** (a pre-session "hold" poisons the session) and **autonomy** (self-coached athletes reject an app overruling them) — are UX problems the engine math must be *designed around*, not bolted onto. See `.planning/research/plan-aware-thesis-pressure-test.md` §"single core interaction" and the nocebo landmine.

---

## 0. TL;DR for requirement definition

1. **The math is mostly built.** Tuwa already ships `ReadinessFusionEngine` (personal-z logistic → Readiness 0–100 + zone), `StrainRiskEngine` (cross-modal load-tolerance flag, the cross-modal anchor), `BaselineEngine` (robust personal baselines + confidence), `StrengthLoadEngine` (per-muscle hard-set/relative-intensity), and `AutoregulationEngine.recommendReadiness` (a **3×3 readiness × strain-risk matrix** emitting `intensityCap`, `volumeModifier`, `sessionType`, headline, detail). v2.0's verdict is a **thin translation layer** on top of these, not a new model.
2. **The one genuinely new piece** is mapping the existing `volumeModifier`/`intensityCap` onto a **concrete adjusted top-set number** for the *planned* lift, plus collapsing the recommendation into a **go / modify / hold** trichotomy with a **one-line why** assembled from `ReasoningEngine.explainDecision` (which already exists and already ranks readiness + strain factors).
3. **Evidence-defensible adjustment magnitude:** a readiness-driven **top-set load trim of roughly −5% to −10%** in the "amber" tier and a **session-character change (swap hard for easy / hold)** in the "red" tier. Going beyond ~10% on load from a daily readiness signal alone is **not** evidence-defensible — the daily-readiness literature supports *modulating session character and small load/volume*, not large precise load deltas. Keep deltas conservative and rounded to real plate increments.
4. **Verdict thresholds should ride the zones that already exist** (`ReadinessZone` low/moderate/high cut at 40/65; `StrainRiskZone` low/moderate/elevated/high at .25/.50/.70) rather than inventing new ones — the matrix already encodes go/modify/hold semantics; v2.0 just labels its cells.
5. **UX:** lead with the number + reason, show the *delta from the plan* not a traffic light, make "keep my plan" a one-tap first-class action, log the disagreement, and **never** show a bare "HOLD / don't train" as the primary affordance. Precedent: TrainerRoad Adaptive Training's accept/decline + post-workout survey is the closest working model; Whoop/Oura's bare score is the validated failure mode.

---

## 1. Existing engines — what each already outputs (REUSE, do not rebuild)

Verified by reading the code (`WorkloadApp/Services/`). This is the substrate v2.0 builds on.

| Engine | Status in code | Output (verified) | Role in the verdict |
|---|---|---|---|
| `BaselineEngine` | Built, pure, **tested-only at runtime** (see note) | Per-signal (HRV/RHR/sleep) robust EWMA baseline + MAD scale + **prequential personal z** (`+z = better`, `nil` in cold-start, never imputed) + Altini CV early-warning + **0–1 confidence** (honest-low cold-start, no population prior) | Supplies the readiness deviation magnitude (the "12% below baseline" in the one-liner) **and the confidence that gates how loud the verdict is** |
| `ReadinessFusionEngine` | Built, pure | **Readiness 0–100**, `ReadinessZone` (low <40 / moderate / high ≥65), **ranked factors** (label, z, signed contribution), confidence (reported separately, NOT folded), `missingSignals` flag. FIXED sign-locked logistic weights (HRV .9, sleep .7, RHR .6, subj-trend .3) | The readiness axis of the verdict. Its **ranked factors are the raw material for the one-line why** |
| `StrainRiskEngine` | Built, pure | **0–1 score**, `StrainRiskZone` (low/moderate/elevated/high at .25/.50/.70), ranked factors, confidence. Fuses **per-muscle strength-load elevation (.30, highest weight)** + endurance-load elevation + fatigue composite + Foster monotony + soft-tissue memory + rest debt | **THIS is the cross-modal anchor.** Endurance-load-elevation + per-muscle elevation is exactly "yesterday's run loaded legs, today's squat is affected; bench isn't." Differentiator vs Garmin/Whoop |
| `StrengthLoadEngine` | Built, pure | Per-muscle `hardSetCount`, relative-intensity buckets (light/mod/heavy/maximal off **est-1RM via Epley**, reused from `SetRecord.estimated1RM`), acute-vs-chronic **elevation 0–1**, same-region recurrence, `hasChronicBaseline` | Per-muscle elevation → which lifts today's verdict touches. Also the **est-1RM reference** the adjusted top-set number is computed against |
| `AutoregulationEngine` | Built; **legacy `(recovery×ACWR)` path is LIVE**, new `(readiness×strainRisk)` path is **flag-gated OFF** (`PRSActivation.isEnabled == false`) | `TrainingRecommendation`: **`intensityCap` (max RPE 1–10)**, **`volumeModifier` (1.0=full … 0.0)**, `sessionType` (power/strength/hypertrophy/conditioning/activeRecovery/rest), warnings, headline, detail. New `recommendReadiness` is a **3×3 readiness × strain matrix** + continuous fatigue modulation + consecutive-day override | **The verdict's decision core already exists.** `volumeModifier`+`intensityCap` are exactly what translate into "trim the top set / hold / go." v2.0 turns this struct into a top-set number + go/modify/hold label |
| `ProgressionEngine` | Built, pure | Per-exercise `SetSuggestion` (weightKg, reps, rpe, …) + `ProgressionType` (.increase/.maintain/.deload/.returnFromBreak) + rationale. **Already consumes `AutoregulationEngine` `volumeModifier`/`intensityCap`** and computes concrete target weights (rounds to 1.25kg, caps +5kg/wk, deload = −(lastWeight×(1−volumeModifier))) | **Closest thing to "the adjusted number" already in code.** It produces a concrete target weight per exercise from the autoregulation output. v2.0's adjusted-top-set math should EXTEND this, not duplicate it |
| `ReasoningEngine` | Built, pure | `summarize` → ranked recovery factors (legacy). **`explainDecision` (Phase 28) → ranked, confidence-annotated `DecisionReason`s** that interleave readiness factors ("Holding back — HRV 1.2σ below baseline") and strain factors ("Caution — per-muscle strength-load elevation"), decomposable to named pre-update factors, **grep-guarded to never say "injury prediction"** | **The one-line why is a `prefix(1)` of `explainDecision`.** Already assembles "readiness X below baseline + heavy run yesterday → …" |
| `PRSReadinessInputBuilder` | Built, pure | Recomputes a real `ReadinessInput` from dashboard data (folds BaselineEngine over real snapshot series → real z → ReadinessFusionEngine; runs StrengthLoad+LoadDistribution+StrainRisk over real sessions) | **The wiring already exists** to produce both channels from real history on the load path. v2.0 reuses this builder |
| `FatigueIndexEngine` | Built (FEA lineage), feeds StrainRisk | composite `index` + `loadElevation`/`sessionDensity`/`recoveryTrend`/`restDebt`/`wellnessTrend`/`softTissueRisk` | Sub-input to StrainRisk; no direct verdict role |

> **CRITICAL runtime note (from `PRSReadinessInputBuilder` doc comment, verified):** `ReadinessFusionEngine.compute` and `StrainRiskEngine.fuse` are currently **called in unit tests only — never in any production file**, and `BaselineState` (@Model) is **never written in production** (the DayBucketer/BaselineEngine fold runs only in tests). The live recovery score is still the **flat 7-day mean** `RecoveryScoreEngine`, and the live recommendation is still the **legacy `(recovery × ACWR)`** matrix (flag OFF). **So v2.0's first job is to ACTIVATE this dormant-but-built pipeline on the verdict surface — it is wired but switched off.** This is a much smaller build than the design specs imply, but it means the verdict is the *first production consumer* of the PRS stack and must own its activation gate.

### What is genuinely NEW for v2.0 (not in code today)

1. **Plan/target ingestion for the verdict** — the verdict needs *today's planned top set* (exercise, target weight or %1RM, target reps, target RPE/RIR) as an input. `PrescribedWorkout` / `WorkoutTemplate` / `TemplateSet` models exist; the verdict must read a *planned* top set, not just last-session history (which is what `ProgressionEngine` does today). **Net-new: a "planned top set" input object.**
2. **The adjusted-top-set number for the planned lift** — `ProgressionEngine` computes a target from *history*; the verdict must compute an adjusted number from *the plan* × readiness × per-muscle strain. Net-new but small: `adjustedTopSet = round(plannedLoad × loadFactor(readinessZone, perMuscleStrainForThisLift))`.
3. **The go / modify / hold trichotomy + one-liner** — collapse `TrainingRecommendation` into three verdict states with a single reason string. Net-new but trivial mapping (§3).
4. **Per-lift (not per-day) cross-modal targeting** — the verdict for *squat* should read leg-region strain; the verdict for *bench* should read push/upper strain. `StrengthLoadEngine.perMuscle` + `perRegion` already exist; the verdict must select the right muscle/region for the planned lift. Net-new selection logic, data already present.
5. **The disagreement log** — record (planned, suggested, what-they-did, post-session outcome) to (a) defuse autonomy by showing the engine earns its keep on differing days, (b) feed WTP validation. Net-new lightweight model.
6. **Feel-override input** — a one-tap "I feel better/worse than this" that adjusts or dismisses the suggestion and is logged. Net-new UI + a single signed override field.

---

## 2. Readiness → concrete load adjustment (the math, with evidence)

### 2.1 What the evidence supports — and where it gets thin

| Method | What it says about magnitude | Evidence strength | Defensible for Tuwa's verdict? |
|---|---|---|---|
| **HRV-guided traffic light** (Altini, Kubios) | Green = full session; **Amber (~7-day mean 10–15% below individual baseline) = reduce intensity ~10–15%**; Red (sustained drop) = swap hard for Z2/active recovery | MODERATE. HRV-guided ≈ predefined at group level, *small margin*, BUT **fewer athletes worsen and more improve** — the individual-variance win is the real benefit ([Granero-Gallegos meta 2020](https://www.mdpi.com/2076-3417/10/23/8532); [Düking/Manresa-Rocamora meta 2021, PMC8507742](https://pmc.ncbi.nlm.nih.gov/articles/PMC8507742/)) | YES for **session character** (go vs easy-swap) and a **small load/intensity trim**. The 10–15% is an *intensity/character* lever in the endurance literature, not a precise barbell-load delta |
| **RIR / RPE autoregulation** | Adjust load to hit a target RIR/RPE on the day; if daily readiness is low or the top set was overrated, **reduce load by one increment** and preserve bar speed/technique (RTS) | STRONG. Autoregulation (load + volume) ≥ fixed loading for strength/hypertrophy ([Shattock/Tee-style meta, PMC8762534](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC8762534/)); APRE highest-efficacy in the 2025 network MA (cited in core redefinition) | YES — and it's the **right framing for self-coached lifters** (they already think in RPE/RIR). "One increment" ≈ the smallest real plate change (1.25–2.5kg or ~2.5–5%) |
| **APRE** (autoregulatory progressive resistance) | Sets 1–2 at 50%/75% of working RM, set 3 = AMRAP at RM, **set 4 load adjusted from set-3 rep count** per a fixed table (more reps than target → up; fewer → down) | STRONG for within-session next-set adjustment ([Training & Conditioning](https://training-conditioning.com/article/understanding-apre-part-2/); [auto-reg meta PMC7994759](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7994759/)) | PARTIAL — APRE adjusts *within* the session from a performed set; Tuwa's verdict is *pre*-session. Use APRE as the **fallback/confirm loop** ("warm-up felt heavy → drop a notch"), not the primary pre-session number |
| **Velocity-loss / bar speed** | Warm-up at fixed % vs historical speed → slow = under-recovered; VL ≤25% favors strength; readiness inferred from first-rep velocity vs personal norm | STRONG but **needs a velocity device** Tuwa doesn't have ([velocity-loss meta PMC8762534]; [SetForSet VBT guide](https://www.setforset.com/blogs/news/autoregulation-tools-for-strength-training)) | NO for the pre-session number (no sensor). YES as a **post-warm-up confirm prompt** ("your top warm-up felt RPE-high vs usual → consider the suggested trim") if/when the athlete logs warm-up RPE |
| **Subjective wellness (Hooper: sleep/fatigue/stress/soreness)** | Higher Hooper (worse wellness) → lower perceived/tolerated load; **best single cheap acute-load predictor**, r≈0.45–0.86 with sRPE depending on study | MODERATE-STRONG, cheap, daily ([Hooper-index basketball study PMC6714361](https://pmc.ncbi.nlm.nih.gov/articles/PMC6714361/); core-redefinition science stack) | YES — already an input to both channels; strengthens the verdict when HRV is missing/cold-start |

**Bottom line on magnitude (evidence-defensible envelope):**

- **Load trim from daily readiness alone: cap at ~−10%, default −5%.** The HRV literature's 10–15% is an *intensity/character* lever; applied to a barbell top set, anything beyond one notch (~−5%, sometimes −10% for a clearly-bad day) outruns the evidence. **Round to real plate increments** — a "−7.3%" suggestion is false precision and erodes trust.
- **Volume trim can be larger than load trim** (the autoregulation literature supports cutting *back-off sets* / hard-set count more readily than the top-set load). Tuwa's `volumeModifier` already does this. Prefer **"keep the top set, cut a back-off set"** over a big top-set load cut when readiness is only mildly down — this is both more defensible and lower-nocebo.
- **The red tier is a character change, not a number.** "Swap the hard session for easy/active recovery, or hold today's top set at last-session weight (no progression)" — not "lift 30% less."
- **Where it gets thin (flag honestly):** (1) precise per-percent load mapping from a continuous readiness scalar — there is no validated f(HRV-z) → exact-%-load function; Tuwa must use **discrete defensible tiers**, not a smooth curve sold as precise. (2) The cross-modal magnitude (how much yesterday's run *specifically* lowers today's squat) is **modeled, not validated** — `StrainRiskEngine`'s per-muscle elevation is a defensible heuristic, but the exact kg is an estimate. Frame as "your legs are carrying yesterday's run" + a conservative trim, never "your squat 1RM is down 6.2% today."

### 2.2 The recommended tier table (defensible, discrete, reuses existing zones)

Drive the verdict from the **already-shipped zones** (`ReadinessZone` × the planned-lift's strain) rather than inventing thresholds. The load factor is applied to the **planned top-set load**; the verdict label is derived in §3.

| Readiness zone | Lift-specific strain (from `StrainRiskEngine` per-muscle/region for THIS lift) | Top-set **load factor** | Volume guidance | Defensible basis |
|---|---|---|---|---|
| **High** (≥65) | low / moderate | **×1.00** (and allow a PR/“go heavy” nudge if the plan calls for it) | full planned volume | HRV-green = execute; autoregulation says push when fresh |
| **High** (≥65) | elevated / high | **×1.00 load, cut 1 back-off set** (`volumeModifier`≈.85) | trim volume, keep intensity | The "recovered but high load" case the two-channel design exists to surface (GA-1). Don't trim the *number*, trim *exposure* |
| **Moderate** (40–65) | low / moderate | **×0.95–1.00** (one notch only if mild) | ~75% volume, cap RPE ~8 | HRV-amber small trim; RIR autoreg "one increment" |
| **Moderate** (40–65) | elevated / high | **×0.93–0.95** + cut back-off sets | ~50–75% volume | Two corroborating down-signals → the lower end of the defensible trim |
| **Low** (<40) | any | **HOLD the number** (top set at last-session load, no progression) OR swap to easy | ~50% volume, RPE cap ~5–6, or active recovery | HRV-red = swap hard for easy; do NOT prescribe a big precise load cut |

Notes:
- **Numbers above are the *defensible envelope*, not magic constants.** The exact factors should be named constants (mirroring `StrengthLoadEngine.Constants`) and, per the locked algo-v1 discipline, **validated in shadow mode against the athlete's own outcomes before going louder**. Ship conservative.
- **Cold-start / low confidence** (`BaselineEngine.confidence` low, or `missingSignals`): **default to ×1.00 "go as planned, low confidence"** and say so. A low-confidence engine must *defer to the plan*, not trim it — this is the single most important nocebo/autonomy guardrail (see §4).
- **The per-lift selection** uses `StrengthLoadEngine.perMuscle[muscleOfPlannedLift].elevation` (or `perRegion[region]`), so squat reads legs, bench reads push. This is the cross-modal anchor made concrete.

### 2.3 Computing the adjusted top-set number

```
plannedTop = planned top set (load_kg, reps, optional targetRPE/RIR)
loadFactor = tier table (readinessZone, perLiftStrain)        // ∈ [0.93, 1.00] typically
e1RMref    = StrengthLoadEngine.e1RMReferences for this (muscle, exercise)  // existing
rawAdjusted = plannedTop.load_kg × loadFactor
adjustedTopSet = roundToNearest(rawAdjusted, step: equipmentIncrement)      // 1.25 / 2.5 kg
// guardrails:
//  - never round UP past the plan when trimming (floor toward plan-minus)
//  - if (plannedTop.load_kg − adjustedTopSet) < smallestIncrement → verdict = GO (no real change)
//  - express ALSO as RPE/RIR framing: "≈ your planned RPE at this load given today’s readiness"
```

- **Reuse `ProgressionEngine.roundToNearest` and its `volumeModifier`/`intensityCap` consumption** — do not re-implement plate math.
- **Express the suggestion two ways** for the autonomy-sensitive user: the *number* ("142.5 → 135 kg") **and** the *autoregulatory rationale* ("hold the same RPE; the bar will feel like your planned weight today"). The second framing matches how self-coached lifters already think and reads as *help*, not override.
- **If the plan is %-based or RPE-based** (common for this user), apply the factor to the %1RM or shift the RPE target by ~0.5–1.0 rather than a kg delta — meet the plan where it lives.

---

## 3. The go / modify / hold verdict logic

### 3.1 Mapping the existing recommendation → trichotomy

`AutoregulationEngine.recommendReadiness` already returns `intensityCap`, `volumeModifier`, `sessionType`. Collapse to three states (no new thresholds needed):

| Verdict | Trigger (from existing outputs) | What the user sees |
|---|---|---|
| **GO** | `loadFactor ≥ 0.99` AND `volumeModifier ≥ 0.95` AND no `.high` strain warning — i.e. the adjusted number ≈ the plan | "Go as planned." (Optionally: "Green light — fresh + load steady.") Plan shown unchanged |
| **MODIFY** | adjusted top set differs from plan by ≥ one real increment, OR `volumeModifier < 0.95` (cut back-off sets), OR `sessionType` downgraded but still trainable | "Suggested: top set 142.5 → **135 kg**, drop 1 back-off set." + one-liner. Plan + suggestion shown side by side, athlete confirms |
| **HOLD** | `sessionType ∈ {rest, activeRecovery}` OR readiness `.low` with corroboration OR consecutive-day override fired | "Today looks like a back-off / easy day." **Framed as the number** ("hold last week's top set, skip the PR attempt"), NOT a red "don't train." Always offer "train as planned anyway" |

- **The verdict is derived, not a 4th model.** It is a pure function of (adjustedTopSet vs plannedTopSet, volumeModifier, sessionType). This keeps it glass-box and trivially testable.
- **Three states map cleanly to the redefinition's "go/modify/hold"** and to the matrix cells already authored in `recommendReadiness` (HIGH/low = go zone; MODERATE/elevated = modify; LOW/* = hold).

### 3.2 The one-line why

Already solvable with `ReasoningEngine.explainDecision`:

```
reasons = ReasoningEngine.explainDecision(readiness, strainRisk, recommendation)
oneLiner = compose(top 1–2 reasons)
```

`explainDecision` already ranks by |contribution| across both channels and emits strings like *"Holding back — HRV 1.2σ below your baseline"* and *"Caution — per-muscle strength-load elevation."* The verdict's one-liner is a templated join of the top readiness factor + the top strain factor + the action:

> **"Readiness 12% below your baseline + legs still loaded from yesterday's run → trim today's top set ~5%."**

- Convert the z to a lay percentage for the copy (the dashboard already shows "% below baseline" via `ReasoningEngine.summarize`). **Show σ in a detail/expand, % in the headline** — % reads as concrete, σ reads as jargon.
- **Always name the cross-modal cause when it's the driver** ("yesterday's run") — that is the line that makes it Tuwa and not Garmin, and it's the line forum users said no incumbent gives them.
- **One line, one expandable.** The headline is the number + reason; tapping reveals the ranked factors + confidence. Don't dump four factors in the primary view.

### 3.3 Explainability + honesty guards (inherit from code)

- **Never injury-prediction language** — both `StrainRiskEngine` and `ReadinessFusionEngine` are grep-guarded for this; the verdict copy must stay inside that guard. Strain is "load-tolerance caution," not "injury risk."
- **Confidence is shown, not folded** — a low-confidence verdict says "low confidence, going with your plan," consistent with `ReadinessFusionEngine`/`StrainRiskEngine` reporting confidence separately.
- **ACWR is a context label only** (`PRSReadinessInputBuilder.contextLabel`) — never a verdict driver (GA-4). Keep it that way.

---

## 4. Verdict-UX patterns that defuse nocebo + autonomy

Both risks are *validated* (pressure-test §"two cracks" + nocebo landmine). The UX rules below are the product's load-bearing defense; the math is necessary but not sufficient.

### 4.1 Precedent — what worked / what failed

| Product | Pattern | Worked? | Lesson for Tuwa |
|---|---|---|---|
| **TrainerRoad Adaptive Training** | After each workout: ML adjusts "Progression Levels"; **suggests** plan changes the athlete **accepts or declines**; short post-workout survey ("how hard?") feeds the model. Difficulty labeled qualitatively (Achievable→Stretch→Breakthrough→Not Recommended) | **Worked at scale** — shipped to entire base; reported 38% lower workout-failure rate, +20% likelier to raise W/kg ([TrainerRoad blog](https://www.trainerroad.com/blog/introducing-adaptive-training-the-right-workout-every-time/); [endurance-sportswire, cited in pressure-test]) | **The model to copy.** Suggest-and-confirm + a feedback loop + *qualitative* difficulty labels (not a bare number) = endurance athletes accept automated modulation when framed as *performance*, with an explicit decline. Tuwa's verdict should be a *suggested change you accept/decline*, and should *learn from* the post-session outcome |
| **RP Hypertrophy app** | Uses **self-reported pump/soreness/RIR** to set next session's sets/load; "tell it how you feel, it dictates next workout" | Worked for the *committed* user; criticized as feeling prescriptive/black-box to others ([dr-muscle critique](https://dr-muscle.com/rp-hypertrophy-app-critique/)) | **Subjective feel is a first-class input, not just biometrics.** Tuwa must let the athlete *feed feel in* (the override), not only receive a verdict. But avoid RP's "it dictates" tone — that's the autonomy trap |
| **Whoop Strain Coach** | Pre-set strain target; buzzes when reached; user can move the slider / ignore | **Mixed → the validated failure mode.** Users override constantly ("I'll hit my session regardless of color"); churn on "a score I don't act on" ([Whoop Strain Coach](https://www.whoop.com/us/en/thelocker/strain-coach/); pressure-test forum corpus) | A bare score/target the user routinely overrides = no behavior change = churn. **Tuwa must beat free feel on *differing-verdict days* and prove it** (the disagreement log), or it's Whoop |
| **Oura/Garmin readiness** | Single readiness/Body Battery number, pre-session | **Nocebo source.** Users refuse to look pre-workout to avoid priming; one overrode a low score then bailed after 2 sets; "it's a guide, not a shackle" | **Do not lead with a bare low number pre-session.** Lead with the *action on the plan* + reason. The number is supporting evidence, not the headline |

### 4.2 The seven UX rules (requirements)

1. **Number + reason, never a red gate.** The primary surface is "*suggested top set: 135 kg (planned 142.5) — readiness 12% low + legs loaded from yesterday's run*," with a confirm. **No standalone "HOLD / don't train" as the hero affordance** — even the HOLD verdict is phrased as a *number* ("hold last week's weight, skip the PR"). Directly defuses nocebo (the betakay/MissRattlesnake cases).
2. **"Keep my plan" is a one-tap, first-class, non-penalized action.** It sits next to "Use suggestion" with equal weight. Declining is normal, expected, and logged without friction or guilt copy. This is the autonomy release valve and the TrainerRoad accept/decline pattern.
3. **Feel-override is an input, not just a dismissal.** A one-tap "I feel better/worse than this" nudges the suggestion (e.g. ±one tier) and is **recorded**. Self-coached athletes prize "I autoregulate myself" — let them, and *learn* from it (RP's lesson, minus the dictation).
4. **Show the disagreement log, and make it the proof surface.** Record (plan, suggestion, what they did, post-session outcome: hit cleanly / bailed / felt overcooked next day). Surface "on days we differed, here's how it went." This is (a) the only place the engine earns trust on the autonomy-purist, (b) the WTP-validation instrument, (c) the antidote to "it just told me what I already knew." Track **differing-verdict days specifically** (pressure-test green-light signal).
5. **Confidence-gated voice.** Low confidence / cold-start → the verdict *defers to the plan* and says "going with your plan, still learning your baseline." Never trim on a guess. (Inherits `BaselineEngine.confidence`.)
6. **Pull, not push, pre-session — and offer a post-warm-up confirm.** Don't shove a low verdict in the athlete's face the moment they open the app at the gym (nocebo). Let them open the verdict when they choose; offer an optional **"how did your warm-up feel?"** confirm (the APRE/velocity logic without a sensor) so a bad number can be *earned* by the body, not pre-imposed by the score.
7. **Frame as the back-room staff, not the coach.** Copy voice = "here's what the sports-science desk would flag," a *data point you decide on* — matching the self-coached athlete's existing "signal, I decide" posture (Cast Iron Strength voice in the pressure-test). Never "you should" / "do this." The athlete authors; Tuwa advises.

### 4.3 Anti-patterns to forbid (from the evidence)

- ❌ Bare pre-session readiness number as the hero (Oura/Garmin nocebo).
- ❌ Silent overwrite of the planned number (autonomy kill; violates the hard product constraint).
- ❌ Red "don't train today" gate (nocebo; forum users bail or ignore).
- ❌ False precision ("−6.2%", "your 1RM is 4.1% lower") — rounds to plates, reads as fake science.
- ❌ "Injury risk: X%" framing (liability; grep-guarded in code already).
- ❌ Guilt/penalty copy when the athlete keeps their plan.
- ❌ Agreement-only theater — if the verdict never differs from what they'd do, it can't earn money (Whoop's "confirmed what I already knew" churn). The log must surface the *differing* days.

---

## 5. Locked algo v1 / existing engines → verdict mapping (what maps, what's new)

| Verdict need | Maps directly onto | New logic required |
|---|---|---|
| Readiness state from HRV/sleep/RHR vs personal baseline | `BaselineEngine` (personal z + confidence) → `ReadinessFusionEngine` (Readiness + zone + factors) | **Activate** the dormant pipeline on the verdict surface (currently tests-only) |
| Cross-modal fatigue (run → squat, not bench) | `StrainRiskEngine` per-muscle/region elevation + endurance-load elevation; `StrengthLoadEngine.perMuscle`/`perRegion` | **Per-lift selection** of the right muscle/region for the planned exercise |
| Go/modify/hold decision | `AutoregulationEngine.recommendReadiness` 3×3 matrix (`intensityCap`/`volumeModifier`/`sessionType`) | **Trichotomy collapse** (pure derived function) |
| Adjusted top-set number | `ProgressionEngine` (target-weight math, `roundToNearest`, volumeModifier consumption, est-1RM) | **Apply factor to the PLANNED top set** (not history); two-way number+RPE framing |
| One-line why | `ReasoningEngine.explainDecision` (ranked, confidence-annotated, injury-safe) | **Templated `prefix(1–2)` join** + z→% lay conversion |
| Confidence gating | `BaselineEngine.confidence`, channel confidences (reported separately) | **Verdict voice rules** (§4.5) |
| Honesty / ACWR demotion / no-injury-language | grep guards + `acwrContextLabel` already in code | Keep verdict copy inside the guard |
| Suggest-and-confirm / feel-override / disagreement log | — (nothing today) | **All net-new UI + a lightweight log model + a signed override field** |
| Plan ingestion of today's top set | `PrescribedWorkout`/`WorkoutTemplate`/`TemplateSet` models exist | **A "planned top set" input** the verdict reads |

**Net assessment:** ~70% of the verdict is *activating and thinly translating already-built engines*; ~30% is genuinely new and it's mostly **UX + plan-target ingestion + the disagreement log**, not new sports-science math. The locked algo v1 (Altini baselines, ACWR-out, Readiness + Strain-Risk two-channel) maps almost 1:1 onto the verdict — the redefinition's "your plan, made safe and optimal" is exactly the two-channel matrix pointed at a planned top set.

---

## 6. Open questions / gaps for requirement definition

1. **Activation gate ownership.** The PRS pipeline is built but flag-OFF and tests-only. Does v2.0 flip it on *only* on the verdict surface (and keep the legacy recovery score elsewhere until shadow parity), or activate it app-wide? Recommend verdict-surface-only first, gated by the existing shadow harness.
2. **Plan-target source.** Where does "today's planned top set" come from for the wedge — a `PrescribedWorkout`, a `WorkoutTemplate` the athlete selected, or last-session + ProgressionEngine as a stand-in until full plan ingestion ships? The wedge can launch on **template/last-session** and grow into full-program ingestion (the v1.3 LLM-import seed).
3. **Exact tier constants.** §2.2's factors are the defensible *envelope*; the precise named constants should be set conservatively and shadow-validated. Need a decision on launch values (recommend the low end: −5% default, −10% ceiling).
4. **Cross-modal magnitude validation.** `StrainRiskEngine` per-muscle elevation is a defensible heuristic but not outcome-validated. Frame conservatively; use the disagreement log to validate before tightening.
5. **Velocity/warm-up confirm.** Is the optional post-warm-up "how did it feel?" confirm in scope for the wedge, or v2.1? It's the cheapest way to *earn* a HOLD without a sensor and strongly de-nocebos, but adds a logging step.
6. **WTP instrumentation.** The disagreement log doubles as the WTP-validation surface the pressure-test demands *before* mid/long horizons. Confirm it ships in the wedge.

---

## Sources

**Existing code (primary, verified by reading):** `WorkloadApp/Services/{ReadinessFusionEngine, StrainRiskEngine, BaselineEngine, StrengthLoadEngine, AutoregulationEngine, ProgressionEngine, ReasoningEngine, PRSReadinessInputBuilder, FatigueIndexEngine}.swift`; `WorkloadApp/Models/{Enums (ReadinessZone/StrainRiskZone/RecoveryZone/ACWRZone), SetRecord}.swift`.

**Sports-science evidence:**
- [Granero-Gallegos et al., HRV-guided vs predefined training meta-analysis (Applied Sciences 2020)](https://www.mdpi.com/2076-3417/10/23/8532) — small group margin, fewer worsen / more improve (individual-variance win).
- [Manresa-Rocamora/Düking et al., HRV-guided training methodological systematic review w/ meta-analysis (PMC8507742, 2021)](https://pmc.ncbi.nlm.nih.gov/articles/PMC8507742/) — ~10–13% trend at ventilatory thresholds.
- [Marco Altini — HRV-guided training, when to hold back vs push](https://marcoaltini.substack.com/p/hrv-guided-training-when-to-hold) and [Medium HRV-guided training](https://medium.com/@altini_marco/heart-rate-variability-hrv-guided-training-to-improve-performance-24b0ec24e6f8) — individual baseline + traffic-light bands.
- [Kubios HRV-guided training (3-month personalized baseline)](https://www.kubios.com/blog/hrv-guided-training/).
- [Load/volume autoregulation meta-analysis (PMC8762534)](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC8762534/) — autoregulation ≥ fixed loading; velocity-loss ≤25% favors strength.
- [Auto-regulation vs fixed-loading max-strength meta (PMC7994759)](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7994759/) and [APRE explainer, Training & Conditioning](https://training-conditioning.com/article/understanding-apre-part-2/) — APRE set-4 load-adjustment table.
- [SetForSet — RPE/RIR/bar-speed autoregulation](https://www.setforset.com/blogs/news/autoregulation-tools-for-strength-training) and [PowerliftingToWin — RTS / daily 1RM](https://www.powerliftingtowin.com/a-review-of-mike-tuchscherers-reactive-training-systems-rts/) — "reduce one increment" on low daily readiness; daily-1RM estimation from RPE.
- [Hooper-index / wellness vs sRPE (PMC6714361)](https://pmc.ncbi.nlm.nih.gov/articles/PMC6714361/) — subjective wellness as cheap daily readiness predictor.

**UX / behavioral precedent:**
- [TrainerRoad — Introducing Adaptive Training](https://www.trainerroad.com/blog/introducing-adaptive-training-the-right-workout-every-time/) and [Adaptive Training Overview](https://support.trainerroad.com/hc/en-us/articles/4404060687387-Adaptive-Training-Overview) — suggest/accept-decline + post-workout survey + qualitative difficulty labels.
- [RP Hypertrophy app critique (dr-muscle)](https://dr-muscle.com/rp-hypertrophy-app-critique/) — subjective feel (pump/soreness/RIR) drives next session; "it dictates" tone risk.
- [Whoop Strain Coach](https://www.whoop.com/us/en/thelocker/strain-coach/) — target + override; the "score I don't act on" churn mode.
- Nocebo / readiness-priming: [Placebo and nocebo in sport — Physiological Society](https://www.physoc.org/magazine-articles/placebo-and-nocebo-effects-in-sport/); [Nocebo on perceived soreness & performance (PMC7739351)](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7739351/).
- Forum-mined autonomy/nocebo/WTP evidence: `.planning/research/plan-aware-thesis-pressure-test.md` (Oura "guide not shackle" / betakay refuses pre-workout score / MissRattlesnake felt-fine-bailed; Whoop churn corpus; Cast Iron Strength "descriptive not prescriptive").

**Internal:** `.planning/notes/core-redefinition-plan-aware-engine.md`; `.planning/research/{algorithm-moat-design.md, competitive-algorithm-analysis.md}` (locked algo v1).
