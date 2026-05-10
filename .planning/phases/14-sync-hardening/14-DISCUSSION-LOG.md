# Phase 14: Sync Hardening - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-10
**Phase:** 14-sync-hardening
**Areas discussed:** Error visibility, Per-entity timestamps, Retry & recovery, Push-side hardening

---

## Error Visibility

| Option | Description | Selected |
|--------|-------------|----------|
| Console log only | Keep errors developer-visible only. Same as today but structured. | |
| Subtle sync indicator | Small icon/badge on Profile tab showing sync health. Tappable for detail. | ✓ |
| Toast on failure | Brief non-blocking banner when sync partially fails. | |

**User's choice:** Subtle sync indicator
**Notes:** Yellow dot badge on Profile tab icon when any entity has sync issues. Tapping into Profile shows sync status detail.

---

## Per-Entity Timestamps

| Option | Description | Selected |
|--------|-------------|----------|
| UserDefaults keys | Simple key-value per entity type. No migration needed. | ✓ |
| SwiftData @Model SyncState | Queryable, survives iCloud restore. Requires schema migration. | |
| Codable struct + JSON file | No SwiftData migration, survives backup/restore. | |

**User's choice:** UserDefaults keys per entity type (single timestamp, not separate pull/push)
**Notes:** User requested Codex adversarial review of the three options. Codex confirmed UserDefaults as lowest-risk, flagging SwiftData's `fatalError` on ModelContainer failure as a launch risk for Option B, and single-file corruption blast radius for Option C.

---

## Retry & Recovery

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-retry on next foreground sync | Failed entity retries on next app foreground (15-min cooldown). | ✓ |
| Immediate retry with backoff | 1-2 retries with exponential backoff. | |
| Manual retry only | User must trigger sync from settings. | |

**User's choice:** Auto-retry on next foreground sync
**Notes:** Leverages existing `shouldForegroundSync` 15-minute cooldown logic.

---

## Push-Side Hardening

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, harden both push and pull | Consistent error handling everywhere. Same SyncEntity enum covers both. | ✓ |
| Pull only, push stays as-is | Focus on pull per requirements. Push failures less critical. | |
| Pull now, push in follow-up | Reduce scope for this phase. | |

**User's choice:** Yes, harden both push and pull
**Notes:** Both directions get structured do/catch error handling and per-entity timestamps.

---

## Claude's Discretion

- SyncTimestampStore API design
- Last error storage (UserDefaults vs in-memory)
- Sync status detail view layout
- `shouldForegroundSync` per-entity logic

## Deferred Ideas

None
