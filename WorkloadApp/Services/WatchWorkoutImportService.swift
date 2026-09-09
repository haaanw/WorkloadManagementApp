import Foundation
import SwiftData
import HealthKit

/// Logs watch-recorded workouts by itself (v1.7.3, UAT round 1 · U4).
///
/// **The ruling.** A workout the athlete already recorded on their watch is a workout they
/// already logged. Tuwa's job is to notice, not to ask. There is no Add row, no RPE sheet
/// and no banner: the session appears in history carrying a quiet "logged from watch" mark,
/// and the athlete finds it there the same way they find everything else.
///
/// **Why the old surface missed things.** `WorkoutImportService` (retired with
/// `WorkoutImportBanner.swift`) fetched a fixed three-day window exactly once per app
/// process, from the Log tab's `.task`. In a `TabView` that child is built on first
/// selection and kept, so the task never fired again — no foreground refresh, no observer,
/// no second chance. A watch workout reaches the phone's HealthKit store minutes after it
/// ends, which is routinely after that one fetch, so the list froze with whatever had
/// synced at launch. Three defects compounded it: the window was three days with no
/// catch-up, anything under five minutes was discarded, and the dedupe was a point match
/// (see `WatchWorkoutMatcher`). This service replaces all four.
///
/// **What it does not do.** It runs on foreground, not in the background: true background
/// delivery needs the `com.apple.developer.healthkit.background-delivery` entitlement, which
/// the app does not hold and which is a provisioning change, not a code change. So the
/// import happens the moment the athlete opens Tuwa rather than while their phone is in a
/// pocket. From the athlete's side the difference is invisible — the session is simply
/// already there.
@MainActor
enum WatchWorkoutImportService {

    // MARK: - Constants

    /// How far back a first run (or a run after a lost anchor) will reach.
    ///
    /// The anchor makes repeat runs exact; this bounds the FIRST one. Without it an anchored
    /// query with no anchor hands over the athlete's entire workout history, and a new
    /// install would silently log years of walks into the load model.
    static let catchUpWindowDays = 14

    /// The persisted `HKQueryAnchor`. HealthKit owns "what has this app seen"; we only store
    /// its bookmark.
    private static let anchorKey = "watchWorkoutQueryAnchor"

    /// Re-entrancy guard.
    ///
    /// Two triggers fire on the same event: `AppRouter`'s foreground handler and the Log
    /// tab's `.task` both run this, and returning to a foregrounded app on the Log tab does
    /// both at once. Without this flag they would each fetch with the SAME un-banked anchor,
    /// each get the same workouts, and each pass `decide` before the other's session existed
    /// — the UUID key cannot help, because both runs read their comparison set before either
    /// wrote. That is a double-logged session, which is the one outcome this whole lane
    /// exists to prevent.
    ///
    /// A plain `Bool` is sufficient BECAUSE the type is `@MainActor`: the read and the write
    /// below are not separated by an `await`, so no second run can observe it false.
    private static var isRunning = false

    // MARK: - Run

