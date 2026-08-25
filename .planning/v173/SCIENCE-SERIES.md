# Tuwa science series — editorial brief (HAN, 2026-08-24)

A research-article series on tuwa.app's blog (`tuwa-website/src/content/blog/`,
Astro content collection, one post exists). Purpose: the SEO/GEO content
engine — fact-dense, citation-backed articles that search engines rank and
answer engines quote. Scope is frontier sports science BROADLY, not only
workload management and recovery.

## Rule 0 — the backbone test (HAN, 2026-08-24)

**The product must be the backbone of the content. Without the product, the
content cannot exist.** This gate runs BEFORE the class assignment in rule 1 and
outranks it. A topic that fails here is not written, however good the search
volume looks.

**The test, applied literally:** delete Tuwa from the finished article. Does it
still stand?

- Still stands unchanged → **no backbone. Reject.** Anyone could have written it,
  a competitor could publish it verbatim, and it builds no association with us.
- Collapses → **backbone. Accept.**

**Three legitimate backbone types.** Every accepted topic names which one it is.

1. **Mechanism** — the article explains something the app actually does, and the
   arithmetic *is* the content. Strongest for GEO; an answer engine quoting it
   quotes us describing our own system.
2. **Decision** — the article is about a build decision the product forced.
   Including, and especially, what we refused to build and why. This is the class
   that suits the founder voice best, because a decision has a person behind it.
3. **Data** — the article reports something only our instrumentation can see. The
   n=1 dogfood, the shadow-engine divergence, the pre-registered validation.
   Nobody else can write these at all, so they are the most defensible over time
   — and they are entirely unexploited today.

**The cost, stated so it is not discovered later.** Backbone topics have far less
search volume than generic ones by construction — "barefoot shoes injury" is
searched, "why Tuwa does not forecast" is not. The compensation is threefold: the
GEO play does not depend on query volume (answer engines quote fact-dense pages
when the *question* arises, not when the page ranks); the X and Substack editions
do not depend on search at all; and a narrow beachhead never needed broad traffic
— it needed the right reader to find something nobody else could have told them.
This is the right trade at this stage. Revisit it only if the series is measured
against traffic volume rather than against qualified readers.

## Editorial rules (non-negotiable)

1. **Two article classes, never blurred:**
   - **"How Tuwa works" class** — explains the algorithms the app actually
     ships (ACWR/EWMA load, HRV baselines, session RPE, readiness verdict
     logic). §10 claim rails bind hard: describe only what is LIVE in the
     shipped version. Sleep-score v2 and estimator v2 are unshipped — they
     may be discussed as open research questions, never as product.
   - **"Frontier review" class — REDEFINED by rule 0 (2026-08-24).** It may
     still range widely in subject, but a survey with no product backbone is
     no longer a publishable article. The evidence must be reviewed *because
     a decision in the app depended on it*, and the article must say which
     decision. "No product claims required at all" is withdrawn — what stays
     withdrawn is the requirement to *sell*; the requirement to be *anchored*
     is new and binding. The claim rails are unchanged: an unshipped engine
     is named as unshipped, never as product.
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

## Starter topics — re-judged against rule 0 (2026-08-24)

The original list predates the backbone test. Two topics fail it outright and are
struck; one is weak and gets converted rather than dropped.

| # | Topic | Backbone | Verdict |
|---|---|---|---|
| 1 | Training load — EWMA, ACWR, and the critics | Mechanism + Decision | **PASS**, written |
| 2 | HRV readiness — morning median vs own baseline | Mechanism | **PASS**, written |
| 3 | Sleep and next-day training capacity | *survey only* | **CONVERT** — see below |
| 4 | Gait retraining / a better way of walking | none | **STRUCK** |
| 5 | Barefoot and minimalist shoes | none | **STRUCK** |
| 6 | Match proximity and strength microdosing | Mechanism | **PASS**, queued |

**Why 4 and 5 are struck.** Tuwa does not measure gait and has no opinion about
footwear. Both articles stand perfectly well with Tuwa deleted from them, which
is the definition of no backbone. They would have brought search traffic to a
page that could not convert it, and any competitor could publish the same piece.
Reconsider only if the product ever acquires a real stake in either subject.

