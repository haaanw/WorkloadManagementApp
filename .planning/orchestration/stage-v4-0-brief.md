# Stage 0″ Brief — DESIGN.md v4 "Instrument" + tokens + fonts + fences

Lane contract for the v4 Stage 0 worker. Orchestrator verifies + commits. Read `.planning/orchestration/2026-07-20-v4-instrument.md` FIRST (the v4 law section is canonical — do not re-derive values), then the picked mockup `.planning/design-reference/tuwa-instrument-round2.html` (column D + shared CSS = ground truth for tone), then current DESIGN.md.

## Mission
Replace the Ink & Grain law with the Instrument law at the token + law + fence layer ONLY. Screens will still compile and run mid-pivot (they reference tokens; retuned values flow through). Do NOT restyle screens — that is Stage 1″/2″.

## Work items
1. **DESIGN.md v4** — full rewrite: Instrument law (palette incl. Panel Law, two-voice type = General Sans UI + IBM Plex Mono dial, index-accent rule, near-square geometry + butted keys, TickScale grammar, Emil motion law with the exact curves/durations from the orchestration doc, retained laws: light-only, no shadows, 8pt grid, text-label-first zones, nocebo guard). Version header "v4 Instrument — Aluminum Panel, 2026-07-20". Record what v3 concepts are RETIRED (serif display, halftone, accent-as-fill CTA, 12pt cards, pill CTAs).
2. **ColorTokens.swift** — repalette to the v4 law values (keep every existing token NAME that screens reference; retune values; ADD panel tokens: `panel`, `panelInk`, `panelInk2`, `panelHairline`, `index`; retune zone triad to instrument variants with WCAG ≥4.5:1 on their surfaces; document each). `accent` token: re-point to the index red BUT audit v2 live-state usages still compiling — do not restyle call sites.
3. **FontTokens.swift** — add dial chokepoint: `dialHero` (~56–64pt), `dialValue` (~28–32pt), `dialSmall` (13pt), `dialTick` (8.5–10pt) via IBM Plex Mono statics with `.monospacedDigit` semantics; Medium for values, SemiBold only if needed for hero. DELETE `serifDisplay` + `displayScore`/`displayVerdict` + the Source Serif requiredPostScriptNames entry; add the Plex Mono PS names. Keep `requiredPostScriptNames` chokepoint-owned. Update the WorkloadApp.swift launch assert expectations accordingly (names only — the assert mechanism stays). CJK cascade: dial tokens are numerals/units only (app-authored), but keep the Noto cascade defensive.
4. **Fonts** — download IBM Plex Mono STATIC Regular/Medium/SemiBold TTFs (OFL; from github.com/IBM/plex releases or google/fonts repo), bundle + register (pbxproj + UIAppFonts in `workload management/workload-management-Info.plist`), include the OFL license file. REMOVE SourceSerif4-Variable.ttf + its license + UIAppFonts entry + pbxproj refs. **Verify PS names at RUNTIME via the DEBUG family print (phase-14 lesson: never trust assumed PS names)** — plain-launch the app once (no SCREENSHOT_MODE would trap on assert if wrong; use SCREENSHOT_MODE launch + read console family dump, then set the assert list to the printed names).
5. **CornerTokens.swift** — card 12→5, control 8→4; pill stays defined but is DEMOTED (chips only; law text in DESIGN.md). Add `panel: CGFloat = 5`.
6. **Fences (`WorkloadAppTests/DesignSystemFenceTests.swift`)** — serif-name fence → IBM Plex Mono name fence (only FontTokens.swift may name it); DELETE the halftone fence AND `Components/HalftoneField.swift` (+ pbxproj) AND its call site in CardStyle's emphasis style (replace `halftoneSignature` param with a no-op removal — Stage 1″ rebuilds the hero as panel; for now the hero card just loses the texture); corner fence unchanged mechanically (values come from tokens); keep animation/shadow/spacing/system-font fences. Add "SourceSerif4" as a BANNED string app-wide now (fence inversion — it must not reappear).
7. **Temporary compile shims** — where deleting displayScore/displayVerdict breaks call sites (DashboardView hero, TodayVerdictCard reason), re-point those two call sites minimally: hero score → `Font.Tokens.dialHero`, verdict reason → `Font.Tokens.body` (Stage 2″ does the real redesign). No other screen edits.

## Verify (you MUST)
Build green; SCREENSHOT_MODE launch; console shows all required PS names resolving (General Sans + Plex Mono ×3 + Noto ×2); screenshot Dashboard + Log to `.planning/orchestration/stage-v4-0-screens/` (they will look mid-pivot — palette shifted, mono hero — that's expected; confirm nothing crashes and text renders in real fonts, NOT system fallback).

## Hard constraints
- NO git. NO `xcodebuild test` (build only). AppShell untouched. xcstrings untouched. Path list of every file you touch in the report.
- Do not delete/rename any ColorTokens/FontTokens/CornerTokens PUBLIC name that has call sites — except the two display tokens handled via item 7. Grep before deleting anything.
- A parallel session may exist: if you see uncommitted changes you didn't make, steer around and report.

## Deliverable
Report: per-item files touched; the runtime-verified PS names; palette table as implemented; every call-site shim; fence changes; verbatim build tail; screenshots; deferrals.
