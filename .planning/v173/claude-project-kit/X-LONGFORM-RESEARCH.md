# X long-form editions — research and recommended changes

Research date 2026-08-24. Scope: the X edition of the science series
(`.planning/v173/SCIENCE-SERIES.md` §Distribution, edition 2). Nothing here is
published; HAN posts everything.

**Read the confidence grading in §5 before acting on any number in §1.** The
series' own editorial rule 2 says grade evidence honestly. That rule applies to
our own marketing research, and most of what follows is third-party SEO blog
measurement, not X documentation.

---

## 1. What the format actually is, and how it is ranked

**Two different surfaces, and the brief conflates them.**

| Surface | Length | Formatting | Access |
|---|---|---|---|
| Long-form **post** | ~25,000 chars | bold, lists, line breaks | all X Premium tiers |
| **Article** | blog-length | headings, rich text, embedded/inline media, own profile tab | **HAN's account has it — confirmed 2026-08-24** |

**The Article surface is the target. HAN confirmed direct write access, so every
"if" in an earlier draft of this note is closed.**

Consequence: the drafts are written for the wrong surface and are pessimistic
about it. Their header says X "strips anything fancier than short paragraphs,
plain lists and links" and marks images as `[IMAGE SLOT n]` for manual
attachment. That describes the *post* surface. On Articles we get real headings,
inline images placed where they belong, and a piece that lives on its own profile
tab as a durable artifact rather than scrolling away. Every draft header needs
rewriting on that basis, and §3.4 and §3.5 become straightforward rather than
conditional.

**Three ranking facts that change the strategy, not just the formatting.**

1. **Dwell time is the prize.** Long-form posts over ~1,000 characters get a
   dwell-time boost, and dwell of 2+ minutes is reported as a strong positive
   ranking signal. Our articles are 12-minute reads. On this surface, length is
   an asset for the first time.
2. **External links are penalised, heavily.** Reported figures range from
   30–40% to 50–70% less For-You distribution, with one source claiming up to
   80%. The direction is consistent across every source; the magnitude is not.
   The standard mitigation is to put the link in a reply rather than the post
   body.
3. **A single long post beat a thread on the same topic** — 7.03% vs 4.72%
   engagement rate — in one controlled comparison. Single long-form suits
   "announcements, arguments, personal essays, compact explainers". Ours are
   arguments.

## 2. The strategic consequence

**The brief has the X edition pointed the wrong way, and the fix is free.**

Today the X edition is written as a funnel: it ends with the tuwa.app link and
the App Store link, and the teaser thread's last tweet carries the canonical URL
as the payoff. That treats X reach as a means of getting clicks to the site.

The ranking mechanics say the reverse is better on every axis:

- Clicking out is the behaviour X penalises; reading in place is the behaviour it
  rewards.
- The site does not need the X traffic for the thing the site is for. Its job is
  search and answer-engine citation, and that job is done by the canonical URL
  existing, being indexed, and carrying the schema — not by X readers visiting.
- The two goals therefore stop competing. **X optimises for a complete
  on-platform read. The site optimises for search.** Same evidence core, no
  conflict, and the canonical-link discipline in the brief is unchanged.

Concretely: the X edition should be *sufficient on its own* — a reader who never
leaves X should get the whole argument and every citation by name. The site link
becomes a citations-and-arithmetic appendix reference near the end, not the
payoff. This is a small edit to three drafts and it does not touch a single fact.

## 3. Changes to make, per draft — **APPLIED 2026-08-25**

All seven landed in `drafts/science-series/*/x.md`. Verified after the edit: every
body opens on a claim rather than on biography, no `apps.apple.com` link remains in
any body, each draft carries six images (two app screenshots + the four figures),
and every teaser thread ends on `[LINK THE X ARTICLE HERE]` rather than a tuwa.app
URL. HAN still fills that placeholder by hand at post time, because the Article URL
does not exist until he publishes it.

Each of the three `drafts/science-series/<slug>/x.md` files. Ordered by expected
effect.

**3.1 — Rewrite the first two lines as a standalone hook.**
Only the first ~280 characters render before "Show more". Today
`how-tuwa-computes-training-load` opens with:

> I am a designer who vibe-codes. I build Tuwa mostly by describing what I want
> to an AI and then arguing with it about the details…

That spends the entire visible window on biography. The article's own title line
is a far better hook and is currently sitting where nobody sees it first. Fix:
put the claim on line 1, a blank line under it, then the identity paragraph.

