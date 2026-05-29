import Foundation
import SwiftData

@Model
final class Athlete {
    @Attribute(.unique) var id: UUID
    var displayName: String
    var sportType: SportType
    var weightUnit: WeightUnit
    var acwrMethod: ACWRMethod
    var loadMetricPreference: LoadSource
    var maxHeartRate: Int?
    var dateOfBirth: Date?
    var createdAt: Date
    var updatedAt: Date
    var supabaseUserId: UUID?
    var isCoach: Bool = false
    var isCoachOnly: Bool = false
    var trainingFrequency: TrainingFrequency?
    var experienceLevel: ExperienceLevel?
    var isOnHormonalContraceptive: Bool?
    var isPregnant: Bool?
    var isLactating: Bool?
    // Additive local-only RED-S exclusion flags (Phase 19 D-11a). NOT synced (Phase 18 CR-01).
    var hasPCOS: Bool?
    var isPerimenopausal: Bool?

    @Relationship(deleteRule: .cascade, inverse: \WorkoutSession.athlete)
    var sessions: [WorkoutSession] = []

    @Relationship(deleteRule: .cascade, inverse: \WorkloadSnapshot.athlete)
    var workloadSnapshots: [WorkloadSnapshot] = []

    @Relationship(deleteRule: .cascade, inverse: \PersonalRecord.athlete)
    var personalRecords: [PersonalRecord] = []

    @Relationship(deleteRule: .cascade, inverse: \RecoverySnapshot.athlete)
    var recoverySnapshots: [RecoverySnapshot] = []

    @Relationship(deleteRule: .cascade, inverse: \WellnessCheckIn.athlete)
    var wellnessCheckIns: [WellnessCheckIn] = []

    @Relationship(deleteRule: .cascade, inverse: \CustomExercise.athlete)
    var customExercises: [CustomExercise] = []

    @Relationship(deleteRule: .cascade, inverse: \BehaviorTag.athlete)
    var behaviorTags: [BehaviorTag] = []

    @Relationship(deleteRule: .cascade, inverse: \MenstrualCycleSnapshot.athlete)
    var menstrualCycleSnapshots: [MenstrualCycleSnapshot] = []

    /// Estimated max HR using 220-age if dateOfBirth is set, otherwise user-configured value
    var estimatedMaxHR: Int {
        if let maxHR = maxHeartRate {
            return maxHR
        }
        if let dob = dateOfBirth {
            let age = Calendar.current.dateComponents([.year], from: dob, to: .now).year ?? 30
            return 220 - age
        }
        return 190 // conservative default
    }

    init(
        id: UUID = UUID(),
        displayName: String,
        sportType: SportType = .lifting,
        weightUnit: WeightUnit = .kg,
        acwrMethod: ACWRMethod = .ewma,
        loadMetricPreference: LoadSource = .srpe,
        maxHeartRate: Int? = nil,
        dateOfBirth: Date? = nil,
        supabaseUserId: UUID? = nil,
        isCoach: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.sportType = sportType
        self.weightUnit = weightUnit
        self.acwrMethod = acwrMethod
        self.loadMetricPreference = loadMetricPreference
        self.maxHeartRate = maxHeartRate
        self.dateOfBirth = dateOfBirth
        self.createdAt = .now
        self.updatedAt = .now
        self.supabaseUserId = supabaseUserId
        self.isCoach = isCoach
    }
}
