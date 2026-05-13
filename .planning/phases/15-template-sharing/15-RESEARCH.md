# Phase 15: Template Sharing - Research

**Researched:** 2026-05-13
**Domain:** Template sharing via short codes, universal links, Supabase JSONB storage, iOS Associated Domains
**Confidence:** HIGH

## Summary

Phase 15 adds template sharing to the Tuwa app. Users generate an 8-character alphanumeric share code for any owned template, which creates a denormalized JSONB snapshot in a new `shared_templates` Supabase table. Recipients enter the code (or tap a universal link) to preview and import the template as an independent deep copy with new UUIDs and personal weight data stripped.

The implementation sits across three tiers: (1) a new Supabase table with RLS and pg_cron cleanup, (2) a new `TemplateSharingService` on the iOS side mirroring the `InviteService` pattern, and (3) three new SwiftUI sheets plus integration points in `WorkoutLogView` toolbar, `TemplateCarouselSection` context menu, and `AppRouter` deep link handling. Universal links require an AASA file hosted at `tuwa.app/.well-known/apple-app-site-association` and an Associated Domains entitlement addition.

**Primary recommendation:** Mirror the InviteService code-generation + Supabase-insert pattern for share code creation. Reuse `SyncService.encodeGroups()` / `decodeGroups()` for template serialization. Build import as `decodeGroups()` + strip `targetWeightKg` + insert with new owner.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Clipboard copy + iOS Share Sheet (`ShareLink`) wrapping the share code or universal link
- **D-02:** 8-character alphanumeric code (uppercase + digits). Extend `InviteService.makeLocalCode()` from 6 to 8 chars
- **D-03:** New `shared_templates` table in Supabase: `id`, `share_code` (unique, 8-char), `owner_id`, `template_json` (JSONB), `expires_at` (30 days), `created_at`
- **D-04:** Template JSON is a self-contained snapshot -- owner can edit/archive/delete without affecting in-flight shares
- **D-05:** Include `"v": 1` schema version field in JSONB payload for forward compatibility
- **D-06:** RLS: permissive read for any authenticated user (by share_code), write restricted to owner_id = auth.uid()
- **D-07:** 30-day expiry cleanup via pg_cron: `DELETE FROM shared_templates WHERE expires_at < now()`
- **D-08:** New `ShareImportPreviewSheet` -- dedicated sheet, reuses sub-view patterns from `TemplatePreviewSheet`
- **D-09:** Code entry: "Import" button in WorkoutLog tab toolbar. Opens sheet with text field, transitions to preview on success
- **D-10:** Import via `deepCopyGroups()` pattern: new UUIDs, current user as owner, `targetWeightKg` stripped
- **D-11:** Host AASA file on `tuwa.app` via static hosting (Netlify/Vercel/Cloudflare Pages)
- **D-12:** URL format: `https://tuwa.app/t/{share_code}`
- **D-13:** Fallback landing page at tuwa.app for users without the app (Smart Banner + App Store redirect)
- **D-14:** Add `com.apple.developer.associated-domains` entitlement with `applinks:tuwa.app`
- **D-15:** Custom URL scheme (`workload://template?code=XXXXXXXX`) as in-app fallback only

