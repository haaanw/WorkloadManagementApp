---
phase: 36
plan: 36
subsystem: design-system / spacing
tags: [ui, spacing, 8pt-grid, design-system, regression-gate]
requires: [phases 31-35 GREEN, Spacing enum (CardStyle.swift)]
provides: [Spacing.baselinePair token, fully grid-clean Views+Components spacing]
affects: [22 view/component files, INVENTORY §5 gate]
tech-stack:
  added: [Spacing.baselinePair (4pt documented sub-grid token)]
  patterns: [label-value baseline pairing tokenized; toggle geometry on-grid]
key-files:
  created: []
  modified:
    - WorkloadApp/Components/CardStyle.swift (token + toggle dims)
    - WorkloadApp/Components/MetricTile.swift
    - WorkloadApp/Components/StalenessWarningBadge.swift
    - WorkloadApp/Components/SleepTrendChart.swift
    - WorkloadApp/Components/RadialPicker.swift
    - WorkloadApp/Components/HRVTrendChart.swift
    - WorkloadApp/Views/Dashboard/HRVDetailView.swift
    - WorkloadApp/Views/Dashboard/SleepDetailView.swift
    - WorkloadApp/Views/Workload/WorkloadView.swift
    - WorkloadApp/Views/Workload/RecoveryLoadChart.swift
    - WorkloadApp/Views/Recovery/MorningCheckInSheet.swift
    - WorkloadApp/Views/Recovery/NiggleLogSheet.swift
    - WorkloadApp/Views/Recovery/RecoveryView.swift
    - WorkloadApp/Views/WorkoutLog/ActiveWorkoutSheet.swift
    - WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift
    - WorkloadApp/Views/WorkoutLog/ExercisePickerView.swift
    - WorkloadApp/Views/WorkoutLog/WorkoutImportBanner.swift
    - WorkloadApp/Views/WorkoutLog/WorkoutImportSheet.swift
    - WorkloadApp/Views/WorkoutLog/TextTemplateImportSheet.swift
    - WorkloadApp/Views/Profile/ProfileView.swift
    - WorkloadApp/Views/Profile/TrainingProfileSheet.swift
    - WorkloadApp/Views/Coach/CoachRosterView.swift
    - WorkloadApp/Views/Coach/ContextSwitcher.swift
    - WorkloadApp/Views/Coach/TemplateEditorSheet.swift
    - WorkloadApp/Views/Coach/PrescribeWorkoutSheet.swift
    - WorkloadApp/Views/Coach/TemplateListView.swift
    - WorkloadApp/Views/TemplateEditorSheet.swift
    - WorkloadApp/Views/PrescribeWorkoutSheet.swift
    - WorkloadApp/Views/TemplateListView.swift
    - WorkloadApp/Views/Subscription/UpgradeSheet.swift
    - .planning/v1.5-audit/INVENTORY.md (gate tightening)
decisions:
  - Adopted ONE documented sub-grid token Spacing.baselinePair (4pt) for label-value pairs
  - Dropped `4` from gate rule 7b (now a named token)
  - Toggle geometry re-gridded 48x28/20x20 -> 48x32/24x24 (preserves knob-fits-track)
  - Chart frames 180 -> 184 (on-grid + axis headroom)
metrics:
  duration: ~1 session
  completed: 2026-06-02
---

# Phase 36 Plan 36: Off-grid Spacing Sweep Summary

One-liner: Swept every residual off-8pt-grid padding/spacing/frame literal across
`WorkloadApp/Views` + `WorkloadApp/Components` to `Spacing.*` tokens, introduced one documented
`Spacing.baselinePair` (4pt) label-value token, re-gridded the design-system toggle, and tightened
the regression gate — rules 7a/7b/7c now CLEAN with rules 1–5 unregressed.

## What changed
- **New token:** `Spacing.baselinePair = 4` in `CardStyle.swift` — the single sanctioned sub-grid
  step, documented for label-value baseline pairs (MetricTile title→value, stat cells, picker
  value+chevron, badge insets). All structural spacing stays on the 8pt grid.
