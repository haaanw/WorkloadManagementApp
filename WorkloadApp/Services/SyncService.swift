import Foundation
import SwiftData
import Supabase

/// Bidirectional sync between SwiftData (local) and Supabase (cloud).
/// Strategy: full upsert — no dirty flags. Last-write-wins on updatedAt.
@MainActor
struct SyncService {

    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    // MARK: - Public API

    /// Push all local records to Supabase (idempotent upsert by id).
    func pushAll(context: ModelContext) async {
        guard let athlete = try? context.fetch(FetchDescriptor<Athlete>()).first else { return }
        await pushAthlete(athlete)
        await pushWorkloadSnapshots(context: context, athleteId: athlete.id)
        await pushRecoverySnapshots(context: context, athleteId: athlete.id)
        await pushWellnessCheckIns(context: context, athleteId: athlete.id)
        await pushPersonalRecords(context: context, athleteId: athlete.id)
        await pushWorkoutSessions(context: context, athleteId: athlete.id)
        await pushBehaviorTags(context: context, athleteId: athlete.id)
        await pushWorkoutTemplates(context: context, coachId: athlete.id)
        await pushPrescribedWorkouts(context: context)
        UserDefaults.standard.set(Date(), forKey: "lastSyncedAt")
    }

    /// Pull all Supabase records for current user and upsert into local SwiftData (last-write-wins).
    func pullAll(context: ModelContext) async {
        guard let athlete = try? context.fetch(FetchDescriptor<Athlete>()).first else { return }
        await pullAthlete(context: context, existingAthlete: athlete)
        await pullWorkloadSnapshots(context: context, athlete: athlete)
        await pullRecoverySnapshots(context: context, athlete: athlete)
        await pullWellnessCheckIns(context: context, athlete: athlete)
        await pullPersonalRecords(context: context, athlete: athlete)
        await pullWorkoutSessions(context: context, athlete: athlete)
        await pullBehaviorTags(context: context, athlete: athlete)
        await pullWorkoutTemplates(context: context, coachId: athlete.id)
        await pullPrescribedWorkouts(context: context, athleteId: athlete.id)
        UserDefaults.standard.set(Date(), forKey: "lastSyncedAt")
    }

    /// Push only WorkloadSnapshot records (called after WorkoutPipeline).
    func pushWorkloadSnapshots(context: ModelContext, athleteId: UUID) async {
        guard let snapshots = try? context.fetch(FetchDescriptor<WorkloadSnapshot>()) else { return }
        let rows = snapshots.map { WorkloadSnapshotRow(from: $0, athleteId: athleteId) }
        _ = try? await client.from("workload_snapshots").upsert(rows).execute()
    }

    /// Push only RecoverySnapshot + WellnessCheckIn (called after RecoveryPipeline).
    func pushRecoveryAndWellness(context: ModelContext, athleteId: UUID) async {
        await pushRecoverySnapshots(context: context, athleteId: athleteId)
        await pushWellnessCheckIns(context: context, athleteId: athleteId)
    }

    /// True if foreground sync should run (>15 min since last sync).
    var shouldForegroundSync: Bool {
        guard let last = UserDefaults.standard.object(forKey: "lastSyncedAt") as? Date else { return true }
        return Date().timeIntervalSince(last) > 15 * 60
    }

    // MARK: - Athlete push/pull

    /// Fetches the athlete profile from Supabase and creates it locally.
    /// Called on first sign-in to a fresh device (no local Athlete exists yet).
    /// Returns the newly-created local Athlete, or nil if not found.
    func bootstrapAthlete(context: ModelContext, userId: UUID) async -> Athlete? {
        guard let row: AthleteRow = try? await client
            .from("athletes")
            .select()
            .eq("user_id", value: userId)
            .single()
            .execute()
            .value
        else { return nil }
        let athlete = Athlete(
            id: row.id,
            displayName: row.displayName ?? "",
            sportType: SportType(rawValue: row.sportType ?? "") ?? .custom
        )
        athlete.supabaseUserId = row.userId
        athlete.isCoach = row.isCoach ?? false
        if let freq = row.trainingFrequency {
            athlete.trainingFrequency = TrainingFrequency(rawValue: freq)
        }
        if let exp = row.experienceLevel {
            athlete.experienceLevel = ExperienceLevel(rawValue: exp)
        }
        athlete.updatedAt = row.updatedAt
        context.insert(athlete)
        try? context.save()
        return athlete
    }

