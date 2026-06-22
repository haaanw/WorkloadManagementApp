# Tuwa SEO And GEO Execution Plan

Last updated: 2026-06-06

## Strategic Decision

Tuwa should not try to rank as a generic recovery app. The SEO and GEO wedge is:

> Adaptive strength training from Apple Watch recovery, workload, soreness, RPE, and workout history.

The query we want to own is not "What is my recovery score?" It is:

> Given my actual strength or hybrid session, recent workload, HRV, sleep, soreness, and RPE, what should I change today?

GEO means Generative Engine Optimization: making Tuwa appear, get cited, and be accurately summarized in AI answers from Google AI features, ChatGPT search, Perplexity, Gemini, Copilot, and similar systems.

## Current State

Observed in the repo on 2026-06-06:

- Existing public pages are legal/support pages under `docs/`: `privacy.html`, `terms.html`, and `support.html`.
- App Store metadata points to GitHub Pages URLs under `https://haaanw.github.io/WorkloadManagementApp/`.
- No marketing homepage, calculator, blog, guide hub, comparison pages, `robots.txt`, or `sitemap.xml` were found in the current repo.
- The market-intelligence vault already defines the keyword map, competitor set, and strategic vote.

Implication: the first SEO job is not optimization. It is building the crawlable website surface that search engines and AI answer engines can cite.

## Success Metrics

### 30 Days

- Marketing homepage live and indexable.
- `robots.txt` and `sitemap.xml` live.
- Google Search Console and Bing Webmaster Tools verified.
- Free Strength Readiness Calculator page live.
- 4 comparison pages drafted or published.
- 20 target queries checked manually across Google, ChatGPT search, and Perplexity.

### 60 Days

- 10 high-intent pages live.
- At least 30 internal links across homepage, guides, calculator, and comparison pages.
- At least 5 pages indexed in Google.
- First 3 non-branded impressions in Search Console.
- Tuwa appears accurately when asked directly in ChatGPT/Perplexity, even if not yet recommended for generic queries.

### 90 Days

- 18-24 pages live.
- 2-3 pages ranking or appearing for long-tail queries.
- At least 3 third-party discussion surfaces seeded with useful, non-spammy answers.
- AI answer audit shows Tuwa cited or mentioned for at least 2 branded/comparison queries.
- Weekly refresh loop operating from the sub-agent system below.

## Query Map

### Priority 1: Own The Wedge

| Query | Intent | Page |
|---|---|---|
| adaptive strength training app | Commercial | `/` |
| strength training readiness calculator | Tool | `/strength-readiness-calculator` |
| Apple Watch training load for strength training | Informational | `/apple-watch-training-load-for-lifters` |
| how to adjust training when HRV is low | Informational | `/guides/how-to-adjust-training-when-hrv-is-low` |
| how to use HRV for strength training | Informational | `/guides/hrv-for-strength-training` |
| recovery score for lifting | Informational | `/guides/recovery-score-for-lifting` |
| training load vs recovery | Informational | `/guides/training-load-vs-recovery` |

### Priority 2: Capture Competitor Switching Demand

| Query | Intent | Page |
|---|---|---|
| Athlytic alternative for strength training | Commercial comparison | `/comparisons/athlytic-alternative-strength-training` |
| Bevel alternative for lifters | Commercial comparison | `/comparisons/bevel-alternative-lifters` |
| Cora vs Tuwa | Branded comparison | `/comparisons/cora-vs-tuwa` |
| WHOOP Strength Trainer alternative Apple Watch | Commercial comparison | `/comparisons/whoop-strength-trainer-alternative-apple-watch` |
| Strong vs Tuwa | Branded comparison | `/comparisons/strong-vs-tuwa` |
| Hevy vs Tuwa | Branded comparison | `/comparisons/hevy-vs-tuwa` |

### Priority 3: Build Trust

| Query | Intent | Page |
|---|---|---|
| should I train when recovery is low | Informational | `/guides/should-i-train-when-recovery-is-low` |
| how much volume should I cut when tired | Informational | `/guides/how-much-volume-to-cut-when-tired` |
| ACWR explained | Science explainer | `/guides/acwr-explained` |
| RPE based volume adjustment | Tool/guide | `/guides/rpe-volume-adjustment` |
| weekly training review template | Template | `/weekly-training-review-template` |

