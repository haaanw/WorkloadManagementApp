---
phase: 42-plan-input-today-s-planned-session-adjustable-targets
plan: 03
subsystem: ui
tags: [swiftui, workout-log, plan-today, template-picker, manual-entry, design-system, localization]

requires:
  - phase: 42-02
    provides: PlannedSessionRepository (planFromTemplate / planManualLift / fetchTodaysPlannedSession)
  - phase: 42-01
    provides: TemplateSet verdict-target slots carried by frozen prescription copies
provides:
  - "Plan Today affordance in the Workout Log toolbar menu (chooser with two designation paths)"
  - "PlanTodaySheet (reuses TemplatePickerSheet) and ManualLiftEntrySheet (one-off lift form)"
  - "Both en + zh-Hans localized strings for the Plan-Today flow"
affects: [43-verdict-engine, 44-verdict-ui]

tech-stack:
  added: []
  patterns:
    - "Reuse-first UI: load-template path presents the EXISTING TemplatePickerSheet rather than rebuilding"
    - "Repository constructed at point of use inside the view (PlannedSessionRepository(modelContext:))"
    - "DESIGN.md-compliant minimal sheets: cardStyle/SharpTextFieldStyle/Rectangle, no accent/shadow, 8pt grid, .design toggle (no Apple green)"

key-files:
  created:
    - WorkloadApp/Views/WorkoutLog/PlanTodaySheet.swift
    - WorkloadApp/Views/WorkoutLog/ManualLiftEntrySheet.swift
  modified:
    - WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift
    - workload management/workload management.xcodeproj/project.pbxproj
    - WorkloadApp/Resources/Localizable.xcstrings

key-decisions:
  - "Plan Today added to the existing ellipsis menu; the '+' start-session flow left untouched"
  - "Manual RPE is optional behind a toggle (slider 1...10); weight/reps parsed before persistence"
  - "TemplatePicker onStartBlank funnels to the manual entry (no blank 'plan' concept)"

patterns-established:
  - "Designate-today UI funnels both paths through PlannedSessionRepository to an existing PrescribedWorkout"

requirements-completed: [PLAN-10]

duration: 6min
completed: 2026-06-13
---

# Phase 42 Plan 03: Plan-Today UI Summary

**A DESIGN.md-compliant "Plan Today" affordance in the Workout Log toolbar menu that opens a two-path chooser — load an existing template (reusing TemplatePickerSheet → planFromTemplate) or enter a one-off manual lift (ManualLiftEntrySheet → planManualLift) — each creating today's PrescribedWorkout, with no verdict/adjusted-number surfacing.**

## Performance

- **Duration:** ~6 min
- **Started:** 2026-06-13T15:11Z (approx, after 42-02)
- **Completed:** 2026-06-13T15:17:07Z
- **Tasks:** 4 (3 autonomous code tasks + 1 human-verify checkpoint, deferred — see below)
- **Files modified:** 5 (2 created, 3 modified)

## Accomplishments
- `ManualLiftEntrySheet` — minimal one-off form (lift name + target weight/reps + optional RPE) creating a `PrescribedWorkout` (templateId nil) via `planManualLift`.
- `PlanTodaySheet` — two-path chooser; the load-template path REUSES the existing `TemplatePickerSheet` and calls `planFromTemplate` (frozen copy), the manual path presents `ManualLiftEntrySheet`.
- `WorkoutLogView` — new "Plan Today" item (`calendar.badge.plus`) in the existing ellipsis menu + `.sheet`; the "+" start-session flow and all other sheets untouched.
- Both new view files registered with 4 explicit pbxproj entries each (exactly one fileRef each, no stray duplicates).
- 17 new localized keys added to `Localizable.xcstrings` in both en and zh-Hans.

## Task Commits

1. **Task 1: ManualLiftEntrySheet + strings** - `8017e52` (feat)
2. **Task 2: PlanTodaySheet + WorkoutLogView entry point** - `e95316f` (feat)
3. **Task 3: pbxproj registration (both view files)** - `2172ef7` (feat)
4. **Task 4: human-verify checkpoint** - deferred to on-device UAT (see below)