    func pushAthlete(_ athlete: Athlete) async {
        guard let userId = athlete.supabaseUserId else { return }
        let row = AthleteRow(
            id: athlete.id,
            userId: userId,
            displayName: athlete.displayName,
            sportType: athlete.sportType.rawValue,
            weightUnit: athlete.weightUnit.rawValue,
            acwrMethod: athlete.acwrMethod.rawValue,
            loadMetricPreference: athlete.loadMetricPreference.rawValue,
            maxHeartRate: athlete.maxHeartRate,
            dateOfBirth: athlete.dateOfBirth,
            isCoach: athlete.isCoach,
            trainingFrequency: athlete.trainingFrequency?.rawValue,
            experienceLevel: athlete.experienceLevel?.rawValue,
            createdAt: athlete.createdAt,
            updatedAt: athlete.updatedAt
        )
        _ = try? await client.from("athletes").upsert(row).execute()
    }

    private func pullAthlete(context: ModelContext, existingAthlete: Athlete) async {
        guard let userId = existingAthlete.supabaseUserId else { return }
        guard let row: AthleteRow = try? await client
            .from("athletes")
            .select()
            .eq("user_id", value: userId)
            .single()
            .execute()
            .value
        else { return }
        if existingAthlete.updatedAt > row.updatedAt { return }
        existingAthlete.displayName = row.displayName ?? existingAthlete.displayName
        existingAthlete.isCoach = row.isCoach ?? existingAthlete.isCoach
        if let freq = row.trainingFrequency {
            existingAthlete.trainingFrequency = TrainingFrequency(rawValue: freq)
        }
        if let exp = row.experienceLevel {
            existingAthlete.experienceLevel = ExperienceLevel(rawValue: exp)
        }
        existingAthlete.updatedAt = row.updatedAt
        try? context.save()
    }

    // MARK: - Push helpers

    private func pushRecoverySnapshots(context: ModelContext, athleteId: UUID) async {
        guard let snapshots = try? context.fetch(FetchDescriptor<RecoverySnapshot>()) else { return }
        let rows = snapshots.map { RecoverySnapshotRow(from: $0, athleteId: athleteId) }
        _ = try? await client.from("recovery_snapshots").upsert(rows).execute()
    }

    private func pushWellnessCheckIns(context: ModelContext, athleteId: UUID) async {
        guard let checkIns = try? context.fetch(FetchDescriptor<WellnessCheckIn>()) else { return }
        let rows = checkIns.map { WellnessCheckInRow(from: $0, athleteId: athleteId) }
        _ = try? await client.from("wellness_check_ins").upsert(rows).execute()
    }

    private func pushPersonalRecords(context: ModelContext, athleteId: UUID) async {
        guard let prs = try? context.fetch(FetchDescriptor<PersonalRecord>()) else { return }
        let rows = prs.map { PersonalRecordRow(from: $0, athleteId: athleteId) }
        _ = try? await client.from("personal_records").upsert(rows).execute()
    }

    private func pushWorkoutSessions(context: ModelContext, athleteId: UUID) async {
        guard let sessions = try? context.fetch(FetchDescriptor<WorkoutSession>()) else { return }
        let rows = sessions.map { WorkoutSessionRow(from: $0, athleteId: athleteId) }
        _ = try? await client.from("workout_sessions").upsert(rows).execute()
    }

    // MARK: - Pull helpers

    private func pullWorkloadSnapshots(context: ModelContext, athlete: Athlete) async {
        guard let rows: [WorkloadSnapshotRow] = try? await client
            .from("workload_snapshots")
            .select()
            .eq("athlete_id", value: athlete.id)
            .execute()
            .value
        else { return }

        for row in rows {
            let pred = #Predicate<WorkloadSnapshot> { $0.id == row.id }
            let existing = try? context.fetch(FetchDescriptor(predicate: pred)).first
            if let existing, existing.updatedAt > row.updatedAt { continue }
            let snap = existing ?? WorkloadSnapshot()
            snap.id = row.id
            snap.snapshotDate = row.snapshotDate
            snap.acuteLoad = row.acuteLoad ?? 0
            snap.chronicLoad = row.chronicLoad ?? 0
            snap.acwr = row.acwr ?? 0
            snap.tsb = row.tsb ?? 0
            snap.weeklyVolume = row.weeklyVolume ?? 0
            snap.loadSource = LoadSource(rawValue: row.loadSource ?? "") ?? .srpe
            snap.updatedAt = row.updatedAt
            snap.athlete = athlete
            if existing == nil { context.insert(snap) }
        }
        try? context.save()
    }

