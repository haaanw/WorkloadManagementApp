import Foundation

/// Runs `FatigueIndexEngine` once per past day, so accumulated fatigue has a HISTORY instead of
/// a single reading.
///
/// ## Why this exists (v1.7.3 · UAT round 1 · U9)
///
/// The fatigue index was computed for today only, in two view models. Trends was asked to answer
/// "what does this add up to for my fatigue", and accumulation and trajectory are both statements
/// about a series — there was no series. This engine builds one.
///
/// **It adds no storage and no algorithm.** Every day's index comes out of the same
/// `FatigueIndexEngine.compute(input:)` the dashboard calls, fed from history the app already
/// persists: `WorkoutSession` dates and training stress, `RecoverySnapshot.recoveryScore`,
/// `WellnessCheckIn.wellnessScore`, and the local niggle log. Walking a pure engine backwards over
/// data we hold is a reduction, not a new model — and it means a historical point can never
/// disagree with the number Today shows, because it is the same function.
///
/// ## Retrospective, and honest about it
///
/// Each day's index is computed from what the app knows NOW about that day, not from what it knew
/// on that day. A check-in entered late, or a HealthKit sync that arrived a day behind, lands on
/// the day it belongs to and the whole series reflects it. That is the right behaviour for a
/// history — a chart of what happened, not a log of what was displayed — but it does mean the
/// series is not a record of past screens.
///
/// ## Parity with the live reading
///
/// The today point is built by the same rules `DashboardViewModel.load()` uses, with the windows
/// pinned to calendar days rather than to a rolling instant:
///
/// - recent session TSS: the 14 calendar days ending on the day (live: `.now - 14 days`),
/// - baseline session TSS: the mean of all positive training-stress values up to the day,
/// - session density: sessions in those 14 days, against `baselineSessionsPer14Days` up to the day,
/// - training streak: consecutive days ending on the day that carry a session, capped at 14,
/// - `daysSinceRestPeriod`: **nil**, exactly as the live path passes it,
/// - recovery trend: the last 7 recovery scores inside the trailing 28 days,
/// - wellness trend: check-in scores inside the trailing 14 days,
/// - soft tissue: qualifying niggles inside `NiggleInjuryDeriver.injuryWindowDays` of the day.
///
/// The calendar-day pinning is the one deliberate difference, and it is why a day's point does
/// not move when the clock does. `cycleContext` is nil here for the same reason the dashboard
/// passes nil: the cycle modifier is not activated.
///
/// Foundation-only, no ambient clock, no SwiftData — callers reduce their models to the three
/// value types below first. `FatigueIndexEngine` stays the only place the weights live.
struct FatigueHistoryEngine {

    // MARK: - Input value types

    /// One logged session, reduced to what the fatigue model reads.
    struct SessionPoint: Equatable {
        let date: Date
        let trainingStress: Double
    }

    /// One day-keyed score (a recovery score, a wellness score).
    struct DayScore: Equatable {
        let date: Date
        let value: Double
    }

    // MARK: - Output

    /// One day of the series.
    struct Point: Equatable {
        /// `startOfDay` of the day this point describes.
        let day: Date
        /// The fatigue accumulation index, 0–100 (higher = more fatigued).
        let index: Double
        let zone: FatigueIndexEngine.FatigueZone
        /// The component scores behind `index`, so the hero's reason tree reports the same
        /// decomposition the number was built from.
        let components: FatigueIndexEngine.FatigueResult
    }

    /// The overall direction of a series.
    enum Trajectory: Equatable {
        /// Fatigue is accumulating across the window.
        case rising
        /// Flat within the noise band.
        case steady
        /// Fatigue is coming down.
        case falling
    }

    // MARK: - Tunables, named

