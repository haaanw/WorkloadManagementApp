# CODEX-A — Shell Integration: port the verdict wedge into the running UIKit shell

**Priority: P0.** The running app is a UIKit shell; the entire SwiftUI Views/ tree is dead code. The v2.0/v2.1 verdict surfaces were built in SwiftUI and are therefore invisible in the real app. This session ports them natively.

## Ground rules
- Baseline commit: `36b69a4` (724 unit tests green). Work in the working tree; do NOT `git commit/checkout/stash/branch` — the orchestrator session verifies and commits.
- The service/engine layer (`WorkloadApp/Services/`, `Repositories/`, `Models/`) is ALIVE and fully tested — consume, never modify.
- Edit ONLY: `WorkloadApp/App/AppShell.swift`, `AppShellUIKitPrimitives.swift` (only if a new primitive is required), `AppShellContracts.swift` (only if required), `WorkloadApp/Resources/Localizable.xcstrings` (surgical insertion-only, alphabetical position, never reformat), and NEW test files in `WorkloadAppTests/` (filesystem-synchronized target — no pbxproj edits; never touch pbxproj).
- Do NOT read `~/.claude/`, `.claude/skills/`, or `agents/`.

## Read first
`CLAUDE.md`, `CONTEXT.md` (Verdict, Microdose, Match tier, Match proximity, Strike zone), `DESIGN.md`, `.planning/notes/v21-basketball-beachhead-plan.md`, `.planning/notes/dogfood-protocol-n1.md`. Then the shell grammar: `TrainHomeViewController` (~AppShell.swift:4200–4500), `PlanTodayViewController` (~4799), Measurement screen (~3240), `dataPlate`/`actionRow`/`metricRow`/`divider`, `InstrumentScrollViewController.rebuild()`, `UIKitStrings.localized`, accessibilityIdentifier conventions.

## The five ports (specs = the dead SwiftUI twins; render in UIKitDesign grammar, NO UIHostingController)

1. **Today verdict card** on Train tab, above plan-today row. Spec: `Views/WorkoutLog/TodayVerdictCard.swift` + `ViewModels/TodayVerdictViewModel.swift`. Flow: `TodayVerdictService.evaluateTodaysPlannedSession` / `evaluateAndWrite` (pass `athlete.nextMatchDate` — this makes the running app WRITE VerdictEvents, turning the Measurement screen live). Frozen decisions read the persisted `VerdictEvent.matchProximity` flag — never recompute from the live date. Render: state label (Steady/Adjust/Microdose/Learning), big adjusted top-set number, compact strike-zone bar (zone lane + dot + planned tick — geometry in the SwiftUI `StrikeZoneBar`), one-line reason, suggest-and-confirm actions (semantics in `Services/VerdictDecision.swift` + applier; athlete always decides; never a red gate; hold = calm rest copy). Reuse `verdictCard.*`/`verdict.*` keys.
2. **Next-match row** below the verdict card. Spec: `Views/WorkoutLog/NextMatchSection.swift` — calm empty state, "Match today/tomorrow/in N days" + short date, change/clear, future-only UIDatePicker sheet, start-of-day normalization, silent expiry (on appear + day-change notification), negative-days guard. Reuse `nextMatch.*` keys.
3. **Felt-right prompt row**, only when eligible (exactly the calendar day after a differing-verdict day — `FeltRightPromptEngine`). Record via `VerdictEventRepository.recordFeltRight` (enforces eligibility at record time; on refusal hide the row). Felt right / Felt wrong / Unsure. Reuse `feltRight.*` keys.
4. **Match tier picker** in the shell's session-logging flow (sessions saving with a `SessionType`, ~4459 region + session editor). When `sessionType == .match`: Pickup/Scrimmage/Match row (`matchTier.*` keys); persist explicitly — `.pickup` when shown-but-untouched (mirror dead `ActiveWorkoutSheet`'s `MatchTierPicker` + Stage-3 semantics); clear when switching away from `.match`.
5. **Dogfood window card** on the Measurement screen: mirror dead `Views/Profile/VerdictMeasurementView.swift` using `FeltRightPromptEngine.DogfoodSummary` — differing days, followed %, felt-right % ("N rated · M missed"), proximity-microdose count. Reuse `measurement.dogfood.*` keys.

## Rules
Match shell grammar exactly (UIKitDesign fonts/colors/hairlines/Spacing, dataPlate composition, 48pt row minimums where siblings use them). Light-only. Anti-nocebo copy per CONTEXT.md. Reuse existing localization keys; new keys en+zh-Hans only when genuinely new. New accessibilityIdentifiers per shell convention; never change existing ones (XCUI depends on them).

## Gate (run yourself, report exact numbers)
1. `xcodebuild build -project "workload management/workload management.xcodeproj" -scheme "workload management" -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -derivedDataPath /tmp/dd-codexint` — must succeed.
2. Same flags + `test -only-testing:WorkloadAppTests` — 0 failures (2 pre-existing skips OK).

## Final report
Per-port summary (what/where/line ranges); VerdictEvent write-path flow; keys added vs reused; exact gate counts; deviations + why.

*Note: a prior codex session (id `019f3be2-5ade-7fb0-b87b-07bb4fb4eade`) read most context but made zero edits before being killed — resuming it may save reading time.*
