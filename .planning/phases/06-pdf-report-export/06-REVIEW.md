---
phase: 06-pdf-report-export
reviewed: 2026-04-25T12:00:00Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - WorkloadApp/Services/PDFReportEngine.swift
  - WorkloadApp/Views/Export/PDFGenerationSheet.swift
  - WorkloadApp/Views/Export/CoachExportSheet.swift
  - WorkloadApp/Views/Coach/CoachRosterView.swift
  - WorkloadApp/Views/Workload/WorkloadView.swift
  - workload management/workload management.xcodeproj/project.pbxproj
findings:
  critical: 0
  warning: 4
  info: 2
  total: 6
status: issues_found
---

# Phase 6: Code Review Report

**Reviewed:** 2026-04-25T12:00:00Z
**Depth:** standard
**Files Reviewed:** 6
**Status:** issues_found

## Summary

The PDF report export feature is well-structured. `PDFReportEngine` correctly follows the project convention of a pure struct with static methods, uses hardcoded light-mode colors for print (avoiding ColorTokens), and excludes raw HealthKit data. The Xcode project file includes all new source files. The main concerns are: (1) a data duplication bug in the coach roster table, (2) a double-draw of the overreaching flag, (3) the coach export sheet running synchronously on the main thread with no async yield, and (4) a force-unwrap in WorkloadView.

## Warnings

### WR-01: Coach Roster Report -- ACWR and ZONE Columns Show Identical Text

**File:** `WorkloadApp/Services/PDFReportEngine.swift:385-393`
**Issue:** The roster table has separate "ACWR" and "ZONE" columns (line 353-354), but both are populated with `acwrText` which is `athlete.acwrZone.displayName` (a string like "Optimal" or "Caution"). The ACWR column should show a numeric ratio, but `RosterAthleteData` does not include an ACWR numeric value. The result is two columns displaying the same zone name string.
**Fix:** Either add an `acwrValue: Double?` field to `RosterAthleteData` and display the numeric ratio in the ACWR column, or remove the duplicate ZONE column and widen ACWR to include both the value and zone label:

```swift
struct RosterAthleteData {
    let name: String
    let recoveryScore: Double?
    let acwrValue: Double?          // add numeric ACWR
    let acwrZone: ACWRZone
    let sessionsCount: Int
    let streakCount: Int
    let isOverreaching: Bool
}

// In the row rendering:
let acwrNumeric = athlete.acwrValue.map { String(format: "%.2f", $0) } ?? "--"
let rowData: [(text: String, width: CGFloat)] = [
    (athlete.name, 140),
    (recoveryText, 80),
    (acwrNumeric, 70),       // numeric ratio
    (acwrText, 80),          // zone name
    ...
]
```

### WR-02: Overreaching Flag "!" Drawn Twice (Overlapping Text)

**File:** `WorkloadApp/Services/PDFReportEngine.swift:387-405`
**Issue:** When `athlete.isOverreaching` is true, the "!" is first included in the `rowData` array (line 387) and drawn by `drawTableRow` in the default text color. Then lines 401-405 draw a second "!" over the same position in `zoneDanger` color. This produces overlapping text glyphs. The first "!" in `textPrimary` bleeds through behind the red one.
**Fix:** Set the flag to an empty string in `rowData` and only draw it in the danger-colored block:

```swift
let flag = ""  // always empty in the table row

// The danger-colored drawing below handles the flag rendering
if athlete.isOverreaching {
    let flagX = marginH + 140 + 80 + 70 + 80 + 70 + 50
    let flagRect = CGRect(x: flagX, y: cursorY, width: 26, height: 24)
    drawText("!", in: flagRect, font: fontRegular(13), color: zoneDanger)
}
```

### WR-03: CoachExportSheet Report Generation Runs Synchronously -- Loading Indicator Never Appears

**File:** `WorkloadApp/Views/Export/CoachExportSheet.swift:212-262`
**Issue:** `generateReport()` sets `isGenerating = true` on line 213 then immediately proceeds with synchronous computation (PDF generation, file write) without yielding to the run loop. Unlike `PDFGenerationSheet.generateReport()` which wraps work in `Task { ... }`, this method never yields, so SwiftUI has no opportunity to re-render the "Generating..." state before the work completes. The loading indicator will never be visible to the user.
**Fix:** Wrap the work in a `Task` block, matching the pattern used in `PDFGenerationSheet`:

```swift
private func generateReport() {
    isGenerating = true

    Task {
        let selectedAthletes = viewModel.linkedAthletes.filter {
            selectedAthleteIds.contains($0.id)
        }

        // ... existing roster data mapping ...

        do {
            let pdfData = PDFReportEngine.generateCoachRosterReport(
                coachName: coachName,
                athletes: rosterData,
                dateRange: selectedRange
            )

            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("Tonus_Roster_Report.pdf")
            try pdfData.write(to: tempURL)
            exportFileURL = tempURL
            showShareSheet = true
        } catch {
            print("Coach export error: \(error)")
            errorMessage = "Report generation failed. Please try again."
        }

        isGenerating = false
    }
}
```

### WR-04: Force Unwrap on Calendar Date Arithmetic

**File:** `WorkloadApp/Views/Workload/WorkloadView.swift:42`
**Issue:** `Calendar.current.date(byAdding: .day, value: -7, to: .now)!` uses a force unwrap. While `Calendar.date(byAdding:)` is practically guaranteed to succeed for simple day offsets, this is inconsistent with the rest of the codebase which uses `?? .now` as a fallback (see `PDFReportEngine.swift:119`, `CoachExportSheet.swift:224`).
**Fix:** Use the same nil-coalescing pattern for consistency:

```swift
let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
```

## Info

### IN-01: Coach Roster PDF Filename Has No Date Stamp

**File:** `WorkloadApp/Views/Export/CoachExportSheet.swift:252`
**Issue:** The athlete PDF uses a date-stamped filename (`tonus_report_\(dateString).pdf`), but the coach roster PDF uses a static name (`Tonus_Roster_Report.pdf`). Generating multiple reports will silently overwrite the previous temp file. This is minor since the file is in the temporary directory and shared immediately, but it is inconsistent.
**Fix:** Add a date stamp for consistency:

```swift
let dateString = Date.now.formatted(.dateTime.year().month().day())
let tempURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("Tonus_Roster_Report_\(dateString).pdf")
```

### IN-02: Alert Binding Uses .constant() Pattern

**File:** `WorkloadApp/Views/Export/PDFGenerationSheet.swift:69` and `WorkloadApp/Views/Export/CoachExportSheet.swift:96`
**Issue:** Both sheets use `.alert("Error", isPresented: .constant(errorMessage != nil))` which creates a read-only binding. The alert system cannot write `false` back to dismiss the alert state. Dismissal works only because the OK button explicitly sets `errorMessage = nil`, triggering a re-render. This is fragile -- if a future change adds a second button without clearing `errorMessage`, the alert will reappear on next render.
**Fix:** Use a computed `Binding` or a dedicated `@State private var showError = false` bool:

```swift
@State private var showError = false

// In body:
.alert("Error", isPresented: $showError) {
    Button("OK") { errorMessage = nil }
} message: {
    Text(errorMessage ?? "")
}

// In catch block:
errorMessage = "Report generation failed."
showError = true
```

---

_Reviewed: 2026-04-25T12:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
