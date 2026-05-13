---
phase: 15-template-sharing
verified: 2026-05-13T13:00:00Z
status: human_needed
score: 5/5
overrides_applied: 0
---

# Phase 15: Template Sharing Verification Report

**Phase Goal:** Users can share any template they own with anyone via a short code or link, and recipients can preview and import it as their own independent copy
**Verified:** 2026-05-13T13:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can tap "Share" on any owned template and receive an 8-character alphanumeric code copyable to clipboard | VERIFIED | `TemplateCarouselSection.swift:318-321` — `onShareTemplate` callback in context menu triggers `ShareCodeSheet`. `ShareCodeSheet.swift:114` — `UIPasteboard.general.string = code`. `TemplateSharingService.makeShareCode()` generates `(0..<8).map { _ in chars.randomElement()! }` with 36-char alphanumeric set. |
| 2 | User can enter a share code in an import sheet and see a full preview of the template (name, exercise groups, exercises, target sets/reps) before deciding to import | VERIFIED | `ShareImportSheet.swift` — `TextField("ABCD1234")` with 8-char uppercase validation, `TemplateSharingService.lookupShareCode` call on lookup. `ShareImportPreviewSheet.swift` — shows `payload.templateName`, `sport.displayName`, exercise groups via `previewGroups`, `setSummary()` renders sets/reps, weekday row. |
| 3 | User can tap a universal link containing a share code and the app opens directly to the import preview | VERIFIED | `AppRouter.swift:46-49` — `TemplateSharingService.handleDeepLink(url)` in `.onOpenURL` handler. `PendingShareCode` struct at line 11. `.sheet(item: $pendingShareCode)` at line 59 presents `ShareImportSheet(prefillCode: pending.code)`. `ShareImportSheet.swift:96-100` — `onAppear` auto-triggers lookup when `prefillCode` is set. `TemplateSharingService.handleDeepLink` validates `tuwa.app/t/{8-char-code}` and `workload://template?code={code}`. Entitlements file contains `applinks:tuwa.app`. |
| 4 | Imported template is a fully independent deep copy — new UUIDs, current user as owner, no personal weight data from the sharer | VERIFIED | `TemplateSharingService.importTemplate`: calls `SyncService.decodeGroups(from:)` which creates fresh `ExerciseGroup`, `TemplateExercise`, `TemplateSet` objects with new `UUID()` inits. Lines 161-165 set `set.targetWeightKg = nil` on all decoded sets. Template is created with `WorkoutTemplate(coachId: athlete.id, ...)` and `template.athleteId = athlete.id` — current user as owner. |
| 5 | Shared template data expires after 30 days and is cleaned up automatically | VERIFIED | `TemplateSharingService.shareTemplate:61` — `Date.now.addingTimeInterval(30 * 24 * 60 * 60)` sets `expiresAt`. `migrations/shared_templates.sql:35-39` — `cron.schedule('cleanup-expired-shares', '0 3 * * *', $$DELETE FROM public.shared_templates WHERE expires_at < now()$$)`. `migrations/shared_templates.sql:14` — index on `expires_at` for performance. |

