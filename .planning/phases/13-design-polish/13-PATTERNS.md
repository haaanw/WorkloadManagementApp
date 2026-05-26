# Phase 13: Design Polish - Pattern Map

**Mapped:** 2026-05-10
**Files analyzed:** 25 (1 new, 24 modified)
**Analogs found:** 24 / 25

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `WorkloadApp/Components/SharpTextFieldStyle.swift` | component | transform | `WorkloadApp/Utilities/ColorTokens.swift` | role-match |
| `WorkloadApp/Utilities/FontTokens.swift` | utility | config | self (modify in place) | exact |
| `WorkloadApp/App/WorkloadApp.swift` | config | config | self (modify in place) | exact |
| `WorkloadApp/Services/PDFReportEngine.swift` | service | transform | self (modify in place) | exact |
| `workload management/workload-management-Info.plist` | config | config | self (modify in place) | exact |
| `DESIGN.md` | documentation | N/A | self (modify in place) | exact |
| `WorkloadApp/Components/SpikeAlertBanner.swift` | component | request-response | self (rogue font fix) | exact |
| `WorkloadApp/Components/FatigueAttentionBanner.swift` | component | request-response | self (rogue font fix) | exact |
| `WorkloadApp/Components/ToastBanner.swift` | component | request-response | self (rogue font fix) | exact |
| `WorkloadApp/Components/StalenessWarningBadge.swift` | component | request-response | `SpikeAlertBanner.swift` | exact |
| `WorkloadApp/Components/DeltaIndicator.swift` | component | request-response | `SpikeAlertBanner.swift` | exact |
| `WorkloadApp/Views/Profile/InviteConfirmationSheet.swift` | component | request-response | self (rogue font fix) | exact |
| `WorkloadApp/Views/Subscription/UpgradeSheet.swift` | component | request-response | self (rogue font fix) | exact |
| `WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift` | component | request-response | self (rogue font fix) | exact |
| `WorkloadApp/Views/WorkoutLog/TextTemplateImportSheet.swift` | component | request-response | self (rogue font fix) | exact |
| `WorkloadApp/Views/Profile/ProfileView.swift` | component | request-response | self (system font fix) | exact |
| `WorkloadApp/Views/Profile/TrainingProfileSheet.swift` | component | request-response | self (system font fix) | exact |
| `WorkloadApp/Views/Dashboard/WeeklySummaryCard.swift` | component | request-response | self (system font fix) | exact |
| `WorkloadApp/Views/Dashboard/DashboardView.swift` | component | request-response | self (system font fix) | exact |
| `WorkloadApp/Views/Coach/ContextSwitcher.swift` | component | request-response | self (system font fix) | exact |
| `WorkloadApp/Views/WorkoutLog/TemplateCarouselSection.swift` | component | request-response | self (system font fix) | exact |
| `WorkloadApp/Views/WorkoutLog/TemplatePickerSheet.swift` | component | request-response | self (system font fix) | exact |
| `WorkloadApp/Views/Auth/SignUpView.swift` | component | request-response | self (system font fix) | exact |
| `WorkloadApp/Views/WorkoutLog/ActiveWorkoutSheet.swift` | component | request-response | self (textfield style fix) | exact |
| `WorkloadApp/Views/TemplateEditorSheet.swift` | component | request-response | self (textfield style fix) | exact |
| `WorkloadApp/Views/PrescribeWorkoutSheet.swift` | component | request-response | self (textfield style fix) | exact |
| `WorkloadApp/Views/Recovery/MorningCheckInSheet.swift` | component | request-response | self (textfield style fix) | exact |
| `WorkloadApp/Views/WorkoutLog/FinishWorkoutSheet.swift` | component | request-response | self (textfield style fix) | exact |
| `WorkloadApp/Views/WorkoutLog/ExercisePickerView.swift` | component | request-response | self (textfield style fix) | exact |

## Pattern Assignments

