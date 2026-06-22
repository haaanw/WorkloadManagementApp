# Positioning And Strategy

Last updated: 2026-06-06

## Strategic Vote

Five possible positions were evaluated:

| Option | Vote | Reason |
|---|---:|---|
| Generic Apple Watch recovery app | No | Athlytic, Bevel, Cora, Gentler Streak, Rekov, FITIV, and Apple itself crowd this lane. |
| Broad AI health coach | No | Google Health, Bevel, Cora, and many new apps are already racing here. Too broad and expensive to defend. |
| Pure strength logger | No | Strong, Hevy, Boostcamp, and RP already own much of this behavior. |
| Coach platform for all sports | Not yet | TrainingPeaks and coach software are entrenched. Coach mode can be a wedge, not the whole company at launch. |
| Explainable adaptive strength and hybrid self-coach | Yes | This is specific, useful, tied to current product strengths, and less directly owned by incumbents. |

## Recommended Position

> Tuwa is an explainable self-coaching system for serious strength and hybrid athletes. It combines your workout plan, workout log, Apple Watch recovery signals, recent workload, soreness, RPE, and PR history to adjust today's training and explain why.

## One-Line App Store Positioning

Primary:

> Adaptive strength training from your Apple Watch recovery and workload.

Sharper:

> Know when to push, cut volume, or recover.

Avoid:

> ACWR-based athlete workload management.

ACWR is useful as an internal load-ramping input, but the market-facing promise should be training adjustment, not injury prediction or sports-science jargon.

## Differentiation Pillars

### 1. Session-Level Action

Competitors often stop at a score. Tuwa should tell the athlete what to change:

- Cap RPE.
- Cut volume.
- Swap to lower intensity.
- Keep load but reduce accessories.
- Run the planned session.
- Take recovery.

### 2. Strength And Hybrid Specificity

The initial audience should not be "anyone who wants health insights." It should be:

- Lifters who condition.
- HYROX/CrossFit-style hybrid athletes.
- Tactical and field-sport athletes.
- Serious amateurs running their own program.
- Strength coaches with small rosters.

### 3. Explainability

Users need to trust the advice. Every recommendation should answer:

- What changed?
- What signal caused it?
- How much should I adjust?
- Is this a one-day issue or a trend?

### 4. Privacy And Data Boundaries

Tuwa has a real privacy point: raw HealthKit data should stay on device and only composite scores sync. This matters more as Google, WHOOP, Oura, and other platforms centralize biometric data.

### 5. Weekly Training Review

Daily readiness is crowded. Weekly review is less crowded and more coach-like. Tuwa should own:

- What worked this week.
- What load changed.
- What recovery signals changed.
- Which lifts improved.
- What to adjust next week.

## Market Risks

### Risk 1: The Product Sounds Like A Feature

"Recovery plus training load" is no longer enough. Apple, Google, Garmin, WHOOP, Bevel, and Cora are converging here.

Response: own the workflow, not the metric. Tuwa must be the place where today's workout changes.

### Risk 2: ACWR Trust

ACWR has scientific criticism. Impellizzeri and others argue against using ACWR as a causal injury-reduction recommendation. A 2025 review still analyzes ACWR for injury prediction, but the practical takeaway is to avoid overclaiming.

Response: use ACWR/EWMA as "workload ramping and tolerance context." Do not market injury prediction.

### Risk 3: Strength Logging Friction

If logging is slower than Strong or Hevy, users leave.

Response: optimize repeated sessions, templates, copy-paste import, previous targets, Apple Watch logging, and fast finish flows.

### Risk 4: Broad AI Apps Outmarket Us

Cora, Bevel, and Google will outspend and outship broad AI health features.

Response: sound like a serious training tool, not a general health chatbot.

### Risk 5: Legacy Name Leakage

Tuwa is the product name, but older project material still contains Tonus. If those references leak into screenshots, metadata, support copy, comparison pages, or social posts, the launch will look less coherent.

Response: use Tuwa everywhere public. Treat Tonus as a historical/internal name until old repo and filename references can be cleaned safely.

## Winning Narrative

The strongest narrative is:

> You already have a workout plan. You already have Apple Watch data. The hard part is knowing what to do with both. Tuwa reads your recent training, recovery, soreness, and RPE, then gives you a specific adjustment for today's session.

## Product Strategy

### Must-Have For Launch

- Tuwa name everywhere in public surfaces.
- Clear onboarding: connect HealthKit, choose training type, import or create plan, log first session.
- Daily recommendation tied to a planned or recent workout.
- Explanation card with top factors.
- Fast workout logging.
- Weekly training review.
- Honest science copy: "load ramping," "fatigue trend," "recovery context"; not "injury prediction."

### Next Differentiators

- Strength-specific load by movement pattern or muscle group.
- Program import from text/photo.
- "Adjust today's workout" button that edits planned sets/reps/RPE.
- Coach share link or PDF report.
- Comparison pages and free tools.

### Coach Wedge

Coach mode should be positioned as:

> Give your athletes a self-coaching app that sends you readiness, workload, and compliance without adding enterprise software.

First coach target:

- 1-person or small-team strength/hybrid coaches.
- Coaches serving remote lifters, HYROX, CrossFit, tactical, and field-sport athletes.
- Not large endurance coaching organizations already standardized on TrainingPeaks.

## Pricing Strategy

Current product direction appears to be around $9.99/month and $79.99/year. This is plausible if the promise is adaptive training, planning, and weekly review. It is hard to defend if the promise is only recovery score because Athlytic is $29.99/year and Apple is free.

Recommended launch pricing test:

- Keep monthly around $9.99.
- Use annual around $79.99 if weekly review and adaptive planning are strong.
- Consider a founder annual at $49.99-$59.99 for the first launch cohort to reduce friction and gather data.
- Do not race to the bottom against Athlytic. Instead, justify price against Bevel/Cora by being more specific and against human coaching by being far cheaper.

## Top 10 Strategic Actions

1. Audit launch assets for legacy Tonus references before publishing.
2. Rewrite App Store screenshots around "adjust today's session," not "view your score."
3. Create a free web calculator: "Apple Watch readiness to strength volume adjustment."
4. Publish comparison pages for Athlytic, Bevel, Cora, WHOOP Strength Trainer, Strong, and Hevy.
5. Build a weekly training review feature or artifact as a retention hook.
6. Add import paths from text programs and repeated sessions.
7. Make HealthKit privacy a product surface, not just a policy.
8. De-emphasize ACWR in user-facing copy.
9. Recruit 20 serious strength/hybrid athletes for structured beta interviews.
10. Recruit 5 small coaches and watch their athlete onboarding friction closely.
