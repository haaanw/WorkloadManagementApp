import Foundation

/// Pure, deterministic helper that resolves the *suggested center value* for a set
/// in the logging UI (weight block picker + reps scrubber). It reads ONLY data the
/// caller already has in hand — template/prescription targets, the in-session
/// previous set, the most-recent non-warmup set from the last session, and (Pro
/// only) an already-computed in-memory progression suggestion. It performs no
/// fetches, no engine calls, no writes, and no side effects.
///
/// Precedence (proposal §3.3 / §4.3):
///   1. Template / prescription target
///   2. In-session previous committed set in the same ExerciseEntry
///   3. Last-session most-recent NON-WARMUP set for the same exerciseName
///   4. In-memory progression suggestion (Pro only)
///   5. nil  → first-ever / unset (caller renders "—" and disables side tiles)
///
/// Each output field is resolved independently down the precedence ladder, so a
/// template that specifies only reps can still fall through to history for weight.
struct SetSuggestion {

    /// One candidate "source" of values in the precedence ladder. All fields
    /// optional; the resolver walks sources in order and takes the first non-nil
    /// value per field.
    struct Candidate {
        var weightKg: Double?
        var reps: Int?
        var distanceMeters: Double?
        var durationSeconds: Int?

        init(
            weightKg: Double? = nil,
            reps: Int? = nil,
            distanceMeters: Double? = nil,
            durationSeconds: Int? = nil
        ) {
            self.weightKg = weightKg
            self.reps = reps
            self.distanceMeters = distanceMeters
            self.durationSeconds = durationSeconds
        }

        var isEmpty: Bool {
            weightKg == nil && reps == nil && distanceMeters == nil && durationSeconds == nil
        }
    }

    /// Resolved suggestion. Any field may be nil → caller shows the unset
    /// placeholder ("—") and handles cold-start behavior per §3.6.
    struct Result {
        let centerWeightKg: Double?
        let reps: Int?
        let distanceMeters: Double?
        let durationSeconds: Int?
    }

    /// Resolve the suggested center values for a set.
    ///
    /// All inputs are already-available data; this function does NOT fetch or
    /// compute anything beyond a deterministic precedence walk. Category neutral
    /// reps fallback applies only to the reps field, and only when nothing earlier
    /// in the ladder supplied reps (§4.3).
    ///
    /// - Parameters:
    ///   - inputMode: which fields are meaningful for this exercise.
    ///   - exerciseName: for documentation/caller symmetry; not used to fetch.
    ///   - category: drives the neutral reps fallback only.
    ///   - templateTarget: target from a WorkoutTemplate / PrescribedWorkout, if any.
    ///   - inSessionPrevSet: the immediately-prior committed set in THIS entry.
    ///   - lastSessionSet: most-recent NON-WARMUP set for this exerciseName across
    ///                     prior sessions (caller must pre-filter warmups).
    ///   - isPro: gates the progression suggestion source (no flag change).
    ///   - progressionSuggestion: already-computed in-memory suggestion, Pro only.
    static func suggest(
        inputMode: ExerciseInputMode,
        exerciseName: String,
        category: ExerciseCategory,
        templateTarget: Candidate? = nil,
        inSessionPrevSet: Candidate? = nil,
        lastSessionSet: Candidate? = nil,
        isPro: Bool = false,
        progressionSuggestion: Candidate? = nil
    ) -> Result {
        // Precedence ladder. Pro-gated source only participates when isPro.
        var ladder: [Candidate?] = [
            templateTarget,
            inSessionPrevSet,
            lastSessionSet
        ]
        if isPro {
            ladder.append(progressionSuggestion)
        }
        let sources = ladder.compactMap { $0 }.filter { !$0.isEmpty }

        func firstWeight() -> Double? { sources.compactMap(\.weightKg).first }
        func firstReps() -> Int? { sources.compactMap(\.reps).first }
        func firstDistance() -> Double? { sources.compactMap(\.distanceMeters).first }
        func firstDuration() -> Int? { sources.compactMap(\.durationSeconds).first }

        let center: Double?
        let reps: Int?
        let distance: Double?
        let duration: Int?

        switch inputMode {
        case .weightReps:
            center = firstWeight()
            reps = firstReps() ?? neutralReps(for: category)
            distance = nil
            duration = nil
        case .repsOnly:
            center = nil
            reps = firstReps() ?? neutralReps(for: category)
            distance = nil
            duration = nil
        case .distanceDuration:
            center = nil
            reps = nil
            distance = firstDistance()
            duration = firstDuration()
        case .durationOnly:
            center = nil
            reps = nil
            distance = nil
            duration = firstDuration()
        }

        return Result(
            centerWeightKg: center,
            reps: reps,
            distanceMeters: distance,
            durationSeconds: duration
        )
    }

