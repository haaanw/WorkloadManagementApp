# Stage 4a Brief — Character Pass (de-defaultification)

Lane contract for the Stage 4a worker. Orchestrator verifies + commits. Prerequisites: Stages R/0/1/2/3/3.5 (`36747b8`…`d430198`). Read DESIGN.md v3 + `.planning/orchestration/2026-07-14-v16-ui-polish.md` (D6/D7 + Stage 4a spec) first.

## Mission
The user's verdict on the current app: "still feels like just a default app… a lot of Apple native components instead of having its own character." Kill the stock chrome. The app should read as a designed instrument in the Ink & Grain language from the first frame — while changing NO behavior.

## ⚠️ Concurrency (D7 — read carefully)
A SECOND Claude Code session may be editing this same checkout (movement bank + exercise-selection redesign). Therefore:
- DO NOT touch: `ExercisePickerView.swift`, `ActiveWorkoutSheet.swift`, `TemplateEditorSheet.swift` (both), `SessionStartPicker.swift`, CustomExercise / exercise dataset models, or any file you observe with uncommitted changes you didn't make. If you see foreign uncommitted edits, note the paths in your report and steer around them.
- `Localizable.xcstrings`: before editing, check `git status` — WAIT, you may NOT run git. Instead: keep catalog edits to the few named value-only edits below, make them in ONE Edit pass, and list them in the report so the orchestrator can verify no collision.
- NO git commands. NO `xcodebuild test` (build only — command in stage-1-brief.md). AppShell files untouched.

## Work items (priority order)

1. **Custom tab bar** (`App/AppRouter.swift` MainTabView + a new `Components/InkTabBar.swift` registered in pbxproj):
   - Hide the system tab bar entirely (`.toolbar(.hidden, for: .tabBar)` per tab or UITabBar appearance) and render our own bar: flat OPAQUE `ColorTokens.background` plane, 0.5pt `divider` top hairline. NO material/blur, NO floating pill, NO shadow, NO corner radius (it's an edge-to-edge plane, not a card).
   - Items, text-forward editorial: micro-caps label (`Font.Tokens.micro`, tracking as used for micro-caps elsewhere). Selected = `text1` + a 2pt accent tick (short rule) ABOVE the label — the live-state accent semantic. Unselected = `text3`. NO glyphs in the primary direction (this is the character move); if at device scale a pure-text bar reads unbalanced, a fallback variant may add a compact thin glyph above the label — screenshot BOTH and say which you recommend.
   - Full-height tap targets (≥44pt), `Haptics.select` on switch (matches existing tab-switch behavior if present — do not double-fire), keep the existing `tabCrossfade`/selection logic and scenePhase sync EXACTLY as is.
   - Stable `accessibilityIdentifier`s: `tab.home`, `tab.log`, `tab.recovery`, `tab.load`, `tab.profile` + proper accessibilityLabels (Stage 4b test rewrite depends on these).
   - Content clearance: every tab root must clear the bar (safeAreaInset or padding) — this FIXES the current clipping (teal CTA band under bar on Home; "CONNECTED DEVICES" on Profile). Verify in screenshots.
2. **Editorial headers, not stock nav chrome** (Dashboard/Recovery/Load/Profile roots; Log already reads editorial — match its pattern): remove system `navigationTitle` styling as the visible title (keep NavigationStack for push behavior). In-content header: `Font.Tokens.screenTitle` (`text1`) on the content's top, generous top padding on the 8pt grid. Keep existing toolbar action buttons working (Log Workout, share, etc.) — restyle placement if the nav bar is hidden (e.g. trailing button row aligned with the header). Detail/pushed screens keep working back navigation.
3. **PRSDualRunCard restraint** (`Views/Dashboard/PRSDualRunCard.swift`): DO NOT remove — it's a flag-gated algorithm surface (default OFF). Restyle to v3 restraint: one quiet line ("Guidance method updated") + expandable disclosure for the previous/updated comparison; instrument voice, standard plate, no accent. Flag gate + all data untouched.
4. **Load tab peak** (`Views/Workload/WorkloadView.swift`): ACWR block onto the emphasis plane (`emphasisCardStyle`, accent top rule) with display-scale instrument numerals (`Font.Tokens.displayMetric` or per hierarchy) — the app's core number gets the screen's one peak. NO serif (two-voice law names exactly two serif roles), NO accent ink on the number. "LOAD STEADY" chip stays text-first.
5. **Recovery copy tightening** (`Views/Recovery/RecoveryView.swift` + xcstrings value-only): the score card's explainer sentences → one calm line each. Value-only edits on EXISTING keys, no new keys, list every key touched.
6. **CTA grammar completion** (Stage 3 deferral): Onboarding + UpgradeSheet primary CTAs onto the shared accent-pill (`PrimaryActionButton` or equivalent style); secondary stays outlined pill. No layout rework beyond the buttons.

## Verify (you MUST)
Build; sim `8E872500-703D-4292-9758-38ADFCCFB126`, SCREENSHOT_MODE; screenshot: all 5 tabs (top), Dashboard scrolled-to-bottom (clearance proof), Profile scrolled (clearance proof), plus tab bar close-crop if useful. LOOK at each; iterate until the bar and headers read designed, not default. Save to `.planning/orchestration/stage-4a-screens/`, list paths.

## Hard constraints
- All fences stay green: corners via CornerTokens/Capsule only (the tab bar plane has NO radius), serif untouched, halftone hero-only, animation literals only in CardStyle.swift (use Motion tokens for the tick/selection transition), no shadows, spacing on the 8pt grid.
- No behavior changes: same tabs, same actions, same navigation, same flag gates. If a change wants behavior, defer + note.
- New files registered in project.pbxproj.

## Deliverable
Report: per-item files touched + what changed; tab-bar direction chosen (text-only vs glyph fallback) with screenshots of both if made; xcstrings keys touched (value-only); foreign-edit paths observed (if any); fence friction; verbatim build tail; deferrals with reasons.