**Score:** 5/5 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `migrations/shared_templates.sql` | Supabase migration with RLS and pg_cron | VERIFIED | `CREATE TABLE public.shared_templates` with `share_code TEXT NOT NULL UNIQUE`, `template_json JSONB NOT NULL`, `expires_at TIMESTAMPTZ NOT NULL`. 3 RLS policies. `cron.schedule` cleanup job. |
| `WorkloadApp/Services/TemplateSharingService.swift` | Share code generation, Supabase CRUD, import logic | VERIFIED | `enum TemplateSharingService` with `makeShareCode`, `shareTemplate`, `lookupShareCode`, `importTemplate`, `handleDeepLink`. `TemplateSharePayload: Codable` with `v: Int`. `SharedTemplateResponse: Identifiable`. |
| `workload management/workload management/workload management.entitlements` | Associated Domains for universal links | VERIFIED | Contains `com.apple.developer.associated-domains` with `applinks:tuwa.app`. HealthKit and Apple Sign-In preserved. |
| `WorkloadApp/Views/WorkoutLog/ShareCodeSheet.swift` | Share code display with copy + share link | VERIFIED | `struct ShareCodeSheet: View`, `UIPasteboard.general.string = code`, `ShareLink(item: shareURL)` with `https://tuwa.app/t/\(code)`. Copy toggle with 1.5s timer. `.presentationDetents([.medium])`. |
| `WorkloadApp/Views/WorkoutLog/TemplateCarouselSection.swift` | Share button in context menu | VERIFIED | `var onShareTemplate: ((WorkoutTemplate) -> Void)? = nil` at line 14. `Label("Share Template", systemImage: "square.and.arrow.up")` in context menu at lines 318-321. |
| `WorkloadApp/Views/WorkoutLog/WorkoutLogView.swift` | State for share presentation, import toolbar button | VERIFIED | `@State private var selectedTemplateForShare: WorkoutTemplate?` at line 19. `@State private var showShareImport = false` at line 24. `Label("Import Shared Template", ...)` in toolbar menu at line 202. Both sheets wired: `.sheet(item: $selectedTemplateForShare)` and `.sheet(isPresented: $showShareImport)` plus `.sheet(item: $shareImportResult)`. |
| `WorkloadApp/Views/WorkoutLog/ShareImportSheet.swift` | Code entry text field with lookup button | VERIFIED | `struct ShareImportSheet: View`, `TextField("ABCD1234", text: $codeInput)`, `SharpTextFieldStyle()`, `TemplateSharingService.lookupShareCode`, `var prefillCode: String?`, `.presentationDetents([.medium])`, `onLookupSuccess` callback. |
| `WorkloadApp/Views/WorkoutLog/ShareImportPreviewSheet.swift` | Full template preview with Import CTA | VERIFIED | `struct ShareImportPreviewSheet: View`, `let response: SharedTemplateResponse`, `Text("SHARED TEMPLATE")` banner, exercise group listing, `TemplateSharingService.importTemplate`, `setSummary` helper, `weekdayRow` helper, `.presentationDetents([.medium, .large])`. Sticky import button with inverted colors. |
| `WorkloadApp/App/AppRouter.swift` | Universal link and custom scheme routing | VERIFIED | `struct PendingShareCode: Identifiable` at line 11. `@State private var pendingShareCode: PendingShareCode?` at line 20. `TemplateSharingService.handleDeepLink(url)` in `.onOpenURL` at lines 46-49. `.sheet(item: $pendingShareCode)` presenting `ShareImportSheet(prefillCode:)` at lines 59-62. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `ShareCodeSheet.swift` | `TemplateSharingService.shareTemplate` | `await generateCode()` on `.task` | WIRED | Line 158: `try await TemplateSharingService.shareTemplate(template, ownerId: ..., client: container.supabase)` |
| `TemplateCarouselSection.swift` | `ShareCodeSheet` (via WorkoutLogView) | `onShareTemplate` callback | WIRED | Line 319: `Button { onShareTemplate(template) }`. WorkoutLogView lines 82-84 set `selectedTemplateForShare = template`, lines 276-279 present `ShareCodeSheet`. |
| `ShareImportSheet.swift` | `TemplateSharingService.lookupShareCode` | `lookUpCode()` async on button tap | WIRED | Line 110: `try await TemplateSharingService.lookupShareCode(codeInput, client: container.supabase)` |
| `ShareImportPreviewSheet.swift` | `TemplateSharingService.importTemplate` | `importTemplate()` async on CTA tap | WIRED | Line 194: `TemplateSharingService.importTemplate(from: response, forAthlete: athlete, context: modelContext)` |
| `AppRouter.swift` | `TemplateSharingService.handleDeepLink` | `.onOpenURL` modifier | WIRED | Line 46: `if let code = TemplateSharingService.handleDeepLink(url)` |
| `TemplateSharingService.swift` | `SyncService.encodeGroups/decodeGroups` | Static method calls | WIRED | `shareTemplate` line 63: `SyncService.encodeGroups(template.groups)`. `importTemplate` line 158: `SyncService.decodeGroups(from: json)`. |
| `TemplateSharingService.swift` | `shared_templates` (Supabase) | `client.from("shared_templates").insert/select` | WIRED | `shareTemplate` line 84: `client.from("shared_templates").insert(payload, ...)`. `lookupShareCode` line 126: `client.from("shared_templates").select()...` |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `ShareCodeSheet.swift` | `shareCode: String?` | `TemplateSharingService.shareTemplate` → Supabase insert → returns code | Yes — generates and returns 8-char code from Supabase write | FLOWING |
| `ShareImportPreviewSheet.swift` | `previewGroups: [ExerciseGroup]` | `SyncService.decodeGroups(from: payload.groupsJson)` from Supabase lookup result | Yes — decoded from JSON retrieved from `shared_templates` table | FLOWING |
| `ShareImportPreviewSheet.swift` | `payload: TemplateSharePayload` | `response.payload` from `lookupShareCode` Supabase select | Yes — populated from `template_json JSONB` column | FLOWING |
| `TemplateSharingService.importTemplate` | `groups: [ExerciseGroup]` | `SyncService.decodeGroups` creates fresh objects with new UUIDs | Yes — new UUIDs, weights stripped before context insert | FLOWING |

### Behavioral Spot-Checks