    /// Resolve the last-session most-recent NON-WARMUP set as a precedence-3 candidate
    /// (proposal §3.3 #3 / Phase F). `history` is the already-fetched, newest-session-first
    /// list from `ProgressionEngine.fetchHistory`; this walks it (newest first) and returns
    /// the first set per field from a non-warmup set. Pure: no fetch, no engine call.
    ///
    /// Warmup sets are excluded so progression isn't poisoned. Each field is resolved
    /// independently across sessions/sets (newest first) so a session whose top set lacks
    /// reps can still fall through to an earlier non-warmup set for reps.
    ///
    /// - Parameter history: `[ExerciseHistoryRecord]` newest-first (from `fetchHistory`).
    /// - Returns: a `Candidate` of the most-recent non-warmup values, or nil if there is
    ///            no non-warmup history at all (truly first-ever → caller renders "—").
    static func lastSessionCandidate(from history: [ExerciseHistoryRecord]) -> Candidate? {
        // Flatten to non-warmup sets in newest-first order (history is already newest-first;
        // within a session, sortedSets is ascending, so the latest performed set is last).
        let nonWarmup: [SetHistoryRecord] = history.flatMap { record in
            record.sets.filter { !$0.isWarmup }.reversed()
        }
        guard !nonWarmup.isEmpty else { return nil }

        let weight = nonWarmup.compactMap(\.weightKg).first
        let reps = nonWarmup.compactMap(\.reps).first
        let distance = nonWarmup.compactMap(\.distanceMeters).first
        let duration = nonWarmup.compactMap(\.durationSeconds).first

        let candidate = Candidate(
            weightKg: weight,
            reps: reps,
            distanceMeters: distance,
            durationSeconds: duration
        )
        return candidate.isEmpty ? nil : candidate
    }

    /// Single sensible neutral reps default by category (§4.3). Never a computed
    /// prescription — just a humane starting point when no history exists.
    static func neutralReps(for category: ExerciseCategory) -> Int {
        switch category {
        case .compound: return 5
        case .isolation: return 10
        case .bodyweight: return 10
        case .cardio, .interval, .plyometric, .drill: return 8
        }
    }
}

/// The `▲ PR` landmark's value — the heaviest weight ever logged on one movement.
///
/// Pure and separate from the view because the "heaviest" part is not obvious:
/// `PRDetector` **appends** a new `PersonalRecord` every time a lift is beaten rather than
/// updating the existing row, so a well-trained movement holds a whole history of `.maxWeight`
/// records and only the largest of them is the current PR. Taking `.first` would put an old,
/// lower number on the rule as if it were the record.
///
/// (`PRDetector` itself matches with `existingPRs.first { … }` against that same history, which
/// is a latent detection defect — recorded in `.planning/v172/AUDIT-HANDOFF.md`, not fixed
/// here: this lane draws the mark, it does not own PR detection.)
///
/// Exercise identity is the name string, matched exactly — the same rule the whole app uses
/// (`CLAUDE.md`: "Exercise identity = name string"), and the same comparison `PRDetector`
/// makes when it decides whether a record was beaten. A fuzzy match here would show a PR the
/// detector will never update.
enum PersonalRecordLookup {

    /// Heaviest logged weight in kg, or nil when the athlete has never set one on this
    /// movement — the normal state for most of a 1,324-exercise catalog.
    ///
    /// - Parameters:
    ///   - exerciseName: the movement, matched exactly.
    ///   - records: the athlete's own records. Pass `athlete.personalRecords`; this function
    ///     does no filtering by athlete because it never sees more than one athlete's rows.
    static func bestMaxWeightKg(
        exerciseName: String,
        in records: [PersonalRecord]
    ) -> Double? {
        records
            .filter { $0.recordType == .maxWeight && $0.exerciseName == exerciseName }
            .map(\.value)
            .max()
    }
}