### `WorkloadApp/Components/SharpTextFieldStyle.swift` (NEW -- component, transform)

**Analog:** `WorkloadApp/Utilities/ColorTokens.swift` (same token/utility pattern)

**Imports pattern** (ColorTokens.swift line 1):
```swift
import SwiftUI
```

**Core pattern** -- TextFieldStyle conformance (from RESEARCH.md, verified against Apple API):
```swift
struct SharpTextFieldStyle: TextFieldStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .font(.Tokens.body)
            .foregroundStyle(ColorTokens.text1)
            .background(ColorTokens.surface)
            .overlay(
                Rectangle()
                    .stroke(ColorTokens.divider, lineWidth: 0.5)
            )
    }
}
```

**Design system compliance pattern** -- matches card styling from SpikeAlertBanner (lines 70-74):
```swift
.background(ColorTokens.surface)
.overlay(
    Rectangle()
        .stroke(ColorTokens.divider, lineWidth: 0.5)
)
```

---

### `WorkloadApp/Utilities/FontTokens.swift` (MODIFY -- utility, config)

**Analog:** Self -- modify in place

**Current pattern** (lines 11-32):
```swift
extension Font {
    enum Tokens {
        static let heroScore   = Font.custom("DMSans-Regular", size: 64)
        static let pageTitle   = Font.custom("DMSans-Regular", size: 32)
        static let sectionHead = Font.custom("DMSans-Medium",  size: 19)
        static let body        = Font.custom("DMSans-Regular", size: 17)
        static let bodyMedium  = Font.custom("DMSans-Medium",  size: 17)
        static let label       = Font.custom("DMSans-Regular", size: 15)
        static let micro       = Font.custom("DMSans-Regular", size: 12)
    }
}
```

**Required change:** Replace all `"DMSans-Regular"` with `"Alpino-Regular"` and `"DMSans-Medium"` with `"Alpino-Medium"`. Update doc comment (line 3) from "DM Sans" to "Alpino". Consider adding `smallLabel` token at 13pt if needed for rogue font migration.

---

### `WorkloadApp/App/WorkloadApp.swift` (MODIFY -- config)

**Analog:** Self -- modify in place

**Current assertion pattern** (lines 11-18):
```swift
#if DEBUG
assert(
    UIFont(name: "DMSans-Regular", size: 15) != nil,
    "DMSans-Regular font not found. Add DMSans-Regular.ttf to the project and UIAppFonts in Info.plist."
)
assert(
    UIFont(name: "DMSans-Medium", size: 15) != nil,
    "DMSans-Medium font not found. Add DMSans-Medium.ttf to the project and UIAppFonts in Info.plist."
)
#endif
```

**Required change:** Replace `"DMSans-Regular"` with `"Alpino-Regular"`, `"DMSans-Medium"` with `"Alpino-Medium"`, and update error messages to reference `.otf` files.

---

### `WorkloadApp/Services/PDFReportEngine.swift` (MODIFY -- service)

**Analog:** Self -- modify in place

**Current UIFont pattern** (lines 68-74):
```swift
private static func fontRegular(_ size: CGFloat) -> UIFont {
    UIFont(name: "DMSans-Regular", size: size) ?? .systemFont(ofSize: size)
}

private static func fontMedium(_ size: CGFloat) -> UIFont {
    UIFont(name: "DMSans-Medium", size: size) ?? .systemFont(ofSize: size, weight: .medium)
}
```

**Required change:** Replace `"DMSans-Regular"` with `"Alpino-Regular"` and `"DMSans-Medium"` with `"Alpino-Medium"`.

---

### Rogue Font.custom("DMSans-*") Files (8 files, 20 references)

**Analog for conversion pattern:** `WorkloadApp/Components/SpikeAlertBanner.swift`

**Before pattern** (SpikeAlertBanner line 32):
```swift
.font(.custom("DMSans-Medium", size: 11))
```

