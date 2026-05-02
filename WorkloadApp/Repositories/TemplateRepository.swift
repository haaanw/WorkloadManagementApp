import Foundation
import SwiftData

/// Handles persistence operations for athlete-owned WorkoutTemplates.
/// Instantiated at point of use with ModelContext (same pattern as WorkoutRepository).
@MainActor
final class TemplateRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Fetch non-archived athlete-owned templates, sorted by most recently updated
    func fetchAthleteTemplates(athleteId: UUID) throws -> [WorkoutTemplate] {
        // Use a simple predicate (athleteId match) and filter in memory.
        // Multi-condition #Predicate expressions exceed Swift type-checker limits
        // when compiled alongside large batched files.
        let predicate = #Predicate<WorkoutTemplate> {
            $0.athleteId == athleteId
        }
        let descriptor = FetchDescriptor<WorkoutTemplate>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
            .filter { $0.isAthleteOwned && !$0.isArchived }
    }

    /// Fetch only favorited athlete-owned templates
    func fetchFavorites(athleteId: UUID) throws -> [WorkoutTemplate] {
        // Fetch athlete-owned templates first, then filter favorites in memory.
        // A 4-condition #Predicate exceeds the Swift type-checker's complexity budget.
        let all = try fetchAthleteTemplates(athleteId: athleteId)
        return all
            .filter { $0.isFavorite && !$0.isArchived }
            .sorted { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }
    }

    /// Save a new athlete-owned template
    func save(_ template: WorkoutTemplate) throws {
        template.updatedAt = .now
        modelContext.insert(template)
        try modelContext.save()
    }

    /// Duplicate an existing template as athlete-owned
    func duplicate(_ template: WorkoutTemplate, athleteId: UUID) throws -> WorkoutTemplate {
        let copy = WorkoutTemplate(
            coachId: athleteId,
            templateName: "\(template.templateName) (Copy)",
            sportType: template.sportType,
            sessionType: template.sessionType,
            notes: template.notes
        )
        copy.isAthleteOwned = true
        copy.athleteId = athleteId
        copy.groups = template.deepCopyGroups()
        modelContext.insert(copy)
        try modelContext.save()
        return copy
    }

    /// Archive a template (soft delete)
    func archive(_ template: WorkoutTemplate) throws {
        template.isArchived = true
        template.updatedAt = .now
        try modelContext.save()
    }

    /// Permanently delete a template
    func delete(_ template: WorkoutTemplate) throws {
        modelContext.delete(template)
        try modelContext.save()
    }
}