    /// Import every watch workout HealthKit has not handed us before. Returns how many
    /// sessions were logged.
    ///
    /// Safe to call as often as the app likes — the anchor and the UUID key make repeats
    /// free. Call it on foreground and on the Log tab's appearance.
    @discardableResult
    static func run(
        healthKit: HealthKitService,
        modelContext: ModelContext,
        syncService: SyncService? = nil
    ) async -> Int {
        guard healthKit.isAvailable, healthKit.isAuthorized else { return 0 }
        #if DEBUG
        // Seeded screenshot runs must never reach the real Health store.
        if ProcessInfo.processInfo.arguments.contains("SCREENSHOT_MODE") { return 0 }
        #endif

        // See `isRunning`. A second caller returns immediately rather than queueing: it
        // wants the same batch the first one is already importing, so waiting would buy
        // nothing and the next foreground picks up anything that arrives meanwhile.
        guard !isRunning else { return 0 }
        isRunning = true
        defer { isRunning = false }

        guard let batch = try? await healthKit.fetchWorkouts(
            since: loadAnchor(),
            windowDays: catchUpWindowDays
        ) else { return 0 }

        guard !batch.workouts.isEmpty else {
            // Nothing new. Still bank the anchor: the query has advanced past whatever it
            // examined, and re-examining it next foreground is pure cost.
            saveAnchor(batch.anchor)
            return 0
        }

        guard let athlete = try? modelContext.fetch(FetchDescriptor<Athlete>()).first else {
            // No athlete yet (bootstrap in flight). Do NOT bank the anchor — these workouts
            // must still be waiting on the next run.
            return 0
        }

        // The permission sheet for the Effort types is raised HERE and only here: at the
        // first moment the app actually holds a watch workout whose rating it wants. An
        // athlete who granted Health before v1.7.3 sees it once, attached to the thing it
        // is for; everyone else sees nothing (iOS renders no sheet when nothing is
        // undetermined).
        await healthKit.refreshAuthorizationIfNeeded()

        var comparable = fetchComparableSessions(around: batch.workouts, modelContext: modelContext)
        var logged = 0

        for workout in batch.workouts {
            let candidate = WatchWorkoutMatcher.Candidate(
                workoutUUID: workout.uuid,
                start: workout.startDate,
                durationSeconds: Int(workout.duration)
            )
            // `comparable` grows as the loop logs, so two HealthKit records of one workout
            // (a watch and a third-party app both writing the session) resolve to one.
            guard WatchWorkoutMatcher.decide(candidate: candidate, existing: comparable) == .log else {
                continue
            }

            // `isAthleteRated` is read and deliberately not branched on. Apple's estimate is
            // a weaker claim than the athlete's own rating, but it is still the best number
            // available and the alternative is no RPE at all — which would leave the session
            // counting toward density while carrying zero load. There is no provenance field
            // on `WorkoutSession` to record the difference in, so it is documented here
            // rather than silently discarded.
            let effort = try? await healthKit.fetchWorkoutEffort(for: workout)
            let session = makeSession(
                from: workout,
                effortScore: effort?.score,
                athlete: athlete
            )
            modelContext.insert(session)

            do {
                _ = try WorkoutPipeline.processSession(
                    session,
                    athlete: athlete,
                    modelContext: modelContext,
                    syncService: syncService
                )
                comparable.append(
                    WatchWorkoutMatcher.ExistingSession(
                        healthKitWorkoutUUID: session.healthKitWorkoutUUID,
                        start: session.sessionDate,
                        durationSeconds: session.durationSeconds
                    )
                )
                logged += 1
            } catch {
                // The session is inserted but its derived load did not land. Roll it back
                // rather than leave a session that counts toward density and carries no
                // load. The save is explicit because the pipeline saves partway through
                // (`WorkoutPipeline.swift:73`), so by the time it throws the insert may
                // already be on disk — an unsaved delete would leave it there.
                modelContext.delete(session)
                try? modelContext.save()
                print("Watch import pipeline error: \(error)")
            }
        }

        // Banked only after the batch is fully processed: a crash mid-loop leaves the anchor
        // where it was, and the next run re-offers the same workouts — which the UUID key
        // then refuses one by one. Re-running is free; losing a workout is not.
        saveAnchor(batch.anchor)
        return logged
    }

    // MARK: - Session construction

    /// Build the session a watch workout describes.
    ///
    /// A cardio workout gets one exercise entry carrying its distance and duration, exactly
    /// as the retired importer built it, so nothing downstream changes shape. A strength or
    /// skill workout gets no entries — the watch does not know what was lifted, and inventing
    /// a placeholder movement would put a lie in the Movement Bank's history.
    static func makeSession(
        from workout: HKWorkout,
        effortScore: Double?,
        athlete: Athlete
    ) -> WorkoutSession {
        let rpe = effortScore.map(WatchWorkoutMatcher.sessionRPE(fromEffortScore:))
        let session = WorkoutSession(
            sessionDate: workout.startDate,
            sessionName: workoutName(for: workout.workoutActivityType),
            sportType: sportType(for: workout.workoutActivityType),
            durationSeconds: Int(workout.duration),
            sessionRPE: rpe,
            sessionType: sessionType(for: workout.workoutActivityType)
        )
        session.healthKitWorkoutUUID = workout.uuid

        let distance = workout.totalDistance?.doubleValue(for: .meter()) ?? 0
        if distance > 0 {
            let entry = ExerciseEntry(
                exerciseName: session.sessionName ?? "",
                exerciseCategory: .cardio,
                muscleGroup: .fullBody,
                orderIndex: 0
            )
            entry.sets.append(
                SetRecord(
                    setIndex: 0,
                    durationSeconds: session.durationSeconds,
                    distanceMeters: distance,
                    rpe: rpe
                )
            )
            session.exerciseEntries.append(entry)
        }

        session.recalculateDerivedFields()
        session.athlete = athlete
        return session
    }

