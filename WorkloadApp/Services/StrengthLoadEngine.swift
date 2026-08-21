import Foundation

/// Pure, deterministic strength-load model (Phase 27, Wave 1).
///
/// Builds the per-muscle HARD-SET / relative-intensity substrate that the Phase-27
/// `StrainRiskEngine` (Wave 3) consumes. This is the structural moat input (competitive
/// §3.1, CHANGE 1): serious-athlete strength sessions are characterised by *hard sets at
/// relative intensity*, NOT by raw tonnage. Raw `weight × reps` tonnage is deliberately
/// NEVER summed anywhere in this engine.
///
/// ## Pure / Foundation-only / dateless-by-injection
/// Static methods only, no stored state. Foundation-only — no `Date.now` /
/// `Calendar.current`: every method that needs day math takes a passed-in `asOf: Date`
/// and `calendar: Calendar` (mirrors the `BaselineEngine` dateless contract). Same input
/// → identical output, always.
///
/// ## est-1RM is REUSED, never reimplemented
/// Relative intensity uses the EXISTING `SetRecord.estimated1RM` (Epley) computed property
/// as the per-set 1RM estimate and as the source of the per-(muscleGroup, exerciseName)
/// rolling-best reference. Epley is NOT re-derived here.
///
/// ## Honest framing
/// This produces load-tolerance *context* primitives (hard-set counts, intensity buckets,
/// acute-vs-chronic elevation, same-region recurrence). It is NEVER an injury prediction.
struct StrengthLoadEngine {

    // MARK: - Output types

    /// Relative-intensity bucket for a scored working set.
    enum IntensityBucket: String, Equatable {
        case light
        case moderate
        case heavy
        case maximal
    }

    /// Classification of a single `SetRecord`.
    enum SetClassification: Equatable {
        /// Flagged `isWarmup` — never counts toward hard or easy.
        case warmup
        /// No weight AND no rpe AND no rir — cannot be scored; tallied separately.
        case unscored
        /// Scored but below the hard-set bar.
        case easy
        /// Scored at or above the hard-set bar (carries the relative-intensity bucket when
        /// intensity could be computed; `nil` bucket = qualified on RIR alone, no rel-intensity).
        case hard(IntensityBucket?)
    }

    /// Per-muscle aggregation result.
    struct MuscleStrengthLoad: Equatable {
        /// Number of qualifying HARD working sets mapped to this muscle.
        let hardSetCount: Int
        /// Sum of per-bucket strain weights across this muscle's hard sets (a relative-
        /// intensity-weighted hard-set tally — NOT tonnage).
        let strengthLoad: Double
        /// Working sets that could not be scored (no weight & no rpe/rir).
        let unscoredCount: Int
        /// Acute-vs-chronic strength-load elevation, 0…1 (deadband + clamp).
        let elevation: Double
        /// Scored working sets classified `.easy` (below the hard bar) in the ACUTE window.
        /// Captured for Finding-5 coverage confidence (Wave 3): coverage counts easy +
        /// hard scored sets, not just hard.
        let easyCount: Int
        /// Whether this muscle has a non-zero CHRONIC-EXCLUSIVE baseline (load in the
        /// 7..<28-day window). When false (new exercise / warmups-only history), elevation
        /// is reported as 0 (NOT an artifactual 4× ratio) and Wave-3 confidence discounts the
        /// muscle as insufficient-baseline rather than treating it as silently safe.
        let hasChronicBaseline: Bool
    }

    /// Full engine result for a window of sessions.
    struct StrengthLoadResult: Equatable {
        let perMuscle: [MuscleGroup: MuscleStrengthLoad]
        let perRegion: [MuscleRegion: Double]
        /// Regions where logged soreness AND acute strength-load elevation coincide
        /// (generalized same-region recurrence cascade — no tendon-specific claim).
        let recurrenceFlags: Set<MuscleRegion>
    }

    // MARK: - Named constants (the SINGLE home for every tunable)

    enum Constants {
        // Relative-intensity bucket cut points (fraction of est-1RM reference).
        static let moderateCut: Double = 0.65   // [0.65, 0.80) = moderate
        static let heavyCut: Double = 0.80      // [0.80, 0.90) = heavy
        static let maximalCut: Double = 0.90    // >= 0.90       = maximal
        // < moderateCut = light

        /// Relative intensity at or above which a set is "hard" by load.
        static let hardSetIntensityThreshold: Double = heavyCut   // >= 0.80 of est-1RM
        /// RIR at or below which a set is "hard" by proximity to failure.
        static let hardSetRIRThreshold: Int = 2                   // <= 2 reps in reserve

