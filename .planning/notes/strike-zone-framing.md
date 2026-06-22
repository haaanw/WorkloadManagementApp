---
title: "Strike Zone" — the organizing metaphor + visualization for v2's verdict
date: 2026-06-14
context: User shared pjfperformance Instagram post (instagram.com/p/DZflaj8iesG) as the concept they want for their profile — "help me stay in the strike zone every workout"
---

# Strike Zone framing

## The concept (pjfperformance)
> "Understanding that strike zone in your training is crucial — but understanding that the strike zone MOVES day to day based on your current state is key." Be "CEO of your own body": dose training responsively to daily readiness/recovery, instead of rigidly following a predetermined program.

Strike zone = the optimal training-intensity BAND (enough stimulus to adapt, not so much you overreach/get hurt) that **shifts every day** with the athlete's physical + mental state.

## Why this is v2, not a new direction
This is the cleanest articulation of the validated v2.0 thesis. Direct mapping:

| Strike-zone idea | v2.0 mechanism |
|---|---|
| The zone moves day to day with your state | Engine recomputes readiness + accumulated/cross-modal fatigue daily (ACT-01/02, Phases 41) |
| Stay in the strike zone *this* workout | The TODAY verdict: go/modify/hold + adjusted top-set number nudges today's PLANNED lift into the zone (Phase 43) |
| Be CEO of your own body (intuition, not rigid program) | Suggest-and-confirm + feel-override-as-input — athlete stays the decision-maker; app quantifies the zone, never dictates (Phase 44). Matches the pressure-test's autonomy finding exactly. |
| Responsive dosing of YOUR plan, not one-size-fits-all | "Modulate a user-authored plan" — the core redefinition ([[tuwa-core-redefinition-plan-aware]]) |

User is the reference user; "help me stay in the strike zone every workout" = the user-facing promise of the verdict. Use it as the headline value prop / ASO line.

## Product idea surfaced (strong fast-follow, NOT a re-scope)
A **strike-zone visualization** as the verdict card's hero framing: render the daily band + where today's planned session LANDS relative to it + the verdict's nudge that moves it into the zone. Benefits:
- Satisfies the anti-nocebo rule (SC4): lead with the zone + action-on-plan, not a bare readiness number.
- Makes the abstract verdict concrete and glanceable ("you're above the zone today → trim the top set to land in it").
- Turns the metaphor into the product's signature visual.

Candidate placement: an enhancement to the Phase-44 `TodayVerdictCard`.

**BUILT 2026-06-15 (commit bb80e8f):** treatment B (number-led) shipped on `TodayVerdictCard` — today's number leads big, a compact `StrikeZoneBar` (muted-sage zone lane + in-zone white dot = today's number + faint planned reference tick when trimmed) sits under it, caption "IN TODAY'S ZONE" / "RIGHT IN YOUR ZONE". Zone band is display-only (tolerance centered on the engine's adjusted number — no new engine math). DESIGN-compliant (0pt, hairlines, ColorTokens, no accent on card), anti-nocebo intact, guard tests green. Followup: zh-Hans for 4 new keys (`verdictCard.fromPlanned`, `.zone.in`, `.zone.right`, `.zone.a11y`) — currently en-fallback. Built atop the cool/precise reskin (commits 5e01fd5 + 1dbed36).

## Copy direction
- Value prop: "Stay in your strike zone — every workout." / "Your strike zone moves daily. Tuwa keeps you in it."
- Positioning stays: your plan, made safe and optimal; you're the CEO, Tuwa is the back room.

Relates to [[tuwa-core-redefinition-plan-aware]], v2 verdict surface (Phase 44), [[core-target-user-group-narrowed]].
