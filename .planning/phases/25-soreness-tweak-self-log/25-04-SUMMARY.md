---
phase: 25-soreness-tweak-self-log
plan: 04
subsystem: ui-capture
tags: [niggle, soreness, swiftui, design-system, dashboard, post-workout]
requires:
  - "SorenessLog model + SorenessLogRepository (25-01)"
  - "MuscleRegion / MuscleGroup coarse-alias round-trip (Phase 22)"
  - "NiggleType enum (25-01)"
  - "DesignToggleStyle / MenuChevron / Spacing / SharpTextFieldStyle / WellnessSlider primitives"
provides:
  - "NiggleLogSheet — one-screen DESIGN-compliant niggle capture sheet"
  - "Dashboard on-demand 'Log a niggle' affordance (D-07)"
  - "Non-blocking post-workout niggle nudge in ActiveWorkoutSheet (D-08)"
affects:
  - "WorkloadApp/Views/Dashboard/DashboardView.swift"
  - "WorkloadApp/Views/WorkoutLog/ActiveWorkoutSheet.swift"
  - "Phase 27 (per-muscle fusion consumes the stored MuscleGroup.rawValue)"
tech-stack:
  added: []
  patterns:
    - "Region picked at coarse MuscleRegion granularity, stored as MuscleGroup alias rawValue"
    - "Post-save nudge routed through a single finishOrNudge() terminal so it never collides with spike/PR early-returns"
key-files:
  created:
    - "WorkloadApp/Views/Recovery/NiggleLogSheet.swift"
  modified:
    - "WorkloadApp/Views/Dashboard/DashboardView.swift"
    - "WorkloadApp/Views/WorkoutLog/ActiveWorkoutSheet.swift"
    - "WorkloadApp/Resources/Localizable.xcstrings"
    - "workload management/workload management.xcodeproj/project.pbxproj"
decisions:
  - "Affordance shape: a low-prominence tappable card-style ROW at the bottom of the Dashboard (not a 2nd toolbar button) — avoids toolbar crowding per D-07 discretion."
  - "Severity control: a dedicated 0–10 Rectangle segment bar (NOT a generalized WellnessSlider, which is hard-coded to 1–5 and renders '/5'). Mirrors WellnessSlider's Rectangle-segment grammar with a 0–10 range and zone-tinted fill."
  - "Nudge sequencing: a confirmationDialog presented from finishOrNudge(), which is the single terminal called from (a) the success path (replacing the final dismiss()), (b) the PR overlay onDismiss, and (c) the spike banner onDismiss. The save commit + pipeline + the spike/PR branches are byte-unchanged; the nudge always fires strictly AFTER those branches resolve."
  - "pbxproj membership for NiggleLogSheet.swift was added after a fresh re-read of project.pbxproj, serialized after 25-03's NiggleInjuryDeriver.swift membership (DD25-prefixed ID namespace, DD2504...)."
metrics:
  duration: "~25 min"
  completed: "2026-05-30"
  tasks_completed: "2 of 2 code tasks (Task 3 is the blocking human-verify checkpoint)"
---

# Phase 25 Plan 04: Niggle Capture UI Summary

DESIGN-compliant `NiggleLogSheet` (region / type / severity 0–10 / limited-training / note / Save) reachable from an on-demand Dashboard affordance (D-07) and a non-blocking post-workout nudge (D-08), writing a local-only `MuscleGroup`-aligned `SorenessLog` via the repository — honestly framed as a load-tolerance context log, never injury prediction.

## What was built

