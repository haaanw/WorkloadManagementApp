# Phase 15: Template Sharing - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-13
**Phase:** 15-template-sharing
**Areas discussed:** Share code delivery, Backend storage, Import preview UX, Universal links

---

## Share Code Delivery

| Option | Description | Selected |
|--------|-------------|----------|
| Clipboard + Share Sheet | Copy button + iOS ShareLink wrapping code/link. Covers iMessage, AirDrop, WhatsApp. | ✓ |
| Clipboard only | Simple copy-to-clipboard, user pastes manually. Mirrors invite code pattern. | |
| In-app send | Built-in recipient picker from roster/contacts. Higher complexity. | |

**User's choice:** Clipboard + Share Sheet (Recommended)
**Notes:** None

---

## Backend Storage

| Option | Description | Selected |
|--------|-------------|----------|
| Denormalized JSON snapshot | New shared_templates table with full JSONB, share_code, expires_at. Independent from live template. | ✓ |
| Reference-based (template_id) | Store only template_id + share_code. Reads from workout_templates. Leaks RLS surface. | |
| Reuse invitations table | Add template_payload column. Semantic mixing, expiry conflicts. | |

**User's choice:** Denormalized JSON snapshot (Recommended)
**Notes:** None

---

## Import Preview UX

### Preview View

| Option | Description | Selected |
|--------|-------------|----------|
| New ShareImportPreviewSheet | Dedicated sheet with "Shared template" banner + import CTA. Matches one-sheet-per-flow pattern. | ✓ |
| Reuse TemplatePreviewSheet | Add isImportMode flag. No new file but couples semantics. | |

### Code Entry Location

| Option | Description | Selected |
|--------|-------------|----------|
| WorkoutLog tab toolbar | Import button near templates. Contextual for both modes. | ✓ |
| TemplatePickerSheet toolbar | Inside template selection flow. | |
| Profile settings row | Low-traffic location. Poor discoverability. | |

**User's choice:** New ShareImportPreviewSheet + WorkoutLog tab toolbar
**Notes:** None

---

## Universal Links

| Option | Description | Selected |
|--------|-------------|----------|
| Static host on tuwa.app | Deploy AASA + landing page via Netlify/Vercel/Cloudflare. Free tier. | ✓ |
| Supabase Edge Function | Serve AASA from Supabase. Unverified .well-known support. | |
| Custom URL scheme only | Keep workload:// scheme. No web fallback. | |

**User's choice:** Static host on tuwa.app
**Notes:** User corrected domain — tutrice.app is stale. App name is Tuwa, domain is tuwa.app. Never use Faros or Tutrice.

---

## Claude's Discretion

- ShareImportPreviewSheet layout details and animation
- Code entry sheet vs inline text field design
- AASA JSON structure and landing page HTML/CSS
- Whether to show sharer name in import preview
- Table index strategy for shared_templates

## Deferred Ideas

None