Step 7b: SKIPPED — no runnable entry points without launching iOS simulator. All logic is within an iOS app (no CLI or server).

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| SHARE-01 | 15-01, 15-02 | User can generate 8-char share code for any owned template | SATISFIED | `makeShareCode()` generates 8-char alphanumeric. ShareCodeSheet + context menu wired end-to-end. |
| SHARE-02 | 15-01, 15-03 | User can import a template by entering a share code | SATISFIED | `ShareImportSheet` with `TextField` entry, `lookupShareCode` call, `onLookupSuccess` callback chain to `ShareImportPreviewSheet`. |
| SHARE-03 | 15-02, 15-03 | User can share template via universal link (tap opens app, imports template) | SATISFIED | `ShareLink(item: URL("https://tuwa.app/t/\(code)"))` in `ShareCodeSheet`. `AppRouter.onOpenURL` handles `tuwa.app/t/{code}` via `handleDeepLink`. `applinks:tuwa.app` in entitlements. |
| SHARE-04 | 15-03 | User sees preview of shared template before importing | SATISFIED | `ShareImportPreviewSheet` shows template name, sport/session type, weekday schedule, all exercise groups with `setSummary` (sets × reps), notes. Import only happens after explicit CTA tap. |
| SHARE-05 | 15-01 | Imported template is deep copy — no reference to original, personal weight data stripped | SATISFIED | `SyncService.decodeGroups` creates new UUID objects. `TemplateSharingService.importTemplate` sets `targetWeightKg = nil` on all sets. New `WorkoutTemplate` with `athleteId = athlete.id`. `context.insert(template)` creates independent local record. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| None found | — | — | — | All new files are substantive implementations with no stubs, TODOs, or placeholders. |

Design system compliance (checked all new view files):
- No `RoundedRectangle` usage — only `Rectangle()` with `.stroke` per 0pt border radius requirement
- No `.shadow()` modifiers
- No `.system()` font calls — all use `Font.Tokens.*`
- All colors use `ColorTokens.*` semantic tokens

### Human Verification Required

The following items require device/simulator testing that cannot be verified programmatically from source inspection:

#### 1. Share Code Generation and Display

**Test:** Open WorkoutLog tab, long-press any template card, tap "Share Template." The ShareCodeSheet should appear with a loading indicator, then transition to showing an 8-character code, the template name, and two buttons: "Copy Code" and "Share Link."
**Expected:** Sheet appears, code is generated and displayed within a few seconds, "Copy Code" button copies to clipboard with "Copied" confirmation for 1.5s, "Share Link" opens iOS Share Sheet with the `https://tuwa.app/t/{code}` URL.
**Why human:** Requires active Supabase connection and live UI rendering; clipboard verification needs device interaction.

#### 2. Share Code Import Flow

**Test:** In WorkoutLog toolbar, tap the `ellipsis.circle` menu and select "Import Shared Template." Enter a valid 8-char code (generated in test 1) and tap "Look Up."
**Expected:** ShareImportSheet dismisses, ShareImportPreviewSheet appears showing the template name, sport/session type, weekday row, all exercise groups with set summaries, and a sticky "Import Template" button. Tapping "Import Template" dismisses the sheet and the imported template appears in the carousel.
**Why human:** Requires a live Supabase environment with an existing shared_templates row; sheet dismissal + sequential presentation cannot be verified statically.

#### 3. Universal Link Deep Link

**Test:** Tap a `https://tuwa.app/t/{VALIDCODE}` link from Messages or Safari while the app is installed (requires the AASA file to be hosted at `tuwa.app/.well-known/apple-app-site-association`).
**Expected:** App opens or comes to foreground and immediately presents ShareImportSheet with the code pre-filled and lookup triggered automatically.
**Why human:** Requires the associated domain to be configured on the tuwa.app server. The iOS entitlement is present but the AASA file hosting is an external service dependency that cannot be verified from source. Deep link routing also requires a running app instance.

#### 4. Weight Stripping Verification

**Test:** Share a template that has exercises with `targetWeightKg` values set. Import the template using the code. Open the imported template in the template editor.
**Expected:** All exercises in the imported template show no target weight values (fields should be empty/nil). Sets should retain target reps and set counts but not weights.
**Why human:** Weight stripping happens at runtime in `importTemplate`; confirming nil values in the UI requires visual inspection of the imported template's edit view.

#### 5. Expired Code Error Handling

**Test:** Manually update a `shared_templates` row in Supabase to set `expires_at` to a past timestamp, then attempt to import it via `ShareImportSheet`.
**Expected:** Error message "This share link has expired. Ask the sender for a new code." appears below the Look Up button in red.
**Why human:** Requires direct Supabase manipulation and observing the specific error message displayed.

### Gaps Summary

No gaps found. All 5 observable truths are VERIFIED by source inspection. All required artifacts exist, are substantive, and are wired correctly. Requirements SHARE-01 through SHARE-05 are all satisfied. The 5 human verification items above require a running device/simulator with a live Supabase connection — they are verification completeness items, not architectural gaps.

---

_Verified: 2026-05-13T13:00:00Z_
_Verifier: Claude (gsd-verifier)_
