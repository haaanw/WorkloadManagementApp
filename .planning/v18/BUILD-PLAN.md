# v1.8 onboarding + monetization — build plan

**Status: GATE PASSED (HAN, 2026-09-01) — "resolutions stand," with the
amendments below. Build may start at batch 1 once HAN's widget checklist
completes and the build slot frees.**

## Gate amendments (HAN, 2026-09-01) — these override the sections below

1. **C4 reveal review prompt: DROPPED ENTIRELY.** No rate-the-app prompt on
   screen 9 — "let's not ever use that." `shouldPromptAtReveal` is not
   built; the ONLY review prompt in the app remains the shipped post-save
   gate. Row 9r leaves the screen map. (The shared-cooldown idea dies with
   it; nothing else referenced it.)
2. **Paywall (screen 11): plans are clickable and comparable.** Annual and
   monthly are selectable options, and the screen offers a tap-through
   free-vs-pro comparison (what the free tier keeps vs what Pro unlocks —
   sourced from the real entitlement gates, not marketing copy).
3. **Account screen (10): three first-class doors.** Email, Sign in with
   Apple, AND Sign in with Google — Google is already fully wired in the
   shipped app (`AuthService.signInWithGoogle`, used by LoginView +
   SignUpView), so the demo's omission was a demo error. Apple and Google
   are NOT small alternatives under an email form; they get their own
   premium-feeling primary treatment (within DESIGN.md v6 — the premium
   reading comes from spacing, type, and relief, not from new colors or
   shadows; Apple's and Google's brand button guidelines still bind).
4. **Overall motion: more dynamic.** The flow should feel alive — staged
   annotation reveals, count-up on the reveal number, spring transitions
   between screens — all via the existing `Motion` tokens and
   `.annotationReveal(index:)`, never new physics. Demo round 2 shows the
   motion pass before the build bakes it in. Written 2026-08-30 against `ONBOARDING.md`
(APPROVED 2026-08-24), `GROWTH-STACK.md`, and `.planning/v173/SCOPE.md` app
feature 4. Every code citation below was re-read in the current tree this
session — the spec's own citations are six days old and the audit deleted
files since.

Work order (HAN, 2026-08-30): (1) this plan; (2) demo for HAN's visual gate
(`.design-explorations/onboarding-v18-demo/`); (3) build behind a feature
flag; (4) suite green per batch. No RevenueCat/ASC config from any session.

---

## 1. Spec-vs-code conflicts — points where both cannot be true

These are the findings the work order asked for. Each has a resolution the
build will follow unless HAN overrules.

### C1. The reveal (screen 9) cannot run `RecoveryPipeline` — no Athlete exists yet

The spec contradicts itself:

- §2 screen table: screen 9 "Writes: RecoverySnapshot".
- §8.1: "quiz answers live in memory … nothing needs to persist before
  screen 10."

`RecoveryPipeline.run(athlete:healthKitService:modelContext:)`
(`RecoveryPipeline.swift:21`) requires an `Athlete` and upserts a
`RecoverySnapshot` — both impossible before account creation at screen 10,
and creating a provisional local Athlete pre-auth would break the sync
identity guard and the zombie-account logic in `AppRouter`.

**Resolution: the reveal computes in memory and persists nothing.** A new
`OnboardingRevealService` reuses the exact live pieces the pipeline uses —
`fetchHRVHistory` / `fetchRestingHRHistory` (90 days), `ReadinessInputReducer`,
`RecoveryScoreEngine` — and returns a value struct (score, zone, HRV baseline,
confidence bucket, observed-day count). After signup at screen 10, the normal
`RecoveryPipeline.run` executes and writes the first real snapshot. The §2
table's "Writes: RecoverySnapshot" happens at screen 10, not 9. The two
numbers come from the same math, so they agree.

### C2. "Baseline confidence ≥ confFloorDays (14)" is a type mismatch

`BaselineEngine.confidence` (`BaselineEngine.swift:342-345`) is a 0–1
composite where `cCount = clamp01((count − 14) / (60 − 14))` — **at exactly 14
observed days the composite is 0.0**, so "confidence ≥ 14" compares a ratio to
a day count, and "confidence > 0" would actually mean ≥15 days. Worse, the
live readiness score does not use `BaselineEngine` at all — the robust
estimator is the DARK v2 arm (locked scope: activation off until parity
gates pass). Branching the paywall on the dark arm would make a monetization
gate depend on an unvalidated engine.

