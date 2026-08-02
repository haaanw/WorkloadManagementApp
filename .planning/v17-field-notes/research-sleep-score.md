# Sleep score v2 — research + proposal

Status: draft for adversarial review. Author: research agent, 2026-07-31.
Scope: replace the duration-only sleep component of `RecoveryScoreEngine` with a
stage-aware, personalized sleep score.

**Evidence grading used throughout**
`A` = meta-analysis / consensus statement / replicated lab work ·
`B` = single peer-reviewed study or systematic review read at abstract level ·
`C` = peer-reviewed but small-n / athlete-specific with known bias ·
`D` = vendor documentation or blog (marketing incentive, no method disclosed) ·
`E` = third-party blog / unverified.
Where I could not read the primary source, I say so. No citation in this document
was written from memory without a URL I actually retrieved this session.

---

## 1. Sleep science for athletes — what actually predicts recovery

### 1.1 Total sleep time is the best-evidenced lever (grade A/B)

- **Sleep extension improves basketball performance.** Mah et al., *Sleep* 34(7):943–950,
  2011. n=11 Stanford men's varsity basketball players, 2–4 wk baseline then 5–7 wk of
  ≥10 h in bed. 282-ft sprint improved 16.2 s → 15.5 s; shooting accuracy improved.
  https://pubmed.ncbi.nlm.nih.gov/21731144/ — **grade C** for effect size (n=11, no
  control group, unblinded, order effects), **grade A** for relevance: this is literally
  the beachhead population. Note: the widely-quoted "+9% free throws / +9.2% three-point"
  figures are consistent with the press coverage
  (https://med.stanford.edu/news/all-news/2011/07/snooze-you-win-its-true-for-achieving-hoop-dreams-says-study.html)
  but I verified only "higher shooting percentages" and the sprint numbers from the
  abstract-level sources. Do not print the 9% figure in-app without reading the paper.
- **Short sleep predicts injury in adolescent athletes.** Milewski et al., *J Pediatr
  Orthop* 34(2), 2014: athletes averaging <8 h/night were 1.7× more likely to have been
  injured (95% CI 1.0–3.0, p=0.04), n=112 survey respondents.
  https://pubmed.ncbi.nlm.nih.gov/25028798/ — **grade C**: self-reported sleep,
  retrospective injury, CI lower bound touches 1.0.
- A meta-analysis reported OR 1.58 (95% CI 1.05–2.37) for musculoskeletal injury in
  adolescents habitually sleeping <8 h, as summarized in *Sleep Optimization in the Young
  Athlete* (https://www.sciencedirect.com/science/article/pii/S2768276524001743) and a
  narrative review (https://pmc.ncbi.nlm.nih.gov/articles/PMC10745648/). **grade B** —
  I read the summarizing reviews, not the pooled analysis. Direction is consistent with
  Milewski; magnitude is modest.
- **Dose–response of restriction is cumulative.** Van Dongen, Maislin, Mullington, Dinges,
  *Sleep* 26(2):117–126, 2003: 14 nights at 4/6/8 h TIB; 4–6 h produced cumulative
  vigilance deficits comparable to 1–2 nights of total deprivation, and subjects
  under-rated their own impairment.
  https://academic.oup.com/sleep/article-abstract/26/2/117/2709164 — **grade A**. This is
  the strongest justification for a *debt* term rather than scoring each night in
  isolation.
- **Sleep extension review.** "Sleep extension in athletes: what we know so far — a
  systematic review", *Sleep Medicine* 2021
  (https://www.sciencedirect.com/science/article/abs/pii/S1389945720305281): of 15 sport
  measures, 6 showed large effects, rest trivial-to-medium; recommends extending by
  46–113 min in athletes habitually sleeping ~7 h. Authors caution on evidence quality.
  **grade B** (abstract-level read).

### 1.2 Stages: physiologically real, but weaker and noisier as a *score input*

- **SWS ↔ growth hormone.** ~70% of nocturnal GH pulses in men coincide with slow-wave
  sleep, and pulse amplitude correlates with concurrent SWS amount (Van Cauter and
  colleagues; https://pubmed.ncbi.nlm.nih.gov/8627466/,
  https://pubmed.ncbi.nlm.nih.gov/10984255/). **grade A** for the physiology. But: no
  source I found demonstrates that *night-to-night* SWS variation within a person predicts
  next-day athletic performance. The mechanism is solid; the daily-scoring inference is not.
- **Motor learning is sleep-dependent, but the responsible stage is contested.** Walker
  et al. (*Learn Mem* 10:275, https://learnmem.cshlp.org/content/10/4/275.full;
  *Neuron* 2002, https://www.sciencedirect.com/science/article/pii/S0896627302007468)
  implicate stage-2 NREM/spindles for motor *sequence* learning; other work correlates
  overnight gains with early-night SWS and late-night REM. **Honest read: "REM = basketball
  skill consolidation" is a plausible story, not an established fact.** Any in-app copy
  must not assert it. This directly caps how much weight REM can honestly carry.
- **Athlete-specific stage norms are thin.** I found no meta-analysis giving target deep%
  or REM% for athletes. Oura's published targets (deep 15–20%, REM ~20–25%) are vendor
  norms for general adults, not athlete evidence.

### 1.3 Continuity, timing, regularity

- **Athletes have worse continuity than non-athletes.** Leeder et al. 2012 (actigraphy,
  47 Olympic athletes vs 20 controls): sleep efficiency 80.6 ± 6.4% vs 88.7 ± 3.6%,
  higher fragmentation. https://pubmed.ncbi.nlm.nih.gov/22329779/ — **grade B**. A
  systematic review of athlete sleep ("Deconstructing athletes' sleep",
  https://pmc.ncbi.nlm.nih.gov/articles/PMC8343120/) reports pooled SE ≈ 86.3 ± 6.8% and
  WASO ≈ 52.7 ± 32.0 min. **Implication: scoring 85% efficiency as "bad" (the general-adult
  threshold) would punish a normal athlete.** Efficiency anchors must be athlete-shifted.
- **Regularity predicts hard outcomes.** Windred et al., *Sleep* 47(1):zsad253, 2024,
  UK Biobank accelerometry: Sleep Regularity Index was a *stronger* predictor of all-cause
  mortality than duration (20–48% lower risk across regularity quantiles).
  https://academic.oup.com/sleep/article/47/1/zsad253/7280269 — **grade A for the finding,
  but it is a mortality endpoint in 40–69-year-olds, not next-day athletic readiness.**
  Using it to justify a regularity term in a daily athlete score is an extrapolation. Say so.

### 1.4 Individual variability — the core justification for personalization

- **Response to sleep loss is trait-like.** Van Dongen et al. 2004, *Sleep*: inter-individual
  differences in neurobehavioral impairment are stable across repeated exposures and not
  explained by baseline function. https://pubmed.ncbi.nlm.nih.gov/15164894/ — **grade A**.
- **Sleep *capacity* differs and can be measured by extension.** Klerman & Dijk (extended
  sleep-opportunity protocols) found asymptotic sleep time ≈ 8.9 h in young adults and
  ≈ 7.4 h in older adults. https://www.cell.com/fulltext/S0960-9822(08)00804-X — **grade B**.
  Relevant caution: under unlimited opportunity, healthy young adults sleep close to 9 h,
  which means "how much they sleep when free" over-estimates need if taken as a raw max.
- **Consensus says individualize.** Walsh et al., *BJSM* 55(7):356–368, 2021 expert
  consensus: a one-size-fits-all 7–9 h recommendation "is unlikely ideal", individualized
  targets recommended; adolescents 8–10 h, adults 7–9 h.
  https://www.sportgeneeskunde.com/wp-content/uploads/Br-J-Sports-Med-2021-Walsh-consensus-statement-sleep-and-the-athlete.pdf
  — **grade A (consensus, not trial)**. This is the citation to lean on for personalization.

---

## 2. Competitor teardown

**Whoop** — Sleep Performance = total sleep time ÷ Sleep Need, as a percentage. Sleep Need
is reported by Whoop as `Baseline + f(strain) + f(debt) − naps`, with baseline learned per
user, a hard day adding "30–60 min", debt scaled and capped.
Sources: https://www.whoop.com/us/en/thelocker/how-much-sleep-do-i-need/ and
https://www.whoop.com/us/en/thelocker/everything-to-know-about-sleep/ — **grade D, and
weaker than that: whoop.com returned HTTP 403 to direct fetch, so these are search-surfaced
excerpts, not pages I read end-to-end.** The functional form also appears in Whoop patent
filings surfaced by search. Treat the *shape* as real (it is corroborated across several
independent write-ups) and every *number* as unverified.

**Oura** — 7 contributors, weights proprietary and unpublished. Verified thresholds from
the support page I did fetch (https://support.ouraring.com/hc/en-us/articles/360057792293-Sleep-Contributors):
total sleep 7–9 h; efficiency ≥85% optimal; REM ~1.5 h optimal; deep 15–20% of TST;
latency 15–20 min ideal (<5 min flagged as over-tired); timing = sleep midpoint between
00:00 and 03:00; restfulness from movement/wake-ups. Bands: 85–100 optimal, 70–84 good,
60–69 fair, <60 pay attention. **grade D but with concrete, quotable anchors** — useful as
a sanity check on our anchors, not as evidence.

**Garmin (Firstbeat)** — duration vs age-adjusted recommendation, stage balance
(deep/light/REM), awake time and restlessness, plus an overnight HRV-derived stress score.
https://www.garmin.com/en-US/blog/fitness/how-garmin-watches-track-your-sleep-calculate-sleep-score/
— **grade D**. Notable: Garmin folds autonomic recovery *into* the sleep score. Tuwa should
not — HRV is already a separate 30% component; folding it into sleep would double-count.

**Athlytic / Bevel** — HealthKit-only iOS recovery apps producing Recovery/Sleep/Strain
scores from Apple Watch (Bevel also ingests Oura/Garmin/Fitbit data via Health).
Neither publishes an algorithm. https://apps.apple.com/us/app/bevel-ai-health-coach/id6456176249,
https://athlytic.github.io/athlyticapp/troubleshooting/ — **grade E**.

**Where Tuwa can be defensibly different.** Every competitor scores sleep against either a
population norm or a proprietary "need" that the user cannot inspect, and none of them know
the athlete's *plan*. Three openings: (1) the target is explainable and inspectable — the
athlete can see the number, its history, and why it moved; (2) need responds to *planned*
load, not just yesterday's strain — Tuwa knows tomorrow is a match; (3) stage components
are scored against **the athlete's own distribution from the same device**, which cancels
the device-specific bias that makes cross-user stage norms meaningless (see §3).

---

## 3. What HealthKit actually gives us

- `HKCategoryTypeIdentifier.sleepAnalysis` values: `inBed`, `asleepUnspecified`, `awake`
  (iOS 10+); `asleepCore`, `asleepDeep`, `asleepREM` (**iOS 16+**).
  https://developer.apple.com/documentation/healthkit/hkcategoryvaluesleepanalysis —
  verified. iOS 17 minimum means all six are available to us; **availability of the stage
  *values* is not availability of stage *data***.
- **Writers differ, and this is the crux of the degradation ladder.**
  - Apple Watch writes staged samples natively (watchOS 9+).
  - Oura explicitly writes "Sleep Duration, Start Time, End Time, Sleep Stages" to Health —
    verified on Oura's own support page
    (https://support.ouraring.com/hc/en-us/articles/360025438734-Apple-Health-Integration),
    with a caveat that Health may re-bin/round the intervals.
  - **Whoop appears to export only asleep/awake sessions to Health, not its 5-stage
    breakdown** — source: https://tryterra.co/blog/whoop-syncs-health-data-to-apple-health-ee298d328f41,
    **grade E, must be verified on device before we rely on it.** If true, a Whoop user is
    a duration-only user in Tuwa, which is a big share of our target market.
  - Garmin writes sleep via Garmin Connect; stage granularity into HealthKit is
    **unverified** — check on device.
  - Manual entries and iPhone-only users produce `inBed` with no stages at all.
- **Staging accuracy against PSG is moderate at best.**
  - Chinoy et al., *Sleep* 44(5):zsaa291, 2021: consumer devices detect sleep/wake well,
    but "device sleep stage assessments were inconsistent".
    https://academic.oup.com/sleep/article/44/5/zsaa291/6055610 — **grade A**.
  - Six-device validation, *SLEEP Advances* 6(2):zpaf021, 2025: four-stage Cohen's κ ranged
    0.21–0.53 (Apple Watch S8 0.53, Fitbit Sense 0.42, Charge 5 0.41, Whoop 4.0 0.37,
    Withings 0.22, Garmin Vivosmart 4 0.21). Whoop caught 69.6% of deep epochs; Apple Watch
    68.6% of REM. Authors: usable for "prolonged and significant changes in sleep
    architecture", not for clinical staging.
    https://academic.oup.com/sleepadvances/article/6/2/zpaf021/8090472 — **grade A**.
  - Apple's own white paper (*Estimating Sleep Stages from Apple Watch*, Oct 2025,
    https://www.apple.com/health/pdf/Estimating_Sleep_Stages_from_Apple_Watch_Oct_2025.pdf)
    exists but **exceeded the fetch size limit — I did not read it.** Someone should, before
    we hard-code any deep/REM anchor.

**Design consequence, stated plainly:** κ ≈ 0.4–0.5 means a single night's deep-minutes
figure carries maybe half the information it appears to. Stage components therefore
(a) get small weights, (b) are scored **relative to the athlete's own trailing distribution
from the same source**, not against absolute norms, and (c) are capped in how far they can
move the total.

---

## 4. Personalized sleep need — method and guardrails

**Cold start.** `RecoveryScoreEngine.sleepTargetHours = 7.5` stays the default until the
personalization gate opens. No change for new users.

**Gate.** ≥28 nights with sleep data in the trailing 90 days, of which ≥8 qualify as
"unconstrained" (see below). Below the gate, need = 7.5 h, full stop.

**Estimator — max of two, blended.**
- *(a) Unconstrained-night estimate.* 75th percentile of TST on nights the athlete was not
  woken by obligation: no session logged before 10:00 the next day, and wake time not
  within ±20 min of their modal weekday wake time. Percentile, not max, because Klerman &
  Dijk show unlimited opportunity inflates duration toward ~9 h; and not the mean, because
  the constrained nights we filtered out are exactly the ones that drag a mean down.
- *(b) Response-based estimate.* Bin trailing-90-night TST into 30-min bins; for each bin
  take median **next-day sleep-free readiness** = weighted z of (HRV vs baseline, RHR vs
  baseline, wellness). **The sleep component must be excluded from this proxy or the
  analysis is circular** — this is the single most important implementation detail in this
  section. Need_b = the lowest bin at which median readiness reaches ≥95% of the plateau
  (max over bins). Requires ≥40 nights and ≥3 populated bins ≥6 h.
- *Blend:* `need_base = 0.6·(a) + 0.4·(b)` when (b) qualifies; else (a); else 7.5 h.

**Guardrails.**
- Bounds: clamp to **[6.5 h, 9.5 h]**.
- Deadband: ignore recomputed values within 15 min of the current stored need.
- Rate limit: at most ±10 min change per weekly update (hysteresis; mirrors the CV-warning
  hysteresis in `BaselineEngine`).
- Cadence: weekly, on the same weekday, from the pipeline — never nightly.
- Reset on discontinuity: if the dominant sleep source bundle ID changes, freeze need and
  restart the stage baselines (device bias is not the athlete changing).

**Nightly need** (the number the duration component scores against):
```
need_tonight = clamp(need_base + strainCredit + debtCredit, need_base, min(need_base + 60min, 10h))
```
- `strainCredit`: 0–30 min, scaled by yesterday's session load vs the athlete's own 28-day
  mean (Tuwa already has TSS/ACWR and cross-modal load). Capped at 30 min, not Whoop's
  claimed 60, because the 60 is vendor-asserted and unverified.
- `debtCredit`: 0–30 min, = 30% of the trailing 7-night cumulative deficit, capped.
  Justified by Van Dongen 2003 (deficits accumulate), capped because full repayment in one
  night is not physiologically supported by anything I found.

**Transparency / nocebo guard.** Target changes surface **once, in the sleep detail screen
and Profile**, in sentence case, as a statement of fact with no imperative: "Your sleep
target moved from 7.5 h to 7.8 h, based on 62 nights." A one-line history of target changes
is inspectable. Never a push notification, never "you are sleep deprived", never a red
state. The target is presented as *what your body has been asking for*, not a demand.

---

## 5. Proposed Tuwa sleep score

Pure function, tier-selected, weights renormalized over available components exactly as
`RecoveryScoreEngine.compute` already does for missing inputs.

### 5.1 Components and composition (Tier A — stages available)

**Composition council-ruled 2026-08-02** (`.planning/sleep-v2/council-composition-ruling.md`;
H-16 in §9.5) — supersedes this section's original weighted-mean table. HAN's 80/20 rule
is stated directly in the arithmetic:

`score = 0.80 × D + Σ pᵢ × clamp((Cᵢ − 80) / 20, −1, +1)`

where D is the duration-vs-need curve (0–100, so duration contributes exactly 0–80),
Cᵢ is each quality component's 0–100 curve value with **met/normal anchored at 80**, and
pᵢ is its point allocation from a 20-point pool. Signed: sub-baseline quality SUBTRACTS,
bounded at −20 total by the ±1 clamp (need-met with catastrophic quality floors at 60).
Quality points never renormalize over missing components (H-17): an absent component
contributes zero, either direction.

| Component | Points | Input | Athlete rationale |
|---|---|---|---|
| Duration vs need | **0.80 × D** (fixed share, not pooled) | TST ÷ `need_tonight` | Only component with direct athlete outcome evidence (Mah, Milewski, Van Dongen). Everything else is mechanism or vendor convention. |
| Continuity (efficiency) | **8** | TST ÷ inBed (the true opportunity window; WASO alone carries no authority — council ruling) | Athletes are *systematically* fragmented (Leeder). Fragmentation is measured far more reliably than staging (Chinoy: sleep/wake good, stages poor). |
| Regularity/timing | **5** | SD of sleep midpoint over trailing 14 nights | Windred 2024 is strong but for *mortality*, not next-day readiness — it cannot fund more than 5 (the council's registry-hygiene ruling); evening basketball makes timing behaviourally actionable. |
| Deep vs own baseline | **3.5** | deep min ÷ EWMA(deep min, same source) | SWS↔GH is grade-A physiology; nightly predictive value is unproven and κ is moderate. Small allocation is the honest allocation. |
| REM vs own baseline | **3.5** | REM min ÷ EWMA(REM min, same source) | Motor consolidation is real; *which stage* is contested. Same reasoning. |

Anchors (all tunable constants, no literals in views; every quality curve's met/normal
point reads 80 — the shared met anchor, so met quality adds exactly zero):
- **Duration** on ratio r = TST/need: r ≥ 1.00 → 100; 0.95 → 90; 0.90 → 80; 0.85 → 68;
  0.80 → 55; 0.70 → 32; ≤0.60 → 10. Piecewise-linear between anchors, monotone.
- **Continuity**: ≥92% → 100; 88% → 90; 85% → 80 (the met anchor — athlete-normal, not a
  failure); 80% → 62; 75% → 45; ≤65% → 20. Deliberately shifted down from the
  general-adult 85% "good" line because athlete pooled SE is ~86% (Deconstructing
  athletes' sleep).
- **Deep / REM** on ratio q = tonight ÷ personal EWMA (re-anchored per H-11 REVISED,
  council ruling 2026-08-02): q ≥ 1.30 → 100; **1.00 → 80** (the met anchor); 0.85 → 75;
  0.70 → 70; 0.55 → 55; ≤0.4 → 45. **Floored at 45** — one noisy staging night must not
  be able to crater the score, and there is no evidence supporting a harsher penalty.
- **Regularity** on midpoint SD: ≤30 min → 100; 45 → 90; 60 → 80 (the met anchor — an
  ordinary athlete fortnight); 90 → 62; ≥120 → 45. Floored at 45 for the same reason
  (health-endpoint evidence, not readiness evidence).

**Calibration warning, load-bearing:** under these anchors, hitting your need scores the
duration component 100, whereas today 7.5 h scores 70. The v2 sleep component will run
materially *higher* than v1 for well-slept nights, which raises the whole recovery score
because sleep is 25% of it. Either the sleep weight, the recovery zone thresholds, or the
anchors must be re-examined together. **This is not a detail to discover in production —
it is Open Question 1.**

### 5.2 Degradation ladder

| Tier | Data present | Behaviour |
|---|---|---|
| A | Stages + timing (+ inBed) | All 5 components, weights as above. |
| B | Stages, no `inBed` | Continuity carries no authority (council ruling 2026-08-02: no in-bed span = no honest efficiency denominator; the original "continuity from WASO" is superseded). Max 92 (H-17). |
| C | Duration + timing only (`asleepUnspecified`; likely Whoop/Garmin/manual) | Duration 0.75 + regularity 0.25, renormalized. Stage components omitted, not zeroed. |
| D | Duration only, <7 nights history, or need not yet personalized | **Exactly today's `sleepDurationToScore` curve against 7.5 h.** Bit-identical fallback. |
| E | No sleep data | Component omitted, weights redistributed — today's behaviour, unchanged. |

Every tier also emits a `confidence` in [0,1] (nights of history × source stability ×
component count), mirroring `BaselineEngine.confidence`, so the verdict layer can
down-weight a low-confidence sleep signal instead of the score silently pretending.

### 5.3 Integration with Tuwa's architecture (hard constraints)

- **New `SleepScoreEngine`: pure struct, static methods, zero state, zero `Date.now`** —
  same contract as `BaselineEngine` (which is grep-gated for `Date(`/`.now`). All
  personalization arrives as inputs.
- **State lives in `BaselineState`**, which already carries a sleep sub-state
  (`sleepMu/sleepWelfordMean/sleepM2/sleepCount/sleepMadBuffer/sleepLastBucketedDate/
  sleepCvRatio/sleepCvLevelRaw/sleepConfidence`). Add: `sleepNeedMinutes`,
  `sleepNeedUpdatedAt`, `sleepNeedSource` (default/learned), `deepMu`/`deepCount`,
  `remMu`/`remCount`, `midpointBuffer: [Double]`, `dominantSleepSourceID: String?`.
  Folded by the pipeline, never by the engine.
- **`HealthKitService`** gains `fetchLastNightSleepDetail()` returning per-stage minutes,
  awake minutes, inBed minutes, session start/end, and the set of source bundle IDs.
  Existing `fetchLastNightSleep()` stays for the Tier-D path.
- **`RecoverySnapshot`** gains stage minutes + the tier + the need used. `sleepScore`
  already exists.
- **Privacy**: composite `sleepScore`, tier, and (proposed) `need` may sync; **per-stage
  minutes are device-local and must be excluded from `SyncService`'s payload.** Note
  `sleepDurationMinutes` already syncs today — whether stage minutes are "raw HealthKit
  data" under the existing rule is Open Question 2, and I am reading the rule
  conservatively until HAN says otherwise.
- **No network, no LLM, no server compute.** Everything above is arithmetic on ≤90 rows.

---

## 6. Validation plan

**Phase 0 — shadow dual-run (mandatory, ≥6 weeks).** Compute v1 and v2 every night, store
both, ship *nothing* user-facing. The repo already has this pattern
(`CrossModalShadowGate`, `PRSDualRunSurface`, `ShadowAnalyticsService`) — reuse it rather
than inventing a new one.

**Log per night** (local only): source bundle IDs, TST, stage minutes, WASO, inBed,
start/end, tier, each component score and weight, `need_base` and `need_tonight` with their
credits, v1 score, v2 score, confidence; next morning: HRV, RHR, wellness, the sleep-free
readiness proxy; next evening: session RPE, felt-right response, verdict issued.

**Falsification criteria — any one fails, the corresponding piece is cut:**
1. **The whole v2 fails** if, over ≥60 nights, v2's Spearman correlation with next-day
   sleep-free readiness does not exceed v1's by a paired-bootstrap margin excluding zero.
   Then: keep duration-only, keep the personalized need if it independently passes (4).
2. **Stage components fail** if their within-source night-to-night residual SD exceeds the
   range over which the deep/REM curves move (i.e. the component is noise). Then: drop to
   Tier C weights for everyone.
3. **Regularity fails** if midpoint SD shows no association with next-day readiness *and*
   HAN reports it as not actionable. Then: move it out of the score into a descriptive
   insight.
4. **Need estimation fails** if it hits a bound (6.5/9.5) within the first 90 days, if
   alternating-week split-halves disagree by >30 min, or if (a) and (b) disagree by >60 min
   persistently.
5. **Whoop/Garmin coverage fails** if on-device inspection shows those sources deliver no
   stages — which does not kill v2, but means Tier C is the *modal* path and its weights
   deserve as much care as Tier A's.

**Honest limit of n=1.** A founder dogfood can falsify (it can show the thing is broken,
noise-dominated, or drifts) but it **cannot calibrate weights** — 0.50/0.15/0.10/0.10/0.15
are priors argued from evidence quality, not fitted values. Anyone reviewing this should
treat "the weights are right" as an unsupported claim, today and after the dogfood.

---

## 7. Open questions for HAN

1. **Score inflation — ANSWERED (HAN, 2026-07-31): option (c), re-anchor, with calibrated
   strictness.** HAN's reasoning, recorded: Apple's sleep score hands out 99/100 for any
   long, unbroken night, and those nights do not reliably match his waking subjective
   energy — that inflation is the failure mode to avoid. But the score must stay
   encouraging, never stressful. Implementation directive: need-met on duration alone
   lands ≈ 85, not 100; the last ~15 points are earned by the quality components
   (continuity, stages at/above own baseline, regularity), so 100 means a genuinely
   excellent night, not merely a long one. Zone boundaries re-checked under the new
   distribution during the shadow dual-run.
2. **Do stage minutes sync? — ANSWERED (HAN, 2026-07-31): device-local.** Stage minutes
   are treated as raw-adjacent HealthKit data; only the composite sleep score syncs.
3. **Target-move transparency — ANSWERED (HAN, 2026-07-31): silent.** The learned need is
   not announced when it moves. (It may still be *inspectable* somewhere quiet if a later
   ruling wants it; announcing is what is ruled out.)

**Device-coverage ruling (HAN, 2026-07-31):** no Whoop or Garmin hardware is available for
the stages-in-HealthKit check. v2 targets **Apple Watch + Oura** users first; the
Whoop/Garmin tier verification is a future-version item. Tier C (duration+timing) remains
the designed fallback for those sources whenever they arrive.
4. **Should need respond to the *plan*, not just yesterday?** Tuwa knows tomorrow is a
   match. Whoop cannot do this. Pre-load the need the night before a match tier? Defensible
   product wedge, zero direct evidence.
5. **REM weighting by skill load** (heavier REM weight after a skill-heavy basketball
   session) — attractive story, contested science (§1.2). Park it as v2.1, or test it in
   shadow now?
6. **Regularity: inside the sleep score, or its own thing?** Its evidence base is a
   different endpoint from everything else in the recovery score.
7. **Naps.** Whoop credits them. HealthKit will report daytime `asleep` samples. Count
   toward TST, count at a discount, or ignore?
8. **Does a scenario profile ever surface to the athlete?** §9 stores it for audit. Showing
   it ("scored against a hard training day") is honest and explains score movement; naming
   `CHRONIC_IRREGULAR` to a user is a nocebo grenade. My default: neutral one-liner for
   load/pressure profiles, silence for the circadian ones.
9. **Freeze need learning during CHRONIC_IRREGULAR?** I propose yes (§9.3) — the
   unconstrained-night estimator's assumptions are violated. Cost: the athletes who most
   need a personalized target are the ones who stop getting one.
10. **Which load signal drives HIGH_STRAIN_DAY** — session TSS, cross-modal fatigue, or
    HealthKit active energy? TSS misses a 12-hour tournament day with no logged session;
    active energy catches it but is noisy and device-dependent.
11. **How many profiles may stack on one night?** I cap the *effect* (§9.4) rather than the
    count. An alternative is strict priority (one profile wins). Priority is more auditable;
    stacking is more truthful.
12. **Is the algorithm published?** §10 argues transparency is the marketing asset. That
    means publishing weights competitors can copy. HAN's call.

---

## 8. Things I could not verify (do not treat as known)

- Apple's own staging validation numbers — white paper exceeded the fetch limit.
- Whoop's Sleep Need constants (30–60 min strain add, debt caps) — vendor pages 403'd;
  everything here is search-excerpt level.
- Whether Whoop and Garmin write sleep *stages* into HealthKit — third-party blog only.
  **On-device check required; it decides which tier is the common case.**
- Oura's component weights — proprietary, never published.
- The "+9% shooting" figure from Mah 2011 — read the paper before printing it anywhere.
- Borbély's Process S time constants (build-up/decay) — I read abstract-level summaries and
  the reappraisal's framing, **not** the parameter values. §9 therefore uses Process S as a
  *shape* argument (pressure rises with wake, dissipates with sleep) and never implements
  the equation.
- Any quantitative link from prior-day energy expenditure to *how many minutes of extra
  sleep are needed*. I found none. The strain credit is an assumption in both Whoop's model
  and ours.
- App Store Review Guidelines wording on health claims (§10 flags copy review; I did not
  fetch the guideline text this session).

---

## 9. Context-conditional scoring (HAN direction, 2026-07-31)

HAN's ruling: the same night of sleep does not mean the same thing in every state. Weights
(and which components deserve authority) shift with the state the athlete entered sleep in.
**One mechanism, different proportions** — profiles are *adjustments over the §5 base
weights*, never parallel scoring systems.

### 9.1 Formal foundations

- **Two-process model (Process S / Process C).** Borbély, Daan, Wirz-Justice, Deboer,
  *J Sleep Res* 25(2):131–143, 2016 (reappraisal of the 1982 model). Process S — homeostatic
  sleep pressure — **accumulates during wakefulness and dissipates during sleep**, and is
  explicitly described as "sleep debt"; slow-wave activity is its EEG marker. It interacts
  with the circadian Process C. https://onlinelibrary.wiley.com/doi/10.1111/jsr.12371,
  https://pubmed.ncbi.nlm.nih.gov/26762182/ — **grade A** for the framework. **I did not
  read the time constants**, so we use the *shape* (longer wake → higher pressure → more
  sleep needed, deep sleep front-loaded) and never the equation. This is the formal basis
  for HAN's scenario 1.
- **Extended wake produces SWS/REM rebound.** Recovery sleep after deprivation shows
  increased slow-wave density/amplitude/slope, and REM rebound magnitude tracks the extent
  of prior deprivation. https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0043224,
  https://www.ncbi.nlm.nih.gov/books/NBK560713/ — **grade B** (PLOS study is a controlled
  lab protocol; StatPearls is a textbook chapter). Consequence: **after long wake, a normal
  deep% is not neutral — expected deep is elevated, so failing to rebound is the signal.**
- **Exercise nudges architecture, weakly.** Kredlow et al., *J Behav Med* 38:427–449, 2015,
  meta-analysis of 66 studies: acute exercise has *small* beneficial effects on TST, latency,
  efficiency and SWS, and a moderate effect on WASO.
  https://link.springer.com/article/10.1007/s10865-015-9617-6 — **grade A, small effects.**
  Evening-exercise meta-analysis (*Sports Med* 2019): SWS +1.3 percentage points vs control.
  https://link.springer.com/article/10.1007/s40279-018-1015-0 — **grade A, tiny effect.**
- **Training load → sleep *need* is NOT established.** A combat-athlete case report found
  trivial, non-significant relationships between daily training load and sleep
  characteristics. https://pmc.ncbi.nlm.nih.gov/articles/PMC9887639/ — **grade C**, but it is
  the closest direct test I found, and it is null. **The strain credit (§4) and the
  HIGH_STRAIN_DAY profile are hypotheses, not evidence.** Whoop asserts the same link with
  no published validation; we should not inherit their confidence.
- **Acute circadian disruption is worse than the adapted state.** First-night-shift studies:
  the nocturnal decline in visual selective attention and the increase in attentional lapses
  are **most pronounced on the first night** versus subsequent nights.
  https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0001233,
  https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6420632/ — **grade B**. This validates HAN's
  scenario 3 as a *distinct state*, not merely a worse version of scenario 4.
- **Chronic misalignment = social jetlag.** Wittmann & Roenneberg, *Chronobiol Int* 23(1–2),
  2006: social jetlag = difference in **sleep midpoint** between work and free days —
  which is exactly the quantity we can compute from HealthKit.
  https://www.tandfonline.com/doi/abs/10.1080/07420520500545979; health-risk review,
  *Nutrients* 13(12):4543, 2021, https://pubmed.ncbi.nlm.nih.gov/34960096/ — **grade A/B for
  the construct and its health associations; no evidence tying it to next-day athletic
  readiness.**
- **Naps.** The sleep-intervention review reports 20–90 min naps improve performance after a
  normal night and restore decrements after partial restriction
  (https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10354314/) — **grade B**. Nothing supports
  1:1 substitution of nap minutes for night minutes, which is what Whoop's "− naps" implies.

### 9.2 The nightly state vector

Computed by the pipeline from data Tuwa already has; passed into the pure engine.

| Field | Source | Notes |
|---|---|---|
| `priorWakeHours` | previous sleep session `endDate` → this session `startDate` | Direct Process-S proxy. Needs the previous night's session, so it is nil on first run. |
| `priorWakeZ` | vs athlete's own 28-night median prior-wake | Absolute thresholds are wrong for a night-owl student. |
| `midpointSD14` | `BaselineState.midpointBuffer`, trailing 14 nights | Regularity state; also the §5 regularity input. |
| `midpointDeviation` | tonight's midpoint − trailing median midpoint | Social-jetlag quantity (Roenneberg's definition). |
| `daysSinceRhythmBreak` | nights since last \|deviation\| > max(2×SD, 90 min) | Separates acute from chronic. |
| `irregularStreak` | consecutive days with `midpointSD14` above the entry threshold | Chronic state with hysteresis. |
| `sleepDebt7` | Σ max(0, need_i − TST_i), trailing 7 nights, capped 6 h | Van Dongen 2003 basis. |
| `priorDayLoadZ` | session TSS / cross-modal load vs 28-day mean | Existing Tuwa data. |
| `priorDayActiveEnergyZ` | HealthKit `activeEnergyBurned` vs 28-day mean | Catches unlogged load (tournament days). |
| `napMinutes` | daytime `asleep` samples since last main sleep | HealthKit already exposes these. |
| `stagesAvailable`, `sourceStable`, `nightsOfHistory` | sleep samples + bundle IDs | Feeds tier + confidence (§5.2). |

All of it is arithmetic over ≤90 local rows. No network, no new permissions beyond
`activeEnergyBurned` read.

### 9.3 Scenario profiles (adjustments to §5 base weights)

Base: duration 0.50 / continuity 0.15 / deep 0.10 / REM 0.10 / regularity 0.15.

| Profile | Trigger | Weight deltas | Need delta | Status |
|---|---|---|---|---|
| **BASELINE** | none of the below | — | — | n/a |
| **HIGH_PRESSURE** | `priorWakeHours ≥ 18` or `priorWakeZ ≥ +1.5` | duration +0.05, deep +0.04, regularity −0.07, REM −0.02 | +6 min per hour of wake above 16 h, cap +45 min | **EVIDENCE-BACKED** (Borbély 2016; SWS-rebound literature) for direction; magnitudes = H-02 |
| **HIGH_STRAIN_DAY** | `priorDayLoadZ ≥ +1` or `activeEnergyZ ≥ +1` | duration +0.02, deep +0.03, regularity −0.05 | +0…30 min | **HYPOTHESIS** (H-03) — Kredlow's SWS effect is small; load→need is null in the only direct test found |
| **ACUTE_SHIFT** | `\|midpointDeviation\| > 2 h` **and** prior `midpointSD14 < 60 min` **and** `daysSinceRhythmBreak ≤ 2` | regularity −0.10, continuity +0.05, duration +0.05, deep −0.03, REM −0.03; **stage components capped at half authority** | +0 (pressure handled by HIGH_PRESSURE if it stacks) | **EVIDENCE-BACKED** that the first disrupted night is uniquely impaired (first-night-shift studies); **HYPOTHESIS** that de-weighting regularity is the right response (H-05) |
| **CHRONIC_IRREGULAR** | `midpointSD14 > 75 min` on ≥10 of 14 nights (exit at <50 min for 5 consecutive nights) | regularity +0.07, duration −0.05, deep −0.02, REM −0.02 | none; **need learning FROZEN** | **HYPOTHESIS** (H-06); construct and health risk are evidenced (Roenneberg, Windred), the weighting is not |
| **DEBT_CARRY** | `sleepDebt7 ≥ 3 h` | duration +0.08, all others −0.02 | +0…30 min (§4 debt credit) | **EVIDENCE-BACKED** direction (Van Dongen 2003: deficits accumulate, hours are what repay them); magnitude = H-07 |
| **NAP_DAY** | `napMinutes ≥ 20` | none | −50% of nap minutes, cap −45 min | **HYPOTHESIS** (H-08); naps help performance (grade B) but 1:1 substitution is unsupported |

Rationale threads worth stating explicitly, because they are the non-obvious part:
- **Why deep goes *up* after long wake or hard load, not down.** Rebound is expected, so the
  measurement is more informative in exactly those states — a night that should have
  rebounded and didn't is a real signal. In BASELINE, nightly deep noise mostly reflects
  staging error (κ ≈ 0.4–0.5).
- **Why REM and deep go *down* under CHRONIC_IRREGULAR and ACUTE_SHIFT.** REM proportion is
  circadian-phase-gated; stage percentages measured at wildly different clock phases are not
  comparable to a personal baseline built from stable-phase nights. Scoring them anyway
  would be measuring the clock, not the recovery.
- **Why regularity goes *down* on the acutely-shifted night.** The athlete already loses
  points on duration and continuity that night. Penalizing regularity too is triple-counting
  one event — and it is the state where the app is most likely to nag someone who flew to a
  tournament. Nocebo guard, expressed as arithmetic.

### 9.4 Composition rules

1. Profiles are detected independently and **may stack**, except ACUTE_SHIFT and
   CHRONIC_IRREGULAR, which are mutually exclusive (acute wins for its ≤2 nights).
2. Deltas are summed, each weight clamped to **[0.05, 0.60]**, then renormalized to 1.0 over
   the components available in the active tier (§5.2). A component dropped by tier never
   receives a delta.
3. Total need adjustment from all sources (strain + debt + pressure − nap) stays inside the
   §4 cap: `need_base ≤ need_tonight ≤ min(need_base + 60 min, 10 h)`.
4. Every state entry/exit has hysteresis except ACUTE_SHIFT, which is single-night by
   definition.
5. The active profile set, the state vector, and the final weights are **stored on the
   snapshot** — a score no one can reconstruct after the fact is not auditable, and this
   engine is going to be argued about.
6. Profiles never change the *tier* and never invent components. Mechanism stays one.

### 9.5 Hypothesis registry (living artifact)

Rule: **anything in the engine that is not backed by a cited source lives here as a row with
a falsification test.** No unregistered assumption ships. This table is maintained in this
file, reviewed at every release that touches the sleep engine, and each row moves through
`HYPOTHESIS → SUPPORTED(n=1) → SUPPORTED(cohort) → REVISED → RETIRED`.

| ID | Claim | Status | Basis | How it gets validated / revised |
|---|---|---|---|---|
| H-01 | Base weights 0.50/0.15/0.10/0.10/0.15 are near-optimal | HYPOTHESIS | Argued from evidence *quality*, not fitted | Shadow run: per-component partial correlation with next-day sleep-free readiness; refit when ≥200 nights exist across ≥20 users |
| H-02 | Need rises ~6 min per hour of wake above 16 h, cap 45 min | HYPOTHESIS | Process S shape (grade A) without published constants | Compare readiness after long-wake nights that did vs didn't reach the raised need; if no difference, flatten to 0 |
| H-03 | A hard training day raises sleep need by up to 30 min | HYPOTHESIS | Kredlow (small architecture effects); direct load→need test is null | Regress next-day readiness on (TST − need) split by load tertile; if the interaction is absent, delete the strain credit — including from §4 |
| H-04 | Deep/REM scored vs the athlete's own same-source EWMA beats population norms | HYPOTHESIS | κ 0.21–0.53 implies device-specific bias (grade A) | Compare both formulations in shadow; also compare across a deliberate device switch |
| H-05 | De-weighting regularity on the acute-shift night is correct | HYPOTHESIS | Impairment on first disrupted night is evidenced; the *response* is not | If acute-shift nights show readiness *worse* than the score implies across ≥10 events, the de-weighting is too generous |
| H-06 | Under chronic irregularity, regularity deserves more weight and stages less | HYPOTHESIS | Social-jetlag health associations (grade A/B); no readiness evidence | Within-athlete: does midpoint SD predict next-day readiness at all? If not, move regularity out of the score entirely (see §7 Q6) |
| H-07 | When in ≥3 h debt, hours dominate architecture | HYPOTHESIS-leaning-evidence | Van Dongen 2003 (grade A) supports hours mattering; the weight shift is ours | Check whether stage components retain any predictive power inside debt states |
| H-08 | A nap offsets 50% of its minutes against nightly need | HYPOTHESIS | Naps aid performance (grade B); substitution ratio unknown | Compare readiness on nap+short-night vs no-nap+equal-total nights |
| H-09 | Personalized need beats the fixed 7.5 h target | HYPOTHESIS | Walsh 2021 consensus recommends individualization (grade A) but does not prove a method | §6 criterion 4 + head-to-head correlation vs fixed target |
| H-10 | Athletes are not harmed (nocebo) by seeing a moved target or a profile label | HYPOTHESIS | None — pure product judgement | Dogfood report + any support signal; revert to silent if it reads as alarming |
| H-11 | The stage curve's met point is q = 1.00 → **80** (the shared met anchor) and its excellent point q ≥ 1.30 → 100, with the 0.85 anchor at **75** — not §5.1's original q ≥ 1.00 → 100 / 0.85 → 85 | **REVISED** (council ruling 2026-08-02: stage met point 85 → 80 so met adds exactly zero under H-16; excellent q ≥ 1.30 → 100 unchanged; 0.85 anchor → 75; sub-baseline anchors and the 45 floor unchanged) | Engine-side consequence of HAN's 80/20 ruling: every quality curve shares one semantic zero ("80 = your normal") | Shadow: distribution of nightly q per athlete per source. If q ≥ 1.30 is unreachable (<2% of nights) the excellent anchor moves to the observed 90th percentile; if at-baseline nights systematically out-run HAN's felt-right rating, the met point is too generous. **§10 publishes these numbers.** |
| H-12 | ~~The Q1 re-anchor constants — duration ceiling 85, quality met anchor 85, quality headroom gain 2.0~~ | **RETIRED** — superseded by council ruling 2026-08-02 (`.planning/sleep-v2/council-composition-ruling.md`): the plateau + met-anchor + headroom-gain mechanism hid the 80/20 rule behind a derived gain constant; the founder's rule should be visible in the arithmetic. Replaced by **H-16** | Was: a derivation from HAN's Q1 ruling (§7 Q1) | n/a — see H-16 |
| H-16 | The two-part composition `score = 0.80 × D + Σ pᵢ × clamp((Cᵢ − 80)/20, −1, +1)` with the ±1 clamp and point vector continuity 8 / regularity 5 / deep 3.5 / REM 3.5 | HYPOTHESIS | Council ruling 2026-08-02 (unanimous on the form; chair-ruled 8/5/3.5/3.5 on registry hygiene — Windred 2024 is a mortality endpoint and cannot fund regularity 6) | Kill tests: (a) partial-r ≤ 0 for any component vs sleep-free next-day readiness at ≥200 nights/≥20 athletes drops that component's points; (b) if HAN's felt-right log shows need-met nights systematically scored above/below ~80, the met anchors are wrong; (c) if no night reaches 100 in ≥60 nights, the excellent anchors are unreachable and move to observed p90 |
| H-17 | Tier maxima as epistemic caps (B 92 / C 85–93): quality points do not renormalize over missing components — missing evidence cannot testify | HYPOTHESIS | Council ruling 2026-08-02 (epistemic-cap principle, both members; chair corrected the carried-over 90/94 renormalizing caps) | Kill test (Codex's, adopted): mask Tier-A nights down to Tier C; if masked scores predict full Tier-A scores with MAE ≤ 3 over ≥200 paired nights, the caps are too conservative |
| H-18 | Profile deltas as point transfers with preserved ratios (§9.3's quality-side weight deltas × 40 into the 20-point pool; duration-side deltas dropped as double-counting; ACUTE_SHIFT stage half-authority = stage points halved 3.5 → 1.75) | HYPOTHESIS | Council ruling 2026-08-02 (profiles touch only the 20-point pool; §4's need credits already move duration's lever) | Kill test: H-13's chatter counts plus shadow comparison of per-profile score deltas vs the old weight-delta arithmetic on the same nights (divergence > 5 pts on >10% of profile nights = translation wrong, revisit) |
| H-13 | Hysteresis hold bands (pressure 18 h → hold 17 h, z 1.5 → 1.25; strain z 1.0 → 0.75; debt 180 → 150 min; nap 20 → 15 min) stop state chatter without changing what the states mean | HYPOTHESIS | None — §9.4 rule 4 mandates hysteresis on every state but ACUTE_SHIFT and names no bands | Shadow: count state entries/exits per 30 nights. More than one flip per two nights on any state = band too narrow; a state that never exits over 30 nights once its signal has fallen = band too wide |
| H-14 | The strain credit saturates at z = +2, so §9.3's trigger point (z = +1) is worth half the 30-min cap | HYPOTHESIS | None — chosen. §4 caps the credit and §9.3 gives the band, neither gives the shape | Falls out of H-03's test: regress next-day readiness on (TST − need) split by load tertile. If the interaction is absent the credit dies with H-03; if present but flat in z, the ramp becomes a step at the trigger |
| H-15 | A changed dominant sleep source halves confidence rather than blocking the score | HYPOTHESIS | None — §5.2 names source stability as a confidence factor and gives it no weight; §4's reset-on-discontinuity rule is the evidence that a source change is a real discontinuity (device bias, κ 0.21–0.53) | Shadow: compare v2-vs-readiness correlation on the 14 nights after a source change against matched stable nights. If it is unchanged, the multiplier goes to 1.0; if the score is frankly wrong there, the tier should drop instead of the confidence |

Registry hygiene: every row cites either a source or "none"; a row that cannot name the
measurement that would change it does not belong in the engine.

**Engine-side rulings on internal spec conflicts (S1, pending HAN's signature).** These are
not hypotheses — they are places where two sections of this document disagree and the code
had to pick. Recorded here so the pick is visible, not buried in a comment.

1. **[SUPERSEDED by the council composition, 2026-08-02]** §9.4 rule 2's weight ceiling
   versus §5.2's Tier C table. The [0.05, 0.60] clamp-and-renormalize machinery was
   deleted with H-12: duration no longer participates in a weight vector at all (fixed
   0.80 share), and the quality pool composes by point transfer (H-18) with a zero floor
   and no renormalization.
2. **§5.2 has no row for a stage-less source that still reports an in-bed span.** §3 says
   manual and iPhone-only entries write `inBed`; §5.2's Tier C row covers "duration + timing
   only". Ruling (restated under the council composition): continuity enters Tier C at its
   full 8 points when the in-bed span is present — Tier C max 93 with continuity, 85
   timing-only (H-17). Discarding a measured efficiency — the input §5.1 calls the most
   reliably measured of the five — because the watch did not stage is worse than the
   alternative.
3. **The tier is a data grade, not a baseline-convergence grade.** §5.2's column is "Data
   present", so a not-yet-converged stage EWMA drops the stage component and renormalizes
   (§5 preamble); it does not demote the night. §5.2's Tier D "duration only" clause is
   implemented as "no component but duration is scorable".
4. **§4's credits are unconditional.** §4 writes `need_tonight = clamp(need_base +
   strainCredit + debtCredit, …)` with no trigger, and §9.3's need-delta column points back
   at §4. The engine therefore computes every credit from its continuous formula on every
   night; the §9.3 profiles govern the *weights* only. Gating the credits on the triggers
   made §4's formulas step functions (one minute of trailing deficit was worth 30 minutes of
   need and ~10 points of score).

---

## 10. Marketing significance

HAN designates this as a flagship differentiator for tuwa.app, the App Store page, and
social. The differentiator that is *actually* true today is **not** "we measure sleep better"
— our staging comes from the same wrist sensors as everyone's, at κ ≈ 0.4–0.5. It is:

1. **The target is yours and it is inspectable.** Whoop's Sleep Need is a black box; Oura's
   weights are proprietary. We can publish ours.
2. **The score knows what the night has to do.** Scoring 7 h the same way after an 18-hour
   day, after a match, and after a normal Tuesday is what every competitor does.
3. **It never leaves the phone.** Composite scores only.

**Claim ladder — what is honestly sayable at each stage.**

| Stage | Sayable | Never sayable |
|---|---|---|
| **A. Shadow (not user-facing)** | Mechanism and design only: "learns your sleep target from your own nights", "weights the night by the state you entered it in". Describe, never assert benefit. | Any performance, recovery, or accuracy claim. Any "validated". Any before/after numbers. |
| **B. Live, n=1 dogfood passed** | "Adapts to your prior wakefulness, training load, and sleep regularity." Name the inputs. Publish the weights and the hypothesis registry — the registry *is* the credibility asset. | "Proven", "clinically validated", "improves performance", anything implying n>1. Citing Mah's basketball results as if they were our users' results. |
| **C. Population-validated (≥200 nights, ≥20 athletes, pre-registered)** | Aggregate findings, stated with n and effect size, and stated as association. | Causal or medical claims; injury-prevention claims; sleep-disorder claims. |

**Hard rails for any copy, at every stage:**
- No medical, diagnostic, or injury-prevention claims. The Milewski/meta-analysis injury
  associations justify our *design*; they must never appear as "Tuwa reduces injury risk".
  (Also: run health-claim copy against App Store Review Guidelines §1.4.1 before submitting —
  I did not fetch the guideline text, so treat this as a to-check, not a citation.)
- No stage-accuracy implications. If we show deep/REM we say they come from the athlete's
  device and are compared to their own history — which is exactly why it works despite the
  sensors.
- Citations in marketing point to papers, and describe what the paper found, not what we
  hope users infer.
- The nocebo guard extends to marketing: no fear framing ("you're wrecking your recovery"),
  no sleep-debt shaming. The engine's voice and the brand's voice must match, or the
  in-app restraint reads as a bug.

The strongest available position, and the one I'd argue for: **publish the algorithm and the
hypothesis registry.** "Here is what we believe, here is our evidence, here is what would
prove us wrong" is a claim no competitor can copy without also giving up their black box —
and it is the only marketing that stays true while the weights are still hypotheses.
