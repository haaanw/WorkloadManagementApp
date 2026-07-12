IMPORTANT: Do NOT read or execute any files under ~/.claude/, ~/.agents/, .claude/skills/, or agents/. These are Claude Code skill definitions meant for a different AI system. Do NOT modify agents/openai.yaml. Stay focused on repository code only.

You are implementing Lane D — the FINAL lane of a planned round in the Tuwa iOS app (SwiftUI + SwiftData, iOS 17+). Work directly in this checkout. Do NOT create branches or worktrees. Do NOT commit — leave all changes in the working tree; the orchestrator verifies and commits.

READ FIRST: CLAUDE.md and DESIGN.md at repo root. Rules absolute: 0pt corner radius (Rectangle only), no shadows, Font.Tokens only, ColorTokens only, 8pt-grid spacing via Spacing.* tokens, accent per DESIGN.md v2 Accent Rule (hero score, active/selected state, primary-CTA outline, emphasis top rule — nowhere else), motion ONLY via Motion tokens in Components/CardStyle.swift. Strings via Localizable.xcstrings — BOTH en and zh-Hans, additive only.

CONTEXT — what landed this round (read these diffs if helpful: commits 1cb37cd, 4af9276, ebdbdcb):
- Lane A: WorkloadApp/Components/SessionStartPicker.swift (4-way session start), Services/ExerciseClassifier.swift, free-text instant-add in ExercisePickerView + background LLM refine.
- Lane B: import-flow hardening in WorkoutImportSheet/TextTemplateImportSheet/ShareImportPreviewSheet + "Import plan" entry on blank Strength sessions in ActiveWorkoutSheet.
- Lane C established the elevation grammar you MUST reuse: `entranceReveal(index:)` modifier + `Motion.staggerStep` + `Motion.resolved(<token>, reduceMotion:)` (all in Components/CardStyle.swift), count-up via .contentTransition(.numericText()) + Motion.scoreCountUp, PressableButtonStyle (.pressable) + Haptics.tap()/success()/warning(). Every animation must resolve to nil/instant under accessibilityReduceMotion.

GOAL — Bring the LOGGING screens up to the same elevation standard, and run a consistency sweep so the whole app feels like one hand made it.

TASKS:
1. SESSION START POLISH (SessionStartPicker + ActiveWorkoutSheet): entrance choreography for the 4-way grid (entranceReveal, staggered), Motion.state animation when the basketball follow-up row / Other-Sport controls / Adjust disclosure appear or collapse (currently may pop), selected-state transitions, Haptics.tap() on option selection (if not already), pressable feedback on all tappable options. The Import-plan entry (Lane B) should feel integrated, not bolted on.
2. EXERCISE PICKER POLISH (ExercisePickerView): entrance for the list, Motion.state for search-result changes and the instant-add row appearing/disappearing, haptic on instant-add success (Haptics.success()), pressable rows.
3. ENTRY/SET LOGGING POLISH (ActiveWorkoutSheet entry cards, WeightBlockPicker, RepScrubber, FinishWorkoutSheet): audit interactions — set-done toggles, weight/rep adjustments, exercise add/remove — for missing Motion.state transitions, missing haptics (set completion = Haptics.success(), destructive remove = Haptics.warning()), abrupt list mutations (use Motion.state animation on the collection changes). Finish flow: FinishWorkoutSheet entrance + summary numbers may use .numericText() count-up where a total is revealed. Do NOT redesign these controls — they were carefully built (3-block WeightBlockPicker, RepScrubber); only smooth what pops and add missing feedback.
4. CONSISTENCY SWEEP (whole app, read-mostly): grep-level audit for violations that crept in anywhere: .shadow(, RoundedRectangle, cornerRadius, .system(, Color(hex/red:/etc hardcoded, raw numeric paddings that are NOT multiples of 8 and not via Spacing.*, animations bypassing Motion tokens, user-facing string literals not going through localization. FIX violations in files you own (Views/WorkoutLog/**, Components/** shared logging components); for violations in files you do NOT own, LIST them in the report instead of fixing.
5. TESTS: only if you touch pure logic (unlikely). UI polish needs no new tests.

FILES OWNED: everything under WorkloadApp/Views/WorkoutLog/ (ActiveWorkoutSheet, ExercisePickerView, SessionStartPicker usage, WeightBlockPicker, RepScrubber, FinishWorkoutSheet, WorkoutLogView, import sheets), WorkloadApp/Components/ (shared, additive-only for helpers), Localizable.xcstrings (additive), pbxproj only if adding a file.
DO NOT TOUCH: Views/Dashboard, Views/Recovery, Views/Workload, Views/Profile, Views/Onboarding, Views/Auth, Views/Coach (Lane C finished those); Services/ (except NO changes at all); Models/; Repositories/; ViewModels/ logic.

HARD CONSTRAINTS: structure freeze (no layout/IA/copy-meaning changes), Reduce Motion suppression on every new animation, Motion tokens only (new tokens go in CardStyle.swift named+commented), no behavior changes to logging logic (isDone safety, suggestions, carry-forward etc. must be untouched).

PROJECT MECHANICS:
- Build gate (run before finishing): xcodebuild -project "workload management/workload management.xcodeproj" -scheme "workload management" -destination "id=8E872500-703D-4292-9758-38ADFCCFB126" -derivedDataPath "$HOME/.tonus-dd" build
  If the sandbox blocks xcodebuild, say so explicitly in your final report and finish — the orchestrator will build externally. Do not fake a build result.

FINAL REPORT: per-screen polish list; consistency-sweep findings (fixed in owned files vs LISTED for others); any new Motion tokens; Reduce Motion approach; files changed; new localization keys; build gate result (or sandbox-blocked); anything deliberately skipped and why.