**Resolution: the branch predicate is a day count, not an engine value.**
`realBranch = (distinct prior wake-days with an HRV daily reduction in the
90-day fetch) ≥ BaselineEngine.BaselineConstants.confFloorDays (14) AND the
reveal computed a real score`. The constant is still read from
`BaselineEngine` so the two never drift. The confidence BUCKET shown on
screen 9 (and sent to analytics as `floor|partial|full`) maps from the same
count: `<14 → floor`, `14–59 → partial`, `≥60 → full`
(`confFullDays = 60`, `BaselineEngine.swift:162`).

### C3. HealthKit "denied" is unobservable — and that is fine

Apple never reveals READ denial: a denied grant looks identical to
granted-with-no-data (`connectionState` goes `.requestedNoData` either way —
`HealthKitService.swift:123`, `RecoveryPipeline.swift:105`). The spec's §4
branch already treats "denied" and "granted with insufficient data"
identically, so nothing breaks — but the analytics events `hk_granted` /
`hk_denied` (GROWTH-STACK §1.2) **cannot be emitted as named**.

**Resolution:** emit `hk_prompt_completed` with
`outcome: data_found | no_data` (post-fetch, observed truth) instead of
granted/denied. The funnel keys on the branch anyway, and a fabricated
grant/deny split would be wrong data.

### C4. `ReviewPromptGate` is save-shaped; the reveal prompt is a second entry, not a parameter

`ReviewPromptGate.shouldPrompt` (`ReviewPromptGate.swift:22`) requires
≥5 sessions and a fresh workout save — screen 9 satisfies neither. Spec §8.6
says "add the reveal-confidence condition".

**Resolution:** add `ReviewPromptGate.shouldPromptAtReveal(branch:confidenceBucket:lastPromptedAt:)`
— fires only on the real branch with bucket ≥ partial, once per install, and
**shares `lastPromptedAtKey`** with the existing save gate so the two gates
observe one cooldown and a user can never be prompted twice in 60 days
(this also answers CODEX X-dist-003 point 4). Apple's 3-per-365 cap is spent
knowingly; the reveal prompt is the highest-sentiment moment we own.

### C5. Screens 1–9 run pre-auth, but today's router puts onboarding behind login

Verified: `AppRouter.swift:20-25` routes `login` before `onboarding`;
`needsOnboarding` derives from `trainingFrequency == nil || experienceLevel
== nil` (lines 72, 192). The new flow inverts the order for fresh installs.
Not a contradiction — the spec names this (§8.1) — but three router facts
must survive the restructure:

- A returning user with a Keychain session must never see the flow
  (`hasSession` check, line 137, stays the first gate).
- A logged-out RETURNING user needs a "log in" affordance on screen 1 that
  jumps straight to `LoginView` — the spec is silent on this; without it an
  existing customer reinstalling must answer a quiz to reach their login.
- The zombie/bootstrap paths (lines 143-162) are untouched; they run only on
  the session path.

### C6. Screen 12's "discounted annual" cannot be coded against config that does not exist

The exit offer is an ASC promotional offer + a dedicated RevenueCat offering
(HAN-owned, ONBOARDING §10). `SubscriptionService.fetchOffering(for:)`
(`SubscriptionService.swift:88`) knows only the two tier offerings.

**Resolution:** code fetches an offering by identifier
(`onboarding` / `onboarding_exit`) with graceful degradation: if the offering
or its discounted package is absent, screen 12 is skipped and a hard-paywall
dismiss intent simply returns to screen 11. The flow must be shippable and
testable before HAN's dashboard work lands. I draft the exact ASC/RevenueCat
configuration for HAN as part of the build; no session touches either.

### C7. Quiz Q1/Q2/Q3 have no home in the schema — and should not get one

`Athlete` carries `trainingFrequency` / `experienceLevel` only (verified,
`Athlete.swift:19-20`). Q1 (what breaks), Q2 (sport split), Q3 (last time you
trained through fatigue) are segmentation, not physiology.

