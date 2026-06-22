---
title: Core Redefinition — Plan-Aware Decision Support Engine
date: 2026-06-12
context: /gsd-explore session redefining core function + PMF after drift; user-validated via Socratic Q&A + 2 research passes (competitive + sports science)
---

# Tuwa Core Redefinition (2026-06-12)

## Identity statement

> **Tuwa = the sports-science staff for self-coached athletes.** The athlete (or their coach) authors the program. Tuwa ingests it whole — blocks, weeks, periodization position — fuses it with physiology, and does what a pro team's back room does: adjusts today's numbers, issues go/modify/hold verdicts, forecasts overreach before the deload. One body, one fatigue budget, across sport skill + strength + conditioning. It never writes the program. It never makes you chat with it.

## Why the redefinition

App drifted toward generic readiness/load monitoring — Whoop/Bevel home turf. Primary intention (founder = primary user): pro-team-level load management and training-volume decision support for an amateur serious **self-training hybrid athlete** who authors his own plan now and will work with skill + S&C coaches later. Monitoring exists only to feed decisions.

## Core function — three horizons

App must know: **full program structure** (blocks/mesocycles, weekly structure, per-session exercises×sets×intensity) + **periodization position** ("week 3 of 4, accumulation, deload in 2 weeks").

| Horizon | Output |
|---|---|
| Today | (1) **Adjust the numbers** — concrete modulation within plan intent ("top set to 85%, cut 2 back-off sets, keep accessories"); (2) **Go/modify/hold verdict** with plain-language reasoning |
| Mid-term | **Forecast ahead** — fatigue trajectory vs remaining block; "at current trajectory you hit overreach before deload; pull deload 1 week earlier" |
| Long-term | Response profiling — how THIS body responds to block types over months |

**Explicitly rejected:** conversational AI coach (user skipped it). LLM = engine behind structured outputs (plan parsing, reasoned adjustments), not chat UI. Keeps product deterministic, liability-bounded, distinct from AI-chatbot slop.

## Target user (sharpened)

Amateur **serious self-coached hybrid athlete**: trains sport skill + strength + conditioning in parallel, hard, without professional coaching/physio/sports-science access today; may engage professional coaches later (app stays the decision/data layer either way). Founder is the reference user.

## PMF / anti-positioning

Competitive research (2026-06-12, sourced):

- **Every product that modulates training owns the program** (Whoop targets, JuggernautAI, RP templates, Athletica, JOIN, Cora).
- **Every product that accepts a user/coach-authored plan refuses to modulate it** (TrainingPeaks — by design, analysis only), routes readiness to a human (TrainHeroic), or has no wearable signal (RP).
- Nobody unifies strength + sport-skill + conditioning in one fatigue model with verdicts + forecasting.

**Open gap Tuwa owns: readiness-driven modulation of a USER-AUTHORED hybrid plan with periodization-position awareness.**

Anti-positioning one-liners:
- Whoop/Bevel: scores without your plan.
- AI-coach apps (Juggernaut/RP/Cora): their plan, not yours.
- TrainingPeaks: your plan, no decisions.
- **Tuwa: your plan, made safe and optimal.**

## Validation outcome (2026-06-13) — online discovery + adversarial pressure-test

Tested the thesis against **51 real online self-coached hybrid athletes** (mined public posts, not live interviews) + 5 adversarial thesis-kills. Full evidence: `.planning/research/discovery-self-coached-hybrid-athletes.md` + `.planning/research/plan-aware-thesis-pressure-test.md`.

**Verdict: MODIFY-SCOPE — go on a narrow wedge, not the full three-horizon thesis.** All 5 kill-lenses landed "weakened" (none killed, none clean-survive).

