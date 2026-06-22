---
title: v2.0 — Cross-Modal Fatigue Model, Plan-Input Data Model & MVP Measurement Framework
date: 2026-06-13
milestone: v2.0 "TODAY verdict" wedge
dimension: cross-modal fatigue + plan-input reuse + measurement instrumentation
status: research findings (no engine code written)
grounding: read of existing code (StrengthLoadEngine, LoadDistributionEngine, StrainRiskEngine, ReadinessFusionEngine, FatigueIndexEngine, PrescribedWorkout/WorkoutTemplate models, ShadowMetrics/ShadowAnalyticsService) + plan-aware thesis pressure-test + discovery corpus + interference-effect literature
---

# v2.0 Research: Cross-Modal Fatigue, Plan Input, Measurement

> **The headline:** The codebase is *much* further along than the brief assumed. The per-muscle strength substrate (`StrengthLoadEngine`), the unified one-budget daily-load series (`LoadDistributionEngine`), the two-channel Readiness + Strain-Risk fusion (`ReadinessFusionEngine` / `StrainRiskEngine`), the flagged session-level plan adjustment (`PRSDualRunSurface.adjust → PrescribedWorkout.targetRPE/targetVolume`), and the validation harness (`ShadowMetrics` with MAE/Spearman/calibration/blocked-CV) **already exist and build green**. The single thing that is genuinely missing — and is exactly the v2.0 differentiator — is a **directional cross-modal fatigue carry**: *yesterday's run/conditioning → today's squat (legs) but barely today's bench (chest)*. Nothing in the current code carries endurance/conditioning fatigue into a per-region penalty on a planned strength set. That is the build. Almost everything else is reuse.

---

## 0. What already exists (so v2.0 reuses, not rebuilds)

Verified by reading the files, not from docs:

| Capability | Where it lives today | Reuse verdict for v2.0 |
|---|---|---|
| Per-muscle hard-set / relative-intensity load, per-`MuscleGroup`, region rollup, est-1RM reference (Epley) | `StrengthLoadEngine.swift` (`perMuscleStrengthLoad`, `MuscleStrengthLoad`, `perRegion: [MuscleRegion: Double]`) | **REUSE as-is.** This is the per-region tissue substrate. It already buckets by `MuscleRegion` (legs/back/chest/shoulders/arms/core/fullBody). |
| One unified fatigue budget across strength + endurance (single real-unit daily series) | `LoadDistributionEngine.combinedDailyLoadSeries` (sRPE endurance + strength strain × `strengthSRPEEquivalentPerStrainUnit=5.0`) | **REUSE.** Already fuses modalities onto one scale. But it is **whole-body / un-regionalized** — that's the gap. |
| Endurance internal load (sRPE), TSS, TRIMP, spike detection, EWMA ATL/CTL | `WorkloadCalculator.swift` | **REUSE.** sRPE is the cross-modal common currency (Foster). |
| 26-muscle + 7-region anatomical taxonomy with exhaustive `MuscleGroup.region` map | `Enums.swift` (`MuscleGroup`, `MuscleRegion`) | **REUSE.** The region map is the lookup the cross-modal kernel needs. |
| Two-channel output: Readiness (systemic recovery) + Strain-Risk (accumulated load-tolerance) | `ReadinessFusionEngine` (logistic, glass-box, sign-locked) + `StrainRiskEngine` (fixed-weight glass-box) | **REUSE.** Cross-modal carry becomes a NEW input/factor, not a new channel. |
| Whole-body fatigue composite (FEA lineage: load elevation, density, recovery trend, rest debt, wellness, soft-tissue) | `FatigueIndexEngine.FatigueResult` | **REUSE as systemic input.** Confirmed via grep: it has **zero** `muscleGroup`/`region`/`CNS`/`peripheral` awareness — it is purely systemic. |
| Flagged adjustment of a real planned workout: cap RPE downward, scale volume | `PRSDualRunSurface.adjust(prescribedWorkout:)` → mutates `PrescribedWorkout.targetRPE` / `targetVolume` (already additive fields, local-only, not synced) | **REUSE + extend.** Today it caps one whole-session RPE; v2.0 needs the adjustment to be **per-exercise/per-region**. |
| Plan structure: template → groups → exercises → sets, with target weight/reps/RPE/RIR, deep-copy snapshot | `WorkoutTemplate → ExerciseGroup → TemplateExercise → TemplateSet`; `PrescribedWorkout` reuses the same `ExerciseGroup` graph with a denormalized frozen snapshot | **REUSE.** This is the plan-input object. No new graph needed (see §2). |
| Validation machinery: per-arm MAE, paired-MAE-difference CI, Spearman ρ, calibration slope, blocked/purged CV, graceful nil-on-insufficient | `ShadowMetrics.swift` + `ShadowAnalyticsService` (already has a `prsMAE` arm slot) | **REUSE.** The differing-verdict / behavior measurement layers onto this. |
| Outcome labels already plumbed | `ShadowPredictor.Outcome`: `recovery`, `wellness`, `completion` (reframed adherence), `pain` (`WellnessCheckIn.soreness` 1-5), `niggleSeverity` (`SorenessLog` 0-10) | **REUSE.** The MVP-measurement events extend this, not replace it. |
| Self-logged soreness/pain/tweak by region | `SorenessLog` (region, type, severity, `limitedTraining`) | **REUSE.** Feeds both cross-modal recurrence AND the post-session ground-truth label. |

