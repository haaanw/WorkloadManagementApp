import Foundation

/// Persisted baselines that survive gaps, late data, and corrections — the **checkpoint plus
/// replayed tail** design.
///
/// ## The problem it solves
///
/// Two obvious ways to maintain a running baseline, each with a fatal flaw at the extreme:
///
/// - **Save the running number and add today to it.** Fast, and it gives the estimator a
///   memory longer than any window we can afford to re-read. But a saved fold can only move
///   forward — the guard that stops a day being counted twice is the same guard that makes a
///   missed or later-corrected day permanently unabsorbable. Health data does not arrive in
///   neat forward order: the Watch syncs late, Apple revises values, and days pass with the
///   app unopened. The saved number then drifts quietly wrong with no way to notice or repair.
/// - **Recompute everything every time.** Always correct and always absorbs late data, but
///   bounded by how much history you can afford to walk, which caps the memory.
///
/// They are the same design at different window sizes, so the fix is to choose the window
/// deliberately rather than take either extreme:
///
/// **Days older than `sealHorizonDays` are considered final and folded into a saved
/// checkpoint. Everything newer is replayed from the raw daily values on every single run.**
///
/// What that buys, concretely:
///
/// - **Gaps are a non-event.** Not opening the app for two days leaves those days sitting in
///   the replay tail; the next run folds them in date order, exactly as if you had opened it
///   each morning. There is no "catch up" special case because nothing was ever skipped.
/// - **Late and corrected data inside the horizon is absorbed automatically**, because that
///   span is rebuilt from raw values rather than trusted from a saved total.
/// - **Idempotent by construction.** Re-running on the same day replays the same tail onto
///   the same checkpoint and lands on the same state — correctness comes from recomputation,
///   not from a "have I already done today?" flag that can itself be wrong.
/// - **Cost is flat.** Roughly `sealHorizonDays` steps per run no matter how many years of
///   history the checkpoint represents.
///
/// ## The one case it does not fully cover, stated plainly
///
/// A value *revised* for a day already sealed into the checkpoint is not re-absorbed. It is
/// detected only when the number of sealed days changes (`sealedDayCount`), which catches a
/// day APPEARING late inside the sealed window and triggers a full rebuild. A silent revision
/// of an existing sealed day survives. That is an accepted, bounded error: the day is beyond
/// the seal horizon, so it is already several half-lives deep in an EWMA that is deliberately
/// robust to single-point moves. `schemaVersion` gives a blunt escape hatch — bump it and
/// every checkpoint rebuilds.
struct BaselineCheckpoint {

    /// Days newer than this are replayed from raw data on every run; older days are sealed.
    ///
    /// 14 days is chosen to sit comfortably beyond the window in which HealthKit realistically
    /// backfills or revises a day, while keeping the per-run replay trivial.
    static let sealHorizonDays: Int = 14

    /// Bump to force every stored checkpoint to rebuild — the escape hatch for a change in the
    /// estimator or in what a sealed day means.
    static let schemaVersion: Int = 1

    /// The saved half: everything the fold needs to resume from the sealed prefix.
    struct Stored {
        var state: BaselineEngine.SignalState
        /// Newest day folded into `state`; nil when nothing is sealed yet.
        var sealedThroughDay: Date?
        /// How many days were folded to build `state`. Compared against what the current
        /// history actually contains, so a day arriving late inside the sealed window is
        /// caught and forces a rebuild.
        var sealedDayCount: Int
        var schemaVersion: Int

        init(
            state: BaselineEngine.SignalState = BaselineEngine.SignalState(),
            sealedThroughDay: Date? = nil,
            sealedDayCount: Int = 0,
            schemaVersion: Int = BaselineCheckpoint.schemaVersion
        ) {
            self.state = state
            self.sealedThroughDay = sealedThroughDay
            self.sealedDayCount = sealedDayCount
            self.schemaVersion = schemaVersion
        }
    }

