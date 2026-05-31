import XCTest
@testable import workload_management

/// Wave-2 → Wave-5 unit tests for the pure `LoadDistributionEngine`: unified daily-load series,
/// Foster monotony/strain numerics + guards, the completeness gate, the heuristic fallback, the
/// Wave-5 single real-unit combined series (no z-standardise+offset), half-open windows, and the
/// W1/W2 non-saturation guarantees. All dates derive from a FIXED anchor + FIXED UTC calendar
/// (deterministic; no `.now`).
final class LoadDistributionEngineTests: XCTestCase {

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

    /// An endurance session that produces a known srpeLoad = minutes * RPE.
    private func enduranceSession(date: Date, minutes: Int, rpe: Double) -> WorkoutSession {
        WorkoutSession(sessionDate: date, sportType: .running, durationSeconds: minutes * 60, sessionRPE: rpe)
    }

    /// A strength session with `hardSets` heavy hard sets (each ≈ 0.85 of a 100 est-1RM ref →
    /// heavy bucket, strain weight 1.0). No sessionRPE so it carries NO endurance load.
    private func strengthSession(date: Date, hardSets: Int) -> WorkoutSession {
        let session = WorkoutSession(sessionDate: date)
        let entry = ExerciseEntry(exerciseName: "Back Squat", muscleGroup: .quads)
        // 100kg x1 establishes a ~103 est-1RM; 85kg sets are ~0.82 → heavy hard.
        var sets = [SetRecord(reps: 1, weightKg: 100, rpe: nil, rir: nil, isWarmup: false)]
        for _ in 0..<hardSets {
            sets.append(SetRecord(reps: 3, weightKg: 85, rpe: nil, rir: 1, isWarmup: false))
        }
        entry.sets = sets
        session.exerciseEntries = [entry]
        return session
    }

    // MARK: - Monotony / strain numerics (pure [Double] — UNCHANGED by Wave-5)

    func test_monotony_uniformSeriesIsHigh() {
        // Near-uniform series → tiny SD → very high monotony.
        let daily = [100.0, 101.0, 99.0, 100.0, 100.0, 101.0, 99.0]
        let m = LoadDistributionEngine.monotony(daily)
        XCTAssertNotNil(m)
        XCTAssertGreaterThan(m!, 50)
    }

    func test_monotony_variedSeriesIsLower() {
        let uniform = [100.0, 101.0, 99.0, 100.0, 100.0, 101.0, 99.0]
        let varied = [10.0, 200.0, 30.0, 180.0, 5.0, 150.0, 60.0]
        let mUniform = LoadDistributionEngine.monotony(uniform)!
        let mVaried = LoadDistributionEngine.monotony(varied)!
        XCTAssertGreaterThan(mUniform, mVaried)
    }

    func test_monotony_knownValue() {
        // mean=2, values 1,2,3 → sampleSD=1 → monotony=2.
        let daily = [1.0, 2.0, 3.0]
        XCTAssertEqual(LoadDistributionEngine.monotony(daily)!, 2.0, accuracy: 1e-9)
    }

    func test_strain_knownValue() {
        // sum=6, monotony=2 → strain=12.
        let daily = [1.0, 2.0, 3.0]
        XCTAssertEqual(LoadDistributionEngine.strain(daily)!, 12.0, accuracy: 1e-9)
    }

    func test_monotony_zeroVarianceReturnsNil() {
        XCTAssertNil(LoadDistributionEngine.monotony([100.0, 100.0, 100.0]))
        XCTAssertNil(LoadDistributionEngine.strain([100.0, 100.0, 100.0]))
    }

    func test_monotony_fewerThanTwoPointsReturnsNil() {
        XCTAssertNil(LoadDistributionEngine.monotony([100.0]))
        XCTAssertNil(LoadDistributionEngine.monotony([]))
    }

    // MARK: - Daily-load series

