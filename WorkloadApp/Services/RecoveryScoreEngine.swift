import Foundation

/// Computes a composite recovery score (0-100) by fusing passive HealthKit data
/// with active subjective wellness data, then applying a trend modifier based on
/// recent recovery trajectory.
///
/// Component weights (base score):
/// - HRV vs personal baseline: 30%
/// - Resting HR vs baseline:   20%
/// - Sleep duration + quality:  25%
/// - Subjective wellness:       25%
///
/// Trend modifier: adjusts base score by up to ±10 points based on 3-day smoothed
/// recovery slope. A score of 70 trending down from 85 is meaningfully different
/// from 70 trending up from 55.
///
/// Baseline = 7-day rolling average (individual, not population-based).
struct RecoveryScoreEngine {

    struct RecoveryInput {
        let hrvSDNN: Double?
        let restingHR: Double?
        let sleepDurationMinutes: Double?
        let wellnessScore: Double?  // 0-100 from WellnessCheckIn

        // Baselines (7-day rolling averages)
        let hrvBaseline: Double?
        let restingHRBaseline: Double?

        // Recent recovery scores for trend calculation (oldest first)
        // Pass last 7 days of recovery scores. Nil or empty = no trend applied.
        let recentScores: [Double]

        init(
            hrvSDNN: Double? = nil,
            restingHR: Double? = nil,
            sleepDurationMinutes: Double? = nil,
            wellnessScore: Double? = nil,
            hrvBaseline: Double? = nil,
            restingHRBaseline: Double? = nil,
            recentScores: [Double] = []
        ) {
            self.hrvSDNN = hrvSDNN
            self.restingHR = restingHR
            self.sleepDurationMinutes = sleepDurationMinutes
            self.wellnessScore = wellnessScore
            self.hrvBaseline = hrvBaseline
            self.restingHRBaseline = restingHRBaseline
            self.recentScores = recentScores
        }
    }

    struct RecoveryResult {
        let score: Double          // 0-100 (trend-adjusted)
        let baseScore: Double      // 0-100 (before trend adjustment)
        let zone: RecoveryZone
        let hrvContribution: Double?
        let rhrContribution: Double?
        let sleepContribution: Double?
        let wellnessContribution: Double?
        let trendSlope3Day: Double?    // points per day (positive = improving)
        let trendSlope7Day: Double?    // points per day (positive = improving)
        let trendModifier: Double      // actual adjustment applied (-10 to +10)
    }

    // MARK: - Weights

    private static let hrvWeight: Double = 0.30
    private static let rhrWeight: Double = 0.20
    private static let sleepWeight: Double = 0.25
    private static let wellnessWeight: Double = 0.25

    /// Maximum trend adjustment in either direction
    private static let maxTrendModifier: Double = 10.0
    /// Minimum data points for 3-day slope
    private static let minTrendSamples: Int = 3

    // MARK: - Compute

