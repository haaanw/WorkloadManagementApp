# Stage 2″ Brief — Per-Screen Apply (Instrument everywhere)

Lane contract for the v4 Stage 2 worker. Orchestrator verifies + commits. Prerequisites: Stage 0″ (`7a4eaec`) + Stage 1″ (committed — check `git log` note in orchestration doc). Read `.planning/orchestration/2026-07-20-v4-instrument.md` + DESIGN.md v4 + mockup column D + the Stage 1″ lane report's **accent inventory** (reproduce via `grep -rn "ColorTokens.accent" WorkloadApp`).

## Mission
Every live screen adopts the Instrument grammar. The shared layer (panel plane, TickScale, KeyRow, buttons, chrome) exists — this lane deploys it and retires every remaining v2/v3 accent-as-fill/wash usage per the Index Rule.

## Work items (priority order)
1. **Dashboard hero → panel**: HeroReadinessCard onto `panelStyle()` (THE one panel on Home): micro-caps label, `dialHero` score in `panelInk` (NOT red — Index Rule), zone as caps text label, full-width `TickScale(.scale, .panel)` 0–100 with zone band + needle at score; RHR/HRV rows as mono `dialSmall` values on a light card below (mockup D layout); periodization row stays compact/quiet; count-up + `dashboard.hero` ID + skeleton preserved. Hero "71" red → panelInk. "Start session" red capsule → shared ink PrimaryActionButton (auto after Stage 1″ — verify).
2. **Verdict card (Log)**: header per mockup — micro-caps "TODAY'S PLAN · <EXERCISE>", weight → `dialValue` mono, "from" caption mono small; reason line stays UI voice `body`; decision row → `KeyRow` (Start-adjusted = CTA ink cell ONLY when it's the single primary action — Accept/Keep stay EQUAL-weight plain cells per the nocebo guard + guard tests; read TodayVerdictCardGuardTests BEFORE editing); feel row → plain cells or quiet text buttons. Zone strip/labels unchanged semantics.
3. **Load tab**: ACWR hero → the screen's panel (`dialHero` ratio + TickScale with strike/zone band per ACWR zones); ATL/CTL/TSB MetricTiles → mono metric rows or keep tiles with `dialSmall` (judgment; mockup mrow pattern preferred); TimeRangeSegmentedControl → butted KeyRow-style segments (selected = ink fill, NOT red wash); chart accent colors unaffected (chart* tokens exempt from Index Rule).
4. **Recovery tab**: score card stays light card (Home owns the readiness panel; no second panel screen-wide — Panel Law) — score value → `dialValue`, factor values mono; red score text → `text1`.
5. **Accent-residue sweep (Index Rule)**: every `ColorTokens.accent`/`accentSubtle` usage from the Stage 1″ inventory → correct v4 treatment: selected/focus states → ink borders/fills (`text1`/`dividerStrong`), washes → `surfaceEl2`, focus borders (SharpTextFieldStyle/InstrumentTextField in CardStyle) → `text1` 1pt, WorkoutLogView filter rail red "All"+underline → ink underline needle-style, TemplateCarouselSection red band → hairline, rings (DataSufficiencyRing) → ink stroke, UpgradeSheet 2pt rule → delete, streak dot → ink. Red remains ONLY: TickScale needles, InkTabBar tick, live-recording indicators if any. `PDFReportEngine` accent → ink (report artifact, not UI accent).
6. **Sheets/auth/onboarding quick pass**: pills inherited the restyle via shared buttons — verify Login/SignUp/Onboarding/Upgrade render coherently in v4 (fields: control-corner + ink focus per item 5); fix layout residue only where it visibly clashes (list it; deep re-craft is NOT in scope).
7. **Copy/labels**: screen titles render uppercase already; do NOT change xcstrings values.

## Verify (you MUST)
Build; SCREENSHOT_MODE sim `8E872500-703D-4292-9758-38ADFCCFB126`; screenshot ALL 5 tabs (Home also scrolled), verdict card states, one sheet, login, to `.planning/orchestration/stage-v4-2-screens/`; LOOK and iterate — the bar: each screen reads like mockup column D. Grep-verify: zero `ColorTokens.accent` outside TickScale/InkTabBar/CardStyle-sanctioned sites; list every file where accent remains and why.

## Hard constraints
- NO git. NO `xcodebuild test` (build only). AppShell untouched. xcstrings untouched. pbxproj for any new file.
- Panel Law: ≤1 `panelStyle(` per screen file (fenced). Corners/mono/serif/shadow/spacing/motion fences stay green.
- Nocebo guard: TodayVerdictCardGuardTests semantics are law — equal-weight Accept/Keep, no red gates, no accent on verdict state or number.
- a11y IDs used by ScreenshotTests must survive: dashboard.hero, recovery.scoreCard, workload.acwr, workoutLog.verdict.reason/.strikeZone, workoutLog.startWorkout, activeWorkout.addExercise, profile.movementBank, tab.*, tabbar.ink, export.workoutData, templatePicker.startBlank, app.loading.view. Container-ID lesson: never add a container ID above a leaf ID.
- Parallel-session rule: steer around foreign uncommitted changes; report.

## Deliverable
Report: per-item files touched; accent-residue grep result; screenshot paths; any guard-test friction and how resolved (never by weakening); verbatim build tail; deferrals.
