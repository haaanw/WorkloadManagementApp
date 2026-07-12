import Foundation
import SwiftData

@Model
final class CustomExercise {
    @Attribute(.unique) var id: UUID
    var name: String
    var exerciseCategory: ExerciseCategory
    var muscleGroup: MuscleGroup?
    var sportType: SportType?
    var createdAt: Date

    var athlete: Athlete?

    init(
        id: UUID = UUID(),
        name: String,
        exerciseCategory: ExerciseCategory = .compound,
        muscleGroup: MuscleGroup,
        sportType: SportType? = nil
    ) {
        self.id = id
        self.name = name
        self.exerciseCategory = exerciseCategory
        self.muscleGroup = muscleGroup
        self.sportType = sportType
        self.createdAt = .now
    }
}