- **22 view/component files** swept: `spacing: 4` label-value pairs → `baselinePair`; row/field
  padding `12/10/6` → `Spacing.xs`(8) or `Spacing.sm`(16) by context; CTA buttons `12` → `Spacing.sm`;
  metadata/icon-label gaps `12/10/6` → `Spacing.xs`; divider inset `52` → `Spacing.xl`(48);
  chart frames `180` → `184`; toggle track `48×28`/knob `20×20`/inset `4` → `48×32`/`24×24`/`baselinePair`;
  paywall grabber `36×4` → `Spacing.lg × baselinePair`; dropped a 2pt checkmark optical kern in favor
  of `.top` alignment.
- **Gate tightened** (INVENTORY §5): dropped `4` from rule 7b stack-spacing list (now a named token);
  documented Wave 5 completion and the remaining justified sub-grid hairline/indicator exceptions.

## Scope honesty
The §2.C "112 findings" was the *original* pre-wave count; Waves 0–4 already snapped the files they
touched. The actual residual at Wave 5 start was **75 raw gate hits** (36 padding + 34 stack + 5 frame).
**All 75 were cleared.** Final scan: rules 7a/7b/7c report **zero** off-grid hits across Views+Components.
This was a fully completable sweep, not a partial one.

## Build status — GREEN
`xcodebuild -project "workload management/workload management.xcodeproj" -scheme "workload management"
-destination 'platform=iOS Simulator,id=CAF84E71-BB64-491D-87C8-875A0143B26D' build` → **BUILD SUCCEEDED**
at every gate (8 builds total, one per batch + toggle). Last build green after the toggle re-grid.

## Regression gate result
- **Rule 7a (padding literals):** CLEAN (0 hits).
- **Rule 7b (stack spacing):** CLEAN (0 hits).
- **Rule 7c (frame dims):** CLEAN (0 hits) — toggle 28/20 re-gridded to 32/24.
- **Rules 1–5 (corners / shadows / fonts / accent / color):** all CLEAN, **no regression**.
  - The only rule-5 matches are `UIColor(red:…)` constants in `Services/PDFReportEngine.swift` —
    a pre-existing, justified PDFKit-rendering exception **outside** Views/Components scope
    (the hardcoded-hex sub-check on Views/Components is CLEAN). Not introduced by this wave.

### Justified remaining sub-grid exceptions (documented, intentional — NOT off-grid spacing)
| Site | Value | Why |
|------|-------|-----|
| CoachRosterView:138 | `frame(width: 3)` | zone-indicator accent bar (indicator width) |
| NiggleLogSheet:198 | `frame(height: 4)` | severity-segment bar (indicator height) |
| HRVDetailView:95, UpgradeSheet:253 | `spacing: 2` | value-unit / micro-label baseline kern |
| UpgradeSheet:265 (was 2) | `baselinePair` | badge inset (tokenized) |
| all cards/toggles | `lineWidth: 0.5` | divider/border hairline |

## Sub-grid token adopted
**Yes** — `Spacing.baselinePair = 4`. Documented in `CardStyle.swift` and reflected in the gate.

## Deviations from Plan
None of Rules 1–4 triggered. All edits were in-scope grid hygiene. No architectural or
auth gates. Minor discretionary call: dropped the 2pt checkmark optical kern in UpgradeSheet
(rely on `.top` HStack alignment) rather than tokenize a sub-4pt value — keeps the gate honest.

## Commits
- `20ee0c4` feat(36): components spacing + baselinePair token
- `9eaaafe` feat(36): dashboard + workload spacing
- `79bd8b6` feat(36): recovery spacing
- `e074061` feat(36): workout log spacing
- `8d1d0c3` feat(36): profile spacing
- `c1481f4` feat(36): coach + templates spacing
- `76dd02b` feat(36): paywall spacing
- `61c4083` feat(36): toggle dims spacing
- `926afb2` chore(36): tighten regression-gate off-grid lists

## Known Stubs
None.

## Self-Check: PASSED
- 36-PLAN.md, 36-SUMMARY.md present.
- All 9 commits (20ee0c4 → 926afb2) verified in git log.
- `Spacing.baselinePair` token confirmed in CardStyle.swift.