### Claude's Discretion
- ShareImportPreviewSheet layout details and animation
- Whether code entry uses separate sheet or inline text field before preview
- Exact AASA JSON structure and landing page HTML/CSS
- Whether to show sharer's name in import preview
- `shared_templates` table index strategy (share_code unique index mandatory; expires_at index optional)

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SHARE-01 | User can generate 8-char share code for any owned template | InviteService.makeLocalCode() pattern extended to 8 chars; new Supabase shared_templates insert |
| SHARE-02 | User can import a template by entering a share code | ShareImportSheet + Supabase select by share_code + decodeGroups() + deep copy |
| SHARE-03 | User can share template via universal link (tap opens app) | AASA file on tuwa.app, Associated Domains entitlement, AppRouter.onOpenURL route |
| SHARE-04 | User sees preview before importing | ShareImportPreviewSheet reusing TemplatePreviewSheet layout patterns |
| SHARE-05 | Imported template is deep copy -- no reference to original, weight data stripped | deepCopyGroups() with targetWeightKg set to nil on all TemplateSets |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Share code generation | API / Backend (Supabase) | iOS Client | Code generated client-side, stored server-side with RLS |
| Template serialization | iOS Client | Database / Storage | Existing encodeGroups() serializes locally, JSONB stored in Supabase |
| Share code lookup | API / Backend (Supabase) | iOS Client | Simple select query, client displays result |
| Template import (deep copy) | iOS Client | -- | Pure client-side: decode JSON, create new SwiftData objects, strip weights |
| Universal link routing | iOS Client | CDN / Static (AASA hosting) | AASA file on static host, link handling in AppRouter |
| Expiry cleanup | Database / Storage (pg_cron) | -- | Server-side scheduled job, no client involvement |
| Share/Import UI | iOS Client (SwiftUI) | -- | Three new sheets, toolbar/context menu integration |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 17+ | All share/import UI sheets | Native framework, already used everywhere | [VERIFIED: codebase]
| SwiftData | iOS 17+ | Local template persistence after import | Already used for all models | [VERIFIED: codebase]
| Supabase Swift SDK | current (already in project) | shared_templates table CRUD | Already used for all backend operations | [VERIFIED: codebase]

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| pg_cron | Supabase built-in | 30-day expiry cleanup | Server-side scheduled deletion | [VERIFIED: Supabase docs]

### Alternatives Considered

None -- all decisions are locked. No new dependencies needed.

**Installation:** No new packages required. All functionality uses existing Supabase Swift SDK and native iOS frameworks.

## Architecture Patterns

### System Architecture Diagram

```
User taps "Share"                      User enters code / taps link
      |                                         |
      v                                         v
[TemplateSharingService]              [TemplateSharingService]
      |                                         |
      | encodeGroups() +                        | select by share_code
      | strip targetWeightKg                    |
      | + add "v": 1                            v
      |                               [Supabase shared_templates]
      v                                         |
[Supabase shared_templates]                     | template_json (JSONB)
      |                                         v
      | returns share_code              [decodeGroups()]
      v                                         |
[ShareCodeSheet]                                | strip targetWeightKg
  - Copy Code                                   | new UUIDs, new owner
  - Share Link (tuwa.app/t/{code})              v
                                        [SwiftData insert]
                                                |
                                        [SyncService push]

Universal Link Flow:
tuwa.app/t/{code} --> iOS checks AASA --> AppRouter.onOpenURL
  --> parse code --> TemplateSharingService.lookupShareCode()
  --> present ShareImportPreviewSheet
```

### Recommended Project Structure

```
WorkloadApp/
  Services/
    TemplateSharingService.swift     # Share code gen, lookup, import logic
  Views/
    WorkoutLog/
      ShareCodeSheet.swift           # Display share code + copy/share buttons
      ShareImportSheet.swift         # Code entry text field + lookup
      ShareImportPreviewSheet.swift  # Template preview + import CTA
```

### Pattern 1: TemplateSharingService (mirrors InviteService)

**What:** A stateless enum with static methods for share code generation, lookup, and import.
**When to use:** All template sharing operations.

```swift
// Source: InviteService.swift pattern [VERIFIED: codebase]
enum TemplateSharingService {

    /// Generate 8-char share code (extends InviteService 6-char pattern)
    static func makeShareCode() -> String {
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<8).map { _ in chars.randomElement()! })
    }

    /// Create share row in Supabase, returns the 8-char code
    @MainActor
    static func shareTemplate(
        _ template: WorkoutTemplate,
        ownerId: UUID,
        client: SupabaseClient
    ) async throws -> String {
        let code = makeShareCode()
        let expires = Date.now.addingTimeInterval(30 * 24 * 60 * 60) // 30 days

        // Serialize template to JSON, stripping targetWeightKg
        let groupsJson = SyncService.encodeGroups(template.groups)
        let payload = SharedTemplateInsert(
            shareCode: code,
            ownerId: ownerId,
            templateJson: TemplateSharePayload(
                v: 1,
                templateName: template.templateName,
                sportType: template.sportType.rawValue,
                sessionType: template.sessionType.rawValue,
                notes: template.notes,
                scheduledDays: template.scheduledDays,
                groupsJson: groupsJson  // weights stripped during import, not here
            ),
            expiresAt: expires
        )

        try await client.from("shared_templates").insert(payload).execute()
        return code
    }

    /// Look up shared template by code
    @MainActor
    static func lookupShareCode(
        _ code: String,
        client: SupabaseClient
    ) async throws -> SharedTemplateResponse { ... }

    /// Import template: decode JSON, strip weights, create local copy
    @MainActor
    static func importTemplate(
        from response: SharedTemplateResponse,
        ownerId: UUID,
        coachId: UUID,
        context: ModelContext
    ) throws -> WorkoutTemplate { ... }
}
```