## Phase Plan

### Phase 0: Decide The Web Surface

Timeline: Days 0-2

Goal: choose where the marketing site lives and make Tuwa consistent.

Actions:

- Decide canonical website domain. Preferred: a real product domain like `tuwa.app`, `trytuwa.com`, or `tuwa.training`. Fallback: current GitHub Pages URL.
- Keep legal URLs working for App Store review.
- Decide whether marketing pages live in the same GitHub Pages site or a separate site.
- Add a public naming rule: Tuwa only; Tonus is legacy/internal.
- Define one primary CTA: "Try Tuwa" or "Join the Tuwa beta" depending on App Store status.

Done when:

- One canonical domain is chosen.
- App Store metadata, support page, and future website pages point to the same brand and domain strategy.

### Phase 1: Technical SEO Foundation

Timeline: Days 3-7

Goal: make the site crawlable, indexable, measurable, and understandable.

Actions:

- Create a marketing homepage at `/`.
- Add `robots.txt`:
  - Allow `Googlebot`, `Bingbot`, `OAI-SearchBot`, and `PerplexityBot`.
  - Decide separately whether to allow `GPTBot` for training use.
  - Include sitemap reference.
- Add `sitemap.xml` with homepage, legal/support pages, calculator, and content pages as they ship.
- Add canonical URLs to every page.
- Add title tags and meta descriptions to every page.
- Add Open Graph and X card metadata.
- Add schema:
  - `Organization` or `Person` for publisher identity.
  - `SoftwareApplication` for Tuwa.
  - `Article` or `BlogPosting` for guides.
  - `BreadcrumbList` for guides and comparisons.
  - `Product` only if pricing and product details are visible.
- Add analytics:
  - Google Search Console.
  - Bing Webmaster Tools.
  - Basic web analytics.
  - App Store click tracking with UTM links.
- Run an indexability check:
  - Homepage loads without login.
  - Important text is visible in HTML.
  - No accidental `noindex`.
  - Mobile page is usable.

Done when:

- Homepage is live.
- `robots.txt` and `sitemap.xml` return 200.
- Search Console can inspect the homepage.
- All live pages have canonical URL, title, meta description, and at least one internal link.

### Phase 2: Build The Lead Magnet

Timeline: Days 8-14

Goal: publish the free tool that demonstrates Tuwa's core logic.

Primary page:

- `/strength-readiness-calculator`

Page promise:

> Use HRV, sleep, soreness, RPE, and planned session intensity to estimate whether to push, maintain, reduce volume, swap intensity, or recover.

Required sections:

- Direct answer block: what the calculator does in 40-60 words.
- Input form:
  - HRV vs baseline.
  - RHR vs baseline.
  - Sleep duration/quality.
  - Soreness.
  - Recent training days.
  - Planned session intensity.
  - Planned lift/session type.
- Output:
  - Push, maintain, reduce, swap, or recover.
  - Suggested volume change.
  - Plain-English reason.
  - "Not medical advice" disclaimer.
- CTA:
  - "Want this automated from Apple Health and your workout log? Try Tuwa."
- Internal links:
  - HRV for strength training guide.
  - Apple Watch training load for lifters guide.
  - Comparison pages.

Done when:

- Calculator page is live and indexable.
- It can work as a standalone useful tool without installing the app.
- It converts naturally into Tuwa's product promise.

### Phase 3: Publish Comparison Pages

Timeline: Days 15-30

Goal: capture commercial intent from users already comparing tools.

Publish in this order:

1. `/comparisons/athlytic-alternative-strength-training`
2. `/comparisons/bevel-alternative-lifters`
3. `/comparisons/whoop-strength-trainer-alternative-apple-watch`
4. `/comparisons/cora-vs-tuwa`
5. `/comparisons/strong-vs-tuwa`
6. `/comparisons/hevy-vs-tuwa`

Comparison page structure:

- 40-60 word direct answer.
- "Best for" table.
- "Where [competitor] wins."
- "Where [competitor] falls short for strength/hybrid athletes."
- "How Tuwa is different."
- Feature comparison table.
- "Do not use Tuwa if..." honesty section.
- Sources and last updated date.
- CTA to calculator and app.

Positioning rules:

- Do not claim competitors are bad.
- Do not claim injury prediction.
- Do not pretend WHOOP lacks strength features.
- Do not sell Tuwa as a generic recovery score.
- Always bring the page back to "what should I change in today's session?"

Done when:

- At least 4 comparison pages are published.
- Each page has current competitor source links.
- Each page has a clear answer block and comparison table.
- Each page links to the calculator and one guide.

### Phase 4: Publish Authority Guides

Timeline: Days 31-60

Goal: build topical authority around strength readiness and training adjustment.

Publish in this order:

1. `/apple-watch-training-load-for-lifters`
2. `/guides/how-to-adjust-training-when-hrv-is-low`
3. `/guides/hrv-for-strength-training`
4. `/guides/recovery-score-for-lifting`
5. `/guides/training-load-vs-recovery`
6. `/guides/should-i-train-when-recovery-is-low`
7. `/guides/how-much-volume-to-cut-when-tired`
8. `/guides/acwr-explained`

Guide page structure:

- Direct answer in the first paragraph.
- Simple decision tree.
- Strength example.
- Hybrid/conditioning example when relevant.
- Common mistakes.
- What Tuwa does with this information.
- Sources.
- Last updated date.

Done when:

- 6+ guides are live.
- Each guide links to at least 2 related pages.
- Each guide has at least one original example or decision rule.
- Each guide includes honest limitations and no medical claims.

### Phase 5: Build Third-Party Presence

Timeline: Days 61-90

Goal: give AI answer engines more places to find Tuwa and more human language to associate with the problem.

Actions:

- Create official Tuwa profiles:
  - YouTube.
  - Reddit brand profile.
  - X.
  - Instagram/TikTok if short-form is active.
- Publish 8-12 YouTube Shorts from existing guide content.
- Answer questions in relevant communities only when the answer is useful without the app.
- Create 3 beta-user training review case studies:
  - Before Tuwa.
  - What signals changed.
  - What session changed.
  - What the athlete learned.
- Pitch or place 3 guest mentions:
  - Apple Watch fitness roundup.
  - Strength training newsletter.
  - HYROX/CrossFit/training blog.

Done when:

- 3 third-party surfaces mention Tuwa in context.
- 3 case studies are live or drafted.
- At least 10 community pain phrases have been added back to the content database.

### Phase 6: Weekly SEO/GEO Intelligence Loop

Timeline: ongoing after Day 30

Goal: keep search and AI visibility alive instead of treating SEO as a one-time build.

Weekly loop:

- Monday: collect competitor, community, and query changes.
- Tuesday: update priority keyword list and page briefs.
- Wednesday: publish or refresh one page.
- Thursday: distribute through social, Reddit, and email/community channels.
- Friday: run measurement and AI visibility audit.

Weekly report fields:

- Pages published.
- Pages refreshed.
- Queries checked.
- Google impressions/clicks.
- Indexed page count.
- AI answer mentions/citations.
- Competitor changes.
- Community pain phrases.
- Next week's top 3 actions.

## GEO Page Pattern

Every important page should contain extractable blocks that work even when quoted or summarized outside the page.

Required blocks:

- Definition block: "Tuwa is..."
- Direct answer block: answers the target query in 40-60 words.
- Decision block: "If X, do Y."
- Comparison table: for all competitor/commercial pages.
- Limitations block: what Tuwa does not claim.
- Source block: official docs, competitor pages, or scientific sources.
- Last updated date.

Example direct answer block:

> If HRV is below your baseline before a heavy strength session, you do not always need to skip training. A better first adjustment is to keep the main lift technical, cap RPE, and reduce accessory volume. Tuwa combines HRV, sleep, soreness, RPE, and recent workload to recommend the specific adjustment.

## Website Architecture

Recommended structure:

```text
/
  strength-readiness-calculator
  weekly-training-review-template
  apple-watch-training-load-for-lifters
  guides/
    how-to-adjust-training-when-hrv-is-low
    hrv-for-strength-training
    recovery-score-for-lifting
    training-load-vs-recovery
    should-i-train-when-recovery-is-low
    how-much-volume-to-cut-when-tired
    acwr-explained
    rpe-volume-adjustment
  comparisons/
    athlytic-alternative-strength-training
    bevel-alternative-lifters
    cora-vs-tuwa
    whoop-strength-trainer-alternative-apple-watch
    strong-vs-tuwa
    hevy-vs-tuwa
  privacy
  terms
  support
  sitemap.xml
  robots.txt
```