        /// RPE→RIR bridge ceiling (RIR = max(0, rpeToRIRMax - rpe)).
        static let rpeToRIRMax: Double = 10.0

        /// Per-bucket strain weight applied to each hard set when summing `strengthLoad`.
        /// Monotonic in intensity; a hard set that qualified on RIR alone (no rel-intensity)
        /// gets the moderate weight as a neutral default.
        static func strainWeight(for bucket: IntensityBucket?) -> Double {
            switch bucket {
            case .light:    return 0.6   // only reachable via RIR-hard at low rel-intensity
            case .moderate: return 0.8
            case .heavy:    return 1.0
            case .maximal:  return 1.3
            case nil:       return 0.8   // RIR-hard, intensity unknown
            }
        }

        // Acute-vs-chronic elevation (FatigueIndex loadElevation philosophy — NOT ACWR).
        /// Ratio band treated as "normal" — no elevation inside it.
        static let elevationDeadband: Double = 0.20   // |ratio − 1| <= 0.20 ⇒ 0
        /// Scales the above-deadband excess into 0…1.
        static let elevationScale: Double = 1.0       // (excess / scale), clamped 0…1

        // Default windows (days) — callers may override.
        static let acuteWindowDays: Int = 7
        static let chronicWindowDays: Int = 28
    }

    // MARK: - Primitives (Task 1)

    /// Estimated reps-in-reserve for a set: logged `rir` wins; else bridge from `rpe`
    /// (`max(0, 10 − rpe)`); else `nil`.
    ///
    /// NOTE: this TRUNCATES the RPE bridge (`Int(2.5) == 2`) and is kept ONLY for the
    /// display / back-compat callers that need an `Int`. Classification uses
    /// `estRIRPrecise` (Double) so a fractional RPE is not rounded into the hard bucket
    /// (Finding 4 / GA-30-D).
    static func estRIR(_ set: SetRecord) -> Int? {
        if let rir = set.rir { return rir }
        if let rpe = set.rpe { return Int(max(0.0, Constants.rpeToRIRMax - rpe)) }
        return nil
    }

    /// Un-truncated reps-in-reserve for classification: logged `rir` wins as `Double(rir)`;
    /// else bridge from `rpe` (`max(0, 10 − rpe)`) WITHOUT truncation; else `nil`.
    ///
    /// Finding 4 / GA-30-D: `estRIR` truncated RPE 7.5 → RIR 2 → falsely `.hard` (≤ 2 bar).
    /// Comparing the precise Double (2.5) against the Double threshold keeps a 7.5-RPE set
    /// `.easy`. RPE 8.0 → 2.0 stays hard.
    static func estRIRPrecise(_ set: SetRecord) -> Double? {
        if let rir = set.rir { return Double(rir) }
        if let rpe = set.rpe { return max(0.0, Constants.rpeToRIRMax - rpe) }
        return nil
    }

    /// Relative intensity = `weightKg / e1RMReference`, or `nil` when no weight / ref <= 0.
    static func relativeIntensity(set: SetRecord, e1RMReference: Double?) -> Double? {
        // `weight > 0` (council fix, 2026-08-13): 0 kg now means BODYWEIGHT on
        // bodyweight movements. Without external load there is no relative intensity
        // against a barbell e1RM — treat it as missing signal, never as intensity 0.
        guard let weight = set.weightKg, weight > 0, let ref = e1RMReference, ref > 0 else { return nil }
        return weight / ref
    }

    /// Map a relative intensity to a bucket.
    static func intensityBucket(_ relIntensity: Double) -> IntensityBucket {
        switch relIntensity {
        case ..<Constants.moderateCut: return .light
        case Constants.moderateCut..<Constants.heavyCut: return .moderate
        case Constants.heavyCut..<Constants.maximalCut: return .heavy
        default: return .maximal
        }
    }

    /// Classify a single set against a per-(muscle, exercise) est-1RM reference.
    static func classify(set: SetRecord, e1RMReference: Double?) -> SetClassification {
        if set.isWarmup { return .warmup }

        let relIntensity = relativeIntensity(set: set, e1RMReference: e1RMReference)
        // Use the precise (un-truncated) RIR for the hard-set decision (Finding 4 / GA-30-D).
        let rirPrecise = estRIRPrecise(set)

        // Cannot score at all (no weight AND no rpe/rir) → unscored.
        guard relIntensity != nil || rirPrecise != nil else { return .unscored }

        let hardByIntensity = (relIntensity ?? 0) >= Constants.hardSetIntensityThreshold
        // Compare in Double against the threshold (2.0) BEFORE any truncation so
        // RPE 7.5 → 2.5 RIR → not hard, while RPE 8.0 → 2.0 → hard.
        let hardByRIR = (rirPrecise ?? .greatestFiniteMagnitude) <= Double(Constants.hardSetRIRThreshold)

        if hardByIntensity || hardByRIR {
            let bucket = relIntensity.map(intensityBucket)
            return .hard(bucket)
        }
        return .easy
    }