**Resolution: no schema change.** Answers live in the in-memory
`OnboardingAnswers` struct; Q6/Q7 write to `Athlete` after signup (same as
today's `completeOnboarding`, `OnboardingView.swift:291`); Q1–Q3 leave the
device only as low-cardinality `choice_id`s on `onboarding_quiz_answered`.
Q2 personalizes screen 9's copy in memory. If HAN later wants segments
server-side, that is a migration decision, not an onboarding one.

### Non-conflicts verified while looking

- Spec line citations for `OnboardingView.swift` (147/177/250),
  `AppRouter.swift` (10/23/72/192, LoginView 34), `BaselineEngine.swift`
  (161-162), `DashboardViewModel.swift` (154) — all still accurate.
- Language selection already has a Profile home: `LanguagePickerView.swift`
  exists in `Views/Profile/`. Removing screen 0 costs nothing;
  `LocaleManager` resolves the system locale at init (verified).
- The connected-state re-ask guard (`connectionState` routing,
  `OnboardingView.swift:177`) carries over into the new screen 8 unchanged.
- `SignUpView.swift` already contains the full account-creation sequence the
  new screen 10 needs (signUp → athlete insert → `pushAthlete` →
  `subscriptionService.logIn` via the router's `onChange` → `setAuthenticated`).
  Screen 10 embeds this logic; it must NOT set `isAuthenticated` in a way that
  routes to `.main` before screens 11/12 run — see the state machine.

---

## 2. Screen map (build names, one job per screen)

Flow name: **OnboardingV2** (feature-flagged; the shipped `OnboardingView`
stays untouched until HAN flips). Coordinator + one file per screen — the
spec forbids growing one 307-line file to 12 steps (§8.2).

| # | View | Job | Writes | Notes |
|---|------|-----|--------|-------|
| 1 | `ColdOpenScreen` | Name the problem; one CTA | — | "Log in" affordance → `LoginView` (C5) |
| 2 | `QuizProblemScreen` | Q1 what breaks your training | memory | 4 options |
| 3 | `GapScreen` | The positioning chart | — | one chart, one line; app-surface imagery only (§5.1) |
| 4 | `QuizSplitScreen` | Q2 sport + lifting split | memory | personalizes screen 9 copy |
| 5 | `QuizFatigueScreen` | Q3 lived outcome | memory | only injury-adjacent screen; no prevention claim |
| 6 | `QuizFrequencyScreen` | Q4 training frequency | memory → Athlete at 10 | reuses `TrainingFrequency` cases |
| 7 | `ExperienceScreen` | experience level | memory → Athlete at 10 | reuses `ExperienceLevel` cases |
| 8 | `HealthConnectScreen` | "read your last 90 days" framing | HK auth | keep `connectionState` routing + skip affordance |
| 9 | `RevealScreen` | real readiness, HRV baseline, confidence | — (C1) | real or degraded per branch; degraded names the date the first real number arrives |
| 9r | review prompt | granted branch, bucket ≥ partial only | UserDefaults | C4; not a screen, an overlay moment |
| 10 | `AccountScreen` | create account | Supabase + Athlete + quiz flush | embeds SignUpView logic; existing-account link |
| 11 | `OnboardingPaywallScreen` | trial-default paywall | purchase | hard/soft per branch; distinct offering (C6) |
| 12 | `ExitOfferScreen` | discounted annual | purchase | dismiss-intent only, once per install; skipped if offering absent (C6) |

Screen count: 12 max, converting path ends at 11 — matches spec §2.

## 3. Paywall-gate state machine

Persisted state (UserDefaults, all namespaced `onboardingV2.`):

- `completed: Bool` — set when the flow hands off to `.main`.
- `branch: String?` — `real` / `degraded`, stamped at screen 9 entry.
- `paywallPending: Bool` — true from screen 11 presentation until purchase
  or (soft) explicit "not now". **Survives relaunch** — see below.
- `exitOfferShown: Bool` — once per install.
- `softPaywallShownAt: Date?` — starts the day-7 re-ask clock.
- `reaskDone: Bool` — the day-7 re-ask fired.

```
fresh install, flag ON, no Keychain session
    → screens 1..8 (answers in memory; back allowed 1..8; "log in" exits to LoginView)

screen 8 → [connect] system HK sheet → fetch 90d → reduce
         → [skip]                       (no fetch)
    branch := (observed prior HRV wake-days ≥ 14 AND score real) ? REAL : DEGRADED   (C2, C3)

REAL:     screen 9 real reveal → review prompt (C4 gate) → screen 10 account
DEGRADED: screen 9 degraded (states the DATE of the first real number:
          today + (14 − observedDays) days) → screen 10 account

screen 10 success → athlete row + quiz flush + RC logIn → screen 11
    (setAuthenticated is deferred / the router respects paywallPending —
     the flow, not the auth flag, decides when .main renders)

screen 11 HARD (branch=REAL):
    no dismiss affordance
    [purchase/trial] → completed → .main
    [dismiss intent] → if !exitOfferShown && exit offering exists
                          → screen 12 → [accept] → .main
                                        [decline] → back to 11
                       else stay on 11
    relaunch while paywallPending && !isPro → resume AT screen 11
    (an account exists; the wall is the product boundary, not a UI accident)

screen 11 SOFT (branch=DEGRADED):
    [purchase/trial] → completed → .main
    ["not now"] → completed, free tier → .main; softPaywallShownAt := now

day-7 re-ask (soft branch only, once):
    dashboard appear && now ≥ softPaywallShownAt+7d && !isPro && !reaskDone
    && observed HRV days ≥ 14 (the app now has data — spec §4)
    → present soft paywall once; reaskDone := true
```

Existing contextual `UpgradeSheet` triggers (5 sites, verified) are
untouched and keep their own offerings — the funnel separability GROWTH-STACK
§1.2 requires.

Hard-paywall honesty note for HAN: `isPro` can also arrive via restore —
screen 11 (both variants) carries the standard Restore Purchases link, which
on success routes to `.main`. Required by App Review 3.1.1.

## 4. Instrumentation (build phase, not after)

- PostHog iOS SDK via SPM — **its own commit, flagged to HAN** (`.pbxproj` +
  package resolution; CLAUDE-only file). Privacy manifest verified before the
  commit lands (GROWTH-STACK §1.1 + CODEX X-dist-003.1).
- `UXAnalyticsService` stays the ONLY egress: new `AnalyticsSink` protocol,
  PostHog registered as a sink behind the existing `sanitized(_:)`
  chokepoint. Views never import PostHog. The event enum grows the §1.2
  onboarding cases; every numeric property is a bucket (`confidence:
  floor|partial|full`, `readiness_band: low|mid|high`), never a value.
- `hk_granted`/`hk_denied` replaced by `hk_prompt_completed{outcome}` (C3).
- Release gate (CONCEDED to CODEX, HAN-owned): ASC privacy label reconciled +
  PostHog manifest disclosure entries added before the flag flips. The label
  today reads "Data Not Collected" and is already wrong for account/sync
  data; PostHog widens it.
- Benchmark note: RevenueCat 2026 H&F D35 median 2.9%, upper quartile 6.2%
  (CODEX X-dist-004). Operating gate stays 4% (GROWTH-STACK Gate 1); 9% stays
  labeled top-decile.

## 5. Feature flag

`OnboardingV2Flag` — a static gate read once at router level:
`UserDefaults` key `flag.onboardingV2` (default **false**), plus a DEBUG
launch argument `ONBOARDING_V2` for demos/screenshots/UAT. While false, the
shipped 4-step `OnboardingView` and the login-first route are byte-identical
to today. The flag governs the ROUTE only; the new files compile in both
states (no dead-code fence issues). HAN flips by one-line default change
(their explicit go), which is also the moment the §4 release gate applies.

## 6. Build batches (each ends with a green suite)

1. **Scaffold + flag + coordinator** — `OnboardingV2Flow` coordinator,
   `OnboardingAnswers`, router branch behind the flag, screens 1–7 (static
   content + quiz), en keys. No paywall, no HK.
2. **HealthKit + reveal** — screen 8 (reuse `connectionState` routing),
   `OnboardingRevealService` (C1), screen 9 real/degraded, branch predicate
   (C2/C3), review-prompt entry (C4).
3. **Account + paywall + exit** — screen 10 (SignUpView logic embedded),
   `OnboardingPaywallScreen` hard/soft, screen 12 with graceful-absence
   (C6), paywallPending resume, day-7 re-ask hook.
4. **PostHog SPM (own commit) + sink + events** (§4).
5. **zh-Hans localization** — after coordinating on `Localizable.xcstrings`
   (it carries another session's uncommitted WIP; nothing appended until
   that session lands or releases).
6. **Fence + suite pass** — design fences green, ScreenshotTests green, new
   unit tests for: branch predicate, state-machine persistence/resume, review
   gate sharing, sanitizer-over-sink, flag-off byte-identical routing.

DESIGN.md v6 binds every screen: CornerTokens only, no shadows, two-voice
type, hero readiness in `metric-readiness`, travertine for the step dots
(the flow's one live-state mark, per the existing `OnboardingView.swift:250`
ruling), one ink pill per screen, 8pt grid, light only, `Motion` tokens,
`.annotationReveal(index:)` for mono labels.

## 7. HAN-owned items (unchanged from spec §10, plus two)

- ASC: intro trial on athlete_pro, screen-12 promotional offer, RevenueCat
  onboarding + exit offerings (I draft exact configs at build time).
- **ASC privacy label reconciliation + PostHog vendor approval** (release
  gate, §4).
- Photography ruling (§5) — the demo uses app-surface imagery only, so the
  ruling can wait until HAN sees the demo.
- Version number at submission.
