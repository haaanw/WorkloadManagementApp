import Foundation

/// Pure, deterministic load-distribution engine (Phase 27, Wave 2).
///
/// Builds a UNIFIED daily-load series (endurance sRPE load via `WorkloadCalculator.srpeLoad`
/// + strength hard-set load via the Wave-1 `StrengthLoadEngine`) and computes Foster
/// monotony & strain — but **completeness-gated** (moat-design §2.6, codex MAJOR): on sparse
/// consumer logs, monotony/strain are statistically fragile, so they are returned only when a
/// minimum-logged-days + non-zero-variance gate passes. When the gate fails, monotony/strain
/// are `nil`, an explicit `gateState` says `.fellBack`, and a 0…1 `fallbackLoadSignal` is
/// derived from the existing density / spike heuristics instead.
///
/// ## Pure / Foundation-only / dateless-by-injection
/// Static methods only, no stored state, no `Date.now` / `Calendar.current` — `asOf` and
/// `calendar` are passed in. Reuses (does NOT reinvent): `WorkloadCalculator.srpeLoad`,
/// `WorkloadCalculator.sessionTSS` + `detectSessionSpike`, `FatigueIndexEngine`'s
/// `sessions/14d` density formula, and `StrengthLoadEngine` set classification.
struct LoadDistributionEngine {

    // MARK: - Output types

    /// Whether monotony/strain were computed or the engine fell back to the heuristic signal.
    enum GateState: String, Equatable {
        case computed
        case fellBack
    }

    /// One day's unified load (a calendar day that had at least one session in the window).
    struct DailyLoad: Equatable {
        let dayStart: Date
        let load: Double   // endurance sRPE load + strength hard-set load
    }

    struct LoadDistributionResult: Equatable {
        let monotony: Double?
        let strain: Double?
        let gateState: GateState
        /// 0…1 heuristic load signal used when the gate fell back (always populated, but only
        /// meaningful — and surfaced as a factor — when `gateState == .fellBack`).
        let fallbackLoadSignal: Double
        /// Count of distinct calendar days with a logged session in the window.
        let loggedDays: Int
    }

    // MARK: - Named constants

    enum Constants {
        /// Window (days) over which the daily-load series is built.
        static let seriesWindowDays: Int = 14
        /// Minimum distinct logged days required before Foster monotony/strain are trusted.
        static let monotonyMinLoggedDays: Int = 7
        /// Density normaliser: sessions per 14 days mapped to 0…1 (mirrors FatigueIndexEngine).
        static let densityFullSessions: Double = 14.0
        /// Spike bump added to the fallback signal when a recent session spike is detected.
        static let spikeBump: Double = 0.25
        /// Spike-detection lookback (days) for the fallback heuristic.
        static let spikeLookbackDays: Int = 14
    }

    // MARK: - Daily-load series (Task 1)

    /// Build the unified daily-load series over `windowDays` ending at `asOf`. Only days that
    /// HAD a session in the window appear (logged days); rest days are absent (not zero-filled)
    /// so `loggedDays` reflects genuine training frequency. Per logged day:
    /// `Σ srpeLoad(sessions with sessionRPE) + Σ strength hard-set load`.
    static func dailyLoadSeries(
        sessions: [WorkoutSession],
        asOf: Date,
        calendar: Calendar,
        windowDays: Int = Constants.seriesWindowDays
    ) -> [DailyLoad] {
        let to = calendar.startOfDay(for: asOf)
        let windowed = sessions.filter { session in
            let from = calendar.startOfDay(for: session.sessionDate)
            guard let diff = calendar.dateComponents([.day], from: from, to: to).day else { return false }
            return diff >= 0 && diff <= windowDays
        }

        // est-1RM references for the strength component (rolling best over FULL history).
        let references = StrengthLoadEngine.e1RMReferences(sessions: sessions)

        var byDay: [Date: Double] = [:]
        for session in windowed {
            let day = calendar.startOfDay(for: session.sessionDate)
            byDay[day, default: 0] += sessionUnifiedLoad(session: session, references: references)
        }

        return byDay
            .map { DailyLoad(dayStart: $0.key, load: $0.value) }
            .sorted { $0.dayStart < $1.dayStart }
    }

    /// One session's unified load: endurance sRPE (only when `sessionRPE` present) + strength
    /// hard-set load (per-bucket strain weight summed over this session's hard sets, reusing
    /// `StrengthLoadEngine.classify`).
    private static func sessionUnifiedLoad(session: WorkoutSession, references: [String: Double]) -> Double {
        var load = 0.0
        if let rpe = session.sessionRPE {
            load += WorkloadCalculator.srpeLoad(durationSeconds: session.durationSeconds, sessionRPE: rpe)
        }
        load += sessionStrengthLoad(session: session, references: references)
        return load
    }

