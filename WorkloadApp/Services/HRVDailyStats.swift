import Foundation

/// The one reducer turning raw HealthKit HRV samples into the **daily** series every HRV
/// surface reads, plus the baseline/deviation statistics computed over it.
///
/// ## Why this exists (v1.7.1)
///
/// Every HRV statistic in the app was computed as `samples.suffix(7)` over the RAW
/// HealthKit series. An Apple Watch writes several SDNN samples a day, so "7-day average"
/// actually spanned about one to two days, the ±1 SD band was a within-day spread, and the
/// deviation percent was compressed toward zero because the latest sample sat inside its own
/// baseline. The window stamp printed a sample count with a `D` suffix ("147D").
///
/// ## The reduction, and why this one
///
/// One value per calendar day: the **median of that day's samples taken before
/// `DayBucketer.morningWindowEndHour` (11:00 local)**. Days with no in-window sample are
/// GAPs — never imputed, never carried forward.
///
/// The morning/overnight restriction is the substantive choice, taken after a multi-model
/// review and a literature check (2026-08-05). Readiness research standardises measurement
/// to a single low-stimulus window — overnight or immediately on waking — because HRV taken
/// through the day is dominated by posture, food, caffeine, stress and training rather than
/// by recovery state. Mixing those contexts into one daily number measures the day, not the
/// athlete's readiness for it. Two alternatives were considered and rejected: a median of
/// ALL of a day's samples (more data, but still mixing physiological contexts), and
/// weighting samples by time of day (no validated weighting kernel exists to defend, and it
/// would hide the mixing rather than remove it).
///
/// Known limitation, stated rather than buried: the fixed 11:00 boundary is a heuristic, not
/// a physiological one. It suits a conventional night's sleep; it mis-serves shift work, a
/// very early bedtime (pre-midnight samples fall outside the window AND land on the previous
/// day), and a waking time after 11:00. The principled key is the athlete's own detected
/// wake time, which the clustered sleep session already provides — deferred deliberately,
/// because binding the HRV series to sleep-session completeness adds a failure mode this
/// patch should not carry. Copy therefore says "morning", never "your wake time".
///
/// Also note the app records Apple's automatically-sampled **SDNN**, while most athlete
/// readiness research uses standardised LnRMSSD recordings. This reduction is defensible
/// noise control; it is not a validation of the readiness algorithm itself.
/// ## Where the arithmetic lives (v1.7.3)
///
/// The baseline / spread / deviation functions moved to `DailySignalStats` when the RHR detail
/// screen needed the same five over an all-day series. Everything below still reads as HRV and
/// every call site is unchanged; only the implementations now point at the shared maths, so the
/// two signals can never drift apart on what "my normal" means. What stays HERE is what is
/// genuinely HRV's: the morning-window reduction above, and the availability cases that exist
/// because that window can be empty on a day that has samples.
struct HRVDailyStats {

    /// See `DailySignalStats.minimumBaselineDays`.
    static let minimumBaselineDays: Int = DailySignalStats.minimumBaselineDays

    /// Number of trailing calendar days the baseline is drawn from.
    static let baselineWindowDays: Int = DailySignalStats.baselineWindowDays

    /// One calendar day's HRV value (gaps excluded — this array is sparse by design).
    typealias DailyValue = DailySignalStats.DailyValue

    /// Reduce raw samples to one value per calendar day, morning window only, gaps dropped.
    ///
    /// - Parameter samples: raw `(date, value)` HealthKit samples in any order.
    /// - Parameter days: how many trailing calendar days to cover.
    /// - Parameter now: reference instant (injected for tests).
    /// - Parameter calendar: injected calendar.
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
        return DayBucketer.bucketMorningWindow(
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

    /// The reading the screen reports: the most recent day that has a value.
    static func latest(_ daily: [DailyValue]) -> DailyValue? {
        DailySignalStats.latest(daily)
    }

    /// Days inside the trailing baseline window that are STRICTLY EARLIER than `latest`.
    ///
    /// Excluding the latest day is what makes the deviation meaningful: a baseline that
    /// contains the reading being compared to it pulls toward that reading, and with a
    /// single day of history it equals it exactly (a permanent, false "0% — on baseline").
    static func baselineDays(
        _ daily: [DailyValue],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [DailyValue] {
        DailySignalStats.baselineDays(daily, calendar: calendar)
    }

    /// Mean of the baseline days, or nil when fewer than `minimumBaselineDays` exist.
    static func baseline(
        _ daily: [DailyValue],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Double? {
        DailySignalStats.baseline(daily, calendar: calendar)
    }

    /// Population SD of the baseline days; nil whenever the baseline itself is nil.
    static func standardDeviation(
        _ daily: [DailyValue],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Double? {
        DailySignalStats.standardDeviation(daily, calendar: calendar)
    }

    /// Percent deviation of the latest day from the baseline; nil when either is missing.
    static func deviationPercent(
        _ daily: [DailyValue],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Double? {
        DailySignalStats.deviationPercent(daily, calendar: calendar)
    }

    /// What the HRV surfaces should render, so "no data" is never silent.
    ///
    /// The distinction matters: before this patch a midday-only wearer saw a wrong-but-
    /// present number. After the morning window they would see "—" with no explanation,
    /// which reads as a broken app. `noMorningSamples` exists to say why.
    enum Availability: Equatable {
        /// No HRV samples at all in the fetched range.
        case noSamples
        /// Samples exist, but none inside the morning window on any day.
        case noMorningSamples
        /// At least one daily value, but fewer baseline days than `minimumBaselineDays`.
        case building(days: Int)
        /// Enough daily values for a baseline and deviation.
        case ready
    }

    static func availability(
        rawSampleCount: Int,
        daily: [DailyValue],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Availability {
        if daily.isEmpty {
            return rawSampleCount == 0 ? .noSamples : .noMorningSamples
        }
        let baselineCount = baselineDays(daily, now: now, calendar: calendar).count
        return baselineCount >= minimumBaselineDays ? .ready : .building(days: daily.count)
    }
}
