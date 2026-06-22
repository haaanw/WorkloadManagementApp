import XCTest
@testable import workload_management

/// Phase 41 / ACT-02 unit tests for the pure `CrossModalFatigueEngine`: directional,
/// region-resolved cross-modal fatigue carry. Proves the headline behaviour —
/// **a hard run penalizes today's squat (legs) but spares today's bench (chest)** —
/// plus the anti-linear-stacking (saturating-concave) property, region decay, personal
/// normalization, multiplicative systemic combine, determinism, degenerate inputs, and the
/// no-injury-prediction copy guard.
///
/// All dates derive from a FIXED anchor with a FIXED UTC calendar so the suite is
/// deterministic (no `.now` / `Calendar.current`) — same idiom as `StrengthLoadEngineTests`.
final class CrossModalFatigueEngineTests: XCTestCase {

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

    /// A non-strength (endurance/conditioning) session: magnitude comes from srpe
    /// (durationSeconds × sessionRPE), modality from `sportType`.
    private func enduranceSession(
        date: Date,
        sport: SportType,
        durationSeconds: Int = 60 * 60,   // 60 min
        rpe: Double? = 8
    ) -> WorkoutSession {
        WorkoutSession(
            sessionDate: date,
            sportType: sport,
            durationSeconds: durationSeconds,
            sessionRPE: rpe,
            sessionType: .cardio
        )
    }

    private func makeSet(
        weightKg: Double? = nil,
        reps: Int? = nil,
        rpe: Double? = nil,
        rir: Int? = nil,
        isWarmup: Bool = false
    ) -> SetRecord {
        SetRecord(reps: reps, weightKg: weightKg, rpe: rpe, rir: rir, isWarmup: isWarmup)
    }

    private func strengthSession(
        date: Date,
        muscle: MuscleGroup,
        exerciseName: String = "Back Squat",
        sets: [SetRecord]
    ) -> WorkoutSession {
        let session = WorkoutSession(sessionDate: date, sportType: .lifting, sessionType: .strength)
        let entry = ExerciseEntry(exerciseName: exerciseName, muscleGroup: muscle)
        entry.sets = sets
        session.exerciseEntries = [entry]
        return session
    }

    // MARK: - Regionalization (β maps)

    func test_regionCarry_running_legsDominateChestNearZero() {
        let result = CrossModalFatigueEngine.compute(
            sessions: [enduranceSession(date: daysAgo(1), sport: .running)],
            systemicReadiness: 100,
            asOf: asOf,
            calendar: calendar
        )
        let legs = result.perRegionCarry[.legs] ?? 0
        let chest = result.perRegionCarry[.chest] ?? 0
        XCTAssertGreaterThan(legs, 0)
        // Running loads legs heavily, chest near-zero.
        XCTAssertGreaterThan(legs, chest * 10 + 1)
        XCTAssertLessThanOrEqual(chest, 1e-9)
    }

    func test_regionCarry_swimming_backShoulders_legsNearZero() {
        let result = CrossModalFatigueEngine.compute(
            sessions: [enduranceSession(date: daysAgo(1), sport: .swimming)],
            systemicReadiness: 100,
            asOf: asOf,
            calendar: calendar
        )
        let back = result.perRegionCarry[.back] ?? 0
        let shoulders = result.perRegionCarry[.shoulders] ?? 0
        let legs = result.perRegionCarry[.legs] ?? 0
        XCTAssertGreaterThan(back, 0)
        XCTAssertGreaterThan(shoulders, 0)
        // Swimming spares legs.
        XCTAssertGreaterThan(back, legs)
        XCTAssertLessThanOrEqual(legs, 1e-9)
    }

    func test_regionCarry_cycling_legsLowerBetaThanRunning() {
        let runLegs = CrossModalFatigueEngine.compute(
            sessions: [enduranceSession(date: daysAgo(1), sport: .running)],
            systemicReadiness: 100, asOf: asOf, calendar: calendar
        ).perRegionCarry[.legs] ?? 0
        let cycleLegs = CrossModalFatigueEngine.compute(
            sessions: [enduranceSession(date: daysAgo(1), sport: .cycling)],
            systemicReadiness: 100, asOf: asOf, calendar: calendar
        ).perRegionCarry[.legs] ?? 0
        // Same srpe + same decay, but cycling β < running β → less leg carry.
        XCTAssertGreaterThan(cycleLegs, 0)
        XCTAssertLessThan(cycleLegs, runLegs)
    }

    // MARK: - Run-hits-squat-not-bench (headline ACT-02 behaviour)

