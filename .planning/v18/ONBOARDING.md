# v1.8 — onboarding redesign + monetization model change

Status: **APPROVED by HAN 2026-08-24.** Spec, not a proposal.
Version label RESOLVED (HAN, 2026-09-02): **this ships as v1.7.3.**
Amended 2026-09-02 (HAN, on the record in BUILD-PLAN.md "Amendments"):
program-import moment + daily-use tutorial JOIN the flow; screens 6–7
(training frequency, experience level) LEAVE it (engine-dead, stay editable
in Profile); quiz screens 2/4/5 stay. BUILD-PLAN.md amendments override
the screen table below where they conflict.

Related: `.planning/v173/MARKETING.md` (marketing lane), `GROWTH-STACK.md`
(instrumentation, offers, ads — the funnel this spec is measured by).

---

## 1. The approved model

Three coupled decisions. Each one is load-bearing; changing one invalidates the
numbers in §7.

1. **Hard paywall, placed after the user sees their own real readiness number.**
   Not after manufactured investment. After output.
2. **Apple's card-gated introductory trial.** NOT a no-card trial.
3. **The gate is conditional on the HealthKit grant.** Granted-with-data → hard
   paywall. Denied or no data → dismissible paywall, user lands in the free tier,
   paywall returns at day 7.

### Why the placement works here (the fact the decision turns on)

Tuwa has a **true day-zero payoff**, which almost nothing in this category has.

- `DashboardViewModel.swift:154` and `RecoveryViewModel.swift:48` pull
  `fetchHRVHistory(days: 90)`. `RecoveryPipeline.swift:53-63` pulls HRV and RHR
  across the baseline window. `SleepDetailView.swift:159` pulls 90 nights.
- `BaselineEngine.swift:161-162` — `confFloorDays = 14`, `confFullDays = 60`.

So a user who already wears a watch has, at the moment of the HealthKit grant,
enough history for a **confident** baseline. The app computes a real readiness
score in seconds. Competitors must fake this moment with a loading animation. We
show the user their own body. That is what earns the right to a hard paywall.

### Why not the no-card trial

Rejected on the merits, not on effort. Tuwa's value compounds — the day-14
verdict beats the day-1 verdict. A no-card trial requires the user to return on
day 7 and buy deliberately, which is exactly the day the novelty is gone and
they have had their first unwelcome red readiness. Apple's trial converts by
default at that moment. In Health & Fitness 82.1% of trials start on day zero.
The no-card path also adds a server-side grant beside `SubscriptionService.isPro`
(a second source of truth) and a reinstall exploit to close.

### Why the gate is conditional

Without HealthKit data, `RecoveryScoreEngine` returns a placeholder. Selling a
hard subscription against a placeholder produces refunds, one-star reviews, and
churn. The conditional gate is the honest reading of a product whose primary
input is a wearable. It also yields two clean funnels instead of one muddy one.

---

## 2. Screen table

12 screens maximum, and the flow ends at 11 for a converting user. Screen 12
fires only on a dismiss attempt.

| # | Screen | Job — why it earns its place | Writes | Kill criterion |
|---|---|---|---|---|
| 1 | Cold open | Name the problem in the user's words: you train hard, alone, and nobody is watching the load | — | <90% advance |
| 2 | Quiz Q1 (4 opt) | What breaks your training: injury / stalling / always tired / guessing. Self-diagnosis beats our assertion | segment | <85% |
| 3 | The gap | One chart: everyone who modulates owns your program; everyone who accepts your program refuses to modulate | — | <90% |
| 4 | Quiz Q2 (4 opt) | Sport + lifting split. Segments the beachhead and personalizes screen 9 | segment | <90% |
| 5 | Quiz Q3 (4 opt) | "Last time you trained through fatigue, what happened" — commitment device, and the only screen that earns the injury framing | segment | <88% |
| 6 | Quiz Q4 | Training frequency | `athlete.trainingFrequency` | <92% |
| 7 | Experience level | Experience level | `athlete.experienceLevel` | <92% |
| 8 | HealthKit connect | Framed as "read your last 90 days", never "grant permission" | HK auth | <70% grant |
| 9 | **Reveal** | Your readiness today, your HRV baseline, your data confidence. The payoff | RecoverySnapshot | <95% advance |
| 10 | Account | Cheap now — they have seen their number | Supabase + Athlete | <80% |
| 11 | **Paywall** | Trial default. Hard or soft per the §4 branch | purchase | see §7 |
| 12 | Exit offer | Fires only on dismiss intent. Discounted annual | purchase | — |

**Language selection leaves onboarding.** Today's screen 0 buys nothing —
`LocaleManager` already resolves the system locale at init, and the flow
pre-selects it. It moves to Profile. That is the free screen that pays for the
reveal.

Every screen keeps one job. If a screen cannot state its job in one sentence and
name the drop-off it prevents, it does not ship.

