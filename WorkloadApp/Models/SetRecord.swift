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

    /// The load this set actually moved, in kg.
    ///
    /// For a bodyweight movement that is the athlete's body mass at the movement's fraction,
    /// plus whatever was added — see `BodyweightLoad` (v1.7.2 audit). Everything else is
    /// `weightKg` unchanged. Walks the relationship up to the athlete because a set's load is
    /// only knowable in the context of the body performing it.
    var effectiveLoadKg: Double? {
        BodyweightLoad.effectiveLoadKg(
            weightKg: weightKg,
            category: exerciseEntry?.exerciseCategory ?? .compound,
            exerciseName: exerciseEntry?.exerciseName ?? "",
            bodyMassKg: exerciseEntry?.session?.athlete?.bodyMassKg
        )
    }

    /// Volume for this set (load × reps)
    var volume: Double {
        (effectiveLoadKg ?? 0) * Double(reps ?? 0)
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