- **PROBLEM is the most validated thing in the corpus.** ≥5 target athletes built their own readiness→plan adjusters out of frustration (HybridLoad, GreenInvestigator817's Garmin utility, Runphatic, daily-LLM workflows). Revealed preference, not opinion.
- **TODAY horizon = the wedge (GO).** Strongest demand + lowest build cost. MID horizon = real but **latent** (discovered too late; build later, don't lead). LONG horizon (response profiling) = **near-zero demand → HOLD**, never a pricing/acquisition assumption.
- **Hybrid-blind recovery score = strongest, most ownable wedge** — same complaint surfaced unprompted across Whoop, Garmin, Oura, Bevel users ("recovered for *what*?"). Pairs with one-fatigue-budget claim.
- **Anti-positioning validated near-verbatim** (itarrow: "I want it about my data, not selling me a new plan"). No-chat-coach + never-writes-program survive.
- **Two real cracks:** (1) **autonomy/identity** — experienced self-coached athletes prize "I autoregulate myself"; verdict must be **suggest-and-confirm, feel-overridable, never overwrite** (now a hard product constraint, tightens MOD-03). (2) **WTP is the genuine soft spot** — zero stated prices, build-not-buy is the defining buyer trait, Whoop churns on "a score I don't act on." **Validate WTP before building mid/long.**
- **UX landmine:** nocebo — a pre-session "hold" can poison the session. Frame as number+reason, not a red don't-train gate.
- **Commoditization clock:** Garmin building per-muscle "Neuromuscular Readiness" for 2026; Whoop Strength Trainer imports plans via screenshot. Wedge is one feature-flag from erosion — move fast, lean on cross-modal + plan-ownership.

**Single core interaction to build/validate first (playbook "build only that, put in front of 5"):** the plan-aware **TODAY verdict for a single strength session** — "here's the adjusted top-set number + one-line why, your call to confirm" — with a **cross-modal fatigue input** (yesterday's run hits today's squat, barely touches bench). That cross-modal anchor is what makes it Tuwa and not Garmin. Do NOT build mid/long until WTP clears. 5-person interview guide (screener + past-behavior + disconfirming questions + green-light signal) lives in the pressure-test doc.

**Honest limitation:** mined forum voices over-represent DIY-builders + identity-purists, under-represent the silent median who might just buy. WTP read is least trustworthy. Real live interviews + money-on-table still required.

## Science stack (research pass 2026-06-12)

- **sRPE (Foster, RPE×duration)** — gold-standard common currency across modalities → hybrid unification backbone. STRONG.
- **APRE/RIR autoregulation > %1RM** (2025 network meta-analysis; APRE highest efficacy) → basis for "adjust the numbers". STRONG.
- **HRV-guided**: credible only with individual rolling baselines (Altini-style rolling mean ± SWC). MODERATE; already in locked algo v1.
- **ACWR**: criticized/trending deprecated as decision rule → locked "ACWR-out dual-run" decision validated.
- **Local (per-muscle) vs systemic load split**: emerging frontier, not yet in consumer market → locked per-muscle strength load is ahead.
- **Wellness questionnaires (Hooper)** — best single acute-load predictor (R²≈0.45); cheap daily signal.
- **Monotony/strain (Foster)** — useful flagging layer (matches deferred Foster seed).

## Relation to locked Algorithm v1 scope

Locked v1 (per-muscle strength load, ACWR-out dual-run, Altini baselines, honest strain-risk) = **validated by research, unchanged**. Redefinition adds the missing layer ON TOP: **plan-awareness** (ingestion, periodization position, modulation, forecast). v1.3 LLM import (parse workout → template) is the seed of plan ingestion — extend from single-workout parsing to full-program parsing.

## What stays / what changes

- Stays: recovery scoring, load tracking, per-muscle taxonomy, cycle-aware baselines, self-coached single-tier model (v1.5 reset), no-chat-coach, no-program-generation.
- Changes: forward plan = new core object; modulation engine; forecast engine; PMF copy/ASO repositioned around "your plan, made safe and optimal".
- Coach future: re-enters as **plan author + data reviewer**, not roster manager (see seed `coach-as-plan-author`).

## New requirements

PLAN-01..03, MOD-01..03, LOAD-01..02, FCST-01..02 — appended to REQUIREMENTS.md under "Core Redefinition Requirements (unscheduled)" 2026-06-12.
