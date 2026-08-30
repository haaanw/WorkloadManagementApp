# v1.7.3 — scope + release checklist (HAN, 2026-08-24)

One release, shipped when ALL of it is done (HAN ruling 2026-08-24: no thin
metadata release; the missed ASO fields wait for the full version).

## Release checklist — DO NOT SUBMIT 1.7.3 WITHOUT THESE

1. **The version-locked ASO fields (missed in the 1.7.2 submission).**
   Store still serves lowercase `tuwa` + old subtitle + old keywords in
   both storefronts. At submission time: **App Information** page → Name +
   Subtitle; **version page** → Keywords. Paste source:
   `.planning/asc/v172-draft/8-fields-paste-ready.txt`
   (`Tuwa: Training Readiness` / `Tuwa - 准备度与训练负荷`).
2. Demo account in review notes; EULA link stays in the description body;
   `NSHealthUpdateUsageDescription` stays.
3. Version is already bumped in-repo to 1.7.3 (21), commit `f12284f`,
   code-identical to live 1.7.2 today. Build number may advance with the
   feature work; the marketing version stands.

## Work queued for 1.7.3 (gathered; HAN prioritizes at kickoff)

- **Marketing lane** — `.planning/v173/MARKETING.md`: Twitter-first launch
  content (voice logging spearhead), SEO audit, GEO.
- **Science series** — `.planning/v173/SCIENCE-SERIES.md`: weekly cadence,
  three articles live on site; X + Substack editions in
  `tuwa-website/drafts/science-series/` await HAN's posting.
- **Audit leftovers deferred from 1.7.2** (`.planning/v172/AUDIT-HANDOFF.md`
  resolution log): localization-key prune (§3.3), L9 two-"week"s copy call
  (§3.5), L6 stage clipping (gated on the sleep-v2 shadow window closing),
  L8 push watermark (sync-contract design), L7 (female-athlete milestone).
- **Post-release validation on official 1.7.2** (can run any time, not
  gated on 1.7.3): `.planning/v172/VOICE-UAT.md` sections 1–3 + 5 on
  device; watch the first ReviewPromptGate ratings arrive; note the ASC
  baseline before the new listing fields land (for `10-ab-rationale.md`).
## App features — NAMED at kickoff (HAN, 2026-08-30)

1. **Voice logging round 2 — dogfood first.** HAN tries the shipped 1.7.2
   voice input on the official build (`.planning/v172/VOICE-UAT.md` is the
   script); his findings become the fix list. The improvement lane opens on
   his report, not before.
2. **Voice section UI redesign.** The capture surfaces (LogCaptureSheet,
   VoiceDictationCard) get a design pass. Demo-first per house style; folds
   in whatever round 1 dogfood surfaces, so it runs behind item 1.
3. **iOS home-screen widgets (WidgetKit).** New widget extension target —
   `.pbxproj` is CLAUDE-only and target creation is the big serialization
   point. Needs an App Group so the widget can read shared data; HealthKit
   raw data stays out of the shared container (composite scores only, same
   law as sync). Candidate widgets: today's readiness reading + verdict;
   training-load strip. Light-only, v6 tokens, no shadows — DESIGN.md binds
   widgets exactly as it binds the app.
4. **The onboarding journey — the approved v1.8 spec rides into this
   release** (HAN 2026-08-30). Spec: `.planning/v18/ONBOARDING.md` (APPROVED
   2026-08-24) + `.planning/v18/GROWTH-STACK.md`. ≤12 screens ending in the
   HealthKit-conditional hard paywall after a real readiness reveal,
   card-gated Apple trial, account creation at screen 10, PostHog behind
   UXAnalyticsService. NOTE: the spec says this is not a point release
   (monetization model changes) — the marketing-version number stays HAN's
   call at submission; 1.7.3 may become 1.8 when it ships. The ASO fields in
   checklist item 1 ride whatever the number ends up being.

## Standing gates

No push, no ASC action without HAN. Sleep-v2 activation and estimator-v2
flip stay on their own validation clocks (not 1.7.3 items unless their
gates clear).
