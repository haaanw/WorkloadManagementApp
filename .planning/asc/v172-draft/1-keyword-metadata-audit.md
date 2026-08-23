# v1.7.2 ASO — keyword and metadata audit

Drafted 2026-08-22 for HAN review. **Nothing here has been sent to App Store Connect.**
Name, subtitle and the keyword field are version-locked fields: they can only change with a
new build, so they ride 1.7.2 or they wait for 1.8.

---

## 1. What is actually live today

Pulled from the iTunes lookup API on 2026-08-22 (`bundleId=com.tonus.app`, US and CN
storefronts):

| Field | Live value | Budget used |
|---|---|---|
| Name | `tuwa` — **lowercase** | 4 / 30 |
| Name (CN) | `tuwa` — **no Chinese characters at all** | 4 / 30 |
| Subtitle | `Adaptive Strength Training` (per `AppStoreMetadata.md`) | 26 / 30 |
| Keywords | `strength,workout log,readiness,HRV,recovery,training load,RPE,progress,Apple Watch,gym` | 85 / 100 |
| Version live | 1.7.1, released 2026-08-12 | — |
| Ratings | **0** | — |

Three defects, in order of cost:

**D1 — the name field is 4 characters out of 30.** On the App Store the name is the
highest-weighted indexed field; subtitle is second; the keyword field is third. Tuwa spends
nothing on the first one. Every competitor spends all of it:

| App | Name field | Chars |
|---|---|---|
| Strong | `Strong Workout Tracker Gym Log` | 30 |
| Hevy | `Hevy - Workout Tracker Gym Log` | 30 |
| TrainingPeaks | `TrainingPeaks: Plan Train Lift` | 30 |
| HomeCourt | `HomeCourt: Basketball Training` | 30 |
| Athlytic | `Athlytic: Fitness & Recovery` | 28 |
| Kubios | `Kubios HRV - Daily Readiness` | 28 |
| JEFIT | `JEFIT Workout Plan Gym Tracker` | 30 |
| **Tuwa** | `tuwa` | **4** |

**D2 — the CN name has no Chinese in it.** In the China storefront a Latin-only name is close
to unfindable: nothing in the highest-weighted field matches any Chinese query. The CN
competitive set is entirely Chinese-named (`训记 - 训练计划专家`, `开练-健身记录与专业训练计划`,
`练练健身 - 无需私教自学健身记录训练`). Tuwa does already surface for `准备度` — that comes from the
description, which is the weakest of the three fields. Putting `准备度` in the name is the
single cheapest CN ranking change available.

**D3 — the name is lowercase.** `tuwa` on the store, `Tuwa` on the website, in the
description, and in `AppStoreMetadata.md`. Fix the case whatever else is decided.

Not an ASO field but adjacent, and it caps everything above: **0 ratings.** Rating count and
average feed both ranking and conversion. No keyword change compensates for an empty ratings
bar. Flagged; the in-app review prompt is app code and belongs to another lane.

---

## 2. The competitive landscape, measured

Method: `itunes.apple.com/search`, US and CN storefronts, 2026-08-22, `entity=software`,
top 12 per query. This is what the store actually returns, not an estimate.

### US

| Query | Who owns it | Read |
|---|---|---|
| `workout log` | Strong, Hevy, RepCount, Fitlist, JEFIT, Fitbod, Setgraph | Saturated. Established brands with six-figure rating counts. Support term only. |
| `strength training` | Ladder, Fitbod, Caliber, Nike, Gymshark | Saturated and paid-marketing heavy. |
| `hrv` | Elite HRV, Welltory, Kubios, HRV4Training, Athlytic, Observa | Crowded but **specialist**, not brand-dominated. Reachable. |
| `training load` | Training Load & Recovery, Athlytic, DailyTSS, TrainingPeaks, TrainHeroic | Medium. Several tiny indies. **Reachable.** |
| `readiness` | Readiness: Recovery Score, Kubios HRV - Daily Readiness, Readiness Advisor, plus unrelated noise | **Thin.** Two real competitors and a lot of off-topic results. The best available opening. |
| `recovery apple watch` | Athlytic, Heart Analyzer, SleepWatch, StressWatch | Medium-high, Athlytic entrenched. |
| `basketball training` | HomeCourt, Hoops AI, Ball AI, Swish AI, Level Up, 94FEETOFGAME | **Wrong intent.** Every result is AI shot-form or drill video. A recovery-and-lifting app ranking here gets impressions from people looking for a jump-shot analyser. |
| `autoregulation` | almost nothing — RPE Max, RPE Calculator, Anneal | Near-empty, and near-zero volume. Not worth a field. |

### CN

