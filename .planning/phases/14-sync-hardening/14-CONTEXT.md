# Phase 14: Sync Hardening - Context

**Gathered:** 2026-05-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Make sync failures visible and isolated so that a problem pulling or pushing one entity type never silently corrupts or blocks other entity types. Replace all silent `try?` calls with structured `do/catch`, add per-entity-type sync timestamps, and surface sync health in the UI.

</domain>

<decisions>
## Implementation Decisions

### Error Handling
- **D-01:** Replace every pull-side `try?` in SyncService with `do/catch` that logs entity type, error description, and timestamp.
- **D-02:** Apply the same `do/catch` hardening to push-side methods (pushAthlete, pushWorkloadSnapshots, etc.) — not just pull. Both directions get structured error handling.
- **D-03:** Each individual pull/push helper must return a success/failure signal so the caller knows whether to advance that entity's timestamp.

### Per-Entity Timestamps
- **D-04:** Use UserDefaults keys per entity type (e.g., `lastSync_workouts`, `lastSync_templates`). Single timestamp per entity — no separate pull/push timestamps.
- **D-05:** Create a typed `SyncEntity` enum (`CaseIterable`) with all 10 entity types to avoid stringly-typed keys: workouts, templates, personalRecords, recoverySnapshots, wellnessCheckIns, workloadSnapshots, behaviorTags, coachRelationships, trainingProfiles, prescribedWorkouts.
- **D-06:** A failed pull/push for a given entity type must NOT advance that entity's timestamp. Only successful completion advances it.
- **D-07:** On sign-out or account switch, clear all per-entity sync timestamps.

### Error Visibility
- **D-08:** Add a subtle sync health indicator — small yellow dot badge on Profile tab icon when any entity type has sync issues.
- **D-09:** Tapping into Profile shows sync status detail (which entities succeeded, which failed, when).

### Retry & Recovery
- **D-10:** No immediate retry on failure. Failed entities automatically retry on the next foreground sync cycle (existing 15-minute cooldown via `shouldForegroundSync`).
- **D-11:** `shouldForegroundSync` logic should consider per-entity timestamps — if any entity is stale beyond threshold, trigger sync even if global cooldown hasn't elapsed.

### Claude's Discretion
- Typed wrapper struct/class design for SyncTimestampStore (exact API surface)
- Whether to store last error message per entity in UserDefaults or keep it in-memory only
- Sync status detail view layout and information density
- Whether `shouldForegroundSync` uses the oldest entity timestamp or checks each independently

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Sync Architecture
- `WorkloadApp/Services/SyncService.swift` — Current sync service (1248 lines). All `try?` calls to replace, pullAll/pushAll orchestration, existing `run()` helper pattern, `shouldForegroundSync` logic.
- `WorkloadApp/App/AppContainer.swift` — Dependency container where SyncService is instantiated. Integration point for sync state.
- `WorkloadApp/App/AppRouter.swift` — Calls pullAll/pushAll on foreground. Integration point for sync trigger logic.
- `WorkloadApp/App/WorkloadApp.swift` — ModelContainer setup with `fatalError` on failure. Context for why SwiftData SyncState was rejected.

### Requirements
- `.planning/REQUIREMENTS.md` — SYNC-01 (do/catch + logging), SYNC-02 (per-entity timestamps), SYNC-03 (partial failure isolation)

### Design System
- `DESIGN.md` — Design constraints for sync indicator UI (0pt corners, no shadows, color tokens, DM Sans/Alpino typography)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `SyncService.run()` helper (line 83-89) — Already wraps async operations with do/catch and `logFailure`. Can be extended to return Bool for success/failure.
- `SyncService.logFailure()` (line 79-81) — Existing error logging. Needs enhancement to include entity type and timestamp.
- `shouldForegroundSync` (line 74-77) — Existing cooldown check. Needs update to use per-entity timestamps.

### Established Patterns
- SyncService is `@MainActor struct` with static-like usage (instantiated with SupabaseClient)
- Push methods use `run()` helper; pull methods inline `try?` — inconsistency to resolve
- Entity-specific methods follow naming pattern: `pullWorkloadSnapshots`, `pushWorkloadSnapshots`
- UserDefaults already used for `lastSyncedAt` — same pattern extends naturally

### Integration Points
- `AppRouter.swift` — foreground sync trigger on `scenePhase.active`
- `AppContainer.swift` — SyncService initialization
- Profile tab — needs badge overlay for sync health indicator
- Profile settings — needs sync status detail view

</code_context>

<specifics>
## Specific Ideas

- Codex adversarial review confirmed UserDefaults as lowest-risk option for a shipping app. Key insight: SwiftData's `fatalError` on ModelContainer open makes @Model SyncState a launch risk.
- Codex recommended making each push/pull helper return success signal — this is more important than the storage backend choice.
- 10 entity types to track: workouts, templates, personalRecords, recoverySnapshots, wellnessCheckIns, workloadSnapshots, behaviorTags, coachRelationships, trainingProfiles, prescribedWorkouts

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 14-sync-hardening*
*Context gathered: 2026-05-10*
