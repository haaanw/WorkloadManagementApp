import Foundation

/// Observable store tracking per-entity sync timestamps and error state.
/// Timestamps persist in UserDefaults; errors are in-memory only (cleared on relaunch).
/// Used by SyncService for per-entity orchestration and by UI for sync status display.
@MainActor
@Observable
final class SyncTimestampStore {

    static let shared = SyncTimestampStore()

    // MARK: - Error State (in-memory only)

    private(set) var lastErrors: [SyncEntity: SyncError] = [:]

    /// Guards against concurrent sync cycles.
    var isSyncing: Bool = false

    struct SyncError {
        let message: String
        let timestamp: Date
    }

    var hasAnyFailure: Bool {
        !lastErrors.isEmpty
    }

    // MARK: - Timestamp Access

    func lastSuccess(for entity: SyncEntity) -> Date? {
        UserDefaults.standard.object(forKey: "lastSync_\(entity.rawValue)") as? Date
    }

    // MARK: - Recording

    func recordSuccess(for entity: SyncEntity) {
        UserDefaults.standard.set(Date(), forKey: "lastSync_\(entity.rawValue)")
        lastErrors[entity] = nil
    }

    func recordFailure(for entity: SyncEntity, error: String) {
        lastErrors[entity] = SyncError(message: error, timestamp: Date())
    }

    // MARK: - Lifecycle

    /// Removes all persisted timestamps and clears in-memory errors.
    /// Call on sign-out to prevent stale state on next sign-in.
    func clearAll() {
        for entity in SyncEntity.allCases {
            UserDefaults.standard.removeObject(forKey: "lastSync_\(entity.rawValue)")
        }
        lastErrors.removeAll()
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
