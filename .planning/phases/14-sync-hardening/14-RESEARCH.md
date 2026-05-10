# Phase 14: Sync Hardening - Research

**Researched:** 2026-05-10
**Domain:** iOS sync service error handling, per-entity sync tracking, UserDefaults state management
**Confidence:** HIGH

## Summary

Phase 14 transforms SyncService from a fire-and-forget sync pipeline into an observable, fault-isolated system. The current SyncService (1248 lines) uses `try?` liberally on both network calls and local persistence operations, meaning any failure is silently swallowed and the global `lastSyncedAt` timestamp advances regardless. This creates a situation where a single entity type failure (e.g., a schema mismatch on `workout_templates`) can silently prevent that entity from ever syncing while the user sees no indication of trouble.

The work decomposes into three layers: (1) replace silent `try?` with structured `do/catch` that returns success/failure signals, (2) add a `SyncEntity` enum and `SyncTimestampStore` to track per-entity sync state via UserDefaults, and (3) surface sync health in the UI via a dot badge on the Profile tab and a detail view. All decisions are locked via CONTEXT.md -- no architectural alternatives need evaluation.

**Primary recommendation:** Restructure each pull/push helper to return `Bool` success signals, build a `SyncTimestampStore` wrapper around UserDefaults keyed by `SyncEntity`, then rewire `pullAll`/`pushAll` to iterate entities independently and update timestamps only on success.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Replace every pull-side `try?` in SyncService with `do/catch` that logs entity type, error description, and timestamp.
- **D-02:** Apply the same `do/catch` hardening to push-side methods (pushAthlete, pushWorkloadSnapshots, etc.) -- not just pull. Both directions get structured error handling.
- **D-03:** Each individual pull/push helper must return a success/failure signal so the caller knows whether to advance that entity's timestamp.
- **D-04:** Use UserDefaults keys per entity type (e.g., `lastSync_workouts`, `lastSync_templates`). Single timestamp per entity -- no separate pull/push timestamps.
- **D-05:** Create a typed `SyncEntity` enum (`CaseIterable`) with all 10 entity types to avoid stringly-typed keys: workouts, templates, personalRecords, recoverySnapshots, wellnessCheckIns, workloadSnapshots, behaviorTags, coachRelationships, trainingProfiles, prescribedWorkouts.
- **D-06:** A failed pull/push for a given entity type must NOT advance that entity's timestamp. Only successful completion advances it.
- **D-07:** On sign-out or account switch, clear all per-entity sync timestamps.
- **D-08:** Add a subtle sync health indicator -- small yellow dot badge on Profile tab icon when any entity type has sync issues.
- **D-09:** Tapping into Profile shows sync status detail (which entities succeeded, which failed, when).
- **D-10:** No immediate retry on failure. Failed entities automatically retry on the next foreground sync cycle (existing 15-minute cooldown via `shouldForegroundSync`).
- **D-11:** `shouldForegroundSync` logic should consider per-entity timestamps -- if any entity is stale beyond threshold, trigger sync even if global cooldown hasn't elapsed.