    func test_runHitsSquatNotBench() {
        // A recent hard run yesterday, with little prior running in the chronic window
        // (a couple of light runs deep in the chronic-exclusive window establish a small
        // personal baseline, so an above-normal spike registers).
        let sessions: [WorkoutSession] = [
            enduranceSession(date: daysAgo(1), sport: .running, durationSeconds: 60 * 60, rpe: 9),
            enduranceSession(date: daysAgo(14), sport: .running, durationSeconds: 30 * 60, rpe: 5),
            enduranceSession(date: daysAgo(21), sport: .running, durationSeconds: 30 * 60, rpe: 5)
        ]
        let result = CrossModalFatigueEngine.compute(
            sessions: sessions,
            systemicReadiness: 100,   // isolate the regional channel; systemic = neutral
            asOf: asOf,
            calendar: calendar
        )
        let legsAdjustment = result.exerciseAdjustment(forRegion: .legs)
        let benchAdjustment = result.exerciseAdjustment(forRegion: .chest)

        // Squat (legs) gets a MEANINGFUL penalty.
        XCTAssertLessThanOrEqual(legsAdjustment, 0.95)
        // Bench (chest) is near-zero — only the (neutral) systemic factor, ~1.0.
        XCTAssertGreaterThanOrEqual(benchAdjustment, 0.99)
        // The asymmetry itself is the headline.
        XCTAssertLessThan(legsAdjustment, benchAdjustment)
    }

    // MARK: - Anti-linear-stacking (saturating concave + bounded)

    func test_regionPenalty_isConcave_notLinearStacking() {
        // penalty(E) = maxPenalty * (1 - exp(-k*E)) is concave in E:
        // penalty(E) < 2 * penalty(E/2) for E > 0.
        let e = 0.8
        let full = CrossModalFatigueEngine.regionPenalty(e)
        let half = CrossModalFatigueEngine.regionPenalty(e / 2)
        XCTAssertLessThan(full, 2 * half)
    }

    func test_regionPenalty_boundedByMaxPenalty() {
        // Even a huge / saturated elevation never exceeds the cap.
        for e in [0.0, 0.5, 1.0, 5.0, 100.0] {
            let p = CrossModalFatigueEngine.regionPenalty(e)
            XCTAssertLessThanOrEqual(p, CrossModalFatigueEngine.Constants.maxPenalty + 1e-12)
            XCTAssertGreaterThanOrEqual(p, 0)
        }
    }

    func test_exerciseAdjustment_neverBelowFloor() {
        // Worst case: max elevation + lowest systemic readiness → factor still > 0 and
        // >= systemicMin * (1 - maxPenalty).
        let result = CrossModalFatigueEngine.compute(
            sessions: [
                enduranceSession(date: daysAgo(1), sport: .running, durationSeconds: 120 * 60, rpe: 10),
                enduranceSession(date: daysAgo(14), sport: .running, durationSeconds: 20 * 60, rpe: 4)
            ],
            systemicReadiness: 0,
            asOf: asOf,
            calendar: calendar
        )
        let legs = result.exerciseAdjustment(forRegion: .legs)
        let floor = CrossModalFatigueEngine.Constants.systemicMin * (1 - CrossModalFatigueEngine.Constants.maxPenalty)
        XCTAssertGreaterThan(legs, 0)
        XCTAssertGreaterThanOrEqual(legs, floor - 1e-9)
    }

    // MARK: - Personal normalization (steady-state → no penalty)

    func test_steadyStateRunner_noLegPenalty() {
        // An athlete who ALWAYS runs hard: acute carry ≈ chronic carry → elevation 0
        // (deadband) → no leg penalty beyond the neutral systemic factor.
        var sessions: [WorkoutSession] = []
        // Equal hard running across both the acute window and the chronic-exclusive window.
        for d in [1, 4] {  // acute window [0, 7)
            sessions.append(enduranceSession(date: daysAgo(d), sport: .running, durationSeconds: 60 * 60, rpe: 8))
        }
        for d in [8, 11, 14, 17, 20, 23] {  // chronic-exclusive window [7, 28) — proportional per-day
            sessions.append(enduranceSession(date: daysAgo(d), sport: .running, durationSeconds: 60 * 60, rpe: 8))
        }
        let result = CrossModalFatigueEngine.compute(
            sessions: sessions,
            systemicReadiness: 100,
            asOf: asOf,
            calendar: calendar
        )
        // Elevation should be ~0 (steady state) → adjustment ~1.0.
        XCTAssertLessThanOrEqual(result.perRegionElevation[.legs] ?? 0, 1e-9)
        XCTAssertEqual(result.exerciseAdjustment(forRegion: .legs), 1.0, accuracy: 1e-9)
    }