### Pattern 2: JSONB Payload with Version Field (D-05)

**What:** The `template_json` column stores a versioned, self-contained snapshot.
**When to use:** All share operations -- encode on share, decode on import.

```swift
// Source: D-05 decision + SyncService GroupDTO pattern [VERIFIED: codebase]
struct TemplateSharePayload: Codable {
    let v: Int  // Schema version, always 1 for now
    let templateName: String
    let sportType: String
    let sessionType: String
    let notes: String?
    let scheduledDays: [Int]
    let groupsJson: String?  // Reuse SyncService.encodeGroups() format
}
```

### Pattern 3: Deep Copy with Weight Stripping (D-10)

**What:** Import creates new SwiftData objects with fresh UUIDs and nil weights.
**When to use:** When importing a shared template.

```swift
// Source: WorkoutTemplate.deepCopyGroups() [VERIFIED: codebase]
// Existing deepCopyGroups() already creates new UUIDs for groups/exercises/sets.
// For sharing, additionally set targetWeightKg = nil on every TemplateSet.
let groups = SyncService.decodeGroups(from: groupsJson)
for group in groups {
    for exercise in group.exercises {
        for set in exercise.sets {
            set.targetWeightKg = nil  // Strip personal weight data
        }
    }
}
```

### Pattern 4: Universal Link Handling in AppRouter

**What:** Parse `tuwa.app/t/{code}` URLs in `.onOpenURL`.
**When to use:** When user taps a universal link.

```swift
// Source: AppRouter.swift onOpenURL pattern [VERIFIED: codebase]
.onOpenURL { url in
    // Existing handlers (Google Sign-In, invite deep links)...

    // Template share universal link: https://tuwa.app/t/ABCD1234
    if url.host == "tuwa.app" || url.host == "www.tuwa.app",
       url.pathComponents.count >= 3,
       url.pathComponents[1] == "t" {
        let code = String(url.pathComponents[2])
        pendingShareCode = PendingShareCode(code: code)
        return
    }

    // Custom URL scheme fallback: workload://template?code=XXXXXXXX
    if url.scheme == "workload", url.host == "template" {
        if let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "code" })?.value {
            pendingShareCode = PendingShareCode(code: code)
            return
        }
    }
}
```

### Anti-Patterns to Avoid
- **Storing template as a reference/foreign key:** The share payload MUST be a self-contained JSONB snapshot (D-04). Never store `template_id` as a foreign key -- the original may be edited or deleted.
- **Including targetWeightKg in shared data or forgetting to strip on import:** Personal weight data must never leak to recipients (D-10, SHARE-05).
- **Using the legacy AASA format:** Use the modern `applinks.details` format with `components` array (iOS 13+). The app targets iOS 17+ so legacy format is unnecessary. [CITED: developer.apple.com/documentation/xcode/supporting-associated-domains]
- **Generating share codes server-side:** Keep code generation client-side (matching InviteService pattern) to avoid an extra round-trip. The unique constraint on `share_code` handles collisions.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Share code generation | Custom UUID shortening | Extend `InviteService.makeLocalCode()` to 8 chars | Pattern already proven, collision-resistant at 36^8 = 2.8 trillion combinations |
| Template JSON serialization | New Codable structs from scratch | Reuse `SyncService.encodeGroups()` / `decodeGroups()` | Existing DTOs (GroupDTO, ExerciseDTO, SetDTO) already handle the full hierarchy |
| Deep copy with new UUIDs | Manual UUID reassignment | `SyncService.decodeGroups()` already creates new objects | decodeGroups() instantiates fresh ExerciseGroup/TemplateExercise/TemplateSet with `init()` defaults (new UUIDs) |
| Expiry cleanup | Client-side polling or Edge Function | pg_cron `DELETE WHERE expires_at < now()` | Zero-maintenance server-side, built into Supabase |
| iOS share sheet | Custom sharing UI | `ShareLink` SwiftUI view | Native API handles all delivery channels |

