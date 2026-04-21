import Foundation
import SwiftData

@Model
final class BehaviorTag {
    @Attribute(.unique) var id: UUID
    var date: Date
    var tagName: String
    var isActive: Bool
    var isCustom: Bool
    var createdAt: Date
    var updatedAt: Date

    var wellnessCheckIn: WellnessCheckIn?
    var athlete: Athlete?

    init(
        id: UUID = UUID(),
        date: Date = .now,
        tagName: String,
        isActive: Bool = true,
        isCustom: Bool = false
    ) {
        self.id = id
        self.date = date
        self.tagName = tagName
        self.isActive = isActive
        self.isCustom = isCustom
        self.createdAt = .now
        self.updatedAt = .now
    }
}
