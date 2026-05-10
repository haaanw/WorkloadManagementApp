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

    func fetchAllSessions(athlete: Athlete? = nil) throws -> [WorkoutSession] {
        let descriptor: FetchDescriptor<WorkoutSession>
        if let athlete {
            let athleteId = athlete.id
            descriptor = FetchDescriptor<WorkoutSession>(
                predicate: #Predicate { $0.athlete?.id == athleteId },
                sortBy: [SortDescriptor(\.sessionDate, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<WorkoutSession>(
                sortBy: [SortDescriptor(\.sessionDate, order: .reverse)]
            )
        }
        return try modelContext.fetch(descriptor)
    }

    func fetchSessions(last days: Int, athlete: Athlete? = nil) throws -> [WorkoutSession] {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: .now)!
        let descriptor: FetchDescriptor<WorkoutSession>
        if let athlete {
            let athleteId = athlete.id
            descriptor = FetchDescriptor<WorkoutSession>(
                predicate: #Predicate { $0.sessionDate >= startDate && $0.athlete?.id == athleteId },
                sortBy: [SortDescriptor(\.sessionDate)]
            )
        } else {
            descriptor = FetchDescriptor<WorkoutSession>(
                predicate: #Predicate { $0.sessionDate >= startDate },
                sortBy: [SortDescriptor(\.sessionDate)]
            )
        }
        return try modelContext.fetch(descriptor)
    }

    /// Fetch sessions within a date range (for weekly summary computation).
    func fetchSessions(from startDate: Date, to endDate: Date, athlete: Athlete? = nil) throws -> [WorkoutSession] {
        let descriptor: FetchDescriptor<WorkoutSession>
        if let athlete {
            let athleteId = athlete.id
            descriptor = FetchDescriptor<WorkoutSession>(
                predicate: #Predicate {
                    $0.sessionDate >= startDate && $0.sessionDate < endDate && $0.athlete?.id == athleteId
                },
                sortBy: [SortDescriptor(\.sessionDate)]
            )
        } else {
            descriptor = FetchDescriptor<WorkoutSession>(
                predicate: #Predicate { $0.sessionDate >= startDate && $0.sessionDate < endDate },
                sortBy: [SortDescriptor(\.sessionDate)]
            )
        }
        return try modelContext.fetch(descriptor)
    }

    func fetchUnsyncedSessions() throws -> [WorkoutSession] {
        let predicate = #Predicate<WorkoutSession> { !$0.isSynced }
        let descriptor = FetchDescriptor<WorkoutSession>(predicate: predicate)
        return try modelContext.fetch(descriptor)
    }
}
