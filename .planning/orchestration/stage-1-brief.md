# Stage 1 Brief — Token/Primitive Adoption (Ink & Grain goes visible)

Lane contract for the Stage 1 worker. Orchestrator verifies + commits. Prerequisites landed: Stage R (`36747b8`, SwiftUI tree is the live app) and Stage 0 (`bdbee4f`, DESIGN.md v3 + CornerTokens + HalftoneField + Font.Tokens.displayScore/displayVerdict + fences). Read `.planning/orchestration/2026-07-14-v16-ui-polish.md` (D2) and DESIGN.md v3 first. Reference render: `.planning/design-reference/tuwa-c3-vs-d1.html` middle column ("Ink & Grain").

## Mission
Make the SHARED LAYER adopt the v3 law so the whole app shifts at once. Screen-specific craft is Stage 3 — here you touch primitives, styles, and the hero surface only.

## Work items
1. **Corners via CornerTokens** (never literals — the fence checks):
   - `Components/CardStyle.swift`: dataPlate / emphasis / hero card shapes → `CornerTokens.card` (12). Keep hairlines + 2pt accent top rule on emphasis surfaces; radius + top-rule can coexist (clip shape, rule inside).
   - Primary CTA button style → `Capsule()` fill per accent rule v3 (verdict/primary CTA = filled accent pill, white/`surfaceEl2` label). Secondary buttons → outlined pill (hairline or accent outline per current semantics).
   - Input fields (`SharpTextFieldStyle` and friends) + segmented/steppers → `CornerTokens.control` (8).
2. **Hero goes serif**: the readiness score display (DashboardView hero + any shared hero component) → `Font.Tokens.displayScore` (accent color, tabular numerals); verdict headline (TodayVerdictCard) → `Font.Tokens.displayVerdict` (`text1`). Do NOT serif anything else — the fence + law forbid it.
3. **Halftone on the hero plane**: add `HalftoneField()` (default params, ≈130×130, top-trailing, behind content) to the hero readiness card ONLY. One per screen max — fence enforces.
4. **Press-feedback unification**: `PressableButtonStyle` (exists in Components) becomes the default for every tappable surface in the shared layer — audit Components/ button/row styles and apply. Screens inherit automatically where they use shared styles; do not chase individual screens.
5. **Spacing normalization (flagged by Stage 0)**: fix the off-grid directional paddings in `Components/MetricTile.swift` ZoneBadge (5/10 → 4/8 or 8/8 judgment call per DESIGN.md), then extend `DesignSystemFenceTests.test_structuralSpacingLiterals_areOnTheGrid` to cover directional `.padding(.edge, N)` forms.
6. **Type-scale tuning**: with real render, adjust `FontTokens.Display` constants if needed (score 76–88, verdict 24–26) — pick what looks right on iPhone 17 Pro Max sim at the hero card's actual width; note your choice.

## Verify visually (you MUST do this)
Boot sim `8E872500-703D-4292-9758-38ADFCCFB126`, launch with `SCREENSHOT_MODE` launch argument (bypasses auth, seeds data — see AppRouter DEBUG block), screenshot the Dashboard (hero card visible) via `xcrun simctl io ... screenshot`, and LOOK at it: serif score, pill CTA, 12pt cards, halftone visible. Attach the screenshot path in your report.

## Hard constraints
- NO git commands. Orchestrator commits.
- Do NOT run `xcodebuild test` — build only (orchestrator runs the suite):
  xcodebuild -project "workload management/workload management.xcodeproj" -scheme "workload management" -destination "id=8E872500-703D-4292-9758-38ADFCCFB126" -derivedDataPath ~/.tonus-dd build
- AppShell.swift / AppShellUIKitPrimitives.swift: untouched (must keep compiling).
- Localizable.xcstrings additive only. New files (unlikely) registered in pbxproj.
- Radius literals are fenced — only CornerTokens (or Capsule()).
- Serif only via Font.Tokens.displayScore/.displayVerdict.

## Deliverable
Report: files touched + why; Display constants chosen; screenshot path(s); any fence you had to extend and how; verbatim build tail; anything deferred to Stage 2/3 with reason.
