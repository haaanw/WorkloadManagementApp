---
phase: 35
plan: 35
type: auto
autonomous: true
subsystem: ui
requirements: []
---

# Phase 35 Plan — UI Wave 4: Corner / font / color hard violations

## Objective
Eliminate the remaining HARD DESIGN.md violations app-wide: rounded text-field corners,
non-token fonts (incl. SF Symbol glyphs sized via `.system(size:)`), hardcoded/system color,
and accent misuse. Goal: regression-gate rules 1–5 all clean.

## Context
- Waves 1–3 done (ladder + section grammar). This wave is the hard-violation sweep.
- Reuse `SharpTextFieldStyle` (Components/) — 0pt square field style — for all `.roundedBorder`.
- Font.Tokens only (FontTokens.swift). Do not amend ColorTokens. Do not touch algorithm/flags.

## Tasks

### Task 1 — CORNER: replace all `.textFieldStyle(.roundedBorder)` with `SharpTextFieldStyle`
- `TemplateEditorSheet.swift` :34, :43 (header fields), :330, :335, :340 (set row fields)
- `PrescribeWorkoutSheet.swift` :95 (notes field)
- Use `.textFieldStyle(SharpTextFieldStyle())`. SharpTextFieldStyle already applies
  `.font(.Tokens.body)` + text1; redundant per-call `.font`/`.foregroundStyle` can stay
  (harmless) but the style governs padding/border/background. Square (Rectangle stroke), 0pt.
- Verify: `feat(35)`.

### Task 2 — FONT real: ShareImportPreviewSheet CTA token consolidation
- `ShareImportPreviewSheet.swift` :137/:138 `.font(.Tokens.body)` + `.fontWeight(.medium)`
  → single `.font(.Tokens.bodyMedium)`, drop the system `.fontWeight`.

### Task 3 — FONT icon glyphs: `.system(size:)` on SF Symbols → Font.Tokens token
Pick a grid-valid token whose size sits near the original, proportional to adjacent text:
- `DeltaIndicator.swift` :17 arrow (was 11, next to `.label`) → `.Tokens.smallLabel`
- `REDSAttentionBanner.swift` :30 xmark (was 13) → `.Tokens.smallLabel`
- `SignUpView.swift` :98 sport icon (was 20, above `.micro`) → `.Tokens.sectionHead` (19)
- `ContextSwitcher.swift` :34 arrows (was 12, next to `.micro`) → `.Tokens.micro`
- `TemplatePickerSheet.swift` :118 sport icon (was 15, above `.body`) → `.Tokens.label`
- `TrainingProfileSheet.swift` :258/:305 chevron.up.chevron.down (was 10) → `.Tokens.micro`
- `TrainingProfileSheet.swift` :341 chevron (was 10) → `.Tokens.micro`
- `TrainingProfileSheet.swift` :373 checkmark (was 14, next to `.body`) → `.Tokens.label`
- Note: `DeltaIndicator:17` not in original task list but matches "fix any other remaining
  `.system(size:` on symbols" directive (Rule 3 gate is strict on `.font(.system(`).

### Task 4 — COLOR: UpgradeSheet purchase-error `.red` → token
- `UpgradeSheet.swift` :151 `.foregroundStyle(.red)` → `ColorTokens.zoneDanger`.

### Task 5 — ACCENT verify (no edit expected)
- Confirmed: only `DashboardView.swift:314` uses `ColorTokens.accent` (hero score).
  ClientDetailView already accent-free. No change.

## Verification
- Build gate: xcodebuild -project, sim id CAF84E71-BB64-491D-87C8-875A0143B26D. MUST be green.
- FULL-app regression gate §5 rules 1–5 across WorkloadApp/ (per-file grep) → all 0.

## Deviations expected
- DeltaIndicator:17 added to glyph sweep (not in original site list) — justified by directive.
- UpgradeSheet single `.red` at :151 (not :146/:151 — copy shifted since audit).
