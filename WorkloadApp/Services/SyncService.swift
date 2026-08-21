import Foundation
import SwiftData
import Supabase

/// Bidirectional sync between SwiftData (local) and Supabase (cloud).
/// Strategy: full upsert -- no dirty flags. Last-write-wins on updatedAt.
/// Each entity syncs independently; failures are isolated and logged per-entity.
@MainActor
struct SyncService {

    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    // MARK: - Public API

    /// Push all local records to Supabase (idempotent upsert by id).
    /// Each entity is pushed independently; a failure in one does not block others.
    func pushAll(context: ModelContext) async {
        let store = SyncTimestampStore.shared
        guard !store.isSyncing else { return }
        store.isSyncing = true
        defer { store.isSyncing = false }

        guard let athlete = try? context.fetch(FetchDescriptor<Athlete>()).first else { return }
        guard await verifyIdentity(athlete) else { return }

        // Deletions settle before any row is written, or a row this device still holds is
        // pushed back over a deletion made elsewhere (audit H6).
        await reconcileTombstones(context: context, athlete: athlete)

        await pushAthlete(athlete)

        if await pushWorkloadSnapshots(context: context, athleteId: athlete.id) {
            store.recordSuccess(for: .workloadSnapshots, direction: .push)
        }
        if await pushRecoverySnapshots(context: context, athleteId: athlete.id) {
            store.recordSuccess(for: .recoverySnapshots, direction: .push)
        }
        if await pushWellnessCheckIns(context: context, athleteId: athlete.id) {
            store.recordSuccess(for: .wellnessCheckIns, direction: .push)
        }
        if await pushPersonalRecords(context: context, athleteId: athlete.id) {
            store.recordSuccess(for: .personalRecords, direction: .push)
        }
        if await pushWorkoutSessions(context: context, athleteId: athlete.id) {
            store.recordSuccess(for: .workouts, direction: .push)
        }
        if await pushBehaviorTags(context: context, athleteId: athlete.id) {
            store.recordSuccess(for: .behaviorTags, direction: .push)
        }
        if await pushWorkoutTemplates(context: context, coachId: athlete.id) {
            store.recordSuccess(for: .templates, direction: .push)
        }
        if await pushTrainingProfile(context: context, athleteId: athlete.id) {
            store.recordSuccess(for: .trainingProfiles, direction: .push)
        }
    }

    /// Pull all Supabase records for current user and upsert into local SwiftData (last-write-wins).
    /// Each entity is pulled independently; a failure in one does not block others.
    func pullAll(context: ModelContext) async {
        let store = SyncTimestampStore.shared
        guard !store.isSyncing else { return }
        store.isSyncing = true
        defer { store.isSyncing = false }

        guard let athlete = try? context.fetch(FetchDescriptor<Athlete>()).first else { return }
        guard await verifyIdentity(athlete) else { return }

        // Deletions settle before any row is read, so a pull cannot re-create a row this
        // device — or another one — has already deleted (audit H6).
        await reconcileTombstones(context: context, athlete: athlete)

        await pullAthlete(context: context, existingAthlete: athlete)

        if await pullWorkloadSnapshots(context: context, athlete: athlete) {
            store.recordSuccess(for: .workloadSnapshots, direction: .pull)
        }
        if await pullRecoverySnapshots(context: context, athlete: athlete) {
            store.recordSuccess(for: .recoverySnapshots, direction: .pull)
        }
        if await pullWellnessCheckIns(context: context, athlete: athlete) {
            store.recordSuccess(for: .wellnessCheckIns, direction: .pull)
        }
        if await pullPersonalRecords(context: context, athlete: athlete) {
            store.recordSuccess(for: .personalRecords, direction: .pull)
        }
        if await pullWorkoutSessions(context: context, athlete: athlete) {
            store.recordSuccess(for: .workouts, direction: .pull)
        }
        if await pullBehaviorTags(context: context, athlete: athlete) {
            store.recordSuccess(for: .behaviorTags, direction: .pull)
        }
        if await pullWorkoutTemplates(context: context, coachId: athlete.id) {
            store.recordSuccess(for: .templates, direction: .pull)
        }
        if await pullTrainingProfile(context: context, athleteId: athlete.id) {
            store.recordSuccess(for: .trainingProfiles, direction: .pull)
        }
    }

    /// Push only WorkloadSnapshot records (called after WorkoutPipeline).
    @discardableResult
    func pushWorkloadSnapshots(context: ModelContext, athleteId: UUID) async -> Bool {
        guard await verifyIdentity(context: context, athleteId: athleteId) else { return false }
        let snapshots: [WorkloadSnapshot]
        do {
            snapshots = try context.fetch(FetchDescriptor<WorkloadSnapshot>())
                .filter { $0.athlete?.id == athleteId }
        } catch {
            logFailure(.workloadSnapshots, .push, error)
            recordFailure(.workloadSnapshots, .push, error)
            return false
        }
        guard !snapshots.isEmpty else { return true }
        let rows = snapshots.map { WorkloadSnapshotRow(from: $0, athleteId: athleteId) }
        return await run(.workloadSnapshots, .push) {
            _ = try await client.from("workload_snapshots").upsert(rows).execute()
        }
    }

    /// Push only RecoverySnapshot + WellnessCheckIn (called after RecoveryPipeline).
    func pushRecoveryAndWellness(context: ModelContext, athleteId: UUID) async {
        guard await verifyIdentity(context: context, athleteId: athleteId) else { return }
        await pushRecoverySnapshots(context: context, athleteId: athleteId)
        await pushWellnessCheckIns(context: context, athleteId: athleteId)
    }

