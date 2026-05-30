import XCTest
@testable import workload_management

/// Wave-1 unit tests for the pure `StrengthLoadEngine`: relative-intensity buckets, the
/// RPE→RIR bridge, hard-set classification, per-muscle aggregation, acute-vs-chronic
/// elevation, and same-region recurrence. All dates derive from a FIXED anchor with a
/// FIXED UTC calendar so the suite is deterministic (no `.now` / `Calendar.current`).
final class StrengthLoadEngineTests: XCTestCase {

    // MARK: - Fixed anchor + calendar

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    /// 2026-03-15 00:00:00 UTC anchor.
    private var asOf: Date {
        DateComponents(calendar: calendar, year: 2026, month: 3, day: 15).date!
    }

    private func daysAgo(_ n: Int) -> Date {
        calendar.date(byAdding: .day, value: -n, to: asOf)!
    }

    // MARK: - Builders

    private func makeSet(
        weightKg: Double? = nil,
        reps: Int? = nil,
        rpe: Double? = nil,
        rir: Int? = nil,
        isWarmup: Bool = false
    ) -> SetRecord {
        SetRecord(reps: reps, weightKg: weightKg, rpe: rpe, rir: rir, isWarmup: isWarmup)
    }

    private func makeSession(
        date: Date,
        muscle: MuscleGroup,
        exerciseName: String = "Back Squat",
        sets: [SetRecord]
    ) -> WorkoutSession {
        let session = WorkoutSession(sessionDate: date)
        let entry = ExerciseEntry(exerciseName: exerciseName, muscleGroup: muscle)
        entry.sets = sets
        session.exerciseEntries = [entry]
        return session
    }

    // MARK: - RIR bridge

    func test_estRIR_loggedRIRWins() {
        let set = makeSet(rpe: 8, rir: 4)
        XCTAssertEqual(StrengthLoadEngine.estRIR(set), 4)
    }

    func test_estRIR_bridgeFromRPE() {
        XCTAssertEqual(StrengthLoadEngine.estRIR(makeSet(rpe: 8)), 2)
        XCTAssertEqual(StrengthLoadEngine.estRIR(makeSet(rpe: 10)), 0)
        XCTAssertEqual(StrengthLoadEngine.estRIR(makeSet(rpe: 6)), 4)
    }

    func test_estRIR_noneWhenNeither() {
        XCTAssertNil(StrengthLoadEngine.estRIR(makeSet(weightKg: 100, reps: 5)))
    }

    // MARK: - Relative intensity

    func test_relativeIntensity_nilWhenNoWeightOrRefInvalid() {
        XCTAssertNil(StrengthLoadEngine.relativeIntensity(set: makeSet(reps: 5), e1RMReference: 100))
        XCTAssertNil(StrengthLoadEngine.relativeIntensity(set: makeSet(weightKg: 80), e1RMReference: 0))
        XCTAssertNil(StrengthLoadEngine.relativeIntensity(set: makeSet(weightKg: 80), e1RMReference: nil))
    }

    func test_relativeIntensity_value() {
        let ri = StrengthLoadEngine.relativeIntensity(set: makeSet(weightKg: 80), e1RMReference: 100)
        XCTAssertEqual(ri!, 0.80, accuracy: 1e-9)
    }

    // MARK: - Bucket boundaries

    func test_intensityBucketBoundaries() {
        XCTAssertEqual(StrengthLoadEngine.intensityBucket(0.64), .light)
        XCTAssertEqual(StrengthLoadEngine.intensityBucket(0.65), .moderate)
        XCTAssertEqual(StrengthLoadEngine.intensityBucket(0.79), .moderate)
        XCTAssertEqual(StrengthLoadEngine.intensityBucket(0.80), .heavy)
        XCTAssertEqual(StrengthLoadEngine.intensityBucket(0.89), .heavy)
        XCTAssertEqual(StrengthLoadEngine.intensityBucket(0.90), .maximal)
    }

    // MARK: - Classification

    func test_classify_warmup() {
        let set = makeSet(weightKg: 90, reps: 3, isWarmup: true)
        XCTAssertEqual(StrengthLoadEngine.classify(set: set, e1RMReference: 100), .warmup)
    }