**Implication:** v2.0 is a *small, surgical* engine addition (the cross-modal kernel) + a UI surface (per-set verdict) + a measurement layer (events/WTP). It is NOT a rebuild of load tracking, readiness, or plan modeling.

---

## 1. CROSS-MODAL FATIGUE MODEL

### 1.1 The job, precisely

> Yesterday's hard run (or conditioning) should knock a meaningful chunk off **today's squat top set** (legs), a smaller chunk off today's deadlift (legs/back), and **near-zero off today's bench** (chest). A whole-body penalty (what Garmin/Whoop do, and what `FatigueIndexEngine` does today) cannot express this. The differentiator is **directional, region-resolved carry-over**, not a scalar readiness number.

This is the **revealed-preference** product spec, stated almost verbatim by the reference user's online twins:

- HybridLoad / Inevitable_Brick_221: *"A run hits your squat hard but barely affects your bench... Linear penalty stacking (-10% run, -15% combat) is too aggressive and ignores CNS vs local fatigue."* The tool varies the penalty **per lift** via an **anchor + diminishing modifier**, explicitly NOT linear stacking. ([source](https://reddit.com/r/HybridAthlete/comments/1roi0kr/i_got_tired_of_guessing_how_much_to_take_off_the/)) — HIGH confidence (the literal product behavior we are matching).
- GreenInvestigator817: *"Garmin says Recovered but my CNS and legs are absolutely fried from a heavy deadlift 48h ago."* ([source](https://www.reddit.com/r/Garmin/comments/1tfuujo/prepping_for_a_heavy_squat_block_this_is_how_my/)) — HIGH confidence the *legs-specific residual* is the felt gap.

### 1.2 The systemic vs local split (the physiological backbone)

Two fatigue channels, accumulated separately, combined per-exercise:

| Channel | What it is | What carries it (existing code) | Decays over |
|---|---|---|---|
| **Systemic / central** | Whole-body autonomic + central fatigue: glycogen, CNS drive, sleep debt. Affects *everything*, modestly. | `ReadinessFusionEngine` (HRV/RHR/sleep z) + `FatigueIndexEngine` whole-body composite + total sRPE load | Days; tracked by existing baselines |
| **Local / peripheral (per-region)** | Tissue-specific damage + neuromuscular fatigue in the muscles that did the work. Running ⇒ **legs**; rowing/ski-erg ⇒ legs + back/lats; bench/press ⇒ chest/shoulders/triceps. | `StrengthLoadEngine.perRegion` already does this *for strength*. **Missing: a region attribution for endurance/conditioning sessions.** | 24-72h, region-specific |

**Science anchor (MODERATE-HIGH confidence).** The concurrent-training **interference effect** is overwhelmingly a **lower-body** phenomenon: running/cycling attenuates *lower-body* dynamic strength and power (CMJ force/power) while upper-body strength is largely spared, and residual fatigue from the endurance bout is the acute mechanism (resistance-before-endurance sequencing protects lower-body strength). This is *exactly* the run→squat-not-bench asymmetry, and it is literature-backed, not just forum lore.
- [Compatibility of Concurrent Aerobic and Strength Training (meta-analysis), Sports Medicine 2021](https://link.springer.com/article/10.1007/s40279-021-01587-7)
- [Endurance Training Intensity Does Not Mediate Interference to Maximal Lower-Body Strength (Frontiers/PMC)](https://pmc.ncbi.nlm.nih.gov/articles/PMC5093324/)
- [Intra-session exercise sequence in the interference effect (meta-analysis, PMC)](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5752732/)
- [Barbell Medicine, interference effect review](https://www.barbellmedicine.com/blog/concurrent-training-and-the-interference-effect/)

> **Honesty flag.** The literature establishes *direction and region* (run interferes with legs, spares upper body) at HIGH confidence. It does **NOT** give a defensible *magnitude* ("a 10km run = −7.5% on today's squat top set"). The specific percentages are a **heuristic**, anchor-and-modifier shaped, to be tuned in shadow mode against the user's own outcomes — never shipped as a precise scientific claim. This matches the project's standing posture: evidence-anchored prior, then calibrate (`algorithm-moat-design.md`).

### 1.3 The defensible v1 formula (anchor + diminishing modifier — NOT linear stacking)

Per planned exercise *e* with primary region *r(e)*, compute a **carry-over fatigue load** `CF_r` for that region from the last N days (N≈3, region-specific decay), then map it through a **saturating (diminishing-returns) modifier** to a per-exercise adjustment. This is `StrengthLoadEngine`'s `elevation` philosophy (deadband + saturating clamp) generalized to cross-modal carry.

**Step 1 — Regionalize endurance/conditioning sessions (the one genuinely new primitive).**
Map each non-strength session to the region(s) it loads, with a coefficient:

```
runningLoad      → legs    (β ≈ 1.0)             [+ minor systemic]
cycling          → legs    (β ≈ 0.7; less eccentric tissue damage than running)
rowing / ski-erg → legs    (β ≈ 0.6) + back/lats (β ≈ 0.5)
swimming         → back/shoulders (β ≈ 0.6)      [low systemic, low legs]
teamSport / HYROX/ CrossFit (mixed) → fullBody-distributed by a default profile
```
Source of the session's modality = existing `WorkoutSession.sportType` + `SessionType`. Source of its magnitude = existing `WorkloadCalculator.srpeLoad` (minutes × sessionRPE) — already computed and stored on every session. **No new logging burden on the user.** Where a strength session contributes, its per-region tissue load is already `StrengthLoadEngine.perRegion[r]`. So:

```
CF_r(today) = Σ_sessions_in_window  ( srpeLoad(session) · β_region(session, r) · decay(Δdays) )
            + StrengthLoadEngine.perRegion[r]  over the same window
```
`decay(Δdays) = exp(−Δdays / τ_r)`, τ tuned per region (legs recover slower from eccentric running damage than chest from pressing; start τ_legs ≈ 2.0d, τ_upper ≈ 1.5d as priors).

**Step 2 — Normalize against the athlete's own region baseline.** Reuse the acute-vs-chronic *elevation* shape already in `StrengthLoadEngine.perMuscleElevation` (deadband 0.20, saturating clamp 0…1) so a person who *always* runs hard before squats isn't perpetually penalized — only an **above-personal-normal** regional carry counts. This is the moat: personal, not population.

**Step 3 — Anchor + diminishing modifier (the anti-linear-stacking core).** Convert the 0…1 regional elevation `E_r` into a per-exercise intensity/volume nudge through a **concave** map so two stacked stressors do not double-penalize:

```
regionPenalty_r = maxPenalty · (1 − exp(−k · E_r))      // saturating; concave; bounded
```
- `maxPenalty` caps the worst case (e.g. legs top-set down ~10%, i.e. ~0.5–1.0 RPE / ~1 RIR), so a verdict is never catastrophic (nocebo guard, §3).
- The `1 − exp(−k·E)` form means the **first** unit of carry-over costs the most and additional carry-over has **diminishing** effect — which is precisely HybridLoad's stated complaint that linear `−10% −15%` stacking is "way too aggressive." HIGH confidence this matches the demanded behavior.

**Step 4 — Combine systemic + local per exercise (multiplicative attenuation, not additive).**
```
exerciseAdjustment(e) = systemicFactor · (1 − regionPenalty_{r(e)})
```
where `systemicFactor ∈ [~0.85, 1.0]` derives from the existing Readiness scalar (low readiness ⇒ small global haircut on everything). Bench on a fried-legs day: `r(e)=chest`, `E_chest≈0` ⇒ `regionPenalty≈0` ⇒ only the mild systemic factor applies (≈ −0–5%). Squat: `r(e)=legs`, `E_legs` high ⇒ meaningful `regionPenalty` (≈ −10%) **on top of** the same systemic factor. **This is the run-hits-squat-not-bench behavior, falling straight out of the region kernel.**

**Step 5 — Emit the verdict per planned set** (see §2 for attachment): adjusted target weight (back-solved from est-1RM and the RPE/RIR shift), or an RPE-cap + volume nudge, plus a one-line "why" string from the dominant factor ("Yesterday's 10 km run is still loading your legs — squat top set trimmed ~7%; bench unaffected").

### 1.4 Why this is defensible and not naive

- **Anti-linear-stacking** by construction (concave saturating modifier) — directly answers the one technical critique the actual competitor (HybridLoad) raised.
- **Region-resolved**, which is what neither Garmin (whole-body "Recovery"), Whoop, nor `FatigueIndexEngine` does today. Garmin's *unshipped* 2026 "Neuromuscular Readiness" is the only thing approaching it — move before it ships (commoditization clock, pressure-test §61).
- **Personal baselines** (elevation vs own normal) — the compounding asset that can't be copied from a spec.
- **Glass-box & decomposable** — every penalty traces to (region, source session, days-ago, elevation), feeding the existing `ReasoningEngine` factor pattern. Non-negotiable per the moat design.

### 1.5 Where the evidence is thin (call it out honestly in-product)

| Claim | Confidence | Note |
|---|---|---|
| Run interferes with legs, spares bench (direction + region) | HIGH | Interference-effect meta-analyses. |
| Magnitude of per-set penalty (the %) | LOW — heuristic | Tune in shadow mode; never present as precise science. |
| Region β coefficients for mixed modalities (HYROX, CrossFit) | LOW — heuristic | Start with a default distributed profile; refine. |
| τ (region decay) values | LOW — heuristic | Priors only; calibrate against next-day soreness by region. |
| Cycling < running for leg tissue damage | MODERATE | Eccentric load argument; defensible prior. |

---

## 2. PLAN-INPUT DATA MODEL (minimal, additive, no migration pain)

### 2.1 The plan object already exists — reuse `PrescribedWorkout`

The brief asked for "today's planned session reusing WorkoutTemplate/TemplateExercise/TemplateSet (+ today-entry)." That object is **already modeled**: `PrescribedWorkout` *is* a frozen, per-day instance of a template's `ExerciseGroup → TemplateExercise → TemplateSet` graph (it shares the exact same `ExerciseGroup` relationship via the `prescription` inverse). It already carries:
- the frozen exercise/set graph (`groups`, `allExercises`),
- `templateId` (nil ⇒ one-off / manual today-entry — the "manual today-entry" path the brief wants),
- `scheduledDate`, `status`, `completedSessionId` (links plan → actual session),
- **`targetRPE` / `targetVolume`** additive fields *already added* for the PRS adjustment, local-only, **not in the sync payload**.

`TemplateSet` already holds the per-set targets the verdict adjusts: `targetReps`, `targetWeightKg`, `targetRPE`, `targetRIR`, `isWarmup`. **The plan-input graph needs no new model.**

### 2.2 How the verdict attaches to a planned set (target → adjusted)

Today `PRSDualRunSurface.adjust` writes ONE session-level `targetRPE`/`targetVolume` onto the `PrescribedWorkout`. v2.0's cross-modal verdict is **per-exercise** (legs vs chest differ within the same session), so the attachment must move down one level — to the **exercise** (sufficient for v1; per-set is overkill since region is constant within an exercise).

**Smallest additive schema change (no migration):** add nullable adjusted-target fields to `TemplateSet` (the set is where targets live, and `PrescribedWorkout`'s frozen `TemplateSet`s are per-prescription copies, so writing them does NOT touch the source template):

```swift
// TemplateSet — ALL nullable, default nil ⇒ additive, no SwiftData migration,
// no sync change (TemplateSet is part of the local groups_json graph, not a synced @Model).
var adjustedTargetWeightKg: Double?   // verdict's suggested weight (nil = unadjusted)
var adjustedTargetRPE: Double?        // verdict's RPE cap for this set's exercise
var verdictReason: String?            // one-line "why" (e.g. "legs loaded from yesterday's run")
var verdictAppliedAt: Date?           // when the cross-modal verdict was computed
var athleteOverrode: Bool             // true once the athlete confirms/edits — MEASUREMENT gold (§3)
```

Rationale this is migration-safe (matches the project's proven D-01/D-03 pattern of additive nullable fields, e.g. `PrescribedWorkout.targetRPE`, `WorkoutTemplate.isAthleteOwned`):
- **Nullable + default** ⇒ existing SwiftData rows decode unchanged (lightweight migration is automatic/no-op).
- `TemplateSet` is persisted inside the local `groups_json`/relationship graph; it is **not** an independently synced `@Model` in `SyncService`'s mapping (same as `PrescribedWorkout.targetRPE` — explicitly "not part of the synced payload"). So **zero backend/RLS change**, consistent with "composite-only sync, no raw data."
- Writing adjusted fields onto the **prescription's frozen copy** never mutates the source `WorkoutTemplate` — authorship is preserved (the "never writes the program" constraint, §3 autonomy).

**Flow:**
1. Athlete picks today's template (or one-off) → existing assignment creates a `PrescribedWorkout` with a deep-copied set graph (existing `deepCopyGroups()`).
2. Cross-modal engine (§1) computes per-exercise `exerciseAdjustment` → writes `adjustedTargetWeightKg` / `adjustedTargetRPE` / `verdictReason` onto each working `TemplateSet` of that prescription. Original `targetWeightKg`/`targetRPE` are **untouched** (the verdict is shown *beside* the plan, never overwriting it — suggest-and-confirm).
3. UI renders plan target struck-through-or-paired with the suggestion + reason; athlete confirms or edits → sets `athleteOverrode`.
4. On logging, the actual `SetRecord` already links via `completedSessionId`; the plan↔actual pairing for measurement is free.

### 2.3 The verdict gate stays OFF by default (consistency with PRSActivation)
Keep the whole cross-modal write path behind the existing `PRSActivation.isEnabled` flag discipline so it ships dark, shadow-logs first, and flips only after the gates clear (§3) — identical to how `PRSDualRunSurface` is fenced today.

---

## 3. MVP MEASUREMENT FRAMEWORK (instrument BEFORE launch — the founder's playbook gap)

> The pressure-test's single biggest open risk is **WTP**, and its single green-light signal is behavioral: *on a differing-verdict day the athlete acts on it and afterward says it was right.* You cannot retrofit that — the events must be logged from day one. The good news: `ShadowMetrics` + `ShadowAnalyticsService` already give MAE / Spearman / calibration / blocked-CV with graceful nil. The MVP layer adds **behavioral + WTP events**, not new statistics.

### 3.1 The core construct: the **differing-verdict day**

Define, per planned session, a `VerdictEvent` (local SwiftData model, composite-only, never raw HealthKit):

```swift
@Model final class VerdictEvent {       // local-first; sync composite fields only
  var id: UUID
  var date: Date
  var prescribedWorkoutId: UUID
  var dominantRegion: String            // e.g. "legs"
  var crossModalSource: String?         // e.g. "running 10km yesterday" (composite label, not raw HK)
  // The two calls being compared:
  var athletePreVerdictPlan: Double     // what they'd have done (plan target weight/RPE), captured BEFORE reveal
  var engineSuggested: Double           // adjusted target
  var differed: Bool                    // |engine − plan| past a meaningful threshold
  // Behavior:
  var actedOnVerdict: Bool?             // did the logged session match the suggestion vs the plan?
  var overrodeVerdict: Bool?            // confirmed-as-is vs edited away
  // Post-session ground truth (next day / end of session):
  var postSessionRightCall: Int?        // self-report: -1 wrong / 0 neutral / +1 "it was right" (the green-light)
  var postSessionNote: String?          // optional verbatim ("I'd have gone too heavy")
}
```

The **green-light signal** = rows where `differed == true && actedOnVerdict == true && postSessionRightCall == +1`. Track the **rate of green-light rows among differing-verdict days** as the north-star validation metric. Agreement-only days (`differed == false`) are the *yellow* flag ("told me what I knew"); `differed == true && actedOnVerdict == false` is the *red* flag (verdict ignored). This is the pressure-test's exact rubric (§92), made into a logged metric.

### 3.2 Events to log locally (minimum viable instrumentation)

| Event | Fields | Why it matters |
|---|---|---|
| `verdict_shown` | date, region, differed, magnitude, crossModalSource | denominator for differing-verdict rate |
| `pre_verdict_intent` | what athlete planned (capture BEFORE reveal, or infer from plan target) | the comparison baseline; without it you can't prove the engine *changed* behavior |
| `verdict_acted` | matched suggestion / matched plan / went own way | behavior, not opinion |
| `verdict_confirmed` vs `verdict_overridden` | autonomy signal | tests the suggest-and-confirm crack (§autonomy) |
| `post_session_rightcall` | -1/0/+1 + optional note | THE green-light; the only place the engine earns its keep |
| `session_logged` | links plan↔actual (already exists via `completedSessionId`) | free ground truth |
| `region_soreness_next_day` | from existing `SorenessLog` by region | did the cross-modal prediction match felt next-day soreness? validates the region kernel |
| `nocebo_check` | low-verdict shown → session abandoned early | guards the pre-session "hold poisons the session" landmine (pressure-test §38) |

All of these resolve into the **existing** `ShadowPredictor.Outcome` set (`pain`, `niggleSeverity`, `completion`, `recovery`, `wellness`) for the statistical arm via `ShadowAnalyticsService`. The cross-modal engine becomes a new prediction **arm** (slot already exists: `prsMAE`), validated with the already-built `ShadowMetrics` (paired-MAE CI, Spearman ρ, calibration slope, blocked CV).

### 3.3 Activation / North-star / retention metrics

| Metric | Definition (concrete) | Target / gate |
|---|---|---|
| **Activation** | New user reaches first **differing-verdict day acted upon** within first 7 days (not just "opened app") | ≥40% of new users hit it (instrument; no hard launch gate, it's the funnel) |
| **Sean Ellis 40% test** | In-app survey after ≥2 weeks: "How would you feel if you could no longer use Tuwa's daily verdict?" — % answering "very disappointed" | ≥40% "very disappointed" = PMF signal. Trigger survey at the activation moment, not on install. |
| **Day-7 retention** | % of users who open + view a verdict on day 7 | Track cohort curve; the pressure-test warns fitness-app churn is ~9.2%/mo, so set internal floor honestly (e.g. D7 ≥ 35%). |
| **Day-30 retention** | % still viewing verdicts at day 30 | The real WTP proxy; the "score I don't act on" churn case ([Anna C](https://www.strongfirst.com/community/threads/returning-my-whoop-band-change-my-mind.23898/)) is what kills here. |
| **Differing-verdict rate** | differing days / total verdict days | Must be **non-trivial** (>20% per the kill-test §129). If the engine agrees with the athlete ~always, it's redundant noise — a *kill* signal, not a success. |
| **Green-light rate** | green-light rows / differing-verdict days | The engine "earns its keep" only here. This is the metric to obsess over. |
| **Override-toward-plan rate** | differing days where athlete reverted to their own number | Autonomy health; a very high rate means the verdict feels like a demotion (re-frame, don't gate). |
| **Engine-beats-feel** | on differing days, whose call matched post-session ground truth (catch the "felt fine, gassed after 2 sets" + "felt dead, PR'd" cases) | The defensibility proof vs free feel. |

### 3.4 WTP signal capture (the genuine soft spot — capture revealed > stated)

The corpus is emphatic: stated WTP from this segment is the least trustworthy data point; the buyer's default is build-not-buy. So capture **revealed** signals and **behavior-anchored** prompts, not "would you pay?":

- **Hard paywall pre-sale / card-on-file** is the only trustworthy test (pressure-test recommends a real Stripe/RevenueCat pre-order, not an email field). RevenueCat is already integrated — gate the verdict behind a trial→paid and measure trial→paid conversion at a real price ($9.99/mo or $79/yr per the kill-test anchors). **≥40% trial→paid into a paid month** is the survival bar from the kill-test (§148).
- **Behavior-anchored in-app prompt** *after* a green-light day only: "You acted on a verdict that changed your session and said it was right. [Keep Tuwa Pro]" — measure tap-through, not a hypothetical.
- **Churn-reason capture** on cancel: free-text + the existing churn triggers ("score I don't act on", "built my own", "too much logging").
- **Differing-verdict × retention correlation:** do users with more green-light days retain/convert better? If yes, the engine is the value; if not, WTP is decoupled from the verdict and the thesis is in trouble. This is the single most important analysis to run.

### 3.5 Privacy posture (non-negotiable, already enforced)
Every event above is **composite/derived** (region labels, verdict deltas, RPE numbers, self-report integers) — **no raw HealthKit** (HRV/RHR/sleep values) ever syncs. `crossModalSource` is a human label ("10km run yesterday"), not a sample. This matches the standing constraint and the local-only pattern of `SorenessLog` / `MenstrualCycleSnapshot` / `CyclePredictionLog`.

### 3.6 The honest nocebo / autonomy guardrails (product constraints that shape measurement)
- Verdict is **suggest-and-confirm**, number+reason, feel-overridable — never a red "don't train" gate (hard constraint from the redefinition; nocebo landmine from pressure-test §38). The `athleteOverrode` field exists precisely so an override is a *first-class, friction-free, logged* action, not a fight.
- Frame the pre-session verdict as an *adjusted number* ("squat top set ~7% lighter"), not a verdict on the *person* ("you're not recovered").

---

## 4. Roadmap implications (phase ordering for the wedge)

1. **Phase A — Cross-modal kernel (engine, dark/shadow).** New pure struct `CrossModalFatigueEngine` (region attribution of endurance/conditioning sessions + anchor/diminishing modifier + per-exercise combine), reusing `StrengthLoadEngine.perRegion`, `WorkloadCalculator.srpeLoad`, `MuscleGroup.region`, and the elevation/deadband shape. Behind `PRSActivation`. Shadow-logs as a new prediction arm. *Avoids:* the whole-body blindness of `FatigueIndexEngine`.
2. **Phase B — Plan-input attachment + per-exercise verdict surface.** Additive nullable `TemplateSet` fields (§2.2); extend `PRSDualRunSurface.adjust` to write per-exercise; suggest-and-confirm UI beside the plan. *Avoids:* migration pain (additive nullable), authorship violation (write the prescription copy, never the template), nocebo (number+reason framing).
3. **Phase C — Measurement instrumentation (MUST precede public launch).** `VerdictEvent` model + event logging + green-light/differing-verdict/WTP capture, wired into existing `ShadowMetrics`/`ShadowAnalyticsService` and RevenueCat. *This is the founder's playbook gap — it is a prerequisite, not a follow-up.*
4. **Phase D — Validate before scale.** Run the engine-beats-feel + green-light-rate + trial→paid analyses on the first cohort; only then decide mid/long horizons. Per the pressure-test: **do NOT build mid/long until WTP clears.**

**Research flags:**
- Phase A magnitude/τ/β tuning: needs shadow data — flagged LOW-confidence, heuristic until calibrated.
- Phase C WTP: the genuine open risk; over-instrument here.
- Mixed-modality (HYROX/CrossFit) region attribution: thin evidence, default profile + later refinement.

---

## 5. Confidence summary

| Area | Confidence | Basis |
|---|---|---|
| Existing code can be reused (per-muscle, unified load, two-channel, plan model, harness) | HIGH | Direct file reads, verified grep (FatigueIndex has no region awareness) |
| Cross-modal *direction* (run→legs not chest) | HIGH | Interference-effect meta-analyses + revealed user behavior (HybridLoad) |
| Cross-modal *magnitude* (the %) | LOW (heuristic) | No literature gives per-set numbers; shadow-calibrate |
| Plan-input reuse + additive schema (no migration) | HIGH | `PrescribedWorkout`/`TemplateSet` already carry targets + proven additive-nullable pattern |
| Measurement framework maps onto existing harness | HIGH | `ShadowMetrics`/`ShadowAnalyticsService`/`Outcome` already present, `prsMAE` slot exists |
| WTP measurement design | MEDIUM | Method is sound (card-on-file, behavior-anchored); the *outcome* is the real unknown |