**After pattern** -- convert to Font.Tokens:
```swift
.font(.Tokens.micro)
```

**Size mapping table for conversion:**

| Raw Size | Weight | Token Replacement |
|----------|--------|-------------------|
| 9pt | Medium | `.Tokens.micro` (12pt) |
| 11pt | Regular/Medium | `.Tokens.micro` (12pt) |
| 13pt | Regular | `.Tokens.smallLabel` (new 13pt token) or `.Tokens.label` (15pt) |
| 13pt | Medium | `.Tokens.smallLabel` + adjust or add `smallLabelMedium` |
| 15pt | Medium | `.Tokens.bodyMedium` (17pt) or new `labelMedium` (15pt) |
| 28pt | Medium | `.Tokens.pageTitle` (32pt) or new token |

**Files affected:**
- `Components/SpikeAlertBanner.swift` -- 6 refs (11pt M, 13pt R, 13pt M, 11pt R)
- `Components/FatigueAttentionBanner.swift` -- 3 refs (11pt M, 15pt M, 13pt R)
- `Components/ToastBanner.swift` -- 1 ref (13pt R)
- `Components/StalenessWarningBadge.swift` -- 1 ref (11pt R)
- `Views/Profile/InviteConfirmationSheet.swift` -- 6 refs (15pt R, 11pt M, 28pt M, 13pt R)
- `Views/Subscription/UpgradeSheet.swift` -- 1 ref (9pt M)
- `Views/WorkoutLog/WorkoutLogView.swift` -- 1 ref (13pt R/M conditional)
- `Views/WorkoutLog/TextTemplateImportSheet.swift` -- 1 ref (14pt R)

---

### System Font Files (10 files, 20 references)

**Analog for conversion:** Same Font.Tokens pattern as rogue fonts above.

**Before pattern** (TemplateCarouselSection line 171):
```swift
.font(.system(size: 17))
```

**After pattern:**
```swift
.font(.Tokens.body)
```

**Exception:** SF Symbol icon sizing (e.g., `.font(.system(size: 24))` for icons) should remain as `.system(size:)` since system font is correct for SF Symbols. Only text rendering uses Alpino.

**Files affected:**
- `Views/Profile/ProfileView.swift` -- 4 refs (12pt, 10pt, 14pt)
- `Views/Profile/TrainingProfileSheet.swift` -- 4 refs (10pt, 14pt)
- `Views/Dashboard/WeeklySummaryCard.swift` -- 2 refs (12pt, 13pt)
- `Views/Dashboard/DashboardView.swift` -- 1 ref (12pt medium)
- `Views/Coach/ContextSwitcher.swift` -- 1 ref (12pt)
- `Views/WorkoutLog/TemplateCarouselSection.swift` -- 4 refs (17pt, 15pt, 24pt icon)
- `Views/Subscription/UpgradeSheet.swift` -- 1 ref (11pt medium)
- `Views/WorkoutLog/TemplatePickerSheet.swift` -- 1 ref (15pt)
- `Components/DeltaIndicator.swift` -- 1 ref (11pt medium)
- `Views/Auth/SignUpView.swift` -- 1 ref (20pt)

---

### TextField Style Replacement (6 files, 23 references)

**Analog:** `WorkloadApp/Views/WorkoutLog/ActiveWorkoutSheet.swift` (highest occurrence count)

**Before pattern** (ActiveWorkoutSheet line 50):
```swift
TextField("Session Name (optional)", text: $sessionName)
    .font(.Tokens.body)
    .foregroundStyle(ColorTokens.text1)
    .textFieldStyle(.roundedBorder)
```

**After pattern:**
```swift
TextField("Session Name (optional)", text: $sessionName)
    .textFieldStyle(SharpTextFieldStyle())
```