**Key insight:** The existing codebase already has 90% of the building blocks: `makeLocalCode()` for code generation, `encodeGroups()`/`decodeGroups()` for serialization, `deepCopyGroups()` as the conceptual pattern, `InviteService` for Supabase insert/lookup, and `TemplatePreviewSheet` for UI layout.

## Common Pitfalls

### Pitfall 1: Share Code Collision
**What goes wrong:** Two users generate the same 8-char code simultaneously.
**Why it happens:** Client-side code generation is random, no server coordination.
**How to avoid:** The `share_code` column has a UNIQUE constraint. If insert fails with a unique violation, retry with a new code (max 3 retries). At 36^8 = ~2.8 trillion combinations, collision is astronomically unlikely but must be handled.
**Warning signs:** Supabase insert throws a PostgreSQL unique violation error (code 23505).

### Pitfall 2: AASA File Caching
**What goes wrong:** Universal links don't work after deploying the AASA file.
**Why it happens:** Apple's CDN caches AASA files aggressively. iOS downloads the AASA file at app install time and periodically refreshes, but not on every link tap. [CITED: developer.apple.com/documentation/xcode/supporting-associated-domains]
**How to avoid:** Deploy AASA file BEFORE submitting the app update. Use `?mode=developer` in the Associated Domains entitlement during development (`applinks:tuwa.app?mode=developer`) to bypass CDN caching. Remove `?mode=developer` for production.
**Warning signs:** Links open in Safari instead of the app. Use Apple's AASA validator at `https://app-site-association.cdn-apple.com/a/v1/tuwa.app` to verify.

### Pitfall 3: Missing Weight Stripping
**What goes wrong:** Shared templates leak the sharer's personal weight data to recipients.
**Why it happens:** `deepCopyGroups()` copies targetWeightKg by default. Developer forgets to nil it out.
**How to avoid:** Strip `targetWeightKg` during import (not during share creation -- the sharer may want to see weights in their own copy). Add explicit test: assert all imported TemplateSet objects have `targetWeightKg == nil`.
**Warning signs:** Recipient sees weight values they didn't enter.

### Pitfall 4: JSONB Encoding Key Mismatch
**What goes wrong:** Supabase expects `snake_case` column names but Swift Codable defaults to `camelCase`.
**Why it happens:** Swift structs use camelCase properties; PostgreSQL columns use snake_case.
**How to avoid:** Use `CodingKeys` enum or configure `JSONEncoder.keyEncodingStrategy = .convertToSnakeCase`. The existing `WorkoutTemplateRow` in SyncService uses Codable with implicit snake_case conversion -- follow the same pattern.
**Warning signs:** Insert succeeds but columns are null or row is malformed.

### Pitfall 5: Entitlements File Not Updated
**What goes wrong:** Universal links don't work because the entitlements file lacks Associated Domains.
**Why it happens:** The `.entitlements` file currently only has HealthKit and Apple Sign-In. Developer forgets to add the new entitlement.
**How to avoid:** Explicitly add `com.apple.developer.associated-domains` with value `applinks:tuwa.app` to the entitlements plist AND verify it appears in the Xcode project build settings.
**Warning signs:** `onOpenURL` never fires for `tuwa.app` URLs.

## Code Examples

### Supabase Table Creation SQL

