import Foundation

/// The baseline statistics every **daily** physiological series reports: the latest day, the
/// prior-day baseline window, its spread, and the latest day's deviation from it.
///
/// ## Why this exists (v1.7.3 · UAT round 1 · U9)
///
/// `HRVDailyStats` grew these five functions for HRV, and the rule that makes them honest —
/// *the baseline never contains the day being compared against it* — is the load-bearing part,
/// not the signal. Wiring Today's RHR cell to a detail screen needed the same five functions
/// over a differently-bucketed series. Copying them would have left the app with two
/// implementations of "my normal" that could drift apart while both looked correct.
///
/// So the arithmetic lives here once, and the per-signal types own only what genuinely differs:
/// **how raw samples reduce to one value per day**, and **what "no data" means** for that
/// signal. `HRVDailyStats` and `RHRDailyStats` are both thin over this.
///
/// Foundation-only, no ambient clock (`now` and `calendar` are parameters), no HealthKit and no
/// SwiftData — the `DayBucketer` purity contract.
struct DailySignalStats {

    /// One calendar day's value for a signal. Gaps are ABSENT from the array rather than
    /// carried as nil — a series of these is sparse by design, never imputed.
    struct DailyValue: Equatable {
        let date: Date
        let value: Double
    }

    /// Minimum number of PRIOR daily values required before a baseline — and therefore a
    /// deviation — is reported. Below this the "baseline" is one or two days, and a deviation
    /// against it is noise wearing a percentage sign. At n = 1 it is worse than noise: the
    /// latest day IS the baseline, so the deviation is a permanent, false 0%.
    static let minimumBaselineDays: Int = 3

    /// Number of trailing calendar days the baseline is drawn from.
    static let baselineWindowDays: Int = 7

    /// The reading a screen reports: the most recent day that has a value.
    static func latest(_ daily: [DailyValue]) -> DailyValue? {
        daily.last
    }

    /// Days inside the trailing baseline window that are STRICTLY EARLIER than `latest`.
    ///
    /// Excluding the latest day is what makes the deviation mean anything: a baseline that
    /// contains the reading being compared to it is pulled toward that reading.
    static func baselineDays(
        _ daily: [DailyValue],
        calendar: Calendar = .current
    ) -> [DailyValue] {
        guard let latest = latest(daily) else { return [] }
        let latestDay = calendar.startOfDay(for: latest.date)
        guard let windowStart = calendar.date(
            byAdding: .day, value: -baselineWindowDays, to: latestDay
        ) else { return [] }
        return daily.filter { entry in
            let day = calendar.startOfDay(for: entry.date)
            return day >= windowStart && day < latestDay
        }
    }

    /// Mean of the baseline days, or nil below `minimumBaselineDays`.
    ///
    /// Mean rather than a second median: the day values are already medians where the signal
    /// needed that, so intra-day robustness is handled; the outer figure is the ordinary
    /// central tendency an athlete reads as "my normal", and it matches the mean
    /// `RecoveryScoreEngine.computeBaseline` uses so the two never tell different stories.
    static func baseline(
        _ daily: [DailyValue],
        calendar: Calendar = .current
    ) -> Double? {
        let days = baselineDays(daily, calendar: calendar)
        guard days.count >= minimumBaselineDays else { return nil }
        return days.map(\.value).reduce(0, +) / Double(days.count)
    }

    /// Population SD of the baseline days; nil whenever the baseline itself is nil, so a band
    /// is never drawn around a figure the screen is not willing to state.
    static func standardDeviation(
        _ daily: [DailyValue],
        calendar: Calendar = .current
    ) -> Double? {
        let days = baselineDays(daily, calendar: calendar)
        guard days.count >= minimumBaselineDays,
              let mean = baseline(daily, calendar: calendar) else { return nil }
        let variance = days
            .map { ($0.value - mean) * ($0.value - mean) }
            .reduce(0, +) / Double(days.count)
        return variance.squareRoot()
    }