    // MARK: - Decay (recency matters)

    func test_decay_runYesterdayCarriesMoreThanThreeDaysAgo() {
        let yesterday = CrossModalFatigueEngine.compute(
            sessions: [enduranceSession(date: daysAgo(1), sport: .running)],
            systemicReadiness: 100, asOf: asOf, calendar: calendar
        ).perRegionCarry[.legs] ?? 0
        let threeAgo = CrossModalFatigueEngine.compute(
            sessions: [enduranceSession(date: daysAgo(3), sport: .running)],
            systemicReadiness: 100, asOf: asOf, calendar: calendar
        ).perRegionCarry[.legs] ?? 0
        XCTAssertGreaterThan(yesterday, threeAgo)
        XCTAssertGreaterThan(threeAgo, 0)
    }

    func test_decay_runOutsideWindowContributesNearZero() {
        let result = CrossModalFatigueEngine.compute(
            sessions: [enduranceSession(date: daysAgo(30), sport: .running)],
            systemicReadiness: 100, asOf: asOf, calendar: calendar
        )
        // Outside the acute window → no acute carry.
        XCTAssertLessThanOrEqual(result.perRegionCarry[.legs] ?? 0, 1e-9)
    }

    // MARK: - Systemic combine (multiplicative, not additive)

    func test_systemicCombine_isMultiplicative() {
        // Low readiness applies a mild global haircut to ALL exercises (incl. chest, which
        // has zero regional carry). Legs = systemicFactor * (1 - legPenalty).
        let sessions: [WorkoutSession] = [
            enduranceSession(date: daysAgo(1), sport: .running, durationSeconds: 60 * 60, rpe: 9),
            enduranceSession(date: daysAgo(14), sport: .running, durationSeconds: 20 * 60, rpe: 4)
        ]
        let lowReadiness = 40.0
        let result = CrossModalFatigueEngine.compute(
            sessions: sessions, systemicReadiness: lowReadiness, asOf: asOf, calendar: calendar
        )
        let systemicFactor = CrossModalFatigueEngine.systemicFactor(readiness: lowReadiness)

        // Chest has no regional carry → adjustment == systemicFactor (within epsilon).
        XCTAssertEqual(result.exerciseAdjustment(forRegion: .chest), systemicFactor, accuracy: 1e-9)
        // Legs = systemicFactor * (1 - legPenalty).
        let legPenalty = CrossModalFatigueEngine.regionPenalty(result.perRegionElevation[.legs] ?? 0)
        XCTAssertEqual(
            result.exerciseAdjustment(forRegion: .legs),
            systemicFactor * (1 - legPenalty),
            accuracy: 1e-9
        )
        // And it is BELOW the chest adjustment (regional carry stacks on top of systemic).
        XCTAssertLessThan(result.exerciseAdjustment(forRegion: .legs), result.exerciseAdjustment(forRegion: .chest))
    }

    func test_systemicFactor_readiness100IsOne() {
        XCTAssertEqual(CrossModalFatigueEngine.systemicFactor(readiness: 100), 1.0, accuracy: 1e-9)
    }

    func test_systemicFactor_readiness0IsFloor() {
        XCTAssertEqual(
            CrossModalFatigueEngine.systemicFactor(readiness: 0),
            CrossModalFatigueEngine.Constants.systemicMin,
            accuracy: 1e-9
        )
    }

    // MARK: - Strength sessions also contribute regional carry

    func test_heavySquatDay_contributesLegCarry() {
        // A heavy squat day should accrue leg-region carry via StrengthLoadEngine.perRegion,
        // alongside any endurance carry.
        let ref = strengthSession(date: daysAgo(20), muscle: .quads, sets: [makeSet(weightKg: 100, reps: 1)])
        let heavy = strengthSession(date: daysAgo(1), muscle: .quads, sets: [
            makeSet(weightKg: 90, reps: 3),
            makeSet(weightKg: 90, reps: 3),
            makeSet(weightKg: 90, reps: 3)
        ])
        let result = CrossModalFatigueEngine.compute(
            sessions: [ref, heavy],
            systemicReadiness: 100,
            asOf: asOf,
            calendar: calendar
        )
        XCTAssertGreaterThan(result.perRegionCarry[.legs] ?? 0, 0)
    }

    // MARK: - Determinism

