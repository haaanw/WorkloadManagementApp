# Orchestration Plan — Design Language v4 "Instrument" (treatment: Aluminum Panel)

Date opened: 2026-07-20. Orchestrator: Claude (session). Serial agent lanes in canonical checkout (NO worktrees/branches). Supersedes the visual layer of v1.6 "Ink & Grain"; the v1.6 structural work (rehost, InkTabBar architecture, ScreenHeader, movement bank, test suite) is retained.

## User decisions
- **D9 (2026-07-20): v1.6 on-device dogfood FAILED on aesthetics** — "not satisfied with the UI… feels like a default app" even after Ink & Grain. v1.6 ship items (version bump, shell deletion, push) PAUSED pending this redesign.
- **D10: New references = Braun · Bang & Olufsen · 1990s Contax** + Emil Kowalski's design-engineering skills (github.com/emilkowalski/skills) for the motion layer.
- **D11: Treatment picked via 2 mockup rounds** (`.planning/design-reference/tuwa-instrument-treatments.html`, `tuwa-instrument-round2.html`): **D "Aluminum Panel"** — B&O aluminum body × black instrument hero panels. Round-1 answer also ratified the **full instrument pivot**: Source Serif display RETIRED, HalftoneField RETIRED, cool paper-blue palette REPLACED. Numerals become the voice (IBM Plex Mono dial digits); General Sans stays as the UI voice.

## The v4 law (from the picked mockup — canonical values)
- **Palette (light-only unchanged):** base `#E9EAEB` (aluminum; flat token — optional subtle vertical gradient ONLY on the scroll background), card `#F5F6F7`, hairline `#D0D2D5` / strong `#C6C9CC`, ink `#17181A`, text2 `#4A4D51`, text3 `#85898E`, disabled `#9A9EA3`. **Panel plane (the signature):** near-black `#1A1C1E→#232527` vertical gradient, panel ink `#F0F1F2`, panel secondary `#8B8F94`, panel hairline `#35373A`. **Index accent `#D04234`** (red needle/dot) — INDEX MARKS ONLY: scale needles, active-tab tick, live-recording dot. Never a fill, never text, never decorative. Zone semantics keep text-label-first law; zone hues re-tuned to instrument variants (desaturated green/amber/red) in Stage 0.
- **Panel Law:** the black panel is for the ONE hero instrument reading per screen (Home readiness, Log verdict header if hero'd, Load ACWR). Max one panel per screen. Everything else lives on aluminum cards.
- **Type:** General Sans = UI voice (unchanged files). **IBM Plex Mono (static Regular/Medium/SemiBold, OFL) = dial voice** — ALL data numerals (scores, weights, metrics, tick labels) via new `Font.Tokens.dial*` chokepoint. Screen titles = micro-caps wide tracking (0.28–0.3em) 12.5–13px semibold, NOT large title. Micro-labels 9.5–10px tracking 0.2em+. Serif chokepoint (`serifDisplay`, displayScore/displayVerdict) DELETED with the font files.
- **Geometry:** corners near-square — card 5pt, panel 5pt, control 4pt; keys are BUTTED rows (flex cells separated by 0.5pt hairlines inside one bordered container — no gaps, no pills). CTA key = ink-filled cell (`#17181A`, panel-ink text) — NOT red. Tab bar: text-only micro-caps, active = ink + 1.5pt red tick line ABOVE (needle grammar), on flat opaque bar (InkTabBar architecture retained, restyled).
- **Scales (the signature component):** `TickScale` — two-weight tick marks (minor 1px / major 1.5px), mono tick numerals, optional zone band (ink on light / panel-ink on panel), 1.5px red needle, optional faint ghost mark (planned value). Replaces StrikeZoneBar's visual; same data semantics + a11y.
- **Motion (Emil Kowalski framework — govern Stage 3'):** crisp + mechanical. Strong ease-out `cubic-bezier(0.23,1,0.32,1)`; press 100–160ms scale 0.97; UI transitions 150–250ms, NEVER >300ms; no ease-in ever; stagger 30–80ms; springs only for gesture/momentum (damping ~1.0); count-up stays but faster (≤400ms); detent haptics on scale/needle landings. Frequent actions (tab switches) get near-instant treatment.
- **No shadows / light-only / 8pt grid / nocebo guard (equal-weight decision keys) — all retained.**

## Stage sequence (mirror v1.6 pipeline; briefs per stage)
- **Stage 0″ — DESIGN.md v4 + tokens + fonts + fences** (brief: `stage-v4-0-brief.md`): rewrite DESIGN.md; ColorTokens repalette; FontTokens mono chokepoint + serif deletion; CornerTokens retune; bundle IBM Plex Mono statics (verify PS names at runtime — phase-14 lesson); flip fence tests (serif fence → PlexMono chokepoint fence; halftone fence → deleted with HalftoneField; corner values).
- **Stage 1″ — shared layer**: CardStyle primitives → aluminum/panel planes, TickScale component, butted KeyRow, InkTabBar + ScreenHeader restyle.
- **Stage 2″ — per-screen apply** (5 tabs + sheets + auth + onboarding).
- **Stage 3″ — motion pass** (Emil framework; use his improve/review-animations checklists).
- **Stage 4″ — gate**: fences + full suite (782) + ScreenshotTests still green + orchestrator visual review + report to user → THEN user re-dogfoods → v1.6/v2.0-numbering decision, version bump, shell deletion, push.

## Ground rules (carried from v1.6)
Build gate command, xcresulttool verification, sim `8E872500-703D-4292-9758-38ADFCCFB126`, DerivedData `~/.tonus-dd`, lane workers never run `xcodebuild test`/git, pbxproj registration for new files, xcstrings additive-only, path-scoped commits, SwiftUI a11y-ID container-clobber lesson, parallel-session awareness (movement-bank session may still exist).

## Status log
- [x] References distilled; Emil skills reviewed (design-eng + apple-design; improve/review-animations reserved for Stage 3″)
- [x] Round 1 mockups (T1 Braun / T2 B&O / T3 Contax) → user: iterate T2+T3+blends; full pivot ratified
- [x] Round 2 mockups (A/B/C/D) → **user picked D "Aluminum Panel"**
- [x] Stage 0″ dispatched + verified + committed (2026-07-20): DESIGN.md v4, repalette (panel/index tokens, WCAG-checked zones), dial chokepoint (Plex Mono statics, PS names runtime-verified), serif+halftone deleted, corners 5/4, fences flipped. Lane's own mono fence caught a PS-name literal in WorkloadApp.swift's assert message — reworded (chokepoint stays the only namer). Gates: full 782 run → 1 fence fail → fix → unit 767/0/2 green (UI tests green in the full run).
- [ ] Stage 1″ dispatched (shared layer — brief: `stage-v4-1-brief.md`)