    /// One run's outcome: the state to score against, and the checkpoint to persist.
    struct Outcome {
        /// Checkpoint + replayed tail — the state today should be scored against.
        let workingState: BaselineEngine.SignalState
        /// The checkpoint to write back. Advances only when days crossed the seal horizon.
        let checkpoint: Stored
        /// True when the stored checkpoint was discarded and rebuilt from scratch.
        let didRebuild: Bool
    }

    /// One day's value, oldest first.
    struct DayValue: Equatable {
        let day: Date
        let value: Double

        init(day: Date, value: Double) {
            self.day = day
            self.value = value
        }
    }

    /// Advance the checkpoint and replay the tail.
    ///
    /// - Parameter stored: the persisted checkpoint, or a fresh one on first run.
    /// - Parameter days: every observed day available, ascending. Days at or before the
    ///   checkpoint are used only to validate it; days after it are folded.
    /// - Parameter config: the per-signal estimator configuration.
    /// - Parameter now: reference instant.
    /// - Parameter calendar: injected calendar.
    static func advance(
        stored: Stored,
        days: [DayValue],
        config: BaselineEngine.SignalConfig,
        now: Date,
        calendar: Calendar
    ) -> Outcome {
        let ascending = days.sorted { $0.day < $1.day }
        let today = calendar.startOfDay(for: now)
        let sealBoundary = calendar.date(byAdding: .day, value: -sealHorizonDays, to: today) ?? today

        // Is the stored checkpoint still a truthful summary of the days it claims?
        var checkpoint = stored
        var didRebuild = false
        if !isUsable(stored, days: ascending, calendar: calendar) {
            checkpoint = Stored()
            didRebuild = true
        }

        // Seal every day that has aged past the horizon but is not yet in the checkpoint.
        var sealedState = checkpoint.state
        var sealedThrough = checkpoint.sealedThroughDay
        var sealedCount = checkpoint.sealedDayCount
        for entry in ascending {
            let day = calendar.startOfDay(for: entry.day)
            if let sealedThrough, day <= calendar.startOfDay(for: sealedThrough) { continue }
            guard day <= sealBoundary else { break }   // ascending ⇒ the rest are tail
            sealedState = BaselineEngine.step(
                state: sealedState,
                observation: entry.value,
                config: config,
                bucketedDate: day
            )
            sealedThrough = day
            sealedCount += 1
        }
        let updated = Stored(
            state: sealedState,
            sealedThroughDay: sealedThrough,
            sealedDayCount: sealedCount,
            schemaVersion: schemaVersion
        )

        // Replay the tail — never persisted, so a late arrival inside the horizon is simply
        // picked up next run, and re-running today changes nothing.
        var working = sealedState
        for entry in ascending {
            let day = calendar.startOfDay(for: entry.day)
            if let sealedThrough, day <= calendar.startOfDay(for: sealedThrough) { continue }
            working = BaselineEngine.step(
                state: working,
                observation: entry.value,
                config: config,
                bucketedDate: day
            )
        }

        return Outcome(workingState: working, checkpoint: updated, didRebuild: didRebuild)
    }

    /// A checkpoint is trusted only when it still matches the history it claims to summarize:
    /// same estimator version, and the same number of days at or before its sealed edge. A
    /// mismatch means a day appeared late inside the sealed window, so the summary is stale.
    private static func isUsable(
        _ stored: Stored,
        days: [DayValue],
        calendar: Calendar
    ) -> Bool {
        guard stored.schemaVersion == schemaVersion else { return false }
        guard let sealedThrough = stored.sealedThroughDay else {
            // Nothing sealed yet — an empty checkpoint is always usable.
            return stored.sealedDayCount == 0 && stored.state.count == 0
        }
        let edge = calendar.startOfDay(for: sealedThrough)
        let observedThroughEdge = days.filter { calendar.startOfDay(for: $0.day) <= edge }.count
        return observedThroughEdge == stored.sealedDayCount
    }
}
