import Foundation

/// Pure input-layer reducer for the individualized-baseline substrate (Phase 26, Plan 03).
///
/// `DayBucketer` collapses raw HealthKit history (`[(date, value)]`, already fetched by the
/// caller) into **one robust value per signal per calendar day**:
///
/// - **HRV / RHR** — the MEDIAN of the in-morning-window samples for that calendar day
///   (samples whose local hour `< morningWindowEndHour`, default 11). A day with no in-window
///   sample is a **GAP** (`value == nil`). Median-of-one degrades to that single value.
/// - **Sleep** — the last-night aggregate, already one value per night; bucketed onto
///   `startOfDay(of: date)` with no morning-window filter.
///
/// Rules enforced structurally (D-02 / D-02a / RESEARCH §5.1–5.4):
/// - **No carry-forward, no imputation.** A day with no fresh in-window sample is a GAP — the
///   prior day's value is never carried forward. GAP days are emitted (dense output) so the
///   downstream engine/caller can advance `daysSinceLastBucket` (recency erosion) over them.
/// - **Stale-sample dedup.** A sample only contributes to the day equal to `startOfDay(of:
///   sample.date)`. A "latest" sample whose day is earlier than a target day does NOT fill the
///   target day — that target day is a GAP, never a fake-stable repeat. Intra-day grouping
///   dedups repeated samples on the same day into a single median.
///
/// Purity (RESEARCH §5 + the tier map): this struct is **Foundation-only**, takes the `Calendar`
/// as a parameter (used for `startOfDay` / `component(.hour)` only), and contains **no**
/// `Date.now`, no RNG, and no `HealthKit` import — so it is deterministic and unit-testable.
/// HealthKit fetching is the caller's responsibility (see `HealthKitService.fetchHRVHistory` /
/// `fetchRestingHRHistory` / `fetchLastNightSleepWithDate`).
struct DayBucketer {

    /// One calendar day's bucketed value for a single signal.
    /// `value == nil` is a **GAP** (no fresh in-window sample that day; never imputed).
    struct BucketedDay: Equatable {
        /// `startOfDay` of the calendar day this bucket represents.
        let date: Date
        /// The day's robust value (median of the morning window, or the night's aggregate),
        /// or `nil` when the day is a GAP.
        let value: Double?
    }

    // MARK: - Constants

    /// Local hour (exclusive) bounding the overnight / first-morning sample window for
    /// HRV & RHR day-bucketing (D-02 / §5.1). Samples with `hour < morningWindowEndHour`
    /// are in-window. Tunable.
    static let morningWindowEndHour: Int = 11

    // MARK: - HRV / RHR morning-window bucketing

    /// Reduce HRV/RHR history to one `BucketedDay` per calendar day across
    /// `[startOfDay(rangeStart) ... startOfDay(rangeEnd)]` ascending and dense.
    ///
    /// For each day, the value is the MEDIAN of that day's in-window samples
    /// (`calendar.component(.hour, from: sample.date) < morningWindowEndHour`), or `nil` (GAP)
    /// when the day has no in-window sample. No carry-forward, no imputation; stale samples
    /// only land on their own `startOfDay` (so a stale latest sample makes later days GAPs).
    ///
    /// - Parameter samples: already-fetched `(date, value)` pairs (any order, any range).
    /// - Parameter rangeStart: first calendar day to emit (its `startOfDay`).
    /// - Parameter rangeEnd: last calendar day to emit (its `startOfDay`).
    /// - Parameter morningWindowEndHour: exclusive local-hour bound (default `Self.morningWindowEndHour`).
    /// - Parameter calendar: injected calendar (tests pass a fixed UTC gregorian calendar).
    static func bucketMorningWindow(
        samples: [(date: Date, value: Double)],
        rangeStart: Date,
        rangeEnd: Date,
        morningWindowEndHour: Int = DayBucketer.morningWindowEndHour,
        calendar: Calendar
    ) -> [BucketedDay] {
        // Group in-window samples by their own startOfDay (intra-day dedup → single bucket).
        var byDay: [Date: [Double]] = [:]
        for sample in samples {
            let hour = calendar.component(.hour, from: sample.date)
            guard hour < morningWindowEndHour else { continue }   // afternoon excluded
            let day = calendar.startOfDay(for: sample.date)
            byDay[day, default: []].append(sample.value)
        }

        return enumerateDays(rangeStart: rangeStart, rangeEnd: rangeEnd, calendar: calendar)
            .map { day in
                if let values = byDay[day], !values.isEmpty {
                    return BucketedDay(date: day, value: BaselineEngine.median(values))
                }
                // GAP — no fresh in-window sample. Never carried forward, never imputed.
                return BucketedDay(date: day, value: nil)
            }
    }