    func test_determinism_identicalOutputsAcrossCalls() {
        let sessions: [WorkoutSession] = [
            enduranceSession(date: daysAgo(1), sport: .running, rpe: 9),
            enduranceSession(date: daysAgo(3), sport: .cycling, rpe: 7),
            enduranceSession(date: daysAgo(14), sport: .running, rpe: 5)
        ]
        let a = CrossModalFatigueEngine.compute(sessions: sessions, systemicReadiness: 70, asOf: asOf, calendar: calendar)
        let b = CrossModalFatigueEngine.compute(sessions: sessions, systemicReadiness: 70, asOf: asOf, calendar: calendar)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.exerciseAdjustment(forRegion: .legs), b.exerciseAdjustment(forRegion: .legs), accuracy: 1e-12)
    }

    // MARK: - Degenerate inputs

    func test_emptySessions_allNeutral() {
        let result = CrossModalFatigueEngine.compute(
            sessions: [],
            systemicReadiness: 100,
            asOf: asOf,
            calendar: calendar
        )
        XCTAssertTrue(result.perRegionCarry.isEmpty || result.perRegionCarry.values.allSatisfy { $0 <= 1e-12 })
        for region in MuscleRegion.allCases {
            XCTAssertEqual(result.exerciseAdjustment(forRegion: region), 1.0, accuracy: 1e-9)
        }
    }

    func test_nilSessionRPE_isSkipped_noFabricatedLoad() {
        let result = CrossModalFatigueEngine.compute(
            sessions: [enduranceSession(date: daysAgo(1), sport: .running, rpe: nil)],
            systemicReadiness: 100,
            asOf: asOf,
            calendar: calendar
        )
        // No RPE → no srpe load → no carry fabricated.
        XCTAssertLessThanOrEqual(result.perRegionCarry[.legs] ?? 0, 1e-12)
        XCTAssertEqual(result.exerciseAdjustment(forRegion: .legs), 1.0, accuracy: 1e-9)
    }

    func test_fullBodyExercise_usesMaxRegionElevation() {
        // A fried-legs day: a fullBody planned exercise should reflect the dominant
        // (max) region elevation, not spare itself.
        let sessions: [WorkoutSession] = [
            enduranceSession(date: daysAgo(1), sport: .running, durationSeconds: 60 * 60, rpe: 9),
            enduranceSession(date: daysAgo(14), sport: .running, durationSeconds: 20 * 60, rpe: 4)
        ]
        let result = CrossModalFatigueEngine.compute(
            sessions: sessions, systemicReadiness: 100, asOf: asOf, calendar: calendar
        )
        // fullBody adjustment should match the worst (legs) region adjustment.
        XCTAssertEqual(
            result.exerciseAdjustment(forRegion: .fullBody),
            result.exerciseAdjustment(forRegion: .legs),
            accuracy: 1e-9
        )
        XCTAssertLessThan(result.exerciseAdjustment(forRegion: .fullBody), 1.0)
    }

    // MARK: - Glass-box reason

    func test_dominantReason_mentionsDominantRegion() {
        let sessions: [WorkoutSession] = [
            enduranceSession(date: daysAgo(1), sport: .running, durationSeconds: 60 * 60, rpe: 9),
            enduranceSession(date: daysAgo(14), sport: .running, durationSeconds: 20 * 60, rpe: 4)
        ]
        let result = CrossModalFatigueEngine.compute(
            sessions: sessions, systemicReadiness: 100, asOf: asOf, calendar: calendar
        )
        let reason = result.dominantReason
        XCTAssertNotNil(reason)
        XCTAssertTrue(reason!.lowercased().contains("legs"))
    }

    // MARK: - No-injury-prediction copy guard (mirrors StrainRiskEngine pattern)

    func test_noInjuryPredictionCopy_inReasonStrings() {
        let banned = ["injury prediction", "predicts injury", "injury risk", "will get injured"]
        let sessions: [WorkoutSession] = [
            enduranceSession(date: daysAgo(1), sport: .running, durationSeconds: 60 * 60, rpe: 9),
            enduranceSession(date: daysAgo(14), sport: .running, durationSeconds: 20 * 60, rpe: 4)
        ]
        let result = CrossModalFatigueEngine.compute(
            sessions: sessions, systemicReadiness: 50, asOf: asOf, calendar: calendar
        )
        let reason = (result.dominantReason ?? "").lowercased()
        for phrase in banned {
            XCTAssertFalse(reason.contains(phrase), "Reason copy contains banned phrase: \(phrase)")
        }
    }
}
