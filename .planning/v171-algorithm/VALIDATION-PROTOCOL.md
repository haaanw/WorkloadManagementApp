# Pre-registered validation protocol — recovery score v1 vs v2

**Written 2026-08-09, BEFORE any outcome data exists.** That is the point. Deciding the bar
after seeing the data is how you talk yourself into an answer, so the criteria below are fixed
now and any later change must be recorded as an amendment with its reason and date.

## The question

The live recovery score (v1) derives HRV and RHR from a ratio to a flat 7-value mean. The
shadow arm (v2) derives them from a personal z against a robust baseline (EWMA half-life, MAD
scale with a σ floor, Huber-clipped folding, persisted via `BaselineCheckpoint`). Both use the
same components, the same weights, and the same sleep and wellness values. **Should v2 replace
v1?**

## Why the obvious outcomes were rejected

An outcome is valid only if it is **not an input** to either score and **not influenced by
seeing** a score.

| Candidate | Rejected because |
|---|---|
| Wellness check-in | It is 25% of BOTH scores. Grading with it rewards whichever arm leans on it hardest, regardless of physiology. |
| Post-session "felt right" | The athlete saw the morning verdict; the rating is partly a reaction to it. Already rejected on the same grounds in the sleep-v2 review. |
| Next-day HRV | Looks independent, is not. HRV is strongly autocorrelated day to day and both arms contain today's HRV, so the arm weighting HRV harder wins on arithmetic rather than insight. |
| Plan adherence | The most contaminated of all: if the app prescribed a 10% cut, completing the cut plan proves nothing. |

## The outcomes actually collected

All four are recorded on `RecoveryShadowDay` beside both arms, and a source-level fence
(`MorningReadinessProbeTests`) asserts no scoring engine reads any of them.

**1. Perceived readiness (PRIMARY).** 1–10, answered before the dashboard renders any score,
opt-in via Profile → Algorithm validation. It is the only measure that targets exactly what the
score claims to estimate — the athlete's own version of the score's output, not another symptom
rating. Deliberately a different scale from the app's 1–5 wellness ratings so it cannot be
confused with an input.

**Blinding is recorded, not assumed.** `wasBlinded` is true only when no score had been shown
yet that day. Non-blinded rows are kept as data and **excluded from every criterion below**.

**2. Morning grip strength (STRONGEST OBJECTIVE, sparse).** Optional, needs a dynamometer.
Best of 3 attempts, same hand, same posture, recorded on waking. Unlike everything else here it
is a *performance* measurement, so it cannot be talked into a better number by optimism. Limits
stated up front: single readings are noisy, and it indexes neuromuscular readiness specifically,
which overlaps with but is not identical to systemic recovery.

**3. Overnight wrist temperature (FREE).** Already collected, scored by nothing. Blunt — it
moves clearly when something is genuinely wrong, less so across ordinary days — but costs the
athlete nothing and cannot be influenced by expectation.

**4. Overnight respiratory rate (FREE).** Newly read from HealthKit, scored by nothing. A
recognised overnight recovery and illness signal, fully independent of both arms.

## The design: score only the disagreement days

Two scores built from the same four inputs agree most days, and agreeing days carry almost no
information about which is better. Analysis therefore restricts to **disagreement days**:

- **Zone disagreement** — the arms fall in different recovery zones. These are the only
  differences that would change a recommendation, so they are the primary stratum.
- **Material numeric disagreement** — |v1 − v2| ≥ 8 points, roughly a quarter of a zone band.

This turns an underpowered n=1 comparison into a tractable one, at the cost of needing enough
days to accumulate disagreements.

## Criteria — fixed in advance

**Gate 0 — enough evidence to look at all.** No conclusion before ALL of:
- ≥ 40 days with both arms scored and a blinded probe;
- ≥ 12 disagreement days by either definition above;
- ≥ 20 days where `hrvConfidence` ≥ 0.5 (below that the estimator itself says it does not know).

If Gate 0 is unmet at review time, the answer is "keep collecting", not a weaker conclusion.

**Gate 1 — divergence characterisation (leak-free, available now).** Report, do not judge:
mean and max |v1 − v2|, signed mean, rank correlation between arms, zone-disagreement rate.
If the arms rank days near-identically and differ only by a level shift, the flip is low-stakes
whichever is theoretically better — and that alone may settle it.

**Gate 2 — criterion validity on disagreement days.** On blinded disagreement days, compare
each arm against perceived readiness by Spearman correlation. v2 is preferred only if:
- ρ(v2, perceived) > ρ(v1, perceived), AND
- the paired bootstrap 95% CI for that difference excludes zero.

**Gate 3 — objective corroboration.** The objective outcomes must not contradict Gate 2. With
≥ 10 grip readings on disagreement days, the same comparison is run on grip; where grip is too
sparse, wrist temperature and respiratory rate are used directionally. **A Gate 2 pass with a
clear Gate 3 contradiction does not flip the score** — it means the subjective probe and the
body disagree, which is a finding to investigate, not a mandate.

**Trend is off in every comparison.** v1's trend modifier autoregresses on its own past output;
leaving it in would confound an estimator change with accumulated inertia. Both stored scores
are pre-trend for this reason.

## What a pass and a failure each mean

- **Pass all gates** → HAN may flip the activation. No code flips it; the analysis is
  report-only and a source-level fence enforces that.
- **Fail Gate 2** → v1 stays. v2 is not "wrong", it is unproven on this athlete's data.
- **Gate 1 shows near-identical ranking** → the choice is not empirical; prefer v1 for
  continuity, since changing numbers the athlete has learned to read has its own cost.

## Honest limitations, recorded now

- **n = 1.** Nothing here generalises to other athletes. It answers "should this athlete's
  score change", not "which estimator is better".
- **Apple writes SDNN**, while most readiness research uses standardised LnRMSSD. The
  reduction is defensible noise control, not validation of the underlying algorithm.
- **The probe is one person's judgement**, and self-report drifts as an athlete learns the app.
- **Grip will be sparse.** Treat it as corroboration, never as the primary criterion.
- **The 11:00 morning window is a heuristic.** Wake-relative windowing remains the principled
  version and is deferred.
