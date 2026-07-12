IMPORTANT: Do NOT read or execute any files under ~/.claude/, ~/.agents/, .claude/skills/, or agents/. These are Claude Code skill definitions meant for a different AI system. Do NOT modify agents/openai.yaml. Stay focused on repository code only.

You are implementing Lane B of a planned round in the Tuwa iOS app (SwiftUI + SwiftData, iOS 17+). Work directly in this checkout. Do NOT create branches or worktrees. Do NOT commit — leave all changes in the working tree; the orchestrator verifies and commits.

READ FIRST: CLAUDE.md and DESIGN.md at repo root. Design rules are absolute: 0pt corner radius (Rectangle only), no shadows, fonts only via Font.Tokens (General Sans), colors only via ColorTokens, all spacing multiples of 8pt, accent color only per DESIGN.md semantics, motion only via the Motion tokens in Components/CardStyle.swift. User-facing strings go through localization keys in WorkloadApp/Resources/Localizable.xcstrings — add keys with BOTH en and zh-Hans values, additive edits only, never regenerate the catalog.

CONTEXT: Lane A just landed (commit 1cb37cd): ActiveWorkoutSheet now opens with a 4-way SessionStartPicker (Strength / Basketball / Aerobic / Other Sport) in WorkloadApp/Components/SessionStartPicker.swift. Free-text exercise add + LLM refinement landed in ExercisePickerView + WorkoutLLMImportService (helpers: resolveLocalExercise, parseExerciseText, resolveLLMExercise, makeCustomExercise).

TASK — Plan import: verify end-to-end, polish, and surface from the logging flow.
The app already has plan/workout import built around WorkoutLLMImportService.parseWorkoutText (Supabase edge function "parse-workout"), PDF text-layer + OCR fallback, and Vision image OCR. UI: WorkoutImportSheet.swift, TextTemplateImportSheet.swift, ShareImportPreviewSheet.swift.

1. TRACE the full import flows (pasted text, PDF, photo) from entry UI → parse → preview → saved WorkoutTemplate. Fix real rough edges you find: dead ends, missing error states, spinner-forever paths, unlocalized strings, DESIGN.md violations inside these three sheets. Do NOT restructure the service; additive/behavior-preserving fixes only.
2. SURFACE import from the session-start flow: when the user picks Strength in SessionStartPicker (or in the template selection area of ActiveWorkoutSheet — pick the architecturally cleanest of the two and say why), add a compact, non-intrusive entry point "Import plan" that opens the existing import UI. It must not add friction for users who just want to log.
3. Make sure an imported template is immediately usable: after successful import, the user should be able to start a session from it without app restart or manual refresh.
4. TESTS: add/extend unit tests for any pure logic you touch (e.g., parsing/mapping helpers). UI-only changes need no new tests.

FILES OWNED (do not touch others except Localizable.xcstrings additively + pbxproj if you add a new file): WorkloadApp/Views/WorkoutLog/WorkoutImportSheet.swift, TextTemplateImportSheet.swift, ShareImportPreviewSheet.swift, WorkoutLLMImportService.swift (additive only), SessionStartPicker.swift / ActiveWorkoutSheet.swift (ONLY the minimal additive entry-point wiring), WorkloadAppTests/*.
DO NOT TOUCH: anything under Views/Dashboard, Views/Recovery, Views/Profile, Views/Workload; Components/CardStyle.swift; ColorTokens/FontTokens; Models/*.swift (NO schema changes); Supabase edge functions or backend.

PROJECT MECHANICS:
- New APP source files must be registered in "workload management/workload management.xcodeproj/project.pbxproj" (PBXFileReference + PBXBuildFile + group child + Sources build phase entry — mimic an existing sibling file's entries exactly). Test files under WorkloadAppTests/ need NO pbxproj edits (synchronized group).
- Build gate (run before finishing): xcodebuild -project "workload management/workload management.xcodeproj" -scheme "workload management" -destination "id=8E872500-703D-4292-9758-38ADFCCFB126" -derivedDataPath "$HOME/.tonus-dd" build
  If the sandbox blocks xcodebuild, say so explicitly in your final report and finish — the orchestrator will build externally. Do not fake a build result.

FINAL REPORT (print at the end): flows traced and what actually works vs broken (be honest — if you could not exercise the edge function network path, say so), files changed with what/why, new localization keys, entry-point placement decision + rationale, build gate result (or sandbox-blocked note), tests added/results, open questions.
