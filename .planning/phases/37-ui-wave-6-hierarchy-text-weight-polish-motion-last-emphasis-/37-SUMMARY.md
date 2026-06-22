---
phase: 37
plan: 37
subsystem: ui
tags: [hierarchy, text-weight, emphasis, motion, design-system, v1.5.1, final-wave]
requires: [31, 32, 33, 34, 35, 36]
provides: [emphasis-tiers, confirmation-motion]
affects: [CoachRosterView, CoachExportSheet, SessionDetailView, UpgradeSheet, OnboardingView, DashboardView]
tech-stack:
  added: []
  patterns: [Font.Tokens-emphasis-tier, reduce-motion-aware-transition]
key-files:
  created: []
  modified:
    - WorkloadApp/Views/Coach/CoachRosterView.swift
    - WorkloadApp/Views/Export/CoachExportSheet.swift
    - WorkloadApp/Views/WorkoutLog/SessionDetailView.swift
    - WorkloadApp/Views/Subscription/UpgradeSheet.swift
    - WorkloadApp/Views/Onboarding/OnboardingView.swift
    - WorkloadApp/Views/Dashboard/DashboardView.swift
decisions:
  - "Hero score reveal + roster row diff are the only NEW motion (reduce-motion-aware, easeOut 0.25)"
  - "Held back custom sheet transitions and SessionDetail entry animation as decorative/low-signal"
metrics:
  duration: ~25m
  completed: 2026-06-02
---

# Phase 37 Plan 37: UI Wave 6 — Hierarchy / text-weight polish + motion (LAST) Summary

Final v1.5.1 wave: added one dominant emphasis tier to each of five audit-flagged flat rows using
existing `Font.Tokens` weights only, then two reduce-motion-aware confirmation transitions —
introducing zero new corner/shadow/font/accent/color/off-grid violations.

## Part 1 — Hierarchy / text-weight (commit 5b6befe)

| Site | Before | After | Effect |
|------|--------|-------|--------|
| CoachRosterView ClientCard status row | recovery/load zone `label`/text2 (= sport caption) | `labelMedium`/text1 | status now dominates the text3 sport caption |
| CoachExportSheet athlete row | name `label` (15pt), zone badge `micro` caps | name `bodyMedium` (17pt Med) | name dominates the supplementary zone badge |
| SessionDetailView per-exercise Total | `label`/text2 | `labelMedium`/text1 | totaled number promoted over caption |
| UpgradeSheet planButton price | `body`/`bodyMedium` (17pt); SAVE badge text3 | price `sectionHead` (19pt Med); SAVE badge text3→text2 | price prominence dominant; badge legible-but-subordinate |
| OnboardingView frequency tile | `body` for both states (color-only distinction) | selected → `bodyMedium`, unselected stays `body` | selected value gets active-state emphasis (mirrors experience-level + language autonym) |

No new fonts/sizes. No accent. No ColorTokens amendments. No new colors — only existing text1/text2
token swaps that strengthen the already-permitted hierarchy.

## Part 2 — Motion (commit 1fca70c)

Added exactly two NEW high-signal transitions, both honoring DESIGN.md Motion (easeOut 0.25, no
spring/bounce) and `@Environment(\.accessibilityReduceMotion)`:

1. **Dashboard hero readiness score** — `.transition(.opacity)` on the score `Text`, animated against
   `viewModel.hasRealData` (the orientation moment DESIGN.md sanctions for the score reveal).
2. **Coach Roster** — `.animation(easeOut 0.25, value: linkedAthletes.count)` so client rows animate
   in/out on pull-refresh (genuine list insert/remove).

The app already had a consistent, DESIGN.md-aligned motion vocabulary (easeOut 0.25 transitions,
linear 0.15 state changes, reduceMotion in RadialPicker). I matched it rather than inventing new
curves.

### Motion intentionally held back (for human review)
- **Custom sheet present/dismiss transitions** — the OS-default sheet animation already orients the
  user; bespoke `.move`/`.opacity` sheet transitions risk the decorative excess DESIGN.md warns
  against. Left as system default. Prefer fewer high-signal transitions.
- **SessionDetailView entry animation** — it is a static, read-only detail view; entries never
  insert/remove during viewing, so animating them would be pure decoration with no signal.

## Deviations from Plan
None — plan executed exactly as written. Rules 1-3 auto-fixes: none required.

## Build Status
- Part 1: **BUILD SUCCEEDED** (xcodebuild -project, sim CAF84E71-BB64-491D-87C8-875A0143B26D).
- Part 2: **BUILD SUCCEEDED** (same destination).

## FINAL Full Regression Gate (INVENTORY §5, rules 1-7) — run via per-file grep (rtk-safe)

| Rule | Result |
|------|--------|
| 1 — rounded corners / `.roundedBorder` | CLEAN (only doc-comment mentions of the rule) |
| 2 — `.shadow(` | CLEAN |
| 3a — `.font(.system(` | CLEAN |
| 3b — semantic system text style | CLEAN |
| 3c — system `.fontWeight` on token font | CLEAN |
| 4 — `ColorTokens.accent` outside Dashboard hero | CLEAN |
| 5a — hardcoded/system semantic color | Only `UIColor(red:…)` in `Services/PDFReportEngine.swift` — documented justified PDFKit exception (outside Views/Components). No Views/Components hits. |
| 5b — hardcoded hex in Views/Components | CLEAN |
| 6 — hand-rolled `.surface`+stroke card (heuristic) | 8 PRE-EXISTING hits (PrescribeWorkoutSheet, TemplatePickerSheet, NiggleLogSheet, ActiveWorkoutSheet×3, ShareImportSheet, ShareCodeSheet×3). Verified byte-identical at the Phase 36 tip (a424ece) — NOT a Phase 37 regression. Rule 6 is documented as a heuristic reviewer-recheck flag, not a hard rule-1-5 violation; these are inline input/selectable rows. |
| 7a — off-grid `.padding` literal | CLEAN |
| 7b — off-grid stack spacing | CLEAN |
| 7c — off-grid frame dimension | CLEAN |

**Hard rules 1-5 + grid (7): ZERO violations introduced by Phase 37; all CLEAN with only the
documented PDFKit exception.** The 8 rule-6 heuristic flags are pre-existing and unchanged by this
wave.

## Self-Check: PASSED
- All 6 modified files exist and compiled (BUILD SUCCEEDED ×2).
- Commits 5b6befe (Part 1) and 1fca70c (Part 2) present in git log.
- Phase 37 diff scope (5b6befe^..HEAD) = exactly the 6 intended view files, nothing else.
