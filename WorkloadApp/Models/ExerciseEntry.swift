import Foundation
import SwiftData

@Model
final class ExerciseEntry {
    @Attribute(.unique) var id: UUID
    var exerciseName: String
    var exerciseCategory: ExerciseCategory
    var muscleGroup: MuscleGroup?
    var orderIndex: Int

    @Relationship(deleteRule: .cascade, inverse: \SetRecord.exerciseEntry)
    var sets: [SetRecord] = []

    var session: WorkoutSession?

    /// Sorted sets by set index
    var sortedSets: [SetRecord] {
        sets.sorted { $0.setIndex < $1.setIndex }
    }

    /// Total volume for this exercise (load × reps, non-warmup only).
    /// Bodyweight movements carry their real load via `SetRecord.effectiveLoadKg` (v1.7.2).
    var totalVolume: Double {
        sets.filter { !$0.isWarmup }.reduce(0.0) { sum, set in sum + set.volume }
    }

    init(
        id: UUID = UUID(),
        exerciseName: String,
        exerciseCategory: ExerciseCategory = .compound,
        muscleGroup: MuscleGroup? = nil,
        orderIndex: Int = 0
    ) {
        self.id = id
        self.exerciseName = exerciseName
        self.exerciseCategory = exerciseCategory
        self.muscleGroup = muscleGroup
        self.orderIndex = orderIndex
    }
}