---

## 3. Per-screen notes that are not obvious

**Screen 1 — cold open.** No feature list. No logo parade. One statement of the
user's problem and one primary CTA. This screen is measured on advance rate
only.

**Screen 3 — the gap.** This is the anti-positioning from `CLAUDE.md` rendered
once, visually: Whoop/Bevel give scores without your plan; AI-coach apps give
their plan; TrainingPeaks holds your plan and makes no decisions. Tuwa takes
your plan and makes it safe. Do not write this as a comparison table — a table
invites reading. One chart, one line of copy.

**Screen 5 — the commitment screen.** The four options are outcomes the user has
lived (missed weeks, a nagging joint, a bad game, nothing yet). This is the only
place the flow may reference injury, and it references the user's own history,
never a threat. Health-claim guardrail: no prevention claim, ever.

**Screen 8 — HealthKit.** Rewrite the framing. Today `OnboardingView.swift:147`
asks for permission and lists three data types. The new screen states what the
user gets back: "Tuwa reads your last 90 days of HRV, resting heart rate, and
sleep, so today's number means something on day one." Keep the existing
`connectionState` routing (`OnboardingView.swift:177`) — a returning user who
already granted must never be asked twice. Keep the skip affordance; §4 handles
that branch.

**Screen 9 — the reveal.** The hero readiness number, its metric hue, the
baseline confidence, and one sentence of what it means today. The number must be
**real**. If the pipeline returns a placeholder, this screen must not pretend —
it degrades to the §4 branch. Faking this screen destroys the only honest
advantage the flow has.

**Review prompt after screen 9, granted branch only.** `ReviewPromptGate.swift`
already exists. Cal AI collects ratings mid-onboarding at peak sentiment, before
any subscription friction, and the resulting rating lifts organic conversion on
the product page for all traffic. We take the same tactic with one restriction
Cal AI does not have: prompt **only** when the reveal produced a real number at
or above the confidence floor. Never in the denied branch. A rating request from
a user we have shown nothing to is how you buy one-star reviews.

**Screen 10 — account.** Placed before the paywall, not after. Reasons: the
purchase always attaches to a real App User ID (no anonymous→identified aliasing
edge cases, and `SubscriptionService.logIn` already keys on the Supabase UUID);
and we capture the email of users who refuse to pay, which is worth real money
to a pre-launch list. Cost: a few points versus Cal AI's post-paywall placement.
Accepted.

**Screen 12 — exit offer.** Triggered by dismiss intent on screen 11, once per
install. Discounted annual. Configured in App Store Connect as a promotional
offer; see `GROWTH-STACK.md` §4 for how this differs from the three other offer
surfaces.

---

## 4. The branch

```
screen 8 → HealthKit authorization
    │
    ├─ granted AND baseline confidence ≥ confFloorDays (14)
    │     → screen 9 real reveal
    │     → review prompt (gated)
    │     → screen 10 account
    │     → screen 11 HARD paywall (no dismiss; trial default)
    │            └─ dismiss intent → screen 12 exit offer
    │
    └─ denied, OR granted with insufficient data
          → screen 9 degrades: "no wearable history yet — here is what Tuwa
            needs and when your first real number arrives"
          → screen 10 account
          → screen 11 SOFT paywall (dismissible, "not now" → free tier)
                 └─ day-7 return: paywall re-presented once the app has data
```

The degraded screen 9 states a date, not a vague promise. It is the screen that
sets up the day-7 re-ask, so it must name the day.

---

## 5. Visual language — one open decision for HAN

HAN's directive is **images over text**. DESIGN.md v6 has no illustration
language and bans icon fonts and emoji outright. I will not invent a visual
language to satisfy a screen count; §"Design System" of `CLAUDE.md` forbids
deviating without explicit approval.

Three sanctioned sources of imagery, in order of preference:

1. **The app's own surfaces** — real chart renders, the verdict card, the load
   chart, the strike-zone bar. Honest, free, on-brand, and it previews the
   product. This covers screens 1, 3, and 9 fully.
2. **The voice-logging screen recording.** `MARKETING.md` §3 already names voice
   logging the marketing spearhead across all channels. A 4-second silent loop
   of a spoken set becoming a logged set is the single best asset we own.
3. **Photography** — NOT sanctioned by v6. If HAN wants photography in
   onboarding, that is a design-system decision and needs an explicit ruling
   before any screen is built.

Binding constraints on every screen: `CornerTokens` only (card 12 / control 8 /
pill); no shadows — relief via `.raised` / `.debossed`; Instrument Sans speaks
and Fragment Mono annotates at ≤12pt uppercase; the reveal's hero number takes
`metric-readiness` per the Reading Color Rule; travertine accent for live-state
marks only (the step dots, per `OnboardingView.swift:250`); one ink-filled pill
CTA per screen; 8pt grid; light only; `.annotationReveal(index:)` for the mono
labels; `Motion` tokens for all transitions.

