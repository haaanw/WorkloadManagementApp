import Foundation
import SwiftData

@Model
final class PersonalRecord {
    @Attribute(.unique) var id: UUID
    var exerciseName: String
    var recordType: PRType
    var value: Double
    var achievedAt: Date
    var sessionId: UUID?
    var previousValue: Double?
    var updatedAt: Date

    var athlete: Athlete?

    var improvement: Double? {
        guard let prev = previousValue, prev > 0 else { return nil }
        return value - prev
    }

    var improvementPercent: Double? {
        guard let prev = previousValue, prev > 0 else { return nil }
        return ((value - prev) / prev) * 100.0
    }

    init(
        id: UUID = UUID(),
        exerciseName: String,
        recordType: PRType = .maxWeight,
        value: Double,
        achievedAt: Date = .now,
        sessionId: UUID? = nil,
        previousValue: Double? = nil
    ) {
        self.id = id
        self.exerciseName = exerciseName
        self.recordType = recordType
        self.value = value
        self.achievedAt = achievedAt
        self.sessionId = sessionId
        self.previousValue = previousValue
        self.updatedAt = .now
    }
}