    // MARK: - Scoping

    /// Every stored session that could plausibly cover one of these workouts.
    ///
    /// One fetch for the whole batch, bounded to the batch's own span plus a day either side
    /// — wide enough that no overlap is missed, narrow enough that the matcher is comparing
    /// against a handful of rows rather than the athlete's whole history.
    private static func fetchComparableSessions(
        around workouts: [HKWorkout],
        modelContext: ModelContext
    ) -> [WatchWorkoutMatcher.ExistingSession] {
        guard
            let earliest = workouts.map(\.startDate).min(),
            let latest = workouts.map({ $0.startDate.addingTimeInterval($0.duration) }).max(),
            let lower = Calendar.current.date(byAdding: .day, value: -1, to: earliest),
            let upper = Calendar.current.date(byAdding: .day, value: 1, to: latest)
        else { return [] }

        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.sessionDate >= lower && $0.sessionDate <= upper }
        )
        let sessions = (try? modelContext.fetch(descriptor)) ?? []
        return sessions.map {
            WatchWorkoutMatcher.ExistingSession(
                healthKitWorkoutUUID: $0.healthKitWorkoutUUID,
                start: $0.sessionDate,
                durationSeconds: $0.durationSeconds
            )
        }
    }

    // MARK: - Anchor store

    static func loadAnchor() -> HKQueryAnchor? {
        guard let data = UserDefaults.standard.data(forKey: anchorKey) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
    }

    static func saveAnchor(_ anchor: HKQueryAnchor) {
        guard let data = try? NSKeyedArchiver.archivedData(
            withRootObject: anchor,
            requiringSecureCoding: true
        ) else { return }
        UserDefaults.standard.set(data, forKey: anchorKey)
    }

    /// Forget what has been seen. Used on sign-out, where the next athlete on this device
    /// must not inherit the previous one's import bookmark.
    static func resetAnchor() {
        UserDefaults.standard.removeObject(forKey: anchorKey)
    }

    // MARK: - Activity mapping
    //
    // Carried verbatim from the retired `WorkoutImportSuggestion` so no session already in
    // history would classify differently today than it did when it was imported.

    static func sportType(for activityType: HKWorkoutActivityType) -> SportType {
        switch activityType {
        case .running, .walking, .hiking:
            return .running
        case .cycling:
            return .cycling
        case .swimming:
            return .swimming
        case .basketball, .soccer, .tennis, .volleyball, .baseball, .hockey,
             .rugby, .handball, .lacrosse, .badminton, .tableTennis, .racquetball,
             .squash, .cricket, .softball:
            return .teamSport
        case .crossTraining, .functionalStrengthTraining, .highIntensityIntervalTraining:
            return .crossfit
        case .traditionalStrengthTraining:
            return .lifting
        default:
            return .custom
        }
    }

    static func sessionType(for activityType: HKWorkoutActivityType) -> SessionType {
        switch activityType {
        case .traditionalStrengthTraining, .functionalStrengthTraining:
            return .strength
        case .running, .cycling, .swimming, .walking, .hiking, .rowing:
            return .cardio
        case .basketball, .soccer, .tennis, .volleyball, .baseball, .hockey:
            return .skill
        case .highIntensityIntervalTraining, .crossTraining:
            return .cardio
        default:
            return .cardio
        }
    }

    static func workoutName(for activityType: HKWorkoutActivityType) -> String {
        switch activityType {
        case .running: return "Run"
        case .walking: return "Walk"
        case .hiking: return "Hike"
        case .cycling: return "Ride"
        case .swimming: return "Swim"
        case .basketball: return "Basketball"
        case .soccer: return "Soccer"
        case .tennis: return "Tennis"
        case .volleyball: return "Volleyball"
        case .baseball: return "Baseball"
        case .hockey: return "Hockey"
        case .rugby: return "Rugby"
        case .traditionalStrengthTraining: return "Strength Training"
        case .functionalStrengthTraining: return "Functional Training"
        case .highIntensityIntervalTraining: return "HIIT"
        case .crossTraining: return "Cross Training"
        case .rowing: return "Rowing"
        case .yoga: return "Yoga"
        case .pilates: return "Pilates"
        case .elliptical: return "Elliptical"
        case .stairClimbing: return "Stair Climbing"
        case .dance: return "Dance"
        case .martialArts: return "Martial Arts"
        case .boxing: return "Boxing"
        default: return "Workout"
        }
    }
}
