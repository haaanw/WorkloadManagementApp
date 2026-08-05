import XCTest
import SwiftData
@testable import workload_management

/// The v1.7.1 streak rule: an in-progress week that has not yet been trained is unfinished,
/// not missed. Before this, every Monday morning a long streak read 0 and the flame row
/// vanished until the week's first session.
@MainActor
final class StreakEngineGraceTests: XCTestCase {

    private var calendar: Calendar = {
        var c = Calendar(identifier: .iso8601)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    /// Monday 2026-08-03 08:00 UTC — a Monday morning, the exact moment the bug showed.
    private var mondayMorning: Date {
        DateComponents(
            calendar: calendar, timeZone: calendar.timeZone,
            year: 2026, month: 8, day: 3, hour: 8
        ).date!
    }

    private func session(weeksAgo: Int) -> WorkoutSession {
        let date = calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: mondayMorning)!
        let s = WorkoutSession()
        s.sessionDate = date
        return s
    }

    func test_mondayMorning_beforeFirstSession_keepsTheEarnedStreak() {
        // Trained the three completed weeks; this week has not started yet.
        let sessions = [session(weeksAgo: 1), session(weeksAgo: 2), session(weeksAgo: 3)]
        let streak = StreakEngine.computeStreak(
            sessions: sessions, now: mondayMorning, calendar: calendar
        )
        XCTAssertEqual(streak, 3, "an unfinished week must not read as a missed week")
    }

    func test_currentWeekTrained_countsTheCurrentWeek() {
        let sessions = [session(weeksAgo: 0), session(weeksAgo: 1), session(weeksAgo: 2)]
        let streak = StreakEngine.computeStreak(
            sessions: sessions, now: mondayMorning, calendar: calendar
        )
        XCTAssertEqual(streak, 3)
    }

    func test_wholeWeekMissed_breaksTheStreak() {
        // Nothing this week AND nothing last week — a full week completed with no training.
        let sessions = [session(weeksAgo: 2), session(weeksAgo: 3)]
        let streak = StreakEngine.computeStreak(
            sessions: sessions, now: mondayMorning, calendar: calendar
        )
        XCTAssertEqual(streak, 0, "a completed empty week is a genuine break")
    }

    func test_gapInOlderWeeks_stopsTheCount() {
        let sessions = [session(weeksAgo: 1), session(weeksAgo: 2), session(weeksAgo: 4)]
        let streak = StreakEngine.computeStreak(
            sessions: sessions, now: mondayMorning, calendar: calendar
        )
        XCTAssertEqual(streak, 2)
    }

    func test_noSessions_isZero() {
        XCTAssertEqual(
            StreakEngine.computeStreak(sessions: [], now: mondayMorning, calendar: calendar),
            0
        )
    }

    func test_streakNeverRisesWithoutASession() {
        // Same history read on Monday and again on Friday of the same untrained week.
        let sessions = [session(weeksAgo: 1), session(weeksAgo: 2)]
        let friday = calendar.date(byAdding: .day, value: 4, to: mondayMorning)!
        XCTAssertEqual(
            StreakEngine.computeStreak(sessions: sessions, now: mondayMorning, calendar: calendar),
            StreakEngine.computeStreak(sessions: sessions, now: friday, calendar: calendar)
        )
    }
}
