import Foundation
import SwiftData

@Model
final class SetRecord {
    @Attribute(.unique) var id: UUID
    var setIndex: Int
    var reps: Int?
    var weightKg: Double?
    var durationSeconds: Int?
    var distanceMeters: Double?
    var rpe: Double?
    var rir: Int?               // Reps in Reserve (autoregulation)
    var isWarmup: Bool
    var isPersonalRecord: Bool
    var completedAt: Date

    var exerciseEntry: ExerciseEntry?

    /// Volume for this set (weight × reps)
    var volume: Double {
        (weightKg ?? 0) * Double(reps ?? 0)
    }

    /// Estimated 1RM using Epley formula: weight × (1 + reps/30)
    var estimated1RM: Double? {
        guard let weight = weightKg, weight > 0,
              let reps = reps, reps > 0 else { return nil }
        return weight * (1.0 + Double(reps) / 30.0)
    }

    init(
        id: UUID = UUID(),
        setIndex: Int = 0,
        reps: Int? = nil,
        weightKg: Double? = nil,
        durationSeconds: Int? = nil,
        distanceMeters: Double? = nil,
        rpe: Double? = nil,
        rir: Int? = nil,
        isWarmup: Bool = false,
        isPersonalRecord: Bool = false,
        completedAt: Date = .now
    ) {
        self.id = id
        self.setIndex = setIndex
        self.reps = reps
        self.weightKg = weightKg
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
        self.rpe = rpe
        self.rir = rir
        self.isWarmup = isWarmup
        self.isPersonalRecord = isPersonalRecord
        self.completedAt = completedAt
    }
}