    private func pullRecoverySnapshots(context: ModelContext, athlete: Athlete) async {
        guard let rows: [RecoverySnapshotRow] = try? await client
            .from("recovery_snapshots")
            .select()
            .eq("athlete_id", value: athlete.id)
            .execute()
            .value
        else { return }

        for row in rows {
            let pred = #Predicate<RecoverySnapshot> { $0.id == row.id }
            let existing = try? context.fetch(FetchDescriptor(predicate: pred)).first
            if let existing, existing.updatedAt > row.updatedAt { continue }
            let snap = existing ?? RecoverySnapshot()
            snap.id = row.id
            snap.date = row.date
            snap.hrvSDNN = row.hrvSdnn
            snap.restingHR = row.restingHr
            snap.sleepDurationMinutes = row.sleepDurationMinutes
            snap.sleepScore = row.sleepScore
            snap.bodyTemp = row.bodyTemp
            snap.vo2Max = row.vo2Max
            snap.recoveryScore = row.recoveryScore ?? 50
            snap.hrvBaseline = row.hrvBaseline
            snap.restingHRBaseline = row.restingHrBaseline
            snap.dataSource = RecoveryDataSource(rawValue: row.dataSource ?? "") ?? .healthKit
            snap.updatedAt = row.updatedAt
            snap.athlete = athlete
            if existing == nil { context.insert(snap) }
        }
        try? context.save()
    }

    private func pullWellnessCheckIns(context: ModelContext, athlete: Athlete) async {
        guard let rows: [WellnessCheckInRow] = try? await client
            .from("wellness_check_ins")
            .select()
            .eq("athlete_id", value: athlete.id)
            .execute()
            .value
        else { return }

        for row in rows {
            let pred = #Predicate<WellnessCheckIn> { $0.id == row.id }
            let existing = try? context.fetch(FetchDescriptor(predicate: pred)).first
            if let existing, existing.updatedAt > row.updatedAt { continue }
            let checkIn = existing ?? WellnessCheckIn()
            checkIn.id = row.id
            checkIn.date = row.date
            checkIn.sleepQuality = row.sleepQuality ?? 3
            checkIn.soreness = row.soreness ?? 3
            checkIn.energy = row.energy ?? 3
            checkIn.stress = row.stress ?? 3
            checkIn.notes = row.notes
            checkIn.updatedAt = row.updatedAt
            checkIn.athlete = athlete
            if existing == nil { context.insert(checkIn) }
        }
        try? context.save()
    }

    private func pullWorkoutSessions(context: ModelContext, athlete: Athlete) async {
        guard let rows: [WorkoutSessionRow] = try? await client
            .from("workout_sessions")
            .select()
            .eq("athlete_id", value: athlete.id)
            .execute()
            .value
        else { return }

        for row in rows {
            let pred = #Predicate<WorkoutSession> { $0.id == row.id }
            let existing = try? context.fetch(FetchDescriptor(predicate: pred)).first
            if let existing, existing.updatedAt > row.updatedAt { continue }
            let session = existing ?? WorkoutSession()
            session.id = row.id
            session.sessionDate = row.date
            session.sessionName = row.sessionName
            session.sportType = SportType(rawValue: row.sportType ?? "") ?? .custom
            session.durationSeconds = row.durationSeconds ?? 0
            session.sessionRPE = row.sessionRpe
            session.notes = row.notes
            session.totalVolume = row.totalVolume
            session.externalLoad = row.externalLoad
            session.internalLoad = row.internalLoad
            session.trainingStress = row.trainingStress
            session.sessionType = SessionType(rawValue: row.sessionType) ?? .strength
            session.loggedByCoachId = row.loggedByCoachId
            session.updatedAt = row.updatedAt
            session.athlete = athlete
            if existing == nil { context.insert(session) }
        }
        try? context.save()
    }

    // MARK: - BehaviorTag push/pull

    private func pushBehaviorTags(context: ModelContext, athleteId: UUID) async {
        guard let tags = try? context.fetch(FetchDescriptor<BehaviorTag>()) else { return }
        let rows = tags.map { BehaviorTagRow(from: $0, athleteId: athleteId) }
        _ = try? await client.from("behavior_tags").upsert(rows).execute()
    }

    private func pullBehaviorTags(context: ModelContext, athlete: Athlete) async {
        guard let rows: [BehaviorTagRow] = try? await client
            .from("behavior_tags")
            .select()
            .eq("athlete_id", value: athlete.id)
            .execute()
            .value
        else { return }

        for row in rows {
            let pred = #Predicate<BehaviorTag> { $0.id == row.id }
            let existing = try? context.fetch(FetchDescriptor(predicate: pred)).first
            if let existing, existing.updatedAt > row.updatedAt { continue }
            let tag = existing ?? BehaviorTag(tagName: row.tagName)
            tag.id = row.id
            tag.date = row.date
            tag.tagName = row.tagName
            tag.isActive = row.isActive
            tag.isCustom = row.isCustom
            tag.createdAt = row.createdAt
            tag.updatedAt = row.updatedAt
            tag.athlete = athlete
            if existing == nil { context.insert(tag) }
        }
        try? context.save()
    }

