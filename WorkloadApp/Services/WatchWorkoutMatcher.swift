import Foundation

/// The guard that stops a watch-recorded workout from double-counting load
/// (v1.7.3, UAT round 1 · U4).
///
/// HAN's ruling makes watch workouts log by themselves. That removes the human who used to
/// read the "Add" row and decide, so the decision has to become an explicit rule — and the
/// rule has to fail SAFE. A session logged twice inflates ATL, ACWR and the fatigue index
/// for the next four weeks and there is no signal that anything is wrong; a session missed
/// once is visible in history and can be added by hand in under a minute. So where the
/// evidence is ambiguous this refuses to log.
///
/// The retired surface matched on a POINT: a candidate was suppressed when some session
/// started within five minutes of it (`WorkoutImportBanner.findUnmatchedWorkouts`). That
/// failed in both directions. An athlete who opened the Tuwa sheet, warmed up, and started
/// the watch ten minutes later got the session twice. Two genuinely different sessions that
/// happened to begin four minutes apart lost one of them, silently. Two intervals either
/// overlap or they do not — that is a question the data can actually answer, and it is the
/// question this asks.
///
/// Pure struct, static methods, no dependencies (the engine convention).
struct WatchWorkoutMatcher {

    // MARK: - Types

    /// A HealthKit workout being considered for auto-logging.
    struct Candidate: Equatable {
        let workoutUUID: UUID
        let start: Date
        let durationSeconds: Int

        init(workoutUUID: UUID, start: Date, durationSeconds: Int) {
            self.workoutUUID = workoutUUID
            self.start = start
            self.durationSeconds = durationSeconds
        }
    }

    /// The shape of an already-stored session this matcher compares against. A plain value
    /// rather than the `@Model` so the rule is testable without a `ModelContainer`.
    struct ExistingSession: Equatable {
        /// Set when the session was itself auto-logged from a HealthKit workout.
        let healthKitWorkoutUUID: UUID?
        let start: Date
        let durationSeconds: Int

        init(healthKitWorkoutUUID: UUID? = nil, start: Date, durationSeconds: Int) {
            self.healthKitWorkoutUUID = healthKitWorkoutUUID
            self.start = start
            self.durationSeconds = durationSeconds
        }
    }

    /// Why a candidate was or was not logged. Every refusal names itself so the decision is
    /// legible in a test and in a log line, rather than being an unexplained absence.
    enum Decision: Equatable {
        /// Nothing covers this workout — log it.
        case log
        /// A session already carries this workout's UUID. The idempotency key did its job:
        /// re-running the import (a lost anchor, a reinstall, a second foreground) can never
        /// produce a duplicate.
        case alreadyImported
        /// An athlete-logged session covers the same clock time. The athlete's own record
        /// wins — it carries exercises, sets and a rated RPE the watch does not have.
        case overlapsExistingSession
        /// Below the noise floor. A watch workout that ran under a minute is an accidental
        /// start, not training.
        case belowDurationFloor
    }

    // MARK: - Constants

    /// Workouts shorter than this are not training (v1.7.3).
    ///
    /// The retired surface used **five minutes**, which silently discarded a four-minute
    /// sprint block and any short skill session — one of the reasons U4's "recent workout
    /// missing" was reproducible on paper. One minute keeps the accidental-start filter and
    /// stops discarding real work.
    static let minimumDurationSeconds = 60

    /// The share of the SHORTER interval that must be covered before two records are called
    /// the same session. Half is deliberately generous: a watch started mid-warm-up, or
    /// stopped before the cooldown, still overlaps the app's session by well over half of
    /// whichever span is shorter.
    static let overlapFloor: Double = 0.5

    /// The fallback tolerance used when one of the two records has no duration — a
    /// hand-logged session that was never given one. With no interval to intersect, start
    /// proximity is the only evidence available.
    static let startProximitySeconds: TimeInterval = 600

    // MARK: - Decide

    /// The one entry point. `existing` should already be scoped to a window around the
    /// candidate; scoping is the caller's job, correctness is this function's.
    static func decide(
        candidate: Candidate,
        existing: [ExistingSession]
    ) -> Decision {
        if existing.contains(where: { $0.healthKitWorkoutUUID == candidate.workoutUUID }) {
            // Checked BEFORE the duration floor on purpose: an already-imported workout is
            // settled regardless of how long it ran, and reporting it as "too short" would
            // misdescribe what happened.
            return .alreadyImported
        }

        if candidate.durationSeconds < minimumDurationSeconds {
            return .belowDurationFloor
        }

        let isCovered = existing.contains { session in
            // A session that came from a DIFFERENT watch workout does not suppress this one.
            // Two back-to-back watch workouts (a lift, then a court session) are two
            // sessions, and each already owns its own idempotency key above.
            guard session.healthKitWorkoutUUID == nil else { return false }
            return isSameSession(candidate: candidate, session: session)
        }

        return isCovered ? .overlapsExistingSession : .log
    }

    // MARK: - Overlap

    /// Whether a candidate and a stored session describe the same block of training time.
    static func isSameSession(candidate: Candidate, session: ExistingSession) -> Bool {
        guard candidate.durationSeconds > 0, session.durationSeconds > 0 else {
            // No interval on one side — fall back to start proximity, the only evidence left.
            return abs(candidate.start.timeIntervalSince(session.start)) <= startProximitySeconds
        }
        return overlapFraction(candidate: candidate, session: session) >= overlapFloor
    }

    /// Intersection of the two intervals as a fraction of the SHORTER one, 0...1.
    ///
    /// Measuring against the shorter span rather than the union is what makes a 20-minute
    /// watch workout recorded inside a 60-minute logged session read as fully covered — it
    /// is, and the athlete's longer record is the one to keep.
    static func overlapFraction(candidate: Candidate, session: ExistingSession) -> Double {
        let candidateEnd = candidate.start.addingTimeInterval(Double(candidate.durationSeconds))
        let sessionEnd = session.start.addingTimeInterval(Double(session.durationSeconds))

        let overlapStart = max(candidate.start, session.start)
        let overlapEnd = min(candidateEnd, sessionEnd)
        let overlap = overlapEnd.timeIntervalSince(overlapStart)
        guard overlap > 0 else { return 0 }

        let shorter = Double(min(candidate.durationSeconds, session.durationSeconds))
        guard shorter > 0 else { return 0 }
        return min(1, overlap / shorter)
    }

    // MARK: - Effort

    /// Apple's workout Effort rating mapped onto the app's session RPE.
    ///
    /// Both instruments are 1–10 and both ask the same question after the fact — Apple's
    /// Effort ("Easy … All Out", watchOS 11+) is a category-ratio scale of how hard the
    /// session felt, which is what Foster's session-RPE is. So the map is the identity, and
    /// the only work here is clamping a decoded value that has drifted outside the scale.
    /// It is deliberately NOT a rescale: inventing a curve between two 1–10 scales would
    /// bias the single subjective input the whole load model rests on.
    ///
    /// The raw HealthKit sample never leaves the device (the HealthKit law). What syncs is
    /// the derived `WorkoutSession.sessionRPE`, exactly as it does for a hand-rated session.
    static func sessionRPE(fromEffortScore score: Double) -> Double {
        min(10, max(1, score.rounded()))
    }
}
