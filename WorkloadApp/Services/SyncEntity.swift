import Foundation
import SwiftData

/// Identifies each entity type that participates in bidirectional sync.
/// Used for per-entity timestamp tracking and error reporting.
enum SyncEntity: String, CaseIterable, Identifiable {
    case workouts
    case templates
    case personalRecords
    case recoverySnapshots
    case wellnessCheckIns
    case workloadSnapshots
    case behaviorTags
    case trainingProfiles

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
        case .trainingProfiles: "Training Profile"
        }
    }
}

/// Direction of a sync operation, used in structured error logging.
enum SyncDirection: String {
    case pull, push
}

/// A durable record that a row was deleted here (v1.7.2 / audit H6).
///
/// Sync is a full upsert with no dirty flags, so before this the local store held no
/// evidence that a deletion had ever happened: delete a workout, and the next pull read
/// the row that was still on the server and put it straight back. The athlete could not
/// win — deleting again just repeated the cycle.
///
/// A tombstone is the missing evidence, and it is deliberately a SEPARATE record rather
/// than a `deletedAt` column on each model. Two reasons:
///
/// 1. **A full-row upsert cannot resurrect a tombstoned row.** With a `deleted_at` column
///    on the entity table, any device that still holds the row would push it back with
///    `deleted_at = NULL` and undo the deletion. The tombstone lives in its own table, so
///    no entity upsert can touch it.
/// 2. **Every local query keeps its current meaning.** No `@Query` or `FetchDescriptor` in
///    the app has to learn to filter deleted rows, so there is no way to miss one.
///
/// The record survives an offline delete, which is the case that made this a bug rather
/// than a race: the intent is on disk before the network is ever consulted.
@Model
final class SyncTombstone {
    var id: UUID = UUID()
    /// The id of the row that was deleted, in whichever table `entity` names.
    var rowId: UUID = UUID()
    /// `SyncEntity.rawValue`. Stored raw so an unknown future entity cannot fail a decode.
    var entityRaw: String = SyncEntity.workouts.rawValue
    var athleteId: UUID = UUID()
    var deletedAt: Date = Date.distantPast
    /// False until the server has been told. Retried every sync cycle until it is true.
    var isPushed: Bool = false

    init(
        id: UUID = UUID(),
        rowId: UUID,
        entity: SyncEntity,
        athleteId: UUID,
        deletedAt: Date = .now,
        isPushed: Bool = false
    ) {
        self.id = id
        self.rowId = rowId
        self.entityRaw = entity.rawValue
        self.athleteId = athleteId
        self.deletedAt = deletedAt
        self.isPushed = isPushed
    }

    var entity: SyncEntity? { SyncEntity(rawValue: entityRaw) }

    // MARK: - Recording

    /// Records the deletion of `rowId`, unless it is already recorded.
    ///
    /// Does NOT save — the caller's own `save()` commits the tombstone and the delete in
    /// one transaction, so the two can never come apart.
    @discardableResult
    static func record(
        rowId: UUID,
        entity: SyncEntity,
        athleteId: UUID,
        in context: ModelContext,
        isPushed: Bool = false
    ) -> SyncTombstone? {
        let entityRaw = entity.rawValue
        let predicate = #Predicate<SyncTombstone> { $0.rowId == rowId && $0.entityRaw == entityRaw }
        if let existing = try? context.fetch(FetchDescriptor(predicate: predicate)).first {
            return existing
        }
        let tombstone = SyncTombstone(
            rowId: rowId,
            entity: entity,
            athleteId: athleteId,
            isPushed: isPushed
        )
        context.insert(tombstone)
        return tombstone
    }

    // MARK: - Reading

    static func all(in context: ModelContext) -> [SyncTombstone] {
        (try? context.fetch(FetchDescriptor<SyncTombstone>())) ?? []
    }

    /// Row ids deleted here for `entity` — the set a pull must refuse to re-create.
    static func deletedRowIds(entity: SyncEntity, in context: ModelContext) -> Set<UUID> {
        let entityRaw = entity.rawValue
        let predicate = #Predicate<SyncTombstone> { $0.entityRaw == entityRaw }
        let rows = (try? context.fetch(FetchDescriptor(predicate: predicate))) ?? []
        return Set(rows.map(\.rowId))
    }

    /// Deletions the server has not been told about yet, grouped by entity.
    static func pendingByEntity(in context: ModelContext) -> [SyncEntity: [SyncTombstone]] {
        let predicate = #Predicate<SyncTombstone> { $0.isPushed == false }
        let rows = (try? context.fetch(FetchDescriptor(predicate: predicate))) ?? []
        return Dictionary(grouping: rows.filter { $0.entity != nil }, by: { $0.entity! })
    }

    // MARK: - Housekeeping

    /// How long a confirmed tombstone is kept.
    ///
    /// It only has to outlive the staleness of the oldest device that might still hold the
    /// row and push it back. Half a year is far beyond any realistic gap, and the records
    /// are a few dozen bytes each, so the ceiling is generous on purpose.
    static let retention: TimeInterval = 180 * 24 * 60 * 60

    /// Drops confirmed tombstones older than `retention`. Unpushed ones are never pruned —
    /// they are the deletion intent itself.
    static func prune(in context: ModelContext, now: Date = .now) {
        let cutoff = now.addingTimeInterval(-retention)
        let predicate = #Predicate<SyncTombstone> { $0.isPushed && $0.deletedAt < cutoff }
        let stale = (try? context.fetch(FetchDescriptor(predicate: predicate))) ?? []
        for tombstone in stale { context.delete(tombstone) }
    }
}
