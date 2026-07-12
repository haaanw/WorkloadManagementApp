# Orchestration Plan — Simplified Logging + UI Elevation Round

Date: 2026-07-10. Orchestrator: Claude (this session). Workers: Codex CLI exec sessions, serial, in canonical checkout (no worktrees, no branches — per standing rule). Orchestrator verifies every build claim and commits per lane.

## User decisions (2026-07-10)
- D1: Replace two RadialPickers with ONE 4-way session-start picker (Strength / Basketball / Aerobic / Other sport).
- D2: Free-text movement bank — instant accept, local heuristic classify, background LLM refine via existing `parse-workout` edge function. Logging never blocks on network.
- D3: Plan import (PDF/photo/text — already built in WorkoutLLMImportService) — verify end-to-end, polish, surface from new start screen.
- D4: Full-app UI polish pass; non-logging screens first, logging screens after Lanes A+B land.

## Ground truth (verified)
- Scheme: `workload management`; project: `workload management/workload management.xcodeproj`
- Build gate: `xcodebuild -project "workload management/workload management.xcodeproj" -scheme "workload management" -destination "id=8E872500-703D-4292-9758-38ADFCCFB126" -derivedDataPath build build` (iPhone 17 Pro Max sim, alive; `build/` gitignored)
- New APP source files MUST be registered in project.pbxproj (PBXFileReference + PBXBuildFile + group + Sources phase). Test files under `WorkloadAppTests/` auto-sync (PBXFileSystemSynchronizedRootGroup).
- Strings: `WorkloadApp/Resources/Localizable.xcstrings` (en + zh-Hans). Additive edits only; never regenerate the catalog (build-churn gotcha).
- Session enums: SportType (7 cases) + SessionType (5) + MatchTier (pickup/scrimmage/match) in `WorkloadApp/Models/Enums.swift`. NO raw-value changes, NO SwiftData migrations this round.

## Lane sequence (serial; each lane: Codex edits → orchestrator builds → orchestrator commits)

### Lane A — Session start + free-text movement bank
Files owned: `Views/WorkoutLog/ActiveWorkoutSheet.swift`, `Views/WorkoutLog/ExercisePickerView.swift`, new `Components/SessionStartPicker.swift`, new `Services/ExerciseClassifier.swift`, `Services/WorkoutLLMImportService.swift` (additive helper only), `Localizable.xcstrings` (additive), pbxproj (additive), tests.
1. 4-way picker replaces both RadialPickers in ActiveWorkoutSheet:
   - Strength → (.lifting, .strength)
   - Basketball → .teamSport + follow-up row: Practice → .skill · Pickup → .match/tier .pickup · Scrimmage → .match/.scrimmage · Match → .match/.match (keeps MatchTier science)
   - Aerobic → (.custom, .cardio) — display label "Aerobic / Class"
   - Other sport → compact follow-up sport picker (running, cycling, swimming, crossfit, custom) + session type defaulting via `defaultSessionType(for:)`
   - Collapsed "Adjust" affordance retains full sport/session control; no capability lost.
2. Free-text bank in ExercisePickerView: no-match query → prominent "Add '<query>'" row → instant accept using `ExerciseClassifier.classify(name:)` (keyword/alias heuristics → ExerciseCategory + MuscleGroup). In-session add works for ALL tiers; persistent CustomExercise save follows existing isPro gate. Background one-shot LLM refine via `parse-workout` (synthetic text "<name> 3x8"), silent failure, updates CustomExercise category/muscle only.
3. Unit tests for mapping + classifier.

### Lane B — Plan import verify + integrate
Files owned: `WorkoutImportSheet.swift`, `TextTemplateImportSheet.swift`, `ShareImportPreviewSheet.swift`, `WorkoutLLMImportService.swift`, small additive entry point in session-start UI (coordinates with Lane A output).
End-to-end verify PDF/photo/text import; fix rough edges; surface import from the new start screen (under Strength / templates area). No backend changes without flagging.

### Lane C — App-wide UI elevation (non-logging screens)
Files owned: Dashboard/, Recovery/, Profile/, Workload/ views, `Components/CardStyle.swift` (Motion), hero count-up implementation (`Motion.scoreCountUp` + `.numericText`), transitions, empty states, micro-interactions. DESIGN.md rules absolute: 0pt radius, no shadows, Font.Tokens, ColorTokens, 8pt grid, accent semantics, motion grammar (springs only for state/entrance).

### Lane D — Logging-screen polish + consistency sweep
After A+B: polish new session start, picker, entry cards, WeightBlockPicker/RepScrubber interactions, haptics coverage; app-wide consistency audit vs DESIGN.md.

### Final gate
Full test suite + orchestrator design-fence check + /codex review of the round's diff.

## Status log
- [x] Lane A dispatched (2026-07-10, codex exec full-auto)
- [x] Lane A verified + committed (2026-07-13, `1cb37cd`, pushed; includes CODEX-G freeform-exercise + CODEX-H; audit by sonnet agent; 2 reverts: truncated Enums.swift, unauthorized InfoPlist.xcstrings HealthKit-write key; 4 compile errors fixed; build+3 test suites green. NOTE: build gate now uses `-derivedDataPath ~/.tonus-dd` — in-repo `build/` is poisoned by iCloud xattrs)
- [x] Lane B dispatched (2026-07-13)
- [x] Lane B verified + committed (2026-07-13, `4af9276`, pushed; build green, sonnet audit SAFE-TO-COMMIT; import flows hardened, Import-plan entry on blank Strength sessions; ShareImportSheet still has no production callsite — open question for Lane D/final gate)
- [x] Lane C dispatched (2026-07-13, codex exec high)
- [ ] Lane C verified + committed
- [ ] Lane D dispatched
- [ ] Lane D verified + committed
- [ ] Final review gate