    // MARK: - Per-muscle aggregation (Task 2)

    /// Rolling-best est-1RM reference per (muscleGroup, exerciseName) across the passed-in
    /// history. Pure recompute from `SetRecord.estimated1RM` — no persisted state needed.
    ///
    /// Keyed by `(MuscleGroup.rawValue, exerciseName)`; exercises with a nil muscleGroup are
    /// excluded (cannot be attributed to a muscle).
    static func e1RMReferences(sessions: [WorkoutSession]) -> [String: Double] {
        var refs: [String: Double] = [:]
        for session in sessions {
            for entry in session.exerciseEntries {
                guard let muscle = entry.muscleGroup else { continue }
                let key = referenceKey(muscle: muscle, exerciseName: entry.exerciseName)
                for set in entry.sets {
                    guard let e1rm = set.estimated1RM else { continue }
                    refs[key] = max(refs[key] ?? 0, e1rm)
                }
            }
        }
        return refs
    }

    private static func referenceKey(muscle: MuscleGroup, exerciseName: String) -> String {
        "\(muscle.rawValue)::\(exerciseName)"
    }

    /// Sum the per-bucket hard-set strain load for one muscle across a set of sessions,
    /// using the supplied est-1RM references. Returns (hardSetCount, strengthLoad,
    /// unscoredCount).
    private static func aggregateMuscle(
        muscle: MuscleGroup,
        sessions: [WorkoutSession],
        references: [String: Double]
    ) -> (hardSetCount: Int, strengthLoad: Double, unscoredCount: Int, easyCount: Int) {
        var hardSetCount = 0
        var strengthLoad = 0.0
        var unscoredCount = 0
        var easyCount = 0

        for session in sessions {
            for entry in session.exerciseEntries where entry.muscleGroup == muscle {
                let ref = references[referenceKey(muscle: muscle, exerciseName: entry.exerciseName)]
                for set in entry.sets {
                    switch classify(set: set, e1RMReference: ref) {
                    case .warmup:
                        continue
                    case .unscored:
                        unscoredCount += 1
                    case .easy:
                        // Finding 5 (GA-30-E): count scored easy sets so Wave-3 coverage
                        // confidence can include them (was silently dropped).
                        easyCount += 1
                    case .hard(let bucket):
                        hardSetCount += 1
                        strengthLoad += Constants.strainWeight(for: bucket)
                    }
                }
            }
        }
        return (hardSetCount, strengthLoad, unscoredCount, easyCount)
    }

    /// Acute-vs-chronic strength-load elevation (FatigueIndex `computeLoadElevation`
    /// philosophy: ratio with a deadband, clamped 0…1 — NOT ACWR). Returns 0 inside the
    /// deadband or when `chronic <= 0`.
    static func perMuscleElevation(acute: Double, chronic: Double) -> Double {
        guard chronic > 0 else { return 0 }
        let ratio = acute / chronic
        let excess = abs(ratio - 1.0) - Constants.elevationDeadband
        // Only an acute INCREASE elevates risk (a drop below baseline is not strain).
        guard ratio > 1.0, excess > 0 else { return 0 }
        return clamp(excess / Constants.elevationScale, min: 0, max: 1)
    }

    /// Same-region recurrence: regions present in BOTH the logged soreness regions and the
    /// elevated regions (generalized cascade, D-27-05). Handles all 7 `MuscleRegion` cases.
    static func sameRegionRecurrence(
        sorenessRegions: [MuscleRegion],
        elevatedRegions: Set<MuscleRegion>
    ) -> Set<MuscleRegion> {
        Set(sorenessRegions).intersection(elevatedRegions)
    }

