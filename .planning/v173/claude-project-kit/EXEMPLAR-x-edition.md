# X long-form edition — paste source

**Do not publish from this repo.** This is a paste-source for X's **Article**
composer. HAN confirmed direct Article access 2026-08-25, so this is written for
the Article surface, not for a plain long-form post: real headings, inline images
placed where they belong, and a piece that lives on its own profile tab instead of
scrolling away.

The canonical edition is the tuwa.app blog post of the same slug, and it publishes
FIRST.

- Canonical URL (must be live before this posts): `https://tuwa.app/blog/how-tuwa-computes-training-load-ewma-acwr/`
- Evidence core: identical to the site edition. Every citation is intact and verified.
- Claim rails bind in this voice too: no injury prediction, no forecasting, no medical claim.
- **Strategy (see `.planning/v173/X-LONGFORM-RESEARCH.md`):** X penalises outbound
  links and rewards on-platform dwell, and the site does not need X clicks — its job
  is search and answer-engine citation, which the canonical URL does by existing. So
  this edition is written to be **sufficient on its own**. A reader who never leaves
  X gets the whole argument and every citation by name. The site link is a citations
  appendix near the end, not the payoff.
- **Figures:** export each named figure as PNG from the live article and attach it
  inline at the marked point. They are the same diagrams the site edition uses.

---

## ARTICLE TITLE

I built a training-load metric on research that was later dismantled. Here is what I kept.

## ARTICLE BODY

I built my training-load metric on a paper with more than 3,000 citations. Then statisticians took that paper apart.

I kept the metric. I changed what my app is allowed to say about it.

I'm a designer who vibe-codes. I build Tuwa by describing what I want to an AI and then arguing with it about the details, and I train the way the app is built for — basketball plus lifting, self-coached, nobody in a back room telling me whether today should be heavy. This is the oldest problem in the app: how do you turn "what I did" into one number that means something tomorrow?

[APP SCREENSHOT 1 — the Training load screen, load curve visible]

## The number

Every session gets a rating out of 10 for how hard the whole thing felt. Duration times that rating gives you internal load. This is the session-RPE method, from Carl Foster's group in the late 1990s — Foster 1998 in *Med Sci Sports Exerc*, and Foster et al. 2001 in *J Strength Cond Res*. Its whole appeal is that it needs no lab and no chest strap, so it works the same for a lifting session and a scrimmage.

In Tuwa a session's stress figure is duration in hours, times session RPE, times that RPE again over ten. The second RPE term makes hard sessions count for more than long easy ones. Sum the sessions on a calendar day and you have that day's load. Rest days go in as zeros, not as gaps.

The part I care most about: there is one load curve, not one per sport. Strength work gets scored by hard sets and converted into session-RPE-equivalent units before it joins the same series as conditioning and sport practice. If you played a match Tuesday and squatted Wednesday, you have one fatigue budget.

[FIGURE — one-fatigue-budget — three kinds of training reduced to one daily series] Most apps that do this well own your programme. Most apps that accept your programme refuse to do this at all.

## The smoothing

The standard metric here is the acute:chronic workload ratio. Last 7 days of load divided by last 28. Near 1.0 means this week looks like the last month.

Rolling averages have a stupid property: a day inside the window counts fully, a day outside counts zero. So a brutal session carries full weight for seven days and then disappears overnight. Nothing about fatigue has a cliff edge on day eight.

[FIGURE — cliff-edge — rolling window vs exponential decay, the day-8 cliff]

Williams et al. (*Br J Sports Med* 2017) proposed replacing both windows with exponentially weighted moving averages, which decay gradually. Menaspà (*BJSM* 2017) argued the same thing from the coaching side. Murray et al. (*BJSM* 2017) compared the two forms in Australian footballers and found the exponential version more sensitive.

So Tuwa uses that. Acute decays at 1/7 a day, chronic at 1/28. Ratio is acute over chronic.

One honest note about my own implementation: both terms get re-estimated over a 35-day history every time you save a session, starting from zero. That is a short memory for a 28-day decay constant, so the chronic term sits a bit below its settled value and the ratio sits a bit above. It is one of the reasons I show a zone and a direction rather than a number you are supposed to obey.

## Then I read the criticism

This is the part that changed the product.

Between 2019 and 2021 the ACWR literature got taken apart by people who know statistics better than the people who built it.

Lolli et al. (*BJSM* 2019): the acute window is inside the chronic window, so the numerator is part of its own denominator. That mathematical coupling alone produces correlation with outcome — you get the same structure out of random numbers.

