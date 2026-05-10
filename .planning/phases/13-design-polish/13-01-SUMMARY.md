---
phase: 13-design-polish
plan: 01
subsystem: typography
tags: [font, design-system, alpino, infrastructure]
dependency_graph:
  requires: []
  provides: [alpino-font-infrastructure, font-tokens-alpino]
  affects: [all-views-using-font-tokens, pdf-report-engine]
tech_stack:
  added: [Alpino-Regular.otf, Alpino-Medium.otf]
  patterns: [centralized-font-tokens]
key_files:
  created:
    - WorkloadApp/Resources/Alpino-Regular.otf
    - WorkloadApp/Resources/Alpino-Medium.otf
  modified:
    - WorkloadApp/Utilities/FontTokens.swift
    - WorkloadApp/App/WorkloadApp.swift
    - WorkloadApp/Services/PDFReportEngine.swift
    - workload management/workload-management-Info.plist
    - workload management/workload management.xcodeproj/project.pbxproj
  deleted:
    - WorkloadApp/Resources/DMSans-Regular.ttf
    - WorkloadApp/Resources/DMSans-Medium.ttf
decisions:
  - Added 3 new font tokens (smallLabel, smallLabelMedium, labelMedium) to support Plan 02 rogue font cleanup
metrics:
  duration: 128s
  completed: "2026-05-10T10:48:09Z"
  tasks_completed: 2
  tasks_total: 2
  files_changed: 7
---

# Phase 13 Plan 01: Alpino Font Infrastructure Migration Summary

Replaced DM Sans with Alpino across all font infrastructure files, establishing Alpino as the single typography source for all views using Font.Tokens.

## One-liner

DM Sans to Alpino font swap across Resources, FontTokens, Info.plist, pbxproj, DEBUG assertions, and PDFReportEngine with 3 new token additions for downstream cleanup.

## Changes Made

### Task 1: Copy Alpino font files and remove DM Sans (6556a86)

- Copied `Alpino-Regular.otf` (45.5 KB) and `Alpino-Medium.otf` (43.1 KB) from Alpino_Complete source to `WorkloadApp/Resources/`
- Removed `DMSans-Regular.ttf` and `DMSans-Medium.ttf` from Resources

### Task 2: Update build config, FontTokens, assertions, and PDFReportEngine (d5eb012)

- **FontTokens.swift**: Replaced all DM Sans PostScript names with Alpino equivalents (7 Alpino-Regular, 5 Alpino-Medium references). Added 3 new tokens: `smallLabel` (13pt Regular), `smallLabelMedium` (13pt Medium), `labelMedium` (15pt Medium) for Plan 02 rogue font cleanup.
- **WorkloadApp.swift**: Updated DEBUG assertions to validate Alpino-Regular and Alpino-Medium load at launch.
- **PDFReportEngine.swift**: Updated UIFont helper methods to use Alpino PostScript names.
- **Info.plist**: Updated UIAppFonts entries from `DMSans-Regular.ttf`/`DMSans-Medium.ttf` to `Alpino-Regular.otf`/`Alpino-Medium.otf`.
- **project.pbxproj**: Updated all 8 references (PBXBuildFile, PBXFileReference, PBXGroup, Resources build phase) from DMSans to Alpino.

## Verification

- Zero `DMSans` references across all modified files (grep confirmed)
- FontTokens.swift contains 7 Alpino-Regular and 5 Alpino-Medium references
- All 3 new tokens (smallLabel, smallLabelMedium, labelMedium) present
- Alpino .otf files exist in Resources (non-zero size)
- DM Sans .ttf files removed from Resources

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED
