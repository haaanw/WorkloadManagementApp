---
title: v2.1 "Basketball Beachhead" — milestone plan (grill session output)
date: 2026-07-07
context: /grill-with-docs session 2026-07-06/07. Niche pivot + full release plan (app, UI polish, store, website) with hybrid Claude Code ⇄ Codex workflow. Decisions recorded in CONTEXT.md, docs/adr/0001-0002, .planning/notes/dogfood-protocol-n1.md.
---

# v2.1 Basketball Beachhead — Plan

## Decisions this milestone rests on

1. **Niche = amateur competitive basketball players who also strength-train** (ADR-0001). "Hybrid athlete" avoided (market collision). Founder = reference user. Multi-sport (swim/climb/MA) = later depth roadmap, not launch positioning.
2. **Verdict direction = backward carry + match-proximity rule** (ADR-0002). One optional "next match" date, one rule (≤48h → tighten bound, microdose framing). NO trajectory forecasting (MID stays behind WTP gate).
3. **Match tier** (pickup → scrimmage → match): tier decides protection, not fatigue. Protection binary — only scheduled matches trigger proximity; serious scrimmage handled by *promotion* (athlete schedules it as match). All tiers produce carry.
4. **Microdose** = the proximity trim shape (athlete's own session → 1–2 capped top sets, no back-offs). Fixed shape at launch; user-template swap = fast-follow. Never app-initiated sessions (never-writes-program fence).
5. **Validation = n=1 founder dogfood**, pre-registered criteria in `.planning/notes/dogfood-protocol-n1.md`. WTP gate stays closed.
6. **Prep-now, publish-at-gate**: store + website assets built during dogfood window, nothing public until criteria pass.

## Timeline

```
Wk 0–2   TRACK 1 (engine delta) + TRACK 2 (UI polish)  → TestFlight build
Wk 2–8   DOGFOOD WINDOW (6 in-season weeks, pre-registered)
          ├─ TRACK 3 store prep      (Claude + Codex copy)
          └─ TRACK 4 website         (Codex owns)
Wk 8     GATE — criteria review
          PASS → App Store submit + website deploy + ASO live
          FAIL → engine tune loop; assets stay drafted; repeat window
```

## Track 1 — Engine/product delta (Phase 46, app repo, Claude via GSD)

| # | Item | Size |
|---|---|---|
| 1 | Retune `teamSport` β → basketball-shaped (legs ~0.9, core 0.3, upper ~0.1) + `// basketball-shaped priors (beachhead)` HEURISTIC comment. Pre-launch, no real teamSport users — safe. | XS |
| 2 | Match-tier picker at log time (pickup/scrimmage/match); carry multiplier (~×1.3) on match+scrimmage only | S |
| 3 | "Next match" optional date field + flexible schedule section (empty state = no scheduled match, verdict backward-only) | S |
| 4 | Proximity rule in verdict bound (≤48h → cap top set, cut back-offs) + microdose reason copy | M |
| 5 | Microdose vocabulary on verdict card + zh-Hans keys (incl. 4 outstanding strike-zone keys) | XS |
| 6 | Dogfood logging: next-day "felt right?" capture on differing-verdict days (extend VerdictEvent as needed) | S |

**Fenced OUT:** match-day morning card (fast-follow post-gate), microdose template-swap, `.basketball` enum case, MID/forecast math, recurring-schedule objects.

**Pre-req (Stage 0 check):** confirm main is green + pushed (post git-recovery state f4529d4).

## Track 2 — UI polish ("solid foundation, elevate details")

`/ios-design-review` on device against DESIGN.md → findings → fix pass → re-review. Codex second-opinions the findings list. Merges before TestFlight build.

## Track 3 — Store repositioning (PREP ONLY until gate)

- ASO keyword research: basketball niche ("basketball training load", "stay fresh for game day", strike zone, microdose)
- Title/subtitle/description rewrite; anti-positioning intact ("your plan, made safe and optimal")
- Screenshot re-shoot: existing `SCREENSHOT_MODE` pipeline + `scripts/frame_screenshots.swift`, basketball-flavored seed data (match sessions, microdose verdict card)
- Codex drafts copy; Claude verifies every claim against shipped code (verify-before-claiming rule)

## Track 4 — Website tuwa.app (CODEX OWNS, prep only until gate)

- Repo: `~/Desktop/tuwa-website` (Astro, Cloudflare, own CLAUDE.md + SEO_GEO_PLAN.md)
- Reposition hero/copy to beachhead; vocabulary synced from app repo `CONTEXT.md`
- Claude reviews Codex diffs + audits claims

## Hybrid Claude ⇄ Codex workflow

| | Claude Code | Codex |
|---|---|---|
| Builds | Tracks 1–2, screenshot pipeline (app repo) | Track 4 (website repo) + Track 3 copy/ASO research drafts |
| Reviews | Codex website diffs + copy audit | Claude phase plans (before execute) + diffs (after) |
| Cadence | per-phase cross-verification, not end-of-milestone | same |
| Disagreements | surfaced to user, never auto-resolved | same |

Codex gets more load where work is text/separable (website, ASO research, copy). App-repo Swift stays Claude-owned (GSD + build verification).

## Gate criteria

See `.planning/notes/dogfood-protocol-n1.md` — 5 pre-registered criteria, pass/fail outcomes. Criteria are not bendable after the window starts.