    func test_classify_unscored() {
        // No weight AND no rpe/rir.
        let set = makeSet(reps: 8)
        XCTAssertEqual(StrengthLoadEngine.classify(set: set, e1RMReference: 100), .unscored)
    }

    func test_classify_hardByIntensity_carriesBucket() {
        let set = makeSet(weightKg: 85, reps: 3) // 85/100 = 0.85 -> heavy, hard by intensity
        XCTAssertEqual(StrengthLoadEngine.classify(set: set, e1RMReference: 100), .hard(.heavy))
    }

    func test_classify_hardByRIR_lowIntensity() {
        // 50/100 = 0.50 (light) but RIR 1 -> hard by RIR, bucket = light.
        let set = makeSet(weightKg: 50, rir: 1)
        XCTAssertEqual(StrengthLoadEngine.classify(set: set, e1RMReference: 100), .hard(.light))
    }

    func test_classify_hardByRIR_noIntensity_nilBucket() {
        let set = makeSet(rpe: 9) // RIR 1, no weight -> hard, nil bucket
        XCTAssertEqual(StrengthLoadEngine.classify(set: set, e1RMReference: nil), .hard(nil))
    }

    func test_classify_easy() {
        // 0.50 rel intensity, RIR 4 -> not hard by either.
        let set = makeSet(weightKg: 50, rir: 4)
        XCTAssertEqual(StrengthLoadEngine.classify(set: set, e1RMReference: 100), .easy)
    }

    func test_classify_determinism() {
        let set = makeSet(weightKg: 85, reps: 3)
        let a = StrengthLoadEngine.classify(set: set, e1RMReference: 100)
        let b = StrengthLoadEngine.classify(set: set, e1RMReference: 100)
        XCTAssertEqual(a, b)
    }

    // MARK: - e1RM references (rolling best)

    func test_e1RMReferences_rollingBest() {
        let s1 = makeSession(date: daysAgo(10), muscle: .quads, sets: [makeSet(weightKg: 100, reps: 1)])
        let s2 = makeSession(date: daysAgo(3), muscle: .quads, sets: [makeSet(weightKg: 90, reps: 5)]) // Epley 90*(1+5/30)=105
        let refs = StrengthLoadEngine.e1RMReferences(sessions: [s1, s2])
        let key = "quads::Back Squat"
        XCTAssertEqual(refs[key]!, 105.0, accuracy: 1e-9)
    }

    // MARK: - Per-muscle aggregation

    func test_perMuscle_hardSetCount_acrossSessions() {
        // Reference: a 1-rep 100kg single establishes 100 est-1RM for quads/Back Squat.
        let ref = makeSession(date: daysAgo(20), muscle: .quads, sets: [makeSet(weightKg: 100, reps: 1)])
        // Acute (within 7d): two heavy sets (85kg -> 0.85), one easy (50kg, rir 5).
        let acute = makeSession(date: daysAgo(2), muscle: .quads, sets: [
            makeSet(weightKg: 85, reps: 3),
            makeSet(weightKg: 85, reps: 3),
            makeSet(weightKg: 50, rir: 5)
        ])
        let result = StrengthLoadEngine.perMuscleStrengthLoad(
            sessions: [ref, acute],
            asOf: asOf,
            calendar: calendar
        )
        let quad = result.perMuscle[.quads]!
        XCTAssertEqual(quad.hardSetCount, 2)
        // Two heavy hard sets * 1.0 strain weight.
        XCTAssertEqual(quad.strengthLoad, 2.0, accuracy: 1e-9)
    }

    func test_perMuscle_unscoredTally() {
        let session = makeSession(date: daysAgo(1), muscle: .biceps, exerciseName: "Curl", sets: [
            makeSet(reps: 12) // no weight, no rpe/rir -> unscored
        ])
        let result = StrengthLoadEngine.perMuscleStrengthLoad(
            sessions: [session],
            asOf: asOf,
            calendar: calendar
        )
        XCTAssertEqual(result.perMuscle[.biceps]?.unscoredCount, 1)
        XCTAssertEqual(result.perMuscle[.biceps]?.hardSetCount, 0)
    }

    // MARK: - Elevation

    func test_perMuscleElevation_deadbandReturnsZero() {
        // ratio 1.1 -> |0.1| <= 0.20 deadband -> 0
        XCTAssertEqual(StrengthLoadEngine.perMuscleElevation(acute: 1.1, chronic: 1.0), 0, accuracy: 1e-9)
    }