| Query | Who owns it | Read |
|---|---|---|
| `准备度` | FitWoody 恢复教练与准备度, Observa, Reps — **and Tuwa already appears** | **Thin, and we are already in it.** Own it. |
| `训练负荷` | LoadFit, KingFit, Vita, 天悦康康 | Thin and low-quality. Reachable. |
| `HRV` | StressWatch, FeelFlow, 解压小橙子, 潮汐 | Occupied by **stress/relaxation** apps, not training apps. Different intent, weak defenders. |
| `力量训练` | 训记, Muscle Booster, 开练, StrongLifts | Saturated by big Chinese logging apps. |
| `健身记录` | 训记, Keep, Apple 健身, 薄荷健康 | Saturated. Keep is a national brand. |
| `篮球 训练` | 加练, 开炼, 篮迹, 篮球教学 | **Wrong intent** — tutorial video and drill apps. Same problem as the US. |

**Conclusion that drives the recommendation.** The queries where Tuwa can realistically rank
are `readiness` / `准备度` and `training load` / `训练负荷`. The beachhead query — basketball —
is owned end to end by apps doing a different job, in both storefronts. Basketball belongs in
the keyword field, the screenshots and the description hook, where it qualifies the audience,
not in the two fields that decide whether the listing is ever seen.

*(HAN chose this track — "readiness spine" — on 2026-08-22. The basketball-forward
alternative is preserved in §5 in case the beachhead is promoted later.)*

---

## 3. Recommended fields

### English

```
NAME      Tuwa: Training Readiness
SUBTITLE  Your plan, tuned to recovery
KEYWORDS  HRV,load,ACWR,workout,log,lift,strength,sleep,strain,fatigue,basketball,gym,tracker,RPE,barbell
```

- Name 24/30 · Subtitle 28/30 · Keywords 95/100.
- Name and subtitle already index `tuwa`, `training`, `readiness`, `plan`, `tuned`,
  `recovery` — so none of those six are repeated in the keyword field. Apple builds phrases
  across all three fields, so `training load`, `readiness score`, `recovery tracker` and
  `workout log` are all formed without spending characters twice.
- No spaces after commas: a space costs a character and buys nothing.
- `basketball` is in, at low cost, so the beachhead is still reachable by anyone who searches
  for it — without betting the name on it.

Alternates, if the recommendation is rejected:

| # | Name | Subtitle | Note |
|---|---|---|---|
| 1 | `Tuwa: Training Readiness` (24) | `Your plan, tuned to recovery` (28) | **Recommended.** |
| 2 | `Tuwa: Readiness & Load` (22) | `Train by readiness, not mood` (28) | Sharper, less searchable — `load` alone is a weaker token than `training`. |
| 3 | `Tuwa: Readiness for Lifters` (27) | `HRV, load, and today's lift` (27) | Narrows to lifting; drops the sport-skill half of the product. |

### Simplified Chinese

```
NAME      Tuwa - 准备度与训练负荷
SUBTITLE  读身体的信号，调今天的训练量
KEYWORDS  HRV,心率变异性,静息心率,睡眠,恢复评分,力量训练,健身记录,训练日志,ACWR,疲劳,过度训练,篮球,举铁,深蹲,卧推,自主训练,比赛日,减量,备赛,运动表现,健康数据
```

- Name 15/30 · Subtitle 14/30 · Keywords 87/100. CJK counts one character per glyph, so the
  Chinese fields have far more headroom than the English ones — spend it.
- The name now carries `准备度` (the one CN query Tuwa already appears in) and `训练负荷`.
- The subtitle deliberately avoids `训练` a second time and states the promise plainly.

Alternates:

| # | Name | Subtitle | Note |
|---|---|---|---|
| 1 | `Tuwa - 准备度与训练负荷` (15) | `读身体的信号，调今天的训练量` (14) | **Recommended.** |
| 2 | `Tuwa 准备度 - 训练负荷与恢复` (18) | `准备度决定今天的训练量` (11) | More tokens in the name; reads more like a feature list than a brand. |
| 3 | `Tuwa - 准备度与训练负荷` (15) | `今天该练多少，身体说了算` (12) | Warmer subtitle, slightly less precise. |

### Category

Currently Health & Fitness (primary) + Sports (secondary). **Keep.** Health & Fitness is
where every competitor sits and where the intent is; Sports is a cheap second surface.

---

## 4. What is deliberately NOT in the fields

- **`自律训练`** (zh) — collides with autogenic-training/relaxation apps. Wrong audience.
- **`AI`, `AI coach`, `教练`** — Tuwa is explicitly not a chat coach (`CLAUDE.md` Project).
  Ranking for it would bring traffic that churns on the first screen.
- **`Apple Watch`** — was in the old keyword field. Tuwa reads Apple Health, and works with
  any source that writes to it (Oura, Whoop, Garmin). Naming one wearable both narrows the
  claim and burns 11 characters.
- **`微剂量` / `microdose`** — signature vocabulary with near-zero search volume, and
  "microdose" has a strong off-topic meaning in English. It earns its place on a screenshot
  caption and in the description, not in the keyword field.
- **`strike zone`** — same reasoning: brand language, not a query.
- **Sleep-score-v2 vocabulary** — the engine is unshipped. See §6.

---

## 5. The basketball-forward alternative (not chosen, kept on file)

If the v2.1 beachhead is promoted out of the background and the ASO is meant to follow it:

```
NAME      Tuwa: Basketball & Lifting     (26/30)
SUBTITLE  Fresh for game day             (18/30)
NAME zh   Tuwa 篮球 - 力量与恢复            (16/30)
SUB  zh   为比赛日留住状态                  (8/30)
```

Cost of taking it: the two highest-weighted fields now compete in a query owned by
HomeCourt / Hoops AI / Ball AI (US) and 加练 / 开炼 / 篮迹 (CN), all of which do computer-vision
shot analysis or drill video. Expect impressions to rise and conversion to fall. It also
narrows the listing in front of the lifting-and-recovery audience, which is where the
product's actual differentiator lands.

Cheaper way to test the same hypothesis: leave the fields alone and run Apple Search Ads on
`basketball training`, `game day recovery`, `篮球 恢复`. If the click-through and install rate
justify it, promote the name on the following release.

---

## 6. Claim grading (§10 claim rails)

Every listing claim was checked against shipped code:

| Claim in the copy | Status | Evidence |
|---|---|---|
| Voice / typed / dictated logging into an editable draft | **Ships in 1.7.2** | `LogCaptureSheet`, `WorkoutVoiceLogService`, `parse-workout` `mode:"log"` — deployed and curl-verified 2026-08-18 |
| Free on every tier | **Ships** | `.planning/v172/SCOPE.md` Objective 0 |
| Go / modify / hold verdict with an adjusted number and a reason | **Ships** | `TodayVerdictEngine`, `VerdictReasonBuilder` |
| Match proximity → microdose | **Ships** | `TodayVerdictEngine`, `NextMatchSection` |
| Cross-modal carry drives the verdict (game → legs, spares bench) | **Ships, on by default** | `CrossModalShadowGate.crossModalDrivesVerdict == true`, shipped default since 2026-07-08 |
| Recovery score from HRV / RHR / sleep, own rolling baseline | **Ships** | `RecoveryScoreEngine`, `ReadinessFusionEngine` |
| ACWR + spike detection, one load curve across modalities | **Ships** | `WorkloadCalculator` |
| Sleep scored against a **fixed 7.5-hour** target | **Ships** | `RecoveryScoreEngine.sleepTargetHours`; the 7.5 h line is drawn in `SleepTrendChart` / `SleepDetailView` |
| 1,324-movement bank | **Ships** | `Resources/ExerciseCatalog.json` |
| Raw health data never leaves the device | **Ships** | HealthKit read-only, composite scores only in sync |
| **Context-conditional sleep score (sleep v2)** | **BUILT, BUT DARK** | see below |
| Forecasting / overreach prediction | **NOT SHIPPED** | out of scope, `SCOPE.md` |
| AI chat coach | **Never** | anti-positioning, `CLAUDE.md` |

**On sleep v2 — checked in source 2026-08-22, because the answer is not the obvious one.**

The engine **is built**. `WorkloadApp/Services/SleepScoreEngine.swift` is 662 lines: five
scored components (duration, continuity, regularity, deep, REM), an A–E tier ladder, and
seven night profiles (`BASELINE`, `HIGH_PRESSURE`, `HIGH_STRAIN_DAY`, `ACUTE_SHIFT`,
`CHRONIC_IRREGULAR`, `DEBT_CARRY`, `NAP_DAY`). `RecoveryPipeline.runSleepV2Shadow` calls
`SleepScoreEngine.compute` every night on real HealthKit data.

**And it is dark.** Its output goes into local-only `SleepShadowNight` rows and stops there:

- Nothing under `Views/`, `ViewModels/` or `Components/` reads `SleepShadowNight`. Grep is
  empty in all three.
- The live recovery score still comes from `RecoveryScoreEngine.compute`
  (`RecoveryPipeline.swift:144`), whose sleep term is the fixed 7.5-hour target
  (`RecoveryScoreEngine.sleepTargetHours`).
- The pipeline says so itself: *"The live recovery score is untouched — this is a shadow."*

So an athlete on 1.7.2 gets **nothing** from sleep v2. Describing it in the listing would
describe behaviour the binary does not have, which is the metadata-accuracy problem App
Review looks for — and this listing has already been rejected twice.

**Recommendation: keep it out**, and leave it on the website, where the Methodology section
already grades it correctly (`status: design · not in the shipping app`, `no performance or
accuracy claim is made here`). It becomes listing copy — and a strong What's New — in the
release that wires the shadow to the score. A graded, review-safe paragraph is parked in
`4b-optional-sleep-v2-block.md` for that day; it is not in the default description text.

**Medical language.** The old description said "not medical advice". The claim rails wording
is stronger and more accurate and is used instead: *"Tuwa is a training tool, not a medical
device. It does not diagnose, treat, or prevent injury."*

---

## 7. Fields that must not change

- **The EULA link stays in the description body.** The v1.6 submission was rejected on
  2026-07-25 for its absence. Both new descriptions end with it.
- `NSHealthUpdateUsageDescription` stays in `Info.plist`.
- The demo account (`2583710743@qq.com`) stays in the App Review notes.
- `https://haaanw.github.io/WorkloadManagementApp/{terms,privacy}.html` stays live — build 17's
  paywall still points there.
