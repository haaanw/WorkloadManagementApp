---
phase: 15-template-sharing
fixed_at: 2026-05-13T14:45:00Z
review_path: .planning/phases/15-template-sharing/15-REVIEW.md
iteration: 1
findings_in_scope: 5
fixed: 4
skipped: 1
status: partial
---

# Phase 15: Code Review Fix Report

**Fixed at:** 2026-05-13T14:45:00Z
**Source review:** .planning/phases/15-template-sharing/15-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 5
- Fixed: 4
- Skipped: 1

## Fixed Issues

### CR-01: Deep link share code triggers sheet before authentication check completes

**Files modified:** `WorkloadApp/App/AppRouter.swift`
**Commit:** 6769f84
**Applied fix:** Added `deferredShareCode` state variable. The `onOpenURL` handler now checks `container.isAuthenticated` before setting `pendingShareCode`. If not authenticated, the code is stored in `deferredShareCode` and processed in the `onChange(of: container.isAuthenticated)` handler once auth completes.

### WR-01: Expired share codes are served to clients; no client-side expiration check

**Files modified:** `WorkloadApp/Services/TemplateSharingService.swift`
**Commit:** 73ebd8a
**Applied fix:** Added `.gt("expires_at", value: ISO8601DateFormatter().string(from: Date.now))` filter to the `lookupShareCode` Supabase query. Expired templates now return a "not found" error (PGRST116) instead of being served to the client, which is already handled by the error UI in ShareImportSheet.

### WR-03: `setSummary` in ShareImportPreviewSheet shows weight data that was supposedly stripped

**Files modified:** `WorkloadApp/Views/WorkoutLog/ShareImportPreviewSheet.swift`
**Commit:** b94a3ac
**Applied fix:** The `previewGroups` computed property now strips `targetWeightKg` from all sets immediately after decoding, before the preview UI renders. This prevents the sharer's personal weight data from appearing in the `setSummary` display. The `setSummary` helper will now fall back to the "N x reps" format without weight.

### WR-04: `onLookupSuccess` callback fires after `dismiss()` -- timing-dependent behavior

**Files modified:** `WorkloadApp/Views/WorkoutLog/ShareImportSheet.swift`
**Commit:** 63c73e6
**Applied fix:** Swapped the order of `dismiss()` and `onLookupSuccess?(result)` so the callback fires first while the view hierarchy is still intact, then dismiss occurs. This avoids the known SwiftUI sheet-transition issue where a second sheet fails to present if triggered during dismissal teardown.

## Skipped Issues

### WR-02: Share code generated with non-cryptographic randomness

**File:** `WorkloadApp/Services/TemplateSharingService.swift:14-15`
**Reason:** Reviewer explicitly states "Consider this acceptable for the current use case." The 8-char alphanumeric space with 30-day expiration is adequate for the current sharing volume. No code change needed.
**Original issue:** `makeShareCode()` uses `String.randomElement()` which calls `SystemRandomNumberGenerator`. The 8-char alphanumeric space (36^8) is smaller than typical share link tokens but acceptable for current use.

---

_Fixed: 2026-05-13T14:45:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
