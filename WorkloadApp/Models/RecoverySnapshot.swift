import Foundation
import SwiftData

@Model
final class RecoverySnapshot {
    @Attribute(.unique) var id: UUID
    var date: Date
    var hrvSDNN: Double?
    var restingHR: Double?
    var sleepDurationMinutes: Double?
    var sleepScore: Double?
    var bodyTemp: Double?
    var vo2Max: Double?
    var recoveryScore: Double
    var hrvBaseline: Double?
    var restingHRBaseline: Double?
    var dataSource: RecoveryDataSource
    var updatedAt: Date

    var athlete: Athlete?

    var zone: RecoveryZone {
        RecoveryZone.classify(score: recoveryScore)
    }

    init(
        id: UUID = UUID(),
        date: Date = .now,
        hrvSDNN: Double? = nil,
        restingHR: Double? = nil,
        sleepDurationMinutes: Double? = nil,
        sleepScore: Double? = nil,
        bodyTemp: Double? = nil,
        vo2Max: Double? = nil,
        recoveryScore: Double = 50,
        hrvBaseline: Double? = nil,
        restingHRBaseline: Double? = nil,
        dataSource: RecoveryDataSource = .healthKit
    ) {
        self.id = id
        self.date = date
        self.hrvSDNN = hrvSDNN
        self.restingHR = restingHR
        self.sleepDurationMinutes = sleepDurationMinutes
        self.sleepScore = sleepScore
        self.bodyTemp = bodyTemp
        self.vo2Max = vo2Max
        self.recoveryScore = recoveryScore
        self.hrvBaseline = hrvBaseline
        self.restingHRBaseline = restingHRBaseline
        self.dataSource = dataSource
        self.updatedAt = .now
    }
}
