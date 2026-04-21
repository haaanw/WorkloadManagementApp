import Foundation
import SwiftData

@Model
final class WorkloadSnapshot {
    @Attribute(.unique) var id: UUID
    var snapshotDate: Date
    var acuteLoad: Double
    var chronicLoad: Double
    var acwr: Double
    var tsb: Double
    var weeklyVolume: Double
    var loadSource: LoadSource
    var updatedAt: Date

    var athlete: Athlete?

    var zone: ACWRZone {
        ACWRZone.classify(acwr: acwr, ctl: chronicLoad)
    }

    init(
        id: UUID = UUID(),
        snapshotDate: Date = .now,
        acuteLoad: Double = 0,
        chronicLoad: Double = 0,
        acwr: Double = 0,
        tsb: Double = 0,
        weeklyVolume: Double = 0,
        loadSource: LoadSource = .srpe
    ) {
        self.id = id
        self.snapshotDate = snapshotDate
        self.acuteLoad = acuteLoad
        self.chronicLoad = chronicLoad
        self.acwr = acwr
        self.tsb = tsb
        self.weeklyVolume = weeklyVolume
        self.loadSource = loadSource
        self.updatedAt = .now
    }
}
