import Foundation
import SwiftData

@MainActor
final class WorkloadRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Upsert today's workload snapshot
    func upsertSnapshot(_ result: WorkloadCalculator.WorkloadResult, weeklyVolume: Double, loadSource: LoadSource) throws {
        let today = Calendar.current.startOfDay(for: .now)
        let predicate = #Predicate<WorkloadSnapshot> { $0.snapshotDate == today }
        let descriptor = FetchDescriptor<WorkloadSnapshot>(predicate: predicate)

        if let existing = try modelContext.fetch(descriptor).first {
            existing.acuteLoad = result.atl
            existing.chronicLoad = result.ctl
            existing.acwr = result.acwr
            existing.tsb = result.tsb
            existing.weeklyVolume = weeklyVolume
            existing.loadSource = loadSource
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
            modelContext.insert(snapshot)
        }
        try modelContext.save()
    }

    func fetchSnapshots(last days: Int) throws -> [WorkloadSnapshot] {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: .now)!
        let predicate = #Predicate<WorkloadSnapshot> { $0.snapshotDate >= startDate }
        let descriptor = FetchDescriptor<WorkloadSnapshot>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.snapshotDate)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Fetch workload snapshots within a date range (for weekly summary computation).
    func fetchSnapshots(from startDate: Date, to endDate: Date) throws -> [WorkloadSnapshot] {
        let predicate = #Predicate<WorkloadSnapshot> { $0.snapshotDate >= startDate && $0.snapshotDate < endDate }
        let descriptor = FetchDescriptor<WorkloadSnapshot>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.snapshotDate)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchLatestSnapshot() throws -> WorkloadSnapshot? {
        let descriptor = FetchDescriptor<WorkloadSnapshot>(
            sortBy: [SortDescriptor(\.snapshotDate, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).first
    }
}
