import Foundation
import SwiftData

/// Handles persistence operations for WorkoutSession and related models.
@MainActor
final class WorkoutRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func saveSession(_ session: WorkoutSession) throws {
        session.recalculateDerivedFields()
        modelContext.insert(session)
        try modelContext.save()
    }

    func deleteSession(_ session: WorkoutSession) throws {
        modelContext.delete(session)
        try modelContext.save()
    }

    func fetchAllSessions() throws -> [WorkoutSession] {
        let descriptor = FetchDescriptor<WorkoutSession>(
            sortBy: [SortDescriptor(\.sessionDate, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchSessions(last days: Int) throws -> [WorkoutSession] {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: .now)!
        let predicate = #Predicate<WorkoutSession> { $0.sessionDate >= startDate }
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.sessionDate)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Fetch sessions within a date range (for weekly summary computation).
    func fetchSessions(from startDate: Date, to endDate: Date) throws -> [WorkoutSession] {
        let predicate = #Predicate<WorkoutSession> { $0.sessionDate >= startDate && $0.sessionDate < endDate }
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.sessionDate)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchUnsyncedSessions() throws -> [WorkoutSession] {
        let predicate = #Predicate<WorkoutSession> { !$0.isSynced }
        let descriptor = FetchDescriptor<WorkoutSession>(predicate: predicate)
        return try modelContext.fetch(descriptor)
    }
}