Homepage sections:

- H1: `Adaptive Strength Training From Your Recovery And Workload`
- Subhead: `Tuwa uses Apple Watch recovery signals, workout logging, workload, soreness, and RPE to adjust today's strength or hybrid session and explain why.`
- Primary CTA: `Try Tuwa`
- Secondary CTA: `Use the free readiness calculator`
- Product proof: workout log, readiness, workload, weekly review.
- Privacy proof: raw HealthKit data stays on device.
- Audience proof: serious strength and hybrid athletes training without a full-time coach.

## Sub-Agent System

This system can be run by one person, multiple humans, or future Codex sub-agents. The important part is that each role has a narrow job, a handoff artifact, and a weekly cadence.

### Agent 0: Growth Orchestrator

Mission: decide priorities and keep the system moving.

Inputs:

- This plan.
- `competitor-index.md`.
- `keywords-content-sources.md`.
- Search Console and analytics.

Outputs:

- Weekly SEO/GEO brief.
- Ordered publishing queue.
- Final go/no-go on page publish.

Cadence:

- 30 minutes every Monday.
- 20 minutes every Friday.

Prompt:

```text
You are Tuwa's Growth Orchestrator. Review the current keyword map, competitor changes, Search Console data, and AI visibility checks. Pick the top 3 SEO/GEO actions for this week. Preserve the strategic wedge: adaptive strength training from recovery and workload. Do not recommend generic recovery-app positioning or injury-prediction claims.
```

### Agent 1: Query Intelligence Agent

Mission: find and prioritize the exact queries Tuwa should target.

Inputs:

- Search Console.
- Google autocomplete.
- Google Trends.
- Reddit/YouTube/community language.
- Competitor pages.

Outputs:

- Weekly query list with intent, priority, and target page.
- Pain phrase list.
- New comparison opportunities.

Cadence:

- Weekly during the first 90 days.
- Biweekly after.

Prompt:

```text
You are Tuwa's Query Intelligence Agent. Find queries from self-coached lifters and hybrid athletes who use Apple Watch, recovery apps, or workout logs but do not know how to adjust today's session. Classify each query by intent: informational, tool, comparison, commercial, or support. Prioritize queries where Tuwa's answer is more specific than generic recovery apps.
```

### Agent 2: SERP And GEO Analyst

Mission: inspect current search and AI answers before pages are written.

Inputs:

- Target query.
- Google results.
- Google AI features if present.
- ChatGPT search answer.
- Perplexity answer.
- Gemini/Copilot answer when available.

Outputs:

- SERP/GEO brief:
  - Who ranks.
  - Who gets cited.
  - What answer pattern appears.
  - What is missing for strength/hybrid athletes.
  - What Tuwa must say differently.

Cadence:

- Before every major page.
- Monthly for top 20 target queries.

Prompt:

```text
You are Tuwa's SERP and GEO Analyst. For the target query, summarize the current Google results and AI answers. Identify cited sources, repeated claims, missing angles, and content formats. Recommend the exact answer block Tuwa should publish to be more useful and more citable. Flag any medical, injury-prediction, or unsupported science risk.
```

### Agent 3: Technical SEO Agent

Mission: make sure search engines and AI crawlers can access the site.

Inputs:

- Website repo.
- Live URLs.
- Search Console.
- Bing Webmaster Tools.
- Page source or rendered HTML.

Outputs:

- Technical SEO checklist.
- Crawl/indexation fixes.
- Schema validation notes.

Cadence:

- Before launch.
- After every template change.
- Monthly after launch.

Prompt:

```text
You are Tuwa's Technical SEO Agent. Audit crawlability, indexability, canonical URLs, sitemap, robots.txt, metadata, mobile usability, schema, internal links, and visible HTML text. Confirm important content is not hidden behind scripts or login. For GEO, verify OAI-SearchBot and PerplexityBot are allowed if the business decision is to appear in AI answers.
```

### Agent 4: Page Strategist

Mission: turn query opportunities into page briefs.

Inputs:

- SERP/GEO brief.
- Query map.
- Tuwa positioning.
- Competitor index.

Outputs:

- Page brief with title, H1, URL, search intent, sections, CTA, internal links, and source needs.

