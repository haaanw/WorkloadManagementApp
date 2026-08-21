import Foundation
import SwiftData

@MainActor
final class WorkloadRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Upsert today's workload snapshot
    func upsertSnapshot(
        _ result: WorkloadCalculator.WorkloadResult,
        weeklyVolume: Double,
        loadSource: LoadSource,
        athlete: Athlete? = nil
    ) throws {
        let today = Calendar.current.startOfDay(for: .now)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
        // Half-open day range, newest first (v1.7.2 / audit M5). Exact `== today` equality
        // missed any row whose date was written unfloored, so the upsert inserted a SECOND
        // row for the same day; the sort makes the survivor deterministic either way.
        let descriptor: FetchDescriptor<WorkloadSnapshot>
        if let athlete {
            let athleteId = athlete.id
            descriptor = FetchDescriptor<WorkloadSnapshot>(
                predicate: #Predicate { $0.snapshotDate >= today && $0.snapshotDate < tomorrow && $0.athlete?.id == athleteId },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<WorkloadSnapshot>(
                predicate: #Predicate { $0.snapshotDate >= today && $0.snapshotDate < tomorrow },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        }

        if let existing = try modelContext.fetch(descriptor).first {
            existing.acuteLoad = result.atl
            existing.chronicLoad = result.ctl
            existing.acwr = result.acwr
            existing.tsb = result.tsb
            existing.weeklyVolume = weeklyVolume
            existing.loadSource = loadSource
            existing.athlete = athlete ?? existing.athlete
            existing.updatedAt = .now
        } else {
            let snapshot = WorkloadSnapshot(
                snapshotDate: today,
                acuteLoad: result.atl,
                chronicLoad: result.ctl,
                acwr: result.acwr,
                tsb: result.tsb,
                weeklyVolume: weeklyVolume,
                loadSource: loadSource
            )
            snapshot.athlete = athlete
            modelContext.insert(snapshot)
        }
        try modelContext.save()
    }

    func fetchSnapshots(last days: Int, athlete: Athlete? = nil) throws -> [WorkloadSnapshot] {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: .now)!
        let descriptor: FetchDescriptor<WorkloadSnapshot>
        if let athlete {
            let athleteId = athlete.id
            descriptor = FetchDescriptor<WorkloadSnapshot>(
                predicate: #Predicate { $0.snapshotDate >= startDate && $0.athlete?.id == athleteId },
                sortBy: [SortDescriptor(\.snapshotDate)]
            )
        } else {
            descriptor = FetchDescriptor<WorkloadSnapshot>(
                predicate: #Predicate { $0.snapshotDate >= startDate },
                sortBy: [SortDescriptor(\.snapshotDate)]
            )
        }
        return try modelContext.fetch(descriptor)
    }

    /// Fetch workload snapshots within a date range (for weekly summary computation).
    func fetchSnapshots(from startDate: Date, to endDate: Date, athlete: Athlete? = nil) throws -> [WorkloadSnapshot] {
        let descriptor: FetchDescriptor<WorkloadSnapshot>
        if let athlete {
            let athleteId = athlete.id
            descriptor = FetchDescriptor<WorkloadSnapshot>(
                predicate: #Predicate {
                    $0.snapshotDate >= startDate && $0.snapshotDate < endDate && $0.athlete?.id == athleteId
                },
                sortBy: [SortDescriptor(\.snapshotDate)]
            )
        } else {
            descriptor = FetchDescriptor<WorkloadSnapshot>(
                predicate: #Predicate { $0.snapshotDate >= startDate && $0.snapshotDate < endDate },
                sortBy: [SortDescriptor(\.snapshotDate)]
            )
        }
        return try modelContext.fetch(descriptor)
    }

    func fetchLatestSnapshot(athlete: Athlete? = nil) throws -> WorkloadSnapshot? {
        let descriptor: FetchDescriptor<WorkloadSnapshot>
        if let athlete {
            let athleteId = athlete.id
            descriptor = FetchDescriptor<WorkloadSnapshot>(
                predicate: #Predicate { $0.athlete?.id == athleteId },
                sortBy: [SortDescriptor(\.snapshotDate, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<WorkloadSnapshot>(
                sortBy: [SortDescriptor(\.snapshotDate, order: .reverse)]
            )
        }
        return try modelContext.fetch(descriptor).first
    }
}