> I built my training-load metric on a paper with 3,000+ citations. Then
> statisticians took that paper apart.
>
> I kept the metric. I changed what my app is allowed to say about it.
>
> (I'm a designer who vibe-codes; I train the way the app is built for — …)

The blank line is load-bearing: it is what makes the reader tap "Show more",
which is the first success metric and the gate on the dwell-time boost.

**3.2 — Move both external links out of the body's climax.**
Keep the citations-and-arithmetic link, but demote it to a single line near the
end, and drop the App Store link from the body entirely — put it in the profile
bio and the first reply. Two outbound links in the last four lines is the exact
shape the link penalty targets, and it also makes a piece whose whole argument is
epistemic restraint end like an ad.

**3.3 — Point the teaser thread at the Article, not at tuwa.app.**
Tweet 3 currently ends with the tuwa.app URL. The thread should link the Article
instead: an on-platform link, no penalty, and it feeds the dwell-time signal we
want. The canonical URL still appears inside the Article, so the site loses
nothing. The external URL leaves the thread entirely.

**3.4 — Promote the bold pseudo-headers to real headings.**
`**The number**`, `**The smoothing**`, `**Then I read the criticism**` are already
a clean section structure and become real headings on the Article surface. Do
this — it is free, and headings are what make a 2,000-word piece skimmable enough
to earn the dwell time in the first place.

**3.5 — Raise the image count from 2 to 4–6, and use the new figures.**
Two image slots across ~2,000 words is thin for a surface where "strong hook +
visuals + long-form" is the reported winning combination. The four figures built
for the site edition — one fatigue budget, the cliff edge, mathematical coupling,
the zone strip — are exportable to PNG and carry the argument better than the
app screenshots currently slotted. Recommended cadence: hook → figure → section →
figure, roughly one per 350 words.

**3.6 — Restructure to claim → proof → implication.**
The draft runs problem → criticism → what I shipped, which is sound. The reported
best-performing shape for contrarian technical takes is claim-proof-implication,
and this piece already has the contrarian claim: *the research my metric came from
was dismantled, and I kept the metric anyway.* Leading with that and then
proving it is a reordering, not a rewrite.

**3.7 — Keep the self-criticism. It is the differentiator.**
Nothing in the research argues against it, and §"Why I am posting the criticism
of my own metric" is the strongest paragraph in the draft. No change.

## 4. What does not change

- Every citation, verbatim and verified. The claim rails bind in the founder
  voice exactly as on the site (`SCIENCE-SERIES.md` rule 3).
- Site publishes first. No syndication before the canonical URL is live.
- Substack: canonical link stays pointed at tuwa.app. The link penalty is an X
  mechanic and has no Substack equivalent, so the Substack edition keeps its
  links where they are and keeps the subscribe CTA.
- HAN posts. Nothing outward moves from a session.

## 5. Confidence, honestly graded

| Claim | Grade | Why |
|---|---|---|
| External links reduce distribution | **HIGH direction, LOW magnitude** | Every source agrees on the direction; quoted figures span 30–80%, which is the signature of estimation, not measurement |
| Long-form >1,000 chars gets a dwell boost | **MEDIUM** | Consistently reported across SEO/growth blogs; not verified against X's own documentation or the open-sourced ranking code |
| "+10 weight" for 2+ min dwell | **LOW** | A specific number from a single growth-tool blog. Treat as directional only |
| Single long post 7.03% vs thread 4.72% | **LOW** | One controlled comparison, one topic, one account. Suggestive, not general |
| First ~280 chars visible before "Show more" | **HIGH** | Observable behaviour of the product |
| HAN's account can publish Articles | **CONFIRMED** | HAN, 2026-08-24, from his own composer. Third-party sources conflicted on the tier requirement; the account itself settles it and the sources are now irrelevant |

**Not verified and deliberately not asserted:** whether any of this holds for an
account of HAN's size and niche. Every source measures aggregate behaviour. An
account whose audience is dev/build-in-public may behave differently from the
population the studies describe, and the honest test is our own first three
articles.

**Method limit:** this is web-search research over marketing and growth blogs.
X's ranking code was open-sourced (reported 2026) and would be a primary source;
I did not read it. If any of these mechanics is load-bearing for a decision
bigger than paragraph order, that is where to go next.

## Sources

- [X (Twitter) Algorithm Statistics 2026 — engagement weights and reach decay](https://www.autotweet.io/statistics/x-twitter-algorithm-statistics)
- [X Algorithm Explained 2026](https://www.autotweet.io/blog/x-algorithm-explained-2026)
- [X (Twitter) Algorithm: Ranking Factors & Growth Tips (August 2026)](https://www.socialpilot.co/blog/twitter-algorithm)
- [The X Algorithm in 2026: What Actually Makes Posts Go Viral](https://opentweet.io/blog/how-twitter-x-algorithm-works-2026)
- [X algorithm goes open source](https://explainx.ai/blog/x-algorithm-open-source-github-elon-musk-2026)
- [How to Post Long Tweets on X (A 2026 Guide)](https://superx.so/blog/post-long-tweets)
- [Experiment: Do Long-Form X Posts Give You More Reach?](https://blog.hootsuite.com/experiment-x-threads-vs-longform-posts/)
- [Post structure: building engaging content](https://postwriter.co/blog/post-structure)
- [How to Write Long-Form Posts on X](https://tweethunter.io/blog/how-to-write-a-long-form-post-on-x)
- [Access-tier conflict — Articles vs long-form posts, January 2026](https://x.com/MichealCodes/status/2012802486805897696)
- [X removes Top Articles for Premium users (Jan 2026)](https://piunikaweb.com/2026/01/08/x-premium-top-articles-removed-ios-media-preview-toggle-missing/)
- [Social media image sizes 2026 — link card 1200×631](https://buffer.com/resources/social-media-image-sizes/)