    /// Strength hard-set load for one session (sum of per-bucket strain weights for hard sets),
    /// reusing the Wave-1 classification + strain weights. No raw tonnage.
    private static func sessionStrengthLoad(session: WorkoutSession, references: [String: Double]) -> Double {
        var load = 0.0
        for entry in session.exerciseEntries {
            guard let muscle = entry.muscleGroup else { continue }
            let ref = references["\(muscle.rawValue)::\(entry.exerciseName)"]
            for set in entry.sets {
                if case let .hard(bucket) = StrengthLoadEngine.classify(set: set, e1RMReference: ref) {
                    load += StrengthLoadEngine.Constants.strainWeight(for: bucket)
                }
            }
        }
        return load
    }

    // MARK: - Foster monotony / strain (Task 1)

    /// Foster monotony = mean / sampleSD. Returns nil when < 2 data points or sampleSD == 0
    /// (the gate handles those; never divide by zero / produce inf).
    static func monotony(_ daily: [Double]) -> Double? {
        guard daily.count >= 2 else { return nil }
        let mean = daily.reduce(0, +) / Double(daily.count)
        guard let sd = sampleSD(daily, mean: mean), sd > 0 else { return nil }
        return mean / sd
    }

    /// Foster strain = sum(daily) * monotony. Nil whenever monotony is nil.
    static func strain(_ daily: [Double]) -> Double? {
        guard let m = monotony(daily) else { return nil }
        return daily.reduce(0, +) * m
    }

    private static func sampleSD(_ values: [Double], mean: Double) -> Double? {
        guard values.count >= 2 else { return nil }
        let ss = values.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) }
        let variance = ss / Double(values.count - 1)
        guard variance.isFinite, variance >= 0 else { return nil }
        return sqrt(variance)
    }

    // MARK: - Completeness gate + fallback (Task 2)

    /// The completeness gate passes only when there are at least `monotonyMinLoggedDays`
    /// logged days AND the daily series has non-zero variance.
    static func completenessGate(_ series: [DailyLoad]) -> Bool {
        guard series.count >= Constants.monotonyMinLoggedDays else { return false }
        let loads = series.map(\.load)
        let mean = loads.reduce(0, +) / Double(loads.count)
        guard let sd = sampleSD(loads, mean: mean) else { return false }
        return sd > 0
    }

    /// Full distribution result: gated Foster monotony/strain OR a heuristic fallback.
    static func distribution(
        sessions: [WorkoutSession],
        asOf: Date,
        calendar: Calendar,
        windowDays: Int = Constants.seriesWindowDays
    ) -> LoadDistributionResult {
        let series = dailyLoadSeries(sessions: sessions, asOf: asOf, calendar: calendar, windowDays: windowDays)
        let loggedDays = series.count
        let fallback = fallbackLoadSignal(sessions: sessions, asOf: asOf, calendar: calendar)

        guard completenessGate(series) else {
            return LoadDistributionResult(
                monotony: nil,
                strain: nil,
                gateState: .fellBack,
                fallbackLoadSignal: fallback,
                loggedDays: loggedDays
            )
        }

        let loads = series.map(\.load)
        return LoadDistributionResult(
            monotony: monotony(loads),
            strain: strain(loads),
            gateState: .computed,
            fallbackLoadSignal: fallback,
            loggedDays: loggedDays
        )
    }

    // MARK: - Fallback heuristic (Task 2)

    /// 0…1 fallback load signal: a blend of session density (sessions/14d clamped, mirroring
    /// `FatigueIndexEngine`'s density formula) bumped when a recent session spike is detected
    /// (`WorkloadCalculator.detectSessionSpike`). Used when the monotony gate fails.
    static func fallbackLoadSignal(
        sessions: [WorkoutSession],
        asOf: Date,
        calendar: Calendar
    ) -> Double {
        let to = calendar.startOfDay(for: asOf)
        let recent = sessions.filter { session in
            let from = calendar.startOfDay(for: session.sessionDate)
            guard let diff = calendar.dateComponents([.day], from: from, to: to).day else { return false }
            return diff >= 0 && diff <= Constants.spikeLookbackDays
        }

        // Density component (sessions / 14d, clamped 0…1) — same shape as FatigueIndexEngine.
        let density = clamp(Double(recent.count) / Constants.densityFullSessions, min: 0, max: 1)

        // Spike component: TSS of the most-recent session vs the prior TSS values.
        var spikeBump = 0.0
        let sortedByDate = recent.sorted { $0.sessionDate < $1.sessionDate }
        if let latest = sortedByDate.last, let rpe = latest.sessionRPE {
            let latestTSS = WorkloadCalculator.sessionTSS(durationSeconds: latest.durationSeconds, sessionRPE: rpe)
            let priorTSS: [Double] = sortedByDate.dropLast().compactMap { s in
                guard let r = s.sessionRPE else { return nil }
                return WorkloadCalculator.sessionTSS(durationSeconds: s.durationSeconds, sessionRPE: r)
            }
            if WorkloadCalculator.detectSessionSpike(sessionTSS: latestTSS, recentSessionTSSValues: priorTSS) != nil {
                spikeBump = Constants.spikeBump
            }
        }

        return clamp(density + spikeBump, min: 0, max: 1)
    }

    // MARK: - Helpers

    private static func clamp(_ value: Double, min: Double, max: Double) -> Double {
        Swift.min(max, Swift.max(min, value))
    }
}