### Claude's Discretion
- Typed wrapper struct/class design for SyncTimestampStore (exact API surface)
- Whether to store last error message per entity in UserDefaults or keep it in-memory only
- Sync status detail view layout and information density
- Whether `shouldForegroundSync` uses the oldest entity timestamp or checks each independently

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SYNC-01 | All SyncService pull-side `try?` calls replaced with `do/catch` + error logging | Code audit identified 13 pull-side `try?` Supabase calls and 5 push-side `try?` calls. Pattern for replacement documented below. |
| SYNC-02 | Per-entity sync timestamps track last successful sync per data type | SyncEntity enum with 10 cases, SyncTimestampStore wrapper around UserDefaults. Pattern documented. |
| SYNC-03 | Partial sync failure for one entity type does not block other entity types from syncing | pullAll/pushAll restructured to iterate independently, each entity's success/failure handled in isolation. |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Error handling (do/catch) | Services (SyncService) | -- | All sync logic lives in SyncService; errors caught at the operation boundary |
| Per-entity timestamps | Services (SyncTimestampStore) | -- | UserDefaults wrapper; no persistence layer involvement |
| Sync isolation (partial failure) | Services (SyncService) | -- | pullAll/pushAll orchestration is entirely within SyncService |
| Sync health UI (dot badge) | Views (AppRouter/MainTabView) | Services (SyncTimestampStore) | Tab bar badge is a view concern; data comes from SyncTimestampStore |
| Sync status detail view | Views (SyncStatusView) | Services (SyncTimestampStore) | New SwiftUI view reads from SyncTimestampStore |
| Sign-out cleanup | App (AppContainer) | Services (SyncTimestampStore) | AppContainer.signOut() calls SyncTimestampStore.clearAll() |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 17+ | UI framework (tab badge, status view) | Project standard [VERIFIED: CLAUDE.md] |
| UserDefaults | iOS 17+ | Per-entity sync timestamp persistence | Locked decision D-04, validated by Codex review [VERIFIED: CONTEXT.md] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Foundation (Date, DateFormatter) | iOS 17+ | Timestamp storage and relative time formatting | All timestamp operations |

No new dependencies required. This phase is entirely internal refactoring + one new view.

## Architecture Patterns

### System Architecture Diagram

```
Foreground Trigger (scenePhase.active / pull-to-refresh)
    |
    v
shouldForegroundSync (checks per-entity timestamps)
    |
    v
pushAll / pullAll (iterates SyncEntity.allCases)
    |
    +---> pushWorkoutSessions() ---> Bool (success/fail)
    |         |                          |
    |         v                          v
    |     Supabase upsert         SyncTimestampStore.recordSuccess/recordFailure
    |
    +---> pullWorkloadSnapshots() ---> Bool (success/fail)
    |         |                            |
    |         v                            v
    |     Supabase select + SwiftData   SyncTimestampStore.recordSuccess/recordFailure
    |
    +---> ... (8 more entity types, each independent)
    |
    v
UI reads SyncTimestampStore
    |
    +---> MainTabView: dot badge on Profile tab (zoneCaution if any failures)
    +---> SyncStatusView: per-entity rows with status indicators
```

### Recommended Project Structure
```
WorkloadApp/
  Services/
    SyncService.swift          # Modified: do/catch, Bool returns, per-entity orchestration
    SyncTimestampStore.swift   # NEW: UserDefaults wrapper for per-entity sync state
    SyncEntity.swift           # NEW: CaseIterable enum with 10 entity types
  Views/
    Profile/
      SyncStatusView.swift     # NEW: sync detail view
      ProfileView.swift        # Modified: add "Sync Status" navigation row
  App/
    AppRouter.swift            # Modified: dot badge on Profile tab, updated shouldForegroundSync usage
    AppContainer.swift         # Modified: signOut clears sync timestamps
```

### Pattern 1: Pull Helper With Bool Return

**What:** Each pull/push method returns `Bool` indicating success, enabling the caller to conditionally advance that entity's timestamp.

**When to use:** Every individual pull and push method in SyncService.

**Example:**
```swift
// BEFORE (current):
private func pullWorkloadSnapshots(context: ModelContext, athlete: Athlete) async {
    guard let rows: [WorkloadSnapshotRow] = try? await client
        .from("workload_snapshots")
        .select()
        .eq("athlete_id", value: athlete.id)
        .execute()
        .value
    else { return }
    // ... upsert logic ...
    try? context.save()
}

// AFTER (hardened):
@discardableResult
private func pullWorkloadSnapshots(context: ModelContext, athlete: Athlete) async -> Bool {
    let rows: [WorkloadSnapshotRow]
    do {
        rows = try await client
            .from("workload_snapshots")
            .select()
            .eq("athlete_id", value: athlete.id)
            .execute()
            .value
    } catch {
        logFailure(.workloadSnapshots, .pull, error)
        return false
    }
    // ... upsert logic (internal try? on context.fetch per-row is acceptable) ...
    do {
        try context.save()
    } catch {
        logFailure(.workloadSnapshots, .pull, error)
        return false
    }
    return true
}
```
[VERIFIED: SyncService.swift code audit]

