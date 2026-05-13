# Phase 15: Template Sharing - Context

**Gathered:** 2026-05-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can share any owned template with anyone via an 8-character alphanumeric code or universal link. Recipients preview the full template (name, groups, exercises, sets/reps) and import it as a fully independent deep copy with new UUIDs, current user as owner, no personal weight data from the sharer. Shared data expires after 30 days.

</domain>

<decisions>
## Implementation Decisions

### Share Code Delivery
- **D-01:** Clipboard copy + iOS Share Sheet (`ShareLink`) wrapping the share code or universal link. Lets iOS handle delivery channel (iMessage, AirDrop, WhatsApp, etc.).
- **D-02:** 8-character alphanumeric code (uppercase + digits). Extend existing `InviteService.makeLocalCode()` pattern from 6 to 8 chars.

### Backend Storage
- **D-03:** New dedicated `shared_templates` table in Supabase with columns: `id`, `share_code` (unique, 8-char), `owner_id`, `template_json` (JSONB — full denormalized template snapshot), `expires_at` (30 days from creation), `created_at`.
- **D-04:** Template JSON is a self-contained snapshot — owner can edit, archive, or delete their template without affecting in-flight shares.
- **D-05:** Include `"v": 1` schema version field in the JSONB payload so the import decode path can handle future schema changes.
- **D-06:** RLS: permissive read policy on `shared_templates` for any authenticated user (recipient reads by share_code). Write restricted to owner_id = auth.uid().
- **D-07:** 30-day expiry cleanup via pg_cron: `DELETE FROM shared_templates WHERE expires_at < now()`. Same pattern as invitation cleanup.

### Import Preview UX
- **D-08:** New `ShareImportPreviewSheet` — dedicated sheet showing "Shared template" banner + "Import" CTA. Reuses layout sub-views from TemplatePreviewSheet internally (exercise group list, set summary) but is a separate view file.
- **D-09:** Code entry point: "Import" button in WorkoutLog tab toolbar. Tapping opens a sheet with text field for share code entry, then transitions to ShareImportPreviewSheet on successful lookup.
- **D-10:** Imported template is created via `deepCopyGroups()` pattern — new UUIDs, current user as owner, `targetWeightKg` stripped (no personal weight data from sharer).

### Universal Links
- **D-11:** Host AASA file on `tuwa.app` via static hosting (Netlify/Vercel/Cloudflare Pages).
- **D-12:** URL format: `https://tuwa.app/t/{share_code}` — short, shareable, clean.
- **D-13:** Fallback landing page at tuwa.app for users without the app installed — Apple Smart Banner + App Store redirect.
- **D-14:** Add `com.apple.developer.associated-domains` entitlement with `applinks:tuwa.app`.
- **D-15:** Custom URL scheme (`workload://template?code=XXXXXXXX`) as in-app fallback only — not the primary share mechanism.

### Claude's Discretion
- ShareImportPreviewSheet layout details and animation
- Whether code entry uses a separate sheet or an inline text field before preview
- Exact AASA JSON structure and landing page HTML/CSS
- Whether to show sharer's name in import preview (if owner_id resolves to a display name)
- `shared_templates` table index strategy (share_code unique index is mandatory; expires_at index for pg_cron is optional)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Template Model & Deep Copy
- `WorkloadApp/Models/WorkoutTemplate.swift` — Full template model hierarchy (WorkoutTemplate → ExerciseGroup → TemplateExercise → TemplateSet). `deepCopyGroups()` method is the pattern for import.

### Existing Code Patterns
- `WorkloadApp/Services/InviteService.swift` — 6-char code generation (`makeLocalCode()`), deep link parsing (`handleDeepLink()`), Supabase invite row creation. Pattern to mirror for share codes.
- `WorkloadApp/Views/WorkoutLog/TemplatePreviewSheet.swift` — Existing template preview layout (groups, exercises, sets). Reuse sub-views in ShareImportPreviewSheet.
- `WorkloadApp/Services/SyncService.swift` — `WorkoutTemplateRow` Codable struct (line ~1371) with `groupsJson` JSONB encoding. Pattern for serializing template to share payload.

### Sync & Backend
- `WorkloadApp/SupabaseConfig.swift` — Supabase URL and anon key config.
- `WorkloadApp/App/AppRouter.swift` — Deep link handling via `.onOpenURL`. Must add template share code route.

### Design System
- `DESIGN.md` — 0pt corners, no shadows, Alpino typography, 8pt spacing grid, ColorTokens.

### Requirements
- `.planning/REQUIREMENTS.md` — SHARE-01 through SHARE-05

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `InviteService.makeLocalCode()` — Random alphanumeric code generator. Extend from 6 to 8 chars.
- `InviteService.handleDeepLink()` — URL parsing for `workload://` scheme. Add template route.
- `WorkoutTemplate.deepCopyGroups()` — Deep copy all groups/exercises/sets with new UUIDs. Core of import logic.
- `TemplatePreviewSheet` — Template preview layout (name, sport, session type, weekday row, exercise groups). Extract sub-views for reuse.
- `WorkoutTemplateRow` (SyncService) — Codable struct for template JSON encoding/decoding. Reuse for share payload serialization.

### Established Patterns
- Sheets per flow: `TextTemplateImportSheet`, `TemplateEditorSheet`, `TemplatePickerSheet` — each flow has its own sheet.
- `@MainActor struct` with static methods for service logic (InviteService pattern).
- Supabase RPC/table operations via `client.from("table").insert/select/delete`.
- Deep links handled in `AppRouter.onOpenURL`.

### Integration Points
- `WorkoutLogView` toolbar — add "Import" button for share code entry.
- `AppRouter.swift` `.onOpenURL` — add universal link route for `tuwa.app/t/{code}`.
- `.entitlements` file — add `applinks:tuwa.app`.
- Supabase dashboard — create `shared_templates` table, RLS policies, pg_cron job.
- `tuwa.app` domain — deploy AASA file + fallback landing page.

</code_context>

<specifics>
## Specific Ideas

- App name is **Tuwa** — all user-facing strings, share banners, landing page must use this name. Never use Faros, Tonus, or Tutrice.
- Bundle ID is `com.tonus.app` (cannot change on live App Store listing). AASA appID must use this.
- Share link format: `https://tuwa.app/t/ABCD1234` — short and clean.
- Strip `targetWeightKg` from shared template data — no personal weight info leaks to recipient.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 15-template-sharing*
*Context gathered: 2026-05-13*
