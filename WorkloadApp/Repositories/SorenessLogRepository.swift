import Foundation
import SwiftData

/// Persistence for the **local-only** niggle self-log (Phase 25, D-01).
///
/// v1.5 self-coached reset note: the visible niggle-logging UI was removed, but this local-only
/// log + its `SorenessLog` `@Model` are migration-sensitive and intentionally KEPT for a later
/// migration-aware cleanup pass.
///
/// `SorenessLog` is a local-only model (mirrors `CyclePredictionLog` / `MenstrualCycleSnapshot`).
/// This repository reads/writes it on-device only — it never encodes, uploads, or syncs niggle
/// data (no `import Supabase`, no encoder, no push/pull). The type name appears nowhere in
/// `SyncService.swift`.
///
/// ## Conventions
/// - `insert(...)` constructs + inserts the row **and saves** (self-contained, matching the
///   find-or-create+save convention of `CyclePredictionLogRepository.upsertPrediction`). Callers
///   need not call `save()` themselves.
/// - `fetchRecent(days:athlete:)` returns logs whose `date >= Calendar.startOfDay(now - days)`,
///   sorted **newest-first** (descending `date`). The Plan 03 derivation helper is order-agnostic;
///   newest-first is chosen for UI-friendliness.
/// - To avoid the iOS 26.1 in-memory SwiftData trap on optional to-one relationship `#Predicate`,
///   the date window is applied in the `FetchDescriptor` and the `athlete` filter is applied in
///   Swift after the fetch (never via an `athlete?.id` predicate).
@MainActor
final class SorenessLogRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Construct, insert, and save a new niggle log. Returns the inserted row.
    @discardableResult
    func insert(
        region: MuscleGroup,
        type: NiggleType,
        severity: Int,
        limitedTraining: Bool,
        note: String?,
        athlete: Athlete?
    ) -> SorenessLog {
        let log = SorenessLog(
            date: .now,
            regionRaw: region.rawValue,
            typeRaw: type.rawValue,
            severity: severity,
            limitedTraining: limitedTraining,
            note: note,
            athlete: athlete
        )
        modelContext.insert(log)
        try? modelContext.save()
        return log
    }

    /// All niggle logs from the last `days` days (inclusive of the start-of-day boundary), newest
    /// first. When `athlete` is non-nil, results are filtered to that athlete in Swift (no
    /// optional-relationship `#Predicate`, dodging the iOS 26.1 in-memory trap).
    func fetchRecent(days: Int, athlete: Athlete?) -> [SorenessLog] {
        let calendar = Calendar.current
        let windowStart = calendar.startOfDay(
            for: calendar.date(byAdding: .day, value: -days, to: .now) ?? .now
        )
        let descriptor = FetchDescriptor<SorenessLog>(
            predicate: #Predicate { $0.date >= windowStart },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let rows = (try? modelContext.fetch(descriptor)) ?? []
        guard let athlete else { return rows }
        let athleteId = athlete.id
        return rows.filter { $0.athlete?.id == athleteId }
    }

    func save() throws {
        try modelContext.save()
    }
}