    /// True if foreground sync should run (delegates to per-entity timestamp logic).
    var shouldForegroundSync: Bool {
        SyncTimestampStore.shared.shouldSync
    }

    // MARK: - Logging & Classification

    private func logFailure(_ entity: SyncEntity, _ direction: SyncDirection, _ error: Error) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("SyncService [\(timestamp)] \(direction.rawValue) \(entity.rawValue) error: \(error)")
    }

    private func logFailure(_ operation: String, _ error: Error) {
        print("SyncService \(operation) error: \(error)")
    }

    private func classifyError(_ error: Error) -> String {
        if error is URLError {
            return "Network unavailable"
        }
        if "\(error)".contains("401") || "\(error)".contains("403") {
            return "Authentication expired"
        }
        if "\(error)".contains("500") || "\(error)".contains("502") || "\(error)".contains("503") {
            return "Server error"
        }
        if error is DecodingError || error is EncodingError {
            return "Data format error"
        }
        return "Sync error"
    }

    /// A compact slice of the underlying error for the Sync Status row's second line, so
    /// a failure is diagnosable on the device without the Xcode console (v1.7.1).
    private func errorDetail(_ error: Error) -> String? {
        if let postgrest = error as? PostgrestError {
            return postgrest.message
        }
        if let decoding = error as? DecodingError {
            switch decoding {
            case .typeMismatch(_, let context),
                 .valueNotFound(_, let context),
                 .dataCorrupted(let context):
                return context.debugDescription
            case .keyNotFound(let key, _):
                return "Missing field: \(key.stringValue)"
            @unknown default:
                return nil
            }
        }
        if error is URLError { return nil }
        return String("\(error)".prefix(140))
    }

    /// Records a failure with both the classified label and the diagnostic detail.
    private func recordFailure(_ entity: SyncEntity, _ direction: SyncDirection, _ error: Error) {
        SyncTimestampStore.shared.recordFailure(
            for: entity,
            direction: direction,
            error: classifyError(error),
            detail: errorDetail(error)
        )
    }

    /// The one seam where an entity's sync outcome is recorded.
    ///
    /// Success is stamped HERE, not only in `pushAll`/`pullAll` (v1.7.1). Pipeline- and
    /// UI-triggered pushes — a logged workout, a saved template, a recovery run — used to
    /// be able to record a FAILURE but never a success, so one flaky-network moment painted
    /// a Sync Status row red and no amount of subsequent successful syncing could clear it.
    /// Recording both outcomes at the same seam makes the screen tell the truth.
    @discardableResult
    private func run(_ entity: SyncEntity, _ direction: SyncDirection, _ action: () async throws -> Void) async -> Bool {
        do {
            try await action()
            SyncTimestampStore.shared.recordSuccess(for: entity, direction: direction)
            return true
        } catch {
            logFailure(entity, direction, error)
            recordFailure(entity, direction, error)
            return false
        }
    }

    // MARK: - Identity guard (v1.7.1)

    /// Refuses to sync when the local athlete does not belong to the signed-in account.
    /// Born from the 2026-08-10 incident: a seeded mock athlete (random id, nil
    /// `supabaseUserId`) pushed under an id the server never issued — every row was
    /// RLS-rejected and both failure legs were silent (`pushAthlete` guard-returned, the
    /// children errored per-entity while the pulls painted the rows green). The fault is
    /// recorded on `SyncTimestampStore` and rendered as a banner on SyncStatusView.
    private func verifyIdentity(_ athlete: Athlete) async -> Bool {
        let store = SyncTimestampStore.shared
        guard let sessionUserId = try? await client.auth.session.user.id else {
            store.recordIdentityFault(.noSession)
            return false
        }
        guard let linkedUserId = athlete.supabaseUserId else {
            store.recordIdentityFault(.unlinkedAthlete)
            return false
        }
        guard linkedUserId == sessionUserId else {
            store.recordIdentityFault(.accountMismatch)
            return false
        }
        store.clearIdentityFault()
        return true
    }

    /// Variant for the seams that receive only an athlete id (pipeline-triggered pushes).
    private func verifyIdentity(context: ModelContext, athleteId: UUID) async -> Bool {
        let athletes = (try? context.fetch(FetchDescriptor<Athlete>())) ?? []
        guard let athlete = athletes.first(where: { $0.id == athleteId }) else {
            SyncTimestampStore.shared.recordIdentityFault(.unlinkedAthlete)
            return false
        }
        return await verifyIdentity(athlete)
    }

    // MARK: - Tombstones (audit H6)

    /// Where each tombstoned entity lives, and which column carries its owner. An entity
    /// absent from this map simply has no deletion path — adding one is a single line here
    /// plus a `SyncTombstone.record` call at the repository's delete seam.
    ///
    /// `workout_templates` is owned by `coach_id`, not `athlete_id` — the athlete-owned
    /// column on that table is nullable and is not the row's owner. Filtering the hard
    /// delete on the wrong column would silently match nothing.
    private static let tombstonedTables: [SyncEntity: (table: String, ownerColumn: String)] = [
        .workouts: ("workout_sessions", "athlete_id"),
        .templates: ("workout_templates", "coach_id"),
        .personalRecords: ("personal_records", "athlete_id"),
        .behaviorTags: ("behavior_tags", "athlete_id"),
        .wellnessCheckIns: ("wellness_check_ins", "athlete_id")
    ]

    /// Reconciles deletions in both directions, before any row is pushed or pulled.
    ///
    /// Ordering is load-bearing. Deletions must settle FIRST, or a device that still holds
    /// a row another device deleted pushes it back in the same cycle, and the athlete sees
    /// the deletion undo itself.
    ///
    /// Every step degrades safely when `sync_tombstones` does not exist yet (migration 010
    /// is run by hand): the push leg records a per-entity failure and retries next cycle,
    /// the pull leg returns nothing, and the local tombstones still keep the pull loops
    /// from re-creating deleted rows. The single-device defect is fixed with or without
    /// the migration; the migration is what makes deletions cross devices.
    private func reconcileTombstones(context: ModelContext, athlete: Athlete) async {
        await pushTombstones(context: context, athleteId: athlete.id)
        await pullTombstones(context: context, athleteId: athlete.id)
        SyncTombstone.prune(in: context)
        try? context.save()
    }

    private func pushTombstones(context: ModelContext, athleteId: UUID) async {
        let pending = SyncTombstone.pendingByEntity(in: context)
        guard !pending.isEmpty else { return }

        for (entity, tombstones) in pending {
            guard let target = Self.tombstonedTables[entity] else { continue }
            let rows = tombstones.map {
                SyncTombstoneRow(athleteId: athleteId, entity: entity.rawValue, rowId: $0.rowId, deletedAt: $0.deletedAt)
            }
            let rowIds = tombstones.map(\.rowId.uuidString)

            let succeeded = await run(entity, .push) {
                _ = try await client
                    .from("sync_tombstones")
                    .upsert(rows, onConflict: "athlete_id,entity,row_id")
                    .execute()
                // Then remove the rows themselves. The tombstone is what makes this safe:
                // a device that has not synced since still learns the row is gone, so the
                // hard delete cannot be undone by that device's next push.
                _ = try await client
                    .from(target.table)
                    .delete()
                    .eq(target.ownerColumn, value: athleteId)
                    .in("id", values: rowIds)
                    .execute()
            }
            if succeeded {
                for tombstone in tombstones { tombstone.isPushed = true }
            }
        }
    }

    private func pullTombstones(context: ModelContext, athleteId: UUID) async {
        let rows: [SyncTombstoneRow]
        do {
            rows = try await client
                .from("sync_tombstones")
                .select()
                .eq("athlete_id", value: athleteId)
                .execute()
                .value
        } catch {
            // Absent table (migration not run) or a transport failure. Local deletions are
            // still honoured; only cross-device propagation waits.
            logFailure("pull tombstones", error)
            return
        }

        for row in rows {
            guard let entity = SyncEntity(rawValue: row.entity) else { continue }
            SyncTombstone.record(
                rowId: row.rowId,
                entity: entity,
                athleteId: athleteId,
                in: context,
                isPushed: true
            )
            deleteLocalRow(id: row.rowId, entity: entity, context: context)
        }
    }

    /// Removes the local copy of a row another device deleted.
    private func deleteLocalRow(id: UUID, entity: SyncEntity, context: ModelContext) {
        switch entity {
        case .workouts:
            if let row = try? context.fetch(FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.id == id })).first {
                context.delete(row)
            }
        case .templates:
            if let row = try? context.fetch(FetchDescriptor<WorkoutTemplate>(predicate: #Predicate { $0.id == id })).first {
                context.delete(row)
            }
        case .personalRecords:
            if let row = try? context.fetch(FetchDescriptor<PersonalRecord>(predicate: #Predicate { $0.id == id })).first {
                context.delete(row)
            }
        case .behaviorTags:
            if let row = try? context.fetch(FetchDescriptor<BehaviorTag>(predicate: #Predicate { $0.id == id })).first {
                context.delete(row)
            }
        case .wellnessCheckIns:
            if let row = try? context.fetch(FetchDescriptor<WellnessCheckIn>(predicate: #Predicate { $0.id == id })).first {
                context.delete(row)
            }
        case .recoverySnapshots, .workloadSnapshots, .trainingProfiles:
            // Derived daily rows and the single training profile have no deletion path.
            break
        }
    }

    // MARK: - Athlete push/pull

    /// The three distinguishable outcomes of a bootstrap attempt.
    ///
    /// They are separate cases because the callers must act differently (v1.7.2 / audit H7).
    /// `bootstrapAthlete` used to return `Athlete?`, which collapsed "the server has no
    /// profile for this account" and "the request never reached the server" into one `nil`.
    /// Every caller read that `nil` as the former, so a reinstall on a bad network signed
    /// the athlete out of a perfectly good account, and an Apple/Google re-auth created a
    /// fresh local profile named "Athlete" and pushed it over the real server row.
    enum BootstrapOutcome {
        /// A profile exists on the server and now exists locally.
        case created(Athlete)
        /// The request succeeded and the account genuinely has no athlete row.
        case notFound
        /// The request failed. Nothing is known about whether a profile exists.
        case failed(Error)
    }

    /// Fetches the athlete profile from Supabase and creates it locally.
    /// Called on first sign-in to a fresh device (no local Athlete exists yet).
    ///
    /// Decodes an ARRAY rather than using `.single()`: `.single()` reports zero rows as the
    /// error PGRST116, which is precisely the ambiguity this method exists to remove. With
    /// an array, an empty result IS the not-found signal and any thrown error IS a failure.
    func bootstrapAthlete(context: ModelContext, userId: UUID) async -> BootstrapOutcome {
        let rows: [AthleteRow]
        do {
            rows = try await client
                .from("athletes")
                .select()
                .eq("user_id", value: userId)
                .limit(1)
                .execute()
                .value
        } catch {
            logFailure("bootstrap athlete", error)
            return .failed(error)
        }
        guard let row = rows.first else { return .notFound }

        let athlete = Athlete(
            id: row.id,
            displayName: row.displayName ?? "",
            sportType: SportType(rawValue: row.sportType ?? "") ?? .custom
        )
        athlete.supabaseUserId = row.userId
        Self.apply(row, to: athlete)
        context.insert(athlete)
        try? context.save()
        return .created(athlete)
    }

    func pushAthlete(_ athlete: Athlete) async {
        guard await verifyIdentity(athlete) else { return }
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
            dateOfBirth: athlete.dateOfBirth.map(DateOnly.init),
            isCoach: athlete.isCoach,
            trainingFrequency: athlete.trainingFrequency?.rawValue,
            experienceLevel: athlete.experienceLevel?.rawValue,
            createdAt: athlete.createdAt,
            updatedAt: athlete.updatedAt
        )
        do {
            _ = try await client.from("athletes").upsert(row).execute()
        } catch {
            logFailure("push athlete", error)
        }
    }

    private func pullAthlete(context: ModelContext, existingAthlete: Athlete) async {
        guard let userId = existingAthlete.supabaseUserId else { return }
        let rows: [AthleteRow]
        do {
            rows = try await client
                .from("athletes")
                .select()
                .eq("user_id", value: userId)
                .limit(1)
                .execute()
                .value
        } catch {
            logFailure("pull athlete", error)
            return
        }
        guard let row = rows.first else { return }
        if existingAthlete.updatedAt > row.updatedAt { return }
        Self.apply(row, to: existingAthlete)
        do {
            try context.save()
        } catch {
            logFailure("pull athlete save", error)
        }
    }

    /// Copies a server athlete row onto a local `Athlete`.
    ///
    /// Every field `pushAthlete` sends is restored here (v1.7.2 / audit M1). Before this,
    /// a pull restored only `displayName` / `isCoach` / `trainingFrequency` /
    /// `experienceLevel`, so `sportType`, `weightUnit`, `acwrMethod`,
    /// `loadMetricPreference`, `maxHeartRate` and `dateOfBirth` were write-only — a new
    /// device came up with defaults for settings the athlete had already chosen, silently.
    ///
    /// Nil is read as ABSENT, never as "cleared". The `athletes` table has grown columns by
    /// hand across three releases (007 backfilled two of them), so a column the server does
    /// not have yet decodes as nil on every row; coalescing keeps a schema gap from wiping a
    /// real local value. The cost is that genuinely clearing `maxHeartRate` or `dateOfBirth`
    /// does not propagate to another device — the cheaper of the two failures.
    static func apply(_ row: AthleteRow, to athlete: Athlete) {
        athlete.displayName = row.displayName ?? athlete.displayName
        if let sport = row.sportType.flatMap(SportType.init(rawValue:)) {
            athlete.sportType = sport
        }
        if let unit = row.weightUnit.flatMap(WeightUnit.init(rawValue:)) {
            athlete.weightUnit = unit
        }
        if let method = row.acwrMethod.flatMap(ACWRMethod.init(rawValue:)) {
            athlete.acwrMethod = method
        }
        if let metric = row.loadMetricPreference.flatMap(LoadSource.init(rawValue:)) {
            athlete.loadMetricPreference = metric
        }
        athlete.maxHeartRate = row.maxHeartRate ?? athlete.maxHeartRate
        athlete.dateOfBirth = row.dateOfBirth?.date ?? athlete.dateOfBirth
        athlete.isCoach = row.isCoach ?? athlete.isCoach
        if let freq = row.trainingFrequency.flatMap(TrainingFrequency.init(rawValue:)) {
            athlete.trainingFrequency = freq
        }
        if let exp = row.experienceLevel.flatMap(ExperienceLevel.init(rawValue:)) {
            athlete.experienceLevel = exp
        }
        athlete.updatedAt = row.updatedAt
    }

    // MARK: - Push helpers

    @discardableResult
    private func pushRecoverySnapshots(context: ModelContext, athleteId: UUID) async -> Bool {
        let snapshots: [RecoverySnapshot]
        do {
            snapshots = try context.fetch(FetchDescriptor<RecoverySnapshot>())
                .filter { $0.athlete?.id == athleteId }
        } catch {
            logFailure(.recoverySnapshots, .push, error)
            recordFailure(.recoverySnapshots, .push, error)
            return false
        }
        guard !snapshots.isEmpty else { return true }
        let rows = snapshots.map { RecoverySnapshotRow(from: $0, athleteId: athleteId) }
        return await run(.recoverySnapshots, .push) {
            _ = try await client.from("recovery_snapshots").upsert(rows).execute()
        }
    }

    @discardableResult
    private func pushWellnessCheckIns(context: ModelContext, athleteId: UUID) async -> Bool {
        let checkIns: [WellnessCheckIn]
        do {
            checkIns = try context.fetch(FetchDescriptor<WellnessCheckIn>())
                .filter { $0.athlete?.id == athleteId }
        } catch {
            logFailure(.wellnessCheckIns, .push, error)
            recordFailure(.wellnessCheckIns, .push, error)
            return false
        }
        guard !checkIns.isEmpty else { return true }
        let rows = checkIns.map { WellnessCheckInRow(from: $0, athleteId: athleteId) }
        return await run(.wellnessCheckIns, .push) {
            _ = try await client.from("wellness_check_ins").upsert(rows).execute()
        }
    }

    @discardableResult
    private func pushPersonalRecords(context: ModelContext, athleteId: UUID) async -> Bool {
        let prs: [PersonalRecord]
        do {
            prs = try context.fetch(FetchDescriptor<PersonalRecord>())
                .filter { $0.athlete?.id == athleteId }
        } catch {
            logFailure(.personalRecords, .push, error)
            recordFailure(.personalRecords, .push, error)
            return false
        }
        guard !prs.isEmpty else { return true }
        let rows = prs.map { PersonalRecordRow(from: $0, athleteId: athleteId) }
        return await run(.personalRecords, .push) {
            _ = try await client.from("personal_records").upsert(rows).execute()
        }
    }

    @discardableResult
    private func pushWorkoutSessions(context: ModelContext, athleteId: UUID) async -> Bool {
        let sessions: [WorkoutSession]
        do {
            sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
                .filter { $0.athlete?.id == athleteId }
        } catch {
            logFailure(.workouts, .push, error)
            recordFailure(.workouts, .push, error)
            return false
        }
        guard !sessions.isEmpty else { return true }
        let rows = sessions.map { WorkoutSessionRow(from: $0, athleteId: athleteId) }
        return await run(.workouts, .push) {
            _ = try await client.from("workout_sessions").upsert(rows).execute()
        }
    }

    // MARK: - Pull helpers

    @discardableResult
    private func pullWorkloadSnapshots(context: ModelContext, athlete: Athlete) async -> Bool {
        let rows: [WorkloadSnapshotRow]
        do {
            rows = try await client
                .from("workload_snapshots")
                .select()
                .eq("athlete_id", value: athlete.id)
                .execute()
                .value
        } catch {
            logFailure(.workloadSnapshots, .pull, error)
            recordFailure(.workloadSnapshots, .pull, error)
            return false
        }

        for row in rows {
            let pred = #Predicate<WorkloadSnapshot> { $0.id == row.id }
            let existing = try? context.fetch(FetchDescriptor(predicate: pred)).first
            if let existing, existing.updatedAt > row.updatedAt { continue }
            let snap = existing ?? WorkloadSnapshot()
            snap.id = row.id
            snap.snapshotDate = row.snapshotDate.date
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
        do {
            try context.save()
        } catch {
            logFailure(.workloadSnapshots, .pull, error)
            recordFailure(.workloadSnapshots, .pull, error)
            return false
        }
        return true
    }

    @discardableResult
    private func pullRecoverySnapshots(context: ModelContext, athlete: Athlete) async -> Bool {
        let rows: [RecoverySnapshotRow]
        do {
            rows = try await client
                .from("recovery_snapshots")
                .select()
                .eq("athlete_id", value: athlete.id)
                .execute()
                .value
        } catch {
            logFailure(.recoverySnapshots, .pull, error)
            recordFailure(.recoverySnapshots, .pull, error)
            return false
        }

        for row in rows {
            let pred = #Predicate<RecoverySnapshot> { $0.id == row.id }
            let existing = try? context.fetch(FetchDescriptor(predicate: pred)).first
            if let existing, existing.updatedAt > row.updatedAt { continue }
            let snap = existing ?? RecoverySnapshot()
            snap.id = row.id
            snap.date = row.date.date
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
        do {
            try context.save()
        } catch {
            logFailure(.recoverySnapshots, .pull, error)
            recordFailure(.recoverySnapshots, .pull, error)
            return false
        }
        return true
    }

    @discardableResult
    private func pullWellnessCheckIns(context: ModelContext, athlete: Athlete) async -> Bool {
        let rows: [WellnessCheckInRow]
        do {
            rows = try await client
                .from("wellness_check_ins")
                .select()
                .eq("athlete_id", value: athlete.id)
                .execute()
                .value
        } catch {
            logFailure(.wellnessCheckIns, .pull, error)
            recordFailure(.wellnessCheckIns, .pull, error)
            return false
        }

        // Rows deleted here are never re-created (audit H6). The tombstone check is
        // local, so it holds even before migration 010 lets the deletion reach the server.
        let tombstoned = SyncTombstone.deletedRowIds(entity: .wellnessCheckIns, in: context)
        for row in rows {
            let pred = #Predicate<WellnessCheckIn> { $0.id == row.id }
            if tombstoned.contains(row.id) { continue }
            let existing = try? context.fetch(FetchDescriptor(predicate: pred)).first
            if let existing, existing.updatedAt > row.updatedAt { continue }
            let checkIn = existing ?? WellnessCheckIn()
            checkIn.id = row.id
            checkIn.date = row.date.date
            checkIn.sleepQuality = row.sleepQuality ?? 3
            checkIn.soreness = row.soreness ?? 3
            checkIn.energy = row.energy ?? 3
            checkIn.stress = row.stress ?? 3
            checkIn.notes = row.notes
            checkIn.updatedAt = row.updatedAt
            checkIn.athlete = athlete
            if existing == nil { context.insert(checkIn) }
        }
        do {
            try context.save()
        } catch {
            logFailure(.wellnessCheckIns, .pull, error)
            recordFailure(.wellnessCheckIns, .pull, error)
            return false
        }
        return true
    }

    @discardableResult
    private func pullWorkoutSessions(context: ModelContext, athlete: Athlete) async -> Bool {
        let rows: [WorkoutSessionRow]
        do {
            rows = try await client
                .from("workout_sessions")
                .select()
                .eq("athlete_id", value: athlete.id)
                .execute()
                .value
        } catch {
            logFailure(.workouts, .pull, error)
            recordFailure(.workouts, .pull, error)
            return false
        }

        // Rows deleted here are never re-created (audit H6). The tombstone check is
        // local, so it holds even before migration 010 lets the deletion reach the server.
        let tombstoned = SyncTombstone.deletedRowIds(entity: .workouts, in: context)
        for row in rows {
            let pred = #Predicate<WorkoutSession> { $0.id == row.id }
            if tombstoned.contains(row.id) { continue }
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
            session.totalVolume = row.totalVolume ?? 0
            session.externalLoad = row.externalLoad ?? 0
            session.internalLoad = row.internalLoad ?? 0
            session.trainingStress = row.trainingStress ?? 0
            session.sessionType = SessionType(rawValue: row.sessionType ?? "") ?? .strength
            session.loggedByCoachId = row.loggedByCoachId
            session.updatedAt = row.updatedAt
            session.athlete = athlete
            if existing == nil { context.insert(session) }
        }
        do {
            try context.save()
        } catch {
            logFailure(.workouts, .pull, error)
            recordFailure(.workouts, .pull, error)
            return false
        }
        return true
    }

    // MARK: - BehaviorTag push/pull

    @discardableResult
    private func pushBehaviorTags(context: ModelContext, athleteId: UUID) async -> Bool {
        let tags: [BehaviorTag]
        do {
            tags = try context.fetch(FetchDescriptor<BehaviorTag>())
                .filter { $0.athlete?.id == athleteId }
        } catch {
            logFailure(.behaviorTags, .push, error)
            recordFailure(.behaviorTags, .push, error)
            return false
        }
        guard !tags.isEmpty else { return true }
        let rows = tags.map { BehaviorTagRow(from: $0, athleteId: athleteId) }
        return await run(.behaviorTags, .push) {
            _ = try await client.from("behavior_tags").upsert(rows).execute()
        }
    }

    @discardableResult
    private func pullBehaviorTags(context: ModelContext, athlete: Athlete) async -> Bool {
        let rows: [BehaviorTagRow]
        do {
            rows = try await client
                .from("behavior_tags")
                .select()
                .eq("athlete_id", value: athlete.id)
                .execute()
                .value
        } catch {
            logFailure(.behaviorTags, .pull, error)
            recordFailure(.behaviorTags, .pull, error)
            return false
        }

        // Rows deleted here are never re-created (audit H6). The tombstone check is
        // local, so it holds even before migration 010 lets the deletion reach the server.
        let tombstoned = SyncTombstone.deletedRowIds(entity: .behaviorTags, in: context)
        for row in rows {
            let pred = #Predicate<BehaviorTag> { $0.id == row.id }
            if tombstoned.contains(row.id) { continue }
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
        do {
            try context.save()
        } catch {
            logFailure(.behaviorTags, .pull, error)
            recordFailure(.behaviorTags, .pull, error)
            return false
        }
        return true
    }

    @discardableResult
    private func pullPersonalRecords(context: ModelContext, athlete: Athlete) async -> Bool {
        let rows: [PersonalRecordRow]
        do {
            rows = try await client
                .from("personal_records")
                .select()
                .eq("athlete_id", value: athlete.id)
                .execute()
                .value
        } catch {
            logFailure(.personalRecords, .pull, error)
            recordFailure(.personalRecords, .pull, error)
            return false
        }

        // Rows deleted here are never re-created (audit H6). The tombstone check is
        // local, so it holds even before migration 010 lets the deletion reach the server.
        let tombstoned = SyncTombstone.deletedRowIds(entity: .personalRecords, in: context)
        for row in rows {
            let pred = #Predicate<PersonalRecord> { $0.id == row.id }
            if tombstoned.contains(row.id) { continue }
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
        do {
            try context.save()
        } catch {
            logFailure(.personalRecords, .pull, error)
            recordFailure(.personalRecords, .pull, error)
            return false
        }
        return true
    }
    // MARK: - Template push/pull

    @discardableResult
    func pushWorkoutTemplates(context: ModelContext, coachId: UUID) async -> Bool {
        guard await verifyIdentity(context: context, athleteId: coachId) else { return false }
        let templates: [WorkoutTemplate]
        do {
            templates = try context.fetch(
                FetchDescriptor<WorkoutTemplate>(predicate: #Predicate { $0.coachId == coachId })
            )
        } catch {
            logFailure(.templates, .push, error)
            recordFailure(.templates, .push, error)
            return false
        }
        guard !templates.isEmpty else { return true }
        let rows = templates.map { WorkoutTemplateRow(from: $0) }
        return await run(.templates, .push) {
            _ = try await client.from("workout_templates").upsert(rows).execute()
        }
    }

    @discardableResult
    private func pullWorkoutTemplates(context: ModelContext, coachId: UUID) async -> Bool {
        let rows: [WorkoutTemplateRow]
        do {
            rows = try await client
                .from("workout_templates")
                .select()
                .eq("coach_id", value: coachId)
                .execute()
                .value
        } catch {
            logFailure(.templates, .pull, error)
            recordFailure(.templates, .pull, error)
            return false
        }

        // Rows deleted here are never re-created (audit H6). The tombstone check is
        // local, so it holds even before migration 010 lets the deletion reach the server.
        let tombstoned = SyncTombstone.deletedRowIds(entity: .templates, in: context)
        for row in rows {
            if tombstoned.contains(row.id) { continue }
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
            template.isAthleteOwned = row.isAthleteOwned
            template.athleteId = row.athleteId
            template.isFavorite = row.isFavorite
            template.isArchived = row.isArchived
            template.lastUsedAt = row.lastUsedAt
            template.usageCount = row.usageCount
            template.scheduledDays = row.scheduledDays ?? []

            // Rebuild the group tree ONLY when its content actually differs (v1.7.1).
            //
            // The LWW guard above skips a row only when local is strictly NEWER, and this
            // loop then sets `template.updatedAt = row.updatedAt` — so from the first
            // applied pull onward local and server timestamps are EQUAL forever, the guard
            // never fires, and every foreground sync cascade-deleted and re-created every
            // ExerciseGroup / TemplateExercise / TemplateSet with fresh UUIDs. That churn
            // could also empty a template mid-edit.
            //
            // Comparing the canonical encoding instead of widening the timestamp guard is
            // deliberate: an equal timestamp does NOT imply equal payload (two devices can
            // edit inside the same truncated second), so skipping purely on equality could
            // strand a real remote change. Content is the honest test — identical content
            // means there is nothing to rebuild; different content still applies.
            let incomingGroupsJSON = row.groupsJson
            let localGroupsJSON = existing.map { Self.encodeGroups($0.groups) } ?? nil
            if existing == nil || incomingGroupsJSON != localGroupsJSON {
                if existing != nil {
                    for group in template.groups { context.delete(group) }
                    template.groups = []
                }
                if let groupsJSON = incomingGroupsJSON {
                    template.groups = Self.decodeGroups(from: groupsJSON)
                }
            }

            if existing == nil { context.insert(template) }
        }
        do {
            try context.save()
        } catch {
            logFailure(.templates, .pull, error)
            recordFailure(.templates, .pull, error)
            return false
        }
        return true
    }

    // MARK: - Training Profile push/pull

    @discardableResult
    func pushTrainingProfile(context: ModelContext, athleteId: UUID) async -> Bool {
        guard await verifyIdentity(context: context, athleteId: athleteId) else { return false }
        let predicate = #Predicate<TrainingProfile> { $0.athleteId == athleteId }
        let profile: TrainingProfile?
        do {
            profile = try context.fetch(FetchDescriptor(predicate: predicate)).first
        } catch {
            logFailure(.trainingProfiles, .push, error)
            recordFailure(.trainingProfiles, .push, error)
            return false
        }
        guard let profile else { return true }
        let row = TrainingProfileRow(from: profile)
        return await run(.trainingProfiles, .push) {
            // Conflict on athlete_id, not the primary key (v1.7.2 / audit M4). The table
            // carries UNIQUE(athlete_id) (migration 006) while each device mints its own
            // `id`, so a default PK upsert from a second device is an INSERT that violates
            // the unique constraint — 23505, a permanently red Training Profile row.
            _ = try await client
                .from("training_profiles")
                .upsert(row, onConflict: "athlete_id")
                .execute()
        }
    }

    @discardableResult
    private func pullTrainingProfile(context: ModelContext, athleteId: UUID) async -> Bool {
        // Decode an ARRAY, not `.single()` (v1.7.1). `.single()` treats zero rows as the
        // error PGRST116, so an athlete who never completed cold start had a permanently
        // red "Training Profile" row — which, because `shouldSync` returns true whenever
        // any entity has a recorded failure, also forced a full push+pull on every single
        // foreground. No profile on the server is an ABSENCE, not a failure.
        let rows: [TrainingProfileRow]
        do {
            rows = try await client
                .from("training_profiles")
                .select()
                .eq("athlete_id", value: athleteId)
                .limit(1)
                .execute()
                .value
        } catch {
            logFailure(.trainingProfiles, .pull, error)
            recordFailure(.trainingProfiles, .pull, error)
            return false
        }
        guard let row = rows.first else {
            // Nothing to pull; the local profile (if any) stands.
            return true
        }

        let predicate = #Predicate<TrainingProfile> { $0.athleteId == athleteId }
        let existing = try? context.fetch(FetchDescriptor(predicate: predicate)).first
        if let existing, existing.updatedAt > row.updatedAt { return true }

        if let existing {
            existing.sessionsPerWeek = row.sessionsPerWeek
            existing.avgDurationMinutes = row.avgDurationMinutes
            existing.typicalSRPE = row.typicalSrpe
            existing.weeksAtLevel = row.weeksAtLevel
            existing.trainingAgeYears = row.trainingAgeYears
            existing.periodizationPreference = row.periodizationPreference
            existing.movementTypes = row.movementTypes
            existing.injuryHistory = row.injuryHistory?.data(using: .utf8)
            existing.seededATL = row.seededAtl
            existing.seededCTL = row.seededCtl
            existing.seededAt = row.seededAt
            existing.biasEstimatedATL = row.biasEstimatedAtl
            existing.biasEstimatedCTL = row.biasEstimatedCtl
            existing.biasActualATL = row.biasActualAtl
            existing.biasActualCTL = row.biasActualCtl
            existing.biasCapturedAt = row.biasCapturedAt
            existing.coldStartCompletedAt = row.coldStartCompletedAt
            existing.updatedAt = row.updatedAt
        } else {
            let profile = TrainingProfile(
                id: row.id,
                athleteId: row.athleteId,
                sessionsPerWeek: row.sessionsPerWeek,
                avgDurationMinutes: row.avgDurationMinutes,
                typicalSRPE: row.typicalSrpe,
                weeksAtLevel: row.weeksAtLevel,
                seededATL: row.seededAtl,
                seededCTL: row.seededCtl,
                seededAt: row.seededAt
            )
            profile.createdAt = row.createdAt
            profile.trainingAgeYears = row.trainingAgeYears
            profile.periodizationPreference = row.periodizationPreference
            profile.movementTypes = row.movementTypes
            profile.injuryHistory = row.injuryHistory?.data(using: .utf8)
            profile.biasEstimatedATL = row.biasEstimatedAtl
            profile.biasEstimatedCTL = row.biasEstimatedCtl
            profile.biasActualATL = row.biasActualAtl
            profile.biasActualCTL = row.biasActualCtl
            profile.biasCapturedAt = row.biasCapturedAt
            profile.coldStartCompletedAt = row.coldStartCompletedAt
            profile.updatedAt = row.updatedAt
            context.insert(profile)
        }
        do {
            try context.save()
        } catch {
            logFailure(.trainingProfiles, .pull, error)
            recordFailure(.trainingProfiles, .pull, error)
            return false
        }
        return true
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

/// Calendar-day codec for Postgres `DATE` columns (v1.7.1 sync repair).
///
/// PostgREST serialises a `DATE` column as a bare "yyyy-MM-dd" string. The client's
/// global `.iso8601`-style strategies could neither decode that (every pull on
/// recovery_snapshots / wellness_check_ins / workload_snapshots threw DecodingError →
/// "Data format error") nor encode it day-stably: a full UTC timestamp cast to `DATE`
/// server-side lands on the previous calendar day for any zone east of UTC at local
/// midnight — which is exactly what start-of-day snapshot dates are. Date-only fields
/// therefore round-trip through this wrapper as the LOCAL calendar day, bypassing the
/// container's Date strategies entirely.
struct DateOnly: Codable, Equatable {
    let date: Date

    /// `TimeZone.current` is read on every call — never cached (v1.7.2 / audit M6). See
    /// `CalendarDay` for why that matters.
    init(_ date: Date) {
        self.date = CalendarDay.startOfDay(for: date, in: .current)
    }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        // Tolerate a timestamptz string too (first 10 chars are the date part) in case
        // a column is migrated later.
        guard let parsed = CalendarDay.date(from: String(raw.prefix(10)), in: .current) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Unrecognized DATE string: \(raw)"
            ))
        }
        self.date = parsed
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(CalendarDay.string(from: date, in: .current))
    }
}

/// One deletion, on its own table (v1.7.2 / audit H6). Keeping deletions out of the entity
/// tables is what makes them survive a full-row upsert from a device that still holds the
/// row — see `SyncTombstone` for the argument.
struct SyncTombstoneRow: Codable {
    let athleteId: UUID
    let entity: String
    let rowId: UUID
    let deletedAt: Date
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
    let dateOfBirth: DateOnly?
    let isCoach: Bool?
    let trainingFrequency: String?
    let experienceLevel: String?
    // PRIVACY: reproductive-health flags (isOnHormonalContraceptive, isPregnant,
    // isLactating) are intentionally NOT synced — they stay device-local per the
    // cycle-data privacy invariant. Do not add them to this row. (Phase 18 / CR-01)
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
    let snapshotDate: DateOnly
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
        self.snapshotDate = DateOnly(model.snapshotDate)
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
    let date: DateOnly
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
        self.date = DateOnly(model.date)
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
    let date: DateOnly
    let sleepQuality: Int?
    let soreness: Int?
    let energy: Int?
    let stress: Int?
    let notes: String?
    let updatedAt: Date

    init(from model: WellnessCheckIn, athleteId: UUID) {
        self.id = model.id
        self.athleteId = athleteId
        self.date = DateOnly(model.date)
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
    // Optional on decode (v1.7.1): the live table predates the committed DDL, so these
    // columns can be nullable server-side — a single NULL row must not fail the whole
    // pull. Push always supplies concrete values.
    let sessionType: String?
    let loggedByCoachId: UUID?
    let notes: String?
    let totalVolume: Double?
    let externalLoad: Double?
    let internalLoad: Double?
    let trainingStress: Double?
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
    let isAthleteOwned: Bool
    let athleteId: UUID?
    let isFavorite: Bool
    let isArchived: Bool
    let lastUsedAt: Date?
    let usageCount: Int
    let scheduledDays: [Int]?

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
        self.isAthleteOwned = model.isAthleteOwned
        self.athleteId = model.athleteId
        self.isFavorite = model.isFavorite
        self.isArchived = model.isArchived
        self.lastUsedAt = model.lastUsedAt
        self.usageCount = model.usageCount
        self.scheduledDays = model.scheduledDays.isEmpty ? nil : model.scheduledDays
    }
}

// MARK: - Training Profile Row

struct TrainingProfileRow: Codable {
    let id: UUID
    let athleteId: UUID
    let sessionsPerWeek: Int
    let avgDurationMinutes: Int
    let typicalSrpe: Double
    let weeksAtLevel: Int
    let trainingAgeYears: Int?
    let periodizationPreference: String?
    let movementTypes: [String]?
    let injuryHistory: String?  // JSON string for JSONB column
    let seededAtl: Double
    let seededCtl: Double
    let seededAt: Date
    let biasEstimatedAtl: Double?
    let biasEstimatedCtl: Double?
    let biasActualAtl: Double?
    let biasActualCtl: Double?
    let biasCapturedAt: Date?
    let coldStartCompletedAt: Date?
    let createdAt: Date
    let updatedAt: Date

    init(from model: TrainingProfile) {
        self.id = model.id
        self.athleteId = model.athleteId
        self.sessionsPerWeek = model.sessionsPerWeek
        self.avgDurationMinutes = model.avgDurationMinutes
        self.typicalSrpe = model.typicalSRPE
        self.weeksAtLevel = model.weeksAtLevel
        self.trainingAgeYears = model.trainingAgeYears
        self.periodizationPreference = model.periodizationPreference
        self.movementTypes = model.movementTypes
        self.injuryHistory = model.injuryHistory.flatMap { String(data: $0, encoding: .utf8) }
        self.seededAtl = model.seededATL
        self.seededCtl = model.seededCTL
        self.seededAt = model.seededAt
        self.biasEstimatedAtl = model.biasEstimatedATL
        self.biasEstimatedCtl = model.biasEstimatedCTL
        self.biasActualAtl = model.biasActualATL
        self.biasActualCtl = model.biasActualCTL
        self.biasCapturedAt = model.biasCapturedAt
        self.coldStartCompletedAt = model.coldStartCompletedAt
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
