# Stage 3 Brief — Per-Screen Craft (Ink & Grain everywhere)

Lane contract for the Stage 3 worker. Orchestrator verifies + commits. Prerequisites: Stages R/0/1/2 (`36747b8`, `bdbee4f`, `0a3c95b`, `842a8af`). Read DESIGN.md v3 + `.planning/orchestration/2026-07-14-v16-ui-polish.md` first. Reference render: `.planning/design-reference/tuwa-c3-vs-d1.html` middle column.

## Mission
Every LIVE screen reads as one designed object in the v3 language. The token layer did the wholesale shift; this lane does the residue + hierarchy + rhythm. Coach/AppShell surfaces are out of scope (unreachable/retired).

## Checklist (accumulated deferrals + audit findings, priority order)
1. **Square residue sweep**: screen-local hand-rolled plates/banners still square — PRBanner, Spike/Fatigue/REDS banners, sheet scaffolds on Auth/Profile/Import screens, TemplateEditorSheet, Export/PDF sheets, ShareImport surfaces. All fills/strokes → CornerTokens (card for plates, control for inputs, Capsule for chips). The corners fence is already live — anything you touch must go through tokens.
2. **Dashboard hero hierarchy** (orchestrator visual review found it stacked/busy): READINESS micro-label + serif score is the moment; the periodization-progress ring + "3 of 8 weeks" + RHR/HRV rows + zone line below it currently compete. Restructure inside the existing card: score block gets breathing room (Spacing.lg below score), demote periodization progress to a compact single row (ring 20-24pt inline with label, not centered 56pt), RHR/HRV rows stay but tighten, zone line stays the card's last line. NO new information, NO removed information — hierarchy only.
3. **Auth screens** (LoginView/SignUpView): full-bleed row fields → the standard field treatment (control-radius, hairline, focus feedback per Stage 2 pattern); CTAs → pill grammar (primary filled accent, secondary outlined); section rhythm on the 8pt grid.
4. **Section rhythm sweep** (Dashboard, Log, Recovery, Load, Profile): consistent header grammar (micro-caps label, Spacing.lg between sections, Spacing.sm label-to-content), generous top padding under the nav per the editorial reference. Where a screen hand-rolls different section spacing, normalize.
5. **Empty/error states**: EmptyStateCard and friends adopt v3 (card radius, instrument voice, one quiet line + optional secondary action as outlined pill). No illustrations, no color noise.
6. **Copy/craft nits**: "--" → "—" em-dash in periodization copy (check catalog: additive value edit only, do NOT add keys); stale "0pt corners" doc comments in touched files updated to cite CornerTokens; any leftover hardcoded spacing in touched screens onto the grid.
7. **Recent-sessions rows (Dashboard)**: bare text stacks → plate treatment (dataPlate rows or a single grouped plate with hairline separators), tappable rows get .pressable.

## Verify (you MUST)
Sim `8E872500-703D-4292-9758-38ADFCCFB126`, SCREENSHOT_MODE, screenshot EVERY screen you touched (before is in git; after = your render): Dashboard (top + scrolled), Log, Recovery, Load, Profile, Login, SignUp, one import sheet, one empty state. Look at each; iterate until it reads calm and aligned. Save to `.planning/orchestration/stage-3-screens/`, list paths in the report.

## Hard constraints
- NO git commands. NO `xcodebuild test` (build only; command in stage-1-brief.md). AppShell files untouched. xcstrings: additive/value-edit only, never regenerate.
- All fences must stay green: corners via tokens only, serif only via the 2 display tokens (do NOT serif anything new — including the dashboard rec.headline; the two-voice law names exactly two roles), halftone stays hero-only (do not add fields), animation literals only in CardStyle.swift.
- Layout changes must not alter behavior: same actions, same data, same navigation. If a hierarchy fix wants a behavior change, list it as a deferral instead.

## Deliverable
Report: per-checklist-item files touched + what changed; screenshot paths per screen; any fence friction and how you resolved it (never by weakening a fence without flagging); verbatim build tail; deferrals with reasons.