    func test_dailyLoadSeries_bucketsByDayAndSumsLoad() {
        // Two sessions same day → one DailyLoad entry summing both srpeLoads.
        let s1 = enduranceSession(date: daysAgo(1), minutes: 30, rpe: 6) // 180
        let s2 = enduranceSession(date: daysAgo(1), minutes: 20, rpe: 5) // 100
        let s3 = enduranceSession(date: daysAgo(3), minutes: 40, rpe: 5) // 200
        let series = LoadDistributionEngine.dailyLoadSeries(sessions: [s1, s2, s3], asOf: asOf, calendar: calendar)
        XCTAssertEqual(series.count, 2)
        let day1 = series.first { calendar.isDate($0.dayStart, inSameDayAs: daysAgo(1)) }!
        XCTAssertEqual(day1.load, 280.0, accuracy: 1e-9)
    }

    func test_dailyLoadSeries_excludesOutOfWindow() {
        let inWin = enduranceSession(date: daysAgo(5), minutes: 30, rpe: 6)
        let outWin = enduranceSession(date: daysAgo(40), minutes: 30, rpe: 6)
        let series = LoadDistributionEngine.dailyLoadSeries(sessions: [inWin, outWin], asOf: asOf, calendar: calendar)
        XCTAssertEqual(series.count, 1)
    }

    func test_dailyLoadSeries_skipsSrpeWhenNoSessionRPE() {
        // Session with nil sessionRPE and no scored strength sets → load 0 but still a logged day.
        let s = WorkoutSession(sessionDate: daysAgo(1), sportType: .running, durationSeconds: 1800, sessionRPE: nil)
        let series = LoadDistributionEngine.dailyLoadSeries(sessions: [s], asOf: asOf, calendar: calendar)
        XCTAssertEqual(series.count, 1)
        XCTAssertEqual(series[0].load, 0.0, accuracy: 1e-9)
    }

    // MARK: - Half-open window boundary (Finding 3 / GA-30-C, Wave-5 W3)

    /// Wave-5 W3: windows are now HALF-OPEN. A session exactly `windowDays` (14) old is EXCLUDED;
    /// a session `windowDays - 1` (13) old is INCLUDED — so a "window of N days" spans exactly N
    /// calendar days, matching StrengthLoadEngine.windowedRange's exclusive-upper form. (Under the
    /// superseded inclusive form, a diff==14 session was wrongly counted, spanning 15 calendar
    /// days.)
    func test_dailyLoadSeries_windowBoundaryHalfOpen() {
        let atBoundary = enduranceSession(date: daysAgo(14), minutes: 30, rpe: 6) // diff == windowDays → EXCLUDED
        let justInside = enduranceSession(date: daysAgo(13), minutes: 30, rpe: 6) // diff == windowDays-1 → INCLUDED
        let series = LoadDistributionEngine.dailyLoadSeries(
            sessions: [atBoundary, justInside], asOf: asOf, calendar: calendar
        )
        XCTAssertEqual(series.count, 1) // only the justInside session
        XCTAssertTrue(series.contains { calendar.isDate($0.dayStart, inSameDayAs: daysAgo(13)) })
        XCTAssertFalse(series.contains { calendar.isDate($0.dayStart, inSameDayAs: daysAgo(14)) })
    }

    // MARK: - Completeness gate + distribution

    func test_distribution_denseVariedLog_computed() {
        // 8 distinct days, varied loads → gate passes, monotony/strain non-nil, .computed.
        var sessions: [WorkoutSession] = []
        let minutesByDay = [30, 50, 20, 60, 25, 45, 35, 55]
        for (i, mins) in minutesByDay.enumerated() {
            sessions.append(enduranceSession(date: daysAgo(i + 1), minutes: mins, rpe: 6))
        }
        let result = LoadDistributionEngine.distribution(sessions: sessions, asOf: asOf, calendar: calendar)
        XCTAssertEqual(result.gateState, .computed)
        XCTAssertNotNil(result.monotony)
        XCTAssertNotNil(result.strain)
        XCTAssertEqual(result.loggedDays, 8)
    }

