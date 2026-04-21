# Feature Landscape

**Domain:** Athlete training analytics (weekly summaries, periodization, fatigue analysis, data export)
**Researched:** 2026-04-20
**Context:** Tonus already ships recovery scoring, ACWR/EWMA load tracking, autoregulation recommendations, PR detection, coach-athlete relationships, and two-tier subscriptions. This research covers what to build next.

## Table Stakes

Features users expect from any app that claims to offer "training analytics." Missing any of these and power users will switch to TrainingPeaks, WHOOP, or HRV4Training.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Weekly training summary** | WHOOP, Oura, TrainingPeaks all deliver automated weekly recaps. Athletes expect a Monday-morning snapshot of their week. | Medium | Tonus already has WorkloadSnapshot (ATL, CTL, ACWR, TSB, weeklyVolume) and RecoverySnapshot (HRV, RHR, sleep, recovery score) per day -- aggregation is straightforward. Show: total sessions, total volume, avg recovery score, load trend direction, ACWR zone distribution. |
| **Multi-week trend charts** | Every competitor shows 4-week, 12-week, and 6-month views. Athletes need to see whether their fitness is building or stalling. | Low | Tonus already has 28-day HRV trend on dashboard. Extend to CTL/ATL/TSB trend lines on the Workload tab with a time-range picker (4w / 12w / 6m). Data already exists in WorkloadSnapshot history. |
| **Week-over-week load comparison** | TrainingPeaks and AthleteMonitoring show this. Coaches especially need "this week vs last week" at a glance. | Low | Compute delta of weekly volume and session count. Display as simple +/- percentage on the weekly summary card. |
| **CSV data export** | Strong, StrongLifts, FitNotes, TrainingPeaks all offer CSV export. Athletes with data portability expectations will not stay without it. | Medium | Export WorkoutSession history (date, exercise, sets, reps, weight, RPE, volume, load). Standard CSV format compatible with Strong/TrainingPeaks import conventions. Gate behind Pro subscription. |
| **Recovery-load correlation view** | HRV4Training and WHOOP both show how load spikes affect recovery. This is the core promise of Tonus (combining recovery + load). | Medium | Plot recovery score as a line overlaid on daily load bars. 28-day view. The data is already collected -- this is a visualization feature, not a computation feature. Highlight periods where high load preceded recovery dips. |

## Differentiators

