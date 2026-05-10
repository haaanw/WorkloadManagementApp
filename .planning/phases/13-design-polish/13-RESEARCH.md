# Phase 13: Design Polish - Research

**Researched:** 2026-05-10
**Domain:** iOS typography migration (font swap) + custom TextFieldStyle
**Confidence:** HIGH

## Summary

Phase 13 is a surgical visual migration: swap DM Sans for Alpino across all typography, and replace every `.roundedBorder` text field style with a custom 0pt-corner `SharpTextFieldStyle`. The codebase is well-architected for this change -- `Font.Tokens` centralizes font definitions, so the core swap is a 7-line edit in `FontTokens.swift`. However, research uncovered **20 rogue `.font(.system(...))` calls across 10 files** and **20 raw `Font.custom("DMSans-*")` calls across 8 files** (outside FontTokens.swift) that bypass the token system and must also be migrated.

The Alpino font PostScript names have been verified from the .otf metadata: `Alpino-Regular` and `Alpino-Medium`. These are direct drop-in replacements for `DMSans-Regular` and `DMSans-Medium` in `Font.custom()` calls. The `.roundedBorder` replacement is straightforward -- 23 occurrences across 6 files, no `RoundedRectangle` usage exists anywhere in the codebase.

**Primary recommendation:** Execute in three waves: (1) font infrastructure (files, plist, pbxproj, FontTokens.swift, assertions), (2) fix all rogue font references (system fonts + raw Font.custom calls), (3) create and apply SharpTextFieldStyle + update DESIGN.md.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Use Alpino-Regular.otf and Alpino-Medium.otf from the `Alpino_Complete/Alpino_Complete/Fonts/OTF/` directory. Source: FontShare (ITF FFL license).
- **D-02:** Direct 1:1 weight mapping -- DM Sans Regular -> Alpino Regular, DM Sans Medium -> Alpino Medium. No other weights used.
- **D-03:** Remove DMSans-Regular.ttf and DMSans-Medium.ttf from `WorkloadApp/Resources/` after adding Alpino files.
- **D-04:** Keep current pt sizes (64/32/19/17/15/12) as starting point. Adjust only where Alpino reads too small on-device.
- **D-05:** Create a single shared `SharpTextFieldStyle` struct conforming to `TextFieldStyle`. Apply via `.textFieldStyle(SharpTextFieldStyle())` at all 6 affected files (23 occurrences).
- **D-06:** Update DESIGN.md to reference Alpino instead of DM Sans.

### Claude's Discretion
- Font size fine-tuning -- adjust any size that feels too small with Alpino's x-height
- PostScript name verification from the .otf metadata for `Font.custom()` calls
- Whether to keep `Font.Tokens` extension file name as `FontTokens.swift` or rename

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DESGN-01 | App uses Alpino font (Regular + Medium) from FontShare instead of DM Sans across all views | PostScript names verified (`Alpino-Regular`, `Alpino-Medium`). Full inventory of all font references compiled: 7 in FontTokens.swift (central), 20 raw Font.custom("DMSans-*") in 8 other files, 20 `.font(.system())` in 10 files, 2 UIFont references in PDFReportEngine, 2 UIFont assertions in WorkloadApp.swift. |
| DESGN-02 | All `.roundedBorder` text field styles replaced with 0pt corner custom style per design system | 23 occurrences across 6 files confirmed. Zero `RoundedRectangle` instances found. SharpTextFieldStyle spec defined in UI-SPEC.md. |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Font file bundling | Build / Xcode project | -- | .otf files added to Resources, registered in Info.plist, referenced in pbxproj |
| Font token definitions | Utility layer (FontTokens.swift) | -- | Single source of truth for all font references |
| Rogue font cleanup | View layer + Components | Services (PDFReportEngine) | Direct Font.custom/system calls scattered across views must route through tokens |
| TextFieldStyle | Components layer | -- | New SharpTextFieldStyle.swift, applied at view layer call sites |
| Design doc update | Documentation | -- | DESIGN.md is the design system source of truth |

