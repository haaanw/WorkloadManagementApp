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

    // MARK: - Precise (un-truncated) RIR bridge (Finding 4 / GA-30-D)

    func test_estRIRPrecise_loggedRIRWins() {
        XCTAssertEqual(StrengthLoadEngine.estRIRPrecise(makeSet(rpe: 8, rir: 4))!, 4.0, accuracy: 1e-9)
    }

    func test_estRIRPrecise_fractionalRPE_notTruncated() {
        // RPE 7.5 → 2.5 RIR (NOT 2 as the Int estRIR truncates to).
        XCTAssertEqual(StrengthLoadEngine.estRIRPrecise(makeSet(rpe: 7.5))!, 2.5, accuracy: 1e-9)
        XCTAssertEqual(StrengthLoadEngine.estRIRPrecise(makeSet(rpe: 8.0))!, 2.0, accuracy: 1e-9)
        XCTAssertEqual(StrengthLoadEngine.estRIRPrecise(makeSet(rpe: 7.6))!, 2.4, accuracy: 1e-9)
    }

    func test_estRIRPrecise_noneWhenNeither() {
        XCTAssertNil(StrengthLoadEngine.estRIRPrecise(makeSet(weightKg: 100, reps: 5)))
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

    // Finding 4 / GA-30-D: fractional RPE must compare in Double, not truncate, before the
    // ≤ 2 hard bar. RPE 7.5 (2.5 RIR) at low intensity is .easy; RPE 8.0 (2.0) is .hard.
    func test_classify_fractionalRPE_75_lowIntensity_isEasy() {
        // 50/100 = 0.50 (light) so not hard-by-intensity; RPE 7.5 → 2.5 RIR → not hard-by-RIR.
        let set = makeSet(weightKg: 50, rpe: 7.5)
        XCTAssertEqual(StrengthLoadEngine.classify(set: set, e1RMReference: 100), .easy)
    }

    func test_classify_fractionalRPE_76_lowIntensity_isEasy() {
        let set = makeSet(weightKg: 50, rpe: 7.6) // 2.4 RIR → not hard
        XCTAssertEqual(StrengthLoadEngine.classify(set: set, e1RMReference: 100), .easy)
    }

    func test_classify_RPE80_lowIntensity_isHard() {
        // 50/100 = 0.50 (light), RPE 8.0 → 2.0 RIR → hard-by-RIR; bucket = .light (rel-intensity known).
        let set = makeSet(weightKg: 50, rpe: 8.0)
        XCTAssertEqual(StrengthLoadEngine.classify(set: set, e1RMReference: 100), .hard(.light))
    }

    func test_classify_fractionalRPE_stillHardByIntensity() {
        // Even an easy RIR is overridden by hard-by-intensity (>= 0.80).
        let set = makeSet(weightKg: 85, rpe: 6.0) // 0.85 intensity (heavy), RIR 4 (easy)
        XCTAssertEqual(StrengthLoadEngine.classify(set: set, e1RMReference: 100), .hard(.heavy))
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

    // MARK: - Chronic-excludes-acute elevation (Finding 3 / GA-30-C)

    /// A steady-state athlete (proportional per-day load in both windows) → ratio ≈ 1 →
    /// elevation 0, instead of the old superset artefact. 1 hard set in acute (load 1.0 / 7d)
    /// matched by 3 equal hard sets in the 21-day chronic-exclusive window (3.0 / 21d) gives
    /// equal per-day load.
    func test_perMuscleStrengthLoad_steadyState_elevationZero() {
        let refExercise = "Bench Press"
        // Reference establishes e1RM 100 for chest/Bench (100kg x1 → Epley 103.33).
        let ref = makeSession(date: daysAgo(27), muscle: .chest, exerciseName: refExercise,
                              sets: [makeSet(weightKg: 100, reps: 1)])
        // 1 heavy set in acute (85kg ≈ 0.82 of ref → heavy, weight 1.0).
        let acute = makeSession(date: daysAgo(2), muscle: .chest, exerciseName: refExercise,
                                sets: [makeSet(weightKg: 85, reps: 3)])
        // 3 heavy sets spread across the chronic-exclusive window [7,28).
        let chronicA = makeSession(date: daysAgo(10), muscle: .chest, exerciseName: refExercise,
                                   sets: [makeSet(weightKg: 85, reps: 3)])
        let chronicB = makeSession(date: daysAgo(15), muscle: .chest, exerciseName: refExercise,
                                   sets: [makeSet(weightKg: 85, reps: 3)])
        let chronicC = makeSession(date: daysAgo(20), muscle: .chest, exerciseName: refExercise,
                                   sets: [makeSet(weightKg: 85, reps: 3)])
        let result = StrengthLoadEngine.perMuscleStrengthLoad(
            sessions: [ref, acute, chronicA, chronicB, chronicC],
            asOf: asOf, calendar: calendar
        )
        let chest = result.perMuscle[.chest]!
        XCTAssertTrue(chest.hasChronicBaseline)
        // acutePerDay = 1.0/7, chronicPerDay = 3.0/21 → ratio 1.0 → elevation 0.
        XCTAssertEqual(chest.elevation, 0, accuracy: 1e-9)
    }

    /// A brand-new exercise present ONLY in the acute window (no chronic-exclusive history)
    /// → elevation 0 AND hasChronicBaseline == false (insufficient baseline), NEVER 4×.
    func test_perMuscleStrengthLoad_newExercise_elevationZero_baselineFalse() {
        let acute = makeSession(date: daysAgo(1), muscle: .quads, sets: [
            makeSet(weightKg: 95, reps: 3), // 0.90+ → maximal hard
            makeSet(weightKg: 95, reps: 3),
            makeSet(weightKg: 95, reps: 3)
        ])
        // e1RM reference established purely from the acute sets (no prior history).
        let result = StrengthLoadEngine.perMuscleStrengthLoad(
            sessions: [acute],
            asOf: asOf, calendar: calendar
        )
        let quad = result.perMuscle[.quads]!
        XCTAssertGreaterThan(quad.hardSetCount, 0)        // heavy acute load present
        XCTAssertFalse(quad.hasChronicBaseline)           // but NO chronic baseline
        XCTAssertEqual(quad.elevation, 0, accuracy: 1e-9) // → elevation 0, not 4×
    }

    /// An established chronic baseline plus a genuine acute spike → elevation > 0 AND
    /// hasChronicBaseline == true.
    func test_perMuscleStrengthLoad_establishedBaselinePlusSpike_elevationPositive() {
        let ref = makeSession(date: daysAgo(27), muscle: .quads, sets: [makeSet(weightKg: 100, reps: 1)])
        // Light chronic baseline: one heavy set in the chronic-exclusive window.
        let chronic = makeSession(date: daysAgo(20), muscle: .quads, sets: [makeSet(weightKg: 85, reps: 3)])
        // Acute spike: three heavy sets.
        let acute = makeSession(date: daysAgo(1), muscle: .quads, sets: [
            makeSet(weightKg: 90, reps: 3),
            makeSet(weightKg: 90, reps: 3),
            makeSet(weightKg: 90, reps: 3)
        ])
        let result = StrengthLoadEngine.perMuscleStrengthLoad(
            sessions: [ref, chronic, acute],
            asOf: asOf, calendar: calendar
        )
        let quad = result.perMuscle[.quads]!
        XCTAssertTrue(quad.hasChronicBaseline)
        XCTAssertGreaterThan(quad.elevation, 0)
    }

    // MARK: - easyCount capture (Finding 5 data / GA-30-E)

    func test_perMuscleStrengthLoad_easyCount_capturesScoredEasySets() {
        // Two easy scored sets (low intensity, ample RIR) + one hard set in the acute window.
        let acute = makeSession(date: daysAgo(1), muscle: .biceps, exerciseName: "Curl", sets: [
            makeSet(weightKg: 50, rir: 5),  // 0.5 of ref, RIR 5 → easy
            makeSet(weightKg: 50, rir: 5),  // easy
            makeSet(weightKg: 95, rir: 1)   // hard by RIR
        ])
        // Establish e1RM 100 for biceps/Curl via a prior single.
        let ref = makeSession(date: daysAgo(10), muscle: .biceps, exerciseName: "Curl",
                              sets: [makeSet(weightKg: 100, reps: 1)])
        let result = StrengthLoadEngine.perMuscleStrengthLoad(
            sessions: [ref, acute],
            asOf: asOf, calendar: calendar
        )
        let biceps = result.perMuscle[.biceps]!
        XCTAssertEqual(biceps.easyCount, 2)
        XCTAssertEqual(biceps.hardSetCount, 1)
    }

    // MARK: - windowed boundary partition (Finding 3 / GA-30-C)

    /// A session exactly at diff == acuteWindowDays (7) lands in the CHRONIC-exclusive window,
    /// NOT acute — proving the half-open partition with no shared boundary day.
    func test_windowedBoundary_dayAtAcuteEdge_isChronicNotAcute() {
        let ref = makeSession(date: daysAgo(27), muscle: .quads, sets: [makeSet(weightKg: 100, reps: 1)])
        // Exactly 7 days ago: must count as chronic baseline, NOT acute load.
        let boundary = makeSession(date: daysAgo(7), muscle: .quads, sets: [makeSet(weightKg: 90, reps: 3)])
        let result = StrengthLoadEngine.perMuscleStrengthLoad(
            sessions: [ref, boundary],
            asOf: asOf, calendar: calendar
        )
        let quad = result.perMuscle[.quads]!
        // The boundary session's hard set is NOT in the acute window → acute hardSetCount 0.
        XCTAssertEqual(quad.hardSetCount, 0)
        // But it DID establish a chronic-exclusive baseline.
        XCTAssertTrue(quad.hasChronicBaseline)
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
