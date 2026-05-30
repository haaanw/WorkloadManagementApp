import XCTest
@testable import workload_management

/// Wave-2 unit tests for the pure `LoadDistributionEngine`: unified daily-load series, Foster
/// monotony/strain numerics + guards, the completeness gate, and the heuristic fallback. All
/// dates derive from a FIXED anchor + FIXED UTC calendar (deterministic; no `.now`).
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

    // MARK: - Monotony / strain numerics

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
        // Exactly monotonyMinLoggedDays (7) varied days → gate passes.
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
}