## Standard Stack

No new libraries or dependencies. This phase is purely internal code changes.

### Core
| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| Alpino-Regular.otf | FontShare release | Body text, labels, hero score | Locked decision D-01 |
| Alpino-Medium.otf | FontShare release | Section headers, active states | Locked decision D-01 |
| SwiftUI TextFieldStyle | iOS 17+ | Custom text field appearance | Native protocol, zero dependencies |

## Architecture Patterns

### Pattern 1: Centralized Font Tokens

**What:** All font references flow through `Font.Tokens` enum extension -- a single file controls every text style in the app.

**When to use:** Always. No view file should contain raw `Font.custom()` or `.font(.system())` calls.

**Current state (verified):**
```swift
// FontTokens.swift -- the ONLY place Font.custom() should appear
extension Font {
    enum Tokens {
        static let heroScore   = Font.custom("Alpino-Regular", size: 64)  // was DMSans-Regular
        static let pageTitle   = Font.custom("Alpino-Regular", size: 32)
        static let sectionHead = Font.custom("Alpino-Medium",  size: 19)
        static let body        = Font.custom("Alpino-Regular", size: 17)
        static let bodyMedium  = Font.custom("Alpino-Medium",  size: 17)
        static let label       = Font.custom("Alpino-Regular", size: 15)
        static let micro       = Font.custom("Alpino-Regular", size: 12)
    }
}
```
[VERIFIED: codebase grep -- FontTokens.swift is the only file with Font.Tokens definitions]

### Pattern 2: Custom TextFieldStyle

**What:** SwiftUI `TextFieldStyle` protocol conformance with `makeBody(configuration:)`.

