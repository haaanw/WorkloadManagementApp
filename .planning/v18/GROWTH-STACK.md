# v1.8 growth stack — instrumentation, offers, ASO, paid ads

Companion to `ONBOARDING.md`. That file specifies the funnel; this file
specifies how we see it, how we defend the subscription, and in what order we
are allowed to spend money.

Standing rule: agents draft, HAN ships. Nothing here authorizes an outward
action — no App Store Connect mutation, no ad account, no vendor signup.

---

## 1. Product analytics — decision: PostHog

HAN allowed either PostHog or Mixpanel. I pick **PostHog**, and the deciding
reason is not the funnel view — Mixpanel's funnel tooling is better and I will
say so plainly.

It wins on the three things this release actually needs:

1. **Experiments in the same product.** Cal AI ran 61 paywall experiments to
   find a "$0.00" CTA. We will need many paywall and screen-order tests, and
   PostHog carries feature flags, experiments, and surveys beside the analytics.
   Mixpanel would need a second vendor for that.
2. **Free tier that survives a launch.** 1M events per month, no time limit,
   across analytics, replay, flags, experiments, and surveys. Mixpanel cut its
   free tier to 1M events in late 2025 and prices by tracked users, which is the
   wrong meter for a screen-by-screen funnel that fires ~15 events per install.
3. **A privacy escape hatch.** EU cloud, and self-hosting if we ever need it.
   That matters for an app whose core constraint is that raw HealthKit data never
   leaves the device.

Mobile session replay is available, on its own meter at roughly twice the web
rate, with the native iOS SDK defaulting to a **wireframe** view rather than
screenshots. Turn it on for onboarding only, at a sampled rate, and turn it off
once the flow stabilizes.

### 1.1 Integration design — one egress path, reusing what exists

`UXAnalyticsService` (in `WorkloadApp/Services/AnalyticsEngine.swift`) already
has exactly the right shape: a `track(_:properties:)` API and a
`sanitized(_:)` filter that drops any property key containing `raw`,
`healthkit`, `hrv`, `rhr`, `heart`, `sleep`, `temperature`, `vo2`, or
`biometric`.

**Keep it as the only funnel API and add PostHog as a sink behind it.** Do not
call the PostHog SDK from views. The existing sanitizer then becomes the single
chokepoint through which nothing health-shaped can escape, and it is already
covered by tests.

Two hard rules on top:

- **Bucket every number; never send a value.** `confidence: floor|partial|full`,
  not the confidence figure. `readiness_band: low|mid|high`, not the score. A
  readiness score is a composite and our own policy permits composites to leave
  the device, but sending it to a third-party vendor would drag Health & Fitness
  data into `PrivacyInfo.xcprivacy` and into the App Store privacy disclosure.
  Buckets keep the manifest honest and cost us nothing analytically.
- **Verify the SDK privacy manifest** before it goes in the project. Third-party
  SDKs need a privacy manifest and a signature. Confirm PostHog's iOS SDK ships
  both, and add the required disclosure entries. Also: `.pbxproj` edits are
  CLAUDE-only per `.pair/PROTOCOL.md` §4.

### 1.2 Event spec

Fires with the screens, not after them. An uninstrumented funnel cannot be
optimized, and optimizing this funnel is the whole release.

| Event | Properties |
|---|---|
| `onboarding_started` | `install_day`, `locale` |
| `onboarding_screen_viewed` | `index` (1-12), `screen_id` |
| `onboarding_screen_advanced` | `index`, `ms_on_screen` |
| `onboarding_quiz_answered` | `question_id`, `choice_id` (low cardinality only) |
| `onboarding_abandoned` | `index`, `screen_id` |
| `hk_prompt_shown` / `hk_granted` / `hk_denied` | — |
| `reveal_rendered` | `branch: real\|degraded`, `confidence: floor\|partial\|full` |
| `review_prompt_shown` | `branch` |
| `account_created` | `method` |
| `paywall_shown` | `variant`, `gate: hard\|soft`, `offering_id` |
| `trial_started` / `purchase_completed` | `product_id`, `price_tier` |
| `paywall_dismiss_intent` | `variant` |
| `exit_offer_shown` / `exit_offer_accepted` | `offer_id` |
| `onboarding_completed` | `reached_index`, `gate` |

