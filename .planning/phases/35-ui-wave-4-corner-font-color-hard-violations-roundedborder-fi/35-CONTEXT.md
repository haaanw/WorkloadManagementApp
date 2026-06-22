# Phase 35: UI Wave 4 — Corner / font / color hard violations - Context

**Gathered:** 2026-06-02
**Status:** Ready for planning
**Mode:** Auto-generated (discuss skipped; spec locked in INVENTORY.md)

<domain>
## Phase Boundary
Eliminate the remaining HARD DESIGN.md violations: rounded corners, non-token fonts (incl. icon glyphs), hardcoded/system colors, accent misuse. Per INVENTORY.md §2.D/E/F/G + §6 Wave 4. Goal = 0 corner/shadow/hardcoded-color/accent-misuse violations app-wide.

IN SCOPE: the specific violation sites below (from the audit + deferred during Waves 2-3). OUT OF SCOPE: pure off-grid spacing sweep (Wave 5/36), motion (Wave 6/37).
</domain>

<decisions>
## Locked — fix each:
- CORNER: `TemplateEditorSheet` `.textFieldStyle(.roundedBorder)` (INVENTORY §G ~:330/335/340 + header fields) → square custom field style (reuse/extend SharpTextFieldStyle). Also `PrescribeWorkoutSheet:95` `.roundedBorder` (found in Wave 3).
- FONT (real): `ShareImportPreviewSheet:138` `.Tokens.body` + system `.fontWeight(.medium)` → `.Tokens.bodyMedium`.
- FONT (icon glyphs): `.system(size:)` on SF Symbols → Font.Tokens token or `.imageScale`. Sites: SignUpView:98/99, TemplatePickerSheet:118, ContextSwitcher:34, TrainingProfileSheet:258/305/341/373 (and any remaining from §2.D: WeeklySummaryCard already done W1, TemplateCarouselSection already done W2). Off-grid sizes (10/14/20) also fail grid — pick grid-valid scale.
- COLOR: `UpgradeSheet:146/151` `.foregroundStyle(.red)` purchase-error → `ColorTokens.zoneDanger`.
- ACCENT: `ClientDetailView:138` — ALREADY FIXED in Wave 3 (accent→text1). Verify it's clean; do not re-touch unless a hit remains.
- REDSAttentionBanner:30 dismiss-X `.system(size:13)` glyph (pre-existing, flagged W0) → token/imageScale.
- DESIGN.md hard rules; do NOT amend ColorTokens; do NOT touch algorithm/flags.

## Claude's Discretion
The square text-field style implementation (extend SharpTextFieldStyle vs new style). Exact Font.Tokens choice per glyph. Re-run the full §5 regression gate app-wide at the end — rules 1-5 must be CLEAN (rule 1 corners, 2 shadows, 3 fonts, 4 accent, 5 hardcoded color).
</decisions>

<code_context>
## Existing Code Insights
- Spec: INVENTORY.md §2.D (non-token fonts, 14), §2.E (hardcoded color, 1), §2.F (accent, 1 — done), §2.G (corner exception — roundedBorder), §6 Wave 4.
- Deferred-here list accumulated from Waves 2-3 reports: SignUpView:98 sport-icon, UpgradeSheet:151 .red, PrescribeWorkoutSheet:95 .roundedBorder, TrainingProfileSheet:258/305/341/373 glyphs, TemplatePickerSheet:118 glyph.
- SharpTextFieldStyle.swift (Components/) is the square field style to reuse. Font.Tokens in WorkloadApp/Utilities/FontTokens.swift.
</code_context>

<specifics>
## Specifics
Build gate: xcodebuild sim id iPhone 17 Pro `CAF84E71-BB64-491D-87C8-875A0143B26D` via -project. Incremental build every 3-5 files. End with FULL-app §5 regression gate (rules 1-5 must be 0). SERIAL. SourceKit phantom diagnostics expected — trust xcodebuild. rtk mangles multi-file rg — per-file grep.
</specifics>

<deferred>
## Deferred
Residual off-grid spacing (incl. icon-glyph off-grid sizes if any remain, PRCelebrationOverlay/ImportRPESheet) = Wave 5 (36). SetEntryRow placeholder i18n = future. Motion = Wave 6 (37).
</deferred>
