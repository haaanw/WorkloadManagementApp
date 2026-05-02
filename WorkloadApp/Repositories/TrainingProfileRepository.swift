import Foundation
import SwiftData

/// Persistence layer for TrainingProfile cold-start questionnaire data.
/// Follows the same pattern as AthleteRepository: @MainActor final class
/// with ModelContext dependency injection.
@MainActor
final class TrainingProfileRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Fetch the training profile for a specific athlete.
    /// Returns nil if no profile exists yet (cold-start not completed).
    func fetchProfile(athleteId: UUID) throws -> TrainingProfile? {
        let descriptor = FetchDescriptor<TrainingProfile>(
            predicate: #Predicate<TrainingProfile> { $0.athleteId == athleteId }
        )
        return try modelContext.fetch(descriptor).first
    }

    /// Save a new training profile after questionnaire completion.
    func saveProfile(_ profile: TrainingProfile) throws {
        modelContext.insert(profile)
        try modelContext.save()
    }

    /// Update an existing training profile (re-edit from ProfileView).
    func updateProfile(_ profile: TrainingProfile) throws {
        profile.updatedAt = .now
        try modelContext.save()
    }
}
