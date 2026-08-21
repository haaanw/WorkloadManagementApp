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
    // Additive local-only "next match" scheduled date (v2.1 Track 1 item 3, ADR-0002).
    // ONE optional date — no recurrence, no forecasting. nil = no scheduled match, which is
    // a NORMAL state (the athlete's schedule is mixed: league weeks and pickup-only weeks).
    // Nullable ⇒ no SwiftData migration. NOT synced — SyncService.pushAthlete enumerates
    // AthleteRow fields explicitly, so this stays on-device by construction.
    var nextMatchDate: Date?

    /// Latest body mass, read from HealthKit (v1.7.2 audit — bodyweight "option C").
    ///
    /// Exists so a bodyweight set carries a real load: before this, 0 kg × 10 reps was 0, so
    /// three sets of ten pull-ups registered no volume at all. See `BodyweightLoad`.
    ///
    /// PRIVACY: this is a RAW HealthKit value, not a composite score, so it is device-local by
    /// construction and must never be added to `AthleteRow`. Nullable ⇒ no SwiftData migration;
    /// nil simply means "not read yet", and the load math degrades to added-load-only.
    var bodyMassKg: Double?
    /// When `bodyMassKg` was measured — the HealthKit sample's own date, not the read time, so
    /// a months-old weigh-in is visible as such rather than presented as current.
    var bodyMassRecordedAt: Date?

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
