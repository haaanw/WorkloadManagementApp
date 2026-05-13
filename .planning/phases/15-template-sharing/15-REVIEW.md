---
phase: 15-template-sharing
reviewed: 2026-05-13T14:30:00Z
depth: standard
files_reviewed: 8
files_reviewed_list:
  - WorkloadApp/App/AppRouter.swift
  - WorkloadApp/Services/TemplateSharingService.swift
  - WorkloadApp/Views/WorkoutLog/ShareCodeSheet.swift
  - WorkloadApp/Views/WorkoutLog/ShareImportPreviewSheet.swift
  - WorkloadApp/Views/WorkoutLog/ShareImportSheet.swift
  - WorkloadApp/Views/WorkoutLog/TemplateCarouselSection.swift
  - WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift
  - migrations/shared_templates.sql
findings:
  critical: 1
  warning: 4
  info: 3
  total: 8
status: issues_found
---

# Phase 15: Code Review Report

**Reviewed:** 2026-05-13T14:30:00Z
**Depth:** standard
**Files Reviewed:** 8
**Status:** issues_found

## Summary

Phase 15 adds template sharing via 8-character share codes backed by a Supabase `shared_templates` table. The implementation follows the project's established patterns (pure service enum, sheet-based flows, RLS policies). The code is generally well-structured with proper weight stripping on import and a clean deep link flow.

Key concerns: the share code lookup does not validate expiration client-side, the deep link handler in AppRouter may present a sheet to an unauthenticated user, and the SQL migration allows any authenticated user to read all shared templates without checking expiration in the RLS policy.

## Critical Issues

### CR-01: Deep link share code triggers sheet before authentication check completes

**File:** `WorkloadApp/App/AppRouter.swift:46-48`
**Issue:** `onOpenURL` fires regardless of `isCheckingSession` or `container.isAuthenticated` state. If the app receives a universal link while still loading (or while logged out), `pendingShareCode` is set and the `.sheet(item: $pendingShareCode)` will present `ShareImportSheet`. That sheet reads `container.supabase` to call `lookupShareCode`, but the user may not have a valid Supabase session yet, causing a network error or -- worse -- the lookup may succeed (SELECT is allowed for any authenticated user) but the subsequent import would fail silently because there is no local athlete.
**Fix:** Gate the share code handling on authentication state, or defer processing until after auth is confirmed:
```swift
if let code = TemplateSharingService.handleDeepLink(url) {
    if container.isAuthenticated {
        pendingShareCode = PendingShareCode(code: code)
    } else {
        // Store for post-auth processing
        // e.g. a @State var deferredShareCode: String?
    }
    return
}
```

## Warnings

### WR-01: Expired share codes are served to clients; no client-side expiration check

**File:** `WorkloadApp/Services/TemplateSharingService.swift:126-131`
**Issue:** `lookupShareCode` queries the `shared_templates` table without filtering on `expires_at`. The pg_cron job runs only once daily at 3 AM UTC, so expired templates remain readable for up to 24 hours after expiration. There is also no client-side check on `expiresAt` after fetching the row. A user could import an expired template.
**Fix:** Add a server-side filter in the query and a client-side guard:
```swift
let row: SharedTemplateRow = try await client
    .from("shared_templates")
    .select()
    .eq("share_code", value: code.uppercased())
    .gt("expires_at", value: ISO8601DateFormatter().string(from: Date.now))
    .single()
    .execute(decoder: decoder)
    .value
```

### WR-02: Share code generated with non-cryptographic randomness

**File:** `WorkloadApp/Services/TemplateSharingService.swift:14-15`
**Issue:** `makeShareCode()` uses `String.randomElement()` which calls `SystemRandomNumberGenerator`. While this is technically secure on Apple platforms (backed by `arc4random`), the 8-char alphanumeric space (36^8 = ~2.8 trillion) combined with a retry-only-on-collision approach means the code is guessable in theory. For a share feature with 30-day expiration this is low risk, but the code space is smaller than typical share link tokens.
**Fix:** Consider this acceptable for the current use case. If sharing volume grows, increase to 10-12 characters or add a rate limit on the lookup RPC.

### WR-03: `setSummary` in ShareImportPreviewSheet shows weight data that was supposedly stripped

**File:** `WorkloadApp/Views/WorkoutLog/ShareImportPreviewSheet.swift:21-23, 173-182`
**Issue:** `previewGroups` decodes the raw JSON from the payload (line 22), which still contains the original sharer's `targetWeightKg` values. The `setSummary` helper (line 176) then displays `"3 x 8 @ 80kg"` in the preview -- exposing the sharer's personal weight data before the import strips it. The weight stripping only happens in `importTemplate()`, not in the preview.
**Fix:** Strip weights in the preview decode as well:
```swift
private var previewGroups: [ExerciseGroup] {
    guard let json = payload.groupsJson else { return [] }
    let groups = SyncService.decodeGroups(from: json)
    for group in groups {
        for exercise in group.exercises {
            for set in exercise.sets {
                set.targetWeightKg = nil
            }
        }
    }
    return groups
}
```

### WR-04: `onLookupSuccess` callback fires after `dismiss()` -- timing-dependent behavior

**File:** `WorkloadApp/Views/WorkoutLog/ShareImportSheet.swift:113-115`
**Issue:** In `lookUpCode()`, `dismiss()` is called before `onLookupSuccess?(result)`. After dismiss, the sheet's view hierarchy is being torn down. The callback sets `shareImportResult` on the parent (`WorkoutLogView`), which should then present `ShareImportPreviewSheet`. However, calling the callback during sheet dismissal is timing-dependent in SwiftUI and can cause the next sheet to fail to present (known SwiftUI sheet-transition issue).
**Fix:** Swap the order so the callback fires first, or use a small delay:
```swift
onLookupSuccess?(result)
dismiss()
```
Or use `DispatchQueue.main.asyncAfter(deadline: .now() + 0.3)` for the second sheet presentation in the parent.

## Info

### IN-01: Hardcoded domain "tuwa.app" should be a constant

**File:** `WorkloadApp/Services/TemplateSharingService.swift:24`, `WorkloadApp/Views/WorkoutLog/ShareCodeSheet.swift:133`
**Issue:** The domain `tuwa.app` appears in multiple places (deep link parsing, share URL construction). Given the project was renamed from Tonus to Faros, hardcoding domains across files increases the risk of inconsistency if the domain changes again.
**Fix:** Extract to a shared constant, e.g. `enum AppConstants { static let shareDomain = "tuwa.app" }`.

### IN-02: `previewGroups` computed property decodes JSON on every view re-render

**File:** `WorkloadApp/Views/WorkoutLog/ShareImportPreviewSheet.swift:21-23`
**Issue:** `previewGroups` is a computed property that calls `SyncService.decodeGroups(from:)` on every access. Since SwiftUI body can re-evaluate multiple times, this does redundant JSON parsing. Not a correctness issue but wasteful.
**Fix:** Decode once into a `@State` property on `.task` or `.onAppear`.

### IN-03: SQL migration assumes pg_cron extension is available

**File:** `migrations/shared_templates.sql:36-39`
**Issue:** The `cron.schedule()` call will fail if the `pg_cron` extension is not enabled on the Supabase project. This is available on Supabase Pro plans but may not be on free tier.
**Fix:** Add a comment documenting the prerequisite, or wrap in a conditional check / provide manual cleanup instructions as fallback.

---

_Reviewed: 2026-05-13T14:30:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