**Example:**
```swift
// Source: Apple SwiftUI documentation
struct SharpTextFieldStyle: TextFieldStyle {
    @FocusState private var isFocused: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .font(.Tokens.body)
            .foregroundStyle(ColorTokens.text1)
            .background(ColorTokens.surface)
            .overlay(
                Rectangle()
                    .stroke(isFocused ? ColorTokens.text2 : ColorTokens.divider, lineWidth: 0.5)
            )
            .focused($isFocused)
            .animation(.linear(duration: 0.15), value: isFocused)
    }
}
```
[ASSUMED: @FocusState inside TextFieldStyle -- needs build verification. May require passing focus binding from outside if TextFieldStyle doesn't support @FocusState internally.]

### Pattern 3: UIFont for Non-SwiftUI Contexts

**What:** `PDFReportEngine.swift` uses `UIFont(name:size:)` for Core Graphics PDF rendering. These must also reference Alpino PostScript names.

```swift
// PDFReportEngine.swift -- UIFont context (not SwiftUI)
UIFont(name: "Alpino-Regular", size: size) ?? .systemFont(ofSize: size)
UIFont(name: "Alpino-Medium", size: size) ?? .systemFont(ofSize: size, weight: .medium)
```
[VERIFIED: codebase grep -- 2 UIFont references in PDFReportEngine.swift]

### Anti-Patterns to Avoid
- **Raw Font.custom() in view files:** Route through Font.Tokens. The 20 existing raw calls are technical debt being cleaned up in this phase.
- **System font fallback in production:** `.font(.system(size:))` bypasses the design system entirely. All 20 instances must be converted to Font.Tokens references.
- **Hardcoded PostScript names in multiple files:** Only FontTokens.swift and PDFReportEngine.swift should contain font name strings.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Text field styling | Custom overlay per-file | `TextFieldStyle` protocol | SwiftUI's built-in protocol ensures consistent application and single-point updates |
| Font management | Per-file Font.custom() calls | Font.Tokens enum | Centralized control -- font swap requires editing 1 file instead of 30+ |

## Common Pitfalls

### Pitfall 1: PostScript Name Mismatch
**What goes wrong:** `Font.custom("Alpino Regular", size:)` silently falls back to system font if the PostScript name doesn't match exactly.
**Why it happens:** PostScript names don't always match filename. Spaces, hyphens, and casing vary.
**How to avoid:** PostScript names verified: `Alpino-Regular` and `Alpino-Medium` (hyphenated, no spaces). [VERIFIED: otf metadata extraction via fc-scan]
**Warning signs:** The DEBUG assertion in WorkloadApp.swift catches this at launch.

### Pitfall 2: Forgotten System Font References
**What goes wrong:** After migration, some screens still render in San Francisco (system font) instead of Alpino.
**Why it happens:** `.font(.system(size:))` calls don't go through Font.Tokens and are invisible to a simple "DMSans" search.
**How to avoid:** Full inventory compiled below. All 20 `.system()` calls across 10 files must be replaced.
**Warning signs:** Visual inconsistency on screens that use system fonts.

### Pitfall 3: pbxproj Corruption
**What goes wrong:** Adding/removing font files from the Xcode project file breaks the build.
**Why it happens:** The `.pbxproj` file uses unique UUIDs for each file reference. Manual editing can create orphan references.
**How to avoid:** Use Xcode's "Add Files to Project" and "Remove Reference" operations, or carefully update the 4 pbxproj sections (PBXBuildFile, PBXFileReference, PBXGroup children, Resources build phase).
**Warning signs:** Build errors mentioning missing file references.

### Pitfall 4: @FocusState in TextFieldStyle
**What goes wrong:** `@FocusState` may not work inside a `TextFieldStyle` struct's `makeBody` method because the style struct is recreated on each render.
**Why it happens:** SwiftUI property wrappers like `@FocusState` need stable identity.
**How to avoid:** Test the focused border behavior. If `@FocusState` doesn't work inside `TextFieldStyle`, use a simpler approach: always show `ColorTokens.divider` border (no focus state differentiation), or wrap the configuration in a helper View that owns the @FocusState.
**Warning signs:** Focus border never changes color when tapping into a text field.

### Pitfall 5: Missing Font.Tokens for Rogue Sizes
**What goes wrong:** Some rogue references use non-standard sizes (9pt, 10pt, 11pt, 14pt, 24pt) that don't have Font.Tokens equivalents.
**Why it happens:** Developers added one-off font sizes outside the design system.
**How to avoid:** Map each rogue size to the nearest token, or add new tokens if a size is genuinely needed. See inventory below.
**Warning signs:** N/A -- must be decided during implementation.

## Code Examples

### Complete Font Reference Inventory

**Central token file (7 references -- change font name only):**

| File | Current | Action |
|------|---------|--------|
| `WorkloadApp/Utilities/FontTokens.swift` | 7x `Font.custom("DMSans-*")` | Change to `Alpino-Regular` / `Alpino-Medium` |

**Raw Font.custom("DMSans-*") calls outside tokens (20 references -- convert to tokens):**

| File | Count | Sizes Used | Recommended Token |
|------|-------|------------|-------------------|
| `Components/SpikeAlertBanner.swift` | 6 | 11pt(M), 13pt(R), 13pt(M), 11pt(R) | micro, label (or new 13pt token) |
| `Components/FatigueAttentionBanner.swift` | 3 | 11pt(M), 15pt(M), 13pt(R) | micro, label, label |
| `Components/ToastBanner.swift` | 1 | 13pt(R) | label (or micro bumped) |
| `Components/StalenessWarningBadge.swift` | 1 | 11pt(R) | micro (adjust from 12pt?) |
| `Views/Profile/InviteConfirmationSheet.swift` | 6 | 15pt(R), 11pt(M), 28pt(M), 13pt(R) | label, micro, pageTitle(but Medium?), label |
| `Views/Subscription/UpgradeSheet.swift` | 1 | 9pt(M) | Needs new token or use micro |
| `Views/WorkoutLog/WorkoutLogView.swift` | 1 | 13pt(R/M conditional) | label or new 13pt token |
| `Views/WorkoutLog/TextTemplateImportSheet.swift` | 1 | 14pt(R) | label (15pt) |

**System font calls (20 references -- convert to tokens):**

| File | Count | Sizes Used | Recommended Token |
|------|-------|------------|-------------------|
| `Views/Profile/ProfileView.swift` | 4 | 12pt, 10pt, 14pt | micro, micro, label |
| `Views/Profile/TrainingProfileSheet.swift` | 4 | 10pt, 14pt | micro, label |
| `Views/Dashboard/WeeklySummaryCard.swift` | 2 | 12pt, 13pt | micro, label |
| `Views/Dashboard/DashboardView.swift` | 1 | 12pt(medium) | micro or new sectionMicro |
| `Views/Coach/ContextSwitcher.swift` | 1 | 12pt | micro |
| `Views/WorkoutLog/TemplateCarouselSection.swift` | 4 | 17pt, 15pt, 24pt | body, label, new token or pageTitle |
| `Views/Subscription/UpgradeSheet.swift` | 1 | 11pt(medium) | micro |
| `Views/WorkoutLog/TemplatePickerSheet.swift` | 1 | 15pt | label |
| `Components/DeltaIndicator.swift` | 1 | 11pt(medium) | micro |
| `Views/Auth/SignUpView.swift` | 1 | 20pt | sectionHead (19pt) or new |

**UIFont references (non-SwiftUI context, 2 references -- change font name):**

| File | Count | Action |
|------|-------|--------|
| `Services/PDFReportEngine.swift` | 2 | Change `DMSans-Regular` -> `Alpino-Regular`, `DMSans-Medium` -> `Alpino-Medium` |

**DEBUG assertions (2 references -- change font name):**

| File | Count | Action |
|------|-------|--------|
| `App/WorkloadApp.swift` | 2 | Change assertion to validate `Alpino-Regular` and `Alpino-Medium` |

**Build configuration:**

| File | Change |
|------|--------|
| `workload management/workload-management-Info.plist` | UIAppFonts: replace `DMSans-Regular.ttf`, `DMSans-Medium.ttf` with `Alpino-Regular.otf`, `Alpino-Medium.otf` |
| `workload management/workload management.xcodeproj/project.pbxproj` | Remove DMSans file refs (4 entries), add Alpino file refs (4 entries) |
| `WorkloadApp/Resources/` | Remove DMSans .ttf files, add Alpino .otf files |

### Non-Standard Sizes Requiring Decision

Several rogue references use sizes not in the current Font.Tokens scale (64/32/19/17/15/12):

| Size | Weight | Where | Suggested Resolution |
|------|--------|-------|---------------------|
| 9pt | Medium | UpgradeSheet | Map to micro (12pt) -- 9pt is too small |
| 10pt | System | ProfileView, TrainingProfileSheet | Map to micro (12pt) |
| 11pt | Regular/Medium | Multiple components | Map to micro (12pt) |
| 13pt | Regular/Medium | Multiple components | Map to label (15pt) or add new 13pt token |
| 14pt | Regular/System | TextTemplateImportSheet, ProfileView, TrainingProfileSheet | Map to label (15pt) |
| 20pt | System | SignUpView | Map to sectionHead (19pt) |
| 24pt | System | TemplateCarouselSection | Map to pageTitle (32pt) or add new token |
| 28pt | Medium | InviteConfirmationSheet | pageTitle is 32pt Regular -- may need new `pageTitleMedium` or adjust |

**Recommendation:** Add a `smallLabel` token at 13pt if the size distinction from 15pt is visually meaningful. Map 9/10/11pt to micro (12pt). Map 14pt to label (15pt). Map 20pt to sectionHead (19pt). Handle 24pt and 28pt Medium case-by-case. [ASSUMED: size mapping decisions -- executor should verify visual impact]

### SharpTextFieldStyle Replacement

```swift
// Before (23 occurrences across 6 files):
TextField("Weight", text: $weight)
    .textFieldStyle(.roundedBorder)

// After:
TextField("Weight", text: $weight)
    .textFieldStyle(SharpTextFieldStyle())
```

### DESIGN.md Updates

```markdown
// Typography section changes:
- **Typeface:** Alpino -- geometric, neutral, precise. Sharp terminals,
  excellent numerics. Bundle as `.otf` from FontShare (ITF FFL license).
- **Font Loading:** Bundle `Alpino-Regular.otf` and `Alpino-Medium.otf`.
  Reference in SwiftUI: `Font.custom("Alpino-Regular", size: 15)`.

// Implementation Rules #8:
- Typography uses `Font.custom("Alpino-Regular", size:)` and
  `Font.custom("Alpino-Medium", size:)` for all text.

// Decisions Log new row:
| 2026-05-10 | Migrated from DM Sans to Alpino | Geometric sans with sharper terminals -- aligns with International Style direction |
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| DM Sans (Google Fonts) | Alpino (FontShare) | Phase 13 | All typography renders in Alpino |
| `.textFieldStyle(.roundedBorder)` | `.textFieldStyle(SharpTextFieldStyle())` | Phase 13 | 0pt corners on all text inputs |
| Scattered Font.custom/system calls | All through Font.Tokens | Phase 13 | Single source of truth for typography |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | @FocusState works inside TextFieldStyle struct | Pitfall 4 | Focus border animation won't work; need alternative approach (minor visual-only impact) |
| A2 | Size mapping (9/10/11pt -> micro, 14pt -> label, etc.) is visually acceptable | Non-Standard Sizes | Some text may appear too large or small; requires on-device verification |
| A3 | Alpino x-height is similar enough to DM Sans that current pt sizes work without adjustment | D-04 | Text may render noticeably smaller; per D-04, sizes can be bumped 1pt if needed |

## Open Questions

1. **Should a `smallLabel` (13pt) token be added to Font.Tokens?**
   - What we know: 13pt is used in 6+ places across components (SpikeAlertBanner, FatigueAttentionBanner, ToastBanner, InviteConfirmationSheet). Current tokens jump from micro (12pt) to label (15pt).
   - What's unclear: Whether the 13pt vs 15pt distinction is visually meaningful with Alpino's metrics.
   - Recommendation: Add it if 3+ call sites genuinely need a size between micro and label. Otherwise map to label.

2. **24pt font size in TemplateCarouselSection -- what token?**
   - What we know: Used for SF Symbol icons (`.font(.system(size: 24))`), not text.
   - What's unclear: Whether icon sizing should go through Font.Tokens at all.
   - Recommendation: Keep as `.font(.system(size: 24))` for SF Symbols only (system font is correct for symbols). Only Alpino replaces text rendering.

## Project Constraints (from CLAUDE.md)

- **0pt border radius everywhere** -- `Rectangle()`, never `RoundedRectangle`
- **No shadows** -- remove any `.shadow()` modifiers
- **DM Sans Regular + Medium only** (being replaced by Alpino Regular + Medium)
- **All spacing multiples of 8pt**
- **Font.custom() only, never .system() or semantic styles** -- this phase enforces this rule by cleaning up violations
- **Both dark and light mode via ColorTokens**
- **After generating/modifying Swift files, verify pbxproj includes all new source files**
- **Incremental build verification every 3-5 files**

## Sources

### Primary (HIGH confidence)
- Codebase grep: Full inventory of all font references (Font.custom, .system, UIFont) across WorkloadApp/
- Font metadata: PostScript names extracted via `fc-scan` from .otf files
- `13-CONTEXT.md`: Locked decisions D-01 through D-06
- `13-UI-SPEC.md`: SharpTextFieldStyle visual spec and validation criteria
- `DESIGN.md`: Current design system specification

### Secondary (MEDIUM confidence)
- Apple SwiftUI TextFieldStyle protocol documentation [ASSUMED: protocol shape based on training data]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- no new dependencies, verified font files exist with correct PostScript names
- Architecture: HIGH -- centralized token system already exists, just needs name swap + rogue cleanup
- Pitfalls: HIGH -- full inventory compiled via codebase search, @FocusState caveat flagged

**Research date:** 2026-05-10
**Valid until:** 2026-06-10 (stable -- no external dependency changes expected)
