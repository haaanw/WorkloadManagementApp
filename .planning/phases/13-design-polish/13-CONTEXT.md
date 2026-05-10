# Phase 13: Design Polish - Context

**Gathered:** 2026-05-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Migrate all typography from DM Sans to Alpino (Regular + Medium) and replace every rounded-corner text field with a 0pt-corner custom TextFieldStyle. This establishes the correct visual baseline so all subsequent v1.3 phases inherit the right design.

</domain>

<decisions>
## Implementation Decisions

### Font Migration
- **D-01:** Use Alpino-Regular.otf and Alpino-Medium.otf from the `Alpino_Complete/Alpino_Complete/Fonts/OTF/` directory. Source: FontShare (ITF FFL license).
- **D-02:** Direct 1:1 weight mapping — DM Sans Regular → Alpino Regular, DM Sans Medium → Alpino Medium. No other weights used.
- **D-03:** Remove DMSans-Regular.ttf and DMSans-Medium.ttf from `WorkloadApp/Resources/` after adding Alpino files.

### Size Adjustments
- **D-04:** Keep current pt sizes (64/32/19/17/15/12) as starting point. Adjust only where Alpino reads too small on-device.

### TextField Style
- **D-05:** Create a single shared `SharpTextFieldStyle` struct conforming to `TextFieldStyle`. Apply via `.textFieldStyle(SharpTextFieldStyle())` at all 6 affected files (23 occurrences of roundedBorder/RoundedRectangle in text input styling).

### DESIGN.md
- **D-06:** Update DESIGN.md to reference Alpino instead of DM Sans. It stays the live source of truth, not a historical document.

### Claude's Discretion
- Font size fine-tuning — adjust any size that feels too small with Alpino's x-height
- PostScript name verification from the .otf metadata for `Font.custom()` calls
- Whether to keep `Font.Tokens` extension file name as `FontTokens.swift` or rename

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Design System
- `DESIGN.md` — Full design system spec (typography, colors, spacing, layout rules). Must be updated as part of this phase.
- `WorkloadApp/Utilities/FontTokens.swift` — Current Font.Tokens extension (7 sizes, all DM Sans references)

### Font Files
- `Alpino_Complete/Alpino_Complete/Fonts/OTF/Alpino-Regular.otf` — Regular weight source file
- `Alpino_Complete/Alpino_Complete/Fonts/OTF/Alpino-Medium.otf` — Medium weight source file

### Licensing
- FontShare ITF FFL license: https://www.fontshare.com/licenses/itf-ffl

### Affected Files (TextField corners)
- `WorkloadApp/Views/WorkoutLog/ActiveWorkoutSheet.swift` — 11 occurrences
- `WorkloadApp/Views/TemplateEditorSheet.swift` — 8 occurrences
- `WorkloadApp/Views/PrescribeWorkoutSheet.swift` — 1 occurrence
- `WorkloadApp/Views/Recovery/MorningCheckInSheet.swift` — 1 occurrence
- `WorkloadApp/Views/WorkoutLog/FinishWorkoutSheet.swift` — 1 occurrence
- `WorkloadApp/Views/WorkoutLog/ExercisePickerView.swift` — 1 occurrence

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `FontTokens.swift` — Central font token enum. Only file that needs font name changes for all views to update.
- `ColorTokens.swift` — Color system already follows the same token pattern. No changes needed.
- `WorkloadApp.swift` — Has DEBUG assertion validating font names at launch. Must update to validate Alpino names.

### Established Patterns
- All views use `Font.Tokens.*` — no raw `Font.custom()` calls in view files (except PDFReportEngine, scripts)
- Font files registered in Info.plist under `UIAppFonts`
- Resources stored in `WorkloadApp/Resources/`

### Integration Points
- `Info.plist` — UIAppFonts array must swap DM Sans entries for Alpino
- `WorkloadApp.swift` — DEBUG font assertion must validate new Alpino PostScript names
- `.pbxproj` — Must add new .otf files and remove old .ttf files from build

</code_context>

<specifics>
## Specific Ideas

- App name is "Tuwa" — ensure any user-facing strings referencing the app use this name
- Font license is ITF FFL (free for commercial use) — no attribution required in-app but keep license file in repo

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 13-design-polish*
*Context gathered: 2026-05-10*
