IMPORTANT: Do NOT read or execute any files under ~/.claude/, ~/.agents/, .claude/skills/, or agents/. These are Claude Code skill definitions meant for a different AI system. Do NOT modify agents/openai.yaml. Stay focused on repository code only.

You are implementing Lane A of a planned round in the Tuwa iOS app (SwiftUI + SwiftData, iOS 17+). Work directly in this checkout. Do NOT create branches or worktrees. Do NOT commit — leave all changes in the working tree; the orchestrator verifies and commits.

READ FIRST: CLAUDE.md and DESIGN.md at repo root. Design rules are absolute: 0pt corner radius (Rectangle only), no shadows, fonts only via Font.Tokens (General Sans), colors only via ColorTokens, all spacing multiples of 8pt, accent color only per DESIGN.md semantics, motion only via the Motion tokens in Components/CardStyle.swift. User-facing strings go through localization keys in WorkloadApp/Resources/Localizable.xcstrings — add keys with BOTH en and zh-Hans values, additive edits only, never regenerate the catalog.

PROJECT MECHANICS:
- New APP source files must be registered in "workload management/workload management.xcodeproj/project.pbxproj" (PBXFileReference + PBXBuildFile + group child + Sources build phase entry — mimic an existing sibling file's entries exactly). Test files under WorkloadAppTests/ need NO pbxproj edits (synchronized group).
- Build gate (run before finishing): xcodebuild -project "workload management/workload management.xcodeproj" -scheme "workload management" -destination "id=8E872500-703D-4292-9758-38ADFCCFB126" -derivedDataPath build build
  If the sandbox blocks xcodebuild, say so explicitly in your final report and finish — the orchestrator will build externally. Do not fake a build result.

TASK 1 — Replace session-start pickers with one 4-way choice.
In WorkloadApp/Views/WorkoutLog/ActiveWorkoutSheet.swift the session info section currently shows two RadialPickers (SportType, SessionType) + conditional MatchTierPicker. Replace them with a new component (new file WorkloadApp/Components/SessionStartPicker.swift) presenting exactly four options: Strength, Basketball, Aerobic, Other Sport. Semantics (display labels are localized; underlying enums unchanged — NO enum raw-value changes, NO SwiftData migration):
- Strength → sportType .lifting, sessionType .strength
- Basketball → sportType .teamSport, then a follow-up row with four choices: Practice (→ sessionType .skill), Pickup (→ .match, matchTier .pickup), Scrimmage (→ .match, .scrimmage), Match (→ .match, .match)
- Aerobic → sportType .custom, sessionType .cardio (label like "Aerobic / Class")
- Other Sport → follow-up compact sport choice (running, cycling, swimming, crossfit, custom) with sessionType defaulted via the existing defaultSessionType(for:) and a small control to change session type
Include a collapsed "Adjust" affordance that reveals the full existing sport/session controls so no capability is lost. Preserve all downstream behavior: matchTier state, template/resolvedPlan init paths, defaultSessionType logic. Both init paths (template:, resolvedPlan:) must still prefill correctly and reflect the right 4-way selection state.

TASK 2 — Free-text movement bank in the exercise picker.
In WorkloadApp/Views/WorkoutLog/ExercisePickerView.swift: when the search/filter query does not match an existing exercise, show a prominent "Add '<query>'" row at the top. Tapping it immediately returns (name, category, muscle) to the caller — instant accept, zero extra required taps. Classification comes from a new pure engine (new file WorkloadApp/Services/ExerciseClassifier.swift, struct with static methods, no dependencies per repo conventions): keyword/alias heuristics mapping movement vocabulary to ExerciseCategory + MuscleGroup (examples: squat/deadlift/press/row/clean/snatch → .compound with sensible muscle; curl/raise/extension/fly/pulldown → .isolation; run/bike/erg/swim → .cardio; plank/push-up/pull-up/dip → .bodyweight; shooting/dribbling/agility/drill → .drill; unknown → .isolation + nil muscle). Cover common English strength/basketball vocabulary generously (aliases, hyphenation, case-insensitive).
Persistence: in-session add must ALWAYS work regardless of subscription tier. Saving the movement as a reusable CustomExercise follows the EXISTING isPro gate exactly as currently implemented — do not change gating semantics.
Background refinement: after an instant add, fire one non-blocking Task that calls the existing WorkoutLLMImportService.parseWorkoutText (edge function "parse-workout") with a minimal synthetic text like "<name> 3x8", and if the parsed exercise_category/muscle_group differ from the heuristic, update the saved CustomExercise's fields (not the in-flight draft). Single attempt, silent failure, never blocks or surfaces errors to the logging flow. If a small additive helper in WorkoutLLMImportService.swift makes this cleaner, add one — do not restructure the service.

TASK 3 — Tests.
Add unit tests in WorkloadAppTests/ for: the 4-way mapping (all four options + basketball follow-ups produce the exact sportType/sessionType/matchTier combos) and ExerciseClassifier heuristics (a representative table of names → expected category/muscle).

DO NOT TOUCH (owned by other lanes): anything under Views/Dashboard, Views/Recovery, Views/Profile, Views/Workload; WorkoutImportSheet.swift; TextTemplateImportSheet.swift; ShareImportPreviewSheet.swift; Components/CardStyle.swift; ColorTokens.swift; FontTokens.swift. Do not add third-party dependencies. Do not touch Supabase edge functions or any backend code.

FINAL REPORT (print at the end): files changed (full list), what each change does, new localization keys added, build gate result (or sandbox-blocked note), test results if run, any open questions or deviations from this brief.
