import Foundation
import SwiftData

/// Persistence for the **local-only** shadow-mode prediction log (Phase 20, D-01/D-13; Phase 24).
///
/// `CyclePredictionLog` is a local-only model (mirrors `MenstrualCycleSnapshot`). This repository
/// reads/writes it on-device only — it never encodes, uploads, or syncs shadow/cycle data
/// (no `import Supabase`, no encoder, no push/pull).
///
/// v1.5 self-coached reset note: the live cycle-tracking service and its snapshot repository were
/// removed from the visible product, but this local-only log + its `@Model` are migration-sensitive
/// and intentionally KEPT for a later migration-aware cleanup pass.
///
/// ## Phase 24 date contract
/// Rows are keyed for upsert on `predictionDate` (the day the prediction is *made*); resolvability
/// and the resolved window are gated on `targetDate` (the day the prediction is *about*). This is
/// the storage half of the same-day-leak fix (D-03/D-04/D-05).
@MainActor
final class CyclePredictionLogRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Find-or-create the Stage-1 row for an athlete on a given **prediction day**, then apply
    /// `mutate`. Upserts by `Calendar.startOfDay(predictionDate)` + athlete (mirrors
    /// RecoveryRepository's upsert pattern) so re-running the pipeline the same day does not create
    /// duplicate rows (D-04). The model initializer derives `targetDate` from the prediction day.
    func upsertPrediction(
        predictionDate: Date,
        horizonDays: Int = 1,
        athlete: Athlete?,
        mutate: (CyclePredictionLog) -> Void
    ) throws {
        let day = Calendar.current.startOfDay(for: predictionDate)
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: day)!
        let descriptor: FetchDescriptor<CyclePredictionLog>
        if let athlete {
            let athleteId = athlete.id
            descriptor = FetchDescriptor<CyclePredictionLog>(
                predicate: #Predicate { $0.predictionDate >= day && $0.predictionDate < nextDay && $0.athlete?.id == athleteId }
            )
        } else {
            descriptor = FetchDescriptor<CyclePredictionLog>(
                predicate: #Predicate { $0.predictionDate >= day && $0.predictionDate < nextDay }
            )
        }

        if let existing = try modelContext.fetch(descriptor).first {
            mutate(existing)
            existing.updatedAt = .now
        } else {
            let row = CyclePredictionLog(predictionDate: day, predictionHorizonDays: horizonDays)
            row.athlete = athlete
            mutate(row)
            modelContext.insert(row)
        }
        try modelContext.save()
    }

    /// Unresolved rows whose **target** day is strictly before `date`'s day — i.e. the day the
    /// prediction is about has fully elapsed, so its actuals are observable (D-05). Athlete-scoped.
    /// This is the resolution half of the same-day-leak fix: a row written on D about D+1 only
    /// becomes resolvable once D+1 is in the past, and it is then joined on D+1's actuals (Stage 2).
    func fetchUnresolved(targetBefore date: Date, athlete: Athlete? = nil) throws -> [CyclePredictionLog] {
        let cutoff = Calendar.current.startOfDay(for: date)
        let descriptor: FetchDescriptor<CyclePredictionLog>
        if let athlete {
            let athleteId = athlete.id
            descriptor = FetchDescriptor<CyclePredictionLog>(
                predicate: #Predicate { $0.resolvedAt == nil && $0.targetDate < cutoff && $0.athlete?.id == athleteId },
                sortBy: [SortDescriptor(\.targetDate)]
            )
        } else {
            descriptor = FetchDescriptor<CyclePredictionLog>(
                predicate: #Predicate { $0.resolvedAt == nil && $0.targetDate < cutoff },
                sortBy: [SortDescriptor(\.targetDate)]
            )
        }
        return try modelContext.fetch(descriptor)
    }

    /// Resolved rows whose target day falls within a window, athlete-scoped, sorted ascending by
    /// `targetDate` (time order) — for MAE aggregation and the time-ordered metrics.
    func fetchResolved(days: Int, athlete: Athlete? = nil) throws -> [CyclePredictionLog] {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: .now)!
        let descriptor: FetchDescriptor<CyclePredictionLog>
        if let athlete {
            let athleteId = athlete.id
            descriptor = FetchDescriptor<CyclePredictionLog>(
                predicate: #Predicate { $0.resolvedAt != nil && $0.targetDate >= startDate && $0.athlete?.id == athleteId },
                sortBy: [SortDescriptor(\.targetDate)]
            )
        } else {
            descriptor = FetchDescriptor<CyclePredictionLog>(
                predicate: #Predicate { $0.resolvedAt != nil && $0.targetDate >= startDate },
                sortBy: [SortDescriptor(\.targetDate)]
            )
        }
        return try modelContext.fetch(descriptor)
    }

    func save() throws {
        try modelContext.save()
    }
}