[FIGURE — coupling — the acute window nested inside its own denominator]

Bornn, Ward and Norman (MIT Sloan Sports Analytics Conference 2019): a fixed training calendar generates an apparent ACWR-injury relationship even when there is no causal relationship, because exposure and ratio move together by construction.

Impellizzeri et al. (*IJSPP* 2020): here is the list of undeclared analytical choices in a typical ACWR study — how to bin the ratio, where to put the reference category, coupled or uncoupled, EWMA or rolling — and here is how the direction of the result can turn on them. Their 2021 follow-up in *Sports Medicine* is literally titled "Time to Dismiss ACWR and Its Underlying Theory".

Two 2020 systematic reviews, Griffin et al. and Maupin et al., both in *Sports Medicine* and *Open Access J Sports Med* respectively, found the underlying studies heterogeneous and generally at moderate-to-high risk of bias. Wang et al. (*Sports Med* 2020) laid out what a defensible causal analysis would actually have to look like.

I want to be precise about what this does and does not kill.

It does not kill the idea that ramping training faster than you are accustomed to matters. Practitioners believe that, the mechanism is plausible, and I believe it too.

It does kill the specific claim that a ratio above 1.5 carries a quantified injury risk. That claim did not survive.

Those are two different claims and only the first one is safe to build on.

[APP SCREENSHOT 2 — the load zone strip, showing a zone label rather than a risk number]

## What I actually shipped after reading all that

Four things, and each one is a place where I made the app say less than it could have.

The ratio never predicts injury and never blocks a session. Tuwa's daily verdict is go, modify or hold, with a concrete number attached and a reason line naming its inputs. You override it with one tap and the app does not argue with you.

Zones are labels, not verdicts. Below 0.8 is Load Light, 0.8 to 1.3 Load Steady, 1.3 to 1.5 Load Building, 1.5 and up High Load. Those are the conventional bands. They describe where your training moved. They are not calibrated risk boundaries for you specifically, and I do not write copy that pretends otherwise.

[FIGURE — zone-strip — the shipped bands, carried as labels]

Spikes compare you to you. A session at 1.5× your own recent average gets flagged, 2× gets flagged harder, and it needs at least three prior sessions before it will say anything at all. A spike against your own history is a much less contested signal than a ratio of two smoothed curves.

When nothing is known, nothing is reported. No chronic load yet means the zone says No Data instead of defaulting to something reassuring. Same rule for session monotony and strain in Foster's sense — those only get computed when a 14-day window has at least seven logged days with real variance in them. Below that gate they are statistically fragile on the sparse logs actual amateurs produce, so the app falls back to a coarser signal and tells you which one it used.

## What it does not do

No forecasting. There is no overreach prediction in the shipped app. The load history it draws is 28 days of what already happened.

No programme writing. You or your coach author the plan. Tuwa modulates today's numbers inside it. It never writes it.

No diagnosis. Tuwa is a training tool, not a medical device. It does not diagnose, treat or prevent injury. Pain, fever, dizziness or anything medical overrides anything an app tells you.

## Why I am posting the criticism of my own metric

Because the alternative is worse. Half the training apps on the App Store are selling a number derived from this same literature with none of the caveats, and the caveats are the interesting part. If I only tell you the 2016 version of this story I am selling you a certainty that the field itself retracted.

Every citation, with the arithmetic and the figures: https://tuwa.app/blog/how-tuwa-computes-training-load-ewma-acwr/
---

## TEASER THREAD (2–3 tweets)

**Link the X ARTICLE, not tuwa.app.** An on-platform link
carries no distribution penalty and feeds the dwell-time signal; the canonical URL
already sits inside the Article for anyone who wants the citations.

**Tweet 1**
I built my training-load metric on a 2016 paper with 3,000+ citations.

Then between 2019 and 2021 the statisticians took that paper apart.

I kept the metric. I changed what my app is allowed to say about it. Long post on what survived 👇

**Tweet 2**
The part that died: "your ratio is above 1.5, therefore you are at risk."

Mathematical coupling, schedule confounding, and enough undeclared analytical choices that the direction of the result can flip.

The part that lived: ramping faster than you're used to still matters.

**Tweet 3**
So Tuwa shows a zone and a direction, never a risk score. It compares you to you, not to a population. And when it doesn't know, it says No Data instead of something reassuring.

Every citation, and the arithmetic:
[LINK THE X ARTICLE HERE]
