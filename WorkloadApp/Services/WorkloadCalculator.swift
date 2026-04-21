import Foundation

/// Pure workload calculation engine.
/// Implements EWMA and Rolling Average ACWR models,
/// sRPE-based and TRIMP-based internal load, and Efficiency Index.
struct WorkloadCalculator {

    // MARK: - EWMA Constants

    /// ATL decay constant: 1/7
    private static let atlLambda: Double = 1.0 / 7.0
    /// CTL decay constant: 1/28
    private static let ctlLambda: Double = 1.0 / 28.0

    // MARK: - TRIMP HR Zone Weights

    /// HR zone weights for TRIMP calculation (Banister model)
    private static let zoneWeights: [Double] = [1.0, 1.5, 2.0, 3.0, 5.0]

    // MARK: - Data Types

    struct DailyLoad {
        let date: Date
        let tss: Double  // Training Stress Score for that day (0 if rest day)
    }

    struct WorkloadResult {
        let date: Date
        let atl: Double   // Acute Training Load
        let ctl: Double   // Chronic Training Load
        let acwr: Double  // ATL / CTL
        let tsb: Double   // CTL - ATL ("form")

        var zone: ACWRZone {
            ACWRZone.classify(acwr: acwr, ctl: ctl)
        }
    }

    // MARK: - Session-Level Calculations

    /// Training Stress Score for a single session using sRPE method (Foster).
    /// TSS = duration_hours × sessionRPE × (sessionRPE / 10)
    static func sessionTSS(durationSeconds: Int, sessionRPE: Double) -> Double {
        let hours = Double(durationSeconds) / 3600.0
        return hours * sessionRPE * (sessionRPE / 10.0)
    }

    /// Internal load using sRPE method.
    /// sRPE Load = duration_minutes × session_RPE
    static func srpeLoad(durationSeconds: Int, sessionRPE: Double) -> Double {
        let minutes = Double(durationSeconds) / 60.0
        return minutes * sessionRPE
    }

    /// TRIMP calculation from HR zone durations.
    /// - Parameter zoneDurationsMinutes: Array of 5 elements — minutes spent in each HR zone (Z1-Z5)
    static func trimp(zoneDurationsMinutes: [Double]) -> Double {
        zip(zoneDurationsMinutes, zoneWeights).reduce(0.0) { sum, pair in
            sum + pair.0 * pair.1
        }
    }

    /// Classify a heart rate sample into a zone (1-5) based on max HR.
    /// Zone boundaries: Z1 <60%, Z2 60-70%, Z3 70-80%, Z4 80-90%, Z5 90%+
    static func hrZone(heartRate: Double, maxHR: Int) -> Int {
        let pct = heartRate / Double(maxHR)
        switch pct {
        case ..<0.6: return 1
        case 0.6..<0.7: return 2
        case 0.7..<0.8: return 3
        case 0.8..<0.9: return 4
        default: return 5
        }
    }

    /// Efficiency Index: External Load / Internal Load.
    /// Rising = adaptation (fitter), Falling = fatigue/maladaptation.
    static func efficiencyIndex(externalLoad: Double, internalLoad: Double) -> Double? {
        guard internalLoad > 0 else { return nil }
        return externalLoad / internalLoad
    }

    // MARK: - EWMA ACWR

    /// Compute full workload history using EWMA.
    /// - Parameter loads: Array of DailyLoad sorted ascending by date.
    ///   Must include zero-TSS entries for rest days to maintain continuity.
    static func computeHistoryEWMA(loads: [DailyLoad]) -> [WorkloadResult] {
        var atl = 0.0
        var ctl = 0.0
        return loads.map { day in
            atl = atl * (1.0 - atlLambda) + day.tss * atlLambda
            ctl = ctl * (1.0 - ctlLambda) + day.tss * ctlLambda
            let acwr = ctl > 0 ? atl / ctl : 0.0
            return WorkloadResult(date: day.date, atl: atl, ctl: ctl, acwr: acwr, tsb: ctl - atl)
        }
    }

    /// Single forward step from known previous ATL/CTL.
    /// Used after each new session is saved.
    static func stepEWMA(previousATL: Double, previousCTL: Double, todayTSS: Double) -> WorkloadResult {
        let atl = previousATL * (1.0 - atlLambda) + todayTSS * atlLambda
        let ctl = previousCTL * (1.0 - ctlLambda) + todayTSS * ctlLambda
        let acwr = ctl > 0 ? atl / ctl : 0.0
        return WorkloadResult(date: .now, atl: atl, ctl: ctl, acwr: acwr, tsb: ctl - atl)
    }

    // MARK: - Rolling Average ACWR

    /// Compute ACWR using simple rolling averages.
    /// - Parameter dailyLoads: Last 28+ days of daily load values (most recent last)
    static func computeRollingACWR(dailyLoads: [Double]) -> WorkloadResult {
        let count = dailyLoads.count
        let acute7 = count >= 7
            ? dailyLoads.suffix(7).reduce(0, +) / 7.0
            : dailyLoads.reduce(0, +) / max(Double(count), 1)
        let chronic28 = count >= 28
            ? dailyLoads.suffix(28).reduce(0, +) / 28.0
            : dailyLoads.reduce(0, +) / max(Double(count), 1)
        let acwr = chronic28 > 0 ? acute7 / chronic28 : 0.0
        return WorkloadResult(
            date: .now,
            atl: acute7,
            ctl: chronic28,
            acwr: acwr,
            tsb: chronic28 - acute7
        )
    }

    // MARK: - Session Spike Detection

    /// Severity levels for session load spikes.
    enum SpikeSeverity {
        case moderate   // 1.5x–2.0x average
        case high       // >2.0x average
    }

    /// Alert returned when a session's TSS significantly exceeds recent average.
    struct SpikeAlert {
        let sessionTSS: Double
        let averageTSS: Double
        let ratio: Double          // sessionTSS / averageTSS
        let severity: SpikeSeverity
    }

    /// Detect if a session's load is a spike relative to the athlete's recent history.
    /// Returns nil if no spike or insufficient data (fewer than 3 prior sessions).
    /// - Parameters:
    ///   - sessionTSS: The current session's training stress score
    ///   - recentSessions: All sessions within the lookback window (excluding current)
    ///   - threshold: Spike threshold multiplier (default 1.5x)
    static func detectSessionSpike(
        sessionTSS: Double,
        recentSessionTSSValues: [Double],
        threshold: Double = 1.5
    ) -> SpikeAlert? {
        // Need at least 3 prior sessions to establish a meaningful baseline
        guard recentSessionTSSValues.count >= 3 else { return nil }
        guard sessionTSS > 0 else { return nil }

        let averageTSS = recentSessionTSSValues.reduce(0, +) / Double(recentSessionTSSValues.count)
        guard averageTSS > 0 else { return nil }

        let ratio = sessionTSS / averageTSS
        guard ratio >= threshold else { return nil }

        let severity: SpikeSeverity = ratio >= 2.0 ? .high : .moderate
        return SpikeAlert(
            sessionTSS: sessionTSS,
            averageTSS: averageTSS,
            ratio: ratio,
            severity: severity
        )
    }

    // MARK: - Weekly Volume

    /// Rolling 7-day total volume from session volumes.
    static func weeklyVolume(sessions: [(date: Date, volume: Double)]) -> Double {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return sessions.filter { $0.date >= sevenDaysAgo }.reduce(0) { $0 + $1.volume }
    }
}
