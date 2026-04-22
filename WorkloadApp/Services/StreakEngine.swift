import Foundation

/// Computes consecutive-week training streaks from workout session history.
/// A "streak" counts backward from the current calendar week: each consecutive
/// week that contains at least one logged WorkoutSession increments the count.
/// If the current week has no sessions, the streak is 0 (per D-02, hidden in UI).
struct StreakEngine {

    /// Returns the number of consecutive calendar weeks (including current) with at least one session.
    /// Returns 0 if no session exists in the current calendar week.
    ///
    /// Uses `Calendar.current` for locale-aware week boundaries (per research pitfall #2).
    /// - Parameter sessions: All WorkoutSessions to consider. Only `sessionDate` is read.
    static func computeStreak(sessions: [WorkoutSession]) -> Int {
        guard !sessions.isEmpty else { return 0 }
        let calendar = Calendar.current

        // Build a set of (yearForWeekOfYear, weekOfYear) keys for all sessions
        var weekSet = Set<String>()
        for session in sessions {
            let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: session.sessionDate)
            if let y = comps.yearForWeekOfYear, let w = comps.weekOfYear {
                weekSet.insert("\(y)-\(w)")
            }
        }

        // Walk backward from current week
        var streak = 0
        var checkDate = Date.now
        while true {
            let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: checkDate)
            guard let y = comps.yearForWeekOfYear, let w = comps.weekOfYear else { break }
            let key = "\(y)-\(w)"
            if weekSet.contains(key) {
                streak += 1
                guard let prevWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: checkDate) else { break }
                checkDate = prevWeek
            } else {
                break
            }
        }
        return streak
    }
}