Features that set Tonus apart. Not expected by default, but create real competitive advantage -- especially vs. WHOOP (no strength training depth) and TrainingPeaks (no recovery scoring).

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Fatigue pattern detection** | Automatically identify recurring patterns: "Your recovery drops 2 days after high-volume upper body sessions" or "Sleep quality degrades during consecutive high-load weeks." No competitor does this for strength athletes at the individual level. | High | Requires a FatiguePatternEngine (pure struct, static methods) that analyzes 4+ weeks of paired load/recovery data. Pattern types: post-session recovery lag, cumulative load threshold, sleep-load interaction. Output human-readable insights. |
| **Training block detection (periodization awareness)** | Detect whether the athlete is in an accumulation, intensification, or deload phase based on volume and intensity trends -- without them manually configuring mesocycles. TrainingPeaks requires manual ATP setup; Tonus can infer it. | High | Analyze rolling 3-4 week windows of volume trend (increasing = accumulation, decreasing = deload, intensity-shifting = intensification). Display current detected phase on dashboard. Useful for autoregulation: "You appear to be in week 3 of a building phase -- consider a deload next week." |
| **Coach PDF report** | Coaches can generate a branded PDF summary for an athlete covering a date range. AthleteMonitoring charges enterprise prices for this. Tonus can offer it in the Coach tier. | Medium | Use iOS native PDFKit or UIGraphicsRenderer. Include: period summary stats, load chart, recovery chart, PR highlights, session log. Gate behind Coach subscription. |
| **Readiness-adjusted weekly plan suggestion** | Based on current recovery trend and load history, suggest how many sessions and at what intensity for the upcoming week. WHOOP does "strain target" but not session-level. | Medium | Extend AutoregulationEngine to output a weekly recommendation (e.g., "3 sessions, moderate intensity, avoid heavy lower body until recovery improves"). Requires the existing ACWR + recovery zone inputs plus a simple rule engine. |
| **Behavior tagging with correlation** | Let athletes tag daily behaviors (caffeine, alcohol, travel, menstrual cycle phase, stress) and after 2+ weeks show correlations with recovery. WHOOP added this in 2026 ("Behavior Insights"); Oura has "Tags." | Medium | New BehaviorTag model (date, tag name, boolean). After sufficient data (5+ yes/5+ no within 90 days per WHOOP's approach), run simple correlation against recovery score. Display as "Recovery is X% higher on days after you [tag]." |

## Anti-Features

Features to explicitly NOT build. Each has a clear reason.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Manual mesocycle/ATP planner** | TrainingPeaks owns this space with deep coach tooling. Building a full periodization planner is 3+ months of work and competes on their turf. Tonus's value is automated detection, not manual planning. | Detect training phases automatically from data. Show "You appear to be in [phase]" rather than asking users to configure mesocycles. |
| **AI chatbot / conversational coach** | WHOOP and Type to Run are investing heavily here. It requires LLM infrastructure, costs per query, and the liability of giving training advice. Not core to Tonus's data-centric value. | Keep autoregulation engine rule-based and transparent. Show reasoning ("because your HRV is 15% below baseline and ACWR is 1.4") rather than a chatbot. |
| **Social/leaderboard features** | Strava owns social fitness. Adding social features fragments focus and raises moderation burden. PROJECT.md explicitly lists this as out of scope. | Focus on coach-athlete relationship depth instead. Coaches are the "social" layer. |
| **Workout programming / plan builder** | Tonus already has PrescribedWorkout and WorkoutTemplate for coaches. Do NOT build a full plan-builder with progressive overload schemes -- that is a separate product (Juggernaut AI, Dr. Muscle). | Keep templates simple. The value is tracking what was done and analyzing it, not prescribing what to do. |
| **Real-time session analytics (live HR zones, tempo tracking)** | Requires Apple Watch companion app (explicitly out of scope). Phone-only real-time tracking during lifting is impractical. | Focus on post-session analysis. Recovery and load insights happen after the workout, not during. |
| **Calorie/nutrition tracking** | Different product category entirely. MyFitnessPal and MacroFactor own this. Adding it would bloat scope massively. | Could add body weight as a behavior tag for correlation analysis, but do not build food logging. |

## Feature Dependencies

```
Multi-week trend charts (table stakes)
  --> no dependencies, data exists in WorkloadSnapshot

Weekly training summary (table stakes)
  --> no dependencies, aggregates existing snapshots

Week-over-week load comparison (table stakes)
  --> Weekly training summary (displayed within it)

Recovery-load correlation view (table stakes)
  --> no dependencies, overlays existing data

CSV data export (table stakes)
  --> no dependencies, serializes WorkoutSession + snapshots

Fatigue pattern detection (differentiator)
  --> Multi-week trend charts (needs 4+ weeks of data, uses same data source)
  --> Recovery-load correlation view (pattern detection is the algorithmic layer on top of correlation visualization)

Training block detection (differentiator)
  --> Multi-week trend charts (analyzes the same volume/intensity trends)

Readiness-adjusted weekly plan (differentiator)
  --> Weekly training summary (provides context for the suggestion)
  --> Fatigue pattern detection (patterns inform weekly plan adjustments)

Coach PDF report (differentiator)
  --> Weekly training summary (report includes summary data)
  --> Multi-week trend charts (report includes chart images)

Behavior tagging with correlation (differentiator)
  --> Recovery-load correlation view (extends correlation to include tags)
  --> New BehaviorTag model (new SwiftData entity)
```

## MVP Recommendation

**Phase 1 -- Analytics Foundation (table stakes):**
1. Multi-week trend charts (Low complexity, high value, data already exists)
2. Weekly training summary with week-over-week comparison (Medium complexity, expected by every competitor)
3. Recovery-load correlation view (Medium complexity, fulfills Tonus's core promise)

**Phase 2 -- Export and Intelligence (mix of table stakes + differentiators):**
4. CSV data export (Medium complexity, table stakes for data-savvy athletes)
5. Fatigue pattern detection (High complexity, key differentiator -- builds on Phase 1 visualization)
6. Training block detection (High complexity, unique value vs. competitors)

**Phase 3 -- Coach Value and Personalization (differentiators):**
7. Coach PDF report (Medium complexity, monetization lever for Coach tier)
8. Readiness-adjusted weekly plan suggestion (Medium complexity, extends autoregulation)
9. Behavior tagging with correlation (Medium complexity, engagement driver)

**Defer:** AI chatbot, manual periodization planner, social features, real-time analytics.

**Rationale:** Phase 1 gets Tonus to competitive parity on analytics. Phase 2 creates genuine differentiation -- no strength-focused app does automatic fatigue pattern detection or periodization awareness. Phase 3 deepens coach monetization and personal engagement. Each phase builds on the data and visualization foundation of the previous one.

## Sources

- [WHOOP Weekly Performance Assessment](https://www.whoop.com/eu/en/thelocker/new-weekly-performance-assessment/)
- [WHOOP 2026 Feature Updates -- Behavior Trends and Insights](https://www.whoop.com/us/en/thelocker/2026-whats-new/)
- [WHOOP Trend Views](https://www.whoop.com/us/en/thelocker/track-progress-with-new-trend-views/)
- [TrainingPeaks Athlete Features](https://www.trainingpeaks.com/athlete-features/)
- [TrainingPeaks Annual Training Plan Guide](https://www.trainingpeaks.com/learn/articles/the-comprehensive-guide-to-creating-an-annual-training-plan/)
- [TrainingPeaks Data Export](https://help.trainingpeaks.com/hc/en-us/articles/204985370-Data-Export)
- [HRV4Training -- Longitudinal Load Analysis (ResearchGate)](https://www.researchgate.net/publication/309338230_HRV4Training_Large-scale_longitudinal_training_load_analysis_in_unconstrained_free-living_settings_using_a_smartphone_application)
- [Strong App CSV Export](https://help.strongapp.io/article/235-export-workout-data)
- [Oura Reports](https://support.ouraring.com/hc/en-us/articles/360046061373-Oura-Reports)
- [AthleteMonitoring Sample Reports](https://www.athletemonitoring.com/athlete-monitoring-sample-reports/)
- [Monitoring Training Load to Understand Fatigue in Athletes (PMC)](https://pmc.ncbi.nlm.nih.gov/articles/PMC4213373/)
- [myTrainingForecast -- ACR Injury Prevention](https://mytrainingforecast.run)
