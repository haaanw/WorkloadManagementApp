import Foundation
import SwiftData

@Model
final class WellnessCheckIn {
    @Attribute(.unique) var id: UUID
    var date: Date
    var sleepQuality: Int
    var soreness: Int
    var energy: Int
    var stress: Int
    var notes: String?
    var updatedAt: Date

    var athlete: Athlete?

    @Relationship(deleteRule: .cascade, inverse: \BehaviorTag.wellnessCheckIn)
    var behaviorTags: [BehaviorTag] = []

    var wellnessScore: Double {
        let sum = Double(sleepQuality + soreness + energy + stress)
        return (sum / 20.0) * 100.0
    }

    init(
        id: UUID = UUID(),
        date: Date = .now,
        sleepQuality: Int = 3,
        soreness: Int = 3,
        energy: Int = 3,
        stress: Int = 3,
        notes: String? = nil
    ) {
        self.id = id
        self.date = date
        self.sleepQuality = sleepQuality
        self.soreness = soreness
        self.energy = energy
        self.stress = stress
        self.notes = notes
        self.updatedAt = .now
    }
}
