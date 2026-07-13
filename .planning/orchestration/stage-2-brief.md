# Stage 2 Brief — Motion Pass (calm, unified, tactile)

Lane contract for the Stage 2 worker. Orchestrator verifies + commits. Prerequisites: Stage R (`36747b8`), Stage 0 (`bdbee4f`), Stage 1 (`0a3c95b`). Read `.planning/orchestration/2026-07-14-v16-ui-polish.md` + DESIGN.md v3 Motion section first.

## Direction (user-set)
User's complaints: (a) too little/lifeless, (b) janky/inconsistent timing, (c) missing micro-interactions. Taste reference (contralabs.com) reads calm/premium — "life" comes from REFINED, CONSISTENT, PURPOSEFUL motion + tactile feedback, NOT big bouncy springs. When in doubt: quieter, but never snapping.

## Substrate (already exists — extend, don't rebuild)
`Components/CardStyle.swift`: `Motion` tokens (state 0.30/0.86 spring, entrance 0.42/0.82, screen 0.28 easeOut, scoreCountUp 0.40 easeOut), `Motion.resolved(_:reduceMotion:)` gate, `EntranceReveal` stagger modifier, `PressableButtonStyle`, `Haptics`.

## Work items
1. **Timing-grammar sweep**: find every `withAnimation`/`.animation(` in Views/ + Components/ that uses an ad-hoc curve/duration instead of a `Motion` token; migrate to tokens. Add a fence test: no animation literals outside CardStyle.swift (mirror the CornerTokens fence pattern).
2. **Hero count-up**: verify the readiness-score count-up actually runs on Dashboard load post-rehost (Motion.scoreCountUp). If dormant/broken, wire it; pair with `.monospacedDigit()` (already set) so digits don't jitter. The serif score counting up is THE signature moment.
3. **State-change coverage** (the "snapping" hunt): tab switches in MainTabView content, segmented-control section swaps (TimeRangeSegmentedControl, Insights-equivalent SwiftUI views), sheet presentations, verdict card state changes (suggested → accepted), set-row isDone toggles, expand/collapse disclosures — every state change animates with Motion.state or Motion.screen. No hard snaps.
4. **Micro-interaction fill**: text-field focus (subtle border+background shift via Motion.state on @FocusState change — SharpTextFieldStyle/InstrumentTextField), toggle/stepper value changes (Haptics.select on detent-style changes where missing), save/success moments (Haptics.success + a confirming transition), pull-to-refresh if present.
5. **Entrance choreography**: EntranceReveal on Dashboard/Log/Recovery/Load top-level sections (first render only, staggered, capped — reuse the stagger-cap fix from 045a944). Verify no re-trigger on tab revisits.
6. **Reduce Motion**: every animation path must flow through `Motion.resolved(...)` or equivalent gating. Audit for bypasses (the 07-10 Lane D report flagged Onboarding/AppRouter bypasses — those files are now live; fix them).
7. **Skeleton/loading**: where a tab shows blank while loading (DashboardViewModel.load, insights equivalents), add a lightweight placeholder (plate-shaped, no shimmer needed — calm) so data arrival is a transition, not a pop.

## Verify (you MUST)
Build, install on sim `8E872500-703D-4292-9758-38ADFCCFB126` with SCREENSHOT_MODE, exercise the flows via `axe` HID (tab switches, field focus, section swaps), and record a short video of the Dashboard load + a tab walk via `xcrun simctl io ... recordVideo` (stop with SIGINT). Report the video path. Screenshots alone cannot show motion — the orchestrator will watch the video.

## Hard constraints
- NO git commands. NO `xcodebuild test` (build only; command in stage-1 brief). AppShell files untouched. xcstrings additive only. Radius/serif/halftone fences must stay green (don't fight them).
- No new bounce personalities: springs only via existing Motion tokens; new tokens only if genuinely needed, defined in CardStyle.swift with law comment.

## Deliverable
Report: files touched + why; every animation-literal migration (file → token); snap-points found & fixed; reduce-motion bypasses fixed; video + screenshot paths; verbatim build tail; deferrals with reasons.
