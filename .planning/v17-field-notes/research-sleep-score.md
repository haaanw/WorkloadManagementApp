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

### 5.1 Components and starting weights (Tier A — stages available)

| Component | Weight | Input | Athlete rationale |
|---|---|---|---|
| Duration vs need | **0.50** | TST ÷ `need_tonight` | Only component with direct athlete outcome evidence (Mah, Milewski, Van Dongen). Everything else is mechanism or vendor convention. |
| Continuity (efficiency/WASO) | **0.15** | TST ÷ (TST + WASO), or ÷ inBed when present | Athletes are *systematically* fragmented (Leeder). Fragmentation is measured far more reliably than staging (Chinoy: sleep/wake good, stages poor). |
| Deep vs own baseline | **0.10** | deep min ÷ EWMA(deep min, same source) | SWS↔GH is grade-A physiology; nightly predictive value is unproven and κ is moderate. Small weight is the honest weight. |
| REM vs own baseline | **0.10** | REM min ÷ EWMA(REM min, same source) | Motor consolidation is real; *which stage* is contested. Same reasoning. |
| Regularity/timing | **0.15** | SD of sleep midpoint over trailing 14 nights | Windred 2024 is strong but for mortality, not next-day readiness; and evening basketball makes timing behaviourally actionable. |

Anchors (all tunable constants, no literals in views):
- **Duration** on ratio r = TST/need: r ≥ 1.00 → 100; 0.95 → 90; 0.90 → 80; 0.85 → 68;
  0.80 → 55; 0.70 → 32; ≤0.60 → 10. Piecewise-linear between anchors, monotone.
- **Continuity**: ≥92% → 100; 88% → 90; 85% → 80; 80% → 62; 75% → 45; ≤65% → 20.
  Deliberately shifted down from the general-adult 85% "good" line because athlete pooled
  SE is ~86% (Deconstructing athletes' sleep) — 85% must not read as a failure.
- **Deep / REM** on ratio q = tonight ÷ personal EWMA: q ≥ 1.0 → 100; 0.85 → 85;
  0.70 → 70; 0.55 → 55; ≤0.4 → 45. **Floored at 45** — one noisy staging night must not
  be able to crater the score, and there is no evidence supporting a harsher penalty.
- **Regularity** on midpoint SD: ≤30 min → 100; 45 → 90; 60 → 80; 90 → 62; ≥120 → 45.
  Floored at 45 for the same reason (health-endpoint evidence, not readiness evidence).

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
| B | Stages, no `inBed` | Continuity from WASO stage samples; same weights. |
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

1. **Score inflation.** v2 scores a need-met night at 100 where v1 scored 7.5 h at 70. Do we
   (a) accept higher recovery scores app-wide, (b) drop the sleep weight below 0.25, or
   (c) re-anchor the duration curve so need-met ≈ 85? This changes every zone boundary
   downstream and must be decided before implementation, not after.
2. **Do stage minutes sync?** `sleepDurationMinutes` already goes to Supabase. Are per-stage
   minutes "raw HealthKit data" (→ device-local) or a derived composite (→ syncable)? My
   default is device-local.
3. **Does the athlete get told their target moved, and where?** Silent personalization is
   the least alarming but least trustworthy; a Profile line is inspectable but invites
   "why is it 8.1 h?" Which side of the nocebo guard does this fall on?
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

---

## 8. Things I could not verify (do not treat as known)

- Apple's own staging validation numbers — white paper exceeded the fetch limit.
- Whoop's Sleep Need constants (30–60 min strain add, debt caps) — vendor pages 403'd;
  everything here is search-excerpt level.
- Whether Whoop and Garmin write sleep *stages* into HealthKit — third-party blog only.
  **On-device check required; it decides which tier is the common case.**
- Oura's component weights — proprietary, never published.
- The "+9% shooting" figure from Mah 2011 — read the paper before printing it anywhere.