## Files Created/Modified
- `WorkloadApp/Views/WorkoutLog/PlanTodaySheet.swift` - Two-path designation chooser.
- `WorkloadApp/Views/WorkoutLog/ManualLiftEntrySheet.swift` - One-off manual lift form.
- `WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift` - Menu item + sheet wiring.
- `workload management/workload management.xcodeproj/project.pbxproj` - 8 entries (EE4203 PlanTodaySheet, EE4204 ManualLiftEntrySheet).
- `WorkloadApp/Resources/Localizable.xcstrings` - 17 new `planToday.*` keys (en + zh-Hans). (The diff is large because Xcode/serialization re-sorted the catalog keys; content is intact — verified by a green build that resolves all referenced keys.)

## Decisions Made
- Reused `TemplatePickerSheet` verbatim for the load-template path (CONTEXT "reuse existing template-picker UI").
- RPE is optional (toggle + slider) to keep the manual form minimal; weight accepts comma or dot decimals.
- `onStartBlank` from the picker funnels to the manual entry rather than introducing a blank-plan concept.
- Did NOT touch or call the dormant coach code (PrescribeWorkoutSheet/PrescribedWorkoutCard remain untracked and uncompiled); no `pushPrescribedWorkout` call introduced.

## Deviations from Plan

None - plan executed exactly as written. (The checkpoint resolution below is per orchestrator instruction, not a code deviation.)

## Checkpoint — Task 4 (human-verify): DEFERRED to on-device UAT

No human is available in this execution, so per the orchestrator instruction all code-verifiable checks were performed and the phase PROCEEDED without blocking. Code-verifiable results:

- **Build green** on sim `CAF84E71-BB64-491D-87C8-875A0143B26D` with both new view files compiled in (`** BUILD SUCCEEDED **`).
- **DESIGN.md compliance by inspection / grep:** zero matches for `RoundedRectangle`, `.shadow`, `ColorTokens.accent`, `.system(`, or `.cornerRadius` in `PlanTodaySheet.swift` and `ManualLiftEntrySheet.swift`. All surfaces use `cardStyle()` / `SharpTextFieldStyle` / `Rectangle`, `Font.Tokens.*`, `Spacing.*` (8pt grid), and the neutral `.design` toggle (no Apple green).
- **Flow correctness in code:** `PlanTodaySheet` load-template path → `PlannedSessionRepository.planFromTemplate`; manual path → `ManualLiftEntrySheet` → `planManualLift`. `WorkoutLogView` presents `PlanTodaySheet` from the ellipsis menu; the "+" flow is unchanged. Both repository paths are proven to create a fetchable today PrescribedWorkout by the green `PlannedSessionRepositoryTests` (42-02).
- **Localization:** both en and zh-Hans present for all 17 new keys.

**Still requires a human on-device pass (deferred):**
1. Visually confirm 0pt corners, no shadows, General Sans only, 8pt rhythm, and NO accent color in both sheets, in BOTH light and dark mode.
2. Walk Path A (load a template) and Path B (enter a lift) on a device/simulator and confirm clean dismissal + that today's PrescribedWorkout exists afterward.
3. Confirm the existing "+" start-session flow and other Workout Log behavior are unchanged.

This UAT is consolidated into the project's deferred on-device UAT batch.

## Known Stubs
None. Both sheets are fully wired to the Plan-02 repository (no empty/mock data sources). The verdict slots intentionally stay nil — they are populated by the Phase-43 verdict engine (correctly out of scope this phase), which is documented intent, not a stub.

## Issues Encountered
None during 42-03. (The `@MainActor`-in-XCTest deinit crash encountered in 42-02 does not affect these views — they construct the repository inside SwiftUI on the main actor, which is correct.)

## Next Phase Readiness
- Phase 43 (verdict engine) has: a designated today `PrescribedWorkout` (fetchable via `fetchTodaysPlannedSession`) whose working sets carry the verdict-target slots at default, ready to read planned targets and write `adjustedTargetWeightKg` / `adjustedTargetRPE` / `verdictReason` / `verdictAppliedAt` onto the frozen copy.

## Self-Check: PASSED

- FOUND: WorkloadApp/Views/WorkoutLog/PlanTodaySheet.swift
- FOUND: WorkloadApp/Views/WorkoutLog/ManualLiftEntrySheet.swift
- FOUND: .planning/.../42-03-SUMMARY.md
- FOUND commits: 8017e52 (feat), e95316f (feat), 2172ef7 (feat)
- WorkoutLogView references PlanTodaySheet (1 occurrence)

---
*Phase: 42-plan-input-today-s-planned-session-adjustable-targets*
*Completed: 2026-06-13*