    func test_distribution_sparseLog_fellBack() {
        // Only 3 logged days → below monotonyMinLoggedDays → fall back.
        let sessions = [
            enduranceSession(date: daysAgo(1), minutes: 30, rpe: 6),
            enduranceSession(date: daysAgo(2), minutes: 40, rpe: 6),
            enduranceSession(date: daysAgo(3), minutes: 50, rpe: 6)
        ]
        let result = LoadDistributionEngine.distribution(sessions: sessions, asOf: asOf, calendar: calendar)
        XCTAssertEqual(result.gateState, .fellBack)
        XCTAssertNil(result.monotony)
        XCTAssertNil(result.strain)
        XCTAssertGreaterThanOrEqual(result.fallbackLoadSignal, 0)
        XCTAssertLessThanOrEqual(result.fallbackLoadSignal, 1)
    }

    func test_distribution_zeroVarianceFallsBack() {
        // 8 logged days but identical loads → variance 0 → gate fails despite enough days.
        var sessions: [WorkoutSession] = []
        for i in 1...8 {
            sessions.append(enduranceSession(date: daysAgo(i), minutes: 30, rpe: 6)) // all 180
        }
        let result = LoadDistributionEngine.distribution(sessions: sessions, asOf: asOf, calendar: calendar)
        XCTAssertEqual(result.gateState, .fellBack)
        XCTAssertNil(result.monotony)
    }

    func test_completenessGate_boundaryAtMinLoggedDays() {
        // Exactly monotonyMinLoggedDays (7) varied days → gate passes (raw series helper).
        var sessions: [WorkoutSession] = []
        let mins = [30, 50, 20, 60, 25, 45, 35]
        for (i, m) in mins.enumerated() {
            sessions.append(enduranceSession(date: daysAgo(i + 1), minutes: m, rpe: 6))
        }
        let series = LoadDistributionEngine.dailyLoadSeries(sessions: sessions, asOf: asOf, calendar: calendar)
        XCTAssertEqual(series.count, 7)
        XCTAssertTrue(LoadDistributionEngine.completenessGate(series))
    }

    // MARK: - Fallback signal range + determinism

    func test_fallbackLoadSignal_inRange() {
        let sessions = (1...10).map { enduranceSession(date: daysAgo($0), minutes: 30, rpe: 6) }
        let signal = LoadDistributionEngine.fallbackLoadSignal(sessions: sessions, asOf: asOf, calendar: calendar)
        XCTAssertGreaterThanOrEqual(signal, 0)
        XCTAssertLessThanOrEqual(signal, 1)
    }

    func test_distribution_determinism() {
        let sessions = (1...8).map { enduranceSession(date: daysAgo($0), minutes: 20 + $0 * 3, rpe: 6) }
        let a = LoadDistributionEngine.distribution(sessions: sessions, asOf: asOf, calendar: calendar)
        let b = LoadDistributionEngine.distribution(sessions: sessions, asOf: asOf, calendar: calendar)
        XCTAssertEqual(a, b)
    }

    // MARK: - Single real-unit combined series (Wave-5 W1) — supersedes z-standardise+offset

    /// W1: folding strength hard sets onto a subset of days measurably changes monotony vs the
    /// same endurance-only log. Strength is converted to an sRPE-equivalent load on the SINGLE
    /// real-unit combined series (no z-standardise), so it contributes proportionally — both
    /// streams move monotony. (Re-derived from the Wave-2 standardise-based test; under the
    /// single-series model the delta is the natural shift in mean/SD, not an artificial one.)
    func test_distribution_strengthMeasurablyMovesMonotony() {
        // Fixed 8-day endurance log (same logged days in both cases).
        let minutesByDay = [30, 50, 20, 60, 25, 45, 35, 55]
        var enduranceOnly: [WorkoutSession] = []
        for (i, m) in minutesByDay.enumerated() {
            enduranceOnly.append(enduranceSession(date: daysAgo(i + 1), minutes: m, rpe: 6))
        }
        // Same log + strength hard sets folded onto days 1, 4, 7 (same calendar days → same
        // loggedDays count; only the strength stream differs).
        var withStrength = enduranceOnly
        withStrength.append(strengthSession(date: daysAgo(1), hardSets: 2))
        withStrength.append(strengthSession(date: daysAgo(4), hardSets: 3))
        withStrength.append(strengthSession(date: daysAgo(7), hardSets: 1))

        let base = LoadDistributionEngine.distribution(sessions: enduranceOnly, asOf: asOf, calendar: calendar)
        let withStr = LoadDistributionEngine.distribution(sessions: withStrength, asOf: asOf, calendar: calendar)

        XCTAssertEqual(base.gateState, .computed)
        XCTAssertEqual(withStr.gateState, .computed)
        XCTAssertEqual(base.loggedDays, withStr.loggedDays) // same logged days
        XCTAssertNotNil(base.monotony)
        XCTAssertNotNil(withStr.monotony)
        // Strength contributes on the single real-unit scale: monotony differs measurably.
        XCTAssertGreaterThan(abs(base.monotony! - withStr.monotony!), 1e-6)
    }

