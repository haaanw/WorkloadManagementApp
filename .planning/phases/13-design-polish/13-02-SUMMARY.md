---
phase: 13-design-polish
plan: "02"
subsystem: typography
tags: [font-migration, design-system, alpino]
dependency_graph:
  requires: [13-01]
  provides: [complete-font-token-coverage]
  affects: [all-views-using-fonts]
tech_stack:
  added: []
  patterns: [centralized-font-tokens]
key_files:
  created: []
  modified:
    - WorkloadApp/Components/SpikeAlertBanner.swift
    - WorkloadApp/Components/FatigueAttentionBanner.swift
    - WorkloadApp/Components/ToastBanner.swift
    - WorkloadApp/Components/StalenessWarningBadge.swift
    - WorkloadApp/Views/Profile/InviteConfirmationSheet.swift
    - WorkloadApp/Views/Subscription/UpgradeSheet.swift
    - WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift
    - WorkloadApp/Views/WorkoutLog/TextTemplateImportSheet.swift
decisions:
  - All 20 .font(.system(size:)) calls confirmed as SF Symbol icon sizing -- correctly preserved as-is
  - StalenessWarningBadge Image(systemName:) used Font.custom(DMSans) for sizing -- converted to .Tokens.micro since it was a rogue DMSans call on an icon
metrics:
  duration: 5m 32s
  completed: 2026-05-10T10:56:07Z
  tasks: 2
  files_modified: 8
---

# Phase 13 Plan 02: Rogue Font Reference Migration Summary

Replace all raw Font.custom("DMSans-*") calls across 8 files with Font.Tokens references, eliminating every bypass of the centralized Alpino token system.

## Results

**Task 1: Convert raw Font.custom("DMSans-*") calls (8 files, 20 refs)** -- COMPLETE

Replaced all 20 occurrences of `Font.custom("DMSans-*")` with `Font.Tokens.*` references:

| File | Refs | Tokens Used |
|------|------|-------------|
| SpikeAlertBanner.swift | 6 | micro, smallLabel, smallLabelMedium |
| FatigueAttentionBanner.swift | 3 | micro, labelMedium, smallLabel |
| ToastBanner.swift | 1 | smallLabel |
| StalenessWarningBadge.swift | 1 | micro |
| InviteConfirmationSheet.swift | 6 | label, micro, pageTitle, smallLabel |
| UpgradeSheet.swift | 1 | micro |
| WorkoutLogView.swift | 1 | smallLabel / smallLabelMedium (conditional preserved) |
| TextTemplateImportSheet.swift | 1 | label |

**Task 2: Convert .font(.system()) calls (10 files, 20 refs)** -- NO CHANGES NEEDED

All 20 `.font(.system(size:))` calls across the 10 target files are applied to `Image(systemName:)` SF Symbol icons. Per the plan's exception rule, SF Symbol icon sizing correctly uses `.system()` font and must be preserved. Zero text-rendering system font calls exist.

Files verified with no changes:
- ProfileView.swift (4 refs -- all SF Symbol chevrons and icons)
- TrainingProfileSheet.swift (4 refs -- all SF Symbol chevrons and checkmarks)
- WeeklySummaryCard.swift (2 refs -- SF Symbol chevron and flame)
- DashboardView.swift (1 ref -- SF Symbol chevron)
- ContextSwitcher.swift (1 ref -- SF Symbol arrows)
- TemplateCarouselSection.swift (4 refs -- SF Symbol archive, trash, star, plus)
- UpgradeSheet.swift (1 ref -- SF Symbol checkmark)
- TemplatePickerSheet.swift (1 ref -- SF Symbol sport icon)
- DeltaIndicator.swift (1 ref -- SF Symbol arrow)
- SignUpView.swift (1 ref -- SF Symbol sport icon)

## Verification

1. `grep -rn 'Font.custom("DMSans' WorkloadApp/` returns zero results (excluding FontTokens.swift)
2. All `.font(.system(size:))` calls in target files are confirmed SF Symbol icon sizing
3. SpikeAlertBanner.swift contains `.Tokens.micro`, `.Tokens.smallLabel`, `.Tokens.smallLabelMedium`
4. FatigueAttentionBanner.swift contains `.Tokens.labelMedium`

## Deviations from Plan

None -- plan executed as written. The plan anticipated that some `.system()` calls might be on SF Symbol icons and included the exception rule. All 20 turned out to be icons.

## Self-Check: PASSED

- All 8 modified files exist on disk
- Task 1 commit f923d56 found in git log
- SUMMARY.md created at expected path
