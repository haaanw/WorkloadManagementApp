import Foundation

/// Observable store tracking per-entity sync timestamps and error state.
/// Timestamps persist in UserDefaults; errors are in-memory only (cleared on relaunch).
/// Used by SyncService for per-entity orchestration and by UI for sync status display.
@MainActor
@Observable
final class SyncTimestampStore {

    static let shared = SyncTimestampStore()

    // MARK: - Error State (in-memory only)

    /// Failures are keyed by entity AND direction (v1.7.1 incident, 2026-08-10): push and
    /// pull used to share one slot per entity, so the pull that followed a failed push in
    /// the same refresh cleared the error and painted the row green — a 100% push failure
    /// rendered as "all synced". A push failure is cleared only by a push success.
    private(set) var pushErrors: [SyncEntity: SyncError] = [:]
    private(set) var pullErrors: [SyncEntity: SyncError] = [:]

    /// Set when a sync attempt is refused before any per-entity work because the local
    /// athlete does not belong to the signed-in account (v1.7.1 incident: a seeded mock
    /// athlete pushed under an unknown id and every row was RLS-rejected while the screen
    /// stayed green). Rendered as a banner on SyncStatusView; cleared on a verified sync.
    private(set) var identityFault: IdentityFault?

    enum IdentityFault: Equatable {
        case noSession
        case unlinkedAthlete
        case accountMismatch
    }

    /// Observable mirror of the persisted success timestamps. UserDefaults writes do not
    /// invalidate SwiftUI views, so SyncStatusView used to keep rendering a stale
    /// relative time after a sync completed (the stuck "IN 0 SEC" defect, v1.7.1).
    private var successTimestamps: [SyncEntity: Date] = [:]

    /// Guards against concurrent sync cycles.
    var isSyncing: Bool = false

    struct SyncError {
        let message: String
        let timestamp: Date
        /// Compact slice of the underlying error (Postgrest message, decode context) so
        /// a failure is diagnosable from the device, not only from the Xcode console.
        let detail: String?
    }

    /// Display error for a row. The push failure outranks the pull failure: data that
    /// cannot leave the device is the data-loss scenario.
    func lastError(for entity: SyncEntity) -> SyncError? {
        pushErrors[entity] ?? pullErrors[entity]
    }

    var hasAnyFailure: Bool {
        identityFault != nil || !pushErrors.isEmpty || !pullErrors.isEmpty
    }

    /// True when local data may exist nowhere else: a failed push, or a sync refused on
    /// identity. Gates the sign-out wipe — sign-out cascade-deletes the local store, so
    /// with this set it would destroy the only copy.
    var hasPushRisk: Bool {
        identityFault != nil || !pushErrors.isEmpty
    }

    // MARK: - Timestamp Access

    func lastSuccess(for entity: SyncEntity) -> Date? {
        if let cached = successTimestamps[entity] { return cached }
        return UserDefaults.standard.object(forKey: "lastSync_\(entity.rawValue)") as? Date
    }

    // MARK: - Recording

    func recordSuccess(for entity: SyncEntity, direction: SyncDirection) {
        let now = Date()
        UserDefaults.standard.set(now, forKey: "lastSync_\(entity.rawValue)")
        successTimestamps[entity] = now
        switch direction {
        case .push: pushErrors[entity] = nil
        case .pull: pullErrors[entity] = nil
        }
    }

    func recordFailure(for entity: SyncEntity, direction: SyncDirection, error: String, detail: String? = nil) {
        let failure = SyncError(message: error, timestamp: Date(), detail: detail)
        switch direction {
        case .push: pushErrors[entity] = failure
        case .pull: pullErrors[entity] = failure
        }
    }

    func recordIdentityFault(_ fault: IdentityFault) {
        identityFault = fault
    }

    func clearIdentityFault() {
        identityFault = nil
    }

    // MARK: - Lifecycle

    /// Removes all persisted timestamps and clears in-memory errors.
    /// Call on sign-out to prevent stale state on next sign-in.
    func clearAll() {
        for entity in SyncEntity.allCases {
            UserDefaults.standard.removeObject(forKey: "lastSync_\(entity.rawValue)")
        }
        successTimestamps.removeAll()
        pushErrors.removeAll()
        pullErrors.removeAll()
        identityFault = nil
    }

    // MARK: - Sync Decision

    /// True if any entity has never synced, is stale beyond 15 minutes,
    /// or has a recorded failure requiring retry.
    var shouldSync: Bool {
        for entity in SyncEntity.allCases {
            guard let lastSuccess = lastSuccess(for: entity) else { return true }
            if Date().timeIntervalSince(lastSuccess) > 15 * 60 { return true }
        }
        if hasAnyFailure { return true }
        return false
    }
}
