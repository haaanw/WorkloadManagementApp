# v1.7.2 — scope (HAN, 2026-08-13)

Two main objectives, set by HAN the day 1.7.1 (19) went to review.

## Objective 1 — workout-logging UI/UX overhaul (primary lane)

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

## Not in scope

Sleep score v2 activation (its ≥6-week shadow dogfood runs on its own clock);
algorithm estimator v2 flip (gated on the pre-registered validation, ~40 blinded
days); website/ASO (CODEX lane).