    /// W1 core assertion (engine layer): an 8-day VARIED endurance-only log yields a FINITE
    /// monotony in the natural ~1–3 range, so the downstream clamp01(monotony / 3.0) is STRICTLY
    /// < 1.0 — the channel is NOT pinned at max. (Re-derived oracle: srpeLoads
    /// [180,300,120,360,150,270,210,330] → mean 240, sampleSD ≈ 87.83 → monotony ≈ 2.733 →
    /// clamp01(/3) ≈ 0.911. Under the superseded z-offset hack this was ≈4–6 → clamp01 == 1.0.)
    func test_distribution_enduranceOnlyVaried_finiteMonotonyInNaturalRange() {
        var sessions: [WorkoutSession] = []
        let minutesByDay = [30, 50, 20, 60, 25, 45, 35, 55]
        for (i, m) in minutesByDay.enumerated() {
            sessions.append(enduranceSession(date: daysAgo(i + 1), minutes: m, rpe: 6))
        }
        let result = LoadDistributionEngine.distribution(sessions: sessions, asOf: asOf, calendar: calendar)
        XCTAssertEqual(result.gateState, .computed)
        let m = result.monotony
        XCTAssertNotNil(m)
        XCTAssertTrue(m!.isFinite)
        XCTAssertGreaterThan(m!, 0)
        XCTAssertLessThan(m!, 3.0) // natural Foster range — NOT saturated at the /3.0 normaliser
        XCTAssertNotNil(result.strain)
        XCTAssertTrue(result.strain!.isFinite)
        // Explicit non-saturation: clamp01(monotony / 3.0) < 1.0.
        let clamped = Swift.min(1.0, Swift.max(0.0, m! / 3.0))
        XCTAssertLessThan(clamped, 1.0)
    }

    /// A constant 7-day endurance log → the single combined series is finite (no NaN) and the gate
    /// FAILS (zero variance) → monotony nil. (Replaces the standardise-helper NaN guard test.)
    func test_combinedSeries_constantInputNoNaN() {
        var sessions: [WorkoutSession] = []
        for i in 1...7 {
            sessions.append(enduranceSession(date: daysAgo(i), minutes: 30, rpe: 6))
        }
        let series = LoadDistributionEngine.monotonyInputSeries(sessions: sessions, asOf: asOf, calendar: calendar)
        XCTAssertEqual(series.count, 7)
        XCTAssertTrue(series.allSatisfy { $0.isFinite }) // finite real-unit loads, no NaN
        let result = LoadDistributionEngine.distribution(sessions: sessions, asOf: asOf, calendar: calendar)
        XCTAssertEqual(result.gateState, .fellBack) // zero variance → gate fails
        XCTAssertNil(result.monotony)
    }

    // MARK: - W2: gate and metric share ONE series (.computed ⇒ monotony non-nil)

