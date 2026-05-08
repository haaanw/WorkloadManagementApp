# Female Athlete Optimization Research

**Date:** 2026-05-02
**Purpose:** Evidence base for adapting Tonus algorithms to female physiology
**Status:** Research complete, pending implementation planning

---

## Table of Contents

1. [The Male Bias Problem in Sports Science](#1-the-male-bias-problem-in-sports-science)
2. [Menstrual Cycle Phases and Training Response](#2-menstrual-cycle-phases-and-training-response)
3. [Sex Differences in Recovery Metrics](#3-sex-differences-in-recovery-metrics)
4. [Sex Differences in Training Load and Injury Risk](#4-sex-differences-in-training-load-and-injury-risk)
5. [Apple HealthKit Menstrual Data Availability](#5-apple-healthkit-menstrual-data-availability)
6. [Female-Specific Training Methodologies](#6-female-specific-training-methodologies)
7. [Industry Landscape: Competitor Analysis](#7-industry-landscape-competitor-analysis)
8. [Key Uncertainties and Research Gaps](#8-key-uncertainties-and-research-gaps)
9. [Implications for Tonus](#9-implications-for-tonus)
10. [Sources](#10-sources)

---

## 1. The Male Bias Problem in Sports Science

### Scale of the Problem

The data disparity in sports science is severe and well-documented:

- **Only 6-9% of sports science studies focus exclusively on female athletes.** Studies focused exclusively on male athletes/sports account for over 70%, mixed-gender studies ~20%, and female-only studies under 9% (Costello et al., 2014; Cowley et al., 2021).
- When women are included, they remain underrepresented: **women account for only ~35% of participants** in mixed studies. A review of 500+ studies (~25,000 participants) found 64% male vs 36% female participants, with 32% male-only populations vs 12% female-only (Cowley et al., 2021).
- Research reviewers are **more likely to recommend studies focused on men** for publication (Journal of Women's Health, 2021).
- Female leadership in scientific publications remains below 30%, perpetuating the research focus bias.

### Why Women Are Excluded

1. **Perceived complexity:** Hormonal cycle variation is seen as a confounding variable rather than a variable worth studying.
2. **Structural barriers:** More male researchers and coaches in sport science.
3. **Cost:** Controlling for menstrual cycle phase increases study duration and cost.
4. **Historical inertia:** Decades of male-derived norms are treated as universal.

### Consequence for Tonus

Every algorithm in Tonus (RecoveryScoreEngine, WorkloadCalculator, AutoregulationEngine, FatigueIndexEngine, ProgressionEngine) was built on literature derived predominantly from male subjects. The 7-day rolling baseline, ACWR thresholds, EWMA decay constants, recovery zone boundaries, and fatigue weights all reflect male-normative physiology. Female users are being evaluated against standards that may systematically misrepresent their true physiological state.

---

## 2. Menstrual Cycle Phases and Training Response

### 2.1 Hormonal Phases Overview

A typical eumenorrheic (naturally cycling) woman has a ~28-day cycle (range: 21-35 days), divided into:

| Phase | Days (approx.) | Estrogen | Progesterone | Key Characteristics |
|---|---|---|---|---|
| **Early Follicular** (Menstruation) | 1-5 | Low | Low | Both hormones at nadir. Period symptoms may impair perceived readiness. |
| **Late Follicular** | 6-13 | Rising to peak | Low | Estrogen peaks ~day 12. Favorable anabolic environment. |
| **Ovulation** | ~Day 14 | Peak then drops | Starting to rise | LH surge triggers ovulation. Brief estrogen spike. |
| **Early Luteal** | 15-21 | Moderate | Rising | Progesterone rising. Thermoregulatory shift begins. |
| **Late Luteal** | 22-28 | Declining | Peak then declining | Both hormones decline. PMS symptoms. Core temp elevated. |

### 2.2 Impact on Key Biometrics

#### Heart Rate Variability (HRV / RMSSD)

- **Follicular phase: Higher HRV** (greater parasympathetic activity). Population RMSSD peaks around cycle day 5 (Springer Living Systematic Review, 2025).
- **Luteal phase: Lower HRV** (sympathetic dominance). RMSSD reaches minimum around cycle day 27. Decreased HRV observed 4-11 days after ovulation (TrainingPeaks, 2019 study).
- **Magnitude:** Varies by individual; typical within-person variation is meaningful enough to affect recovery score classification but not consistent enough for blanket rules.
- **Critical finding from Marco Altini (HRV4Training creator):** "Group-level changes in a parameter don't always translate into useful individual-level information." Apps that "assume each individual functions exactly like the average of the group" produce misleading guidance.
- **Contraceptive users:** Hormonal contraceptives flatten the natural HRV cycle by suppressing endogenous hormone fluctuations. HRV patterns differ significantly between naturally cycling women and OC users (Springer 2025 systematic review).

#### Resting Heart Rate (RHR)

- **Follicular phase: Lower RHR** (by approximately 2-5 bpm compared to luteal).
- **Luteal phase: Higher RHR** (progesterone increases sympathetic tone). Typical increase of 2-5 bpm, though individual variation ranges from negligible to 10 bpm.
- **Population data:** RHR minimum around cycle day 5, maximum around cycle day 26 (bioRxiv 2025, large-scale wearable study of 2,596 women across 42,759 cycles).
- **Cycle length matters:** Longer cycles show greater variability in cardiorespiratory metrics across the cycle.

#### Body Temperature

- **Follicular phase: Lower core and wrist temperature.**
- **Post-ovulation: Biphasic temperature shift.** Progesterone raises core body temperature by approximately 0.3-0.5 degrees C, persisting throughout the luteal phase.
- **Apple Watch detects this:** Wrist temperature deviation during sleep correlates with ovulation (Apple algorithms validated in Human Reproduction, 2025).
- **Training implication:** Elevated core temp in luteal phase impairs thermoregulation, reducing endurance capacity in heat.

#### Sleep Quality

- **Luteal phase: More sleep disruption.** Elevated progesterone has sedative effects but is offset by higher core temperature and physical discomfort.
- **Menstrual phase: More sleep arousals.** Female athletes with poor subjective sleep quality show significantly more sleep arousals during menses (PMC 2024).
- **Key finding:** Menstrual cycle symptoms (not hormone concentrations per se) have a greater association with poorer objective sleep outcomes (Pearson et al., 2025, European Journal of Sport Science).
- **Estrogen's dual role:** Promotes sleep through serotonergic regulation but may increase REM sleep fragmentation.

#### Perceived Exertion (RPE)

- **Early follicular:** RPE may be elevated relative to actual physiological load due to period symptoms (pain, fatigue, mood).
- **Late follicular:** RPE may be lower for equivalent work (higher pain threshold, better mood, lower perceived effort).
- **Luteal phase:** RPE tends to increase for equivalent work, particularly in endurance tasks, potentially due to thermoregulatory strain and progesterone-mediated ventilatory changes.

### 2.3 Impact on Exercise Performance

Based on the most rigorous systematic reviews (Frontiers in Endocrinology 2025 narrative review; Sports Medicine 2020 meta-analysis):

| Domain | Follicular Phase | Luteal Phase | Evidence Strength |
|---|---|---|---|
| **Aerobic / Endurance** | Higher capacity | Reduced (thermoregulation, substrate shifts) | Moderate |
| **Maximal Strength** | Possibly higher (late follicular peak) | Poorest | Moderate (medium effect size for isometric) |
| **Anaerobic Power** | Stable | Stable | Strong (mostly unaffected) |
| **Sprint/Power** | No significant difference | No significant difference | Moderate |
| **Flexibility** | Insufficient data | Insufficient data | Weak |

**Important caveat:** The Frontiers in Sports and Active Living (2023) review concluded "current evidence shows no influence of women's menstrual cycle phase on acute strength performance or adaptations to resistance exercise training," calling many positive findings into question due to methodological shortcomings (inaccurate phase detection, small samples).

### 2.4 Phase-Based Training Evidence

- **Follicular-emphasized strength training** showed higher gains in muscle strength and muscle diameter than luteal-phase training in one landmark study (Sung et al., 2014, PMID: 25485203).
- However, a 2023 Strength & Conditioning Journal review concluded "research does not support the idea that periodizing strength or endurance training according to the menstrual cycle confers additional benefits over traditional approaches."
- The IMPACT study (clinical trial, BMC Trials 2024) is an ongoing RCT specifically designed to test menstrual cycle-based periodized training on aerobic performance with proper methodology.

**Bottom line:** The evidence is suggestive but not definitive. The strongest case is for using cycle data as contextual information alongside readiness metrics, not as a deterministic training scheduler.

---

## 3. Sex Differences in Recovery Metrics

### 3.1 HRV Distribution Differences

- Female athletes show **greater pNN50 and HF (high frequency) power** than male athletes, indicating higher resting parasympathetic tone.
- Male athletes show **greater LF (low frequency) power and LF/HF ratio**.
- **Absolute RMSSD values tend to be lower in females** at population level, but this is confounded by body size, cardiac chamber dimensions, and fitness level.
- The menstrual cycle introduces **additional within-subject variability** in female HRV measurements that does not exist in males. Uncontrolled phase variation increases LnRMSSD coefficient of variation in females.

### 3.2 RHR Baseline Differences

- Females generally have slightly higher resting heart rates than males at equivalent fitness levels (smaller heart volume, lower stroke volume).
- **The cyclical RHR variation (2-5+ bpm across the cycle) can cause a 7-day rolling baseline to be systematically biased** depending on where in the cycle the window falls. A baseline window entirely in the follicular phase will be lower than one in the luteal phase, causing misclassification of recovery state.

### 3.3 Sleep Architecture Differences

- Females report more sleep disturbances across the lifespan, with menstrual cycle as a major modulator.
- **Progesterone** exerts sedative effects but also raises core body temperature, disrupting sleep maintenance.
- **Estrogen** promotes sleep through serotonin pathways but may fragment REM sleep.
- Female athletes may experience a **sleep quality penalty in the late luteal phase** that is not pathological but is mistakenly flagged by algorithms as indicating poor recovery.
- Sleep arousals increase during menstruation, particularly in athletes with poor subjective sleep quality.

### 3.4 How the Current 7-Day Rolling Baseline Disadvantages Female Athletes

Tonus currently uses a **7-day rolling average for HRV and RHR baselines** (RecoveryScoreEngine). This approach has a fundamental problem for eumenorrheic women:

1. **Phase contamination:** A 7-day window captures at most one-quarter of the cycle. If the window falls entirely in the luteal phase (lower HRV, higher RHR), the baseline will be depressed. A subsequent day in the follicular phase will appear artificially "recovered" relative to this depressed baseline, and vice versa.

2. **False positives/negatives:** A woman transitioning from follicular to luteal phase will show declining HRV and rising RHR that the algorithm interprets as declining recovery, when it may simply be normal hormonal variation.

3. **Masking real signals:** Genuine training fatigue may be masked when it coincides with the expected luteal-phase HRV suppression, or exaggerated when it occurs during the follicular phase.

4. **Contraceptive users affected differently:** Women on hormonal contraceptives have flattened cycles, making the 7-day baseline more appropriate for them but necessitating different handling.

**Research recommendation (Springer 2025 systematic review, Altini/HRV4Training):** Use individualized, within-person monitoring with cycle phase as contextual metadata, not a deterministic override. A **28-day or full-cycle rolling baseline** alongside a shorter (7-day) window provides both hormonal context and acute sensitivity.

### 3.5 Fatigue Accumulation and Recovery Speed

- **Females may recover faster from resistance training** at equivalent relative loads, with one study showing greater recovery capacity despite completing more total volume (PMC, 2025).
- **Estrogen's protective effect:** Higher estrogen levels (follicular phase) may attenuate exercise-induced muscle damage and accelerate muscular regeneration, though human evidence is inconsistent.
- **Progesterone's catabolic tendency:** Elevated progesterone in the luteal phase may increase protein catabolism and reduce the anabolic response to training.
- **Practical implication:** The "same recovery score" may mean different things for a female athlete in different phases. A score of 65 in the late follicular phase may represent better readiness than 65 in the late luteal phase.

---

## 4. Sex Differences in Training Load and Injury Risk

### 4.1 ACWR Threshold Differences

**The critical problem:** The widely cited 0.8-1.3 "sweet spot" for ACWR has **never been validated in female athletes.**

- A 2025 meta-analysis (22 cohort studies, 921 participants, 657 injuries) found ACWR significantly associated with injury risk (ES = 0.72), but explicitly noted: "most of the study is mainly dominated by males."
- **Only 2 of 22 studies included female participants.**
- The 0.8-1.3 zone showed the lowest injury incidence, but with a wide confidence interval (95% CI [0.14, 0.94]), making the conclusion "questionable."
- The authors explicitly recommend: "Future research should aim at the discussion of ACWR on the gender differences, and specify the need for stratified analyses or sex-specific thresholds."
- Studies of female youth volleyball and intercollegiate female soccer/rugby used ACWR effectively for load management, but did not establish sex-specific optimal zones.

**For Tonus:** The current ACWR zone classifications (ACWRZone.classify) use the standard 0.8-1.3 sweet spot. These thresholds should be flagged as male-derived and potentially inaccurate for female users. However, no alternative thresholds exist in the literature to replace them.

### 4.2 ACL Injury Risk by Cycle Phase

- **Strong evidence** that female athletes have significantly greater ACL injury risk in the **preovulatory phase** (first half of cycle). Seven studies in a systematic review favored this finding (Hewett et al., 2007; PMC 2017).
- **Mechanism:** Higher estrogen levels in late follicular/pre-ovulatory phase may reduce connective tissue stiffness, increase anterior knee laxity.
- **Relaxin** (hormone elevated in certain phases) also linked to ACL laxity.
- **Conflicting evidence:** Some studies report different phases of heightened risk. Methodological quality is generally low to very low.
- **Practical note:** ACL risk tracking is likely out of scope for Tonus's core workload algorithms, but awareness could inform injury risk warnings (e.g., "preovulatory phase -- consider neuromuscular warm-up for jumping/cutting activities").

### 4.3 Stress Fracture Risk and RED-S

**RED-S (Relative Energy Deficiency in Sport)** is a critical female-specific concern:

- Estimated to affect **23-80% of female athletes** (depending on sport and screening criteria).
- **Menstrual irregularity** is a primary RED-S marker: oligomenorrhea (<9 cycles/year), secondary amenorrhea (absence of 3+ consecutive periods), or anovulatory cycles.
- **Amenorrheic athletes have 2-4x greater relative risk for stress fracture** than eumenorrheic athletes.
- Athletes with functional hypothalamic amenorrhea experience a **4.5x increase in bone injury prevalence.**
- Energy availability threshold: Healthy athletes need ~45 kcal/kg FFM/day. Below 30 kcal/kg FFM/day triggers clinical concern.
- **44% of ballet dancers and 51% of female endurance runners** experience menstrual abnormalities.

**For Tonus:** Cycle regularity tracking could serve as a RED-S early warning signal. If a user reports irregular or absent periods, the app could flag increased injury risk and recommend consulting a sports medicine professional.

### 4.4 Fatigue Accumulation Patterns

- Female athletes may accumulate fatigue differently due to hormonal modulation of recovery processes.
- The current FatigueIndexEngine uses sex-agnostic weights for its six components (load elevation, session density, recovery trend, rest debt, wellness trend, soft-tissue flag).
- **Luteal phase may amplify perceived fatigue** even when objective training load is unchanged, due to thermoregulatory strain, sleep disruption, and progesterone-mediated effects.
- **Recovery trend component** in FatigueIndexEngine may show false decline during luteal transition, inflating fatigue index without true overreaching.

---

## 5. Apple HealthKit Menstrual Data Availability

### 5.1 Available HKCategoryTypeIdentifiers

HealthKit provides comprehensive menstrual and reproductive health data types:

**Core Menstrual Data:**
| Identifier | Type | Description |
|---|---|---|
| `.menstrualFlow` | HKCategoryType | Records menstrual flow. Uses `HKMetadataKeyMenstrualCycleStart: Bool` to mark cycle start. |
| `.intermenstrualBleeding` | HKCategoryType | Spotting between periods |
| `.irregularMenstrualCycles` | HKCategoryType | Apple-computed flag for irregular cycles |
| `.infrequentMenstrualCycles` | HKCategoryType | Apple-computed flag for infrequent cycles |
| `.prolongedMenstrualPeriods` | HKCategoryType | Apple-computed flag for prolonged periods |
| `.persistentIntermenstrualBleeding` | HKCategoryType | Apple-computed flag for persistent spotting |

**HKCategoryValueMenstrualFlow Values:**
- `.unspecified` -- Flow logged but severity not specified
- `.light` -- Light flow
- `.medium` -- Medium flow
- `.heavy` -- Heavy flow
- `.none` -- No flow (used to mark period end)

**Fertility and Ovulation:**
| Identifier | Type | Description |
|---|---|---|
| `.ovulationTestResult` | HKCategoryType | Home ovulation test result (positive/negative/indeterminate) |
| `.cervicalMucusQuality` | HKCategoryType | Cervical mucus observations (dry, sticky, creamy, watery, egg white) |
| `.sexualActivity` | HKCategoryType | Sexual activity log (with protection status metadata) |
| `.contraceptive` | HKCategoryType | Contraceptive use (type in metadata) |
| `.pregnancy` | HKCategoryType | Pregnancy status |
| `.lactation` | HKCategoryType | Lactation status |
| `.progesteroneTestResult` | HKCategoryType | Home progesterone test result |
| `.pregnancyTestResult` | HKCategoryType | Home pregnancy test result |

**Temperature Data:**
| Identifier | Type | Description |
|---|---|---|
| `.appleSleepingWristTemperature` | HKQuantityType | Wrist temperature deviation during sleep (iOS 17+, Watch Series 8+) |
| `.basalBodyTemperature` | HKQuantityType | Manually logged basal body temperature |
| `.bodyTemperature` | HKQuantityType | General body temperature reading |

### 5.2 Wrist Temperature and Cycle Phase Detection

- **Apple Watch Series 8+** uses dual temperature sensors (wrist surface + under crystal) to measure overnight wrist temperature changes.
- Records **deviation from personal baseline** (not absolute temperature), expressed in degrees C.
- **Requires ~2 menstrual cycles** of nightly wear before retrospective ovulation estimates become available.
- A 2025 study published in Human Reproduction validated Apple's algorithms for retrospective ovulation day estimation and next menses prediction using wrist temperature data.
- **Biphasic shift:** Post-ovulation wrist temperature typically rises 0.2-0.5 degrees C above follicular baseline, persisting through the luteal phase.

### 5.3 Cycle Length Prediction

- Apple uses a **traditional calendar method** for initial predictions, estimating the fertile window by subtracting 13 days (assumed luteal phase length) from the predicted next cycle start.
- Heart rate data improves prediction accuracy.
- **Cycle Deviation Detection** can notify users of irregular patterns.
- Apple does **not** expose a public API for predicted cycle phase or ovulation date. Third-party apps must compute this from raw `.menstrualFlow` samples and `HKMetadataKeyMenstrualCycleStart`.

### 5.4 What Apple Watch Collects Automatically vs. Manual Logging

**Automatic (passive):**
- Wrist temperature (nightly, Series 8+)
- Heart rate / HRV / RHR
- Sleep analysis
- `.irregularMenstrualCycles`, `.infrequentMenstrualCycles`, `.prolongedMenstrualPeriods` (computed from logged data)

**Manual (requires user input):**
- `.menstrualFlow` (period days, flow volume)
- `.ovulationTestResult`
- `.cervicalMucusQuality`
- `.basalBodyTemperature`
- `.sexualActivity`
- `.contraceptive`
- Symptoms (mood, cramps, headache, etc.)

### 5.5 Implementation Considerations for Tonus

1. **Minimum viable integration:** Read `.menstrualFlow` with `HKMetadataKeyMenstrualCycleStart` to determine cycle day. This requires only user-logged period start dates.
2. **Enhanced integration:** Also read `.appleSleepingWristTemperature` to detect luteal phase onset (biphasic shift) without user manual input.
3. **Privacy:** HealthKit menstrual data is among the most sensitive health data. Tonus must request specific read permissions and explain clearly why this data improves training recommendations. **Raw menstrual data must never be uploaded to Supabase** (consistent with existing HealthKit policy).
4. **Graceful degradation:** Many users will not track periods, will use hormonal contraceptives (altering patterns), or will have irregular cycles. The system must work well without cycle data and add value incrementally when it is available.

---

## 6. Female-Specific Training Methodologies

### 6.1 Dr. Stacy Sims -- "Women Are Not Small Men"

Dr. Stacy Sims (PhD, exercise physiology, Stanford/AUT/Waikato) is the leading voice in female-specific training science. Her core philosophy:

**Original ROAR Recommendations (2016):**
- **Follicular phase:** Body is primed for stress and adaptation. Prioritize high-intensity workouts, heavy resistance training. Higher increase in muscle strength possible compared to luteal phase.
- **Ovulation window:** Peak performance potential. Power/speed work.
- **Luteal phase:** Endurance capacity lower. Shift to steady-state, low-to-moderate intensity, moderate resistance training. More recovery needed.
- **Late luteal/premenstrual:** Recovery phase. Technique, mobility, functional strength work.
- **Nutrition:** Increase protein and complex carbs in luteal phase to offset progesterone-driven catabolism and substrate shifts.

**Evolved Position (2025 article on her website):**
Dr. Sims has significantly updated her stance:
- **"Train by readiness, not the calendar."** Her original phase-based framework "created a new limitation" where women adapted training to calendars rather than listening to their bodies.
- **Strength training is "non-negotiable throughout the month."** Not just in the follicular phase.
- **Periodize across months considering life stress,** not daily phases.
- **"Studies show averages, not individuals."** Hormonal variability makes one-size-fits-all recommendations ineffective.
- Stress, sleep, contraceptives, and anovulatory cycles disrupt predicted patterns.
- Use **HRV, sleep, perceived exertion, and mood** to assess daily readiness.

**This evolution is highly significant for Tonus.** It validates a readiness-first approach (which Tonus already uses) augmented by cycle awareness, rather than a cycle-deterministic approach.

### 6.2 Phase-Based Periodization Recommendations (Synthesized)

Based on the full body of evidence, including Sims's evolved position:

| Phase | Intensity | Volume | Session Type | Recovery | Rationale |
|---|---|---|---|---|---|
| **Early Follicular** (Menses) | Moderate (symptom-dependent) | Moderate | Flexible; prioritize what feels good | Normal | Low hormones; symptoms may limit perceived readiness |
| **Late Follicular** | High | High | Strength, power, HIIT | Fast recovery expected | Estrogen rising; favorable anabolic environment |
| **Ovulation** | High (peak) | High | Power, speed, maximal attempts | Normal | Estrogen peak; but watch for ACL warm-up needs |
| **Early Luteal** | Moderate-High | Moderate | Strength (maintain), conditioning | Slightly increased need | Progesterone rising; thermoregulation beginning to shift |
| **Late Luteal** | Moderate-Low | Reduce 10-20% | Steady-state, technique, mobility | High priority | Both hormones declining; PMS symptoms; sleep disruption |

**These are guidelines, not prescriptions.** Individual readiness (HRV, sleep, RPE, wellness) should always take precedence.

### 6.3 Hormonal Contraceptive Impact

**Key findings:**
- Hormonal contraceptives **suppress endogenous hormone fluctuations**, creating a more stable but potentially suppressed hormonal environment.
- **Overall performance impact is "trivial"** at population level (2020 meta-analysis), but individual variation exists.
- **VO2 max may be reduced ~5%** in OC users compared to non-users.
- **Higher inflammation markers** (C-reactive protein) found in elite athletes on OC, which could affect recovery.
- **Higher cortisol and lower anabolic hormones** after resistance training in OC users.
- **HRV patterns flatten:** The cyclical HRV variation seen in naturally cycling women is reduced or absent in OC users.

**For Tonus:** Contraceptive status should be an input variable. OC users should NOT receive cycle-phase-based training adjustments (since their hormonal environment is relatively stable), but should still benefit from readiness-based recommendations. The 7-day HRV baseline may actually be more appropriate for OC users than for naturally cycling women.

---

## 7. Industry Landscape: Competitor Analysis

### 7.1 FitrWoman (Orreco)

**Approach:** First-to-market cycle-aware training app.
- Daily training and nutrition suggestions tailored to menstrual cycle phase.
- Symptom logging, flow tracking, training intensity tracking.
- Nutritional insights: food recommendations by phase, recipe library filterable by phase/symptoms/nutrients.
- Customized alerts at key cycle points.
- **Limitation:** Primarily content-based (tips and suggestions), not algorithmically adaptive. Does not integrate wearable biometric data for readiness scoring. Phase detection relies entirely on user-reported period dates.

### 7.2 Wild.AI

**Approach:** Most sophisticated competitor. AI-driven, biometric-integrated.
- **Cycle tracking** across life stages: menstrual cycle, birth control, perimenopause, menopause.
- **Wearable integration:** Oura, Garmin, Fitbit, Strava, Apple Health, TrainingPeaks. Recently integrated Amazfit T-Rex 3 Pro.
- **Readiness score** from morning check-ins, tailored to cycle phase or menopausal stage.
- **Personalized training, nutrition, and recovery guidance** that adapts to hormonal and biometric patterns.
- **Built on 451+ scientific whitepapers.**
- **Symptom-informed:** Algorithm takes symptoms and cycle phase into consideration for daily adaptation.
- **4.5 stars on App Store.**
- **Gap:** Focused on guidance/recommendations rather than workload management (ACWR, fatigue accumulation). Does not provide training load tracking in the sports science sense.

### 7.3 Jennis (Jessica Ennis-Hill)

**Approach:** Celebrity-backed, coach-led content.
- Created with physiologist Dr. Emma Ross.
- **Cycle Mapping:** Questionnaire determines cycle length, symptoms, fitness level. App pinpoints cycle phase and recommends workout types.
- **Four-phase model:** Follicular HIIT, ovulation power work, luteal moderate intensity, menstrual recovery/yoga.
- **Content library:** HIIT, strength, yoga, LISS, audio runs, recovery sessions (5-35 min).
- **Perimenopause program** added.
- **Limitation:** Prescriptive (workout assigned by phase), not responsive to actual biometric readiness. No wearable integration. No training load tracking.

### 7.4 Market Gap Analysis

| Feature | FitrWoman | Wild.AI | Jennis | Tonus (Current) | Tonus (Opportunity) |
|---|---|---|---|---|---|
| Cycle phase tracking | Yes (manual) | Yes (manual + wearable) | Yes (manual) | No | Yes (HealthKit) |
| Wearable biometric integration | No | Yes (multi-platform) | No | Yes (Apple Health) | Enhanced |
| Readiness / recovery score | No | Yes (basic) | No | Yes (sophisticated) | Cycle-aware |
| Training load tracking (ACWR) | No | No | No | Yes | Cycle-contextualized |
| Fatigue accumulation | No | No | No | Yes | Cycle-aware |
| Phase-based training recs | Yes (content) | Yes (AI-driven) | Yes (prescriptive) | No | Readiness-first + cycle context |
| Autoregulation / volume adjustment | No | Partial | No | Yes | Cycle-informed |
| Progressive overload tracking | No | No | No | Yes | Phase-contextualized |
| RED-S / cycle regularity warnings | No | Partial | No | No | Yes |
| Coach-athlete relationship | No | No | No | Yes | Cycle-aware coaching |
| Contraceptive status handling | No | Yes | No | No | Yes |

**Tonus's unique opportunity:** No existing app combines sophisticated workload management (ACWR, fatigue index, progressive overload) with cycle-aware readiness scoring. Wild.AI comes closest but lacks the training load depth. FitrWoman and Jennis are content-first, not algorithm-first. Tonus can be the first app to bring sports science-grade workload management to female athletes with proper cycle context.

---

## 8. Key Uncertainties and Research Gaps

1. **No validated sex-specific ACWR thresholds exist.** The 0.8-1.3 sweet spot is male-derived. Tonus cannot replace these thresholds with female-specific ones because they have not been established.

2. **Cycle-based periodization lacks strong RCT evidence.** The IMPACT trial (ongoing) may provide clarity. Until then, evidence is suggestive, not prescriptive.

3. **Individual variation dwarfs population-level phase effects.** A woman's HRV may drop 15ms in one luteal phase and not change in the next. Algorithms must handle this gracefully.

4. **Contraceptive diversity is vast.** Combined OC, progestin-only pill, IUD (hormonal and copper), implant, patch, ring -- each creates a different hormonal environment. Tonus cannot model all of these.

5. **Phase detection accuracy from HealthKit data depends on user compliance.** If a user doesn't log period start dates, no cycle inference is possible. Wrist temperature can help but requires Watch Series 8+ and ~2 months of data.

6. **The effect of the menstrual cycle on training response is real but small.** Medium effect sizes for strength, small for endurance, negligible for anaerobic. Overweighting cycle phase in algorithms could introduce more noise than signal.

---

## 9. Implications for Tonus

### 9.1 Architecture: New Model and Service

**New Model: `CyclePhase` / `MenstrualCycleSnapshot`**

A new SwiftData model to store daily cycle state:

```
@Model MenstrualCycleSnapshot
- date: Date
- cycleDay: Int?               // 1-based day of current cycle (nil if unknown)
- estimatedPhase: CyclePhase?  // computed from cycleDay + cycle length
- cycleLength: Int?            // most recent cycle length in days
- isOnContraceptive: Bool
- contraceptiveType: ContraceptiveType?
- flowIntensity: FlowIntensity? // from HealthKit
- wristTempDeviation: Double?   // from appleSleepingWristTemperature
- isCycleStart: Bool            // from HKMetadataKeyMenstrualCycleStart
```

**New Enum: `CyclePhase`**
```
enum CyclePhase: String, Codable, CaseIterable {
    case earlyFollicular   // Days 1-5 (menses)
    case lateFollicular    // Days 6-13
    case ovulatory         // ~Day 14 (± 2 days)
    case earlyLuteal       // Days 15-21
    case lateLuteal        // Days 22-28+
    case unknown           // insufficient data
}
```

**New Service: `CycleTrackingService`**
- Read `.menstrualFlow` from HealthKit with `HKMetadataKeyMenstrualCycleStart`
- Read `.appleSleepingWristTemperature` for biphasic shift detection
- Compute estimated cycle day and phase
- Handle irregular cycles, missing data, contraceptive status
- Respect privacy: never sync raw data to Supabase

### 9.2 RecoveryScoreEngine Modifications

**Current state:** 7-day rolling baseline for HRV and RHR. No cycle awareness.

**Proposed changes:**

1. **Dual baseline system:**
   - Keep the 7-day rolling baseline for acute sensitivity.
   - Add a **28-day (full-cycle) rolling baseline** as a secondary reference.
   - When cycle data is available, compare today's HRV/RHR against the **same-phase average** from prior cycles (e.g., "your HRV today is X% of your typical late-follicular HRV").

2. **Phase-aware expected ranges:**
   - During luteal phase, a lower HRV is expected. The engine should attenuate the penalty applied when HRV drops below the 7-day baseline if the user is in the luteal phase and the drop is within the expected luteal range for that individual.
   - During follicular phase, a higher HRV is expected. The engine should attenuate the bonus when HRV rises if it is simply tracking the expected follicular rise.

3. **New input fields for RecoveryInput:**
   ```
   let cyclePhase: CyclePhase?
   let isOnContraceptive: Bool
   let hrvCycleBaseline: Double?  // same-phase historical average
   let rhrCycleBaseline: Double?  // same-phase historical average
   ```

4. **Contraceptive handling:** If `isOnContraceptive == true`, skip all phase-based adjustments. The 7-day baseline is appropriate for OC users.

5. **Graceful degradation:** If `cyclePhase == nil` or `.unknown`, the engine behaves exactly as it does today. No regression for users who don't track cycles.

### 9.3 AutoregulationEngine Modifications

**Current state:** Decision matrix of recovery zone x ACWR zone, modulated by fatigue index. No cycle awareness.

**Proposed changes:**

1. **New input field:**
   ```
   let cyclePhase: CyclePhase?
   ```

2. **Phase-contextual volume modifier:**
   - Late luteal phase: reduce volumeModifier by 10-15% (configurable) as a soft floor, not a hard cap.
   - Late follicular phase: allow volumeModifier to reach full 1.0 even at slightly elevated fatigue, reflecting the more favorable recovery environment.
   - **Only apply if recovery score is in the yellow zone (ambiguous).** Green and red zones should not be overridden by cycle phase.

3. **Phase-aware session type suggestions:**
   - Late luteal: bias toward `conditioning` or `activeRecovery` when the recommendation is borderline.
   - Late follicular/ovulatory: bias toward `strength` or `power` when the recommendation is borderline.
   - **Never override a `rest` recommendation** based on cycle phase.

4. **New warning type:**
   ```
   case preovulatoryACLRisk  // "Consider neuromuscular warm-up for jumping/cutting"
   ```

### 9.4 FatigueIndexEngine Modifications

**Current state:** Six components with fixed weights. No cycle awareness.

**Proposed changes:**

1. **Phase-aware recovery trend interpretation:**
   - The `recoveryTrend` component (weight 0.20) currently penalizes declining recovery scores. During the follicular-to-luteal transition, declining recovery scores are expected. Add a dampening factor when `cyclePhase` transitions from follicular to luteal.
   - Dampening factor: reduce the recovery trend component weight by ~30% (0.20 -> 0.14) during early luteal transition.

2. **Phase-aware wellness trend interpretation:**
   - The `wellnessTrend` component (weight 0.15) may decline during late luteal/menstrual phase due to PMS symptoms. Apply similar dampening.

3. **Menstrual regularity as a fatigue/risk signal:**
   - New optional component: if cycle data shows irregularity (missed periods, very long cycles), this can serve as a **RED-S early warning** that contributes a small amount to the fatigue index or generates a separate alert.

4. **New input fields:**
   ```
   let cyclePhase: CyclePhase?
   let isOnContraceptive: Bool
   let cycleRegularity: CycleRegularity?  // .regular, .irregular, .absent
   ```

### 9.5 WorkloadCalculator Modifications

**Current state:** EWMA-based ACWR with standard 0.8-1.3 thresholds. No sex differentiation.

**Proposed changes:**

1. **No threshold changes** (no evidence exists for female-specific ACWR thresholds).

2. **Contextual ACWR interpretation:** When presenting ACWR to users, add cycle context:
   - "Your ACWR is 1.1 (optimal). You are in the late follicular phase, which typically supports higher training loads."
   - "Your ACWR is 1.2 (caution). You are in the late luteal phase. Consider that your body may be less resilient to load spikes during this phase."

3. **Future consideration:** If/when female-specific ACWR research emerges, the `ACWRZone.classify()` method should accept an optional sex/cycle parameter.

### 9.6 ProgressionEngine Modifications

**Current state:** Progressive overload suggestions based on training history, recovery state, and detraining detection. No cycle awareness.

**Proposed changes:**

1. **Phase-aware progression scaling:**
   - During late follicular / ovulatory: allow full progressive overload suggestions (weight increases, rep increases).
   - During late luteal: bias toward `maintain` rather than `increase` when the progression rate is marginal.
   - During early follicular (menses): bias toward `maintain` if wellness score is low, even if recovery metrics appear adequate.

2. **New input in TrainingContext:**
   ```
   let cyclePhase: CyclePhase?
   ```

3. **PR expectations by phase:** Consider flagging PRs achieved in the late follicular phase as potentially reflecting the favorable hormonal environment, not necessarily a sustainable new ceiling. (Low priority, informational only.)

### 9.7 RecoveryPipeline and RecoveryPipeline Modifications

- `RecoveryPipeline.run()` should query `CycleTrackingService` for today's cycle state and pass it to `RecoveryScoreEngine`.
- `WorkoutPipeline.processSession()` should stamp `MenstrualCycleSnapshot` cycle day on each workout session for historical analysis.

### 9.8 New Feature: RED-S Risk Monitoring

**Trigger conditions:**
- 3+ consecutive missed periods (secondary amenorrhea)
- Cycle length > 35 days consistently (oligomenorrhea)
- High training load + declining cycle regularity

**Response:**
- Non-alarmist notification: "Your cycle patterns have changed. This can sometimes indicate your body needs more fuel or recovery. Consider speaking with a healthcare provider."
- Never diagnose RED-S -- only surface the pattern.

### 9.9 UI Considerations

- **Cycle tracking opt-in:** Clearly separate menstrual tracking permission from other HealthKit permissions. Some users will not want to share this data. It must be 100% optional.
- **Cycle day indicator:** Small, unobtrusive indicator on dashboard showing current cycle day/phase (if available).
- **Phase context in recovery card:** "Recovery: 68 (Yellow). You're in your luteal phase -- lower HRV and higher heart rate are expected during this phase."
- **Recommendation context:** Training recommendations should reference cycle phase when it influences the recommendation.
- **Contraceptive status:** Profile setting (not HealthKit dependent) for users to indicate if they use hormonal contraception. Affects algorithm behavior.

### 9.10 Implementation Priority

| Priority | Change | Effort | Impact |
|---|---|---|---|
| **P0** | CycleTrackingService + HealthKit menstrual data reads | Medium | Foundation for everything else |
| **P0** | MenstrualCycleSnapshot model | Low | Data layer |
| **P0** | Contraceptive status in Profile | Low | Critical for correct algorithm behavior |
| **P1** | RecoveryScoreEngine dual baseline + phase awareness | High | Highest-impact algorithm change |
| **P1** | Graceful degradation (no-data path unchanged) | Medium | Prevents regression |
| **P2** | AutoregulationEngine phase context | Medium | Improves daily recommendations |
| **P2** | FatigueIndexEngine dampening | Medium | Reduces false fatigue alerts |
| **P2** | RED-S monitoring | Medium | Unique differentiator, safety feature |
| **P3** | ProgressionEngine phase awareness | Low | Marginal improvement |
| **P3** | WorkloadCalculator contextual messaging | Low | Informational |
| **P3** | UI: cycle day indicator, phase context in cards | Medium | User-facing value |

### 9.11 Guiding Principles

1. **Readiness-first, cycle-contextual.** Cycle phase is metadata that contextualizes readiness metrics, not a deterministic override. This aligns with Dr. Sims's evolved position and the strongest research evidence.

2. **Individual over population.** Use within-person historical data (same-phase averages across prior cycles) rather than population-level phase expectations.

3. **Graceful degradation.** The app must work perfectly for: users who don't track cycles, users on hormonal contraceptives, users with irregular cycles, users without Apple Watch, and male users. Cycle awareness adds value but is never required.

4. **Privacy paramount.** Raw menstrual data stays on-device. Only derivative scores (cycle phase, cycle day) can influence algorithms. Nothing syncs to Supabase.

5. **No overconfidence.** The research base is evolving. Cycle-phase effects are real but small and individually variable. The algorithm should apply soft adjustments (5-15% modifiers) rather than dramatic overrides.

6. **Transparency.** When cycle phase influences a recommendation, tell the user why. "We've adjusted your recovery baseline because you're in your luteal phase" is more trustworthy than silently changing behavior.

---

## 10. Sources

### Academic Papers and Reviews

- [Advancing Women's Performance: Hormonal Monitoring and Menstrual Cycle-Tailored Training (MDPI Sports, 2026)](https://www.mdpi.com/2075-4418/14/1/7)
- [Exercise performance at different phases of the menstrual cycle: narrative review (Frontiers in Endocrinology, 2025)](https://www.frontiersin.org/journals/endocrinology/articles/10.3389/fendo.2025.1448686/full)
- [Wearable-Derived HRV Across the Menstrual Cycle: A Living Systematic Review (Sports Medicine, Springer, 2025)](https://link.springer.com/article/10.1007/s40279-025-02388-y)
- [The menstrual cycle through the lens of a wearable device (bioRxiv, 2025)](https://www.biorxiv.org/content/10.1101/2025.09.11.675620v1.full)
- [HRV Measurements Across the Menstrual Cycle in Olympian Swimmers (PMC, 2025)](https://pmc.ncbi.nlm.nih.gov/articles/PMC12197002/)
- [Effects of menstrual cycle phases on athletic performance (high methodological standards) (PubMed, 2025)](https://pubmed.ncbi.nlm.nih.gov/40695607/)
- [The Effects of Menstrual Cycle Phase on Elite Athlete Performance (PMC, 2021)](https://pmc.ncbi.nlm.nih.gov/articles/PMC8170151/)
- [Menstrual Cycle and Athletic Status Interact (PMC, 2025)](https://pmc.ncbi.nlm.nih.gov/articles/PMC12511478/)
- [ACWR for predicting sports injury risk: systematic review and meta-analysis (PMC, 2025)](https://pmc.ncbi.nlm.nih.gov/articles/PMC12487117/)
- [The Relationship Between ACWR and Injury Risk in Sports (PMC, 2020)](https://pmc.ncbi.nlm.nih.gov/articles/PMC7047972/)
- [Comparing ACWR Calculations in Girls' Youth Volleyball (PMC, 2023)](https://pmc.ncbi.nlm.nih.gov/articles/PMC10051422/)
- [Effects of the Menstrual Cycle on ACL Injury Risk (Hewett et al., 2007)](https://journals.sagepub.com/doi/10.1177/0363546506295699)
- [Menstrual cycle effects on lower-limb biomechanics and ACL injury risk (PMC, 2017)](https://pmc.ncbi.nlm.nih.gov/articles/PMC5505581/)
- [Menstrual Cycle Hormone Relaxin and ACL Injuries (PMC, 2024)](https://pmc.ncbi.nlm.nih.gov/articles/PMC11195904/)
- [Association Between Menstrual Cycle Phase, Contraceptive Use and Musculoskeletal Injury (Springer Sports Medicine, 2024)](https://link.springer.com/article/10.1007/s40279-024-02074-5)
- [RED-S: Scientific, Clinical, and Practical Implications for the Female Athlete (PMC, 2022)](https://pmc.ncbi.nlm.nih.gov/articles/PMC9724109/)
- [RED-S and Bone Stress Injuries (ScienceDirect, 2023)](https://www.sciencedirect.com/science/article/abs/pii/S1060187223000515)
- [Impact of REDs on Bone Health in Elite Athletes (PMC, 2025)](https://pmc.ncbi.nlm.nih.gov/articles/PMC12485273/)
- [Effects of oral contraceptives on exercise performance: meta-analysis (PubMed, 2020)](https://pubmed.ncbi.nlm.nih.gov/32666247/)
- [OC effects on muscle strength and fiber composition (BMC Women's Health, 2022)](https://bmcwomenshealth.biomedcentral.com/articles/10.1186/s12905-022-01740-y)
- [Impact of Menstrual cycle-based Periodized training: IMPACT study protocol (BMC Trials, 2024)](https://pmc.ncbi.nlm.nih.gov/articles/PMC10823667/)
- [Follicular versus luteal phase-based strength training (PubMed, 2014)](https://pubmed.ncbi.nlm.nih.gov/25485203/)
- [Current evidence shows no influence of menstrual cycle on strength performance (Frontiers, 2023)](https://www.frontiersin.org/journals/sports-and-active-living/articles/10.3389/fspor.2023.1054542/full)
- [Sex differences in fatigue during and recovery from resistance exercise (PMC, 2025)](https://pmc.ncbi.nlm.nih.gov/articles/PMC12790778/)
- [Effect of Estrogen on Musculoskeletal Performance and Injury Risk (PMC, 2019)](https://pmc.ncbi.nlm.nih.gov/articles/PMC6341375/)
- [Sleep in women: hormonal influences, sex differences and health implications (Frontiers in Sleep, 2023)](https://www.frontiersin.org/journals/sleep/articles/10.3389/frsle.2023.1271827/full)
- [Sleep Arousals During Menses in Female Athletes (PMC, 2024)](https://pmc.ncbi.nlm.nih.gov/articles/PMC11032107/)
- [Sex differences in sleep and menstrual cycle influence in junior endurance athletes (PLOS ONE, 2021)](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0253376)
- [Menstrual Cycle Symptoms Not Hormone Concentrations Associated With Sleep (Pearson et al., European Journal of Sport Science, 2025)](https://onlinelibrary.wiley.com/doi/10.1002/ejsc.70038)
- [HRV role in sports physiology (PMC, 2016)](https://pmc.ncbi.nlm.nih.gov/articles/PMC4840584/)
- [Effect of Different Phases of Menstrual Cycle on HRV (PMC, 2015)](https://pmc.ncbi.nlm.nih.gov/articles/PMC4625231/)
- [Novel method for quantifying cardiovascular fluctuations across the menstrual cycle (npj Digital Medicine, 2024)](https://www.nature.com/articles/s41746-024-01394-0)
- [Gender Disparities in Sport Science: Research Gap Analysis (ResearchGate, 2025)](https://www.researchgate.net/publication/392320124_Gender_Disparities_in_Sport_Science_A_Research_Gap_Analysis_of_Female_Athletes)
- [How sports science is neglecting female athletes (Nature, 2022)](https://www.nature.com/articles/d41586-022-04460-3)
- [Performance of algorithms using wrist temperature for ovulation estimation (Human Reproduction, 2025)](https://academic.oup.com/humrep/article/40/3/469/7989515)

### Apple Developer Documentation

- [HKCategoryTypeIdentifier.menstrualFlow](https://developer.apple.com/documentation/healthkit/hkcategorytypeidentifier/menstrualflow)
- [HKCategoryTypeIdentifier.ovulationTestResult](https://developer.apple.com/documentation/healthkit/hkcategorytypeidentifier/1615252-ovulationtestresult)
- [HKCategoryTypeIdentifier.cervicalMucusQuality](https://developer.apple.com/documentation/healthkit/hkcategorytypeidentifier/cervicalmucusquality)
- [HKCategoryTypeIdentifier.irregularMenstrualCycles](https://developer.apple.com/documentation/healthkit/hkcategorytypeidentifier/irregularmenstrualcycles)
- [HKCategoryTypeIdentifier.prolongedMenstrualPeriods](https://developer.apple.com/documentation/healthkit/hkcategorytypeidentifier/prolongedmenstrualperiods)
- [HKQuantityTypeIdentifier.appleSleepingWristTemperature](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/applesleepingwristtemperature)
- [HKQuantityTypeIdentifier.basalBodyTemperature](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/1615763-basalbodytemperature)
- [HKMetadataKeyMenstrualCycleStart](https://developer.apple.com/documentation/healthkit/hkmetadatakeymenstrualcyclestart)
- [Apple Watch Cycle Tracking](https://support.apple.com/en-us/120356)
- [Retrospective ovulation estimates on Apple Watch](https://support.apple.com/guide/watch/receive-retrospective-ovulation-estimates-apd3ee429691/watchos)

### Expert Sources and Industry

- [Dr. Stacy Sims: The Evolution of Menstrual Cycle Training (2025)](https://www.drstacysims.com/newsletters/articles/posts/the-evolution-of-menstrual-cycle-training)
- [Dr. Stacy Sims: Nail a PR at Every Phase of Your Menstrual Cycle](https://www.drstacysims.com/newsletters/articles/posts/Nail_a_PR_at_Every_Phase_of_Your_Menstrual_Cycle)
- [TrainingPeaks: HRV, Performance and the Menstrual Cycle (with Dr. Sims)](https://www.trainingpeaks.com/coach-blog/the-performance-advantages-of-tracking-menstrual-cycles-with-dr-stacy-sims/)
- [TrainingPeaks: HRV, Athlete Performance and the Menstrual Cycle](https://www.trainingpeaks.com/coach-blog/hrv-performance-and-the-menstrual-cycle/)
- [Marco Altini / HRV4Training: HRV, the Menstrual Cycle, Pregnancy, and Menopause](https://marcoaltini.substack.com/p/heart-rate-variability-hrv-the-menstrual)
- [WHOOP: Dr. Stacy Sims AMA on Training and Menstrual Cycles](https://www.whoop.com/us/en/thelocker/ama-dr-stacy-sims/)
- [Oura Blog: Your Menstrual Cycle impacts your entire body](https://ouraring.com/blog/your-menstrual-cycle/)
- [Clue: What Your Heart Reveals About Your Menstrual Cycle (RHR & HRV)](https://helloclue.com/articles/menstrual-cycle/what-your-heart-can-tell-you-about-your-menstrual-cycle)

### Competitor Apps

- [Wild.AI](https://wild.ai/)
- [Wild.AI: How to Train with Wild.AI](https://www.wild.ai/blog/how-to-train-with-wild-ai)
- [Wild.AI + Oura Integration (Oura Blog)](https://ouraring.com/blog/wild-ai-integration/)
- [FitrWoman Mobile App Features](https://www.fitrwoman.com/product/mobile-app-features)
- [FitrWoman (App Store)](https://apps.apple.com/us/app/fitrwoman/id1189050449)
- [Jennis CycleMapping](https://www.jennisfitness.com/blog/cyclemapping/map-your-training-to-your-menstrual-cycle-with-jennis-cyclemapping/)
- [Jennis](https://www.jennis.com/)

### YouTube Reference

- [Referenced video](https://www.youtube.com/watch?v=pZX8ikmWvEU) -- Content on traditional sports science male bias and female athlete needs (transcript not extractable; thematic alignment confirmed with research findings above).
