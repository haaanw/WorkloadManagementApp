import Foundation
import SwiftData

/// Read-only access to `MenstrualCycleSnapshot` rows for the same-phase baseline
/// read-time join (Plan 18-02).
///
/// `MenstrualCycleSnapshot` is a **local-only** model (D-12 privacy). This repository
/// reads it into memory purely so the recovery pipeline can join phase-per-date against
/// `RecoverySnapshot` HRV/RHR — it never encodes, uploads, or syncs cycle data.
@MainActor
final class CycleSnapshotRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Fetch cycle snapshots within a date window, athlete-scoped, sorted ascending.
    ///
    /// Mirrors `RecoveryRepository.fetchRecoveryHistory` exactly so the two histories
    /// can be joined by date. Callers request a multi-cycle span (~3 cycles) for
    /// same-phase grouping.
    ///
    /// - Parameters:
    ///   - days: number of days back from now to include.
    ///   - athlete: optional athlete scope; when nil, no athlete predicate is applied.
    /// - Returns: matching `MenstrualCycleSnapshot` rows sorted by date ascending.
    func fetchCycleSnapshots(days: Int, athlete: Athlete? = nil) throws -> [MenstrualCycleSnapshot] {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: .now)!
        let descriptor: FetchDescriptor<MenstrualCycleSnapshot>
        if let athlete {
            let athleteId = athlete.id
            descriptor = FetchDescriptor<MenstrualCycleSnapshot>(
                predicate: #Predicate { $0.date >= startDate && $0.athlete?.id == athleteId },
                sortBy: [SortDescriptor(\.date)]
            )
        } else {
            descriptor = FetchDescriptor<MenstrualCycleSnapshot>(
                predicate: #Predicate { $0.date >= startDate },
                sortBy: [SortDescriptor(\.date)]
            )
        }
        return try modelContext.fetch(descriptor)
    }
}