```sql
-- Source: D-03, D-06, D-07 decisions [VERIFIED: CONTEXT.md]
CREATE TABLE public.shared_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    share_code TEXT NOT NULL UNIQUE,
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    template_json JSONB NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index on share_code is implicit from UNIQUE constraint
-- Optional index for pg_cron cleanup performance
CREATE INDEX idx_shared_templates_expires_at ON public.shared_templates (expires_at);

-- RLS policies (D-06)
ALTER TABLE public.shared_templates ENABLE ROW LEVEL SECURITY;

-- Any authenticated user can read (lookup by share_code)
CREATE POLICY "Anyone can read shared templates"
ON public.shared_templates FOR SELECT
TO authenticated
USING (true);

-- Only owner can insert
CREATE POLICY "Owner can share templates"
ON public.shared_templates FOR INSERT
TO authenticated
WITH CHECK (owner_id = auth.uid());

-- Only owner can delete their own shares
CREATE POLICY "Owner can delete shared templates"
ON public.shared_templates FOR DELETE
TO authenticated
USING (owner_id = auth.uid());
```

### pg_cron Cleanup Job

```sql
-- Source: D-07 [VERIFIED: Supabase pg_cron docs]
SELECT cron.schedule(
    'cleanup-expired-shares',
    '0 3 * * *',  -- Daily at 3 AM UTC
    $$DELETE FROM public.shared_templates WHERE expires_at < now()$$
);
```

### AASA File

```json
// Source: Apple Associated Domains docs [CITED: developer.apple.com/documentation/xcode/supporting-associated-domains]
// Host at: https://tuwa.app/.well-known/apple-app-site-association
{
    "applinks": {
        "details": [
            {
                "appIDs": ["9XTU7KMJ4J.com.tonus.app"],
                "components": [
                    {
                        "/": "/t/*",
                        "comment": "Template share codes"
                    }
                ]
            }
        ]
    }
}
```

Note: `appIDs` format is `{TeamID}.{BundleID}`. Team ID is `9XTU7KMJ4J` and bundle ID is `com.tonus.app`. [VERIFIED: project.pbxproj]

### Entitlements Addition

```xml
<!-- Add to workload management.entitlements -->
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:tuwa.app</string>
</array>
```

### Fallback Landing Page (tuwa.app)

