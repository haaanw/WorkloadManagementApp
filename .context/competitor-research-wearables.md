# Competitor Research: Consumer Wearable Recovery / Readiness Algorithms

**Purpose:** Document how the major consumer wearable recovery/readiness algorithms actually work (as far as publicly known), to position Tuwa as differentiated and better for our target user: **amateur but serious trainers and part-time athletes who train hard but have NO access to professional coaching, physiotherapy, or sports-science support.** This group needs pro-grade guidance in lieu of a human expert — they need to be told not just a number, but *why*, *what it means for injury/overtraining*, and *what to do today*.

**Methodology note:** These algorithms are partly proprietary. Below, every factual claim is sourced. Where the exact math is undisclosed, it is explicitly marked **[KNOWN]** (vendor-documented or strongly corroborated) vs **[INFERRED]** (third-party teardown, reasonable deduction, or not publicly confirmed).

Research date: 2026-05-30.

---

## 1. WHOOP — Recovery Score & Strain

### Inputs & scoring method
- Recovery is computed from **4 physiological metrics: HRV, Resting Heart Rate (RHR), Respiratory Rate, and Sleep performance.** **[KNOWN]** ([WHOOP Recovery 101](https://www.whoop.com/us/en/thelocker/how-does-whoop-recovery-work-101/), [Whoopal teardown](https://whoopal.com/whoop-recovery))
  - HRV is described as the **single most influential factor** in the score. **[KNOWN]** ([Whoopal](https://whoopal.com/whoop-recovery))
  - RHR is measured during **deepest sleep**; lower-than-baseline = better recovery. **[KNOWN]**
  - Sleep performance = sleep obtained vs. sleep WHOOP calculated you *needed*. **[KNOWN]**
  - Respiratory rate = breaths/min during sleep; deviations flag illness/stress. **[KNOWN]**
- Output is a **0–100% score** mapped to zones: **Green 67–99%** (primed), **Yellow 34–66%** (maintain), **Red 1–33%** (rest). Average member ≈ 58%. **[KNOWN]** ([WHOOP Recovery 101](https://www.whoop.com/us/en/thelocker/how-does-whoop-recovery-work-101/))
- The exact **weighting / formula is NOT disclosed.** WHOOP only states the "proprietary algorithm is more predictive of next-day capacity" than any single marker. **[INFERRED — undisclosed]** ([WHOOP HRV training guide](https://www.whoop.com/us/en/thelocker/heart-rate-variability-training/))

### Baseline approach
- Each metric is compared against the user's **personal baseline, not population averages.** "High" and "low" are relative to you. **[KNOWN]** ([Whoopal](https://whoopal.com/whoop-recovery))
- Exact baseline **window length is not published** by WHOOP; it adapts continuously as more nights accrue. **[INFERRED — undisclosed window]**

### Explainability — does it tell you WHY?
- **Weak.** WHOOP shows the contributing metric values but **does not explicitly tell you which metric drove a given day's score.** It offers a **Journal** feature so users can self-correlate behaviors with recovery over time — i.e., the burden of "why" is shifted to the user. **[KNOWN]** ([WHOOP Recovery 101](https://www.whoop.com/us/en/thelocker/how-does-whoop-recovery-work-101/))

### Injury-risk / overtraining handling
- No explicit injury-risk model. Overtraining is only *implied* via elevated RHR / depressed HRV / raised respiratory rate vs. baseline (Health Monitor flags out-of-baseline vitals). **[KNOWN]** ([WHOOP Health Monitor](https://www.whoop.com/us/en/thelocker/health-monitor-feature/)) There is no acute:chronic load model for injury and no musculoskeletal/strength load.

### Strain
- Strain is a **0–21 cardiovascular-load scale** based on heart-rate exertion over the day; WHOOP gives a daily **Strain Target** scaled to current Recovery. The **exact math is undisclosed.** **[KNOWN concept / INFERRED math]** ([WHOOP Recovery 101](https://www.whoop.com/us/en/thelocker/how-does-whoop-recovery-work-101/))

### Gaps for our target user
- **Requires WHOOP hardware + mandatory subscription** (~$199–$239/yr; strap is "free" only with membership; 12-month commitment). **[KNOWN]** ([Gene Food review](https://www.mygenefood.com/blog/whoop-strap-4-0-review/))
- **Black box** — tells you the number, not *which* factor drove it or *why*. **[KNOWN]**
- **Strain is purely cardiovascular** — no strength-training / mechanical load model, which is exactly what a serious lifter or hybrid athlete needs. **[INFERRED from documented Strain definition]**
- **No autoregulation prescription** beyond a generic Strain Target ("how hard," not "do exercise X / cut volume Y"). Reviewers note the data is "passive" and "overwhelming for casual or amateur exercisers" without context. **[KNOWN]** ([Heal Nourish Grow](https://healnourishgrow.com/whoop-vs-oura/))
- **No injury-risk lens.**

---

## 2. Oura — Readiness Score

### Inputs & scoring method
- Readiness is built from up to **nine contributors**: Resting Heart Rate, HRV Balance, Body Temperature, Recovery Index, Sleep, Sleep Balance, Sleep Regularity, Previous Day Activity, Activity Balance. **[KNOWN]** ([Oura Readiness Contributors](https://support.ouraring.com/hc/en-us/articles/360057791533-Readiness-Contributors))
- HRV is measured as **RMSSD** in 5-minute windows across the night, averaged over the sleep period. **[KNOWN]** ([Oura Readiness blog](https://ouraring.com/blog/readiness-score/))
- **Body temperature deviation is heavily weighted** and is often the first illness signal — the score drops hard when skin temp is off baseline. **[KNOWN]** ([Oura Trends](https://support.ouraring.com/hc/en-us/articles/360055983614-Using-Trends))
- Output 0–100: **85–100 Optimal, 70–84 Good, 60–69 Fair, 0–59 Pay Attention.** The exact combining formula is **not published.** **[KNOWN scale / INFERRED math]**

### Baseline approach (well-documented, multi-window)
- **Resting HR, Body Temperature:** compared to **long-term ~2-month average.** **[KNOWN]**
- **HRV Balance:** **14-day average vs. 3-month baseline**, recent days weighted more. **[KNOWN]**
- **Activity Balance / Sleep Balance:** **14-day (recent-weighted) vs. ~2-month** long-term. **[KNOWN]**
- This is a **purely individual baseline**, no population norm. **[KNOWN]** ([Oura Readiness Contributors](https://support.ouraring.com/hc/en-us/articles/360057791533-Readiness-Contributors))

### Explainability
- **Moderate.** Oura shows each contributor as "Optimal / Pay attention" so the user can see *which* contributor pulled the score down — better than WHOOP. But it does **not** translate this into a training prescription; framing is "overall capacity for the day," gentler/wellness-oriented rather than training-directive. **[KNOWN]** ([Ashley Mateo / corroborated comparison](https://askvora.com/blog/whoop-vs-oura-ring-2026))

### Injury-risk / overtraining handling
- Overtraining is *inferred* via **Activity Balance** ("training too hard or not enough") and HRV/temperature deviations. There is **no musculoskeletal load model and no injury-risk score.** **[KNOWN]**

### Gaps for our target user
- **Requires Oura ring hardware + subscription** (~$5.99/mo) for full scores. **[KNOWN]** ([reviews](https://askvora.com/blog/whoop-vs-oura-ring-2026))
- **Wellness-framed, not training-directive** — explicitly NOT built to tell a hard-training athlete "how to train today." **[KNOWN]**
- **No strength / mechanical training-load tracking** — Activity Balance is steps/calorie/MET-based, not set-and-rep resistance load. **[INFERRED from contributor definitions]**
- **No autoregulation prescription** and **no injury lens.**

---

## 3. Garmin — Body Battery, Training Readiness, HRV Status, Training Load (Firstbeat)

Garmin's recovery/readiness suite is powered by **Firstbeat Analytics** (acquired by Garmin). It is the most feature-rich of the consumer set.

### Body Battery
- Inputs: **RMSSD HRV, daytime stress (from HRV), and sleep quality/duration.** Scale **5–100**; charges during rest/sleep, drains with exercise/stress/illness. **[KNOWN]** ([the5krunner Body Battery](https://the5krunner.com/garmin-features/sleep/body-battery/), [Garmin Wiki](https://wiki.garminrumors.com/Body_Battery))
- Sleep is the main charging mechanism (a good night can add 40–60 pts); VO2max modulates drain rate. **[KNOWN]**
- Documented weaknesses: "measures nervous-system state, not how you actually feel," **no strength-training load modeling, gives no prescriptive guidance, poor in first 10 days / weak HR signal.** **[KNOWN]** ([the5krunner](https://the5krunner.com/garmin-features/sleep/body-battery/))

### Training Readiness
- Combines **6 inputs with explicit weighting**: **Sleep (high), Recovery Time (high), HRV Status (medium), Sleep History 3-day (medium), Stress History (medium), Training Load balance (low).** Prioritizes acute factors over long-term trends. **[KNOWN]** ([Garmin Wiki Training Readiness](https://wiki.garminrumors.com/Training_Readiness))
- 0–100, five bands (Prime / Primed / Recovering / Strained / Very Strained). **[KNOWN]**
- **Best-in-class explainability of the consumer set:** the watch shows **each contributing factor color-coded green/orange/red**, so the user sees *which specific factor* limits readiness. **[KNOWN]**

### HRV Status
- Compares current overnight HRV to a **personal baseline established over weeks**, with trend (improving/stable/declining) and classification **balanced / unbalanced / low.** **[KNOWN — though Garmin documents the baseline as a rolling ~3-week window; the wiki source did not state the exact window number]** ([Garmin Wiki](https://wiki.garminrumors.com/Training_Readiness))

### Training Load / EPOC / Training Effect
- Built on **EPOC (Excess Post-exercise Oxygen Consumption)**; Training Load = sum of session EPOC. Placed in context of VO2max + activity history → **Training Effect** (aerobic/anaerobic) and **Acute:Chronic load** ratio with Load Focus. **[KNOWN]** ([the5krunner Firstbeat insights](https://the5krunner.com/2019/09/09/garmin-fenix-6-firstbeat-insights/), [shoulditrain load](https://www.shoulditrain.com/blog/garmin-training-load-explained))

### Gaps for our target user
- **Requires a Garmin watch** (premium devices for full suite); strong cardio bias.
- **Training Load = cardiovascular EPOC only.** Lifting/hybrid resistance work is essentially invisible — **no muscle/mechanical load model.** **[KNOWN]** ([the5krunner](https://the5krunner.com/garmin-features/sleep/body-battery/))
- **No specific injury-risk prediction.** Acute:Chronic ratio exists but research (below) shows its predictive power for injury is weak and it is not surfaced as injury guidance.
- **Prescription is generic:** "good day for hard training" vs "recover" — it does NOT prescribe *what* session, load, or exercise. **[KNOWN]**
- **Requires several weeks to baseline.** **[KNOWN]**

---

## 4. Apple — Vitals & Training Load (watchOS 11)

### Inputs & scoring method
- **Vitals app** tracks overnight metrics (HR, RHR, HRV, respiratory rate, wrist temp, blood oxygen) and flags when ≥2 are **outside the personal expected range.** It is a **deviation-flagging tool, not a single recovery/readiness score.** Apple does NOT produce a "recovery score." **[KNOWN]** ([XDA Vitals guide](https://www.xda-developers.com/guide-to-the-vitals-app-in-watchos-11/))
- **Training Load** = **Effort Rating (1–10) × Duration.** Effort rating is auto-estimated from age, height, weight, GPS, HR, elevation — and the **user can override it.** Combined into **7-day vs 28-day load** with a relative arrow (up/steady/down). **[KNOWN]** ([DCRainmaker](https://www.dcrainmaker.com/2024/07/apples-training-load-vitals-watchos11.html), [Tom's Guide](https://www.tomsguide.com/wellness/smartwatches/im-a-marathoner-and-have-been-testing-apple-watchs-training-load-feature-heres-the-pros-and-cons))

### Baseline approach
- Vitals: personal expected range built after ~7 nights. Training Load: needs **~10 days to show, ~28 days to set personal baseline.** **[KNOWN]** ([DCRainmaker](https://www.dcrainmaker.com/2024/07/apples-training-load-vitals-watchos11.html))

### Explainability
- Vitals shows *which* metric is out of range (good transparency on illness signals) but offers **no synthesized readiness number and no "what to do."** **[KNOWN]**

### Injury / overtraining / prescription
- **None.** No recovery score, no autoregulation, no injury lens. Training Load only shows acute-vs-chronic trend; it does not tell you to back off or push.

### Gaps for our target user
- **No unified recovery/readiness score at all** — user must interpret raw vitals.
- **No prescription, no injury lens, no strength-specific load model** (RPE×duration is generic and self-rated).
- Strength of note: **Apple does let the user adjust effort** — a useful precedent that subjective input matters. **[KNOWN]**

---

## 5. Fitbit / Google — Daily Readiness Score

### Inputs & scoring method
- Current algorithm combines **HRV (measured during deep sleep), recent Sleep (last ~week), and Resting Heart Rate.** Google **removed the "activity" component** and replaced it with RHR — so the score now reflects "how your body responds to your overall routine rather than what you did yesterday." **[KNOWN]** ([Google Fitbit blog](https://blog.google/products-and-platforms/devices/fitbit/premium-daily-readiness/), [Fitbit Help](https://support.google.com/fitbit/answer/14236710))
- Score compared against **personal baseline.** Higher = ready for harder training. **[KNOWN]**

### Baseline approach
- Personal baseline (window not precisely published; sleep component uses ~past week). **[KNOWN scale / INFERRED window]**

### Explainability
- Shows the three contributing factors and a brief suggested activity tier (e.g., "go for a workout" vs "take it easy"), but does not prescribe specifics. **[KNOWN]**

### Injury / overtraining / prescription
- **No injury lens, no strength load, no real autoregulation.** Generic "harder vs gentler" suggestion only.

### Gaps for our target user
- **Locked behind Fitbit Premium subscription + Fitbit hardware.** **[KNOWN]**
- Now ignores yesterday's activity entirely, so a hard session may not lower the score — **misaligned with a serious trainer's need to link load → recovery.** **[KNOWN]**
- **No strength model, no injury lens, no real prescription.**

---

## 6. Polar — Nightly Recharge, Recovery Pro, Training Load Pro

Polar is the closest competitor on *training-load* sophistication, especially **muscle load**.

### Nightly Recharge (auto, wrist)
- Two parts: **ANS charge** + **Sleep charge.** ANS charge from **HR, HRV (RMSSD), and breathing rate during the first ~4 hours of sleep**, compared to your **usual level over the past 28 days**; scale **−10 to +10** (≈0 = normal). **[KNOWN]** ([Polar Nightly Recharge](https://support.polar.com/en/nightly-recharge-recovery-measurement), [Polar Recovery Pro vs Nightly Recharge](https://support.polar.com/en/recovery-pro-or-nightly-recharge-which-is-the-right-one-for-me))

### Recovery Pro (requires H10 chest strap)
- Uses the **Orthostatic Test** (resting RMSSD vs standing RMSSD) plus subjective questions about muscle soreness, fatigue, sleep, combined with training history. **Gives explicit feedback on whether you've trained too much / too little / just right** — i.e., it does offer a recovery-directed training recommendation. **[KNOWN]** ([Polar Recovery Pro](https://support.polar.com/en/recovery-pro-or-nightly-recharge-which-is-the-right-one-for-me))

### Training Load Pro (three load types — notable)
- **Cardio Load** = TRIMP from HR + duration. **[KNOWN]**
- **Muscle Load** = mechanical energy (kJ) = avg power × duration — but **only available for running & cycling WITH a power meter.** **[KNOWN]** ([Polar Training Load Pro](https://www.polar.com/en/smart-coaching/training-load-pro))
- **Perceived Load** = session-RPE (1–10) × duration. **[KNOWN]**
- Plus **Cardio Load Status** (Strain vs Tolerance) with statuses incl. "Recovering / Productive / Overreaching." **[KNOWN]**

### Baseline
- ANS charge / Recovery Pro use a **28-day personal baseline.** Cardio Load Status compares acute "Strain" to chronic "Tolerance." **[KNOWN]**

### Gaps for our target user
- **Requires Polar hardware; Recovery Pro additionally needs a chest strap (H10) + manual orthostatic test** — high friction for an amateur. **[KNOWN]**
- **Muscle Load only works with running/cycling power meters — it does NOT cover resistance/strength training.** So the one competitor with a "muscle load" still can't model a lifter's barbell work. **[KNOWN]**
- **No injury-risk score.** Prescription is high-level ("train less/more"), not exercise-specific.

---

## Cross-cutting research on the injury/prescription gap

Independent sports-science research confirms the collective blind spot:
- Wearable **acute:chronic workload ratios have weak/minimal predictive power for injury**, and wearables "lack context and don't account for most injury-prevention factors." **[KNOWN]** ([Medium teardown](https://medium.com/@CuriousCatalyst/training-load-strain-understanding-your-wearables-injury-prevention-system-and-its-7c9aa456e53a), [ultramarathon GAM study](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12327882/))
- **Strength training, eccentrics, plyometrics reduce running injury** — yet **most wearables don't track strength work at all.** **[KNOWN]** ([Springer load comparison](https://link.springer.com/article/10.1186/s40798-025-00969-9))
- Athletes often **distrust black-box numbers** and prioritize feel — implying value in *explained, autoregulation-style* guidance over opaque prescription. **[KNOWN]**
- Real-time, **explained feedback reduced injury rates** in an RCT of recreational runners — i.e., explainability + action has measurable value. **[KNOWN]** ([RCT, PMC10905988](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10905988/))

---

## Summary comparison table

| Product | Recovery method (inputs) | Baseline approach | Explainable (tells you WHY)? | Injury lens? | Prescribes action ("what to do today")? | Biggest gap for amateur-no-coach user |
|---|---|---|---|---|---|---|
| **WHOOP** | 0–100% from HRV (dominant), RHR, respiratory rate, sleep; weights undisclosed | Personal baseline, rolling (window undisclosed) | Weak — shows metrics, not which drove score; offloads "why" to manual Journal | No | Generic Strain Target (how hard, not what) | Black-box, cardio-only Strain, no strength load, no injury lens, mandatory sub + hardware |
| **Oura** | 0–100 from 9 contributors; HRV (RMSSD), RHR, body temp (heavy), recovery index, sleep, activity balance | Individual: RHR/temp ~2-mo, HRV-balance 14-day vs 3-mo | Moderate — per-contributor optimal/pay-attention flags | No (activity balance only) | No — wellness "capacity," not training directive | Wellness-framed not training-directive, no strength load, no prescription, no injury lens, sub + ring |
| **Garmin (Firstbeat)** | Body Battery 5–100 (HRV/stress/sleep); Training Readiness 0–100 (6 weighted factors) | Personal, multi-week (HRV ~3-wk rolling); needs weeks to set | **Best** — Training Readiness color-codes each contributing factor | Weak (ACWR exists, low predictive value, not framed as injury) | Generic ("good day for hard training" / "recover"), not exercise-specific | Cardio-EPOC load only, no strength model, no real injury score, no specific prescription, watch + weeks to baseline |
| **Apple (watchOS)** | No single score; Vitals flags out-of-range overnight metrics; Training Load = Effort×Duration | Personal expected range (~7 nights); load baseline 28-day | Vitals shows which metric is off; but no synthesized readiness | No | No | No unified readiness score, no prescription, no injury lens, no strength-specific load |
| **Fitbit / Google** | Daily Readiness from HRV (deep sleep), recent sleep, RHR (activity removed) | Personal baseline (window mostly undisclosed) | Light — 3 factors + a coarse activity tier | No | Coarse "harder vs gentler" only | Ignores yesterday's activity, no strength load, no injury lens, weak prescription, Premium sub + hardware |
| **Polar** | Nightly Recharge −10..+10 (ANS+sleep charge, RMSSD); Recovery Pro (orthostatic test) | 28-day personal baseline | Moderate — splits ANS vs sleep; Recovery Pro gives too-much/too-little verdict | No | Yes-ish (Recovery Pro: train more/less; Cardio Load Status) | Muscle Load needs power meter (no resistance/strength), Recovery Pro needs chest strap + manual test, no injury score, hardware lock-in |

---

## 6-sentence summary: biggest collective gaps competitors leave open for our target group

1. **Every competitor is hardware- and subscription-locked** (WHOOP strap, Oura ring, Garmin/Polar/Fitbit watches), so an amateur who already owns an Apple Watch + iPhone must buy and subscribe to a *second* ecosystem just to get a recovery number. 2. **None model strength / resistance training load** — every "load" metric is cardiovascular (EPOC, TRIMP, HR-based), and the lone "muscle load" (Polar) requires a running/cycling power meter, so a serious lifter's or hybrid athlete's barbell work is essentially invisible to all of them. 3. **None provide a real injury-risk lens** — at best they expose a weakly-predictive acute:chronic ratio that research shows has minimal injury-predictive power and is never framed as actionable injury guidance. 4. **Explainability ranges from poor (WHOOP black box) to partial (Garmin's color-coded factors), but none translate "why your score is low" into a concrete, autoregulated training decision** — they tell you *how hard* at most, never *what session, what load, what to cut or swap today*. 5. **Recovery and training-load are siloed** — devices show a recovery score and a separate load chart but don't fuse the two longitudinally to teach the athlete how *their* body responds to *their* training over time, which is precisely the coaching insight this group lacks. 6. **The whole category is built for either passive wellness (Oura/Fitbit) or data-saturated pros (WHOOP/Garmin), leaving a clear opening for Tuwa: an explainable, prescription-driven, strength-aware, injury-conscious readiness engine that runs on hardware the user already owns and acts as the coach/physio/sports-scientist this group cannot otherwise access.**
