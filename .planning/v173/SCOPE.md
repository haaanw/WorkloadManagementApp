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
- Candidate app features: HAN names them at kickoff.

## Standing gates

No push, no ASC action without HAN. Sleep-v2 activation and estimator-v2
flip stay on their own validation clocks (not 1.7.3 items unless their
gates clear).