    // MARK: - Coach pull methods

    /// Fetches accepted coach_athlete_relationships and linked athlete profiles for the current coach.
    func pullLinkedAthletes(context: ModelContext) async {
        guard let currentAthlete = try? context.fetch(FetchDescriptor<Athlete>()).first else { return }

        guard let rows: [CoachAthleteRelationshipRow] = try? await client
            .from("coach_athlete_relationships")
            .select()
            .eq("coach_id", value: currentAthlete.id)
            .eq("status", value: "accepted")
            .execute()
            .value
        else { return }

        for row in rows {
            let predicate = #Predicate<CoachAthleteRelationship> { $0.id == row.id }
            if let existing = try? context.fetch(FetchDescriptor(predicate: predicate)).first {
                existing.status = RelationshipStatus(rawValue: row.status) ?? .accepted
                existing.updatedAt = row.updatedAt
            } else {
                let rel = CoachAthleteRelationship(
                    id: row.id,
                    coachId: row.coachId,
                    athleteId: row.athleteId,
                    status: RelationshipStatus(rawValue: row.status) ?? .accepted
                )
                rel.createdAt = row.createdAt
                rel.updatedAt = row.updatedAt
                context.insert(rel)
            }
        }
        try? context.save()

        let linkedAthleteIds = rows.map { $0.athleteId }
        for athleteId in linkedAthleteIds {
            await pullLinkedAthleteProfile(athleteId: athleteId, context: context)
        }
    }

    private func pullLinkedAthleteProfile(athleteId: UUID, context: ModelContext) async {
        guard let row: AthleteRow = try? await client
            .from("athletes")
            .select()
            .eq("id", value: athleteId)
            .single()
            .execute()
            .value
        else { return }

        let predicate = #Predicate<Athlete> { $0.id == athleteId }
        if let existing = try? context.fetch(FetchDescriptor(predicate: predicate)).first {
            existing.displayName = row.displayName ?? existing.displayName
            existing.sportType = SportType(rawValue: row.sportType ?? "") ?? existing.sportType
            existing.isCoach = row.isCoach ?? existing.isCoach
            if let freq = row.trainingFrequency {
                existing.trainingFrequency = TrainingFrequency(rawValue: freq)
            }
            if let exp = row.experienceLevel {
                existing.experienceLevel = ExperienceLevel(rawValue: exp)
            }
            existing.updatedAt = row.updatedAt
        } else {
            let athlete = Athlete(
                id: row.id,
                displayName: row.displayName ?? "",
                sportType: SportType(rawValue: row.sportType ?? "") ?? .custom
            )
            athlete.supabaseUserId = row.userId
            athlete.isCoach = row.isCoach ?? false
            if let freq = row.trainingFrequency {
                athlete.trainingFrequency = TrainingFrequency(rawValue: freq)
            }
            if let exp = row.experienceLevel {
                athlete.experienceLevel = ExperienceLevel(rawValue: exp)
            }
            athlete.updatedAt = row.updatedAt
            context.insert(athlete)
        }
        try? context.save()
    }