- **`NiggleLogSheet.swift`** — a separate sheet (D-09, NOT folded into `MorningCheckInSheet`) mirroring the `MorningCheckInSheet` scaffold: `NavigationStack` + `ScrollView` + `VStack(spacing: 0)` with 0.5pt `Rectangle` dividers, Cancel/Save toolbar. Controls:
  - **Where** — a `Menu`-backed picker (with `MenuChevron`) over the 7 `MuscleRegion` cases (`displayName` + `systemImage`); on Save the region is stored as its `MuscleGroup` alias via `MuscleGroup(rawValue: region.rawValue)` (round-trips for the 7 coarse cases) for Phase-27 per-muscle fusion.
  - **What** — a DESIGN-compliant segmented control (Rectangle segments, `text1` fill on selection) over `NiggleType.allCases` — no system `Picker(.segmented)`.
  - **How bad** — a 0–10 Rectangle segment bar with zone-tinted fill (optimal/caution/danger) and a `n/10` readout.
  - **Limited your training?** — a `Toggle` with `.toggleStyle(.design)` (DesignToggleStyle — no Apple green), default off.
  - **Note (optional)** — `TextField(axis: .vertical)` with `SharpTextFieldStyle`.
  - Save → `SorenessLogRepository(modelContext:).insert(...)` then dismiss. Athlete via `@Query … .first`.
- **Dashboard (D-07)** — `@State showNiggleLog`, a `.sheet { NiggleLogSheet() }`, and a low-prominence card-style "Log a niggle" row at the bottom of the dashboard content. No nag, no reminder.
- **Post-workout nudge (D-08)** — `@State showNiggleNudge` / `showNiggleLog` + a `confirmationDialog("Anything bother you?")` with "Log a niggle" / one-tap "Skip", presented from `finishOrNudge()`. The save commit, the `WorkoutPipeline.processSession` call, and the spike/PR early-return branches are byte-unchanged; the nudge is sequenced strictly after them and never gates the save.

## Deviations from Plan

None affecting scope. Two in-plan discretionary choices were exercised and documented above: the affordance is a **row** (not a toolbar button), and severity uses a **dedicated 0–10 segment bar** (not a generalized `WellnessSlider`, since that primitive is hard-coded to 1–5).

## Deferred Issues (out of scope — pre-existing)

The full `xcodebuild test` run surfaced 3 deterministic failures in `WorkloadAppTests/ShadowPredictorTests` (`test_baselineArm_equalsBaselinePrediction_byteIdentical`, `test_cycleAwareArm_collapsesToBaseline_forUnknownPhase`, `test_cycleAwareArm_equalsCycleAwarePrediction_byteIdentical`). These are **Phase 24 algorithm-moat** tests (file last touched by `9e9e95f`); my changed files touch no shadow/predictor/algorithm sources. Logged to `deferred-items.md`, NOT fixed by 25-04 (SCOPE BOUNDARY). App **build is green**; all other suites (FatigueIndexEngine, Subscription gating, ProgressionEngine, ScreenshotTests, …) pass.

## Verification

- **Build:** `xcodebuild build` → **BUILD SUCCEEDED** (iPhone 17 Pro Max sim `8E872500-703D-4292-9758-38ADFCCFB126`).
- **DESIGN gate (ZERO):** `grep "RoundedRectangle\|\.shadow(\|\.system(" NiggleLogSheet.swift` → 0; `.toggleStyle(.design)` present.
- **Honest-framing gate (ZERO):** no `injury` / `prediction` / `diagnos` in `NiggleLogSheet.swift` or the `ActiveWorkoutSheet` nudge copy.
- **Non-blocking save:** `try modelContext.save()`, the pipeline call, and the spike/PR branches in `saveSession()` are byte-unchanged.
- **pbxproj:** `NiggleLogSheet.swift` has 4 membership entries (PBXBuildFile / PBXFileReference / Recovery group child / Sources phase), added after a fresh re-read and serialized after 25-03.
- **Human checkpoint (Task 3):** PENDING — this plan is `autonomous: false`; awaiting visual approval.

## Commits

- `35beb22` — feat(25-04): DESIGN-compliant NiggleLogSheet
- `2aa8a59` — feat(25-04): Dashboard affordance + non-blocking post-workout nudge

## Self-Check: PASSED

- `WorkloadApp/Views/Recovery/NiggleLogSheet.swift` — FOUND
- commit `35beb22` — FOUND
- commit `2aa8a59` — FOUND