    /// Compute composite recovery score from available inputs.
    /// Gracefully handles missing data by redistributing weights.
    static func compute(input: RecoveryInput) -> RecoveryResult {
        var components: [(score: Double, weight: Double)] = []
        var hrvScore: Double?
        var rhrScore: Double?
        var sleepScore: Double?
        var wellnessScore: Double?

        // HRV component: higher than baseline = better recovery
        if let hrv = input.hrvSDNN, let baseline = input.hrvBaseline, baseline > 0 {
            let ratio = hrv / baseline
            let score = clampScore(ratioToScore(ratio, higherIsBetter: true))
            hrvScore = score
            components.append((score, hrvWeight))
        }

        // Resting HR component: lower than baseline = better recovery
        if let rhr = input.restingHR, let baseline = input.restingHRBaseline, baseline > 0 {
            let ratio = rhr / baseline
            let score = clampScore(ratioToScore(ratio, higherIsBetter: false))
            rhrScore = score
            components.append((score, rhrWeight))
        }

        // Sleep component: based on duration (target: 420 min = 7 hours)
        if let sleepMin = input.sleepDurationMinutes {
            let score = clampScore(sleepDurationToScore(sleepMin))
            sleepScore = score
            components.append((score, sleepWeight))
        }

        // Wellness component: already 0-100
        if let wellness = input.wellnessScore {
            wellnessScore = wellness
            components.append((wellness, wellnessWeight))
        }

        // If no data at all, return neutral 50
        guard !components.isEmpty else {
            return RecoveryResult(
                score: 50,
                baseScore: 50,
                zone: .yellow,
                hrvContribution: nil,
                rhrContribution: nil,
                sleepContribution: nil,
                wellnessContribution: nil,
                trendSlope3Day: nil,
                trendSlope7Day: nil,
                trendModifier: 0
            )
        }

        // Redistribute weights proportionally for missing components
        let totalWeight = components.reduce(0) { $0 + $1.weight }
        let weightedScore = components.reduce(0) { sum, component in
            sum + component.score * (component.weight / totalWeight)
        }

        let baseScore = clampScore(weightedScore)

        // Compute trend slopes
        let slope3 = computeSlope(values: Array(input.recentScores.suffix(3)))
        let slope7 = computeSlope(values: input.recentScores)

        // Apply damped trend modifier using 3-day slope (more responsive)
        // Damping: use tanh to prevent wild swings, cap at ±maxTrendModifier
        let trendMod: Double
        if let s3 = slope3, input.recentScores.count >= minTrendSamples {
            // tanh maps any slope to (-1, 1), then scale by max modifier
            // Sensitivity: slope of 5 pts/day → tanh(5/3) ≈ 0.93 → ~9.3 points
            // Slope of 2 pts/day → tanh(2/3) ≈ 0.58 → ~5.8 points
            trendMod = tanh(s3 / 3.0) * maxTrendModifier
        } else {
            trendMod = 0
        }

        let finalScore = clampScore(baseScore + trendMod)
        return RecoveryResult(
            score: finalScore,
            baseScore: baseScore,
            zone: RecoveryZone.classify(score: finalScore),
            hrvContribution: hrvScore,
            rhrContribution: rhrScore,
            sleepContribution: sleepScore,
            wellnessContribution: wellnessScore,
            trendSlope3Day: slope3,
            trendSlope7Day: slope7,
            trendModifier: trendMod
        )
    }

    // MARK: - Trend Computation

    /// Compute slope (points per day) via simple linear regression.
    /// Returns nil if fewer than 2 values.
    static func computeSlope(values: [Double]) -> Double? {
        guard values.count >= 2 else { return nil }
        let n = Double(values.count)
        // x = 0, 1, 2, ... (day indices)
        let sumX = n * (n - 1) / 2.0
        let sumX2 = n * (n - 1) * (2 * n - 1) / 6.0
        let sumY = values.reduce(0, +)
        let sumXY = values.enumerated().reduce(0.0) { sum, pair in
            sum + Double(pair.offset) * pair.element
        }
        let denominator = n * sumX2 - sumX * sumX
        guard denominator != 0 else { return nil }
        return (n * sumXY - sumX * sumY) / denominator
    }

    // MARK: - Scoring Functions

    /// Convert a ratio-to-baseline into a 0-100 score.
    /// For higherIsBetter (HRV): ratio 1.0 = 70 (good), 1.2+ = 100, 0.7 = 20
    /// For lowerIsBetter (RHR): ratio 1.0 = 70 (good), 0.9 = 90, 1.2 = 20
    private static func ratioToScore(_ ratio: Double, higherIsBetter: Bool) -> Double {
        let adjustedRatio = higherIsBetter ? ratio : (2.0 - ratio)
        // Linear mapping: 0.7 → 20, 1.0 → 70, 1.2 → 100
        return 20.0 + (adjustedRatio - 0.7) * (80.0 / 0.5)
    }

    /// Sleep duration to score: <5h = 10, 6h = 40, 7h = 70, 8h = 90, 9h+ = 100
    private static func sleepDurationToScore(_ minutes: Double) -> Double {
        let hours = minutes / 60.0
        switch hours {
        case ..<5: return 10
        case 5..<6: return 10 + (hours - 5) * 30  // 10-40
        case 6..<7: return 40 + (hours - 6) * 30  // 40-70
        case 7..<8: return 70 + (hours - 7) * 20  // 70-90
        case 8..<9: return 90 + (hours - 8) * 10  // 90-100
        default: return 100
        }
    }

    private static func clampScore(_ score: Double) -> Double {
        min(100, max(0, score))
    }

    // MARK: - Baseline Computation

    /// Compute 7-day rolling average from an array of values
    static func computeBaseline(values: [Double]) -> Double? {
        let recent = Array(values.suffix(7))
        guard !recent.isEmpty else { return nil }
        return recent.reduce(0, +) / Double(recent.count)
    }
}
