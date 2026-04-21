import Foundation

/// Computes a composite recovery score (0-100) by fusing passive HealthKit data
/// with active subjective wellness data.
///
/// Component weights:
/// - HRV vs personal baseline: 30%
/// - Resting HR vs baseline:   20%
/// - Sleep duration + quality:  25%
/// - Subjective wellness:       25%
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
    }

    struct RecoveryResult {
        let score: Double          // 0-100
        let zone: RecoveryZone
        let hrvContribution: Double?
        let rhrContribution: Double?
        let sleepContribution: Double?
        let wellnessContribution: Double?
    }

    // MARK: - Weights

    private static let hrvWeight: Double = 0.30
    private static let rhrWeight: Double = 0.20
    private static let sleepWeight: Double = 0.25
    private static let wellnessWeight: Double = 0.25

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
                zone: .yellow,
                hrvContribution: nil,
                rhrContribution: nil,
                sleepContribution: nil,
                wellnessContribution: nil
            )
        }

        // Redistribute weights proportionally for missing components
        let totalWeight = components.reduce(0) { $0 + $1.weight }
        let weightedScore = components.reduce(0) { sum, component in
            sum + component.score * (component.weight / totalWeight)
        }

        let finalScore = clampScore(weightedScore)
        return RecoveryResult(
            score: finalScore,
            zone: RecoveryZone.classify(score: finalScore),
            hrvContribution: hrvScore,
            rhrContribution: rhrScore,
            sleepContribution: sleepScore,
            wellnessContribution: wellnessScore
        )
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
