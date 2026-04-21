import Foundation
import SwiftData

@Model
final class CoachAthleteRelationship {
    @Attribute(.unique) var id: UUID
    var coachId: UUID
    var athleteId: UUID
    var status: RelationshipStatus
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        coachId: UUID,
        athleteId: UUID,
        status: RelationshipStatus = .pending
    ) {
        self.id = id
        self.coachId = coachId
        self.athleteId = athleteId
        self.status = status
        self.createdAt = .now
        self.updatedAt = .now
    }
}
