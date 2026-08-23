# What each change is expected to move, and how we will know

Drafted 2026-08-22. The point of this file is that after 1.7.2 has been live for a month we
can say which changes worked instead of arguing about it.

## The funnel, and which field touches which stage

```
              impressions  ──►  product page views  ──►  installs
                   ▲                    ▲                    ▲
                   │                    │                    │
        name, subtitle,        icon, name, subtitle,   screenshots (all),
        keyword field,         first 3 screenshots     description, ratings,
        category               (shown in search)       promo text
```

Name, subtitle and the keyword field decide whether the listing is **shown**. Screenshots and
ratings decide whether a person who sees it **installs**. Almost nothing we are changing
touches both, which is what makes the attribution below possible from a single release.

## Change by change

| # | Change | Expected to move | Direction and size | How we read it |
|---|---|---|---|---|
| 1 | Name `tuwa` (4 chars) → `Tuwa: Training Readiness` (24) | **Impressions** | Largest single lever in this pass. The name is the highest-weighted indexed field and today it carries no keyword at all. | ASC → Analytics → Impressions, filtered to **Search**. |
| 2 | CN name gains `准备度` and `训练负荷` | **Impressions, China only** | Large in relative terms, from a small base. A Latin-only name in the CN store matches no Chinese query. | Same metric, storefront = China. |
| 3 | Subtitle `Adaptive Strength Training` → `Your plan, tuned to recovery` | **Impressions** (small) and **tap-through** (small) | Token coverage widens rather than moves: `strength`/`training` shift into the name, `plan`/`recovery` are new. The subtitle is also read in search results, so it affects tap-through. | Impressions, plus product-page-views ÷ impressions. |
| 4 | Keyword field rewritten, no token duplicated from name or subtitle | **Impressions**, long tail | Moderate. The old field wasted characters on `Apple Watch` and on words the name now carries. | Impressions, and the ASC search-term report once there is enough volume. |
| 5 | **Screenshots: plates 1, 2 and 6 were the same image.** Now nine distinct plates, with voice logging at 2 and sleep at 5 | **Conversion** | Largest conversion lever. Search results show the first three plates; two of those three were duplicates of the first. | Conversion rate (installs ÷ product page views). |
| 6 | Seeded data fixed: 12 weeks of history, no "insights unlock after 8 weeks" nag, no empty workout, no "1 EXERCISES" | **Conversion** | Moderate. Every plate now shows the app working rather than the app waiting. | Same metric; not separable from #5 in this release. |
| 7 | Description rewritten, voice logging in the opening paragraph | **Conversion** (small) | Small — most visitors never expand it. Its job is to not lose the people who do. | Not separately measurable. Judge on retention of the "read more" cohort if that ever becomes visible. |
| 8 | Promo text leads with 1.7.2 voice logging | **Conversion** (small) | Small, but free: promo text can be changed at any time with no review, so it is the one field we can iterate weekly. | Change it alone, mid-cycle, and watch conversion. This is the only field that gives a clean read without a release. |

## What is not fixed here, and caps everything above

**The app has 0 ratings**, and the baseline now shows what that costs: 9.4% of product-page
visitors download, against a 25–35% category norm. Rating count and average feed both ranking
and conversion, and no amount of keyword work substitutes for an empty ratings bar sitting on
the page. This is the highest-leverage remaining item and it is app code, not metadata — an
in-app review prompt after a successful verdict-accept or a PR. Out of this lane's scope;
flagged for HAN.

With 12 downloads a quarter, note the loop: too few installs to earn ratings, too few ratings
to lift conversion, too little conversion to justify installs. Impressions is the only end of
it this listing can pull on, which is why the name field is change #1.

## Attribution, given that everything ships at once

Everything above lands in one release, so no single change is isolated. What makes it
readable anyway:

1. **Impressions and conversion move for different reasons.** If impressions rise and
   conversion holds, the text fields worked. If conversion rises and impressions hold, the
   screenshots worked. If both move, both worked. If impressions rise and conversion *falls*,
   the new keywords are pulling the wrong intent — most likely `basketball`, which is the one
   token in the field whose query is owned by apps doing a different job.
2. **Storefront split isolates the CN name change.** China impressions versus US impressions.
3. **Promo text is the free control.** It can be changed without a release, so any later
   promo-only edit gives a clean single-variable read on conversion.

