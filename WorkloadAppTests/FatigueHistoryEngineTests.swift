import XCTest
@testable import workload_management

/// v1.7.3 · UAT round 1 · U9 — the fatigue accumulation series.
///
/// The claim under test is not "the number is right" (that is `FatigueIndexEngine`'s, and this
/// engine adds no algorithm). It is that walking that engine backwards over stored history is a
/// faithful REDUCTION: each day sees only what was known up to it, the windows match the live
/// dashboard's, and the series' last point is the number Today prints.
final class FatigueHistoryEngineTests: XCTestCase {

    // MARK: - Harness

    /// A fixed UTC calendar, so a test run near midnight or in a DST week cannot move a day
    /// boundary under the assertions.
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private let now = Date(timeIntervalSince1970: 1_757_500_000)   // a fixed instant

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: now))!
    }

    private func sessions(dailyFor days: Int, stress: Double = 80) -> [FatigueHistoryEngine.SessionPoint] {
        (0..<days).map { FatigueHistoryEngine.SessionPoint(date: day($0), trainingStress: stress) }
    }

    private func scores(_ value: Double, days: Int) -> [FatigueHistoryEngine.DayScore] {
        (0..<days).map { FatigueHistoryEngine.DayScore(date: day($0), value: value) }
    }

    private func series(
        sessions: [FatigueHistoryEngine.SessionPoint],
        recovery: [FatigueHistoryEngine.DayScore] = [],
        wellness: [FatigueHistoryEngine.DayScore] = [],
        injuries: [Date] = [],
        days: Int = 14
    ) -> [FatigueHistoryEngine.Point] {
        FatigueHistoryEngine.series(
            sessions: sessions,
            recoveryScores: recovery,
            wellnessScores: wellness,
            qualifyingInjuryDates: injuries,
            days: days,
            asOf: now,
            calendar: calendar
        )
    }

    // MARK: - Shape

    func test_series_isOneAscendingPointPerDay() {
        let points = series(sessions: sessions(dailyFor: 40))

        XCTAssertEqual(points.count, 14)
        XCTAssertEqual(points.first?.day, calendar.startOfDay(for: day(13)))
        XCTAssertEqual(points.last?.day, calendar.startOfDay(for: day(0)))
        for index in 1..<points.count {
            XCTAssertLessThan(points[index - 1].day, points[index].day, "the series must be oldest-first")
        }
    }

    func test_series_startsAtTheFirstSession_notAtTheWindowEdge() {
        // Five days of history inside a 30-day window: the opening 25 days would be a run of
        // neutral scores for an athlete who was not yet using the app.
        let points = series(sessions: sessions(dailyFor: 5), days: 30)

        XCTAssertEqual(points.count, 5)
        XCTAssertEqual(points.first?.day, calendar.startOfDay(for: day(4)))
    }

    func test_series_withNoSessions_isEmpty() {
        XCTAssertTrue(series(sessions: []).isEmpty)
    }

    func test_series_withZeroDays_isEmpty() {
        XCTAssertTrue(series(sessions: sessions(dailyFor: 20), days: 0).isEmpty)
    }

    // MARK: - Each day sees only its own past

    /// The load-bearing property: a point is built from history up to ITS day. If a later day's
    /// sessions leaked backwards, the whole series would be today's number repeated.
    ///
    /// The probe needs a long QUIET history behind it, not just a quiet fortnight: load
    /// elevation is recent load over the athlete's own baseline, and with a short history the
    /// two move together, so a hard block reads as ratio 1.0 at both ends of the series. Two
    /// months of easy work make the baseline stable enough for the last five hard days to show.
    func test_eachPoint_readsOnlyTheHistoryUpToItsOwnDay() throws {
        let quiet = (5..<60).map { FatigueHistoryEngine.SessionPoint(date: day($0), trainingStress: 20) }
        let hard = (0..<5).map { FatigueHistoryEngine.SessionPoint(date: day($0), trainingStress: 200) }
        let points = series(sessions: quiet + hard)

        let earliest = try XCTUnwrap(points.first)
        let latest = try XCTUnwrap(points.last)
        XCTAssertLessThan(
            earliest.components.loadElevation, latest.components.loadElevation,
            "a day before the hard block cannot carry the hard block's load elevation"
        )
        XCTAssertLessThan(
            earliest.index, latest.index,
            "and the index it builds must move with it"
        )
    }

    func test_softTissueWindow_isMeasuredFromEachDay_notFromNow() {
        // One qualifying niggle 20 days ago: inside the 28-day window for today, and inside it
        // for every day of a 14-day series — but its RECENCY differs per day, so the risk
        // component decays across the series rather than being stamped once.
        let points = series(
            sessions: sessions(dailyFor: 40),
            injuries: [day(20)],
            days: 14
        )
        let earliest = try! XCTUnwrap(points.first)
        let latest = try! XCTUnwrap(points.last)

        XCTAssertGreaterThan(earliest.components.softTissueRisk, 0)
        XCTAssertGreaterThan(
            earliest.components.softTissueRisk, latest.components.softTissueRisk,
            "a niggle's contribution decays as the series walks away from it"
        )
    }

    func test_softTissue_isZeroWhenTheNiggleIsOlderThanTheWindow() {
        let points = series(sessions: sessions(dailyFor: 60), injuries: [day(90)], days: 14)
        XCTAssertEqual(points.last?.components.softTissueRisk, 0)
    }

    // MARK: - Parity with the live reading

    /// The series' last point must BE the dashboard's number. It is the same engine fed the same
    /// way; this pins that the windows agree, because a Trends hero that disagreed with Today's
    /// fatigue banner about the same day would be a visible defect and not a rounding one.
    func test_todayPoint_matchesADirectFatigueIndexComputation() {
        let stress: Double = 90
        let sessionPoints = sessions(dailyFor: 40, stress: stress)
        let recovery = scores(55, days: 40)
        let wellness = scores(60, days: 40)

        let points = series(sessions: sessionPoints, recovery: recovery, wellness: wellness)
        let today = try! XCTUnwrap(points.last)

        // The same input, assembled by hand the way `DashboardViewModel.load()` assembles it.
        let recent14 = Array(repeating: stress, count: 14)
        let expected = FatigueIndexEngine.compute(input: FatigueIndexEngine.FatigueInput(
            recentSessionTSS: recent14,
            baselineSessionTSS: stress,
            sessionsIn14Days: 14,
            baselineSessionsIn14Days: FatigueIndexEngine.baselineSessionsPer14Days(
                sessionDates: sessionPoints.map(\.date),
                asOf: calendar.startOfDay(for: now),
                calendar: calendar
            ),
            trainingStreakDays: 14,
            daysSinceRestPeriod: nil,
            recentRecoveryScores: Array(repeating: 55, count: 7),
            recentWellnessScores: Array(repeating: 60, count: 14),
            softTissueInjuryCount: 0,
            daysSinceLastInjury: nil
        ))

        XCTAssertEqual(today.index, expected.index, accuracy: 0.0001)
        XCTAssertEqual(today.zone, expected.zone)
        XCTAssertEqual(today.components, expected)
    }

    /// The streak counts back from the day and STOPS at the first rest day — and a day with no
    /// session of its own scores zero, not "the streak that ended yesterday". Same rule as
    /// `DashboardViewModel.computeDaysSinceRest`, which is why the two can share a number.
    ///
    /// Rest debt is the only component the streak reaches, so it is the probe: day 0 sits on a
    /// two-day streak, day 6 on a one-day streak, and day 2 is a rest day with no streak at all.
    func test_trainingStreak_stopsAtTheFirstRestDay() {
        // Trained every day except two days ago.
        let trained = [0, 1, 3, 4, 5, 6].map {
            FatigueHistoryEngine.SessionPoint(date: day($0), trainingStress: 80)
        }
        func restDebt(onDayOffset offset: Int) -> Double {
            FatigueHistoryEngine.point(
                for: day(offset),
                sessions: trained,
                recoveryScores: [],
                wellnessScores: [],
                qualifyingInjuryDates: [],
                calendar: calendar
            ).components.restDebt
        }

        XCTAssertGreaterThan(restDebt(onDayOffset: 0), restDebt(onDayOffset: 6),
                             "a two-day streak carries more rest debt than a one-day streak")
        XCTAssertGreaterThan(restDebt(onDayOffset: 6), restDebt(onDayOffset: 2),
                             "the rest day itself carries no streak at all")
    }

    // MARK: - Reading the series

    func test_trajectory_readsRisingFallingAndSteady() {
        func points(_ values: [Double]) -> [FatigueHistoryEngine.Point] {
            values.enumerated().map { index, value in
                FatigueHistoryEngine.Point(
                    day: day(values.count - 1 - index),
                    index: value,
                    zone: FatigueIndexEngine.FatigueZone.classify(index: value),
                    components: FatigueIndexEngine.compute(input: FatigueIndexEngine.FatigueInput(
                        recentSessionTSS: [], baselineSessionTSS: nil,
                        sessionsIn14Days: 0, baselineSessionsIn14Days: nil,
                        trainingStreakDays: 0, daysSinceRestPeriod: nil,
                        recentRecoveryScores: [], recentWellnessScores: [],
                        softTissueInjuryCount: 0, daysSinceLastInjury: nil
                    ))
                )
            }
        }

        XCTAssertEqual(FatigueHistoryEngine.trajectory(points([40, 45, 50, 55, 60])), .rising)
        XCTAssertEqual(FatigueHistoryEngine.trajectory(points([60, 55, 50, 45, 40])), .falling)
        XCTAssertEqual(FatigueHistoryEngine.trajectory(points([50, 50, 51, 50, 50])), .steady)
        XCTAssertNil(FatigueHistoryEngine.trajectory([]), "one point is not a direction")
    }

    func test_daysWithoutRelief_countsTheTailThatNeverCameDown() {
        func points(_ values: [Double]) -> [FatigueHistoryEngine.Point] {
            values.enumerated().map { index, value in
                FatigueHistoryEngine.Point(
                    day: day(values.count - 1 - index),
                    index: value,
                    zone: FatigueIndexEngine.FatigueZone.classify(index: value),
                    components: FatigueIndexEngine.compute(input: FatigueIndexEngine.FatigueInput(
                        recentSessionTSS: [], baselineSessionTSS: nil,
                        sessionsIn14Days: 0, baselineSessionsIn14Days: nil,
                        trainingStreakDays: 0, daysSinceRestPeriod: nil,
                        recentRecoveryScores: [], recentWellnessScores: [],
                        softTissueInjuryCount: 0, daysSinceLastInjury: nil
                    ))
                )
            }
        }

        XCTAssertEqual(FatigueHistoryEngine.daysWithoutRelief(points([60, 50, 52, 54, 56])), 3)
        XCTAssertEqual(FatigueHistoryEngine.daysWithoutRelief(points([50, 60, 55])), 0,
                       "the last day came down, so there is no run to report")
        XCTAssertEqual(FatigueHistoryEngine.daysWithoutRelief(points([50])), 0)
    }

    // MARK: - Claim rails

    /// The engine returns descriptions, never predictions. A source fence, because the rail is
    /// about what the surface is ALLOWED to say and a green numeric test cannot see copy.
    func test_fence_engineNamesNoRiskAndNoForecast() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("WorkloadApp/Services/FatigueHistoryEngine.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        for banned in ["forecast(", "predictRisk", "injuryRisk", "willOverreach"] {
            XCTAssertFalse(
                source.contains(banned),
                "FatigueHistoryEngine describes accumulation and trajectory — it never forecasts or names a risk (U9 claim rails)"
            )
        }
    }
}