Every event carries the §4-branch dimension. **Segment all reporting by branch.**
A blended funnel hides which of the two products we are selling.

---

## 2. The four offer surfaces — they are not one thing

HAN referred to "App Store retention offers, currently in beta" and "exit
offers". Those are two of four distinct mechanisms. Confusing them wastes
configuration work, so here they are separated.

### 2.1 In-app exit offer — ours, ships with v1.8

Screen 12 of the onboarding. Fires on dismiss intent at the paywall, once per
install. A discounted annual, configured in App Store Connect as a promotional
offer and presented in our own UI. Fully under our control. Build it.

### 2.2 RevenueCat Customer Center — cheap, ships next

An in-app subscription-management and cancellation flow. Its survey routes
automatically: "Too expensive" or "Don't use the app" trigger `rc_cancel_offer`;
"Bought by mistake" triggers `rc_refund_offer`. The promotional offers are
created in App Store Connect, then assigned under **Lifecycle → Retention** in
the Customer Center tab. This also blunts the refund pressure that a hard
paywall creates (`ONBOARDING.md` §9.2).

### 2.3 Apple Retention Messaging API — THIS is the beta HAN meant

Pre-release, and **access must be requested from Apple**. It places a message or
offer on the system cancellation screen inside iOS Settings — the screen we do
not own and today cannot influence. Four message types: text, text with image,
an alternative subscription plan, or a discounted promotional offer.

Requirements to plan around:

- A backend that responds within **700 ms**. Ours would be a Supabase edge
  function; that budget is tight but achievable.
- Per-product and per-locale configuration.
- Sandbox performance testing is mandatory before production.
- Messages display on iOS 15.1+, iPadOS 15.1+, visionOS 1+, macOS 14+.

**Action for HAN now:** request access. The request costs nothing, the queue is
the long part, and nothing else on this list touches the cancellation screen.

### 2.4 Win-back offers — free money, already generally available

Not a beta. Generally available since September 2024; needs iOS 18 and StoreKit 2
(the RevenueCat SDK covers StoreKit 2). Targets subscribers who have **already**
churned, and Apple surfaces them on the product page, in personalized
recommendations, inside the app, in Subscription settings, and through direct
marketing links.

Difference from §2.3 in one line: **Retention Messaging catches the user at
cancellation intent; win-back offers chase the user after they are gone.** Do
both. Track both in App Store Connect Analytics, which reports on introductory,
offer-code, promotional, and win-back offers separately.

---

## 3. ASO

The existing keyword work is in `.planning/store/aso-keywords.md` and
`.planning/handoff/CODEX-C-aso-copy.md`. This section is the ruleset, not a
re-derivation.

- **Field budget:** title 30 characters, subtitle 30, keyword field 100. All
  three are indexed.
- **HAN's no-repeat rule is correct and I confirm it.** Apple indexes the union
  of title, subtitle, and keyword field. A word repeated in two fields buys
  nothing and costs characters. Also indexed and often wasted: the developer
  name and in-app purchase display names.
- **Per-locale keyword fields are free real estate.** en-US and zh-Hans each get
  their own 100 characters. The zh-Hans field is not a translation of the English
  one — it is a second keyword set for a different search language.
- **Tooling:** HAN nominated Astro for keyword discovery. I have not verified
  that tool and take no position on it; AppTweak, Sensor Tower, and MobileAction
  are the established alternatives. Whatever the source, volume estimates are
  estimates — the ranking evidence is our own before/after.
- **Product Page Optimization is free and unused.** Apple lets us A/B test up to
  three treatments of icon, screenshots, and preview against the live page, with
  traffic split and results reported by Apple. This is the cheapest conversion
  work available and it needs no code. Custom Product Pages are the companion:
  dedicated pages per acquisition source, which is how paid ads get a matching
  landing page later.
- **The first two screenshots carry the listing.** With voice logging as the
  marketing spearhead (`.planning/v173/MARKETING.md` §3), screenshot 1 should be
  the spoken-set-to-logged-set moment and screenshot 2 the readiness verdict.

---

## 4. Paid acquisition — gated sequence