**Localization cost, stated plainly:** 12 screens of new copy in en and zh-Hans,
into `Localizable.xcstrings`. zh-Hans takes no case transform and no added
tracking. This is not a rounding error — budget it as its own task.

---

## 6. Permissions map

The user asked to explore permission access. Four prompts exist or will exist.
Order and placement matter more than the prompts themselves.

| Permission | Placement | Reason |
|---|---|---|
| HealthKit | Screen 8, in onboarding | It is the product. Without it there is no reveal and no honest sale |
| Speech / microphone | First use of `LogCaptureSheet`, NOT onboarding | Voice logging is free for all tiers. Prompting for the mic before the user has a workout to log wastes the grant |
| Notifications | After the first real verdict, NOT onboarding | A notification prompt on day 0 has nothing to notify about. Ask when the daily verdict exists |
| App Tracking Transparency | Only when paid ads start | Prompting for ATT with no attribution consumer wired up burns the ask. See `GROWTH-STACK.md` §5 |

Rule: no permission prompt ships without a screen that has already explained
what the user gets for it.

---

## 7. Targets and measurement definitions

The definitions are the load-bearing part. A target without a definition is a
number to argue about later.

- **Onboarding completion = reached screen 11.** Not "paid". At 75% with a hard
  paywall at screen 11 this is realistic; value-first flows benchmark 60-80%
  and flows with long intake forms or early paywalls complete below 40%. Our
  paywall is late by construction, which is what buys the 75%.
- **Download-to-paid (D35).** Start 4%, target 9%. Context: Health & Fitness
  median is 2.56% in North America and the 90th percentile is 11.3%. So 4% is
  already above median and 9% is top-decile. Reachable only with the hard
  paywall; not reachable at all with contextual paywalls alone.
- **HealthKit grant rate at screen 8** — the leading indicator for everything.
  Below 70%, the paywall math collapses because most users route to the soft
  branch. Fix screen 8 before touching the paywall.
- **Per-screen advance rate** — the kill criteria in the §2 table. Any screen
  below its floor for two weeks gets rewritten or deleted.

Segment every metric by the §4 branch. A blended number hides which product we
are actually selling.

---

## 8. Engineering work list

1. **Router restructure** — `AppRouter.swift`. Onboarding currently sits behind
   the auth gate (`needsOnboarding` at lines 10/23/72/192, `LoginView` at 34).
   The new flow runs screens 1-9 with no account, so quiz answers live in memory
   and are written to `Athlete` after signup at screen 10. The Supabase-only
   constraint (no local sync fallback) stays satisfied because nothing needs to
   persist before screen 10.
2. **`OnboardingView` rebuild** — 307 lines today, 4 steps. New flow is a
   coordinator plus screen views; do not grow one file to 12 steps.
3. **Reveal screen** — needs `RecoveryPipeline` to run inside onboarding, and
   needs the confidence value surfaced (`BaselineEngine` confFloor/confFull) to
   pick the §4 branch.
4. **Paywall placement** — new `UpgradeSheet` trigger for the onboarding
   context, hard and soft variants. Today's five contextual triggers stay.
5. **RevenueCat** — a distinct onboarding offering so the funnel is separable
   from contextual paywalls.
6. **`ReviewPromptGate`** — add the reveal-confidence condition.
7. **Instrumentation** — per `GROWTH-STACK.md` §2. Ships with the screens, not
   after them. An uninstrumented funnel cannot be optimized, and optimizing this
   funnel is the entire point of the release.
8. **Localization** — 12 screens × en/zh-Hans.

Suite must stay green (1068/0/2 at 1.7.2). Design-fence tests will catch any
hand-typed radius, shadow, or banned font string.

---

## 9. Risks, stated before they bite

1. **The free tier stops being the default path.** Today anyone can install and
   use Tuwa forever with 7-day history. After this, most first sessions end at a
   wall. That is the intent, and it is still a real change to what the app is.
2. **A hard paywall raises refund pressure.** Mitigation is the honest branch in
   §4 plus the Customer Center refund offer (`GROWTH-STACK.md` §4).
3. **Screen 9 depends on the user's wearable history, which we do not control.**
   If the granted-branch share is small, this release converts like a soft
   paywall and the 9% target does not arrive. Measure the grant rate first.
4. **Review-prompt blowback** if the gate leaks into the denied branch. The gate
   is the mitigation; it must be tested, not assumed.

## 10. HAN-owned items (no session touches these)

- App Store Connect: the introductory trial on the athlete_pro product, and the
  screen-12 promotional offer. I draft the exact configuration; HAN enters it.
- The photography ruling in §5.
- The version number.
- Requesting access to Apple's Retention Messaging API (`GROWTH-STACK.md` §4).