    // MARK: - Sleep bucketing

    /// Reduce last-night sleep aggregates to one `BucketedDay` per calendar day across
    /// `[startOfDay(rangeStart) ... startOfDay(rangeEnd)]` ascending and dense.
    ///
    /// Sleep is already one value per night; each `(date, value)` is keyed by `startOfDay(of:
    /// date)` (no morning-window filter). Multiple samples on one day collapse to their median
    /// (defensive dedup). A day with no sample is a GAP (`nil`), never carried forward.
    static func bucketSleep(
        samples: [(date: Date, value: Double)],
        rangeStart: Date,
        rangeEnd: Date,
        calendar: Calendar
    ) -> [BucketedDay] {
        var byDay: [Date: [Double]] = [:]
        for sample in samples {
            let day = calendar.startOfDay(for: sample.date)
            byDay[day, default: []].append(sample.value)
        }

        return enumerateDays(rangeStart: rangeStart, rangeEnd: rangeEnd, calendar: calendar)
            .map { day in
                if let values = byDay[day], !values.isEmpty {
                    return BucketedDay(date: day, value: BaselineEngine.median(values))
                }
                return BucketedDay(date: day, value: nil)
            }
    }

    // MARK: - Day-advance / idempotency fold (W-1)

    /// Drive `BaselineEngine.step` over an ascending list of `BucketedDay`s, calling it **exactly
    /// once per advanced bucketed day**. This is the W-1 idempotency owner: 26-02 documented that
    /// the engine is dateless and the monotonic day-advance guard lives in the caller/bucketer.
    ///
    /// A day is folded only when:
    ///   1. it has a fresh value (GAP days are skipped — no carry-forward), AND
    ///   2. `startOfDay(day) > state.lastBucketedDate` (strictly after — §2.4).
    ///
    /// Re-presenting the same day or an older day is a **no-op** (the state passes through
    /// unchanged), so calling `foldBuckets` twice with the same input is idempotent. On each real
    /// fold the engine stamps `lastBucketedDate = day`, advancing the monotonic cutoff.
    ///
    /// - Parameter state: the prior per-signal `SignalState` (never mutated).
    /// - Parameter buckets: ascending `BucketedDay`s for this signal (GAPs allowed; skipped).
    /// - Parameter config: the per-signal `SignalConfig` (half-life / σ-floor / sign).
    /// - Parameter calendar: injected calendar for the `startOfDay` comparison.
    /// - Returns: the folded `SignalState` (input untouched).
    static func foldBuckets(
        state: BaselineEngine.SignalState,
        buckets: [BucketedDay],
        config: BaselineEngine.SignalConfig,
        calendar: Calendar
    ) -> BaselineEngine.SignalState {
        var current = state
        for bucket in buckets {
            // GAP days never fold (no carry-forward); recency erosion is handled downstream
            // via daysSinceLastBucket against `lastBucketedDate`.
            guard let value = bucket.value else { continue }

            let day = calendar.startOfDay(for: bucket.date)

            // Monotonic day-advance guard: fold only strictly-after the last bucketed day.
            // Re-presenting the same/older day is a no-op (idempotent).
            if let last = current.lastBucketedDate, day <= calendar.startOfDay(for: last) {
                continue
            }

            current = BaselineEngine.step(
                state: current,
                observation: value,
                config: config,
                bucketedDate: day
            )
        }
        return current
    }

    // MARK: - Day enumeration

    /// Ascending, dense list of `startOfDay` days from `rangeStart` through `rangeEnd`
    /// (inclusive). Returns a single day when start/end share a calendar day, and an empty
    /// array if `rangeEnd < rangeStart`.
    private static func enumerateDays(
        rangeStart: Date,
        rangeEnd: Date,
        calendar: Calendar
    ) -> [Date] {
        let start = calendar.startOfDay(for: rangeStart)
        let end = calendar.startOfDay(for: rangeEnd)
        guard end >= start else { return [] }

        var days: [Date] = []
        var cursor = start
        while cursor <= end {
            days.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return days
    }
}
