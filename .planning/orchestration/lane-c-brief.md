IMPORTANT: Do NOT read or execute any files under ~/.claude/, ~/.agents/, .claude/skills/, or agents/. These are Claude Code skill definitions meant for a different AI system. Do NOT modify agents/openai.yaml. Stay focused on repository code only.

You are implementing Lane C of a planned round in the Tuwa iOS app (SwiftUI + SwiftData, iOS 17+). Work directly in this checkout. Do NOT create branches or worktrees. Do NOT commit — leave all changes in the working tree; the orchestrator verifies and commits.

READ FIRST: CLAUDE.md and DESIGN.md at repo root — DESIGN.md is the constitution for this lane. Rules: 0pt corner radius (Rectangle only), no shadows, fonts only via Font.Tokens (General Sans), colors only via ColorTokens (incl. surfaceEl2 elevation plane), spacing multiples of 8pt, accent color per DESIGN.md v2 semantics (hero readiness number, active/selected state, primary CTA outline), motion ONLY via the Motion tokens in Components/CardStyle.swift (springs for state/entrance, easeOut for screen, easeIn for exit). User-facing strings via Localizable.xcstrings keys — BOTH en and zh-Hans, additive only, never regenerate the catalog.

GOAL — App-wide UI elevation on NON-LOGGING screens. Make the app feel more polished, alive, and premium WITHOUT changing layout structure, information architecture, or any business logic. This is craft: motion, transitions, empty states, micro-interactions, visual rhythm.

TASKS (in priority order):
1. HERO SCORE COUNT-UP: Components/CardStyle.swift defines Motion.scoreCountUp (easeOut 0.40) but the hero readiness score does not animate. Implement a count-up on the Dashboard hero readiness number using .contentTransition(.numericText()) driven by Motion.scoreCountUp when the score first loads or changes. Must respect Reduce Motion (UIAccessibility.isReduceMotionEnabled → no animation, instant value).
2. ENTRANCE CHOREOGRAPHY: Dashboard sections (hero card, metrics strip, training load, recent sessions) should enter with the existing Motion.entrance spring, lightly staggered (~0.05s steps), on first appear only — no re-animation on every tab switch. Same pattern for Recovery and Workload screens' top-level sections.
3. STATE TRANSITIONS: where views swap on state change (loading → content → empty/error) in Dashboard/, Recovery/, Workload/, Profile/, use Motion.state spring with .transition(.opacity) or .blurReplace-style opacity+scale (subtle; no slides from screen edges). Kill any abrupt pops you find.
4. EMPTY STATES: audit EmptyStateCard usages on these screens; ensure consistent vertical rhythm (8pt grid), an SF Symbol at a consistent size, one clear next-step CTA where an action exists. Do not invent new empty states where none exist.
5. PRESSABLE FEEDBACK: verify PressableButtonStyle + Haptics coverage on tappable cards/rows across these screens; add where missing (cards that navigate, metric tiles that open detail). No haptics on passive/display-only elements.
6. CHART POLISH (if quick wins exist): HRVTrendChart / SleepTrendChart / Workload charts — animate data-in with Motion.entrance once per appear; no gratuitous continuous animation.

HARD CONSTRAINTS:
- Structure freeze: do not add/remove/reorder sections, change navigation, or alter copy meaning. Pure elevation.
- Reduce Motion: every new animation must be suppressed when Reduce Motion is on. If a helper for this doesn't exist, add ONE small helper in CardStyle.swift next to the Motion tokens.
- Motion tokens only — if you feel you need a new duration/curve, add it as a named token in CardStyle.swift with a comment, don't inline magic numbers.
- Performance: no animation work in tight loops; nothing that re-renders whole screens per frame.

FILES OWNED: everything under WorkloadApp/Views/Dashboard/, Views/Recovery/, Views/Workload/, Views/Profile/, Components/ (CardStyle.swift Motion additions, MetricTile, ZoneBadge, HRVTrendChart, SleepTrendChart, EmptyStateCard etc.), Localizable.xcstrings (additive), pbxproj only if you add a new file (mimic sibling entries exactly).
DO NOT TOUCH: anything under Views/WorkoutLog/ (Lane D owns logging polish), Views/Onboarding, Views/Auth, Views/Coach; SessionStartPicker.swift; Services/; Models/; Repositories/; ViewModels/ logic (you may add tiny presentation-only computed properties if unavoidable — flag them in the report).

PROJECT MECHANICS:
- Build gate (run before finishing): xcodebuild -project "workload management/workload management.xcodeproj" -scheme "workload management" -destination "id=8E872500-703D-4292-9758-38ADFCCFB126" -derivedDataPath "$HOME/.tonus-dd" build
  If the sandbox blocks xcodebuild, say so explicitly in your final report and finish — the orchestrator will build externally. Do not fake a build result.

FINAL REPORT (print at the end): per-screen list of what you elevated and why it complies with DESIGN.md motion grammar; any new Motion tokens added; Reduce Motion handling approach; files changed; new localization keys (if any); build gate result (or sandbox-blocked note); anything you deliberately did NOT do and why.
