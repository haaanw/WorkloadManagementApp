# Stage 1″ Brief — Shared Layer (panel plane, TickScale, keys, chrome)

Lane contract for the v4 Stage 1 worker. Orchestrator verifies + commits. Prerequisite: Stage 0″ (DESIGN.md v4 + tokens + Plex Mono + fences) committed. Read `.planning/orchestration/2026-07-20-v4-instrument.md` (v4 law) + DESIGN.md v4 + mockup `tuwa-instrument-round2.html` column D FIRST.

## Mission
Build the Instrument grammar's shared components and retune the shared chrome so Stage 2″ can sweep screens. Screen-specific redesign stays OUT (only the shared layer + the call-site parameters it forces).

## Work items
1. **Panel plane** — `panelStyle()` modifier (CardStyle.swift): vertical gradient `#232527→#1A1C1E` (use ColorTokens.panel family; the gradient endpoints become private tokens there), `CornerTokens.panel` corners, `panelHairline` 0.5pt border, no shadow. Content color defaults: provide `.foregroundStyle(ColorTokens.panelInk)` environment so children inherit. **Panel Law fence**: new DesignSystemFenceTests test — at most ONE `panelStyle(` occurrence per file under Views/ (mirror the retired halftone fence pattern).
2. **TickScale** — new `Components/TickScale.swift` (+ pbxproj): reusable scale per DESIGN.md v4 spec — minor ticks 1px / major 1.5px two-weight pattern, optional zone band, 1.5px `index` needle at value, optional ghost mark, optional mono tick numerals (`dialTick`). Variants for light surface + panel via a `TickScaleTheme` (colors from ColorTokens only). Value/range API in generic Double units. Accessibility: decorative elements hidden; one combined element with a label the caller supplies (mirror StrikeZoneBar's approach).
3. **StrikeZoneBar rebuild** — `TodayVerdictCard.swift`'s private StrikeZoneBar keeps its public shape (planned/adjusted/hasAdjustment) + guard-test semantics + `workoutLog.verdict.strikeZone` ID, but renders via TickScale (zone band + needle + ghost planned mark). Do NOT touch the rest of the verdict card (Stage 2″).
4. **Key grammar** — in CardStyle.swift: (a) NEW `KeyRow`/`key cell` component: butted cells inside one 0.5pt-hairline container (`CornerTokens.control` outer corners, cells separated by hairline dividers, no gaps), cell = micro-caps tracked label, `.pressable`, CTA cell variant = ink fill (`text1` bg, `panelInk` label); (b) restyle `PrimaryActionButton` → ink-filled rectangle (control corners, micro-caps tracked label — NO pill, NO accent fill); (c) `SecondaryActionButton` → hairline-bordered rectangle. Call sites inherit automatically.
5. **Emphasis plane retune** — `EmphasisCardStyle`: DELETE the 2pt accent top rule (a red decorative rule violates the Index Rule; grep + remove the `accentRule` param and update call sites' arguments only). Emphasis = `surfaceEl2` + `dividerStrong` alone. Panels are the new hero plane; emphasis is now just "slightly raised".
6. **InkTabBar retune** — bar bg → a hair darker than background (`#E7E8EA`-family token if needed, else `background`), unselected `disabled`/`text3` per mockup, active tick → 1.5pt tall red line spanning ~44% width above the label (mockup D), tracking 0.2em, 9px labels. Architecture (stock-bar-underneath, IDs, crossfade) UNCHANGED.
7. **ScreenHeader retune** — title renders UPPERCASE micro-caps: 13pt Medium, tracking 0.28em, `text1`; trailing action slot 10pt Medium tracking 0.18em `text2`. Same API/IDs; screens' localized titles pass through `.textCase(.uppercase)` (rendering-level; do NOT edit xcstrings).
8. **ZoneBadge/MetricTile retune** — chip → hairline-bordered text-first chip (control corners, micro-caps, zone color as TEXT+border only, never fill). Keep 4pt/8pt paddings on-grid.

## Verify (you MUST)
Build green; SCREENSHOT_MODE on sim `8E872500-703D-4292-9758-38ADFCCFB126`; screenshot Dashboard + Log + Load to `.planning/orchestration/stage-v4-1-screens/`. Expected state: keys/buttons/chrome/tab bar/tick scales in v4 grammar; heroes still on light cards (screens move to panels in Stage 2″). LOOK at each; iterate until the shared pieces read like the mockup.

## Hard constraints
- NO git. NO `xcodebuild test` (build only). AppShell untouched. xcstrings untouched. New files in pbxproj.
- Fences stay green by construction: corners via CornerTokens only, mono names only in FontTokens, no SourceSerif4 string, animation literals only in CardStyle.swift (reuse Motion tokens for any transition you add), spacing on-grid.
- accent/index: appears ONLY in TickScale needle + InkTabBar tick within your scope. If you find other accent usages, list them for Stage 2″ — do not fix.
- Parallel-session rule: steer around foreign uncommitted changes; report.

## Deliverable
Report: per-item files touched; TickScale API summary; every EmphasisCardStyle call-site touched; accent-usage inventory left for Stage 2″; screenshots; verbatim build tail; deferrals.
