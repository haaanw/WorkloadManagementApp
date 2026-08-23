# Tuwa science series — editorial brief (HAN, 2026-08-24)

A research-article series on tuwa.app's blog (`tuwa-website/src/content/blog/`,
Astro content collection, one post exists). Purpose: the SEO/GEO content
engine — fact-dense, citation-backed articles that search engines rank and
answer engines quote. Scope is frontier sports science BROADLY, not only
workload management and recovery.

## Editorial rules (non-negotiable)

1. **Two article classes, never blurred:**
   - **"How Tuwa works" class** — explains the algorithms the app actually
     ships (ACWR/EWMA load, HRV baselines, session RPE, readiness verdict
     logic). §10 claim rails bind hard: describe only what is LIVE in the
     shipped version. Sleep-score v2 and estimator v2 are unshipped — they
     may be discussed as open research questions, never as product.
   - **"Frontier review" class** — surveys evidence on a broad topic (sleep,
     gait, barefoot footwear, physiology). No product claims required at
     all; a short "what this means inside Tuwa" coda is allowed only when
     truthful.
2. **Citations are the product.** Every empirical claim carries a named,
   checkable source (journal article, preprint, position stand). No
   secondhand blog citations. Grade evidence honestly — "one n=12 study
   suggests" beats "research shows".
3. **Health-claim guardrail:** the app disclaimer extends to the series —
   training/education content, not medical advice; no diagnosis, treatment,
   or prevention claims. Barefoot-shoes-class topics state trade-offs and
   populations, never prescriptions.
4. **GEO mechanics on every article:** the direct answer in the first
   ~120 words; question-shaped H2s; FAQPage/Article schema.org markup;
   consistent entity naming (Tuwa + the canonical term); descriptive slug.
5. **Voice:** the working voice of the design system — plain, precise,
   sentence case; annotation styling per site convention. en first;
   zh-Hans translation per article once en is approved (fr optional).
6. **Publishing is HAN-gated** like every deploy. Drafts land as MDX in the
   collection, committed, unpushed.

## Starter topics (HAN's list + the natural firsts)

1. How Tuwa computes training load — EWMA ACWR, and why the ratio's own
   critics shaped the implementation ("How Tuwa works" class).
2. HRV readiness: why the morning median against your own baseline, not
   yesterday's number ("How Tuwa works").
3. Sleep and next-day training capacity — what the evidence actually
   supports (frontier review; do NOT reference the unshipped sleep engine
   as product).
4. Gait retraining / "a better way of walking" — what's evidence-backed vs
   coaching folklore (frontier review).
5. Barefoot/minimalist shoes: who benefits, who gets injured, what the
   transition literature says (frontier review).
6. Match-day proximity and strength training — the microdosing evidence
   base (bridges both classes; canonical vocabulary from CONTEXT.md).

## Distribution — three platforms per article (HAN 2026-08-24)

Every article ships in three editions from one evidence core. Write the
core platform-neutral, then wrap it per platform — never fork the facts.

1. **tuwa.app blog — the canonical edition.** Publishes FIRST. Carries the
   schema markup and the GEO mechanics; this is the URL search and answer
   engines should own. Site voice (working voice, no first person needed).
   CTA: the relevant feature page.
2. **X long-form article — the founder edition.** Posted on HAN's personal
   account, whose identity is a creative who vibe-codes and shares the tech
   — so the wrapper is first-person: "I'm building Tuwa; here is the science
   under this week's problem," including build details where honest. The
   evidence core and every citation stay intact; the claim rails bind
   regardless of voice. Format for X: minimal markup survives, so
   structure by short paragraphs and plain lists, no schema, images
   re-attached natively. Ends with the app link. A 2–3 tweet teaser thread
   links the article.
3. **Substack — the newsletter edition.** Same founder voice as X. Set the
   canonical link to the tuwa.app URL (Substack supports this) so
   syndication never competes with the site in search. CTA: subscribe +
   app link.

Sequencing per article: site edition approved and live → X and Substack
editions within the same week. Never syndicate before the canonical URL
exists. Drafting all three editions together is fine; publishing any of
them is HAN's hand only — the X account and Substack are personal outward
surfaces, same rule as every deploy.

Consequence for how the core is WRITTEN: the personal wrapper must be
separable — open each draft with the evidence core standing alone, so the
site edition needs no surgery and the founder framing is an added layer,
not a rewrite.

## Cadence proposal

One article per week sustained beats six in launch week; SEO compounds on
consistency. First three articles drafted before the series page goes live
so the index never looks abandoned.
