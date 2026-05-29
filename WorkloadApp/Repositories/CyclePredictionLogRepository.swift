import Foundation
import SwiftData

/// Persistence for the **local-only** shadow-mode prediction log (Phase 20, D-01/D-13).
///
/// `CyclePredictionLog` is a local-only model (mirrors `MenstrualCycleSnapshot` /
/// `CycleSnapshotRepository`). This repository reads/writes it on-device only — it never
/// encodes, uploads, or syncs shadow/cycle data (no `import Supabase`, no encoder, no push/pull).
@MainActor
final class CyclePredictionLogRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Find-or-create the Stage-1 row for an athlete on a given day, then apply `mutate`.
    /// Upserts by `Calendar.startOfDay(date)` + athlete (mirrors RecoveryRepository's
    /// upsert pattern) so re-running the pipeline the same day does not create duplicate rows.
    func upsertPrediction(
        date: Date,
        athlete: Athlete?,
        mutate: (CyclePredictionLog) -> Void
    ) throws {
        let day = Calendar.current.startOfDay(for: date)
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: day)!
        let descriptor: FetchDescriptor<CyclePredictionLog>
        if let athlete {
            let athleteId = athlete.id
            descriptor = FetchDescriptor<CyclePredictionLog>(
                predicate: #Predicate { $0.date >= day && $0.date < nextDay && $0.athlete?.id == athleteId }
            )
        } else {
            descriptor = FetchDescriptor<CyclePredictionLog>(
                predicate: #Predicate { $0.date >= day && $0.date < nextDay }
            )
        }

        if let existing = try modelContext.fetch(descriptor).first {
            mutate(existing)
            existing.updatedAt = .now
        } else {
            let row = CyclePredictionLog(date: day)
            row.athlete = athlete
            mutate(row)
            modelContext.insert(row)
        }
        try modelContext.save()
    }

    /// Unresolved rows whose prediction-target day is strictly before `date`'s day
    /// (i.e. yesterday and earlier), athlete-scoped. These are ready for Stage-2 resolution.
    func fetchUnresolved(olderThan date: Date, athlete: Athlete? = nil) throws -> [CyclePredictionLog] {
        let cutoff = Calendar.current.startOfDay(for: date)
        let descriptor: FetchDescriptor<CyclePredictionLog>
        if let athlete {
            let athleteId = athlete.id
            descriptor = FetchDescriptor<CyclePredictionLog>(
                predicate: #Predicate { $0.resolvedAt == nil && $0.date < cutoff && $0.athlete?.id == athleteId },
                sortBy: [SortDescriptor(\.date)]
            )
        } else {
            descriptor = FetchDescriptor<CyclePredictionLog>(
                predicate: #Predicate { $0.resolvedAt == nil && $0.date < cutoff },
                sortBy: [SortDescriptor(\.date)]
            )
        }
        return try modelContext.fetch(descriptor)
    }

    /// Resolved rows within a date window, athlete-scoped, sorted ascending — for MAE aggregation.
    func fetchResolved(days: Int, athlete: Athlete? = nil) throws -> [CyclePredictionLog] {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: .now)!
        let descriptor: FetchDescriptor<CyclePredictionLog>
        if let athlete {
            let athleteId = athlete.id
            descriptor = FetchDescriptor<CyclePredictionLog>(
                predicate: #Predicate { $0.resolvedAt != nil && $0.date >= startDate && $0.athlete?.id == athleteId },
                sortBy: [SortDescriptor(\.date)]
            )
        } else {
            descriptor = FetchDescriptor<CyclePredictionLog>(
                predicate: #Predicate { $0.resolvedAt != nil && $0.date >= startDate },
                sortBy: [SortDescriptor(\.date)]
            )
        }
        return try modelContext.fetch(descriptor)
    }

    func save() throws {
        try modelContext.save()
    }
}
