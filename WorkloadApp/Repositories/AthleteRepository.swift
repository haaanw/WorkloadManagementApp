import Foundation
import SwiftData

@MainActor
final class AthleteRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchCurrentAthlete() throws -> Athlete? {
        let descriptor = FetchDescriptor<Athlete>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try modelContext.fetch(descriptor).first
    }

    func updateAthlete(_ athlete: Athlete) throws {
        athlete.updatedAt = .now
        try modelContext.save()
    }
}
