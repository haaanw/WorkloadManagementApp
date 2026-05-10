import Foundation
import SwiftData

@MainActor
final class BehaviorTagRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchTagsForDate(_ date: Date, athlete: Athlete? = nil) throws -> [BehaviorTag] {
        let start = Calendar.current.startOfDay(for: date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        let descriptor: FetchDescriptor<BehaviorTag>
        if let athlete {
            let athleteId = athlete.id
            descriptor = FetchDescriptor<BehaviorTag>(
                predicate: #Predicate { $0.date >= start && $0.date < end && $0.athlete?.id == athleteId },
                sortBy: [SortDescriptor(\.tagName)]
            )
        } else {
            descriptor = FetchDescriptor<BehaviorTag>(
                predicate: #Predicate { $0.date >= start && $0.date < end },
                sortBy: [SortDescriptor(\.tagName)]
            )
        }
        return try modelContext.fetch(descriptor)
    }

    func fetchAllTags(days: Int = 90, athlete: Athlete? = nil) throws -> [BehaviorTag] {
        let start = Calendar.current.date(byAdding: .day, value: -days, to: .now)!
        let descriptor: FetchDescriptor<BehaviorTag>
        if let athlete {
            let athleteId = athlete.id
            descriptor = FetchDescriptor<BehaviorTag>(
                predicate: #Predicate { $0.date >= start && $0.athlete?.id == athleteId },
                sortBy: [SortDescriptor(\.date)]
            )
        } else {
            descriptor = FetchDescriptor<BehaviorTag>(
                predicate: #Predicate { $0.date >= start },
                sortBy: [SortDescriptor(\.date)]
            )
        }
        return try modelContext.fetch(descriptor)
    }

    func fetchActiveTags(days: Int = 90, athlete: Athlete? = nil) throws -> [BehaviorTag] {
        let start = Calendar.current.date(byAdding: .day, value: -days, to: .now)!
        let descriptor: FetchDescriptor<BehaviorTag>
        if let athlete {
            let athleteId = athlete.id
            descriptor = FetchDescriptor<BehaviorTag>(
                predicate: #Predicate { $0.date >= start && $0.isActive && $0.athlete?.id == athleteId },
                sortBy: [SortDescriptor(\.date)]
            )
        } else {
            descriptor = FetchDescriptor<BehaviorTag>(
                predicate: #Predicate { $0.date >= start && $0.isActive },
                sortBy: [SortDescriptor(\.date)]
            )
        }
        return try modelContext.fetch(descriptor)
    }

    func fetchCustomTagNames(for athlete: Athlete) throws -> [String] {
        let athleteId = athlete.id
        let predicate = #Predicate<BehaviorTag> { $0.isCustom && $0.athlete?.id == athleteId }
        let descriptor = FetchDescriptor<BehaviorTag>(predicate: predicate)
        let tags = try modelContext.fetch(descriptor)
        return Array(Set(tags.map { $0.tagName })).sorted()
    }

    /// Upsert a behavior tag with T-03-01 mitigation: sanitize tag name before persisting.
    func upsertTag(_ tag: BehaviorTag) throws {
        tag.tagName = String(tag.tagName.trimmingCharacters(in: .whitespaces).prefix(20))
        tag.updatedAt = .now
        modelContext.insert(tag)
        try modelContext.save()
    }

    func deleteCustomTag(named tagName: String, for athlete: Athlete) throws {
        let athleteId = athlete.id
        let predicate = #Predicate<BehaviorTag> { $0.tagName == tagName && $0.isCustom && $0.athlete?.id == athleteId }
        let descriptor = FetchDescriptor<BehaviorTag>(predicate: predicate)
        let tags = try modelContext.fetch(descriptor)
        for tag in tags {
            modelContext.delete(tag)
        }
        try modelContext.save()
    }
}