Cadence:

- For every planned page.

Prompt:

```text
You are Tuwa's Page Strategist. Create a page brief for the target query. The page must answer the query directly, support Tuwa's wedge, include an honest limitations section, and convert to the readiness calculator or app. Include H1, meta title, meta description, URL slug, section outline, internal links, schema type, and required sources.
```

### Agent 5: Science And Claims Reviewer

Mission: keep claims credible and App Store-safe.

Inputs:

- Draft page.
- Sources.
- Local product constraints.
- HealthKit privacy rule.

Outputs:

- Claims review with required edits.
- Approved source list.
- Risk flags.

Cadence:

- Before publishing guides, comparisons, calculators, and anything mentioning HRV, ACWR, recovery, injury, fatigue, or health.

Prompt:

```text
You are Tuwa's Science and Claims Reviewer. Review the page for unsupported claims, medical advice risk, injury-prediction language, overconfident ACWR claims, and misleading competitor statements. Keep the copy useful and plain-English. Approve only claims supported by sources or clearly framed as product positioning.
```

### Agent 6: Competitive Page Agent

Mission: write honest, current comparison pages.

Inputs:

- Competitor page.
- Pricing/features source links.
- Competitor index.
- SERP/GEO brief.

Outputs:

- Comparison page draft.
- Competitor source table.
- "Do not use Tuwa if..." section.

Cadence:

- During Phase 3.
- Refresh monthly for top competitors.

Prompt:

```text
You are Tuwa's Competitive Page Agent. Write an honest comparison page for the target competitor. Give the competitor credit where it wins. Position Tuwa only where it is truly different: session-level adjustment for strength and hybrid athletes using Apple Watch, workout logs, workload, soreness, and RPE. Do not make unsupported claims.
```

### Agent 7: GEO Extractability Editor

Mission: make every page easy for AI systems to quote, summarize, and cite.

Inputs:

- Draft page.
- Target query.
- SERP/GEO brief.

Outputs:

- Extractability edit.
- Answer blocks.
- FAQ-style questions in visible copy.
- Tables and concise definitions.

Cadence:

- Before publishing every page.

Prompt:

```text
You are Tuwa's GEO Extractability Editor. Edit this page so AI answer engines can extract accurate passages. Add a 40-60 word direct answer near the top, clear definitions, tables where useful, standalone paragraphs, source-backed claims, and visible Q&A sections. Do not add hidden text or special AI-only files.
```

### Agent 8: Community Presence Agent

Mission: create third-party language and trust without spam.

Inputs:

- Query map.
- Reddit/community pain phrases.
- Published Tuwa pages.

Outputs:

- Weekly community opportunities.
- Helpful answer drafts.
- Pain phrase updates.

Cadence:

- Weekly.

Prompt:

```text
You are Tuwa's Community Presence Agent. Find real discussions where self-coached lifters, hybrid athletes, Apple Watch users, or recovery-app users ask how to adjust training. Draft useful answers that stand alone without requiring Tuwa. Mention Tuwa only when relevant and allowed. Capture exact pain language for future SEO pages.
```

### Agent 9: Measurement Agent

Mission: prove what is working and decide what to refresh.

Inputs:

- Search Console.
- Bing Webmaster Tools.
- Web analytics.
- App Store clicks.
- AI visibility audit.
- Publishing log.

Outputs:

- Weekly scorecard.
- Monthly content refresh queue.
- Query movement table.

Cadence:

- Weekly after Phase 1.
- Monthly deep review.

Prompt:

```text
You are Tuwa's Measurement Agent. Review SEO and GEO performance for the last week. Report indexed pages, impressions, clicks, CTR, top queries, app/install CTA clicks, AI mentions/citations, pages needing refresh, and the next three actions. Separate evidence from inference.
```

## Handoff Artifacts

### Keyword Brief

```text
Query:
Intent:
Priority:
Target page:
Current ranking/citation competitors:
Searcher pain:
Tuwa angle:
Required sources:
CTA:
```

### Page Brief

```text
URL:
H1:
Meta title:
Meta description:
Primary query:
Secondary queries:
Direct answer block:
Required sections:
Required tables:
Internal links:
Schema:
Sources:
Risk notes:
Publish gate:
```

### GEO Audit Row