    /// Percent deviation of the latest day from the baseline; nil when either is missing.
    static func deviationPercent(
        _ daily: [DailyValue],
        calendar: Calendar = .current
    ) -> Double? {
        guard let latest = latest(daily),
              let baseline = baseline(daily, calendar: calendar),
              baseline > 0 else { return nil }
        return ((latest.value - baseline) / baseline) * 100
    }
}

/// The daily resting-heart-rate series behind Today's RHR cell, plus its baseline statistics.
///
/// ## The one substantive difference from HRV, and why
///
/// **RHR takes the all-day reduction, with no morning-window filter.** Apple Watch derives
/// resting heart rate as a *daily aggregate* over rest periods and refines it through the day,
/// so the sample's timestamp does not mark a morning reading — filtering it by hour would keep
/// or drop a day's value essentially at random. HRV SDNN is the opposite: a momentary
/// measurement whose time of day genuinely changes what it means, so it keeps the morning
/// window. Both reviewers on the 2026-08-05 panel raised this independently, and
/// `ReadinessInputReducer` already scores the two signals this way — this type is the CHART
/// side of the same decision, so the screen and the score agree about the same athlete on the
/// same day.
///
/// ## Direction, stated because it is the opposite of HRV's
///
/// A *rise* above baseline is the direction of interest for RHR; for HRV it is a fall. Nothing
/// here encodes that — deviation is reported signed and the screen names what it means in
/// words. Colouring an elevated RHR red would be a diagnosis the engine cannot support, which
/// is the pressure the nocebo guard exists to prevent.
struct RHRDailyStats {

    typealias DailyValue = DailySignalStats.DailyValue

    static let minimumBaselineDays: Int = DailySignalStats.minimumBaselineDays
    static let baselineWindowDays: Int = DailySignalStats.baselineWindowDays

    /// Reduce raw samples to one value per calendar day across the trailing `days` window.
    /// Several samples on one day collapse to their median (defensive dedup); a day with no
    /// sample is a GAP and is dropped, never imputed and never carried forward.
    static func dailyValues(
        samples: [(date: Date, value: Double)],
        days: Int,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [DailyValue] {
        guard days > 0 else { return [] }
        let end = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: end) else {
            return []
        }
        return DayBucketer.bucketAllDay(
            samples: samples,
            rangeStart: start,
            rangeEnd: end,
            calendar: calendar
        )
        .compactMap { bucket in
            guard let value = bucket.value else { return nil }
            return DailyValue(date: bucket.date, value: value)
        }
    }

    static func latest(_ daily: [DailyValue]) -> DailyValue? {
        DailySignalStats.latest(daily)
    }

    static func baselineDays(_ daily: [DailyValue], calendar: Calendar = .current) -> [DailyValue] {
        DailySignalStats.baselineDays(daily, calendar: calendar)
    }

    static func baseline(_ daily: [DailyValue], calendar: Calendar = .current) -> Double? {
        DailySignalStats.baseline(daily, calendar: calendar)
    }

    static func standardDeviation(_ daily: [DailyValue], calendar: Calendar = .current) -> Double? {
        DailySignalStats.standardDeviation(daily, calendar: calendar)
    }

    static func deviationPercent(_ daily: [DailyValue], calendar: Calendar = .current) -> Double? {
        DailySignalStats.deviationPercent(daily, calendar: calendar)
    }

    /// What the RHR surface should render, so "no data" is never silent.
    ///
    /// There is no `noMorningSamples` case here and its absence is the point: RHR has no
    /// window filter, so a sample that exists always lands on a day. Either HealthKit wrote
    /// nothing, or the history is still too short for a baseline.
    enum Availability: Equatable {
        /// No resting-heart-rate samples at all in the fetched range.
        case noSamples
        /// At least one daily value, but fewer prior days than `minimumBaselineDays`.
        case building(days: Int)
        /// Enough daily values for a baseline and a deviation.
        case ready
    }

    static func availability(
        daily: [DailyValue],
        calendar: Calendar = .current
    ) -> Availability {
        guard !daily.isEmpty else { return .noSamples }
        let priorDays = baselineDays(daily, calendar: calendar).count
        return priorDays >= minimumBaselineDays ? .ready : .building(days: daily.count)
    }
}
