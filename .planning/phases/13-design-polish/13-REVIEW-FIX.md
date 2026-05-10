---
phase: 13-design-polish
fixed_at: 2026-05-10T12:30:00Z
review_path: .planning/phases/13-design-polish/13-REVIEW.md
iteration: 1
findings_in_scope: 6
fixed: 6
skipped: 0
status: all_fixed
---

# Phase 13: Code Review Fix Report

**Fixed at:** 2026-05-10T12:30:00Z
**Source review:** .planning/phases/13-design-polish/13-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 6 (1 Critical, 5 Warning)
- Fixed: 6
- Skipped: 0

## Fixed Issues

### CR-01 + WR-03: Rename stale brand "Tutrice" to "Tuwa" across codebase

**Files modified:** `WorkloadApp/Services/PDFReportEngine.swift`, `WorkloadApp/Views/Subscription/UpgradeSheet.swift`, `WorkloadApp/Views/Onboarding/OnboardingView.swift`, `WorkloadApp/Views/Profile/ProfileView.swift`, `WorkloadApp/Views/Dashboard/WelcomeActionCard.swift`, `WorkloadApp/Views/Export/CoachExportSheet.swift`
**Commit:** bdba03d
**Applied fix:** Replaced all 8 occurrences of "Tutrice" with "Tuwa" across the codebase (PDF header/footer, UpgradeSheet subtitle, onboarding HealthKit step, ProfileView notifications and HealthKit descriptions, WelcomeActionCard title, CoachExportSheet filename). Also removed 1 stale "Faros" comment in PDFReportEngine. Per user override, the correct brand name is "Tuwa" (not "Faros" as the review suggested).

### WR-01: Replace .system() font with Alpino design token in UpgradeSheet

**Files modified:** `WorkloadApp/Views/Subscription/UpgradeSheet.swift`
**Commit:** acd2b26
**Applied fix:** Changed `.font(.system(size: 11, weight: .medium))` on checkmark icon to `.font(.Tokens.micro)` to use the Alpino 12pt token instead of SF Pro.

### WR-02: Update DESIGN.md type scale to match FontTokens implementation

**Files modified:** `DESIGN.md`
**Commit:** b9f05b0
**Applied fix:** Updated both the bullet list and the type scale table in DESIGN.md to reflect the actual FontTokens sizes: hero 64pt, pageTitle 32pt, sectionHead 19pt, body 17pt, label 15pt, smallLabel 13pt, micro 12pt. Added "Small label" row to the table. This documents the +2pt device-optimized bump that was implemented in FontTokens.swift.

### WR-04: Replace DispatchQueue.main.asyncAfter with cancellable Task.sleep in ToastBanner

**Files modified:** `WorkloadApp/Components/ToastBanner.swift`
**Commit:** 00f165a
**Applied fix:** Replaced `.onAppear` with `DispatchQueue.main.asyncAfter` to `.task` with `try? await Task.sleep(for:)`. The `.task` modifier automatically cancels when the view disappears, preventing potential issues with invalidated bindings.

### WR-05: Fix 14pt vertical padding to 16pt for 8pt grid compliance

**Files modified:** `WorkloadApp/Views/Subscription/UpgradeSheet.swift`
**Commit:** ccfc37f
**Applied fix:** Changed `.padding(.vertical, 14)` to `.padding(.vertical, 16)` on HistoryTeaserBanner to comply with the 8pt grid spacing rule from DESIGN.md.

---

_Fixed: 2026-05-10T12:30:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