    func test_perMuscleElevation_aboveDeadbandClamps() {
        // ratio 2.0 -> excess = 1.0 - 0.2 = 0.8 -> clamp(0.8) = 0.8
        XCTAssertEqual(StrengthLoadEngine.perMuscleElevation(acute: 2.0, chronic: 1.0), 0.8, accuracy: 1e-9)
        // ratio 3.0 -> excess 1.8 -> clamps to 1
        XCTAssertEqual(StrengthLoadEngine.perMuscleElevation(acute: 3.0, chronic: 1.0), 1.0, accuracy: 1e-9)
    }

    func test_perMuscleElevation_chronicZeroGuard() {
        XCTAssertEqual(StrengthLoadEngine.perMuscleElevation(acute: 5.0, chronic: 0), 0, accuracy: 1e-9)
    }

    func test_perMuscleElevation_dropBelowBaselineIsNotStrain() {
        // ratio 0.5 -> not an increase -> 0
        XCTAssertEqual(StrengthLoadEngine.perMuscleElevation(acute: 0.5, chronic: 1.0), 0, accuracy: 1e-9)
    }

    // MARK: - Same-region recurrence (all 7 regions)

    func test_sameRegionRecurrence_intersectionOnly() {
        let soreness: [MuscleRegion] = [.legs, .back, .core]
        let elevated: Set<MuscleRegion> = [.back, .chest, .fullBody]
        let recurrence = StrengthLoadEngine.sameRegionRecurrence(
            sorenessRegions: soreness,
            elevatedRegions: elevated
        )
        XCTAssertEqual(recurrence, [.back])
    }

    func test_sameRegionRecurrence_allSevenRegionsHandled() {
        let all: [MuscleRegion] = MuscleRegion.allCases
        XCTAssertEqual(all.count, 7)
        let recurrence = StrengthLoadEngine.sameRegionRecurrence(
            sorenessRegions: all,
            elevatedRegions: Set(all)
        )
        XCTAssertEqual(recurrence, Set(all))
    }

    func test_sameRegionRecurrence_emptyWhenNoOverlap() {
        let recurrence = StrengthLoadEngine.sameRegionRecurrence(
            sorenessRegions: [.legs],
            elevatedRegions: [.arms]
        )
        XCTAssertTrue(recurrence.isEmpty)
    }

    // MARK: - End-to-end recurrence (soreness + elevation coincide)

    func test_perMuscleStrengthLoad_recurrenceFlagsWhenSorenessAndElevationCoincide() {
        let ref = makeSession(date: daysAgo(25), muscle: .quads, sets: [makeSet(weightKg: 100, reps: 1)])
        // Chronic window has light activity; acute window spikes hard sets -> elevation in legs.
        let chronicLight = makeSession(date: daysAgo(20), muscle: .quads, sets: [
            makeSet(weightKg: 85, reps: 3)
        ])
        let acuteHeavy = makeSession(date: daysAgo(1), muscle: .quads, sets: [
            makeSet(weightKg: 90, reps: 3),
            makeSet(weightKg: 90, reps: 3),
            makeSet(weightKg: 90, reps: 3)
        ])
        let result = StrengthLoadEngine.perMuscleStrengthLoad(
            sessions: [ref, chronicLight, acuteHeavy],
            sorenessRegions: [.legs],
            asOf: asOf,
            calendar: calendar
        )
        XCTAssertGreaterThan(result.perMuscle[.quads]!.elevation, 0)
        XCTAssertTrue(result.recurrenceFlags.contains(.legs))
    }

    // MARK: - Determinism on a fixed fixture

    func test_perMuscleStrengthLoad_determinism() {
        let ref = makeSession(date: daysAgo(25), muscle: .quads, sets: [makeSet(weightKg: 100, reps: 1)])
        let acute = makeSession(date: daysAgo(2), muscle: .quads, sets: [makeSet(weightKg: 85, reps: 3)])
        let a = StrengthLoadEngine.perMuscleStrengthLoad(sessions: [ref, acute], asOf: asOf, calendar: calendar)
        let b = StrengthLoadEngine.perMuscleStrengthLoad(sessions: [ref, acute], asOf: asOf, calendar: calendar)
        XCTAssertEqual(a, b)
    }
}