    /// Fetches all snapshot data for a single linked athlete.
    func pullAthleteSnapshots(athleteId: UUID, context: ModelContext) async {
        guard let linkedAthlete = try?
            context.fetch(FetchDescriptor<Athlete>(predicate: #Predicate { $0.id == athleteId })).first
        else { return }

        await pullWorkloadSnapshots(context: context, athlete: linkedAthlete)
        await pullRecoverySnapshots(context: context, athlete: linkedAthlete)
        await pullWellnessCheckIns(context: context, athlete: linkedAthlete)
        await pullPersonalRecords(context: context, athlete: linkedAthlete)
        await pullWorkoutSessions(context: context, athlete: linkedAthlete)
    }

    // MARK: - Coach push methods

    /// Push a workload snapshot on behalf of a linked athlete (coach-initiated).
    func pushCoachWorkloadSnapshot(_ snapshot: WorkloadSnapshot, for athleteId: UUID) async {
        let row = WorkloadSnapshotRow(from: snapshot, athleteId: athleteId)
        _ = try? await client.from("workload_snapshots").upsert(row).execute()
    }

    /// Push a recovery snapshot on behalf of a linked athlete (coach-initiated).
    func pushCoachRecoverySnapshot(_ snapshot: RecoverySnapshot, for athleteId: UUID) async {
        let row = RecoverySnapshotRow(from: snapshot, athleteId: athleteId)
        _ = try? await client.from("recovery_snapshots").upsert(row).execute()
    }

    /// Push a personal record on behalf of a linked athlete (coach-initiated).
    func pushCoachPersonalRecord(_ pr: PersonalRecord, for athleteId: UUID) async {
        let row = PersonalRecordRow(from: pr, athleteId: athleteId)
        _ = try? await client.from("personal_records").upsert(row).execute()
    }

    /// Push a workout session on behalf of a linked athlete (coach-initiated).
    func pushCoachWorkoutSession(_ session: WorkoutSession, for athleteId: UUID) async {
        let row = WorkoutSessionRow(from: session, athleteId: athleteId)
        _ = try? await client.from("workout_sessions").upsert(row).execute()
    }

    /// Deletes a coach-athlete relationship from Supabase and removes the local SwiftData record.
    /// Callable by either party (coach or athlete) in the relationship.
    func removeRelationship(id: UUID, context: ModelContext) async throws {
        // 1. Delete from Supabase
        try await client
            .from("coach_athlete_relationships")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()

        // 2. Remove local SwiftData record
        let descriptor = FetchDescriptor<CoachAthleteRelationship>(
            predicate: #Predicate { $0.id == id }
        )
        if let local = try context.fetch(descriptor).first {
            context.delete(local)
        }
        try context.save()
    }

    private func pullPersonalRecords(context: ModelContext, athlete: Athlete) async {
        guard let rows: [PersonalRecordRow] = try? await client
            .from("personal_records")
            .select()
            .eq("athlete_id", value: athlete.id)
            .execute()
            .value
        else { return }

        for row in rows {
            let pred = #Predicate<PersonalRecord> { $0.id == row.id }
            let existing = try? context.fetch(FetchDescriptor(predicate: pred)).first
            if let existing, existing.updatedAt > row.updatedAt { continue }
            let pr = existing ?? PersonalRecord(exerciseName: row.exerciseName ?? "", value: row.value ?? 0)
            pr.id = row.id
            pr.exerciseName = row.exerciseName ?? ""
            pr.recordType = PRType(rawValue: row.recordType ?? "") ?? .maxWeight
            pr.value = row.value ?? 0
            pr.previousValue = row.previousValue
            pr.sessionId = row.sessionId
            pr.achievedAt = row.achievedAt ?? .now
            pr.updatedAt = row.updatedAt
            pr.athlete = athlete
            if existing == nil { context.insert(pr) }
        }
        try? context.save()
    }

struct AthleteRow: Codable {
    let id: UUID
    let userId: UUID
    let displayName: String?
    let sportType: String?
    let weightUnit: String?
    let acwrMethod: String?
    let loadMetricPreference: String?
    let maxHeartRate: Int?
    let dateOfBirth: Date?
    let isCoach: Bool?
    let trainingFrequency: String?
    let experienceLevel: String?
    let createdAt: Date
    let updatedAt: Date
}

struct BehaviorTagRow: Codable {
    let id: UUID
    let athleteId: UUID
    let date: Date
    let tagName: String
    let isActive: Bool
    let isCustom: Bool
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, date
        case athleteId = "athlete_id"
        case tagName = "tag_name"
        case isActive = "is_active"
        case isCustom = "is_custom"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from tag: BehaviorTag, athleteId: UUID) {
        self.id = tag.id
        self.athleteId = athleteId
        self.date = tag.date
        self.tagName = tag.tagName
        self.isActive = tag.isActive
        self.isCustom = tag.isCustom
        self.createdAt = tag.createdAt
        self.updatedAt = tag.updatedAt
    }
}

struct WorkloadSnapshotRow: Codable {
    let id: UUID
    let athleteId: UUID
    let snapshotDate: Date
    let acuteLoad: Double?
    let chronicLoad: Double?
    let acwr: Double?
    let tsb: Double?
    let weeklyVolume: Double?
    let loadSource: String?
    let updatedAt: Date

    init(from model: WorkloadSnapshot, athleteId: UUID) {
        self.id = model.id
        self.athleteId = athleteId
        self.snapshotDate = model.snapshotDate
        self.acuteLoad = model.acuteLoad
        self.chronicLoad = model.chronicLoad
        self.acwr = model.acwr
        self.tsb = model.tsb
        self.weeklyVolume = model.weeklyVolume
        self.loadSource = model.loadSource.rawValue
        self.updatedAt = model.updatedAt
    }
}

struct RecoverySnapshotRow: Codable {
    let id: UUID
    let athleteId: UUID
    let date: Date
    let recoveryScore: Double?
    let hrvSdnn: Double?
    let restingHr: Double?
    let sleepDurationMinutes: Double?
    let sleepScore: Double?
    let bodyTemp: Double?
    let vo2Max: Double?
    let hrvBaseline: Double?
    let restingHrBaseline: Double?
    let dataSource: String?
    let updatedAt: Date

    init(from model: RecoverySnapshot, athleteId: UUID) {
        self.id = model.id
        self.athleteId = athleteId
        self.date = model.date
        self.recoveryScore = model.recoveryScore
        self.hrvSdnn = model.hrvSDNN
        self.restingHr = model.restingHR
        self.sleepDurationMinutes = model.sleepDurationMinutes
        self.sleepScore = model.sleepScore
        self.bodyTemp = model.bodyTemp
        self.vo2Max = model.vo2Max
        self.hrvBaseline = model.hrvBaseline
        self.restingHrBaseline = model.restingHRBaseline
        self.dataSource = model.dataSource.rawValue
        self.updatedAt = model.updatedAt
    }
}

struct WellnessCheckInRow: Codable {
    let id: UUID
    let athleteId: UUID
    let date: Date
    let sleepQuality: Int?
    let soreness: Int?
    let energy: Int?
    let stress: Int?
    let notes: String?
    let updatedAt: Date

    init(from model: WellnessCheckIn, athleteId: UUID) {
        self.id = model.id
        self.athleteId = athleteId
        self.date = model.date
        self.sleepQuality = model.sleepQuality
        self.soreness = model.soreness
        self.energy = model.energy
        self.stress = model.stress
        self.notes = model.notes
        self.updatedAt = model.updatedAt
    }
}

struct PersonalRecordRow: Codable {
    let id: UUID
    let athleteId: UUID
    let exerciseName: String?
    let recordType: String?
    let value: Double?
    let previousValue: Double?
    let sessionId: UUID?
    let achievedAt: Date?
    let updatedAt: Date

    init(from model: PersonalRecord, athleteId: UUID) {
        self.id = model.id
        self.athleteId = athleteId
        self.exerciseName = model.exerciseName
        self.recordType = model.recordType.rawValue
        self.value = model.value
        self.previousValue = model.previousValue
        self.sessionId = model.sessionId
        self.achievedAt = model.achievedAt
        self.updatedAt = model.updatedAt
    }
}

struct WorkoutSessionRow: Codable {
    let id: UUID
    let athleteId: UUID
    let date: Date
    let sessionName: String?
    let sportType: String?
    let durationSeconds: Int?
    let sessionRpe: Double?
    let sessionType: String
    let loggedByCoachId: UUID?
    let notes: String?
    let totalVolume: Double
    let externalLoad: Double
    let internalLoad: Double
    let trainingStress: Double
    let updatedAt: Date

    init(from model: WorkoutSession, athleteId: UUID) {
        self.id = model.id
        self.athleteId = athleteId
        self.date = model.sessionDate
        self.sessionName = model.sessionName
        self.sportType = model.sportType.rawValue
        self.durationSeconds = model.durationSeconds
        self.sessionRpe = model.sessionRPE
        self.sessionType = model.sessionType.rawValue
        self.loggedByCoachId = model.loggedByCoachId
        self.notes = model.notes
        self.totalVolume = model.totalVolume
        self.externalLoad = model.externalLoad
        self.internalLoad = model.internalLoad
        self.trainingStress = model.trainingStress
        self.updatedAt = model.updatedAt
    }
}

    // MARK: - Template push/pull

    func pushWorkoutTemplates(context: ModelContext, coachId: UUID) async {
        guard let templates = try? context.fetch(
            FetchDescriptor<WorkoutTemplate>(predicate: #Predicate { $0.coachId == coachId })
        ) else { return }
        let rows = templates.map { WorkoutTemplateRow(from: $0) }
        _ = try? await client.from("workout_templates").upsert(rows).execute()
    }

    private func pullWorkoutTemplates(context: ModelContext, coachId: UUID) async {
        guard let rows: [WorkoutTemplateRow] = try? await client
            .from("workout_templates")
            .select()
            .eq("coach_id", value: coachId)
            .execute()
            .value
        else { return }

        for row in rows {
            let pred = #Predicate<WorkoutTemplate> { $0.id == row.id }
            let existing = try? context.fetch(FetchDescriptor(predicate: pred)).first
            if let existing, existing.updatedAt > row.updatedAt { continue }
            let template = existing ?? WorkoutTemplate(coachId: row.coachId, templateName: row.templateName)
            template.id = row.id
            template.coachId = row.coachId
            template.templateName = row.templateName
            template.sportType = SportType(rawValue: row.sportType) ?? .lifting
            template.sessionType = SessionType(rawValue: row.sessionType) ?? .strength
            template.notes = row.notes
            template.updatedAt = row.updatedAt
            template.createdAt = row.createdAt

            // Replace groups from JSON
            if existing != nil {
                for group in template.groups { context.delete(group) }
                template.groups = []
            }
            if let groupsJSON = row.groupsJson {
                template.groups = Self.decodeGroups(from: groupsJSON)
            }

            if existing == nil { context.insert(template) }
        }
        try? context.save()
    }

    // MARK: - Prescription push/pull

    func pushPrescribedWorkouts(context: ModelContext) async {
        guard let prescriptions = try? context.fetch(FetchDescriptor<PrescribedWorkout>()) else { return }
        let rows = prescriptions.map { PrescribedWorkoutRow(from: $0) }
        _ = try? await client.from("prescribed_workouts").upsert(rows).execute()
    }

    func pushPrescribedWorkout(_ prescription: PrescribedWorkout) async {
        let row = PrescribedWorkoutRow(from: prescription)
        _ = try? await client.from("prescribed_workouts").upsert(row).execute()
    }

    private func pullPrescribedWorkouts(context: ModelContext, athleteId: UUID) async {
        // Pull prescriptions assigned TO this athlete
        guard let rows: [PrescribedWorkoutRow] = try? await client
            .from("prescribed_workouts")
            .select()
            .eq("athlete_id", value: athleteId)
            .execute()
            .value
        else { return }

        for row in rows {
            let pred = #Predicate<PrescribedWorkout> { $0.id == row.id }
            let existing = try? context.fetch(FetchDescriptor(predicate: pred)).first
            if let existing, existing.updatedAt > row.updatedAt { continue }
            let rx = existing ?? PrescribedWorkout(
                coachId: row.coachId,
                athleteId: row.athleteId,
                scheduledDate: row.scheduledDate,
                templateName: row.templateName
            )
            rx.id = row.id
            rx.coachId = row.coachId
            rx.athleteId = row.athleteId
            rx.templateId = row.templateId
            rx.scheduledDate = row.scheduledDate
            rx.status = PrescriptionStatus(rawValue: row.status) ?? .assigned
            rx.completedSessionId = row.completedSessionId
            rx.notes = row.notes
            rx.templateName = row.templateName
            rx.sportType = SportType(rawValue: row.sportType) ?? .lifting
            rx.sessionType = SessionType(rawValue: row.sessionType) ?? .strength
            rx.updatedAt = row.updatedAt
            rx.createdAt = row.createdAt

            // Replace groups from JSON
            if existing != nil {
                for group in rx.groups { context.delete(group) }
                rx.groups = []
            }
            if let groupsJSON = row.groupsJson {
                rx.groups = Self.decodeGroups(from: groupsJSON)
            }

            if existing == nil { context.insert(rx) }
        }
        try? context.save()
    }

    // Also pull prescriptions the coach created (for coach-side status updates)
    func pullCoachPrescriptions(context: ModelContext, coachId: UUID) async {
        guard let rows: [PrescribedWorkoutRow] = try? await client
            .from("prescribed_workouts")
            .select()
            .eq("coach_id", value: coachId)
            .execute()
            .value
        else { return }

        for row in rows {
            let pred = #Predicate<PrescribedWorkout> { $0.id == row.id }
            let existing = try? context.fetch(FetchDescriptor(predicate: pred)).first
            if let existing, existing.updatedAt > row.updatedAt { continue }
            let rx = existing ?? PrescribedWorkout(
                coachId: row.coachId,
                athleteId: row.athleteId,
                scheduledDate: row.scheduledDate,
                templateName: row.templateName
            )
            rx.id = row.id
            rx.coachId = row.coachId
            rx.athleteId = row.athleteId
            rx.templateId = row.templateId
            rx.scheduledDate = row.scheduledDate
            rx.status = PrescriptionStatus(rawValue: row.status) ?? .assigned
            rx.completedSessionId = row.completedSessionId
            rx.notes = row.notes
            rx.templateName = row.templateName
            rx.sportType = SportType(rawValue: row.sportType) ?? .lifting
            rx.sessionType = SessionType(rawValue: row.sessionType) ?? .strength
            rx.updatedAt = row.updatedAt
            rx.createdAt = row.createdAt

            // Replace groups from JSON
            if existing != nil {
                for group in rx.groups { context.delete(group) }
                rx.groups = []
            }
            if let groupsJSON = row.groupsJson {
                rx.groups = Self.decodeGroups(from: groupsJSON)
            }

            if existing == nil { context.insert(rx) }
        }
        try? context.save()
    }

    // MARK: - Group JSON helpers

    static func encodeGroups(_ groups: [ExerciseGroup]) -> String? {
        let dtos = groups.sorted(by: { $0.orderIndex < $1.orderIndex }).map { GroupDTO(from: $0) }
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(dtos) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func decodeGroups(from json: String) -> [ExerciseGroup] {
        let decoder = JSONDecoder()
        guard let data = json.data(using: .utf8),
              let dtos = try? decoder.decode([GroupDTO].self, from: data) else { return [] }
        return dtos.enumerated().map { index, dto in
            let group = ExerciseGroup(groupName: dto.groupName, orderIndex: index)
            group.exercises = dto.exercises.enumerated().map { eIdx, exDTO in
                let exercise = TemplateExercise(
                    exerciseName: exDTO.exerciseName,
                    exerciseCategory: ExerciseCategory(rawValue: exDTO.exerciseCategory) ?? .compound,
                    muscleGroup: exDTO.muscleGroup.flatMap { MuscleGroup(rawValue: $0) },
                    orderIndex: eIdx
                )
                exercise.sets = exDTO.sets.enumerated().map { sIdx, setDTO in
                    TemplateSet(
                        setIndex: sIdx,
                        targetReps: setDTO.targetReps,
                        targetWeightKg: setDTO.targetWeightKg,
                        targetDurationSeconds: setDTO.targetDurationSeconds,
                        targetDistanceMeters: setDTO.targetDistanceMeters,
                        targetRPE: setDTO.targetRPE,
                        targetRIR: setDTO.targetRIR,
                        isWarmup: setDTO.isWarmup
                    )
                }
                return exercise
            }
            return group
        }
    }

}

// MARK: - Coach Rows

private struct CoachAthleteRelationshipRow: Codable {
    let id: UUID
    let coachId: UUID
    let athleteId: UUID
    let status: String
    let createdAt: Date
    let updatedAt: Date
}

// MARK: - Template Row

struct WorkoutTemplateRow: Codable {
    let id: UUID
    let coachId: UUID
    let templateName: String
    let sportType: String
    let sessionType: String
    let notes: String?
    let groupsJson: String?
    let createdAt: Date
    let updatedAt: Date

    init(from model: WorkoutTemplate) {
        self.id = model.id
        self.coachId = model.coachId
        self.templateName = model.templateName
        self.sportType = model.sportType.rawValue
        self.sessionType = model.sessionType.rawValue
        self.notes = model.notes
        self.groupsJson = SyncService.encodeGroups(model.groups)
        self.createdAt = model.createdAt
        self.updatedAt = model.updatedAt
    }
}

// MARK: - Prescription Row

struct PrescribedWorkoutRow: Codable {
    let id: UUID
    let coachId: UUID
    let athleteId: UUID
    let templateId: UUID?
    let scheduledDate: Date
    let status: String
    let completedSessionId: UUID?
    let notes: String?
    let templateName: String
    let sportType: String
    let sessionType: String
    let groupsJson: String?
    let createdAt: Date
    let updatedAt: Date

    init(from model: PrescribedWorkout) {
        self.id = model.id
        self.coachId = model.coachId
        self.athleteId = model.athleteId
        self.templateId = model.templateId
        self.scheduledDate = model.scheduledDate
        self.status = model.status.rawValue
        self.completedSessionId = model.completedSessionId
        self.notes = model.notes
        self.templateName = model.templateName
        self.sportType = model.sportType.rawValue
        self.sessionType = model.sessionType.rawValue
        self.groupsJson = SyncService.encodeGroups(model.groups)
        self.createdAt = model.createdAt
        self.updatedAt = model.updatedAt
    }
}

// MARK: - Group DTO for JSON encoding

private struct GroupDTO: Codable {
    let groupName: String
    let exercises: [ExerciseDTO]

    init(from group: ExerciseGroup) {
        self.groupName = group.groupName
        self.exercises = group.sortedExercises.map { ExerciseDTO(from: $0) }
    }
}

private struct ExerciseDTO: Codable {
    let exerciseName: String
    let exerciseCategory: String
    let muscleGroup: String?
    let sets: [SetDTO]

    init(from exercise: TemplateExercise) {
        self.exerciseName = exercise.exerciseName
        self.exerciseCategory = exercise.exerciseCategory.rawValue
        self.muscleGroup = exercise.muscleGroup?.rawValue
        self.sets = exercise.sortedSets.map { SetDTO(from: $0) }
    }
}

private struct SetDTO: Codable {
    let targetReps: Int?
    let targetWeightKg: Double?
    let targetDurationSeconds: Int?
    let targetDistanceMeters: Double?
    let targetRPE: Double?
    let targetRIR: Int?
    let isWarmup: Bool

    init(from set: TemplateSet) {
        self.targetReps = set.targetReps
        self.targetWeightKg = set.targetWeightKg
        self.targetDurationSeconds = set.targetDurationSeconds
        self.targetDistanceMeters = set.targetDistanceMeters
        self.targetRPE = set.targetRPE
        self.targetRIR = set.targetRIR
        self.isWarmup = set.isWarmup
    }
}