### Pattern 2: Orchestrator With Per-Entity Timestamp Update

**What:** `pullAll`/`pushAll` iterate entity types, call each helper, and update timestamps only on success.

**Example:**
```swift
func pullAll(context: ModelContext) async {
    guard let athlete = try? context.fetch(FetchDescriptor<Athlete>()).first else { return }

    let store = SyncTimestampStore.shared

    if await pullWorkloadSnapshots(context: context, athlete: athlete) {
        store.recordSuccess(for: .workloadSnapshots)
    } else {
        store.recordFailure(for: .workloadSnapshots, error: "Pull failed")
    }

    if await pullRecoverySnapshots(context: context, athlete: athlete) {
        store.recordSuccess(for: .recoverySnapshots)
    } else {
        store.recordFailure(for: .recoverySnapshots, error: "Pull failed")
    }

    // ... repeat for all 10 entity types ...
    // NO global lastSyncedAt update -- each entity tracks independently
}
```
[VERIFIED: pattern derived from CONTEXT.md D-03, D-04, D-06]

### Pattern 3: SyncTimestampStore

**What:** Typed wrapper around UserDefaults for per-entity sync state.

**Example:**
```swift
@MainActor
@Observable
final class SyncTimestampStore {
    static let shared = SyncTimestampStore()

    /// Last successful sync timestamp per entity
    func lastSuccess(for entity: SyncEntity) -> Date? {
        UserDefaults.standard.object(forKey: "lastSync_\(entity.rawValue)") as? Date
    }

    func recordSuccess(for entity: SyncEntity) {
        UserDefaults.standard.set(Date(), forKey: "lastSync_\(entity.rawValue)")
        // Clear any stored error
        lastErrors[entity] = nil
    }

    func recordFailure(for entity: SyncEntity, error: String) {
        lastErrors[entity] = SyncError(message: error, timestamp: Date())
    }

    /// In-memory only -- no need to persist error messages across launches
    private(set) var lastErrors: [SyncEntity: SyncError] = [:]

    var hasAnyFailure: Bool {
        !lastErrors.isEmpty
    }

    func clearAll() {
        for entity in SyncEntity.allCases {
            UserDefaults.standard.removeObject(forKey: "lastSync_\(entity.rawValue)")
        }
        lastErrors.removeAll()
    }

    struct SyncError {
        let message: String
        let timestamp: Date
    }
}
```
[ASSUMED: API surface design is Claude's discretion per CONTEXT.md]

### Anti-Patterns to Avoid
- **Global timestamp after partial failure:** Never set a single `lastSyncedAt` that represents "all entities synced." Each entity must track independently. The old `UserDefaults.standard.set(Date(), forKey: "lastSyncedAt")` at end of `pushAll`/`pullAll` must be removed.
- **Retrying inside the sync cycle:** D-10 explicitly says no immediate retry. Failed entities wait for the next foreground sync cycle.
- **Persisting error messages in UserDefaults:** Error strings are ephemeral. If the app relaunches, all entities start fresh (no stale error badges). Keep errors in-memory via `@Observable` property. Timestamps persist because they represent real sync state.
- **Catching errors on internal `context.fetch` per-row:** The `try?` on `context.fetch(FetchDescriptor(predicate: pred)).first` inside upsert loops is acceptable -- these are local SwiftData queries that rarely fail, and failing one row should not block the whole entity. The critical `try?` to replace are the Supabase network calls and the final `context.save()`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Relative time formatting | Custom "X min ago" logic | `RelativeDateTimeFormatter` | Handles localization, edge cases (future dates, boundaries) automatically |
| Sync state persistence | Raw string key management | `SyncTimestampStore` wrapper with `SyncEntity` enum | Avoids typos in UserDefaults keys, centralizes all sync state access |
| Tab badge overlay | Custom ZStack badge | SwiftUI `.overlay` with offset | Standard SwiftUI composition, no custom layout needed |

## Common Pitfalls

### Pitfall 1: Advancing Timestamp On Partial Entity Success
**What goes wrong:** An entity pull fetches rows from Supabase (succeeds) but `context.save()` fails. The timestamp advances because the network call succeeded, but local data is incomplete.
**Why it happens:** Treating "network success" as "sync success."
**How to avoid:** Return `true` only after both the network fetch AND the `context.save()` succeed. Wrap `context.save()` in its own `do/catch`.
**Warning signs:** Entities appear "synced" but local data doesn't match Supabase.

### Pitfall 2: Stale Error Badges After App Relaunch
**What goes wrong:** If errors are persisted in UserDefaults, the app shows a sync warning dot badge on launch before any sync has been attempted in the current session.
**Why it happens:** Persisted error state from a previous session lingers.
**How to avoid:** Keep error state in-memory only (`@Observable` property). On app launch, the error dictionary starts empty. The first sync cycle will populate it with current failures.
**Warning signs:** User sees yellow dot badge immediately on launch, then it disappears after first sync.

### Pitfall 3: Coach Methods Not Included In Entity Tracking
**What goes wrong:** `pullLinkedAthletes`, `pullAthleteSnapshots`, and `pushCoach*` methods are left with `try?` because they aren't called from `pullAll`/`pushAll`.
**Why it happens:** These methods are called from separate coach-specific flows, not the main sync cycle.
**How to avoid:** Harden these methods with `do/catch` too (D-02 says both directions), but they don't need per-entity timestamp tracking since they're coach-specific and don't run on the main sync cycle. Apply structured logging but not timestamp management.
**Warning signs:** Coach-mode sync failures remain invisible.

### Pitfall 4: `shouldForegroundSync` Always Returns True
**What goes wrong:** After removing the global `lastSyncedAt`, if `shouldForegroundSync` checks per-entity timestamps and ANY entity has never synced, it always returns `true`, causing sync to run on every foreground event.
**Why it happens:** New entity types or first-time installs have no timestamps.
**How to avoid:** D-11 says "if any entity is stale beyond threshold, trigger sync." Use the OLDEST entity timestamp (or `nil` if any has never synced) as the trigger. This is correct behavior -- if an entity has never synced, sync should run.
**Warning signs:** Sync running every time the app foregrounds (but this is actually correct for the "never synced" case; it only becomes a problem if the threshold is too short).

### Pitfall 5: Race Condition Between Pull-to-Refresh and Background Sync
**What goes wrong:** User pulls to refresh in SyncStatusView while a foreground sync is already in progress. Two sync cycles run simultaneously, causing duplicate writes.
**Why it happens:** No mutual exclusion on sync execution.
**How to avoid:** Add a simple `isSyncing` boolean guard in SyncService (or SyncTimestampStore). If sync is already running, skip the duplicate request.
**Warning signs:** Duplicate rows in SwiftData, context save conflicts.

## Code Examples

### SyncEntity Enum
```swift
// Source: CONTEXT.md D-05
enum SyncEntity: String, CaseIterable, Identifiable {
    case workouts
    case templates
    case personalRecords
    case recoverySnapshots
    case wellnessCheckIns
    case workloadSnapshots
    case behaviorTags
    case coachRelationships
    case trainingProfiles
    case prescribedWorkouts

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .workouts: "Workouts"
        case .templates: "Templates"
        case .personalRecords: "Personal Records"
        case .recoverySnapshots: "Recovery"
        case .wellnessCheckIns: "Wellness"
        case .workloadSnapshots: "Training Load"
        case .behaviorTags: "Behavior Tags"
        case .coachRelationships: "Coach Links"
        case .trainingProfiles: "Training Profile"
        case .prescribedWorkouts: "Prescribed Workouts"
        }
    }
}
```
[VERIFIED: entity list from CONTEXT.md D-05, display names from UI-SPEC]

### Enhanced logFailure
```swift
// Source: derived from existing SyncService.logFailure (line 79-81)
private func logFailure(_ entity: SyncEntity, _ direction: SyncDirection, _ error: Error) {
    let timestamp = ISO8601DateFormatter().string(from: Date())
    print("SyncService [\(timestamp)] \(direction.rawValue) \(entity.rawValue) error: \(error)")
}

private enum SyncDirection: String {
    case pull, push
}
```
[VERIFIED: existing logFailure pattern at SyncService.swift line 79-81]

### Tab Badge Overlay
```swift
// Source: UI-SPEC dot badge specification
ProfileView()
    .tabItem { Label("Profile", systemImage: "person.fill") }
    .overlay(alignment: .topTrailing) {
        if syncTimestampStore.hasAnyFailure {
            Circle()
                .fill(ColorTokens.zoneCaution)
                .frame(width: 8, height: 8)
                .offset(x: 8, y: -8)
        }
    }
```
[ASSUMED: exact SwiftUI overlay approach; may need adjustment for TabView child overlay behavior]

### shouldForegroundSync Updated
```swift
// Source: derived from CONTEXT.md D-11
var shouldForegroundSync: Bool {
    let store = SyncTimestampStore.shared
    // If any entity has never synced, sync immediately
    for entity in SyncEntity.allCases {
        guard let lastSuccess = store.lastSuccess(for: entity) else { return true }
        if Date().timeIntervalSince(lastSuccess) > 15 * 60 { return true }
    }
    // If any entity has a recorded failure, sync to retry
    if store.hasAnyFailure { return true }
    return false
}
```
[VERIFIED: D-11 logic requirement from CONTEXT.md]

## `try?` Audit: Complete Inventory

### Pull-Side Supabase Calls (MUST convert per SYNC-01)

| Line | Method | Current Pattern | Entity |
|------|--------|----------------|--------|
| 237 | pullWorkloadSnapshots | `guard let rows = try? await client...` | workloadSnapshots |
| 266 | pullRecoverySnapshots | `guard let rows = try? await client...` | recoverySnapshots |
| 299 | pullWellnessCheckIns | `guard let rows = try? await client...` | wellnessCheckIns |
| 327 | pullWorkoutSessions | `guard let rows = try? await client...` | workouts |
| 379 | pullBehaviorTags | `guard let rows = try? await client...` | behaviorTags |
| 547 | pullPersonalRecords | `guard let rows = try? await client...` | personalRecords |
| 777 | pullWorkoutTemplates | `guard let rows = try? await client...` | templates |
| 839 | pullTrainingProfile | `guard let row = try? await client...` | trainingProfiles |
| 931 | pullPrescribedWorkouts | `guard let rows = try? await client...` | prescribedWorkouts |
| 147 | pullAthlete | `guard let row = try? await client...` | (athlete profile -- not a tracked entity but needs hardening) |

### Push-Side `try?` Calls (MUST convert per D-02)

| Line | Method | Current Pattern | Entity |
|------|--------|----------------|--------|
| 142 | pushAthlete | `_ = try? await client.from("athletes").upsert(row).execute()` | (athlete profile) |
| 505 | pushCoachWorkloadSnapshot | `_ = try? await client...` | (coach-specific, no timestamp) |
| 511 | pushCoachRecoverySnapshot | `_ = try? await client...` | (coach-specific, no timestamp) |
| 517 | pushCoachPersonalRecord | `_ = try? await client...` | (coach-specific, no timestamp) |
| 523 | pushCoachWorkoutSession | `_ = try? await client...` | (coach-specific, no timestamp) |

### Push Methods Already Using `run()` Helper (Already have do/catch via `run()`)

| Method | Uses `run()` | Entity |
|--------|-------------|--------|
| pushWorkloadSnapshots | Yes (line 62) | workloadSnapshots |
| pushRecoverySnapshots | Yes (line 181) | recoverySnapshots |
| pushWellnessCheckIns | Yes (line 198) | wellnessCheckIns |
| pushPersonalRecords | Yes (line 213) | personalRecords |
| pushWorkoutSessions | Yes (line 229) | workouts |
| pushBehaviorTags | Yes (line 372) | behaviorTags |
| pushWorkoutTemplates | Yes (line 771) | templates |
| pushTrainingProfile | Yes (line 833) | trainingProfiles |
| pushPrescribedWorkouts | Yes (line 917) | prescribedWorkouts |

Note: The `run()` helper already catches errors but does not return success/failure. It needs to be modified to `return Bool`.

### Coach-Specific Pull Methods (Harden but no entity timestamp)

| Line | Method | Current Pattern |
|------|--------|----------------|
| 409 | pullLinkedAthletes | `guard let currentAthlete = try? ...` + `guard let rows = try? await client...` |
| 446 | pullLinkedAthleteProfile | `guard let row = try? await client...` |
| 979 | pullCoachPrescriptions | `guard let rows = try? await client...` |

### Internal `try?` Calls (KEEP as-is)

| Pattern | Count | Rationale |
|---------|-------|-----------|
| `try? context.fetch(FetchDescriptor(predicate:)).first` inside upsert loops | ~20 | Per-row local queries; failing one row should not abort entire entity |
| `try? context.save()` at end of pull methods | 10 | These MUST be converted to `do/catch` -- save failure means data loss |
| `try? context.save()` in bootstrapAthlete | 1 | Edge case -- bootstrapping is separate from sync cycle |

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Global `lastSyncedAt` | Per-entity timestamps | This phase | Failures are isolated, visible |
| Silent `try?` on network calls | Structured `do/catch` with entity+direction logging | This phase | Errors are diagnosable |
| `run()` helper returns Void | `run()` returns Bool | This phase | Caller can track success |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Storing error messages in-memory only (not UserDefaults) is sufficient -- users don't need to see pre-launch errors | Common Pitfalls, Code Examples | LOW -- worst case, badge appears slightly late after relaunch |
| A2 | Tab badge can be overlaid on TabView child using `.overlay` modifier | Code Examples | MEDIUM -- may need alternative approach if TabView clips overlays |
| A3 | SyncTimestampStore as singleton `@Observable` class is appropriate | Code Examples | LOW -- standard pattern for app-wide state in this codebase |
| A4 | `isSyncing` guard is needed for pull-to-refresh race condition | Common Pitfalls | LOW -- defensive measure, worst case is duplicate writes that are idempotent |

## Open Questions (RESOLVED)

1. **Tab badge overlay behavior in SwiftUI TabView** (RESOLVED)
   - What we know: SwiftUI's `.badge()` modifier only supports Int and String (red badge). Custom colored badges require overlay.
   - What's unclear: Whether `.overlay` on a TabView child view renders above the tab bar or is clipped to the content area.
   - Recommendation: If `.overlay` doesn't work, use a ZStack wrapping the TabView with absolute positioning, or apply `.badge("")` with a custom appearance. Test during implementation.

2. **Error classification for UI display** (RESOLVED)
   - What we know: UI-SPEC defines 5 error categories (network, auth, server, decode, unknown).
   - What's unclear: How to map Supabase SDK error types to these categories.
   - Recommendation: Inspect the error type in `logFailure` -- `URLError` maps to "Network unavailable", HTTP 401/403 to "Authentication expired", HTTP 5xx to "Server error", `DecodingError` to "Data format error", everything else to "Sync error". Implement during execution.

## Sources

### Primary (HIGH confidence)
- SyncService.swift (1248 lines) -- complete code audit of all `try?` calls, method signatures, and data flow
- CONTEXT.md -- all 11 locked decisions (D-01 through D-11)
- UI-SPEC.md -- dot badge spec, entity display names, error copy, layout constraints
- AppContainer.swift -- signOut cleanup pattern, SyncService initialization
- AppRouter.swift -- foreground sync trigger locations, TabView structure

### Secondary (MEDIUM confidence)
- DESIGN.md -- font (Alpino), spacing (8pt grid), color tokens (zoneCaution, zoneOptimal)

### Tertiary (LOW confidence)
- None

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- no new dependencies, pure internal refactoring
- Architecture: HIGH -- all decisions locked, code audit complete, patterns clear
- Pitfalls: HIGH -- derived directly from code audit of existing SyncService behavior

**Research date:** 2026-05-10
**Valid until:** 2026-06-10 (stable -- internal refactoring, no external dependency changes)