    /// W2: the completeness gate now runs on the SAME single combined series fed to Foster
    /// monotony/strain. For any dense varied log that passes the gate, gateState == .computed
    /// implies monotony != nil AND strain != nil — the divergence hazard (gate passes on one
    /// series while monotony is nil on the other → StrainRisk read 0-at-full-weight) is
    /// structurally impossible.
    func test_distribution_computedImpliesMonotonyNonNil() {
        var sessions: [WorkoutSession] = []
        let minutesByDay = [30, 50, 20, 60, 25, 45, 35, 55]
        for (i, m) in minutesByDay.enumerated() {
            sessions.append(enduranceSession(date: daysAgo(i + 1), minutes: m, rpe: 6))
        }
        // Mix in strength too, to exercise the combined real-unit path under the gate.
        sessions.append(strengthSession(date: daysAgo(2), hardSets: 2))
        sessions.append(strengthSession(date: daysAgo(5), hardSets: 3))
        let result = LoadDistributionEngine.distribution(sessions: sessions, asOf: asOf, calendar: calendar)
        XCTAssertEqual(result.gateState, .computed)
        XCTAssertNotNil(result.monotony) // .computed ⇒ monotony never nil (single shared series)
        XCTAssertNotNil(result.strain)
    }

    /// W1 saturation oracle (mixed endurance+strength): a dense varied mixed log → monotony finite
    /// and clamp01(monotony / 3.0) STRICTLY < 1.0.
    func test_distribution_variedLog_monotonyNotSaturated() {
        var sessions: [WorkoutSession] = []
        let minutesByDay = [30, 50, 20, 60, 25, 45, 35, 55]
        for (i, m) in minutesByDay.enumerated() {
            sessions.append(enduranceSession(date: daysAgo(i + 1), minutes: m, rpe: 6))
        }
        sessions.append(strengthSession(date: daysAgo(1), hardSets: 2))
        sessions.append(strengthSession(date: daysAgo(4), hardSets: 1))
        let result = LoadDistributionEngine.distribution(sessions: sessions, asOf: asOf, calendar: calendar)
        XCTAssertEqual(result.gateState, .computed)
        let m = result.monotony
        XCTAssertNotNil(m)
        XCTAssertTrue(m!.isFinite)
        let clamped = Swift.min(1.0, Swift.max(0.0, m! / 3.0))
        XCTAssertLessThan(clamped, 1.0) // the core W1 assertion: NOT pinned at 1.0
    }

    /// W1 movement oracle: a NEAR-UNIFORM daily distribution yields strictly HIGHER monotony than
    /// a VARIED one (monotony = mean/SD, so uniformity raises it). Compared on raw monotony so the
    /// ordering is visible even when the uniform case saturates clamp01 (the legitimate ceiling).
    func test_distribution_uniformVsVaried_monotonyOrders() {
        // Near-uniform 8-day endurance log.
        var uniform: [WorkoutSession] = []
        let uniformMins = [40, 41, 39, 40, 40, 41, 39, 40]
        for (i, m) in uniformMins.enumerated() {
            uniform.append(enduranceSession(date: daysAgo(i + 1), minutes: m, rpe: 6))
        }
        // Varied 8-day endurance log over the same logged days.
        var varied: [WorkoutSession] = []
        let variedMins = [30, 50, 20, 60, 25, 45, 35, 55]
        for (i, m) in variedMins.enumerated() {
            varied.append(enduranceSession(date: daysAgo(i + 1), minutes: m, rpe: 6))
        }
        let mUniform = LoadDistributionEngine.distribution(sessions: uniform, asOf: asOf, calendar: calendar)
        let mVaried = LoadDistributionEngine.distribution(sessions: varied, asOf: asOf, calendar: calendar)
        XCTAssertEqual(mUniform.gateState, .computed)
        XCTAssertEqual(mVaried.gateState, .computed)
        XCTAssertGreaterThan(mUniform.monotony!, mVaried.monotony!) // uniform > varied
    }

    /// The raw dailyLoadSeries oracle is UNCHANGED by the combined-series path (separate path).
    func test_dailyLoadSeries_rawOracleUnchanged() {
        let s1 = enduranceSession(date: daysAgo(1), minutes: 30, rpe: 6) // 180
        let s2 = enduranceSession(date: daysAgo(1), minutes: 20, rpe: 5) // 100
        let series = LoadDistributionEngine.dailyLoadSeries(sessions: [s1, s2], asOf: asOf, calendar: calendar)
        let day1 = series.first { calendar.isDate($0.dayStart, inSameDayAs: daysAgo(1)) }!
        XCTAssertEqual(day1.load, 280.0, accuracy: 1e-9) // raw absolute load preserved
    }
}
