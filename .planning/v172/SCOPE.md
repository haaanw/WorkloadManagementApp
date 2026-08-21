# v1.7.2 — scope (HAN, 2026-08-13; amended 2026-08-17, 2026-08-21)

Two main objectives, set by HAN the day 1.7.1 (19) went to review.
**2026-08-17 amendment (HAN): a new Objective 0 — natural-language workout
logging — is now the primary lane.** Objectives 1 and 2 stand but yield priority.
**2026-08-21 amendment (HAN): Objective 3 — ASO + App Store screenshot
optimization — added.** Objectives 1–3 are distributed to parallel Claude
sessions; prompts in `.planning/v172/SESSION-PROMPTS.md`.

## Objective 0 — natural-language workout logging (PRIMARY, HAN 2026-08-17)

The main way to log a workout becomes describing it — speak it, type it, or use
the keyboard's dictation mic — parsed by an LLM into an editable draft session.
Manual set entry stays as the correction layer. Approved plan:
`~/.claude/plans/mighty-snuggling-perlis.md`. Key locked decisions:

- Three equal input modalities into one pipeline; in-app voice is never the only door.
- Two capture modes: post-workout narrative (LogCaptureSheet) and live
  incremental (VoiceDictationCard inside ActiveWorkoutSheet, local
  VoiceSetUtteranceParser first, LLM fallback).
- Always editable-draft review in ActiveWorkoutSheet (sets arrive `isDone`);
  never auto-save.
- LLM provider for log mode: **DeepSeek `deepseek-v4-flash`** via the
  `parse-workout` edge function `mode:"log"`; plan mode stays OpenAI. Edge
  function gained JWT verification + per-user daily quota
  (`008_parse_quota.sql`, PARSE_DAILY_LIMIT default 40). Free for all tiers.
- Build log: phases A–E machine-complete 2026-08-17 (suite 988/0/2). Backend
  deployed + curl-verified 2026-08-18 (migration run, `DEEPSEEK_API_KEY` set,
  JWT/quota guards pass — VOICE-UAT §4). **Device UAT WAIVED pre-ship (HAN
  ruling 2026-08-21):** HAN validates on the official 1.7.2 App Store build,
  using `.planning/v172/VOICE-UAT.md` as the script. Committed 2026-08-21.

## Objective 1 — workout-logging UI/UX overhaul (primary lane → second lane 2026-08-17)

The 1.7.1 rounds made the set-entry row *correct*; this milestone makes it *right*.

- **Opening item: the always-visible scrub scale.** HAN's standing critique of the
  current scrub: you cannot know where a swipe lands BEFORE touching it. The scale
  (or whatever form the design lands on) must show the value landscape at rest, not
  only mid-drag. Demo-first like every design lane; HAN gates direction.
- The rest of the logging flow is open for redesign: exercise cards, set list
  density, the finish flow, template interplay, one-handed reach. HAN: "improve the
  UI and the UX for that" — broad mandate, demos before code.

## Objective 2 — codebase review / audit

Find bugs, simplify, optimize the structure. Standing debt that folds in:

- **31 ranked audit findings** from `.planning/v171-hotfix/AUDIT-2026-08-05.md` —
  highest: deletion resurrection (needs tombstones + schema), athlete-field pull
  gaps, `bootstrapAthlete` zombie sign-out.
- **HealthKit protocol seam** so pipeline tests are hermetic (the
  VerdictSurfaceActivation timing fragility class).
- **Per-direction sync status hardening** follow-ons; ScreenshotTests defensive
  launch-retry (boot flake, 3 sightings).
- **Dead weight:** retired UIKit-era leftovers, `Views/Coach/` (compiles unmounted;
  deletion was gated on v1.6 validating — v1.7 is live), unused strings/keys.
- **Bodyweight option C:** athlete body mass (HealthKit read) → true total-load
  math; today 0 kg = BW by convention and external-only volume.
- Wake-relative HRV windowing stays gated on sleep-v2 daily trust (not an audit
  item, listed so it isn't re-discovered).

## Objective 3 — ASO + App Store screenshots (added 2026-08-21)

The current listing is a basic version. Optimize:

- **Screenshot sets** (en + zh-Hans): the framed-caption pipeline exists
  (`scripts/frame_screenshots.swift`, `ScreenshotTests`, SCREENSHOT_MODE seed);
  the sets need a story pass — feature order, captions, seeded data quality,
  and a voice-logging screenshot once Objective 0 ships.
- **Listing copy**: current texts live in `.planning/asc/` (promo, description,
  What's New; en + zh-Hans). Keyword field, title/subtitle, description
  structure all unoptimized.
- Claims must grade to engine status (§10 claim rails); EULA link stays in the
  description body (App Review lesson); no ASC mutation without HAN.

## Not in scope

Sleep score v2 activation (its ≥6-week shadow dogfood runs on its own clock);
algorithm estimator v2 flip (gated on the pre-registered validation, ~40 blinded
days); website/ASO (CODEX lane).
