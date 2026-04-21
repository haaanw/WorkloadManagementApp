import Foundation

/// Produces human-readable reasoning factors from recovery and workload inputs.
/// Explains *why* the readiness score is what it is, ranked by impact.
///
/// Pure struct with static methods — no state, no dependencies.
struct ReasoningEngine {

    struct Input {
        let recoveryResult: RecoveryScoreEngine.RecoveryResult
        let workloadSnapshot: WorkloadSnapshot?
        let rawHRV: Double?
        let rawRHR: Double?
        let hrvBaseline: Double?
        let rhrBaseline: Double?
        let sleepMinutes: Double?
        let daysSinceRest: Int
    }

    struct Factor {
        let label: String       // "Heart Rate Variability"
        let deltaText: String   // "14% below baseline" / "38 min below average"
        let impact: Double      // 0–1, used for ranking (higher = more impactful)
        let direction: Direction

        enum Direction { case positive, neutral, negative }
    }

    /// Returns factors ranked by impact (highest first), max 3 for hero card display.
    static func summarize(input: Input) -> [Factor] {
        var factors: [Factor] = []

        // HRV — higher than baseline is better
        if let hrv = input.rawHRV, let baseline = input.hrvBaseline, baseline > 0 {
            let delta = (hrv - baseline) / baseline * 100
            let abs = Swift.abs(delta)
            let direction: Factor.Direction = delta > 5 ? .positive : delta < -5 ? .negative : .neutral
            let text = delta >= 0
                ? String(format: "%.0f%% above baseline", abs)
                : String(format: "%.0f%% below baseline", abs)
            factors.append(Factor(
                label: "Heart Rate Variability",
                deltaText: text,
                impact: min(abs / 30, 1.0),
                direction: direction
            ))
        }

        // Resting HR — lower than baseline is better (direction inverted)
        if let rhr = input.rawRHR, let baseline = input.rhrBaseline, baseline > 0 {
            let delta = (rhr - baseline) / baseline * 100
            let abs = Swift.abs(delta)
            let direction: Factor.Direction = delta > 5 ? .negative : delta < -5 ? .positive : .neutral
            let text = delta >= 0
                ? String(format: "%.0f%% above baseline", abs)
                : String(format: "%.0f%% below baseline", abs)
            factors.append(Factor(
                label: "Resting Heart Rate",
                deltaText: text,
                impact: min(abs / 30, 1.0),
                direction: direction
            ))
        }

        // Sleep — target is 420 min (7 hours)
        if let sleep = input.sleepMinutes {
            let delta = sleep - 420
            let abs = Swift.abs(delta)
            let direction: Factor.Direction = delta >= 30 ? .positive : delta <= -30 ? .negative : .neutral
            let text: String
            if delta >= 0 {
                text = "\(Int(delta)) min above average"
            } else {
                text = "\(Int(abs)) min below average"
            }
            factors.append(Factor(
                label: "Sleep Duration",
                deltaText: text,
                impact: min(abs / 90, 1.0),  // 90 min deviation = max impact
                direction: direction
            ))
        }

        // Consecutive training days — flags accumulating fatigue
        if input.daysSinceRest >= 4 {
            let days = input.daysSinceRest
            factors.append(Factor(
                label: "Training Streak",
                deltaText: "\(days) consecutive training days",
                impact: min(Double(days - 3) / 4.0, 1.0),
                direction: .negative
            ))
        }

        return factors.sorted { $0.impact > $1.impact }.prefix(3).map { $0 }
    }
}