## The baseline — captured 2026-08-22

ASC → Analytics → Overview, app `6761185505`, **90-day window ending 2026-08-20**
(`dateSpec=d90`). Recorded here because it cannot be recovered at this granularity later.

| Metric | 90-day total | vs previous 90 days |
|---|---:|---:|
| Impressions (展示次数) | **787** | +629% |
| Product page views (产品页面查看次数) | **127** | +606% |
| First-time downloads (首次下载次数) | **12** | +200% |
| Redownloads (重新下载次数) | 1 | −80% |
| Conversion rate (转化率, Apple's daily average) | **2.57%** | −73.6% |
| Updates (更新次数) | 14 | — |
| Proceeds / paid users / IAP purchases | *insufficient data* | — |

Note the window is **d90, not d28.** At this volume 28 days would carry roughly 4 downloads,
which is not a number anything can be measured against. The post-release read must use the
same d90 window, or the comparison is not like for like.

Two arithmetic notes, because the numbers do not agree with each other by accident:

- Apple's 2.57% is a **daily average of daily rates**, which low-volume days skew upward.
  The period-level rate is `12 ÷ 787 = 1.52%`. Both are in the table; use the period-level
  one for the after-comparison, and compute it the same way both times.
- The −73.6% on conversion sits beside +629% on impressions. That is the expected shape, not
  a regression: impressions grew far faster than downloads, so the ratio fell. It is what
  "we became slightly more visible to people who did not convert" looks like.

### What the funnel actually says

```
787 impressions  ──16.1%──►  127 page views  ──9.4%──►  12 downloads
```

- **16.1% impression → page view is healthy.** The icon and the current name/subtitle are not
  what is broken.
- **9.4% page view → download is the weak link.** Health & Fitness typically runs in the
  25–35% band. Of everyone who opened the product page, more than nine in ten left. That is
  the screenshots and the empty ratings bar, in that order — and it is direct evidence for
  changes 5 and 6 above.
- **787 impressions over 90 days is ~8.7 per day.** This is the binding constraint on
  everything. The listing is not losing a competition; it is not in one.

## Product Page Optimization: not yet — correcting an earlier recommendation

Before the baseline was in hand this file recommended starting Apple's Product Page
Optimization on the screenshot set about four weeks after launch. **At 12 downloads per 90
days that is not a viable test.** PPO splits live traffic across variants and needs enough
installs per arm to separate a real effect from noise. A two-arm test at this volume gets on
the order of six installs per arm per quarter. It would take the better part of a year to say
anything, and the answer would still be inside the noise.

PPO becomes the right tool at roughly **50+ installs per month**, and the way to get there is
impressions — changes 1–4. Revisit it when the monthly install count has a second digit.

Until then the screenshot work is justified on the funnel arithmetic above (9.4% page view →
download against a 25–35% category norm), not on a split test. That is weaker evidence than
a controlled test, and it is the strongest evidence this traffic level supports. Worth saying
plainly rather than dressing up.

## Expected timeline

| When | What to look at |
|---|---|
| Before submission | Baseline is captured — see above. Nothing more needed. |
| Days 1–14 after live | Nothing. Indexing settles and the update bump distorts everything, and at ~8.7 impressions/day a one-week window is pure noise. |
| Day 90 after live | **Impressions vs 787**, same d90 window. The read on changes 1–4, and the one number that matters most. |
| Day 90 after live | **Page view → download vs 9.4%**, computed the same way. The read on changes 5–6. |
| Day 90 after live | **Impression → page view vs 16.1%.** Should hold or rise; a fall means the new name or subtitle is pulling worse-matched traffic — most likely `basketball`. |
| Whenever | Promo text can be edited without a release. It is the only clean single-variable test available, so save it for when there is a specific question worth asking. |

**One honest caveat about all of the above.** At 787 impressions and 12 downloads per
quarter, none of these comparisons will reach statistical significance. They are directional
reads on a listing that is currently close to invisible. The purpose of the numbers is to
catch a change that makes things clearly *worse*, and to see whether the name-field fix moves
impressions by the large multiple it should. Anything subtler than that is not measurable
here yet, and treating it as measurable would be the mistake.
