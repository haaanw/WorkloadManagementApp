# Tuwa product facts — ground truth for article claims (as of 1.7.2, 2026-08-30)

The Claude Project has no access to the codebase. This file is the shipped-vs-
unshipped ledger every article claim must check against. When an article needs a
fact not listed here, it gets flagged for verification against the repo — never
assumed.

## The product, one paragraph

Tuwa (iOS, App Store) is the sports-science staff layer for self-coached
athletes — people who train sport skill + strength + conditioning in parallel
with no professional support. The athlete authors the training program; Tuwa
never writes it. It fuses the plan with physiology (HRV, resting heart rate,
sleep, training history from Apple Health) and gives a daily verdict: go as
written, trim, or hold — a number and a reason. Beachhead: amateur competitive
basketball players who also strength-train. Never say "hybrid athlete."
Canonical zh term for readiness: 准备度.

## SHIPPED (live in 1.7.2 — full present-tense claims allowed)

- Natural-language workout logging: speak, type, or keyboard-dictate; an LLM
  (DeepSeek, server-side) parses the TEXT into an editable draft; nothing saves
  without confirmation; local parser handles live per-set utterances offline.
  Free on every tier. The LLM is a parser, never a chat coach.
- Daily readiness verdict (go / modify / hold) with the adjusted number and a
  one-line reason; match-proximity awareness (microdose near game day);
  keeping the plan as written always one equal-weight tap (nocebo guard).
- Training load: session TSS → EWMA acute/chronic → ACWR with spike detection;
  one load curve across court time, lifting, conditioning ("one fatigue
  budget"). Per-session RPE stays a continuous 1–10 scale.
- Recovery score from HRV + RHR + sleep + subjective wellness. HRV = morning-
  window daily median scored against the athlete's own rolling robust baseline
  (EWMA + MAD, today excluded from its own baseline); RHR = calendar-day
  aggregate deliberately unfiltered by hour. Sleep v1 scores duration against a
  fixed 7.5 h target; nights are cluster-reduced to the dominant source
  (naps separated).
- Bodyweight sets carry load (0 kg = bodyweight by convention, relative-
  intensity guarded) — shipped 1.7.2.
- Movement bank: 1,324-exercise catalog. Set entry: always-visible scrub scale
  with TARGET and LAST markers.
- Privacy: raw HealthKit data never leaves the device; only composite scores
  sync. Submitted workout TEXT goes to the parse service (disclosed in the
  privacy policy).

## UNSHIPPED / DARK (name as non-shipping or do not mention)

- **Sleep score v2** (stage-aware, personalized need): built, runs SHADOW-ONLY
  on real nights, drives nothing a user sees. Pre-registered ≥6-week dogfood
  gates it. May be discussed as an open design question, never as product.
- **Recovery estimator v2** (robust-z): runs dark beside v1; pre-registered
  blinded validation (morning probe, optional grip) gates any flip.
- **No forecasting.** The app refuses future-projection features by recorded
  ADR. This is a Decision-article asset, not a gap to apologize for.
- **No nutrition tracking, no time-of-day inference, no gait/footwear stake,
  no accelerometry.** RED-S engine exists but is orphaned/unreachable — never
  present it as product.
- In progress for the next release (not shipped, do not reference as live):
  home-screen widgets, redesigned onboarding.

## Standing language rules

- Training/education content, not medical advice; no diagnosis, treatment, or
  prevention claims.
- Evidence graded honestly ("one n=12 study suggests…"); every citation opened
  and read before it appears.
- App name is Tuwa only (Faros/Tonus/Tutrice are dead names, never use).