    /// Full per-muscle strength-load over an acute window vs a chronic window, plus region
    /// rollup and same-region recurrence flags.
    ///
    /// - Parameters:
    ///   - sessions: athlete-scoped sessions (any length; windowed internally by date).
    ///   - sorenessRegions: regions with a recent qualifying soreness signal (Wave 3 supplies
    ///     these from Phase 25 — passed in as a plain parameter so the engine stays free of
    ///     SwiftData fetches).
    ///   - asOf / calendar: injected for determinism (no `Date.now` / `Calendar.current`).
    static func perMuscleStrengthLoad(
        sessions: [WorkoutSession],
        sorenessRegions: [MuscleRegion] = [],
        asOf: Date,
        calendar: Calendar,
        acuteWindowDays: Int = Constants.acuteWindowDays,
        chronicWindowDays: Int = Constants.chronicWindowDays
    ) -> StrengthLoadResult {
        // Finding 3 (GA-30-C): acute and chronic are EXACTLY PARTITIONED half-open windows so
        // chronic is NOT a superset of acute. Acute = days [0, acuteWindowDays);
        // chronic-exclusive = days [acuteWindowDays, chronicWindowDays). A steady-state athlete
        // therefore gets ratio ≈ 1 (elevation 0) instead of the old superset artefact (~4×).
        let acuteSessions = windowedRange(
            sessions, lowerDayInclusive: 0, upperDayExclusive: acuteWindowDays,
            asOf: asOf, calendar: calendar
        )
        let chronicExclSessions = windowedRange(
            sessions, lowerDayInclusive: acuteWindowDays, upperDayExclusive: chronicWindowDays,
            asOf: asOf, calendar: calendar
        )

        // References computed from the FULL passed-in history (rolling best is monotone).
        let references = e1RMReferences(sessions: sessions)

        // Consider muscles appearing in EITHER window so a new acute-only muscle is still
        // evaluated (and flagged insufficient-baseline) rather than skipped.
        var muscles = Set<MuscleGroup>()
        for session in acuteSessions + chronicExclSessions {
            for entry in session.exerciseEntries {
                if let m = entry.muscleGroup { muscles.insert(m) }
            }
        }

        // Per-day-normalised load so acute and the chronic-EXCLUSIVE window compare on the same
        // per-day basis. Chronic normaliser is the exclusive span (chronic − acute) days.
        let acuteDays = Double(max(1, acuteWindowDays))
        let chronicExclDays = Double(max(1, chronicWindowDays - acuteWindowDays))

        var perMuscle: [MuscleGroup: MuscleStrengthLoad] = [:]
        var perRegion: [MuscleRegion: Double] = [:]
        var elevatedRegions = Set<MuscleRegion>()

        for muscle in muscles {
            let acute = aggregateMuscle(muscle: muscle, sessions: acuteSessions, references: references)
            let chronicExcl = aggregateMuscle(muscle: muscle, sessions: chronicExclSessions, references: references)

            let acutePerDay = acute.strengthLoad / acuteDays
            let chronicPerDay = chronicExcl.strengthLoad / chronicExclDays
            // Zero chronic-exclusive load = new exercise / warmups only → insufficient baseline:
            // report elevation 0 (never 4×) and flag it so Wave-3 confidence discounts honestly.
            let hasChronicBaseline = chronicExcl.strengthLoad > 0
            let elevation = hasChronicBaseline
                ? perMuscleElevation(acute: acutePerDay, chronic: chronicPerDay)
                : 0

            perMuscle[muscle] = MuscleStrengthLoad(
                hardSetCount: acute.hardSetCount,
                strengthLoad: acute.strengthLoad,
                unscoredCount: acute.unscoredCount,
                elevation: elevation,
                easyCount: acute.easyCount,
                hasChronicBaseline: hasChronicBaseline
            )

            let region = muscle.region
            perRegion[region, default: 0] += acute.strengthLoad
            if elevation > 0 { elevatedRegions.insert(region) }
        }

        let recurrence = sameRegionRecurrence(
            sorenessRegions: sorenessRegions,
            elevatedRegions: elevatedRegions
        )

        return StrengthLoadResult(
            perMuscle: perMuscle,
            perRegion: perRegion,
            recurrenceFlags: recurrence
        )
    }

    // MARK: - Helpers

