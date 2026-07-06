import Foundation
import SwiftData

@Model
final class WorkoutSession {
    @Attribute(.unique) var id: UUID
    var sessionDate: Date
    var sessionName: String?
    var sportType: SportType
    var durationSeconds: Int
    var sessionRPE: Double?
    var notes: String?
    var sessionType: SessionType = SessionType.strength
    var loggedByCoachId: UUID?          // nil = athlete self-logged
    var sourceTemplateId: UUID? = nil    // template this session was started from
    var isSynced: Bool

    /// v2.1 beachhead: match-tier raw value (`MatchTier.rawValue`) for `.match`-type sessions.
    /// ADDITIVE + NULLABLE by design: every pre-v2.1 row and non-match session decodes to nil,
    /// which the carry model treats as pickup — so there is NO SwiftData migration and NO
    /// Supabase schema change. Deliberately excluded from `SyncService.WorkoutSessionRow`
    /// (the sync bridge enumerates fields explicitly) — this field never syncs.
    var matchTierRaw: String? = nil

    /// Typed accessor over `matchTierRaw`. nil = no tier recorded (treated as pickup).
    var matchTier: MatchTier? {
        get { matchTierRaw.flatMap(MatchTier.init(rawValue:)) }
        set { matchTierRaw = newValue?.rawValue }
    }

    // External load (the work done)
    var totalVolume: Double          // kg × reps for lifting; meters for cardio
    var externalLoad: Double         // Normalized external load value

    // Internal load (physiological cost)
    var internalLoad: Double         // sRPE load = duration_min × sessionRPE
    var trimpScore: Double?          // HR zone-weighted TRIMP (nil if no HR data)

    // Derived workload values (computed at save time)
    var trainingStress: Double       // TSS = hours × RPE × (RPE/10)
    var acuteLoad: Double            // ATL snapshot at time of session
    var chronicLoad: Double          // CTL snapshot at time of session

    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \ExerciseEntry.session)
    var exerciseEntries: [ExerciseEntry] = []

    var athlete: Athlete?

    /// Sorted exercise entries by order index
    var sortedEntries: [ExerciseEntry] {
        exerciseEntries.sorted { $0.orderIndex < $1.orderIndex }
    }

    /// Duration in minutes
    var durationMinutes: Double {
        Double(durationSeconds) / 60.0
    }

    /// Duration in hours
    var durationHours: Double {
        Double(durationSeconds) / 3600.0
    }

    init(
        id: UUID = UUID(),
        sessionDate: Date = .now,
        sessionName: String? = nil,
        sportType: SportType = .lifting,
        durationSeconds: Int = 0,
        sessionRPE: Double? = nil,
        notes: String? = nil,
        sessionType: SessionType = .strength,
        loggedByCoachId: UUID? = nil
    ) {
        self.id = id
        self.sessionDate = sessionDate
        self.sessionName = sessionName
        self.sportType = sportType
        self.durationSeconds = durationSeconds
        self.sessionRPE = sessionRPE
        self.notes = notes
        self.sessionType = sessionType
        self.loggedByCoachId = loggedByCoachId
        self.isSynced = false
        self.totalVolume = 0
        self.externalLoad = 0
        self.internalLoad = 0
        self.trimpScore = nil
        self.trainingStress = 0
        self.acuteLoad = 0
        self.chronicLoad = 0
        self.createdAt = .now
        self.updatedAt = .now
    }

    /// Recalculate derived fields from exercise entries and RPE
    func recalculateDerivedFields() {
        // Volume: sum of (weight × reps) across all non-warmup sets
        let weightVolume = exerciseEntries.reduce(0.0) { entrySum, entry in
            entrySum + entry.sets.filter { !$0.isWarmup }.reduce(0.0) { setSum, set in
                let weight = set.weightKg ?? 0
                let reps = Double(set.reps ?? 0)
                return setSum + (weight * reps)
            }
        }

        // Distance: sum of all distance across entries (meters)
        let totalDistance = exerciseEntries.reduce(0.0) { entrySum, entry in
            entrySum + entry.sets.reduce(0.0) { setSum, set in
                setSum + (set.distanceMeters ?? 0)
            }
        }

        // Use weight volume for strength, distance for cardio
        totalVolume = weightVolume > 0 ? weightVolume : totalDistance
        externalLoad = totalVolume

        // Internal load (sRPE method) — works for all sport types
        if let rpe = sessionRPE {
            internalLoad = durationMinutes * rpe
            trainingStress = durationHours * rpe * (rpe / 10.0)
        }

        updatedAt = .now
    }
}
