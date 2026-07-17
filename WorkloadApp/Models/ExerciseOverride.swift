import Foundation
import SwiftData

/// User modification of a bundled catalog exercise (local-only — never synced).
///
/// Keyed by the catalog exercise NAME because exercise identity throughout the
/// app is the name string (`ExerciseEntry.exerciseName`, `PersonalRecord.exerciseName`,
/// `TemplateExercise.exerciseName`). `nil` fields mean "keep the catalog value";
/// `isHidden` removes the entry from the picker without touching history.
@Model
final class ExerciseOverride {
    /// Catalog exercise name this override applies to.
    @Attribute(.unique) var exerciseName: String
    /// Remapped muscle group; `nil` keeps the catalog value.
    var muscleGroup: MuscleGroup?
    /// Remapped category; `nil` keeps the catalog value.
    var exerciseCategory: ExerciseCategory?
    /// Hide this exercise from the picker entirely.
    var isHidden: Bool
    var createdAt: Date

    init(
        exerciseName: String,
        muscleGroup: MuscleGroup? = nil,
        exerciseCategory: ExerciseCategory? = nil,
        isHidden: Bool = false
    ) {
        self.exerciseName = exerciseName
        self.muscleGroup = muscleGroup
        self.exerciseCategory = exerciseCategory
        self.isHidden = isHidden
        self.createdAt = .now
    }
}
