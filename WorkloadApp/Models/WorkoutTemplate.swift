import Foundation
import SwiftData

// MARK: - WorkoutTemplate

@Model
final class WorkoutTemplate {
    @Attribute(.unique) var id: UUID
    var coachId: UUID
    var templateName: String
    var sportType: SportType
    var sessionType: SessionType
    var notes: String?
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Athlete Ownership (D-01)

    var isAthleteOwned: Bool = false
    var athleteId: UUID? = nil

    // MARK: - Template Management (D-02)

    var isFavorite: Bool = false
    var isArchived: Bool = false
    var lastUsedAt: Date? = nil
    var usageCount: Int = 0
    var scheduledDays: [Int] = []  // ISO 8601: 1=Mon...7=Sun

    @Relationship(deleteRule: .cascade, inverse: \ExerciseGroup.template)
    var groups: [ExerciseGroup] = []

    /// Groups sorted by order index
    var sortedGroups: [ExerciseGroup] {
        groups.sorted { $0.orderIndex < $1.orderIndex }
    }

    init(
        id: UUID = UUID(),
        coachId: UUID,
        templateName: String,
        sportType: SportType = .lifting,
        sessionType: SessionType = .strength,
        notes: String? = nil
    ) {
        self.id = id
        self.coachId = coachId
        self.templateName = templateName
        self.sportType = sportType
        self.sessionType = sessionType
        self.notes = notes
        self.createdAt = .now
        self.updatedAt = .now
    }

    /// Deep-copy all groups, exercises, and sets into new detached instances.
    /// Used when assigning a template to create a frozen snapshot.
    func deepCopyGroups() -> [ExerciseGroup] {
        sortedGroups.map { group in
            let newGroup = ExerciseGroup(
                groupName: group.groupName,
                orderIndex: group.orderIndex
            )
            newGroup.exercises = group.sortedExercises.map { exercise in
                let newExercise = TemplateExercise(
                    exerciseName: exercise.exerciseName,
                    exerciseCategory: exercise.exerciseCategory,
                    muscleGroup: exercise.muscleGroup,
                    orderIndex: exercise.orderIndex
                )
                newExercise.sets = exercise.sortedSets.map { set in
                    TemplateSet(
                        setIndex: set.setIndex,
                        targetReps: set.targetReps,
                        targetWeightKg: set.targetWeightKg,
                        targetDurationSeconds: set.targetDurationSeconds,
                        targetDistanceMeters: set.targetDistanceMeters,
                        targetRPE: set.targetRPE,
                        targetRIR: set.targetRIR,
                        isWarmup: set.isWarmup
                    )
                }
                return newExercise
            }
            return newGroup
        }
    }
}

// MARK: - ExerciseGroup

@Model
final class ExerciseGroup {
    @Attribute(.unique) var id: UUID
    var groupName: String
    var orderIndex: Int

    var template: WorkoutTemplate?
    var prescription: PrescribedWorkout?

    @Relationship(deleteRule: .cascade, inverse: \TemplateExercise.group)
    var exercises: [TemplateExercise] = []

    /// Exercises sorted by order index
    var sortedExercises: [TemplateExercise] {
        exercises.sorted { $0.orderIndex < $1.orderIndex }
    }

    init(
        id: UUID = UUID(),
        groupName: String = "Group A",
        orderIndex: Int = 0
    ) {
        self.id = id
        self.groupName = groupName
        self.orderIndex = orderIndex
    }
}

// MARK: - TemplateExercise

@Model
final class TemplateExercise {
    @Attribute(.unique) var id: UUID
    var exerciseName: String
    var exerciseCategory: ExerciseCategory
    var muscleGroup: MuscleGroup?
    var orderIndex: Int

    var group: ExerciseGroup?

    @Relationship(deleteRule: .cascade, inverse: \TemplateSet.exercise)
    var sets: [TemplateSet] = []

    /// Sets sorted by set index
    var sortedSets: [TemplateSet] {
        sets.sorted { $0.setIndex < $1.setIndex }
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

// MARK: - TemplateSet

@Model
final class TemplateSet {
    @Attribute(.unique) var id: UUID
    var setIndex: Int
    var targetReps: Int?
    var targetWeightKg: Double?
    var targetDurationSeconds: Int?
    var targetDistanceMeters: Double?
    var targetRPE: Double?
    var targetRIR: Int?
    var isWarmup: Bool

    var exercise: TemplateExercise?

    init(
        id: UUID = UUID(),
        setIndex: Int = 0,
        targetReps: Int? = nil,
        targetWeightKg: Double? = nil,
        targetDurationSeconds: Int? = nil,
        targetDistanceMeters: Double? = nil,
        targetRPE: Double? = nil,
        targetRIR: Int? = nil,
        isWarmup: Bool = false
    ) {
        self.id = id
        self.setIndex = setIndex
        self.targetReps = targetReps
        self.targetWeightKg = targetWeightKg
        self.targetDurationSeconds = targetDurationSeconds
        self.targetDistanceMeters = targetDistanceMeters
        self.targetRPE = targetRPE
        self.targetRIR = targetRIR
        self.isWarmup = isWarmup
    }
}
