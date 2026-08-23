# v1.7.3 parallel lane — marketing (SEO + GEO + Twitter-first social)

Status: QUEUED (HAN, 2026-08-22). Runs in parallel with v1.7.3 app work.
Nothing starts until v1.7.2 closes. This file is the to-do and the direction
record so the lane opens without re-litigating.

## Decisions taken (HAN, 2026-08-22)

- Primary social platform: **Twitter/X**. Instagram is secondary (repurposed
  video only, if at all).
- The existing Twitter account stays a **personal solo-developer account**
  (notes + thoughts). Strategy must build on that voice, not replace it with a
  brand account.
- ASO stays in v1.7.2 Objective 3 (Lane C) — this lane is website SEO/GEO +
  social, NOT the App Store listing.

## Workstreams

### 1. Website SEO (tuwa-website — coordinate with CODEX lane)

Existing groundwork: `[...seoGeo].astro` programmatic route, feature pages,
`blog/`, `compare.astro`, `methodology.astro`, three locales (en/zh/fr).
To do: keyword-to-page mapping against the beachhead queries (basketball +
lifting readiness, ACWR, HRV training decisions); title/meta/heading audit;
internal linking; Search Console baseline before any change so movement is
measurable; page-speed pass.

### 2. GEO — generative engine optimization

Goal: be the cited source when ChatGPT/Claude/Perplexity answer questions like
"how much should I lift the day after a basketball game". Mechanics: fact-dense
methodology/FAQ pages with direct answers high on the page; schema.org markup
(FAQPage, SoftwareApplication, Article); consistent entity naming (Tuwa +
category terms); the §10 claim rails apply — engines quote text verbatim, an
overclaim becomes a quoted overclaim.

### 2b. Science series — the SEO/GEO content engine (HAN 2026-08-24)

A research-article series on the site's existing blog
(`src/content/blog/`, one post today). Brief + editorial rules:
`.planning/v173/SCIENCE-SERIES.md`. Scope is frontier sports science
broadly — the fatigue/readiness algorithms Tuwa uses, sleep, gait,
barefoot footwear, physiology — not just workload management. This series
IS the GEO play: fact-dense, citation-backed pages are what answer
engines quote.

### 3. Twitter (primary)

**Voice logging is the marketing spearhead across ALL channels (HAN
2026-08-24)** — not a website-only item. The launch thread, the demo screen
recordings, the first Reels, and the compare-page row all lead with it.

Direction: build-in-public from the personal account; the founder IS the
reference user, so the n=1 dogfood is the content. Pillars: (a) dev/build
notes (already native to the account); (b) real training decisions shown in
the app — readiness verdicts, load charts, the morning probe; (c) short
sports-science explainers targeted at basketball-players-who-lift; (d) ship
moments with screen recordings (voice logging is the flagship demo). Pinned
launch thread when 1.7.2 ships. Bio gets the tuwa.app link. Engagement target:
basketball-training and strength-training communities, NOT generic #buildinpublic
only. Cadence proposal, thread templates, and a 4-week content calendar are the
lane's first deliverable — drafts only, HAN posts everything (outward-facing
rule).

### 4. Instagram (secondary, optional)

Repurpose the Twitter screen recordings as Reels. No separate content pipeline.
Decide at lane open whether it is worth the overhead at all.

## Constraints

- All posting, account changes, and publishing are HAN-only (§4 outward rule).
  Agents draft; HAN ships.
- Claims grade to engine status (§10): sleep-score v2 and estimator v2 are
  unshipped — no marketing claim ahead of the engines.
- Vocabulary: never "hybrid athlete" in positioning; canonical terms in
  CONTEXT.md; app name is Tuwa only.
- Website surfaces belong to the CODEX lane historically — settle ownership on
  the pair board when the lane opens.
