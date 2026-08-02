# Sleep score composition — parliament synthesis (chair ruling, 2026-08-02)

Motion: final scoring composition under HAN's 80/20 ruling (duration alone caps the
composite at 80; quality earns the last 20). Members: Codex (confidence 0.87), Grok
(0.74), chair = the orchestrator session (position pre-registered before reading either).
Full transcript: `.planning/sleep-v2/parliament-transcript-2026-08-02.txt`.

## Unanimous (adopted)

1. **Reject the plateau + headroom-gain mechanism** (S1's H-12). Both members: the gain
   constant hides the 80/20 rule. The chair's pre-registered position had kept it for
   minimal churn — outvoted by a better argument: the founder's rule should be *visible
   in the arithmetic*, not derivable from it.
2. **Adopt the explicit two-part composition:**
   `score = 0.80 × D + Σ pᵢ × clamp((Cᵢ − 80) / 20, −1, +1)`
   where D = the 0–100 duration-vs-need curve (so duration contributes exactly 0–80),
   Cᵢ = each quality component's 0–100 curve value, pᵢ = its point allocation.
   Signed (Codex's correction of Grok): sub-baseline quality SUBTRACTS — a fragmented
   night on real WASO data must read worse than its hours alone. The symmetric ±1 clamp
   is the CHAIR's addition: it bounds the downside at −20 total (a need-met night with
   catastrophic quality floors at 60, comparable to the old blend's 62.5), preserving
   the nocebo guard that unbounded signed adjustment (Codex) would break and the
   sub-baseline signal that clamp-at-zero (Grok's opening) would erase.
3. **Every quality curve's "met/normal" point re-anchors to 80** so met adds exactly
   zero bonus (Grok's rebuttal catch of Codex's residual 85: met-at-85 would silently
   hand back a free 5 points). Stage curve: q=1.00 → 80, q≥1.30 → 100, 0.85 → 75;
   sub-baseline anchors 0.40→45, 0.55→55, 0.70→70 and the 45 floor stay (athlete-
   shifted, Leeder SE ≈80.6%).
4. **Quality points do NOT renormalize over missing components** (epistemic-cap
   principle, both members). Chair correction of both members' numbers: their 90/94
   Tier-C caps were carried from the OLD renormalizing arithmetic. Under the adopted
   point pool the caps fall out naturally with zero new constants:
   Tier A max 100 · Tier B (no in-bed span: no continuity) max 92 · Tier C
   timing-only max 85, with continuity 93. Missing evidence simply cannot testify.
5. **Context profiles touch only the 20-point pool.** Duration's 80 budget is fixed;
   sleep-pressure/strain/debt effects act on `needTonight` (§4's continuous credits),
   never on duration's share. §9.3's weight deltas are re-expressed as point transfers
   within the pool, preserving each profile's internal ratios; duration-side deltas are
   DROPPED as double-counting (the need credits already move the same lever).
6. Tier D stays bit-identical to the legacy curve (exempt by design); Tier E nil.

## Split decision (chair rules)

**Quality point allocation.** Codex: continuity 8 / regularity 6 / deep 3 / REM 3.
Grok final: 8 / 5 / 3.5 / 3.5. Chair pre-registered 6/6/4/4 — both members put
continuity first at 8 on grounds the chair accepts (Chinoy: sleep/wake detection is the
honest wearable signal; stage κ 0.21–0.53 caps stage authority; Leeder: athletes are
systematically fragmented, so continuity is where athlete-shifted anchoring matters).
**Ruling: 8 / 5 / 3.5 / 3.5** — Grok's regularity-5 argument is decisive on registry
hygiene: Windred 2024 is a *mortality* endpoint and cannot fund a next-day-readiness
weight of 6; overclaiming a citation is the exact failure §9.5 exists to prevent.

## Registry consequences (all rows carry kill tests)

- H-11 REVISED: stage met point 85 → 80; excellent q≥1.30 → 100 unchanged, <2%
  reachability test unchanged; 0.85 anchor → 75.
- H-12 RETIRED (headroom gain) → replaced by **H-16**: the two-part composition with
  the ±1 clamp and point vector 8/5/3.5/3.5. Kill tests: (a) partial-r ≤ 0 for any
  component vs sleep-free next-day readiness at ≥200 nights/≥20 athletes drops that
  component's points; (b) if HAN's felt-right log shows need-met nights systematically
  scored above/below ~80, the met anchors are wrong; (c) if no night reaches 100 in
  ≥60 nights, the excellent anchors are unreachable and move to observed p90.
- **H-17** (new): tier maxima as epistemic caps (B 92 / C 85–93). Kill test (Codex's,
  adopted): mask Tier-A nights down to Tier C; if masked scores predict full Tier-A
  scores with MAE ≤ 3 over ≥200 paired nights, the caps are too conservative.
- **H-18** (new): profile deltas as point transfers with preserved ratios. Kill test:
  H-13's chatter counts plus shadow comparison of per-profile score deltas vs the old
  weight-delta arithmetic on the same nights (divergence > 5 pts on >10% of profile
  nights = translation wrong, revisit).

## What HAN's 80-point ruling changed downstream

Old (S1 as committed): need-met typical night ≈85; Tier-C max 90.
New: need-met typical night = exactly 80; quality visibly earns/loses the last 20;
Tier-C max 85/93; every quality curve shares one semantic zero ("80 = your normal").
Athlete sentence (per the council's explainability criterion): "Hours get you to 80.
Sleeping better than your usual — unbroken, on schedule, deep — earns the last 20."