```text
Query:
Platform: Google / ChatGPT / Perplexity / Gemini / Copilot
Answer summary:
Sources cited:
Tuwa mentioned: yes/no
Competitors mentioned:
Missing angle:
Action:
```

### Publish Gate

Before a page goes live:

- Tuwa name only.
- Clear target query.
- Direct answer in first 100 words.
- Page has a real user benefit even without installing Tuwa.
- No injury-prediction claims.
- No medical advice.
- Competitor claims are sourced.
- Science claims are sourced.
- Last updated date exists.
- Canonical URL exists.
- Title and meta description exist.
- Important content visible in HTML.
- Internal links added.
- Schema added where appropriate and matches visible text.
- CTA points to calculator or app.

## First 12 Pages To Build

| Order | Page | Type | Primary CTA |
|---:|---|---|---|
| 1 | `/` | Homepage | Try Tuwa |
| 2 | `/strength-readiness-calculator` | Free tool | Try Tuwa |
| 3 | `/apple-watch-training-load-for-lifters` | Guide | Use calculator |
| 4 | `/comparisons/athlytic-alternative-strength-training` | Comparison | Use calculator |
| 5 | `/comparisons/bevel-alternative-lifters` | Comparison | Use calculator |
| 6 | `/comparisons/whoop-strength-trainer-alternative-apple-watch` | Comparison | Use calculator |
| 7 | `/guides/how-to-adjust-training-when-hrv-is-low` | Guide | Try Tuwa |
| 8 | `/guides/hrv-for-strength-training` | Guide | Use calculator |
| 9 | `/comparisons/cora-vs-tuwa` | Comparison | Try Tuwa |
| 10 | `/comparisons/strong-vs-tuwa` | Comparison | Try Tuwa |
| 11 | `/comparisons/hevy-vs-tuwa` | Comparison | Try Tuwa |
| 12 | `/weekly-training-review-template` | Template | Try Tuwa |

## Measurement Dashboard

Track weekly:

- Total indexable pages.
- Pages submitted to sitemap.
- Pages indexed.
- Non-branded impressions.
- Branded impressions.
- Top 10 queries.
- Top 10 pages.
- Calculator starts.
- Calculator completions.
- App Store CTA clicks.
- AI answer mentions.
- AI answer citations.
- Competitor pages updated.
- Community pain phrases captured.

## AI Visibility Query Set

Run monthly:

```text
best Apple Watch recovery app for lifters
adaptive strength training app
strength training readiness calculator
how should I adjust strength training when HRV is low
Apple Watch training load for strength training
Athlytic alternative for strength training
Bevel alternative for lifters
Cora vs Tuwa
WHOOP Strength Trainer alternative Apple Watch
Strong vs Tuwa
Hevy vs Tuwa
recovery score for lifting
training load vs recovery
```

## Source Principles

Use primary sources wherever possible:

- Google Search Central for Google SEO and AI features.
- OpenAI crawler docs for ChatGPT search crawl access.
- Perplexity crawler docs for Perplexity crawl access.
- Apple support docs for Apple Watch Vitals and Training Load.
- Competitor official websites and App Store pages for competitor claims.
- PubMed, ACSM, BMC/Springer, or named expert sources for HRV, ACWR, and workload science.

Important current guidance:

- Google says the same SEO fundamentals apply to AI features; pages need to be indexable and eligible for snippets.
- Google says there is no special schema required for AI Overviews or AI Mode.
- OpenAI separates `OAI-SearchBot` for ChatGPT search visibility from `GPTBot` for possible model training.
- Perplexity recommends allowing `PerplexityBot` for search visibility and says it is not used for foundation-model pretraining.

Sources:

- Google AI features and your website: https://developers.google.com/search/docs/appearance/ai-features
- Google SEO Starter Guide: https://developers.google.com/search/docs/fundamentals/seo-starter-guide
- Google structured data introduction: https://developers.google.com/search/docs/appearance/structured-data/intro-structured-data
- OpenAI crawlers: https://platform.openai.com/docs/bots
- Perplexity crawlers: https://docs.perplexity.ai/guides/bots

## Final Operating Rule

Every SEO and GEO decision should pass this test:

> Does this help a serious self-coached strength or hybrid athlete decide what to change in today's session?

If not, it is probably too generic for Tuwa.