**Why 3 converts rather than dies.** As written it is a literature survey whose
only link to the product is an engine the claim rails forbid presenting as a
product. That is a backbone the article is not allowed to lean on. The fix is to
change which type it is: make it a **Decision** article. The subject stops being
"what the sleep evidence supports" and becomes *"I am building a sleep score, the
evidence is thinner than the category pretends, so here is what I capped, what I
refused, and why it runs dark for six weeks before it touches anyone's score."*
The survey then serves as the evidence for a decision instead of standing alone,
the shadow engine is named as non-shipping exactly as the rails require, and the
piece becomes one only we can write. The already-drafted article is close to this
— it needs a reframe, not a rewrite.

## Replacement and follow-on topics, by backbone type

All verified as shipped or as real recorded decisions before being listed here.

**Mechanism**
- One fatigue budget — basketball, lifting and conditioning on a single load
  curve. This is the actual differentiator and no competitor draws it.
- What a pull-up costs — bodyweight sets are not zero load (shipped in 1.7.2).
- What "No Data" means, and why the app refuses to guess when it does not know.

**Decision** — best fit for the founder voice
- Why Tuwa does not forecast. An article about refusing the feature every
  competitor advertises, fenced by our own ADR.
- Why the daily verdict is go / modify / hold and never a red gate — the nocebo
  problem, and designing so a pre-session hold cannot poison the session.
- Why session RPE stayed a 1–10 scale instead of four buttons. Quantizing puts up
  to ±1 RPE of error into a verdict input. A tiny UI question with a traceable
  consequence, which is exactly the shape this class wants.
- Why an LLM parses my workouts but never writes my program. Carries the voice-
  logging spearhead and is a genuine epistemics argument, not a feature tour.

**Data** — strongest long-term, gated on the data existing
- Two recovery estimators run side by side for six weeks: what diverged.
- The blinded morning probe — pre-registered before any data existed. Does a
  readiness score predict anything for one athlete?
- 12h45m versus 5h19m: what my own sleep data taught me about reading HealthKit.

These three depend on the dogfood clocks, so they schedule themselves. Nothing in
this class publishes ahead of its own criteria — pre-registration is what makes
them credible rather than self-serving, and publishing early would destroy the
one property that distinguishes them.

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

## Deferred: the zh-Hans translation checklist (HAN, 2026-08-25)

**Nothing here is done now, deliberately.** The blog collection is English-only,
so every zh gap below is currently honest rather than broken — a Chinese reader
sees localized chrome around an English article, which is what it is. These items
land together, in one pass, when the first translated article does. Ordered so a
later session can work straight down the list.

1. **Create the zh article route.** `src/pages/{zh,fr}/blog/` hold an index page
   and nothing else today. The branch point is already marked in
   `src/components/blog/SeriesIndex.astro` — `articleHref()` currently returns
   `/blog/<id>` for every locale, with the reason in a comment above it.
2. **Swap the CJK reading voice off the system stack.** `--font-read-cjk` in
   `global.css` resolves to Songti SC / SimSun today. Self-host Noto Serif SC and
   import `@fontsource/noto-serif-sc/400.css` **on the zh article route only** —
   never globally. It ships 1,632 subset files and ~105 KB of `@font-face` CSS per
   weight, which is why it is not already installed.
3. **Localize the figure labels.** The axis labels, keys and in-figure sentences
   in `src/components/blog/figures.ts` are hardcoded English. They need a locale
   argument threaded through `FIGURES[name](locale)` and `Figure.astro`. This is
   the largest of the five items and the one most likely to be underestimated —
   there are roughly forty strings across nine figures.
4. **Localize `articleClass`.** Frontmatter carries English strings ("How Tuwa
   works", "Frontier review") that render straight into the kicker. Either move
   them to keys resolved per locale, or accept English classes on zh pages.
5. **Translate the `faq` blocks.** They feed FAQPage schema, which answer engines
   quote verbatim, so an untranslated FAQ on a zh page is a worse failure than an
   untranslated paragraph.

**Already handled, so do not redo:** cover-mark captions carry zh (`BlogPostLayout`);
the drop cap is suppressed on CJK; the annotation voice takes no case transform and
no added tracking in zh; the series index chrome, masthead and ledger headers are
localized in `src/i18n/locales/zh/blog.ts`.

## Cadence proposal

One article per week sustained beats six in launch week; SEO compounds on
consistency. First three articles drafted before the series page goes live
so the index never looks abandoned.