HAN's instruction is to hold paid ads until there are real users. I agree, and
the gates below make "real users" a number instead of a feeling.

**Gate 0 — instrument and baseline. No spend.**
PostHog live, the §1.2 events firing, two weeks of organic data. You cannot buy
traffic for a funnel you cannot see; you will only learn that money left.

**Gate 1 — the paywall must convert organically.** D35 download-to-paid ≥ 4%
(the `ONBOARDING.md` §7 start target; category median is 2.56% in North
America). Below 4%, paid traffic converts worse than organic and every dollar
subsidizes a broken screen.

**Gate 2 — Apple Ads Basic, on the $100 credit.**
- New Apple Ads accounts get a one-time **$100 US credit**. Eligibility: be the
  registered App Store Connect account holder with at least one app for sale.
  The credit appears on the Billing page after a payment method is added, and
  **the Apple Ads account must be linked to App Store Connect** for the credit
  to land.
- Basic is automated: set a monthly budget (capped at $10,000 per app) and a max
  cost-per-install, and Apple runs targeting and bidding. Billing is **per
  install, not per tap**. Ads appear only in search results.
- Note on HAN's phrasing: there is no Apple product called "Ads Max". The two
  products are **Apple Ads Basic** and **Apple Ads Advanced**; within Advanced,
  search-results campaigns choose between *Manage Bids* and *Maximize
  Conversions*. Start on Basic. Move to Advanced only when we want brand-defense
  and competitor keyword campaigns, which need manual bids.
- **No MMP is required at this gate.** Apple Ads reports its own installs and
  App Store Connect attributes them. Do not buy attribution we are not using.
- **No ATT prompt at this gate either.** Apple Ads does not need IDFA.

**Gate 3 — MMP, only when a second paid channel opens.**
HAN mentioned AppsFlyer and "AppStack"; I could not confirm an MMP by the latter
name — the candidates worth comparing are:
- **Tenjin** — free to 2,000 conversions/month, then ~$0.04 per conversion. Best
  fit for our volume.
- **AppsFlyer Zero** — 12,000 conversions free in the first year. Fine, and more
  than we need pre-scale.
- **Singular** — 15,000 paid conversions on the free plan.
- **Adjust** — enterprise pricing, no public rates. Wrong tool at our size.
Realistic cost at under 5,000 installs/month is $0–200. Pick at the gate, not
now; the free tiers make this a reversible decision.

**Gate 4 — TikTok ads.** Last, and only after Gate 3. Requires the ATT prompt,
plus SKAdNetwork / AdAttributionKit conversion-value mapping so the network can
optimize on a signal that survives privacy limits. TikTok creative is a separate
production problem from everything above; the voice-logging demo is the asset
that already exists.

---

## 5. Targets and gates, in one table

| Metric | Now | Start target | Goal | Where it is set |
|---|---|---|---|---|
| Onboarding completion (reached screen 11) | unmeasured | 60% | ≥75% | `ONBOARDING.md` §7 |
| HealthKit grant at screen 8 | unmeasured | 70% | 80% | leading indicator for everything |
| D35 download-to-paid | unmeasured | 4% | ≥9% | category median 2.56%, p90 11.3% |
| Trial start rate at paywall | unmeasured | 20% | 35% | 82.1% of H&F trials start on D0 |
| Paid spend | $0 | $0 until Gate 1 | $100 Apple credit at Gate 2 | §4 |

"Unmeasured" is the honest current state for all of it. We have never had product
analytics — `UXAnalyticsService` writes 200 events to `UserDefaults` and nothing
reads them off-device. Every number above is a first measurement, not a
regression target, and the first two weeks of data may move these goalposts.

## 6. HAN-owned actions

1. Request access to the **Apple Retention Messaging API** (§2.3). Do this first
   — it is a queue, not a build.
2. App Store Connect: the introductory trial, the screen-12 promotional offer,
   the Customer Center cancel/refund offers, and the win-back offer.
3. Create the Apple Ads account and link it to App Store Connect so the $100
   credit lands. Do not start a campaign until Gate 1.
4. Approve PostHog as a vendor (a third-party SDK receiving bucketed usage
   events, no health values).