Note: SharpTextFieldStyle internally applies `.font(.Tokens.body)`, `.foregroundStyle(ColorTokens.text1)`, and `.background(ColorTokens.surface)` -- so individual `.font()` and `.foregroundStyle()` modifiers on TextField can be removed if they match the style defaults. Review each call site.

**Files and counts:**
- `Views/WorkoutLog/ActiveWorkoutSheet.swift` -- 11 occurrences
- `Views/TemplateEditorSheet.swift` -- 8 occurrences
- `Views/PrescribeWorkoutSheet.swift` -- 1 occurrence
- `Views/Recovery/MorningCheckInSheet.swift` -- 1 occurrence
- `Views/WorkoutLog/FinishWorkoutSheet.swift` -- 1 occurrence
- `Views/WorkoutLog/ExercisePickerView.swift` -- 1 occurrence

---

### Build Configuration Files

**Info.plist** (`workload management/workload-management-Info.plist` lines 26-30):
```xml
<key>UIAppFonts</key>
<array>
    <string>DMSans-Regular.ttf</string>
    <string>DMSans-Medium.ttf</string>
</array>
```

**Required change:** Replace with `Alpino-Regular.otf` and `Alpino-Medium.otf`.

**pbxproj** -- Remove DMSans file references (PBXBuildFile, PBXFileReference, PBXGroup children, Resources build phase), add Alpino file references with same structure.

**Resources directory** -- Copy `Alpino_Complete/Alpino_Complete/Fonts/OTF/Alpino-Regular.otf` and `Alpino-Medium.otf` to `WorkloadApp/Resources/`, remove `DMSans-Regular.ttf` and `DMSans-Medium.ttf`.

---

### `DESIGN.md` (MODIFY -- documentation)

**Sections requiring update:**
- Typography section (lines 23-31): Replace all "DM Sans" with "Alpino", update description
- Font Loading section (lines 44-48): Update filenames and Font.custom references
- Implementation Rule #8 (line 183): Change font names
- Decisions Log (lines 186-197): Add new row for Alpino migration

---

## Shared Patterns

### Design System Card Styling
**Source:** `WorkloadApp/Components/SpikeAlertBanner.swift` (lines 70-76)
**Apply to:** SharpTextFieldStyle (overlay/background pattern)
```swift
.background(ColorTokens.surface)
.overlay(
    Rectangle()
        .stroke(ColorTokens.divider, lineWidth: 0.5)
)
```

### Font Token Usage
**Source:** `WorkloadApp/Utilities/FontTokens.swift` (lines 11-32)
**Apply to:** All 18 files with rogue font references
```swift
// Always use token references, never raw Font.custom() in view files:
.font(.Tokens.body)        // 17pt Regular
.font(.Tokens.bodyMedium)  // 17pt Medium
.font(.Tokens.label)       // 15pt Regular
.font(.Tokens.micro)       // 12pt Regular
.font(.Tokens.sectionHead) // 19pt Medium
.font(.Tokens.pageTitle)   // 32pt Regular
.font(.Tokens.heroScore)   // 64pt Regular
```

### Color Token Usage
**Source:** `WorkloadApp/Utilities/ColorTokens.swift` (lines 23-48)
**Apply to:** SharpTextFieldStyle
```swift
// Semantic colors -- never hardcode hex
ColorTokens.text1      // primary text
ColorTokens.text2      // secondary text
ColorTokens.surface    // card/field background
ColorTokens.divider    // borders, hairline rules
```

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `WorkloadApp/Components/SharpTextFieldStyle.swift` | component | transform | No existing TextFieldStyle in codebase. Pattern derived from Apple's TextFieldStyle protocol + project's card styling convention (ColorTokens + Rectangle overlay). Research provides full spec. |

## Metadata

**Analog search scope:** `WorkloadApp/` (Views, Components, Utilities, Services, App, Resources), `workload management/` (Info.plist, pbxproj), project root (DESIGN.md)
**Files scanned:** 25+ source files via grep inventory
**Pattern extraction date:** 2026-05-10