    /// Sessions whose `sessionDate` day-difference from `asOf` falls in the HALF-OPEN range
    /// `[lowerDayInclusive, upperDayExclusive)`, compared on `calendar.startOfDay`.
    /// Future-dated sessions (diff < 0) are excluded.
    ///
    /// Finding 3 / GA-30-C: the previous `diff >= 0 && diff <= days` form was inclusive of
    /// BOTH endpoints (spanning `days+1` calendar days) and was reused for acute and chronic,
    /// making chronic a superset of acute. This half-open form lets the caller partition acute
    /// `[0, acuteWindowDays)` and chronic-exclusive `[acuteWindowDays, chronicWindowDays)` with
    /// no shared boundary day: a session exactly at `diff == acuteWindowDays` lands in chronic,
    /// not acute.
    private static func windowedRange(
        _ sessions: [WorkoutSession],
        lowerDayInclusive: Int,
        upperDayExclusive: Int,
        asOf: Date,
        calendar: Calendar
    ) -> [WorkoutSession] {
        let to = calendar.startOfDay(for: asOf)
        return sessions.filter { session in
            let from = calendar.startOfDay(for: session.sessionDate)
            guard let diff = calendar.dateComponents([.day], from: from, to: to).day else { return false }
            return diff >= lowerDayInclusive && diff < upperDayExclusive
        }
    }

    private static func clamp(_ value: Double, min: Double, max: Double) -> Double {
        Swift.min(max, Swift.max(min, value))
    }
}

// MARK: - Bodyweight load (v1.7.2 audit — "option C")

/// Turns a bodyweight set into a real external load.
///
/// The set-entry convention since v1.7.1 is that `weightKg == 0` on a `.bodyweight` movement
/// means "bodyweight", and `nil` means "never entered" (a logged bodyweight set must never be
/// indistinguishable from a forgotten field). That convention made the ROW honest and left the
/// MATH wrong: 0 kg × 10 reps is 0, so three sets of ten pull-ups registered no volume at all
/// and a pure-calisthenics session reported an external load of zero. sRPE-driven training
/// stress was unaffected — only volume, weekly volume and load distribution were blind.
///
/// The missing quantity is the athlete's body mass, which the app now reads from HealthKit
/// (`Athlete.bodyMassKg`, device-local — raw HealthKit values never leave the phone).
///
/// **What this deliberately does NOT touch:** `estimated1RM`, personal records and
/// `relativeIntensity`. Giving a pull-up an e1RM overnight would mint a burst of "records"
/// against a stored value of zero, and the right e1RM reference for a bodyweight movement is a
/// separate modelling question. This is the total-load fix and nothing else.
enum BodyweightLoad {

    /// Used when a movement is not recognised. Deliberately mid-range rather than 1.0: over-
    /// stating load feeds an inflated ACWR, and an inflated ACWR tells an athlete to back off
    /// a session they could have trained. The conservative error is the safe one here.
    static let defaultFraction = 0.65

    /// Fraction of body mass a movement actually moves.
    ///
    /// Rounded published estimates, matched on the lowercased exercise name. The table is
    /// short on purpose — every entry is a claim about a body, and a long table of guesses
    /// reads as precision the numbers do not have.
    static func fraction(exerciseName: String) -> Double {
        let name = exerciseName.lowercased()
        // Hanging and vertical pressing move essentially the whole body.
        if name.contains("pull-up") || name.contains("pull up") || name.contains("pullup")
            || name.contains("chin-up") || name.contains("chin up") || name.contains("chinup")
            || name.contains("muscle-up") || name.contains("muscle up")
            || name.contains("dip") {
            return 1.0
        }
        if name.contains("inverted row") || name.contains("australian") {
            return 0.60
        }
        if name.contains("push-up") || name.contains("push up") || name.contains("pushup")
            || name.contains("press-up") || name.contains("press up") {
            return 0.65
        }
        if name.contains("squat") || name.contains("lunge") || name.contains("step-up")
            || name.contains("step up") || name.contains("pistol") {
            return 0.60
        }
        if name.contains("sit-up") || name.contains("sit up") || name.contains("crunch")
            || name.contains("leg raise") || name.contains("hollow") || name.contains("v-up") {
            return 0.40
        }
        return defaultFraction
    }

    /// The load a set actually moved, in kg.
    ///
    /// - Non-bodyweight movements are returned unchanged — this must never alter a barbell lift.
    /// - `nil` in, `nil` out: a set with no weight entered has no load, and inventing one from
    ///   body mass would turn a forgotten field into data.
    /// - No body mass on file → the pre-v1.7.2 answer (added load only). Degrading to the old
    ///   number is honest; guessing a body mass is not.
    static func effectiveLoadKg(
        weightKg: Double?,
        category: ExerciseCategory,
        exerciseName: String,
        bodyMassKg: Double?
    ) -> Double? {
        guard category == .bodyweight else { return weightKg }
        guard let addedKg = weightKg else { return nil }
        guard let bodyMassKg, bodyMassKg > 0 else { return addedKg }
        return bodyMassKg * fraction(exerciseName: exerciseName) + addedKg
    }
}
