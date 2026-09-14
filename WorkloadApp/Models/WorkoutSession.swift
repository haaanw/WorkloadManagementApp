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

    /// The HealthKit workout this session was auto-logged from (v1.7.3, UAT round 1 · U4).
    ///
    /// ADDITIVE + NULLABLE, like `matchTierRaw`: every hand-logged session and every
    /// pre-1.7.3 row decodes to nil, so there is NO SwiftData migration and NO Supabase
    /// schema change. Deliberately excluded from `SyncService.WorkoutSessionRow` — it names
    /// a sample in the athlete's own Health store and means nothing on the server.
    ///
    /// It is the auto-import's idempotency key. `WatchWorkoutMatcher` refuses any candidate
    /// whose UUID is already on a session, so a lost query anchor, a reinstall or a second
    /// foreground pass can never produce the same session twice.
    var healthKitWorkoutUUID: UUID? = nil

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

    /// True when `totalVolume` holds METRES rather than kilogram-tonnage
    /// (v1.7.3 · UAT round 3 · U22).
    ///
    /// `totalVolume` is a dual-meaning field by construction: `recalculateDerivedFields`
    /// falls back to summed distance whenever the session moved no weight. A render site
    /// that prints the number with a literal " kg" therefore tells a 1.1 km walk that it
    /// moved 1,106 kilograms. This is the discriminator every such site must consult, and
    /// `SessionWorkReading` (WeightFormatter.swift) is the one place that consults it.
    ///
    /// The test is POSITIVE, not a fallback: some set must actually carry a distance, and no
    /// set may have produced strength volume. A session with NO local sets at all — a legacy
    /// row, a session pulled down by sync, a fixture — keeps its `totalVolume` as tonnage.
    /// The absence of sets says nothing about what the number means, and reading it as
    /// distance silently dropped such sessions out of the weekly tonnage sum.
    ///
    /// A session that moved nothing at all has a zero `totalVolume` and is neither tonnage
    /// nor distance — `false` here, and the caller falls through to the sRPE load.
    var volumeIsDistance: Bool {
        guard totalVolume > 0 else { return false }
        let sets = exerciseEntries.flatMap(\.sets)
        guard sets.contains(where: { $0.distanceMeters != nil }) else { return false }
        let strengthVolume = sets.filter { !$0.isWarmup }.reduce(0.0) { $0 + $1.volume }
        return strengthVolume <= 0
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
        // Volume: sum of (load × reps) across all non-warmup sets.
        //
        // "Load" rather than "weight" since v1.7.2 (audit — bodyweight option C): a bodyweight
        // movement now contributes body mass × the movement's fraction, so three sets of ten
        // pull-ups are no longer worth zero. `SetRecord.effectiveLoadKg` owns that rule; a
        // barbell lift is unchanged, and an athlete with no body mass on file gets the old
        // added-load-only number rather than a guess.
        let weightVolume = exerciseEntries.reduce(0.0) { entrySum, entry in
            entrySum + entry.sets.filter { !$0.isWarmup }.reduce(0.0) { setSum, set in
                setSum + set.volume
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