    /// Days of history required before a series is drawn at all. Matches `BaselineEngine`'s
    /// confidence floor: below two weeks the load-elevation and density components are being
    /// compared against a baseline built from almost nothing, and a chart of that is a chart of
    /// its own warm-up. The surface says "not enough history yet" instead of guessing.
    static let minimumHistoryDays: Int = 14

    /// Index points per day of slope at or beyond which a window reads as rising / falling
    /// rather than steady. 0.5/day is ~7 points across a fortnight — a move an athlete would
    /// notice, and comfortably outside day-to-day jitter in the component scores.
    static let trajectorySlopeThreshold: Double = 0.5

    /// Trailing calendar days the recovery-trend component reads from (the dashboard's
    /// `fetchRecoveryHistory(days: 28)` window).
    private static let recoveryWindowDays: Int = 28

    /// Number of recovery scores the trend component consumes (the live `suffix(7)`).
    private static let recoveryTrendCount: Int = 7

    /// Trailing calendar days for the session and wellness windows.
    private static let activityWindowDays: Int = 14

    /// Longest training streak the live path will count back (`computeDaysSinceRest`).
    private static let maximumStreakDays: Int = 14

    // MARK: - The series

    /// Build the fatigue index for each of the trailing `days` calendar days, oldest first.
    ///
    /// Days are emitted only where the inputs can support them: the series starts at the first
    /// day on or after the athlete's earliest session, so an account's opening weeks do not
    /// render as a flat run of neutral scores. An empty return means there is nothing to draw.
    static func series(
        sessions: [SessionPoint],
        recoveryScores: [DayScore],
        wellnessScores: [DayScore],
        qualifyingInjuryDates: [Date],
        days: Int,
        asOf: Date = .now,
        calendar: Calendar = .current
    ) -> [Point] {
        guard days > 0, !sessions.isEmpty else { return [] }

        let today = calendar.startOfDay(for: asOf)
        guard let windowStart = calendar.date(byAdding: .day, value: -(days - 1), to: today),
              let earliestSession = sessions.map({ calendar.startOfDay(for: $0.date) }).min()
        else { return [] }

        let first = max(windowStart, earliestSession)
        guard first <= today else { return [] }

        var points: [Point] = []
        var day = first
        while day <= today {
            points.append(
                point(
                    for: day,
                    sessions: sessions,
                    recoveryScores: recoveryScores,
                    wellnessScores: wellnessScores,
                    qualifyingInjuryDates: qualifyingInjuryDates,
                    calendar: calendar
                )
            )
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return points
    }

    /// One day's fatigue index, from everything known up to and including that day.
    static func point(
        for day: Date,
        sessions: [SessionPoint],
        recoveryScores: [DayScore],
        wellnessScores: [DayScore],
        qualifyingInjuryDates: [Date],
        calendar: Calendar = .current
    ) -> Point {
        let dayStart = calendar.startOfDay(for: day)

        let sessionsToDate = sessions.filter { calendar.startOfDay(for: $0.date) <= dayStart }
        let recentSessions = sessionsToDate.filter {
            daysBetween(calendar.startOfDay(for: $0.date), dayStart, calendar) < activityWindowDays
        }

        let positiveStress = sessionsToDate.map(\.trainingStress).filter { $0 > 0 }
        let baselineStress: Double? = positiveStress.isEmpty
            ? nil
            : positiveStress.reduce(0, +) / Double(positiveStress.count)

        let recentRecovery = trailingScores(
            recoveryScores,
            endingOn: dayStart,
            windowDays: recoveryWindowDays,
            calendar: calendar
        ).suffix(recoveryTrendCount)

        let recentWellness = trailingScores(
            wellnessScores,
            endingOn: dayStart,
            windowDays: activityWindowDays,
            calendar: calendar
        )

        let injuriesInWindow = qualifyingInjuryDates.filter {
            let gap = daysBetween(calendar.startOfDay(for: $0), dayStart, calendar)
            return gap >= 0 && gap <= NiggleInjuryDeriver.injuryWindowDays
        }
        let daysSinceLastInjury = injuriesInWindow
            .map { daysBetween(calendar.startOfDay(for: $0), dayStart, calendar) }
            .min()

        let input = FatigueIndexEngine.FatigueInput(
            recentSessionTSS: recentSessions.map(\.trainingStress),
            baselineSessionTSS: baselineStress,
            sessionsIn14Days: recentSessions.count,
            baselineSessionsIn14Days: FatigueIndexEngine.baselineSessionsPer14Days(
                sessionDates: sessionsToDate.map(\.date),
                asOf: dayStart,
                calendar: calendar
            ),
            trainingStreakDays: streakDays(endingOn: dayStart, sessions: sessionsToDate, calendar: calendar),
            // nil, exactly as `DashboardViewModel.load()` passes it — the app has never derived
            // a rest-period marker, and inventing one here would make the history disagree with
            // the reading Today prints.
            daysSinceRestPeriod: nil,
            recentRecoveryScores: Array(recentRecovery),
            recentWellnessScores: recentWellness,
            softTissueInjuryCount: injuriesInWindow.count,
            daysSinceLastInjury: daysSinceLastInjury
        )

        let result = FatigueIndexEngine.compute(input: input)
        return Point(day: dayStart, index: result.index, zone: result.zone, components: result)
    }

    // MARK: - Reading the series

    /// The window's direction, from the least-squares slope of the index over its days.
    ///
    /// `RecoveryScoreEngine.computeSlope` is the app's one regression — the same function the
    /// fatigue engine's own recovery-trend component and the HRV detail screen's trend token
    /// run on. A second implementation here would be a second answer to the same question.
    static func trajectory(_ points: [Point]) -> Trajectory? {
        guard points.count >= 2,
              let slope = RecoveryScoreEngine.computeSlope(values: points.map(\.index))
        else { return nil }
        if slope > trajectorySlopeThreshold { return .rising }
        if slope < -trajectorySlopeThreshold { return .falling }
        return .steady
    }

    /// Consecutive days at the END of the series on which the index did not fall — how long
    /// fatigue has been holding or climbing. Zero when the most recent day came down.
    ///
    /// This is a DESCRIPTION of stored values, which is what the claim rails permit: it counts
    /// what the series already shows and forecasts nothing.
    static func daysWithoutRelief(_ points: [Point]) -> Int {
        guard points.count >= 2 else { return 0 }
        var days = 0
        for index in stride(from: points.count - 1, to: 0, by: -1) {
            guard points[index].index >= points[index - 1].index else { break }
            days += 1
        }
        return days
    }

    // MARK: - Private

    /// Whole calendar days from `from` to `to` (negative when `from` is later).
    private static func daysBetween(_ from: Date, _ to: Date, _ calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: from, to: to).day ?? 0
    }

    /// Scores inside the trailing `windowDays` ending on `day` (inclusive), oldest first.
    private static func trailingScores(
        _ scores: [DayScore],
        endingOn day: Date,
        windowDays: Int,
        calendar: Calendar
    ) -> [Double] {
        scores
            .filter {
                let gap = daysBetween(calendar.startOfDay(for: $0.date), day, calendar)
                return gap >= 0 && gap < windowDays
            }
            .sorted { $0.date < $1.date }
            .map(\.value)
    }

    /// Consecutive days ending on `day` that carry at least one session, capped at
    /// `maximumStreakDays`. Mirrors `DashboardViewModel.computeDaysSinceRest` — including its
    /// behaviour that a day with no session scores 0, not "the streak that ended yesterday".
    private static func streakDays(
        endingOn day: Date,
        sessions: [SessionPoint],
        calendar: Calendar
    ) -> Int {
        let trainedDays = Set(sessions.map { calendar.startOfDay(for: $0.date) })
        var streak = 0
        var cursor = day
        while streak < maximumStreakDays, trainedDays.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }
}