```html
<!-- Source: D-13 [ASSUMED: standard Smart Banner pattern] -->
<!DOCTYPE html>
<html>
<head>
    <meta name="apple-itunes-app" content="app-id=YOUR_APP_STORE_ID">
    <title>Tuwa - Shared Template</title>
    <style>
        body { font-family: -apple-system, sans-serif; text-align: center; padding: 48px 16px; }
    </style>
</head>
<body>
    <h1>Open in Tuwa</h1>
    <p>Download Tuwa to import this workout template.</p>
    <a href="https://apps.apple.com/app/idYOUR_APP_STORE_ID">Download on the App Store</a>
</body>
</html>
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Custom URL schemes only | Universal Links (AASA) + custom scheme fallback | iOS 9+ (2015), modern format iOS 13+ | Universal links are the primary mechanism; custom scheme is fallback only |
| Firebase Dynamic Links | Self-hosted AASA + static landing page | Firebase Dynamic Links deprecated Aug 2025 | Must self-host; no third-party dynamic link service |

**Deprecated/outdated:**
- Firebase Dynamic Links: Fully deprecated August 2025. Do not use. [VERIFIED: WebSearch]
- Legacy AASA format (flat `applinks.apps` array): Replaced by modern `applinks.details` with `components`. Legacy still works but modern format recommended for iOS 13+. [CITED: developer.apple.com/documentation/xcode/supporting-associated-domains]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | tuwa.app domain is available and can be configured for static hosting | Architecture Patterns | HIGH -- universal links won't work without AASA on this domain |
| A2 | App Store ID is known for Smart Banner meta tag | Code Examples (landing page) | LOW -- can be added after app is approved |
| A3 | Supabase project has pg_cron extension enabled | Code Examples (cleanup job) | MEDIUM -- may need to enable in Supabase dashboard |
| A4 | SyncService.encodeGroups/decodeGroups are accessible (not private) | Don't Hand-Roll | LOW -- they are `static` methods, can verify access level |

## Open Questions

1. **tuwa.app domain setup**
   - What we know: D-11 specifies hosting AASA on tuwa.app via Netlify/Vercel/Cloudflare Pages
   - What's unclear: Is the domain already registered and configured? Which static host will be used?
   - Recommendation: This is a manual step the user must do. Plan should include clear instructions but flag it as a human action item.

2. **App Store ID for Smart Banner**
   - What we know: App is submitted to App Store (v1.0 submitted 2026-04-30)
   - What's unclear: Whether the app has been approved and has a numeric App Store ID
   - Recommendation: Use placeholder in landing page HTML; user fills in actual ID.

3. **Weight stripping: share-time vs import-time**
   - What we know: D-10 says strip on import. SHARE-05 says "personal weight data stripped."
   - What's unclear: Should we strip in the JSONB payload (share-time) or during import?
   - Recommendation: Strip at import time per D-10. The JSONB can retain weights as part of the snapshot -- they're the sharer's data. Only strip when creating the recipient's copy. This matches the decision text.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Supabase (cloud) | shared_templates table | Yes | -- | None (required) |
| pg_cron | Expiry cleanup | Yes (Supabase built-in) | -- | Manual cleanup or Edge Function |
| tuwa.app domain | Universal links | Unknown | -- | Custom URL scheme fallback (D-15) |
| Static hosting (Netlify/Vercel/CF Pages) | AASA + landing page | Unknown | -- | Any static host works |

**Missing dependencies with no fallback:**
- None -- custom URL scheme (D-15) provides fallback if universal links aren't ready

**Missing dependencies with fallback:**
- tuwa.app domain + static hosting: If not ready, share codes still work via clipboard/manual entry. Universal links can be added in a follow-up.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | Share lookup requires authenticated user (RLS) |
| V3 Session Management | No | Uses existing Supabase session |
| V4 Access Control | Yes | RLS: read by any authenticated, write by owner only |
| V5 Input Validation | Yes | Share code: validate 8-char alphanumeric, server-side UNIQUE constraint |
| V6 Cryptography | No | No secrets in share codes (they're meant to be shared) |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Share code enumeration/brute force | Information Disclosure | 36^8 keyspace (~2.8T), Supabase rate limiting, codes expire in 30 days |
| Malicious template JSON injection | Tampering | JSON decoded via Swift Codable (type-safe), no raw string execution |
| Unauthorized template creation | Elevation of Privilege | RLS: `owner_id = auth.uid()` on INSERT policy |
| PII leakage via shared weights | Information Disclosure | targetWeightKg stripped at import time per D-10 |

## Sources

### Primary (HIGH confidence)
- Codebase: `InviteService.swift` -- code generation + Supabase insert pattern
- Codebase: `SyncService.swift` -- `encodeGroups()`, `decodeGroups()`, `WorkoutTemplateRow`, `GroupDTO`/`ExerciseDTO`/`SetDTO`
- Codebase: `WorkoutTemplate.swift` -- model hierarchy, `deepCopyGroups()` method
- Codebase: `TemplatePreviewSheet.swift` -- preview layout, `setSummary()`, `weekdayRow()`
- Codebase: `AppRouter.swift` -- `onOpenURL` deep link handling pattern
- Codebase: `TemplateCarouselSection.swift` -- context menu pattern for templates
- Codebase: `project.pbxproj` -- Team ID `9XTU7KMJ4J`, Bundle ID `com.tonus.app`
- Codebase: `workload management.entitlements` -- current entitlements (HealthKit, Apple Sign-In)

### Secondary (MEDIUM confidence)
- [Apple Associated Domains documentation](https://developer.apple.com/documentation/xcode/supporting-associated-domains) -- AASA file format, modern `components` syntax
- [Supabase pg_cron documentation](https://supabase.com/docs/guides/database/extensions/pg_cron) -- cron.schedule() syntax for cleanup
- [Supabase JSONB documentation](https://supabase.com/docs/guides/database/json) -- JSONB insert/select patterns
- [Supabase Swift insert docs](https://supabase.com/docs/reference/swift/insert) -- Swift SDK insert API

### Tertiary (LOW confidence)
- [Universal Links guide 2026](https://app.smler.io/blogs/deep-linking/ios/what-are-ios-universal-links-complete-guide-2026) -- general patterns, cross-verified with Apple docs

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all libraries already in project, no new dependencies
- Architecture: HIGH -- mirrors proven InviteService + SyncService patterns exactly
- Pitfalls: HIGH -- well-documented domain (universal links, JSONB, code collisions)

**Research date:** 2026-05-13
**Valid until:** 2026-06-13 (stable domain, no fast-moving dependencies)
