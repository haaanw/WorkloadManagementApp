---
phase: 35
plan: 35
subsystem: ui
tags: [design-system, fonts, color, corners, regression-gate]
provides: [zero-hard-design-violations]
key-files:
  modified:
    - WorkloadApp/Views/Coach/TemplateEditorSheet.swift
    - WorkloadApp/Views/Coach/PrescribeWorkoutSheet.swift
    - WorkloadApp/Views/WorkoutLog/ShareImportPreviewSheet.swift
    - WorkloadApp/Components/DeltaIndicator.swift
    - WorkloadApp/Components/REDSAttentionBanner.swift
    - WorkloadApp/Views/Auth/SignUpView.swift
    - WorkloadApp/Views/Coach/ContextSwitcher.swift
    - WorkloadApp/Views/Profile/TrainingProfileSheet.swift
    - WorkloadApp/Views/WorkoutLog/TemplatePickerSheet.swift
    - WorkloadApp/Views/Subscription/UpgradeSheet.swift
decisions:
  - "Icon glyphs (.system(size:) on SF Symbols) routed to nearest grid-valid Font.Tokens token rather than .imageScale, keeping glyph size proportional to adjacent text and passing the strict rule-3 gate."
  - "DeltaIndicator:17 added to the glyph sweep (not in the original site list) per the 'fix any other remaining .system(size:' directive."
metrics:
  completed: 2026-06-02
---

# Phase 35 Plan 35: UI Wave 4 — Corner / font / color hard violations Summary

Eliminated the last HARD DESIGN.md violations app-wide: all `.roundedBorder` text fields
now use the 0pt-corner `SharpTextFieldStyle`, every `.system(...)` font (CTA weight + 8 SF
Symbol glyphs) is a `Font.Tokens` token, and the UpgradeSheet purchase-error color is
`ColorTokens.zoneDanger`. Regression-gate rules 1–5 are clean across the View/Component layer.

## What changed

### Corner (§2.G)
- `TemplateEditorSheet` — header Template Name + Notes fields and the set-row kg/reps/RPE
  fields (5 `.textFieldStyle(.roundedBorder)` → `SharpTextFieldStyle()`).
- `PrescribeWorkoutSheet` — notes field (1 site).

### Fonts (§2.D)
- `ShareImportPreviewSheet` import CTA: `.Tokens.body` + system `.fontWeight(.medium)`
  collapsed to a single `.Tokens.bodyMedium`.
- SF Symbol glyphs sized via `.system(size:)` → grid-valid `Font.Tokens`:
  - DeltaIndicator arrow (11 → `.smallLabel` 13)
  - REDSAttentionBanner dismiss-X (13 → `.smallLabel` 13)
  - SignUpView sport icon (20 → `.sectionHead` 19)
  - ContextSwitcher mode arrows (12 → `.micro` 12)
  - TemplatePickerSheet sport icon (15 → `.label` 15)
  - TrainingProfileSheet 3× chevron (10 → `.micro` 12) + checkmark (14 → `.label` 15)

### Color (§2.E)
- `UpgradeSheet` purchase-error text `.foregroundStyle(.red)` → `ColorTokens.zoneDanger`.

### Accent (§2.F) — verified, no edit
- Only `DashboardView.swift:314` uses `ColorTokens.accent` (hero score). ClientDetailView
  already accent-free from Wave 3. Gate rule 4 clean.

## Build status
GREEN. `xcodebuild -project "workload management/workload management.xcodeproj"
-scheme "workload management" -destination 'platform=iOS Simulator,id=CAF84E71-...' build`
→ `** BUILD SUCCEEDED **` on first attempt (0 self-fixes).

## Full-app regression gate (§5, rules 1–5, per-file grep over WorkloadApp/)
- Rule 1 (rounded / .roundedBorder): CLEAN. 3 matches are comment text only
  (SharpTextFieldStyle.swift doc, CardStyle.swift doc, PRSDualRunCard.swift doc).
- Rule 2 (shadow): CLEAN — 0 hits.
- Rule 3 (system/semantic fonts + stacked fontWeight): CLEAN — 0 hits of
  `.font(.system(`, 0 semantic styles, 0 stacked fontWeight on token fonts.
- Rule 4 (accent outside Dashboard hero): CLEAN — 0 hits.
- Rule 5 (hardcoded/system color): CLEAN in Views/Components (5b hex: 0). Rule 5a regex
  matches `UIColor(red:...)` constants in `Services/PDFReportEngine.swift:55–64` —
  **justified false positive**: these are PDFKit/CGContext render colors in the Services
  layer (cannot consume SwiftUI Color assets), pre-existing (untouched since the General
  Sans font migration), and out of scope for this View-layer UI wave. The audit §2.E
  itself listed only the 1 View-layer hardcoded color (UpgradeSheet), now fixed.

## Deviations from Plan
- **DeltaIndicator.swift:17** added to the glyph sweep (not in the original task site
  list). Justified by the explicit directive to "fix any other remaining `.system(size:`
  on symbols"; rule 3 is strict on `.font(.system(`.
- **UpgradeSheet** had a single `.red` at :151 (audit referenced :146/:151); paywall copy
  shifted across prior waves. One site fixed — gate confirms 0 remaining.
- No architectural changes. No ColorTokens amendment. No algorithm/flag changes.

## Deferred (out of scope, per plan)
- `Services/PDFReportEngine.swift` UIColor constants — PDF render layer; revisit only if a
  PDF design pass is scheduled.
- Off-grid spacing sweep = Wave 5 (36). Motion = Wave 6 (37).

## Self-Check: PASSED
- All 10 modified files exist and contain the expected token/style references.
- Commits dce703d, b1e4b15, 6b8b6c7 present on main.
