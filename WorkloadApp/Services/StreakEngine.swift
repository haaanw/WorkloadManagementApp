import Foundation

/// Computes consecutive-week training streaks from workout session history.
///
/// A "streak" is the number of consecutive ISO weeks, counting backward, that contain at
/// least one logged `WorkoutSession`.
///
/// **The in-progress week is not evidence of failure (v1.7.1).** The original walk started
/// at the current week and broke immediately when it held no session, so every Monday
/// morning — before the week's first session — a six-week streak read `0` and the flame row
/// vanished from `WeeklySummaryCard`. A week that has not finished cannot have been missed.
/// The rule is therefore:
///
/// - Current week has a session → count it and walk back.
/// - Current week is empty → it is still in progress; start the walk at LAST week, so the
///   streak shows what the athlete has actually earned so far.
/// - Current week empty AND last week empty → a whole week completed with no training. The
///   streak is genuinely broken: `0`.
///
/// The number never rises without a logged session, and it stops claiming the current week
/// on the athlete's behalf — it reports completed weeks until this week earns its place.
struct StreakEngine {

    /// Number of consecutive ISO weeks with at least one session, per the rule above.
    ///
    /// - Parameter sessions: sessions to consider; only `sessionDate` is read.
    /// - Parameter now: injected clock (tests pin it; production passes the default).
    /// - Parameter calendar: injected calendar for week boundaries.
    static func computeStreak(
        sessions: [WorkoutSession],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        guard !sessions.isEmpty else { return 0 }

        // Week identity = (yearForWeekOfYear, weekOfYear) so year rollover cannot collide.
        var weekSet = Set<String>()
        for session in sessions {
            let comps = calendar.dateComponents(
                [.yearForWeekOfYear, .weekOfYear],
                from: session.sessionDate
            )
            if let y = comps.yearForWeekOfYear, let w = comps.weekOfYear {
                weekSet.insert("\(y)-\(w)")
            }
        }

        func weekKey(_ date: Date) -> String? {
            let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            guard let y = comps.yearForWeekOfYear, let w = comps.weekOfYear else { return nil }
            return "\(y)-\(w)"
        }

        // Start at the current week when it already holds a session; otherwise start at last
        // week, because an empty in-progress week is unfinished, not missed.
        var cursor = now
        if let currentKey = weekKey(now), !weekSet.contains(currentKey) {
            guard let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: now) else {
                return 0
            }
            cursor = lastWeek
        }

        var streak = 0
        while let key = weekKey(cursor), weekSet.contains(key) {
            streak += 1
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else {
                break
            }
            cursor = previous
        }
        return streak
    }
}
