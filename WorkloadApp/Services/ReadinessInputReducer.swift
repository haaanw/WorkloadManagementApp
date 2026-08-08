import Foundation

/// Turns raw HealthKit history into the exact values the recovery score consumes: today's
/// reading per signal, and the baseline series behind it.
///
/// ## Why this exists (v1.7.1 algorithm update)
///
/// The pipeline used to take `fetchLatestHRVWithDate()` — literally whatever sample HealthKit
/// wrote most recently, over an unbounded window. For an Apple Watch user that is frequently
/// a midday reading, so "today's HRV" could be a value taken standing in a queue after
/// coffee, scored against a baseline built the same careless way. Meanwhile the HRV charts
/// had already moved to morning-window daily medians, so the score and the chart one tap away
/// disagreed about the same athlete on the same day.
///
/// Two signals, two reductions, and the difference is not cosmetic:
///
/// - **HRV (SDNN) is a momentary measurement.** When it was taken changes what it means, so
///   only the morning window counts (`DayBucketer.bucketMorningWindow`). A day with no
///   morning sample has no HRV — it is not filled in from the afternoon or from yesterday.
/// - **Resting heart rate is already a daily aggregate.** Apple Watch computes RHR over rest
///   periods and refines it through the day; its timestamp does not mark a morning reading.
///   Filtering it by hour would keep or drop it essentially at random, so RHR takes the
///   all-day per-day reduction (`DayBucketer.bucketAllDay`). Both reviewers on the 2026-08-05
///   panel raised this independently; it is the one place the two signals must diverge.
///
/// ## Today is never part of its own baseline
///
/// `baselineValues` returns days STRICTLY BEFORE today. The old path fetched a 7-day history
/// that included today's own row once the day's first run had written it, so a second run —
/// a wellness check-in, a dashboard reload — folded today's reading into the mean it was
/// about to be compared against. The deviation shrank and the score moved with no new
/// physiology. Same defect, same fix, for the score-trend series.
///
/// Pure and injectable: no HealthKit, no SwiftData, no ambient clock.
struct ReadinessInputReducer {

    /// One signal reduced for scoring: today's value (if any) and the prior-day series.
    struct Reduced {
        /// Today's reading, or nil when today has no qualifying measurement. Nil is a real
        /// answer — `RecoveryScoreEngine` drops the component and renormalizes over what is
        /// present, which is honest, rather than scoring a value we do not have.
        let today: Double?
        /// Strictly-prior days that carry a value, oldest first. The baseline is computed
        /// from these, so today can never pull its own comparison.
        let priorDays: [Double]
        /// The same prior days with their dates, for consumers that fold day by day and need
        /// to know WHICH day each value belongs to — `BaselineCheckpoint` seals by date.
        let priorDatedDays: [(day: Date, value: Double)]
        /// Days with data in the window, today included — for coverage reporting.
        let observedDayCount: Int
    }

    /// Reduce HRV samples: morning window, median per day.
    static func hrv(
        samples: [(date: Date, value: Double)],
        windowDays: Int,
        now: Date,
        calendar: Calendar
    ) -> Reduced {
        reduce(
            buckets: bucketsForMorningWindow(
                samples: samples, windowDays: windowDays, now: now, calendar: calendar
            ),
            now: now,
            calendar: calendar
        )
    }

    /// Reduce RHR samples: per calendar day, NO hour filter (see the type doc).
    static func rhr(
        samples: [(date: Date, value: Double)],
        windowDays: Int,
        now: Date,
        calendar: Calendar
    ) -> Reduced {
        guard let range = range(windowDays: windowDays, now: now, calendar: calendar) else {
            return Reduced(today: nil, priorDays: [], priorDatedDays: [], observedDayCount: 0)
        }
        return reduce(
            buckets: DayBucketer.bucketAllDay(
                samples: samples,
                rangeStart: range.start,
                rangeEnd: range.end,
                calendar: calendar
            ),
            now: now,
            calendar: calendar
        )
    }

    /// Drop today from a day-keyed score series, so the trend modifier cannot read the score
    /// it is about to modify. `recentScores` came from a history fetch that included today's
    /// row after the day's first run.
    static func priorDayScores(
        _ dated: [(date: Date, score: Double)],
        now: Date,
        calendar: Calendar
    ) -> [Double] {
        let today = calendar.startOfDay(for: now)
        return dated
            .filter { calendar.startOfDay(for: $0.date) < today }
            .sorted { $0.date < $1.date }
            .map(\.score)
    }

    // MARK: - Private

    private static func range(
        windowDays: Int,
        now: Date,
        calendar: Calendar
    ) -> (start: Date, end: Date)? {
        guard windowDays > 0 else { return nil }
        let end = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .day, value: -(windowDays - 1), to: end) else {
            return nil
        }
        return (start, end)
    }

    private static func bucketsForMorningWindow(
        samples: [(date: Date, value: Double)],
        windowDays: Int,
        now: Date,
        calendar: Calendar
    ) -> [DayBucketer.BucketedDay] {
        guard let range = range(windowDays: windowDays, now: now, calendar: calendar) else {
            return []
        }
        return DayBucketer.bucketMorningWindow(
            samples: samples,
            rangeStart: range.start,
            rangeEnd: range.end,
            calendar: calendar
        )
    }

    private static func reduce(
        buckets: [DayBucketer.BucketedDay],
        now: Date,
        calendar: Calendar
    ) -> Reduced {
        let today = calendar.startOfDay(for: now)
        var todayValue: Double?
        var prior: [Double] = []
        var priorDated: [(day: Date, value: Double)] = []
        var observed = 0
        for bucket in buckets {
            guard let value = bucket.value else { continue }
            observed += 1
            let day = calendar.startOfDay(for: bucket.date)
            if day == today {
                todayValue = value
            } else if day < today {
                prior.append(value)
                priorDated.append((day: day, value: value))
            }
        }
        return Reduced(
            today: todayValue,
            priorDays: prior,
            priorDatedDays: priorDated,
            observedDayCount: observed
        )
    }
}
